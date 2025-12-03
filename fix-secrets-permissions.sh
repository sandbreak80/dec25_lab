#!/bin/bash

# Fix secrets.yaml permissions so appdcli can read it

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "Fix secrets.yaml Permissions"
echo "========================================="
echo ""

echo "🔧 Fixing permissions on VM1..."

expect << EOF
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "$ " { send "sudo chown root:root /var/appd/config/secrets.yaml\r" }
expect "password" { send "${VM_PASSWORD}\r" }
expect "$ " { send "sudo chmod 644 /var/appd/config/secrets.yaml\r" }
expect "$ " { send "ls -la /var/appd/config/secrets.yaml\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '✅ Permissions fixed. Ready to install:'\r" }
expect "$ " { send "echo 'appdcli start appd small'\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "✅ Done! Now run on VM1:"
echo "   appdcli start appd small"
echo ""
