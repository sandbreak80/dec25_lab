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

clear
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

read -p "Press ENTER to start installation..."

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   Installation Instructions                              ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM1
  ssh appduser@$VM1_PUB

Step 2: Verify cluster is healthy
  appdctl show cluster
  # All nodes should show "Running: true"

Step 3: Start installation
  appdcli start all $PROFILE

  This installs everything in one command!

Step 4: Monitor installation (20-30 minutes)
  
  Watch pods starting:
    watch kubectl get pods --all-namespaces

  Check service status:
    appdcli ping

  View resource usage:
    kubectl top nodes

Step 5: Wait for all services to show "Success"
  appdcli ping
  
  Expected output:
    Controller          | Success
    Events              | Success
    EUM Collector       | Success
    EUM Aggregator      | Success
    EUM Screenshot      | Success
    Synthetic Shepherd  | Success
    Synthetic Scheduler | Success
    Synthetic Feeder    | Success
    AD/RCA Services     | Success
    SecureApp           | Success
    ATD                 | Success

Step 6: Exit SSH
  exit

╔══════════════════════════════════════════════════════════╗
║   Common Issues & Solutions                              ║
╚══════════════════════════════════════════════════════════╝

Issue: "Permission denied on secrets.yaml"
Fix:   sudo chmod 644 /var/appd/config/secrets.yaml

Issue: "Database is locked" (MySQL)
Fix:   Wait 30 seconds and retry: appdcli start all $PROFILE

Issue: "Pod stuck in Pending"
Fix:   Check resources: kubectl top nodes
       May need to wait for other pods to stabilize

Issue: Service shows "Failed"
Fix:   Wait 5 more minutes - some services take time
       Check pod logs: kubectl logs <pod-name> -n <namespace>

EOF

read -p "Press ENTER when installation is complete..."

# Verify installation
echo ""
log_info "Verifying installation..."

ssh -o ConnectTimeout=10 appduser@$VM1_PUB "appdcli ping" 2>/dev/null | tee "state/team${TEAM_NUMBER}/service-status.txt" && {
    log_success "Services verified!"
} || {
    log_warning "Could not verify services - check manually"
}

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

🔒 Optional: Install SecureApp separately
  (Note: 'start all' already includes SecureApp)
  ./appd-install-secureapp.sh --team ${TEAM_NUMBER}

🔍 Troubleshooting:
  ./appd-check-health.sh --team ${TEAM_NUMBER}

EOF

mark_step_complete "appd-installed" "$TEAM_NUMBER"
