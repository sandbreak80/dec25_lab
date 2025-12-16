#!/bin/bash
# Check AppDynamics Health
# Usage: ./appd-check-health.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Check AppDynamics installation health and status.

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")

# Always use password auth (bootstrap/cluster init modify SSH keys)
PASSWORD="AppDynamics123!"
export VM1_PUB PASSWORD

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Health Check - Team ${TEAM_NUMBER}                   ║
╚══════════════════════════════════════════════════════════╝

EOF

log_info "Checking service status..."
echo ""

expect << EOF_EXPECT 2>&1
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$VM1_PUB "appdcli ping"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

if [ $? -ne 0 ]; then
    log_error "Cannot connect to VM1"
    exit 1
fi

echo ""
log_info "Checking pod health..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl get pods --all-namespaces | grep -E '(cisco|authn|mysql|kafka|redis)' | head -20"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT

echo ""
log_info "Checking resource usage..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl top nodes"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT

echo ""
log_info "Checking cluster status..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdctl show cluster"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Controller Access                                      ║
╚══════════════════════════════════════════════════════════╝

URL:  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
User: admin
Pass: welcome (CHANGE THIS!)

EOF
