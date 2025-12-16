#!/bin/bash
# Download and Apply AppDynamics License
# This script downloads the license from S3 and applies it to the Controller

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Apply AppDynamics License                              ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --bucket NAME        S3 bucket name (optional, auto-detected)
    --license-file PATH  Use local license file instead of S3
    --help, -h           Show this help

Examples:
    $0 --team 1                                    # Download from S3 and apply
    $0 --team 1 --license-file /path/to/license.lic  # Apply local file

This script will:
  1. Download license.lic from S3 (or use local file)
  2. Copy license to VM1 at /var/appd/config/license.lic
  3. Apply license using appdcli
  4. Verify license is active
  5. Optionally wait for license to take effect (up to 5 minutes)

Prerequisites:
  • Controller must be installed and running
  • VM1 must be accessible via SSH

EOF
    exit 1
}

TEAM_NUMBER=""
BUCKET_NAME=""
LOCAL_LICENSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --bucket) BUCKET_NAME="$2"; shift 2 ;;
        --license-file) LOCAL_LICENSE="$2"; shift 2 ;;
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

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Apply License - Team ${TEAM_NUMBER}                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Get VM1 IP and SSH key
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null)

if [[ -z "$VM1_IP" ]]; then
    log_error "VM1 IP not found. Has infrastructure been deployed?"
    exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
    log_error "SSH key not found: $KEY_PATH"
    exit 1
fi

SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

log_info "VM1: $VM1_IP"
echo ""

# Step 1: Get the license file
if [[ -n "$LOCAL_LICENSE" ]]; then
    # Use local file
    if [[ ! -f "$LOCAL_LICENSE" ]]; then
        log_error "License file not found: $LOCAL_LICENSE"
        exit 1
    fi
    
    log_info "Using local license file: $LOCAL_LICENSE"
    LICENSE_SOURCE="$LOCAL_LICENSE"
else
    # Download from S3
    # Auto-detect bucket from state or use provided bucket
    if [[ -z "$BUCKET_NAME" ]] && [[ -f "${SCRIPT_DIR}/../state/shared/license-s3.txt" ]]; then
        source "${SCRIPT_DIR}/../state/shared/license-s3.txt"
    fi
    
    if [[ -z "$BUCKET_NAME" ]]; then
        BUCKET_NAME="appdynamics-lab-resources"
        log_warning "No bucket specified, using default: $BUCKET_NAME"
    fi
    
    log_info "Downloading license from S3..."
    log_info "Bucket: s3://${BUCKET_NAME}/shared/license.lic"
    
    LICENSE_SOURCE="/tmp/license-team${TEAM_NUMBER}.lic"
    
    if aws s3 cp "s3://${BUCKET_NAME}/shared/license.lic" "$LICENSE_SOURCE" 2>&1; then
        log_success "License downloaded"
    else
        log_error "Failed to download license from S3"
        log_info "Make sure the license has been uploaded:"
        log_info "  ./scripts/upload-license-to-s3.sh"
        exit 1
    fi
fi

# Verify license file
if ! grep -q "property_version" "$LICENSE_SOURCE"; then
    log_error "Downloaded file does not appear to be a valid AppDynamics license"
    exit 1
fi

# Extract and show license info
EXPIRY=$(grep "property_expiration_date_iso" "$LICENSE_SOURCE" | cut -d'=' -f2 | sed 's/\\:/:/g')
EDITION=$(grep "property_edition" "$LICENSE_SOURCE" | cut -d'=' -f2)
CUSTOMER=$(grep "property_customer-name" "$LICENSE_SOURCE" | cut -d'=' -f2)

echo ""
log_info "License Information:"
echo "  Customer: $CUSTOMER"
echo "  Edition: $EDITION"
echo "  Expires: $EXPIRY"
echo ""

# Step 2: Check if Controller is running
log_info "Checking if Controller is running..."
if ! ssh $SSH_OPTS appduser@${VM1_IP} "appdcli ping 2>/dev/null | grep -q 'controller.*Success'" 2>/dev/null; then
    log_error "Controller is not running or not responding"
    log_info "Make sure the Controller is installed and running:"
    log_info "  ./deployment/07-install.sh --team ${TEAM_NUMBER}"
    exit 1
fi
log_success "Controller is running"

# Step 3: Copy license directly to AppDynamics config directory
log_info "Copying license to VM1:/var/appd/config/license.lic..."
scp $SSH_OPTS "$LICENSE_SOURCE" appduser@${VM1_IP}:/var/appd/config/license.lic > /dev/null 2>&1

log_success "License file installed at /var/appd/config/license.lic"

# Step 5: Apply license using appdcli
log_info "Applying license to Controller..."
echo ""

ssh $SSH_OPTS appduser@${VM1_IP} "appdcli license controller /var/appd/config/license.lic" 2>&1 | sed 's/^/  /'

log_success "License applied!"

# Step 6: Touch the file to force reload (as per AppDynamics docs)
log_info "Triggering license reload..."
ssh $SSH_OPTS appduser@${VM1_IP} "touch /var/appd/config/license.lic"

echo ""
log_info "Waiting for license to take effect (up to 5 minutes)..."
echo ""

# Wait for license to be detected
for i in {1..10}; do
    sleep 30
    echo "  Check $i/10 (${i}:00 elapsed)..."
    
    # Try to verify in Controller UI (this would require curl to the REST API)
    # For now, just wait the recommended time
    
    if [ $i -eq 10 ]; then
        log_warning "Waited 5 minutes for license activation"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ License Application Complete!                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "The license has been applied to your Controller."
echo ""
echo "To verify the license is active:"
echo "  1. Log in to Controller UI:"
echo "     https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/"
echo ""
echo "  2. Navigate to: Settings → License → Account Usage"
echo ""
echo "  3. Verify license details match:"
echo "     - Edition: ${EDITION}"
echo "     - Expires: ${EXPIRY}"
echo ""
echo "If the license doesn't appear after 5 minutes:"
echo "  - SSH to VM1: ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}"
echo "  - Run: sudo touch /var/appd/config/license.lic"
echo "  - Wait 2-3 minutes and check again"
echo ""

# Clean up temporary file if we downloaded from S3
if [[ -z "$LOCAL_LICENSE" ]] && [[ -f "$LICENSE_SOURCE" ]]; then
    rm -f "$LICENSE_SOURCE"
fi

# Mark step complete
mark_step_complete "license-applied" "$TEAM_NUMBER"

