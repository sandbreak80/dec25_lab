#!/bin/bash
# Apply AppDynamics License from S3
# Usage: ./09-apply-license.sh --team TEAM_NUMBER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Apply AppDynamics License - Team                       ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

This script will:
  1. Download license.lic from S3
  2. Copy license to VM1:/var/appd/config/license.lic
  3. Apply license using appdcli
  4. Verify license is active

Prerequisites:
  • Controller must be installed and running
  • VM1 must be accessible

Time: ~1 minute

EOF
    exit 1
}

TEAM_NUMBER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
fi

load_team_config "$TEAM_NUMBER"
check_aws_cli

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

# Always use password auth (bootstrap/cluster init modify SSH keys)
PASSWORD="AppDynamics123!"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Apply License - Team ${TEAM_NUMBER}                               ║
╚══════════════════════════════════════════════════════════╝

This will download and apply the AppDynamics license from S3.

Domain: ${FULL_DOMAIN}

EOF

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)

if [[ -z "$VM1_PUB" ]]; then
    log_error "VM1 IP not found. Has infrastructure been deployed?"
    exit 1
fi

log_info "VM1: $VM1_PUB"
echo ""

# Step 1: Download license from S3
log_info "Step 1: Downloading license from S3..."
echo ""

BUCKET_NAME="appdynamics-lab-resources"
LICENSE_FILE="/tmp/license-team${TEAM_NUMBER}.lic"

if aws s3 cp "s3://${BUCKET_NAME}/shared/license.lic" "$LICENSE_FILE" 2>&1 | sed 's/^/  /'; then
    log_success "License downloaded"
else
    log_error "Failed to download license from S3"
    echo ""
    echo "Make sure the license has been uploaded:"
    echo "  ./scripts/upload-license-to-s3.sh --admin-profile default"
    exit 1
fi

# Verify it's a valid license
if ! grep -q "property_version" "$LICENSE_FILE"; then
    log_error "Downloaded file does not appear to be a valid license"
    exit 1
fi

echo ""

# Extract license info
EXPIRY=$(grep "property_expiration_date_iso" "$LICENSE_FILE" | cut -d'=' -f2 | sed 's/\\:/:/g')
EDITION=$(grep "property_edition" "$LICENSE_FILE" | cut -d'=' -f2)

log_info "License Information:"
echo "  Edition: $EDITION"
echo "  Expires: $EXPIRY"
echo ""

# Step 2: Check if Controller is running
log_info "Step 2: Checking if Controller is running..."
echo ""

CONTROLLER_RUNNING=$(expect << EOF_EXPECT 2>/dev/null
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdcli ping 2>/dev/null"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)

if echo "$CONTROLLER_RUNNING" | grep -iq "controller.*Success"; then
    log_success "Controller is running"
else
    log_error "Controller is not running or not responding"
    echo ""
    echo "Make sure the Controller is installed and running:"
    echo "  ./deployment/07-install.sh --team ${TEAM_NUMBER}"
    exit 1
fi

echo ""

# Step 3: Copy license to VM1
log_info "Step 3: Copying license to VM1..."
echo ""

expect << EOF_EXPECT 2>&1 | grep -E "(Warning|100%|password)" | sed 's/^/  /'
set timeout 30
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${LICENSE_FILE} appduser@${VM1_PUB}:/var/appd/config/license.lic
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

log_success "License copied to /var/appd/config/license.lic"
echo ""

# Step 4: Apply license
log_info "Step 4: Applying license to Controller..."
echo ""

APPLY_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdcli license controller /var/appd/config/license.lic"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)

echo "$APPLY_OUTPUT" | grep -v "Warning:" | grep -v "password" | sed 's/^/  /'

if echo "$APPLY_OUTPUT" | grep -q "License updated"; then
    log_success "License applied successfully!"
else
    log_error "Failed to apply license"
    echo ""
    echo "Debug output:"
    echo "$APPLY_OUTPUT" | sed 's/^/  /'
    exit 1
fi

echo ""

# Step 5: Verify license file exists
log_info "Step 5: Verifying license installation..."
echo ""

LICENSE_CHECK=$(expect << EOF_EXPECT 2>/dev/null
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "ls -lh /var/appd/config/license.lic"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)

if echo "$LICENSE_CHECK" | grep -q "license.lic"; then
    echo "$LICENSE_CHECK" | grep "license.lic" | sed 's/^/  /'
    log_success "License file verified"
else
    log_warning "Could not verify license file"
fi

echo ""
log_success "License application complete!"
echo ""

cat << EOF
╔══════════════════════════════════════════════════════════╗
║  ✅ License Applied Successfully!                        ║
╚══════════════════════════════════════════════════════════╝

License Details:
  Edition:  $EDITION
  Expires:  $EXPIRY
  Location: /var/appd/config/license.lic

To verify in Controller UI:
  1. Log in: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
  2. Go to: Settings → License
  3. Verify license information

✅ Step completed: license-applied

EOF

# Mark step complete
mkdir -p "state/team${TEAM_NUMBER}"
touch "state/team${TEAM_NUMBER}/license-applied.txt"

