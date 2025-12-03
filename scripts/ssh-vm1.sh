#!/bin/bash
# SSH to VM1 using team SSH key
# Helper script for easy VM access

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  SSH to VM1 (Primary Node)                              ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--user USERNAME]

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --user, -u USERNAME  SSH user (default: appduser)
    --help, -h           Show this help

Examples:
    $0 --team 1
    $0 --team 1 --user appduser

EOF
    exit 1
}

TEAM_NUMBER=""
SSH_USER="ubuntu"  # AppDynamics VA AMI uses ubuntu as default SSH user

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

# Get VM1 IP
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null || echo "")

if [[ -z "$VM1_IP" ]] || [[ "$VM1_IP" == "None" ]]; then
    log_error "VM1 IP not found. Has the infrastructure been deployed?"
    echo ""
    echo "Deploy first:"
    echo "  ./lab-deploy.sh --team $TEAM_NUMBER"
    exit 1
fi

# Determine key file
if [[ -n "$VM_SSH_KEY" ]]; then
    KEY_FILE="${HOME}/.ssh/${VM_SSH_KEY}.pem"
else
    KEY_FILE="${HOME}/.ssh/appd-lab-team${TEAM_NUMBER}-key.pem"
fi

if [[ ! -f "$KEY_FILE" ]]; then
    log_error "SSH key not found: $KEY_FILE"
    echo ""
    echo "Create your SSH key first:"
    echo "  ./scripts/create-ssh-key.sh --team $TEAM_NUMBER"
    exit 1
fi

# SSH to VM1
log_info "Connecting to VM1: $VM1_IP"
log_info "User: $SSH_USER"
log_info "Key: $KEY_FILE"
echo ""

ssh -i "$KEY_FILE" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${VM1_IP}"
