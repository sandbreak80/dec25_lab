#!/bin/bash
# Install AppDynamics Services
# Usage: ./appd-install.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Install AppDynamics Services                          ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Installs AppDynamics services on the Kubernetes cluster.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --profile PROFILE    Deployment profile (small, medium) [default: small]
    --help, -h           Show this help

Installation includes:
  - Controller
  - Events Service
  - EUM (End User Monitoring)
  - Synthetic Monitoring
  - AIOps
  - ATD (Automatic Transaction Diagnostics)
  - SecureApp (Secure Application)

Note: 'appdcli start all small' installs ALL services including SecureApp.
      For individual service installation, use dedicated scripts.

Time: 20-30 minutes

EOF
}

TEAM_NUMBER=""
PROFILE="small"

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

load_team_config "$TEAM_NUMBER"

cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Install AppDynamics - Team ${TEAM_NUMBER}                        ║
╚══════════════════════════════════════════════════════════╝

Profile: $PROFILE

This will install ALL AppDynamics services:
  ✓ Controller
  ✓ Events Service
  ✓ EUM (End User Monitoring)
  ✓ Synthetic Monitoring
  ✓ AIOps
  ✓ ATD (Automatic Transaction Diagnostics)
  ✓ SecureApp

Time: 20-30 minutes

EOF

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")

# Password is always AppDynamics123! (set in step 3)
PASSWORD="AppDynamics123!"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
log_info "Using password authentication (AppDynamics modifies keys during bootstrap)"

# Check for expect
if ! command -v expect &> /dev/null; then
    log_error "expect is not installed"
    echo "Install expect first: brew install expect"
    exit 1
fi

echo ""
log_info "Starting AppDynamics installation on VM1..."
echo ""

# Step 1: Verify cluster health
log_info "Step 1: Verifying cluster health..."

CLUSTER_CHECK=$(expect << 'EOF_EXPECT'
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdctl show cluster"
expect {
    "password:" { 
        send "$env(PASSWORD)\r"
        exp_continue 
    }
    -re "voter.*true" {
        # Successfully got cluster status
    }
    "Connection refused" {
        puts "ERROR: Connection refused"
        exit 1
    }
    "Connection timed out" {
        puts "ERROR: Connection timed out"
        exit 1
    }
    timeout {
        puts "ERROR: Command timeout"
        exit 1
    }
    eof
}
EOF_EXPECT
)

CLUSTER_CHECK_EXIT=$?
echo "$CLUSTER_CHECK" | tee "state/team${TEAM_NUMBER}/cluster-status.txt"

if [ $CLUSTER_CHECK_EXIT -ne 0 ]; then
    log_error "Cluster check failed - cannot connect to VM1"
    log_error "Verify VM is running and you can access it"
    exit 1
fi

if ! echo "$CLUSTER_CHECK" | grep -q "voter"; then
    log_error "Cluster status check failed - unexpected output"
    exit 1
fi

log_success "Cluster is healthy"
echo ""

# Step 2: Start installation
log_info "Step 2: Starting AppDynamics installation..."
log_warning "This will take 20-30 minutes. Please be patient..."
echo ""

INSTALL_OUTPUT=$(expect << 'EOF_EXPECT' 2>&1
set timeout 3600
log_user 1

spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdcli start all $env(PROFILE)"

expect {
    "password:" { 
        send "$env(PASSWORD)\r"
        exp_continue 
    }
    "Connection refused" {
        puts "\nERROR: SSH connection refused"
        exit 1
    }
    "Connection timed out" {
        puts "\nERROR: SSH connection timed out"
        exit 1
    }
    "Operation timed out" {
        puts "\nERROR: SSH operation timed out"
        exit 1
    }
    timeout {
        puts "\nERROR: Installation command timeout (>60 minutes)"
        exit 1
    }
    eof {
        # Command completed
    }
}
EOF_EXPECT
)

INSTALL_EXIT=$?
echo "$INSTALL_OUTPUT" | sed 's/^/  /'

if [ $INSTALL_EXIT -ne 0 ]; then
    log_error "Installation command failed (exit code: $INSTALL_EXIT)"
    log_error "Check the output above for errors"
    log_info ""
    log_info "You can manually complete the installation:"
    log_info "  ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
    log_info "  appdcli start all $PROFILE"
    exit 1
fi

if echo "$INSTALL_OUTPUT" | grep -qi "ERROR\|Connection.*timed out\|Connection refused"; then
    log_error "Installation command encountered errors"
    exit 1
fi

log_success "Installation command completed"
echo ""

# Step 3: Wait and verify
log_info "Step 3: Waiting for services to start (checking every 60 seconds)..."
echo ""

SERVICES_READY=false

for i in {1..30}; do
    sleep 60
    echo ""
    echo "  Check $i/30..."
    
    # Use expect with password auth (no prompts!)
    PING_OUTPUT=$(expect << 'EOF_CHECK' 2>&1
set timeout 30
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null appduser@$env(VM1_PUB) "appdcli ping"
expect {
    "password:" { 
        send "$env(PASSWORD)\r"
        exp_continue 
    }
    "Connection refused" {
        puts "ERROR: Connection refused"
        exit 1
    }
    "Connection timed out" {
        puts "ERROR: Connection timed out"
        exit 1
    }
    timeout {
        puts "ERROR: Timeout"
        exit 1
    }
    eof
}
EOF_CHECK
)
    
    PING_EXIT=$?
    
    if [ $PING_EXIT -ne 0 ]; then
        log_error "Failed to check service status (cannot connect to VM)"
        log_error "Deployment may have failed or VM is unreachable"
        exit 1
    fi
    
    echo "$PING_OUTPUT" | tee "state/team${TEAM_NUMBER}/service-status-check-${i}.txt"
    
    # Check if all services are up
    if echo "$PING_OUTPUT" | grep -q "Success"; then
        # Count how many services show Success
        SUCCESS_COUNT=$(echo "$PING_OUTPUT" | grep -c "Success" || true)
        FAILED_COUNT=$(echo "$PING_OUTPUT" | grep -c "Failed" || true)
        
        if [ $SUCCESS_COUNT -gt 5 ] && [ $FAILED_COUNT -eq 0 ]; then
            log_success "All critical services are up!"
            SERVICES_READY=true
            break
        else
            echo "  Services starting... ($SUCCESS_COUNT ready, $FAILED_COUNT failed)"
        fi
    else
        echo "  Services still initializing..."
    fi
    
    if [ $i -eq 30 ]; then
        log_error "Services failed to start after 30 minutes"
        log_error "Final status:"
        echo "$PING_OUTPUT" | grep -E "Controller|Events|SecureApp" | sed 's/^/  /'
        echo ""
        log_info "Check manually:"
        log_info "  ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
        log_info "  appdcli ping"
        exit 1
    fi
done

if [ "$SERVICES_READY" != "true" ]; then
    log_error "Service verification failed"
    exit 1
fi

echo ""
echo ""
log_info "Final verification..."

expect << EOF_EXPECT 2>&1 | tee "state/team${TEAM_NUMBER}/service-status.txt"
set timeout 30
spawn ssh $SSH_OPTS appduser@$VM1_PUB "appdcli ping"
expect {
    "password:" { send "${PASSWORD}\r"; exp_continue }
    eof
}
EOF_EXPECT

log_success "Services verified!"

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   ✅ AppDynamics Installation Complete!                  ║
╚══════════════════════════════════════════════════════════╝

🌐 Access Your Controller:
  URL:  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
  User: admin
  Pass: welcome

⚠️  IMPORTANT: Change the password immediately!
  1. Log in to Controller UI
  2. Go to Settings → My Preferences
  3. Change password

📊 Service Status:
  Run on VM1: appdcli ping

EOF

mark_step_complete "appd-installed" "$TEAM_NUMBER"
