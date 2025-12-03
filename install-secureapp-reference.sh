#!/bin/bash
# Install SecureApp on Current Reference Instance
# Quick script for instructor's reference cluster

set -e

VM1_IP="10.0.0.103"
VM1_PUBLIC="44.232.63.139"

cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║   Install SecureApp - Reference Cluster                 ║
╚══════════════════════════════════════════════════════════╝

This will install Cisco Secure Application on the reference cluster.

SecureApp provides:
  - Runtime application security
  - Vulnerability detection
  - Threat monitoring

Time: 10-15 minutes

EOF

read -p "Press ENTER to continue..."

echo ""
echo "Checking if SecureApp is already installed..."
ssh appduser@$VM1_PUBLIC "kubectl get pods -n cisco-secureapp 2>/dev/null" && {
    echo ""
    echo "✅ SecureApp pods found!"
    echo ""
    echo "Checking status..."
    ssh appduser@$VM1_PUBLIC "appdcli ping | grep -i secure"
    echo ""
    read -p "SecureApp already installed. Reinstall? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
} || {
    echo "SecureApp not found. Proceeding with installation..."
}

echo ""
echo "========================================="
echo "Installing SecureApp..."
echo "========================================="
echo ""

ssh appduser@$VM1_PUBLIC << 'ENDSSH'
echo "Verifying Controller is running..."
appdcli ping | grep Controller

echo ""
echo "Installing SecureApp (small profile)..."
appdcli start secapp small

echo ""
echo "Waiting for pods to start (this takes 5-10 minutes)..."
sleep 30

echo ""
echo "Checking pod status..."
kubectl get pods -n cisco-secureapp

echo ""
echo "Verifying service status..."
appdcli ping | grep -i secure

echo ""
echo "Installation complete!"
ENDSSH

echo ""
echo "========================================="
echo "✅ SecureApp Installation Complete!"
echo "========================================="
echo ""
echo "Verify installation:"
echo "  ssh appduser@$VM1_PUBLIC"
echo "  kubectl get pods -n cisco-secureapp"
echo "  appdcli ping"
echo ""
echo "Access SecureApp:"
echo "  https://controller.splunkylabs.com/controller/"
echo "  Navigate to: Applications → Security"
echo ""
