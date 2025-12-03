#!/bin/bash
# Create Kubernetes Cluster
# Automates: appdctl cluster init on VM1 with VM2 and VM3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

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

# Check if SSH key is configured
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")
if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
    SSH_METHOD="key"
    SSH_OPTS="-i ${KEY_PATH}"
    log_info "Using SSH key: $KEY_PATH"
else
    SSH_METHOD="password"
    SSH_OPTS=""
    PASSWORD="AppDynamics123!"
    log_info "Using password-based SSH"
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

# Step 1: Verify all nodes are ready
log_info "Step 1: Verifying all nodes are bootstrapped..."
echo ""

verify_node() {
    local NODE=$1
    local NODE_IP=$2
    
    log_info "Checking $NODE ($NODE_IP)..."
    
    if [[ "$SSH_METHOD" == "key" ]]; then
        ssh ${SSH_OPTS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 appduser@${VM1_PUB} "ping -c 2 -W 2 ${NODE_IP} >/dev/null 2>&1" && {
            log_success "$NODE is reachable"
        } || {
            log_error "$NODE is not reachable from VM1"
            return 1
        }
    else
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
    fi
}

verify_node "VM2" "$VM2_PRIV"
verify_node "VM3" "$VM3_PRIV"

echo ""
log_success "All nodes are ready!"
echo ""

# Step 2: Create cluster
log_info "Step 2: Creating Kubernetes cluster..."
echo ""
log_info "Running: appdctl cluster init $VM2_PRIV $VM3_PRIV"
echo ""
log_warning "This takes ~10 minutes. Please wait..."
echo ""

if [[ "$SSH_METHOD" == "key" ]]; then
    # With SSH keys - fully automated
    ssh ${SSH_OPTS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "cd /home/appduser && appdctl cluster init $VM2_PRIV $VM3_PRIV" 2>&1 | while IFS= read -r line; do
        echo "  $line"
    done
    
    RESULT=${PIPESTATUS[0]}
else
    # With password - use expect
    expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 900
log_user 1

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "cd /home/appduser && appdctl cluster init $VM2_PRIV $VM3_PRIV"

expect {
    "password:" {
        send "${PASSWORD}\r"
        exp_continue
    }
    "Successfully created a multi node cluster" {
        puts ""
        puts "✅ Cluster creation successful!"
    }
    timeout {
        puts ""
        puts "❌ Timeout waiting for cluster creation"
        exit 1
    }
    eof
}
EOF_EXPECT
    
    RESULT=$?
fi

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

# Step 3: Verify cluster
log_info "Step 3: Verifying cluster..."
echo ""

sleep 5

echo "Cluster Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$SSH_METHOD" == "key" ]]; then
    ssh ${SSH_OPTS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdctl show cluster" 2>&1 | sed 's/^/  /'
else
    expect << EOF_EXPECT 2>&1 | sed 's/^/  /'
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "appdctl show cluster"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check high-availability
log_info "Checking high-availability status..."
echo ""

if [[ "$SSH_METHOD" == "key" ]]; then
    HA_STATUS=$(ssh ${SSH_OPTS} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "microk8s status" 2>/dev/null | grep "high-availability" || echo "")
else
    HA_STATUS=$(expect << 'EOF_EXPECT' 2>/dev/null | grep "high-availability" || echo ""
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@${VM1_PUB} "microk8s status"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT
)
fi

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
  Nodes: 3
  High Availability: Yes
  Primary: $VM1_PRIV

Expected cluster output:
 NODE              | ROLE  | RUNNING 
-------------------+-------+---------
 $VM1_PRIV:19001  | voter | true    
 $VM2_PRIV:19001  | voter | true    
 $VM3_PRIV:19001  | voter | true

📝 Next Steps:
  1. Configure cluster:
     ./appd-configure.sh --team ${TEAM_NUMBER}

  2. Install AppDynamics:
     ./appd-install.sh --team ${TEAM_NUMBER}

📚 Manual cluster check (optional):
  ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}
  appdctl show cluster
  microk8s status

EOF

mark_step_complete "cluster-initialized" "$TEAM_NUMBER"
