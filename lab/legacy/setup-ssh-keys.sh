#!/bin/bash
# Setup SSH key authentication for passwordless access

VM_IP="44.232.63.139"
VM_USER="appduser"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "🔑 Setup SSH Key Authentication"
echo "========================================="
echo ""
echo "This will enable passwordless SSH access to:"
echo "  ${VM_USER}@${VM_IP}"
echo ""

# Check if SSH key already exists
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "✅ SSH key already exists: ~/.ssh/id_rsa.pub"
else
    echo "Creating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "appd-lab-key"
    echo "✅ SSH key created"
fi

echo ""
echo "Copying SSH key to VM..."
echo "You'll need to enter the password ONE more time:"
echo ""

# Use ssh-copy-id to copy the key
ssh-copy-id -i ~/.ssh/id_rsa.pub ${VM_USER}@${VM_IP}

echo ""
echo "Testing passwordless SSH..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 ${VM_USER}@${VM_IP} "echo 'SSH key authentication working!'" 2>/dev/null; then
    echo "✅ SSH key authentication is working!"
    echo ""
    echo "You can now run scripts without entering passwords."
else
    echo "❌ SSH key authentication test failed"
    echo "You may need to manually copy the key:"
    echo "  cat ~/.ssh/id_rsa.pub | ssh ${VM_USER}@${VM_IP} 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'"
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
