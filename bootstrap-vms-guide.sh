#!/usr/bin/env bash

# Bootstrap AppDynamics VA VMs
# This script guides you through bootstrapping all 3 VMs

source config.cfg

echo "========================================="
echo "AppDynamics VA - Bootstrap Guide"
echo "========================================="
echo ""
echo "This will guide you through bootstrapping all 3 VMs."
echo "You'll need to SSH to each VM and run commands manually."
echo ""
echo "Default SSH password: changeme"
echo ""

# VM details
echo "Your VMs:"
echo "  VM 1 (Primary): $NODE1_PUBLIC_IP (Private: $NODE1_IP)"
echo "  VM 2: $NODE2_PUBLIC_IP (Private: $NODE2_IP)"
echo "  VM 3: $NODE3_PUBLIC_IP (Private: $NODE3_IP)"
echo ""
echo "Gateway: 10.0.0.1"
echo "DNS: 8.8.8.8"
echo "Subnet: 10.0.0.0/24"
echo ""

# Function to bootstrap a single VM
bootstrap_vm() {
    local vm_name=$1
    local public_ip=$2
    local private_ip=$3
    local hostname=$4
    
    echo "========================================="
    echo "Bootstrap $vm_name"
    echo "========================================="
    echo ""
    echo "1. SSH to the VM:"
    echo "   ssh appduser@$public_ip"
    echo "   Password: changeme"
    echo ""
    echo "2. Run the bootstrap command:"
    echo "   sudo appdctl host init"
    echo ""
    echo "3. When prompted, enter these values:"
    echo "   Hostname: $hostname"
    echo "   Host IP address (CIDR): $private_ip/24"
    echo "   Default gateway: 10.0.0.1"
    echo "   DNS server: 8.8.8.8"
    echo ""
    echo "4. Wait for bootstrap to complete (2-3 minutes)"
    echo ""
    echo "5. Verify bootstrap succeeded:"
    echo "   appdctl show boot"
    echo ""
    echo "   All services should show 'Succeeded'"
    echo ""
    echo "6. Type 'exit' to disconnect"
    echo ""
    read -p "Press Enter when ready to see next VM instructions..."
    echo ""
}

# Bootstrap each VM
bootstrap_vm "VM 1 (Primary)" "$NODE1_PUBLIC_IP" "$NODE1_IP" "appdva-vm-1"
bootstrap_vm "VM 2" "$NODE2_PUBLIC_IP" "$NODE2_IP" "appdva-vm-2"
bootstrap_vm "VM 3" "$NODE3_PUBLIC_IP" "$NODE3_IP" "appdva-vm-3"

echo "========================================="
echo "All VMs Bootstrap Instructions Complete"
echo "========================================="
echo ""
echo "After bootstrapping all 3 VMs, verify:"
echo ""
echo "1. SSH to primary VM:"
echo "   ssh appduser@$NODE1_PUBLIC_IP"
echo ""
echo "2. Verify all services succeeded:"
echo "   appdctl show boot"
echo ""
echo "Expected output:"
echo "  NAME              | STATUS    | ERROR"
echo "  ------------------+-----------+------"
echo "  firewall-setup    | Succeeded | --"
echo "  hostname          | Succeeded | --"
echo "  netplan           | Succeeded | --"
echo "  ssh-setup         | Succeeded | --"
echo "  storage-setup     | Succeeded | --"
echo "  cert-setup        | Succeeded | --"
echo "  enable-time-sync  | Succeeded | --"
echo "  microk8s-setup    | Succeeded | --"
echo "  cloud-init-config | Succeeded | --"
echo ""
echo "If any service shows 'Failed', wait a few minutes and check again."
echo ""
echo "========================================="
echo "Next Step: Create Cluster"
echo "========================================="
echo ""
echo "Once all 3 VMs are bootstrapped, run:"
echo "  ./create-cluster.sh"
echo ""
