#!/bin/bash
# SSH to VM2 using team SSH key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  SSH to VM2 (Secondary Node)                            ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--user USERNAME]

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --user, -u USERNAME  SSH user (default: appduser)
    --help, -h           Show this help

EOF
    exit 1
}

TEAM_NUMBER=""
SSH_USER="appduser"

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --user|-u) SSH_USER="$2"; shift 2 ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
fi

load_team_config "$TEAM_NUMBER"

VM2_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null || echo "")

if [[ -z "$VM2_IP" ]] || [[ "$VM2_IP" == "None" ]]; then
    log_error "VM2 IP not found. Has the infrastructure been deployed?"
    exit 1
fi

if [[ -n "$VM_SSH_KEY" ]]; then
    KEY_FILE="${HOME}/.ssh/${VM_SSH_KEY}.pem"
else
    KEY_FILE="${HOME}/.ssh/appd-lab-team${TEAM_NUMBER}-key.pem"
fi

if [[ ! -f "$KEY_FILE" ]]; then
    log_error "SSH key not found: $KEY_FILE"
    echo "Create your SSH key first: ./scripts/create-ssh-key.sh --team $TEAM_NUMBER"
    exit 1
fi

log_info "Connecting to VM2: $VM2_IP"
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${VM2_IP}"
