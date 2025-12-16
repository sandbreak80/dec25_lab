#!/bin/bash
# Configure AppDynamics (globals.yaml.gotmpl)
# Usage: ./appd-configure.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Configure AppDynamics for Team                        ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Updates globals.yaml.gotmpl with team-specific configuration.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

This script:
  1. Downloads current globals.yaml.gotmpl from VM1
  2. Updates it with team-specific values
  3. Uploads it back to VM1
  4. Verifies configuration

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Configure AppDynamics - Team ${TEAM_NUMBER}                      ║
╚══════════════════════════════════════════════════════════╝

This will update globals.yaml.gotmpl with your team's configuration:
  Domain:     team${TEAM_NUMBER}.splunkylabs.com
  Tenant:     customer1
  DNS Names:  All team-specific URLs

EOF

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")

# Always use password auth (bootstrap/cluster init modify SSH keys)
PASSWORD="AppDynamics123!"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
log_info "Using password authentication (AppDynamics modifies keys during bootstrap)"

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

echo ""

# Step 1: Download current config
log_info "Downloading current configuration from VM1..."
mkdir -p "state/team${TEAM_NUMBER}/configs"

SCP_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 30
spawn scp $SSH_OPTS appduser@$VM1_PUB:/var/appd/config/globals.yaml.gotmpl "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.original"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    "No such file or directory" { puts "ERROR: Config file not found"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

SCP_EXIT=$?
if [ $SCP_EXIT -ne 0 ]; then
    log_error "Failed to download config. Is VM1 accessible?"
    echo "$SCP_OUTPUT" | sed 's/^/  /'
    exit 1
fi

log_success "Config downloaded"

# Step 2: Create updated config
log_info "Creating team-specific configuration..."

cp "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.original" \
   "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated"

# Update dnsDomain
sed -i.bak "s/dnsDomain: .*/dnsDomain: team${TEAM_NUMBER}.splunkylabs.com/" \
    "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated"

# Update dnsNames
sed -i.bak "/dnsNames: &dnsNames/,/^[^ ]/ {
    s|- .*nip.io|# - nip.io (replaced with real DNS)|
    s|- localhost|- localhost\n  - team${TEAM_NUMBER}.splunkylabs.com\n  - customer1-team${TEAM_NUMBER}.auth.splunkylabs.com\n  - customer1-tnt-authn-team${TEAM_NUMBER}.splunkylabs.com\n  - controller-team${TEAM_NUMBER}.splunkylabs.com|
}" "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated"

# Update externalUrl entries
sed -i.bak "s|externalUrl: https://[^/]*/|externalUrl: https://team${TEAM_NUMBER}.splunkylabs.com/|g" \
    "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated"

log_success "Configuration updated"

# Step 3: Show diff
log_info "Changes made:"
echo ""
echo "Domain:"
grep "dnsDomain:" "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated"
echo ""
echo "DNS Names:"
grep -A 6 "dnsNames:" "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated" | head -7
echo ""

log_info "Uploading configuration to VM1..."
echo ""

# Step 4: Upload to VM1
log_info "Uploading configuration to VM1..."

# Backup original on VM1
BACKUP_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh $SSH_OPTS appduser@$VM1_PUB "sudo cp /var/appd/config/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl.backup"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

if [ $? -ne 0 ]; then
    log_error "Failed to backup config on VM1"
    echo "$BACKUP_OUTPUT" | sed 's/^/  /'
    exit 1
fi

# Upload new config
UPLOAD_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 30
spawn scp $SSH_OPTS "state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.updated" appduser@$VM1_PUB:/tmp/globals.yaml.gotmpl.new
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

if [ $? -ne 0 ]; then
    log_error "Failed to upload config to VM1"
    echo "$UPLOAD_OUTPUT" | sed 's/^/  /'
    exit 1
fi

# Move into place
MOVE_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh $SSH_OPTS appduser@$VM1_PUB "sudo mv /tmp/globals.yaml.gotmpl.new /var/appd/config/globals.yaml.gotmpl"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

if [ $? -ne 0 ]; then
    log_error "Failed to move config into place on VM1"
    echo "$MOVE_OUTPUT" | sed 's/^/  /'
    exit 1
fi

CHOWN_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh $SSH_OPTS appduser@$VM1_PUB "sudo chown appduser:appduser /var/appd/config/globals.yaml.gotmpl"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

if [ $? -ne 0 ]; then
    log_error "Failed to set ownership on config file"
    echo "$CHOWN_OUTPUT" | sed 's/^/  /'
    exit 1
fi

log_success "Configuration uploaded"

# Step 5: Verify
log_info "Verifying configuration..."
VERIFY_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh $SSH_OPTS appduser@$VM1_PUB "grep 'dnsDomain:' /var/appd/config/globals.yaml.gotmpl"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

VERIFY_EXIT=$?
if [ $VERIFY_EXIT -ne 0 ]; then
    log_error "Failed to verify configuration"
    echo "$VERIFY_OUTPUT" | sed 's/^/  /'
    exit 1
fi

echo "$VERIFY_OUTPUT" | grep "dnsDomain:"

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   ✅ Configuration Complete!                             ║
╚══════════════════════════════════════════════════════════╝

Configuration files:
  Original backup: /var/appd/config/globals.yaml.gotmpl.backup (on VM1)
  Local backup:    state/team${TEAM_NUMBER}/configs/globals.yaml.gotmpl.original
  Updated config:  Applied to VM1

EOF

mark_step_complete "appd-configured" "$TEAM_NUMBER"
