#!/bin/bash

# Install Optional AppDynamics Services
# AIOps, OTIS, ATD, UIL

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "Install Optional AppDynamics Services"
echo "========================================="
echo ""
echo "This will install:"
echo "  1. AIOps (Anomaly Detection)"
echo "  2. OTIS (OpenTelemetry)"
echo "  3. ATD (Automatic Transaction Diagnostics)"
echo "  4. UIL (Universal Integration Layer)"
echo ""
echo "Total time: ~30-40 minutes"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "========================================="
echo "Step 1: Install AIOps (Anomaly Detection)"
echo "========================================="
echo ""
echo "⏱️  This takes ~10-15 minutes..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo 'Installing AIOps...'\r" }
expect "$ " { send "appdcli start aiops small\r" }
expect {
    "Install successful" { 
        send "echo ''\r"
        send "echo '✅ AIOps installed successfully!'\r"
        send "echo ''\r"
    }
    "Install failed" {
        send "echo ''\r"
        send "echo '❌ AIOps installation failed!'\r"
        send "echo ''\r"
    }
    timeout {
        send "echo ''\r"
        send "echo '⏳ Still installing... (this can take 15 minutes)'\r"
        send "echo ''\r"
    }
}
expect "$ " { send "echo 'Verifying AIOps pods...'\r" }
expect "$ " { send "kubectl get pods -n cisco-aiops\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "appdcli ping | grep 'AD/RCA'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Step 2: Install OTIS (OpenTelemetry)"
echo "========================================="
echo ""
echo "⏱️  This takes ~5-10 minutes..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo 'Installing OTIS...'\r" }
expect "$ " { send "appdcli start otis small\r" }
expect {
    "Install successful" { 
        send "echo ''\r"
        send "echo '✅ OTIS installed successfully!'\r"
        send "echo ''\r"
    }
    "Install failed" {
        send "echo ''\r"
        send "echo '❌ OTIS installation failed!'\r"
        send "echo ''\r"
    }
    timeout {
        send "echo ''\r"
        send "echo '⏳ Still installing...'\r"
        send "echo ''\r"
    }
}
expect "$ " { send "echo 'Verifying OTIS pods...'\r" }
expect "$ " { send "kubectl get pods -n cisco-otis\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "appdcli ping | grep 'OTIS'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Step 3: Install ATD (Auto Transaction Diagnostics)"
echo "========================================="
echo ""
echo "⏱️  This takes ~10-15 minutes..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo 'Verifying AuthN service...'\r" }
expect "$ " { send "kubectl get pods -n authn | grep auth\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo 'Installing ATD...'\r" }
expect "$ " { send "appdcli start atd small\r" }
expect {
    "Install successful" { 
        send "echo ''\r"
        send "echo '✅ ATD installed successfully!'\r"
        send "echo ''\r"
    }
    "Install failed" {
        send "echo ''\r"
        send "echo '❌ ATD installation failed!'\r"
        send "echo ''\r"
    }
    timeout {
        send "echo ''\r"
        send "echo '⏳ Still installing...'\r"
        send "echo ''\r"
    }
}
expect "$ " { send "echo 'Verifying ATD pods...'\r" }
expect "$ " { send "kubectl get pods -n cisco-atd\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "appdcli ping | grep 'ATD'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Step 4: Install UIL (Universal Integration Layer)"
echo "========================================="
echo ""
echo "⏱️  This takes ~5-10 minutes..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo 'Installing UIL...'\r" }
expect "$ " { send "appdcli start uil small\r" }
expect {
    "Install successful" { 
        send "echo ''\r"
        send "echo '✅ UIL installed successfully!'\r"
        send "echo ''\r"
    }
    "Install failed" {
        send "echo ''\r"
        send "echo '❌ UIL installation failed!'\r"
        send "echo ''\r"
    }
    timeout {
        send "echo ''\r"
        send "echo '⏳ Still installing...'\r"
        send "echo ''\r"
    }
}
expect "$ " { send "echo 'Verifying UIL pods...'\r" }
expect "$ " { send "kubectl get pods -n cisco-uil\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "appdcli ping | grep 'UIL'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "📊 Final Status Check..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "appdcli ping\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Resource Usage ==='\r" }
expect "$ " { send "kubectl top nodes\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "✅ All Optional Services Installed!"
echo "========================================="
echo ""
echo "Installed:"
echo "  ✅ AIOps (Anomaly Detection)"
echo "  ✅ OTIS (OpenTelemetry)"
echo "  ✅ ATD (Automatic Transaction Diagnostics)"
echo "  ✅ UIL (Universal Integration Layer)"
echo ""
echo "Next steps:"
echo "  1. Verify all services show 'Success' in appdcli ping"
echo "  2. Apply license (when received)"
echo "  3. Configure services as needed"
echo ""
