#!/usr/bin/env bash

# Change password on all VMs

echo "========================================="
echo "Change Password on All VMs"
echo "========================================="
echo ""
echo "New password: FrMoJMZayxBj8@iU"
echo ""
echo "You'll need to SSH to each VM and change the password"
echo "Default password is: changeme"
echo ""

VMS=(
    "44.232.63.139:VM-1"
    "54.244.130.46:VM-2"
    "52.39.239.130:VM-3"
)

for vm_info in "${VMS[@]}"; do
    ip="${vm_info%%:*}"
    name="${vm_info##*:}"
    
    echo "========================================="
    echo "Change password on $name ($ip)"
    echo "========================================="
    echo ""
    echo "1. SSH to VM:"
    echo "   ssh appduser@$ip"
    echo "   Current password: changeme"
    echo ""
    echo "2. Change password:"
    echo "   passwd"
    echo "   Enter current password: changeme"
    echo "   Enter new password: FrMoJMZayxBj8@iU"
    echo "   Confirm new password: FrMoJMZayxBj8@iU"
    echo ""
    echo "3. Type 'exit' to disconnect"
    echo ""
    read -p "Press Enter when done with $name..."
    echo ""
done

echo "========================================="
echo "✅ Password Change Complete"
echo "========================================="
echo ""
echo "New password for all VMs: FrMoJMZayxBj8@iU"
echo ""
echo "⚠️  IMPORTANT: Store this password securely!"
echo ""
echo "Next: Bootstrap the VMs"
echo "  ./bootstrap-vms-guide.sh"
echo ""
