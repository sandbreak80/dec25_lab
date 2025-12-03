#!/usr/bin/env bash

# Bootstrap all 3 AppDynamics VA VMs
# This configures hostname, IP, gateway, and DNS on each node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source config.cfg

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "Bootstrap AppDynamics VA Nodes"
echo "========================================="
echo ""

# Configuration from config.cfg
NODES=(
    "${NODE1_PUBLIC_IP}:${NODE1_IP}:${VM_NAME_1}"
    "${NODE2_PUBLIC_IP}:${NODE2_IP}:${VM_NAME_2}"
    "${NODE3_PUBLIC_IP}:${NODE3_IP}:${VM_NAME_3}"
)

GATEWAY_IP="10.0.0.1"
DNS_SERVER="8.8.8.8"
CIDR_MASK="24"

echo "Configuration:"
echo "  Gateway: ${GATEWAY_IP}"
echo "  DNS: ${DNS_SERVER}"
echo "  CIDR Mask: /${CIDR_MASK}"
echo ""

# Function to bootstrap a node
bootstrap_node() {
    local public_ip=$1
    local private_ip=$2
    local hostname=$3
    local ip_cidr="${private_ip}/${CIDR_MASK}"
    
    echo -e "${BLUE}▶${NC} Bootstrapping ${hostname} (${public_ip})..."
    
    # Test SSH connectivity
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes appduser@${public_ip} "exit" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Cannot SSH to ${hostname} at ${public_ip}"
        echo "     Try: ssh-copy-id appduser@${public_ip}"
        echo "     Password: changeme"
        return 1
    fi
    
    # Create bootstrap script
    cat > /tmp/bootstrap-${hostname}.sh << EOF
#!/bin/bash
# Bootstrap script for ${hostname}

echo "Starting bootstrap for ${hostname}..."
echo "  Hostname: ${hostname}"
echo "  IP/CIDR: ${ip_cidr}"
echo "  Gateway: ${GATEWAY_IP}"
echo "  DNS: ${DNS_SERVER}"
echo ""

# Run appdctl host init with automated input
echo "${hostname}
${ip_cidr}
${GATEWAY_IP}
${DNS_SERVER}" | sudo appdctl host init

# Wait a moment for bootstrap to complete
sleep 5

# Show boot status
echo ""
echo "Bootstrap status:"
sudo appdctl show boot
EOF
    
    # Copy and execute bootstrap script
    scp -o ConnectTimeout=10 /tmp/bootstrap-${hostname}.sh appduser@${public_ip}:/tmp/ 2>/dev/null
    
    if ssh -o ConnectTimeout=30 appduser@${public_ip} "chmod +x /tmp/bootstrap-${hostname}.sh && /tmp/bootstrap-${hostname}.sh" 2>&1; then
        echo -e "  ${GREEN}✓${NC} Bootstrap completed for ${hostname}"
        return 0
    else
        echo -e "  ${RED}✗${NC} Bootstrap failed for ${hostname}"
        return 1
    fi
}

# Bootstrap all nodes
echo "Starting bootstrap process for all nodes..."
echo ""

SUCCESS_COUNT=0
FAILED_NODES=()

for node_info in "${NODES[@]}"; do
    IFS=':' read -r public_ip private_ip hostname <<< "$node_info"
    
    if bootstrap_node "$public_ip" "$private_ip" "$hostname"; then
        ((SUCCESS_COUNT++))
    else
        FAILED_NODES+=("$hostname")
    fi
    echo ""
done

# Summary
echo "========================================="
echo "Bootstrap Summary"
echo "========================================="
echo ""

if [ $SUCCESS_COUNT -eq 3 ]; then
    echo -e "${GREEN}✓${NC} All 3 nodes bootstrapped successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Wait 2-3 minutes for services to stabilize"
    echo "  2. Verify boot status: ssh appduser@${NODE1_PUBLIC_IP} 'appdctl show boot'"
    echo "  3. Create cluster: cd .. && ./post-deployment/02-create-cluster.sh"
    exit 0
else
    echo -e "${RED}✗${NC} Bootstrap failed on ${#FAILED_NODES[@]} node(s):"
    for node in "${FAILED_NODES[@]}"; do
        echo "  - $node"
    done
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check SSH access: ssh appduser@<node-ip>"
    echo "  2. Verify password: changeme"
    echo "  3. Check security group allows your IP"
    echo "  4. Try manual bootstrap on failed nodes"
    exit 1
fi
