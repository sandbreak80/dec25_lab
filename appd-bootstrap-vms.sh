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

# Check if SSH key is configured
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")
if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
    SSH_METHOD="key"
    log_info "Using SSH key: $KEY_PATH"
    export KEY_PATH  # For expect scripts
else
    SSH_METHOD="password"
    PASSWORD="AppDynamics123!"
    log_info "Using password-based SSH (password: $PASSWORD)"
fi

# Export password for expect scripts
PASSWORD="AppDynamics123!"
export PASSWORD

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

# Function to bootstrap a single VM (with SSH key)
bootstrap_vm_with_key() {
    local VM_NUM=$1
    local VM_IP=$2
    local VM_PRIVATE=$3
    
    # Export for expect
    export VM_IP
    
    log_info "[$VM_NUM/3] Bootstrapping VM${VM_NUM}: $VM_IP (using SSH key)"
    
    # Check if bootstrap already completed
    if ssh -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        appduser@${VM_IP} "appdctl show boot | grep -q 'Succeeded'" 2>/dev/null; then
        log_warning "VM${VM_NUM} already bootstrapped, skipping..."
        echo ""
        return 0
    fi
    
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

    # Copy bootstrap script
    scp -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        /tmp/bootstrap-vm${VM_NUM}.sh appduser@${VM_IP}:/tmp/bootstrap.sh > /dev/null 2>&1
    
    # Execute bootstrap with password sent via stdin to sudo -S
    ssh -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        appduser@${VM_IP} "chmod +x /tmp/bootstrap.sh && echo '${PASSWORD}' | sudo -S /tmp/bootstrap.sh" 2>&1 | sed 's/^/  /'
    
    BOOTSTRAP_STATUS=${PIPESTATUS[0]}
    
    # Clean up
    rm -f /tmp/bootstrap-vm${VM_NUM}.sh
    
    if [ $BOOTSTRAP_STATUS -eq 0 ]; then
        log_success "VM${VM_NUM} bootstrap complete!"
    else
        log_error "VM${VM_NUM} bootstrap FAILED!"
        exit 1
    fi
    echo ""
}

# Bootstrap all VMs based on SSH method
if [[ "$SSH_METHOD" == "key" ]]; then
    bootstrap_vm_with_key 1 "$VM1_IP" "$VM1_PRIVATE"
    bootstrap_vm_with_key 2 "$VM2_IP" "$VM2_PRIVATE"
    bootstrap_vm_with_key 3 "$VM3_IP" "$VM3_PRIVATE"
else
    bootstrap_vm_with_password 1 "$VM1_IP" "$VM1_PRIVATE"
    bootstrap_vm_with_password 2 "$VM2_IP" "$VM2_PRIVATE"
    bootstrap_vm_with_password 3 "$VM3_IP" "$VM3_PRIVATE"
fi

# CRITICAL: Copy VM1's SSH key to VM2/VM3 for cluster init
# appdctl cluster init needs VM1 to SSH to VM2/VM3
log_info "Setting up VM-to-VM SSH for cluster init..."
echo ""

# Get VM1's public key (generated during bootstrap)
log_info "Retrieving VM1's SSH public key..."
if [[ "$SSH_METHOD" == "key" ]]; then
    VM1_PUB_KEY=$(ssh -i "${KEY_PATH}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        appduser@${VM1_IP} "cat ~/.ssh/id_rsa.pub" 2>/dev/null)
else
    VM1_PUB_KEY=$(expect << EOF_EXPECT 2>/dev/null
set timeout 10
spawn ssh -o StrictHostKeyChecking=no appduser@${VM1_IP} "cat ~/.ssh/id_rsa.pub"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)
fi

if [[ -z "$VM1_PUB_KEY" ]]; then
    log_error "Failed to retrieve VM1's public key"
    exit 1
fi

log_success "VM1 public key retrieved"

# Function to safely add key to authorized_keys (idempotent)
install_key_safely() {
    local TARGET_IP=$1
    local TARGET_NAME=$2
    
    log_info "Installing VM1's key on ${TARGET_NAME}..."
    
    if [[ "$SSH_METHOD" == "key" ]]; then
        # Use a safe script that checks if key exists before adding
        ssh -i "${KEY_PATH}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            appduser@${TARGET_IP} "
                # Ensure .ssh directory exists with correct permissions
                mkdir -p ~/.ssh
                chmod 700 ~/.ssh
                
                # Check if key already exists
                if grep -q \"${VM1_PUB_KEY}\" ~/.ssh/authorized_keys 2>/dev/null; then
                    echo 'Key already present'
                else
                    # Add key safely
                    echo '${VM1_PUB_KEY}' >> ~/.ssh/authorized_keys
                    chmod 600 ~/.ssh/authorized_keys
                    echo 'Key added'
                fi
            " 2>&1 | sed 's/^/    /'
    else
        expect << EOF_EXPECT 2>&1 | sed 's/^/    /'
set timeout 10
spawn ssh -o StrictHostKeyChecking=no appduser@${TARGET_IP} "
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    if grep -q \\\"${VM1_PUB_KEY}\\\" ~/.ssh/authorized_keys 2>/dev/null; then
        echo 'Key already present'
    else
        echo '${VM1_PUB_KEY}' >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo 'Key added'
    fi
"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
    fi
    
    log_success "${TARGET_NAME}: VM1 key installed"
}

# Install VM1's key on VM2 and VM3
install_key_safely "$VM2_IP" "VM2"
install_key_safely "$VM3_IP" "VM3"

echo ""
log_success "VM1 can now SSH to VM2/VM3 (required for cluster init)"
echo ""

# Final verification
log_info "Running final verification on all VMs..."
echo ""

for i in 1 2 3; do
    VM_IP_VAR="VM${i}_IP"
    VM_IP="${!VM_IP_VAR}"
    
    echo "VM${i} Status:"
    if [[ "$SSH_METHOD" == "key" ]]; then
        ssh -i "${KEY_PATH}" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            appduser@${VM_IP} "appdctl show boot" 2>&1 | sed 's/^/  /'
    else
        expect << EOF_EXPECT
set timeout 10
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM_IP} "appdctl show boot"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
    fi
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
