#!/bin/bash
# Change appduser password on all VMs
# Must be run BEFORE bootstrap

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Change appduser Password on VMs                        ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--password NEW_PASSWORD]

Arguments:
    --team, -t NUMBER       Your team number (1-5)
    --password, -p PASSWORD New password (default: AppDynamics123!)
    --help, -h              Show this help

Examples:
    $0 --team 1
    $0 --team 1 --password MySecurePass123!

This script will:
  1. ✓ SSH to each VM as ubuntu
  2. ✓ Change appduser password (bypass forced change prompt)
  3. ✓ Verify password was changed

Note: This must be run BEFORE appd-bootstrap-vms.sh!

EOF
    exit 1
}

TEAM_NUMBER=""
NEW_PASSWORD="AppDynamics123!"

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --password|-p) NEW_PASSWORD="$2"; shift 2 ;;
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

# Check SSH key exists
if [[ -z "$VM_SSH_KEY" ]]; then
    VM_SSH_KEY="appd-lab-team${TEAM_NUMBER}-key"
fi

KEY_FILE="${HOME}/.ssh/${VM_SSH_KEY}.pem"
if [[ ! -f "$KEY_FILE" ]]; then
    log_error "SSH key not found: $KEY_FILE"
    exit 1
fi

log_info "Changing appduser password on Team ${TEAM_NUMBER} VMs..."
echo ""
log_warning "New password: $NEW_PASSWORD"
echo ""

# Get VM IPs
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
VM2_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null)
VM3_IP=$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt" 2>/dev/null)

if [[ -z "$VM1_IP" ]] || [[ -z "$VM2_IP" ]] || [[ -z "$VM3_IP" ]]; then
    log_error "VM IPs not found. Has infrastructure been deployed?"
    exit 1
fi

# Function to change password on a VM
change_password() {
    local VM_NUM=$1
    local VM_IP=$2
    
    log_info "[$VM_NUM/3] Changing password on VM${VM_NUM}: $VM_IP"
    
    # Change password using chpasswd (bypasses interactive prompt)
    ssh -i "$KEY_FILE" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ubuntu@${VM_IP} "echo 'appduser:${NEW_PASSWORD}' | sudo chpasswd && sudo chage -d 0 appduser && echo '✅ Password changed successfully'" 2>&1 | sed 's/^/    /'
    
    if [ $? -eq 0 ]; then
        log_success "VM${VM_NUM} password changed!"
    else
        log_error "Failed to change password on VM${VM_NUM}"
        exit 1
    fi
    echo ""
}

# Change password on all VMs
change_password 1 "$VM1_IP"
change_password 2 "$VM2_IP"
change_password 3 "$VM3_IP"

log_success "All VM passwords changed successfully!"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Password Change Complete!                              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "New appduser password: $NEW_PASSWORD"
echo ""
echo "Next Steps:"
echo "  1. Bootstrap VMs:"
echo "     ./appd-bootstrap-vms.sh --team $TEAM_NUMBER"
echo ""
echo "  2. Create cluster:"
echo "     ./appd-create-cluster.sh --team $TEAM_NUMBER"
echo ""
echo "Important: Save this password! You'll need it for SSH access:"
echo "  ssh ubuntu@<VM-IP>"
echo "  sudo su - appduser"
echo "  (password: $NEW_PASSWORD)"
echo ""
