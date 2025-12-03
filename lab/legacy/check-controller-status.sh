#!/bin/bash

# Check Controller status and password configuration

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "Controller Status & Password Check"
echo "========================================="
echo ""

expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo '=== Controller Pod Status ==='\r" }
expect "$ " { send "kubectl get pods -n cisco-controller\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Controller Service Status ==='\r" }
expect "$ " { send "appdcli ping | grep Controller\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Controller Logs (last 30 lines) ==='\r" }
expect "$ " { send "kubectl logs -n cisco-controller --tail=30 \$(kubectl get pods -n cisco-controller -o name | grep controller-deployment) 2>&1 | tail -30\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Check secrets.yaml encryption ==='\r" }
expect "$ " { send "ls -la /var/appd/config/secrets.yaml*\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Controller Ready Check ==='\r" }
expect "$ " { send "kubectl get pods -n cisco-controller -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Controller Container Ready ==='\r" }
expect "$ " { send "kubectl get pods -n cisco-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "exit\r" }
expect eof
EOF

echo ""
echo "========================================="
echo "Diagnosis Complete"
echo "========================================="
echo ""
