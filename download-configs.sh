#!/bin/bash

VM_PASSWORD="FrMoJMZayxBj8@iU"
VM_IP="44.232.63.139"

echo "Downloading configuration files from VM1..."

# Download globals.yaml.gotmpl
expect << EOF
spawn scp appduser@${VM_IP}:/var/appd/config/globals.yaml.gotmpl ./globals.yaml.gotmpl.original
expect {
    "password:" { send "${VM_PASSWORD}\r"; exp_continue }
    eof
}
EOF

# Download secrets.yaml
expect << EOF
spawn scp appduser@${VM_IP}:/var/appd/config/secrets.yaml ./secrets.yaml.original
expect {
    "password:" { send "${VM_PASSWORD}\r"; exp_continue }
    eof
}
EOF

if [ -f "globals.yaml.gotmpl.original" ]; then
    echo "✅ Downloaded globals.yaml.gotmpl.original"
else
    echo "❌ Failed to download globals.yaml.gotmpl"
fi

if [ -f "secrets.yaml.original" ]; then
    echo "✅ Downloaded secrets.yaml.original"
else
    echo "❌ Failed to download secrets.yaml"
fi
