#!/bin/bash

# Quick verification and next steps script
# Run this to verify everything is ready for cluster creation

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "Pre-Cluster Creation Verification"
echo "========================================="
echo ""

echo "1️⃣ Verifying globals.yaml.gotmpl configuration..."
expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo '=== DNS Domain ==='\r" }
expect "$ " { send "grep 'dnsDomain:' /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== DNS Names ==='\r" }
expect "$ " { send "grep -A 6 'dnsNames:' /var/appd/config/globals.yaml.gotmpl | head -8\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== External URLs ==='\r" }
expect "$ " { send "grep 'externalUrl:' /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '2️⃣ Testing DNS Resolution...'\r" }
expect "$ " { send "nslookup customer1.auth.splunkylabs.com | grep -A 2 'Name:'\r" }
expect "$ " { send "nslookup controller.splunkylabs.com | grep -A 2 'Name:'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '3️⃣ Checking all VMs are reachable...'\r" }
expect "$ " { send "ping -c 2 10.0.0.56 > /dev/null 2>&1 && echo '✅ VM2 (10.0.0.56) reachable' || echo '❌ VM2 unreachable'\r" }
expect "$ " { send "ping -c 2 10.0.0.177 > /dev/null 2>&1 && echo '✅ VM3 (10.0.0.177) reachable' || echo '❌ VM3 unreachable'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '========================================'\r" }
expect "$ " { send "echo 'Ready to create cluster!'\r" }
expect "$ " { send "echo '========================================'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo 'Next command:'\r" }
expect "$ " { send "echo 'appdctl cluster init 10.0.0.56 10.0.0.177'\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "✅ Verification Complete!"
echo "========================================="
echo ""
echo "If everything above looks good, you're ready to create the cluster!"
echo ""
echo "To proceed:"
echo "  1. SSH to VM1: ssh appduser@44.232.63.139"
echo "  2. Run: appdctl cluster init 10.0.0.56 10.0.0.177"
echo "  3. Enter password when prompted: FrMoJMZayxBj8@iU"
echo ""
