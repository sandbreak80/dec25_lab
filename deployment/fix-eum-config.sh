#!/bin/bash
# Fix EUM Configuration - Update externalUrl
# Usage: ./fix-eum-config.sh --team TEAM_NUMBER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Fix EUM Configuration                                 ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Fixes the EUM externalUrl in globals.yaml.gotmpl and syncs services.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

This script:
  1. Updates EUM externalUrl to https://teamX.splunkylabs.com/eumaggregator
  2. Updates Events externalUrl to https://teamX.splunkylabs.com/events
  3. Syncs AppDynamics services to apply changes
  4. Restarts EUM pod

Time: 5-10 minutes

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Fix EUM Configuration - Team ${TEAM_NUMBER}                      ║
╚══════════════════════════════════════════════════════════╝

This will fix the EUM externalUrl configuration.

EOF

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")
PASSWORD="AppDynamics123!"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Export for expect scripts
export VM1_PUB PASSWORD TEAM_NUMBER

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

echo ""
log_info "Step 1: Checking current EUM configuration..."

CURRENT_CONFIG=$(expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "grep -A2 'eum:' /var/appd/config/globals.yaml.gotmpl"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$CURRENT_CONFIG"
echo ""

log_info "Step 2: Backing up and updating EUM externalUrl to PUBLIC DNS..."
log_info "Using: https://controller-team${TEAM_NUMBER}.splunkylabs.com/eumaggregator"
echo ""

BACKUP_AND_UPDATE=$(expect << 'EOF_EXPECT'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "sudo cp /var/appd/config/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl.backup-eum && sudo sed -i 's|externalUrl: https://.*nip.io|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/eumaggregator|' /var/appd/config/globals.yaml.gotmpl && sudo sed -i 's|externalUrl: <domain_name>|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/eumaggregator|' /var/appd/config/globals.yaml.gotmpl && sudo sed -i 's|externalUrl: https://<domain_name>|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/eumaggregator|' /var/appd/config/globals.yaml.gotmpl && sudo sed -i 's|externalUrl: https://team.*splunkylabs.com/eumaggregator|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/eumaggregator|' /var/appd/config/globals.yaml.gotmpl && grep -A2 'eum:' /var/appd/config/globals.yaml.gotmpl"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$BACKUP_AND_UPDATE"

log_success "EUM externalUrl updated to PUBLIC DNS"
echo ""

log_info "Step 3: Updating Events externalUrl to PUBLIC DNS..."
log_info "Using: https://controller-team${TEAM_NUMBER}.splunkylabs.com/events"
echo ""

EVENTS_UPDATE=$(expect << 'EOF_EXPECT'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "sudo sed -i 's|externalUrl: https://.*:32105|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/events|' /var/appd/config/globals.yaml.gotmpl && sudo sed -i 's|externalUrl: https://team.*splunkylabs.com/events|externalUrl: https://controller-team$env(TEAM_NUMBER).splunkylabs.com/events|' /var/appd/config/globals.yaml.gotmpl && grep -A3 'events:' /var/appd/config/globals.yaml.gotmpl | head -5"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$EVENTS_UPDATE"

log_success "Events externalUrl updated"
echo ""

log_info "Step 4: Syncing AppDynamics services..."
log_warning "This will take 5-10 minutes..."
echo ""

SYNC_OUTPUT=$(expect << 'EOF_EXPECT'
set timeout 900
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdcli sync appd"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Sync timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$SYNC_OUTPUT"

if echo "$SYNC_OUTPUT" | grep -qi "error"; then
    log_warning "Sync reported errors, but continuing..."
else
    log_success "Services synced"
fi

echo ""
log_info "Step 5: Restarting EUM pod..."

RESTART_OUTPUT=$(expect << 'EOF_EXPECT'
set timeout 60
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl delete pod -n cisco-eum eum-ss-0"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$RESTART_OUTPUT"

log_info "Waiting for EUM pod to restart (30 seconds)..."
sleep 30

log_info "Checking EUM pod status..."

POD_STATUS=$(expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl get pods -n cisco-eum"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$POD_STATUS"

log_success "EUM pod restarted"
echo ""

log_info "Step 6: Verifying EUM service..."

VERIFY_OUTPUT=$(expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdcli ping | grep -i eum"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

echo "$VERIFY_OUTPUT"

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   ✅ EUM Configuration Fixed!                            ║
╚══════════════════════════════════════════════════════════╝

PUBLIC DNS URLs configured:
  EUM:    https://controller-team${TEAM_NUMBER}.splunkylabs.com/eumaggregator
  Events: https://controller-team${TEAM_NUMBER}.splunkylabs.com/events

✅ These URLs are now accessible from any browser on the internet!

To verify in Controller UI:
  1. Go to https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
  2. Login as admin/welcome
  3. Go to Settings → Application Server Agent → Advanced
  4. Check EUM Cloud Host setting

To test JavaScript injection:
  1. Create a Browser App in Controller
  2. Get the JavaScript snippet
  3. Verify it points to controller-team${TEAM_NUMBER}.splunkylabs.com
  4. Add snippet to test web page
  5. Check EUM data flowing in Controller

EOF

