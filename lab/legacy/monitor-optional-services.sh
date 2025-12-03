#!/bin/bash

# Monitor AIOps and ATD installation progress

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================="
echo "Monitor Optional Services Installation"
echo "========================================="
echo ""
echo "Monitoring AIOps and ATD pod startup..."
echo "This usually takes 10-15 minutes"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    echo "========================================="
    echo "Optional Services Status"
    echo "========================================="
    date
    echo ""
    
    expect << 'EOF'
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "$ " { send "echo '=== AIOps Pods (20 total) ==='\r" }
expect "$ " { send "kubectl get pods -n cisco-aiops --no-headers | wc -l\r" }
expect "$ " { send "echo 'Running:'\r" }
expect "$ " { send "kubectl get pods -n cisco-aiops --no-headers | grep -c Running || echo '0'\r" }
expect "$ " { send "echo 'Pending/Starting:'\r" }
expect "$ " { send "kubectl get pods -n cisco-aiops --no-headers | grep -cE 'Pending|ContainerCreating|Init' || echo '0'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== ATD Pods (2 total) ==='\r" }
expect "$ " { send "kubectl get pods -n cisco-atd --no-headers | wc -l\r" }
expect "$ " { send "echo 'Running:'\r" }
expect "$ " { send "kubectl get pods -n cisco-atd --no-headers | grep -c Running || echo '0'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Service Status ==='\r" }
expect "$ " { send "appdcli ping | grep -E '(AD/RCA|ATD)'\r" }
expect "$ " { send "echo ''\r" }
expect "$ " { send "echo '=== Resource Usage ==='\r" }
expect "$ " { send "kubectl top nodes\r" }
expect "$ " { send "exit\r" }
expect eof
EOF
    
    echo ""
    echo "Checking again in 30 seconds..."
    echo "Press Ctrl+C to stop"
    sleep 30
done
