#!/bin/bash

# Upload the updated globals.yaml.gotmpl to VM1
# This script uses expect to handle password prompts

VM_PASSWORD="FrMoJMZayxBj8@iU"
VM_IP="44.232.63.139"

echo "========================================="
echo "Upload Updated Configuration to VM1"
echo "========================================="
echo ""

# Check if updated file exists
if [ ! -f "globals.yaml.gotmpl.updated" ]; then
    echo "❌ Error: globals.yaml.gotmpl.updated not found!"
    echo "Please ensure the file exists in the current directory."
    exit 1
fi

echo "📤 Uploading globals.yaml.gotmpl.updated to VM1..."

    # Upload the file
    expect << EOF
spawn scp globals.yaml.gotmpl.updated appduser@${VM_IP}:/tmp/globals.yaml.gotmpl
expect {
    "password:" { send "${VM_PASSWORD}\r"; exp_continue }
    eof
}
EOF

if [ $? -eq 0 ]; then
    echo "✅ File uploaded to /tmp/globals.yaml.gotmpl"
    echo ""
    echo "📋 Now backing up original and moving updated file into place..."
    
    # SSH in and move the file
    expect << EOF
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "$ " { send "sudo cp /var/appd/config/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl.backup\r" }
expect "password" { send "${VM_PASSWORD}\r" }
expect "$ " { send "sudo mv /tmp/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "sudo chown root:root /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "sudo chmod 644 /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "echo 'Verifying configuration...'\r" }
expect "$ " { send "grep 'dnsDomain:' /var/appd/config/globals.yaml.gotmpl\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

    echo ""
    echo "✅ Configuration updated successfully!"
    echo ""
    echo "📝 What was changed:"
    echo "  • dnsDomain: splunkylabs.com"
    echo "  • Added DNS names for auth and controller"
    echo "  • Updated EUM external URL"
    echo "  • Updated Events external URL"
    echo "  • Updated AIOps external URL"
    echo "  • Commented out nip.io entries (using real DNS)"
    echo ""
    echo "🔐 Original backed up to: /var/appd/config/globals.yaml.gotmpl.backup"
    echo ""
else
    echo "❌ Failed to upload file"
    exit 1
fi
