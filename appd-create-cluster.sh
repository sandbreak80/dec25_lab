#!/bin/bash
# Create Kubernetes Cluster
# Usage: ./appd-create-cluster.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Create Kubernetes Cluster                             ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER

Creates a 3-node Kubernetes cluster for AppDynamics.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

Prerequisites:
  - All 3 VMs must be bootstrapped
  - appdctl show boot shows "Succeeded" on all VMs

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

clear
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
  Primary (VM1): $VM1_PRIV
  Worker (VM2):  $VM2_PRIV
  Worker (VM3):  $VM3_PRIV

EOF

read -p "Press ENTER to continue..."

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   Instructions                                           ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM1 (primary node)
  ssh appduser@$VM1_PUB

Step 2: Verify all nodes bootstrapped
  # On VM1, check each node can be reached:
  ping -c 2 $VM2_PRIV
  ping -c 2 $VM3_PRIV

Step 3: Create cluster
  cd /home/appduser
  appdctl cluster init $VM2_PRIV $VM3_PRIV

  You'll be prompted for the password for VM2 and VM3.
  Enter the password you set during bootstrap.

Step 4: Wait for cluster creation (~10 minutes)
  The command will:
  - Configure Kubernetes on all nodes
  - Set up high-availability
  - Label nodes
  - Configure networking

Step 5: Verify cluster
  appdctl show cluster
  
  Expected output:
   NODE              | ROLE  | RUNNING 
  -------------------+-------+---------
   $VM1_PRIV:19001  | voter | true    
   $VM2_PRIV:19001  | voter | true    
   $VM3_PRIV:19001  | voter | true

  microk8s status
  
  Should show: "high-availability: yes"

Step 6: Exit SSH
  exit

EOF

read -p "Press ENTER when cluster creation is complete..."

echo ""
echo "Verifying cluster..."
ssh -o ConnectTimeout=10 appduser@$VM1_PUB "appdctl show cluster" 2>/dev/null && {
    log_success "Cluster verified!"
} || {
    log_warning "Could not verify cluster - check manually"
}

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   ✅ Cluster Created!                                    ║
╚══════════════════════════════════════════════════════════╝

Your 3-node Kubernetes cluster is ready!

📊 Cluster Info:
  Nodes: 3
  High Availability: Yes
  Primary: $VM1_PRIV

📝 Next Step: Configure AppDynamics
  ./appd-configure.sh --team ${TEAM_NUMBER}

EOF

mark_step_complete "cluster-initialized" "$TEAM_NUMBER"
