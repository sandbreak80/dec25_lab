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
SSH_USER="appduser"  # AppDynamics VA default user

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

VM2_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null || echo "")

if [[ -z "$VM2_IP" ]] || [[ "$VM2_IP" == "None" ]]; then
    log_error "VM2 IP not found. Has the infrastructure been deployed?"
    exit 1
fi

# Check if SSH key is configured
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")

if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
    # SSH with key (passwordless)
    log_info "Connecting to VM2: $VM2_IP"
    log_info "User: $SSH_USER"
    log_success "Using SSH key: $KEY_PATH"
    echo ""
    
    ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${VM2_IP}"
else
    # SSH with password
    log_info "Connecting to VM2: $VM2_IP"
    log_info "User: $SSH_USER"
    log_warning "Password: AppDynamics123! (or your team password)"
    echo ""
    echo "💡 Tip: Run './scripts/setup-ssh-keys.sh --team ${TEAM_NUMBER}' for passwordless access!"
    echo ""
    
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${VM2_IP}"
fi
