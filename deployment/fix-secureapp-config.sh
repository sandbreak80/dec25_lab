#!/bin/bash
# Fix SecureApp Configuration and Reinstall
# This fixes the Controller endpoint so SecureApp can reach it from inside the cluster

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Fix SecureApp Controller Connectivity                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "This will:"
echo "  1. Stop SecureApp services"
echo "  2. Backup globals.yaml.gotmpl"
echo "  3. Update configuration to use internal Controller endpoint"
echo "  4. Reinstall SecureApp"
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "=== Step 1: Stopping SecureApp ==="
appdcli stop secapp
echo "Waiting for pods to terminate..."
sleep 30

echo ""
echo "=== Step 2: Backing up configuration ==="
cd /var/appd/config
cp globals.yaml.gotmpl globals.yaml.gotmpl.backup-$(date +%Y%m%d-%H%M%S)
echo "✅ Backup created"

echo ""
echo "=== Step 3: Updating configuration ==="
echo "Enabling hybrid mode to specify internal Controller endpoint..."

# Update the hybrid section to use internal service
sed -i 's/^  enable: false/  enable: true/' globals.yaml.gotmpl
sed -i 's/domainName: controller.nip.io/domainName: controller-service.cisco-controller.svc/' globals.yaml.gotmpl
sed -i 's/sslEnabled: true/sslEnabled: false/' globals.yaml.gotmpl

echo ""
echo "Updated configuration:"
grep -A6 'hybrid:' globals.yaml.gotmpl

echo ""
echo "=== Step 4: Reinstalling SecureApp ==="
read -p "Install with which profile? (small/medium/large) [small]: " PROFILE
PROFILE=${PROFILE:-small}

echo "Installing SecureApp with profile: $PROFILE"
appdcli start secapp $PROFILE

echo ""
echo "=== Step 5: Waiting for pods to start (5 minutes) ==="
sleep 300

echo ""
echo "=== Step 6: Checking SecureApp status ==="
kubectl get pods -n cisco-secureapp

echo ""
echo "=== Step 7: Testing SecureApp API ==="
appdcli run secureapp checkApi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Configuration Update Complete                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "If API check passed, you can now:"
echo "  1. Upload feeds:"
echo "     appdcli run secureapp uploadFeed /home/appduser/secapp_data_25.12.18.1765984004.dat"
echo ""
echo "  2. Check health:"
echo "     appdcli run secureapp health"
echo ""
echo "Backup saved at:"
echo "  $(ls -1 /var/appd/config/globals.yaml.gotmpl.backup-* | tail -1)"


