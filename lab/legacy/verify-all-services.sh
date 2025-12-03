#!/bin/bash
# Verify all services after 'appdcli start all small'

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"

echo "========================================"
echo "🔍 Verifying All AppDynamics Services"
echo "========================================"
echo ""

expect << EXPECT_SCRIPT
set timeout 30
spawn ssh appduser@${VM_IP}
expect {
    "password:" {
        send "${VM_PASSWORD}\r"
        exp_continue
    }
    "appduser@" {
        send "echo '1️⃣ Service Status Check'\r"
        send "appdcli ping\r"
        send "echo ''\r"
        send "echo '2️⃣ Kubernetes Pods Status'\r"
        send "kubectl get pods --all-namespaces | grep -E '(cisco|authn|mysql|kafka|redis|postgres|es|fluent|synthetic|eum|events|ingress)' | head -30\r"
        send "echo ''\r"
        send "echo '3️⃣ Resource Usage'\r"
        send "kubectl top nodes\r"
        send "echo ''\r"
        send "echo '4️⃣ Helm Releases'\r"
        send "helm list --all-namespaces | grep -E '(cisco|authn|controller|events|eum|synthetic|aiops|atd|secureapp)' | wc -l\r"
        send "echo ' Helm releases found'\r"
        send "exit\r"
    }
    timeout {
        puts "Timeout connecting"
        exit 1
    }
}
expect eof
EXPECT_SCRIPT

echo ""
echo "========================================"
echo "✅ Verification Complete!"
echo "========================================"
echo ""
echo "Next: Check that all services show 'Success'"
