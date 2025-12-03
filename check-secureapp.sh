#!/bin/bash
# Check SecureApp status

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================"
echo "🔍 Checking SecureApp Status"
echo "========================================"
echo ""

expect << EXPECT_SCRIPT
set timeout 20
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "echo 'SecureApp Pods:'\r"
    send "kubectl get pods -n cisco-secureapp\r"
    send "echo ''\r"
    send "echo 'SecureApp Services:'\r"
    send "kubectl get svc -n cisco-secureapp\r"
    send "echo ''\r"
    send "echo 'SecureApp Helm Release:'\r"
    send "helm list -n cisco-secureapp\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT
