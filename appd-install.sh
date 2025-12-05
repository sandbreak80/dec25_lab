#!/bin/bash
# Install AppDynamics Services
# Usage: ./appd-install.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

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

# Determine SSH method
if [[ -f "state/team${TEAM_NUMBER}/ssh-key-path.txt" ]]; then
    KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt")
    SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    log_info "Using SSH key: $KEY_PATH"
else
    SSH_OPTS="-o StrictHostKeyChecking=no"
    log_warning "No SSH key found, using password authentication"
fi

echo ""
log_info "Starting AppDynamics installation on VM1..."
echo ""

# Step 1: Verify cluster health
log_info "Step 1: Verifying cluster health..."
ssh $SSH_OPTS appduser@$VM1_PUB "appdctl show cluster" 2>&1 | tee "state/team${TEAM_NUMBER}/cluster-status.txt"
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_error "Cluster check failed"
    exit 1
fi
log_success "Cluster is healthy"
echo ""

# Step 2: Start installation
log_info "Step 2: Starting AppDynamics installation..."
log_warning "This will take 20-30 minutes. Please be patient..."
echo ""

ssh $SSH_OPTS appduser@$VM1_PUB "appdcli start all $PROFILE" 2>&1 | sed 's/^/  /'

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_error "Installation command failed"
    log_info "You can manually complete the installation:"
    log_info "  ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
    log_info "  appdcli start all $PROFILE"
    exit 1
fi

log_success "Installation command completed"
echo ""

# Step 3: Wait and verify
log_info "Step 3: Waiting for services to start (checking every 60 seconds)..."
echo ""

for i in {1..30}; do
    sleep 60
    echo "  Check $i/30..."
    ssh $SSH_OPTS appduser@$VM1_PUB "appdcli ping" 2>&1 | tee "state/team${TEAM_NUMBER}/service-status-check.txt"
    
    # Check if all services are up
    if grep -q "Success" "state/team${TEAM_NUMBER}/service-status-check.txt" && \
       ! grep -q "Progressing\|Failed\|Pending" "state/team${TEAM_NUMBER}/service-status-check.txt"; then
        log_success "All services are up!"
        break
    fi
    
    if [ $i -eq 30 ]; then
        log_warning "Timeout waiting for services. Check manually:"
        log_info "  ./scripts/ssh-vm1.sh --team $TEAM_NUMBER"
        log_info "  appdcli ping"
    fi
done

echo ""
echo ""
log_info "Final verification..."

ssh $SSH_OPTS appduser@$VM1_PUB "appdcli ping" 2>&1 | tee "state/team${TEAM_NUMBER}/service-status.txt"
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

📝 Next Steps:
  1. Log in to Controller UI
  2. Change admin password
  3. Apply license (when received)
  4. Configure applications
  5. Deploy agents

🔍 Troubleshooting:
  ./appd-check-health.sh --team ${TEAM_NUMBER}

EOF

mark_step_complete "appd-installed" "$TEAM_NUMBER"
