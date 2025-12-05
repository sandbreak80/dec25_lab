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

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Health Check - Team ${TEAM_NUMBER}                   ║
╚══════════════════════════════════════════════════════════╝

EOF

log_info "Checking service status..."
echo ""

ssh appduser@$VM1_PUB "appdcli ping" 2>/dev/null || {
    log_error "Cannot connect to VM1"
    exit 1
}

echo ""
log_info "Checking pod health..."
echo ""

ssh appduser@$VM1_PUB "kubectl get pods --all-namespaces | grep -E '(cisco|authn|mysql|kafka|redis)' | head -20"

echo ""
log_info "Checking resource usage..."
echo ""

ssh appduser@$VM1_PUB "kubectl top nodes"

echo ""
log_info "Checking cluster status..."
echo ""

ssh appduser@$VM1_PUB "appdctl show cluster"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╝
║   Controller Access                                      ║
╚══════════════════════════════════════════════════════════╝

URL:  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
User: admin
Pass: welcome (CHANGE THIS!)

EOF
