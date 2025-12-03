#!/bin/bash
# Bootstrap VMs - Helper Script
# Usage: ./appd-bootstrap-vms.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Bootstrap AppDynamics VMs                              ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

This script helps you bootstrap all 3 VMs.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

What it does:
  1. Shows VM IPs and connection info
  2. Guides you through 'appdctl host init' on each VM
  3. Verifies bootstrap completed

Note: You'll need to SSH to each VM and run commands interactively.

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Bootstrap VMs for Team ${TEAM_NUMBER}                             ║
╚══════════════════════════════════════════════════════════╝

You need to bootstrap all 3 VMs before creating the cluster.

This process:
  1. Configures hostname
  2. Sets up networking
  3. Initializes storage
  4. Prepares Kubernetes

Each VM takes ~5 minutes to bootstrap.

EOF

# Get VM IPs
VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt" 2>/dev/null)
VM1_PRIV=$(cat "state/team${TEAM_NUMBER}/vm1-private-ip.txt" 2>/dev/null)
VM2_PUB=$(cat "state/team${TEAM_NUMBER}/vm2-public-ip.txt" 2>/dev/null)
VM2_PRIV=$(cat "state/team${TEAM_NUMBER}/vm2-private-ip.txt" 2>/dev/null)
VM3_PUB=$(cat "state/team${TEAM_NUMBER}/vm3-public-ip.txt" 2>/dev/null)
VM3_PRIV=$(cat "state/team${TEAM_NUMBER}/vm3-private-ip.txt" 2>/dev/null)

cat << EOF
📊 Your VMs:

VM1 (Primary):
  Public IP:  $VM1_PUB
  Private IP: $VM1_PRIV
  SSH:        ssh appduser@$VM1_PUB

VM2:
  Public IP:  $VM2_PUB
  Private IP: $VM2_PRIV
  SSH:        ssh appduser@$VM2_PUB

VM3:
  Public IP:  $VM3_PUB
  Private IP: $VM3_PRIV
  SSH:        ssh appduser@$VM3_PUB

Default credentials:
  Username: appduser
  Password: changeme

EOF

read -p "Press ENTER to start bootstrap process..."

# Bootstrap each VM
for i in 1 2 3; do
    clear
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Bootstrap VM${i}                                           ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM${i}
  ssh appduser@$(cat "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt")

Step 2: Run bootstrap command:
  sudo appdctl host init

Step 3: When prompted, enter:
  Hostname:   team${TEAM_NUMBER}-vm-${i}
  IP Address: $(cat "state/team${TEAM_NUMBER}/vm${i}-private-ip.txt")/24
  Gateway:    10.${TEAM_NUMBER}.0.1
  DNS:        10.${TEAM_NUMBER}.0.2

Step 4: Wait for bootstrap to complete (~5 minutes)

Step 5: Verify bootstrap:
  appdctl show boot
  
  All services should show "Succeeded"

Step 6: IMPORTANT - Change default password:
  passwd appduser
  
  Use a secure password and share with your team!

Step 7: Exit SSH session:
  exit

EOF

    read -p "Press ENTER when VM${i} bootstrap is complete..."
    
    # Verify bootstrap
    echo ""
    echo "Verifying VM${i} bootstrap..."
    VM_IP=$(cat "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt")
    
    ssh -o ConnectTimeout=5 appduser@$VM_IP "appdctl show boot" 2>/dev/null && {
        log_success "VM${i} bootstrap verified!"
    } || {
        log_warning "Could not verify VM${i} - check manually"
    }
    
    echo ""
done

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   ✅ All VMs Bootstrapped!                               ║
╚══════════════════════════════════════════════════════════╝

📊 Summary:
  VM1: team${TEAM_NUMBER}-vm-1 ($VM1_PRIV)
  VM2: team${TEAM_NUMBER}-vm-2 ($VM2_PRIV)
  VM3: team${TEAM_NUMBER}-vm-3 ($VM3_PRIV)

✅ All VMs should show:
  - Hostname configured
  - Network configured
  - Storage ready
  - Kubernetes initialized

📝 Next Step: Create Kubernetes Cluster
  ./appd-create-cluster.sh --team ${TEAM_NUMBER}

EOF

mark_step_complete "vms-bootstrapped" "$TEAM_NUMBER"
