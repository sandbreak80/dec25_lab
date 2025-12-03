#!/bin/bash
# Bootstrap AppDynamics Virtual Appliance VMs
# This must be run AFTER infrastructure deployment
# Runs: sudo appdctl host init on each VM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Bootstrap AppDynamics Virtual Appliance VMs            ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    --help, -h           Show this help

Example:
    $0 --team 1

This script will:
  1. ✓ SSH to each VM as ubuntu user
  2. ✓ Run 'sudo appdctl host init' to bootstrap the node
  3. ✓ Configure hostname, network, storage, firewall, SSH
  4. ✓ Verify bootstrap with 'appdctl show boot'

Prerequisites:
  • VMs must be deployed (./lab-deploy.sh)
  • SSH keys must be configured
  • VMs must be accessible via SSH

Note: This is required before creating the AppDynamics cluster!

EOF
    exit 1
}

TEAM_NUMBER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
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

# Note: We use sshpass for password-based SSH automation
# Students will use their team password (set by appd-change-password.sh)

log_info "Bootstrapping AppDynamics VMs for Team ${TEAM_NUMBER}..."
echo ""

# Get VM IPs
VM1_IP=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
VM2_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null)
VM3_IP=$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt" 2>/dev/null)

VM1_PRIVATE=$(cat "state/team${TEAM_NUMBER}/vm1-private-ip.txt" 2>/dev/null)
VM2_PRIVATE=$(cat "state/team${TEAM_NUMBER}/vm2-private-ip.txt" 2>/dev/null)
VM3_PRIVATE=$(cat "state/team${TEAM_NUMBER}/vm3-private-ip.txt" 2>/dev/null)

if [[ -z "$VM1_IP" ]] || [[ -z "$VM2_IP" ]] || [[ -z "$VM3_IP" ]]; then
    log_error "VM IPs not found. Has infrastructure been deployed?"
    exit 1
fi

# Function to bootstrap a single VM
bootstrap_vm() {
    local VM_NUM=$1
    local VM_IP=$2
    local VM_PRIVATE=$3
    
    log_info "[$VM_NUM/3] Bootstrapping VM${VM_NUM}: $VM_IP"
    
    # Create bootstrap script
    cat > /tmp/bootstrap-vm${VM_NUM}.sh << 'BOOTSTRAP_EOF'
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AppDynamics VA Bootstrap - VM${VM_NUM}                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Starting AppDynamics host bootstrap..."
echo "Default appduser password: changeme"
echo ""

# Get network details from current config
HOSTNAME=$(hostname)
HOST_IP=$(ip addr show $(ip route | grep default | awk '{print $5}') | grep 'inet ' | awk '{print $2}')
GATEWAY=$(ip route | grep default | awk '{print $3}')
DNS_SERVER=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')

echo "Network Configuration (auto-detected):"
echo "  Hostname: $HOSTNAME"
echo "  Host IP: $HOST_IP"
echo "  Gateway: $GATEWAY"
echo "  DNS: $DNS_SERVER"
echo ""

# Run appdctl host init as ubuntu (will use sudo)
# Note: appduser exists but we're running as ubuntu with sudo
echo "Running: sudo appdctl host init"
echo "  (Logging in as appduser and running host init)"
echo ""

# Run the bootstrap command
sudo appdctl host init <<EOF_INIT
$HOSTNAME
$HOST_IP
$GATEWAY
$DNS_SERVER
EOF_INIT

BOOTSTRAP_STATUS=$?

if [ $BOOTSTRAP_STATUS -eq 0 ]; then
    echo ""
    echo "✅ Bootstrap command completed!"
    echo ""
    echo "Waiting 10 seconds for services to initialize..."
    sleep 10
    
    echo ""
    echo "Verifying bootstrap status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sudo -u appduser appdctl show boot || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ VM bootstrap successful!"
else
    echo ""
    echo "❌ Bootstrap command failed with exit code: $BOOTSTRAP_STATUS"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if appduser exists: id appduser"
    echo "  2. Try running manually:"
    echo "     sudo su - appduser"
    echo "     sudo appdctl host init"
    exit 1
fi
BOOTSTRAP_EOF

    # Copy and execute bootstrap script (using password auth)
    # Use expect for password automation
    expect << EOF_EXPECT
set timeout 30
spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /tmp/bootstrap-vm${VM_NUM}.sh appduser@${VM_IP}:/tmp/bootstrap.sh
expect {
    "password:" { send "AppDynamics123!\r"; exp_continue }
    eof
}

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM_IP} "chmod +x /tmp/bootstrap.sh && sudo /tmp/bootstrap.sh"
expect {
    "password:" { send "AppDynamics123!\r"; exp_continue }
    eof
}
EOF_EXPECT
    
    # Clean up
    rm -f /tmp/bootstrap-vm${VM_NUM}.sh
    
    log_success "VM${VM_NUM} bootstrap complete!"
    echo ""
}

# Bootstrap all VMs
bootstrap_vm 1 "$VM1_IP" "$VM1_PRIVATE"
bootstrap_vm 2 "$VM2_IP" "$VM2_PRIVATE"
bootstrap_vm 3 "$VM3_IP" "$VM3_PRIVATE"

# Final verification
log_info "Running final verification on all VMs..."
echo ""

for i in 1 2 3; do
    VM_IP_VAR="VM${i}_IP"
    VM_IP="${!VM_IP_VAR}"
    
    echo "VM${i} Status:"
    expect << EOF_EXPECT
set timeout 10
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM_IP} "appdctl show boot"
expect {
    "password:" { send "AppDynamics123!\r"; exp_continue }
    eof
}
EOF_EXPECT
    echo ""
done

log_success "All VMs bootstrapped successfully!"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Bootstrap Complete!                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "  1. Create AppDynamics cluster:"
echo "     ./appd-create-cluster.sh --team $TEAM_NUMBER"
echo ""
echo "  2. Configure cluster:"
echo "     ./appd-configure.sh --team $TEAM_NUMBER"
echo ""
echo "  3. Install AppDynamics services:"
echo "     ./appd-install.sh --team $TEAM_NUMBER"
echo ""
