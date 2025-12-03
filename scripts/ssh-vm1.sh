#!/bin/bash
# SSH to VM1 - Helper Script
# Usage: ./ssh-vm1.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

SSH to your team's primary VM (VM1).

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

Example:
    $0 --team 1

Default credentials:
    Username: appduser
    Password: (from config)

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

# Get VM1 IP
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)

if [ -z "$VM1_IP" ]; then
    log_error "VM1 IP not found. Has the deployment completed?"
    exit 1
fi

log_info "Connecting to VM1 (Team ${TEAM_NUMBER})..."
log_info "IP: $VM1_IP"
log_info "Username: appduser"
echo ""

ssh appduser@$VM1_IP
