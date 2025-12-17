#!/bin/bash
# Check AppDynamics Health
# Usage: ./appd-check-health.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Check AppDynamics installation health and status.

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")

# Password is always AppDynamics123! (set in step 3)
PASSWORD="AppDynamics123!"
export VM1_PUB PASSWORD

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Health Check - Team ${TEAM_NUMBER}                   ║
╚══════════════════════════════════════════════════════════╝

EOF

log_info "Checking service status..."
echo ""

PING_CHECK=$(expect << EOF_EXPECT 2>&1
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$VM1_PUB "appdcli ping"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

PING_EXIT=$?

if [ $PING_EXIT -ne 0 ]; then
    log_error "Cannot connect to VM1"
    log_error "$PING_CHECK"
    exit 1
fi

echo ""
log_info "Checking pod health..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl get pods --all-namespaces | grep -E '(cisco|authn|mysql|kafka|redis)' | head -20"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT

echo ""
log_info "Checking resource usage..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl top nodes"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT

echo ""
log_info "Checking cluster status..."
echo ""

expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdctl show cluster"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT

echo ""

# Validate critical services by checking pod health (more reliable than appdcli ping)
log_info "Validating critical services via pod health..."
echo ""

POD_STATUS=$(expect << 'EOF_EXPECT' 2>&1
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "kubectl get pods -n cisco-controller -n cisco-events -n cisco-secureapp --no-headers"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    "Connection refused" { puts "ERROR: Connection refused"; exit 1 }
    "Connection timed out" { puts "ERROR: Connection timed out"; exit 1 }
    timeout { puts "ERROR: Timeout"; exit 1 }
    eof
}
EOF_EXPECT
)

# Check Controller pods
CONTROLLER_PODS=$(echo "$POD_STATUS" | grep "cisco-controller" | grep -E "controller-deployment|bootstrap" || echo "")
CONTROLLER_RUNNING=$(echo "$CONTROLLER_PODS" | grep -E "Running|Completed" | wc -l | tr -d ' ')

if [[ $CONTROLLER_RUNNING -eq 0 ]]; then
    log_error "Controller pods are not running!"
    echo ""
    echo "⚠️  The Controller may still be starting up after license application."
    echo "   This typically takes 5-10 minutes."
    echo ""
    echo "Check status with:"
    echo "  ssh appduser@${VM1_PUB}"
    echo "  kubectl get pods -n cisco-controller"
    echo ""
    exit 1
fi

# Check Events pods
EVENTS_PODS=$(echo "$POD_STATUS" | grep "cisco-events" || echo "")
EVENTS_RUNNING=$(echo "$EVENTS_PODS" | grep -c "Running" || echo "0")

# Check SecureApp pods (optional but nice to verify)
SECUREAPP_PODS=$(echo "$POD_STATUS" | grep "cisco-secureapp" || echo "")
SECUREAPP_RUNNING=$(echo "$SECUREAPP_PODS" | grep -E "Running|Completed" | wc -l | tr -d ' ')

log_success "✅ Controller: $CONTROLLER_RUNNING pods running"
log_success "✅ Events: $EVENTS_RUNNING pods running"
log_success "✅ SecureApp: $SECUREAPP_RUNNING pods running"

echo ""
log_info "Checking service URLs..."
echo ""

# Check Controller URL (any response 200-499 is good - service is up)
CONTROLLER_HTTP=$(expect << 'EOF_EXPECT' 2>&1 | grep -oE "[0-9]{3}" | head -1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "curl -k -s -o /dev/null -w '%{http_code}' https://controller-team$env(TEAM_NUMBER).splunkylabs.com/controller/"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT
)

# Check Events URL
EVENTS_HTTP=$(expect << 'EOF_EXPECT' 2>&1 | grep -oE "[0-9]{3}" | head -1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "curl -k -s -o /dev/null -w '%{http_code}' https://team$env(TEAM_NUMBER).splunkylabs.com/events/"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT
)

# Check SecureApp URL
SECUREAPP_HTTP=$(expect << 'EOF_EXPECT' 2>&1 | grep -oE "[0-9]{3}" | head -1
set timeout 15
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "curl -k -s -o /dev/null -w '%{http_code}' https://team$env(TEAM_NUMBER).splunkylabs.com/secureapp/"
expect {
    "password:" { send "$env(PASSWORD)\r"; exp_continue }
    eof
}
EOF_EXPECT
)

# Validate URLs
# 200-299 = OK, 300-399 = Redirect (normal for auth), 401/403 = Auth required (service UP!)
# Only 500+ or empty = actual problem
URL_ISSUES=false

if [[ -z "$CONTROLLER_HTTP" ]] || [[ "$CONTROLLER_HTTP" -ge 500 ]]; then
    log_error "❌ Controller URL not responding (HTTP: $CONTROLLER_HTTP)"
    URL_ISSUES=true
else
    if [[ "$CONTROLLER_HTTP" -ge 300 ]] && [[ "$CONTROLLER_HTTP" -lt 400 ]]; then
        log_success "✅ Controller URL responding (HTTP: $CONTROLLER_HTTP - redirect, normal)"
    elif [[ "$CONTROLLER_HTTP" -eq 401 ]] || [[ "$CONTROLLER_HTTP" -eq 403 ]]; then
        log_success "✅ Controller URL responding (HTTP: $CONTROLLER_HTTP - auth required, service UP!)"
    else
        log_success "✅ Controller URL responding (HTTP: $CONTROLLER_HTTP)"
    fi
fi

if [[ -z "$EVENTS_HTTP" ]] || [[ "$EVENTS_HTTP" -ge 500 ]]; then
    log_warning "⚠️  Events URL not responding (HTTP: $EVENTS_HTTP)"
else
    log_success "✅ Events URL responding (HTTP: $EVENTS_HTTP)"
fi

if [[ -z "$SECUREAPP_HTTP" ]] || [[ "$SECUREAPP_HTTP" -ge 500 ]]; then
    log_warning "⚠️  SecureApp URL not responding (HTTP: $SECUREAPP_HTTP)"
else
    if [[ "$SECUREAPP_HTTP" -ge 300 ]] && [[ "$SECUREAPP_HTTP" -lt 400 ]]; then
        log_success "✅ SecureApp URL responding (HTTP: $SECUREAPP_HTTP - redirect to auth, normal!)"
    elif [[ "$SECUREAPP_HTTP" -eq 401 ]] || [[ "$SECUREAPP_HTTP" -eq 403 ]]; then
        log_success "✅ SecureApp URL responding (HTTP: $SECUREAPP_HTTP - auth required, service UP!)"
    else
        log_success "✅ SecureApp URL responding (HTTP: $SECUREAPP_HTTP)"
    fi
fi

if [[ "$URL_ISSUES" == "true" ]]; then
    echo ""
    log_error "Critical service URLs are not accessible!"
    echo ""
    echo "The Controller may still be starting after license application."
    echo "Wait 5-10 minutes and try accessing:"
    echo "  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/"
    echo ""
    exit 1
fi
echo ""

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   ✅ Deployment Complete!                                ║
╚══════════════════════════════════════════════════════════╝

Controller Access:
  URL:  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
  User: admin
  Pass: welcome (CHANGE THIS!)

EOF

# Check for any pods that aren't healthy
NOT_READY_PODS=$(echo "$POD_STATUS" | grep -vE "Running|Completed" | awk '{print $1}' | head -5)
if [[ -n "$NOT_READY_PODS" ]]; then
    echo "⚠️  Note: Some pods are still starting:"
    echo "$NOT_READY_PODS" | sed 's/^/   /'
    echo "   These may become available in a few minutes."
    echo ""
fi
