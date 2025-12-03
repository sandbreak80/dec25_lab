#!/bin/bash

# Monitor AppDynamics service installation progress

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "AppDynamics Installation Monitor"
echo "========================================="
echo ""

echo "📊 Checking service status..."
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo '=== Service Status ==='\r" }
expect "$ " { send "appdcli ping\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Pod Summary ==='\r" }
expect "$ " { send "kubectl get pods --all-namespaces | grep -E '(NAMESPACE|Running|Pending|Error|CrashLoop)' | head -20\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Node Resources ==='\r" }
expect "$ " { send "kubectl top nodes 2>/dev/null || echo 'Metrics not yet available'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo 'Check complete! Press Ctrl+C to exit or wait...'\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Monitor Complete"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Wait for all pods to be Running"
echo "  2. Verify: appdcli ping (all Success)"
echo "  3. Access: https://controller.splunkylabs.com/controller"
echo "  4. Login: admin / 3tzylHGF9JCHpqYM"
echo ""
