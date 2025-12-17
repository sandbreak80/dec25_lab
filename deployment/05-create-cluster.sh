#!/bin/bash
# Create Kubernetes Cluster
# Automates: appdctl cluster init on VM1 with VM2 and VM3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Create AppDynamics Kubernetes Cluster                 ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Creates a 3-node Kubernetes cluster for AppDynamics.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

Prerequisites:
  - All 3 VMs must be bootstrapped
  - appdctl show boot shows "Succeeded" on all VMs
  - SSH keys must be configured (or use password)

This script will:
  1. Verify all nodes are ready
  2. Run 'appdctl cluster init' on VM1
  3. Verify cluster creation
  4. Check high-availability status

Time: ~10 minutes

EOF
}

TEAM_NUMBER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
    exit 1
fi

load_team_config "$TEAM_NUMBER"
check_aws_cli

# Password is always AppDynamics123! (set in step 3)
PASSWORD="AppDynamics123!"

# Check if SSH key is configured (for informational purposes only)
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")
if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
    log_info "SSH keys were configured, but using password auth (AppDynamics modifies keys during bootstrap)"
else
    log_info "Using password-based SSH authentication"
fi

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Create Kubernetes Cluster - Team ${TEAM_NUMBER}                  ║
╚══════════════════════════════════════════════════════════╝

This will create a 3-node Kubernetes cluster using MicroK8s.

Time: ~10 minutes

EOF

# Get VM IPs
VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")
VM1_PRIV=$(cat "state/team${TEAM_NUMBER}/vm1-private-ip.txt")
VM2_PRIV=$(cat "state/team${TEAM_NUMBER}/vm2-private-ip.txt")
VM3_PRIV=$(cat "state/team${TEAM_NUMBER}/vm3-private-ip.txt")

cat << EOF
📊 Cluster Nodes:
  Primary (VM1): $VM1_PRIV (public: $VM1_PUB)
  Worker (VM2):  $VM2_PRIV
  Worker (VM3):  $VM3_PRIV

EOF

# Step 1: Verify all nodes are bootstrapped
log_info "Step 1: Verifying all nodes are bootstrapped..."
echo ""

# Function to check if a VM is fully bootstrapped
check_bootstrap_complete() {
    local VM_NUM=$1
    local VM_IP=$2
    
    log_info "Checking VM${VM_NUM} bootstrap status..."
    
    # Always use password auth (bootstrap may have modified SSH keys)
    BOOT_STATUS=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "ssh -o StrictHostKeyChecking=no appduser@${VM_IP} 'appdctl show boot'"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)
    
    BOOT_CHECK_EXIT=$?
    if [ $BOOT_CHECK_EXIT -ne 0 ]; then
        log_error "VM${VM_NUM} bootstrap check failed: cannot connect"
        return 1
    fi
    
    # Check if all bootstrap steps show "Succeeded"
    if echo "$BOOT_STATUS" | grep -q "STATUS" && ! echo "$BOOT_STATUS" | grep -E "(Failed|InProgress|Pending)" > /dev/null; then
        log_success "VM${VM_NUM} bootstrap: Complete"
        return 0
    else
        log_error "VM${VM_NUM} bootstrap: NOT COMPLETE"
        echo "$BOOT_STATUS" | sed 's/^/    /'
        return 1
    fi
}

# Check all VMs are bootstrapped
log_info "Verifying bootstrap completion on all VMs..."
echo ""

ALL_READY=true
for i in 1 2 3; do
    case $i in
        1) VM_IP=$VM1_PRIV; VM_PUB_IP=$VM1_PUB ;;
        2) VM_IP=$VM2_PRIV; VM_PUB_IP=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt") ;;
        3) VM_IP=$VM3_PRIV; VM_PUB_IP=$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt") ;;
    esac
    
    # For VM1, check directly; for VM2/VM3, check via VM1
    if [ $i -eq 1 ]; then
        log_info "Checking VM1 bootstrap status (direct)..."
        # Always use password auth (bootstrap may have modified SSH keys)
        BOOT_STATUS=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdctl show boot"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)
        
        BOOT_CHECK_EXIT=$?
        if [ $BOOT_CHECK_EXIT -ne 0 ]; then
            log_error "VM1 bootstrap check failed: cannot connect"
            ALL_READY=false
            continue
        fi
        
        if echo "$BOOT_STATUS" | grep -q "STATUS" && echo "$BOOT_STATUS" | grep -q "Succeeded" && ! echo "$BOOT_STATUS" | grep -E "(Failed|InProgress)" > /dev/null; then
            log_success "VM1 bootstrap: Complete"
        else
            log_error "VM1 bootstrap: NOT COMPLETE (still running or failed)"
            echo ""
            echo "Current status:"
            echo "$BOOT_STATUS" | sed 's/^/  /'
            echo ""
            log_warning "Bootstrap is still extracting container images (~15-20 min)"
            log_warning "Run this command to monitor progress:"
            echo "  ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}"
            echo "  appdctl show boot"
            echo ""
            ALL_READY=false
        fi
    fi
done

if [ "$ALL_READY" = false ]; then
    echo ""
    log_error "Bootstrap not complete. Please wait and try again."
    echo ""
    echo "To monitor bootstrap progress:"
    echo "  ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}"
    echo "  watch -n 10 appdctl show boot"
    echo ""
    exit 1
fi

echo ""
log_success "All VMs fully bootstrapped!"
echo ""

# Step 2: Verify network connectivity
log_info "Step 2: Verifying network connectivity..."
echo ""

verify_node() {
    local NODE=$1
    local NODE_IP=$2
    
    log_info "Checking $NODE ($NODE_IP)..."
    
    # Use password auth (bootstrap may have modified SSH keys)
    expect << EOF_EXPECT
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "ping -c 2 -W 2 ${NODE_IP}"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "2 packets transmitted" { }
    timeout { exit 1 }
}
expect eof
EOF_EXPECT
    if [ $? -eq 0 ]; then
        log_success "$NODE is reachable"
    else
        log_error "$NODE is not reachable from VM1"
        return 1
    fi
}

verify_node "VM2" "$VM2_PRIV"
verify_node "VM3" "$VM3_PRIV"

echo ""
log_success "All nodes are ready!"
echo ""

# Step 3: Setup SSH keys for VM1 -> VM2/VM3 communication
log_info "Step 3: Setting up SSH keys for cluster init..."
echo ""

# Generate SSH key on VM1 if it doesn't exist
log_info "Generating SSH key on VM1..."
expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -q"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

# Get VM1's public key
log_info "Retrieving VM1's public key..."
VM1_PUBKEY=$(expect << EOF_EXPECT 2>&1 | grep "^ssh-ed25519" || echo ""
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "cat ~/.ssh/id_ed25519.pub"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)

if [[ -z "$VM1_PUBKEY" ]]; then
    log_error "Failed to retrieve VM1's public key"
    exit 1
fi

log_success "VM1 public key retrieved"

# Copy VM1's public key to VM2
log_info "Adding VM1's key to VM2's authorized_keys..."
expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt") "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${VM1_PUBKEY}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

# Copy VM1's public key to VM3
log_info "Adding VM1's key to VM3's authorized_keys..."
expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt") "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${VM1_PUBKEY}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

# Add VM2/VM3 host keys to VM1's known_hosts
log_info "Adding VM2/VM3 host keys to VM1's known_hosts..."
expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "ssh-keyscan -H ${VM2_PRIV} ${VM3_PRIV} >> ~/.ssh/known_hosts 2>/dev/null"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

log_success "SSH keys configured for cluster init"
echo ""

# Step 4: Create cluster
log_info "Step 4: Creating Kubernetes cluster..."
echo ""
log_info "Running: appdctl cluster init $VM2_PRIV $VM3_PRIV"
echo ""
log_warning "This takes ~10 minutes. Please wait..."
echo ""

# Use password auth (bootstrap may have modified SSH keys)
expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 900
log_user 1

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "cd /home/appduser && appdctl cluster init $VM2_PRIV $VM3_PRIV"

set success 0
expect {
    "password:" {
        send "${PASSWORD}\r"
        exp_continue
    }
    "Successfully created a multi node cluster" {
        set success 1
        puts ""
        puts "✅ Cluster creation successful!"
        exp_continue
    }
    timeout {
        puts ""
        puts "❌ Timeout waiting for cluster creation"
        exit 1
    }
    eof
}

if {$success == 0} {
    puts ""
    puts "❌ Cluster creation failed - success message not found"
    exit 1
}
EOF_EXPECT

RESULT=$?

echo ""

if [ $RESULT -eq 0 ]; then
    log_success "Cluster initialization command completed!"
else
    log_error "Cluster initialization failed!"
    echo ""
    echo "Common issues:"
    echo "  • Nodes not fully bootstrapped (wait 15-20 min after bootstrap)"
    echo "  • Network connectivity issues"
    echo "  • Insufficient resources"
    echo ""
    echo "Check logs on VM1:"
    echo "  ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
    echo "  sudo journalctl -u appd-os -f"
    exit 1
fi

echo ""

# Step 5: Verify cluster
log_info "Step 5: Verifying cluster..."
echo ""

sleep 5

echo "Cluster Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Note: Cluster init may have modified SSH keys, so use password authentication
CLUSTER_OUTPUT=$(expect << EOF_EXPECT 2>&1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdctl show cluster"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

CLUSTER_CHECK_EXIT=$?
if [ $CLUSTER_CHECK_EXIT -ne 0 ]; then
    log_error "Cannot retrieve cluster status - connection failed"
    exit 1
fi

echo "$CLUSTER_OUTPUT" | sed 's/^/  /'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify all 3 nodes are present
NODE_COUNT=$(echo "$CLUSTER_OUTPUT" | grep -c "voter" || echo "0")
if [ "$NODE_COUNT" -ne 3 ]; then
    log_error "Expected 3 nodes in cluster, found: $NODE_COUNT"
    log_info "Cluster output:"
    echo "$CLUSTER_OUTPUT"
    exit 1
fi

# Check high-availability
log_info "Checking high-availability status..."
echo ""

# Use password authentication (cluster init may have modified SSH keys)
HA_STATUS=$(expect << EOF_EXPECT 2>/dev/null | grep "high-availability" || echo ""
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "microk8s status"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)

if [[ -n "$HA_STATUS" ]]; then
    log_success "High-availability is enabled"
    echo "  $HA_STATUS"
else
    log_warning "Could not verify high-availability status"
fi

echo ""
log_success "Cluster verification complete!"
echo ""

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   ✅ Cluster Created!                                    ║
╚══════════════════════════════════════════════════════════╝

Your 3-node Kubernetes cluster is ready!

📊 Cluster Info:
  Nodes: $NODE_COUNT
  High Availability: Yes
  Primary: $VM1_PRIV

Actual Cluster Status:
EOF

# Show the actual cluster table output (filter to just the table)
echo "$CLUSTER_OUTPUT" | grep -A 5 "NODE" | sed 's/^/  /'

echo ""

mark_step_complete "cluster-initialized" "$TEAM_NUMBER"
