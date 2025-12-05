#!/bin/bash
# Install SecureApp (Secure Application)
# Usage: ./appd-install-secureapp.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Install Secure Application (SecureApp)                ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [OPTIONS]

Installs Cisco Secure Application for AppDynamics.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --profile PROFILE    Deployment profile (small, medium) [default: small]
    --help, -h           Show this help

SecureApp provides:
  - Runtime application security
  - Vulnerability detection
  - Threat monitoring
  - Compliance reporting

Prerequisites:
  - Controller must be installed and running
  - License file must be available

Time: 10-15 minutes

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
║   Install Secure Application - Team ${TEAM_NUMBER}                 ║
╚══════════════════════════════════════════════════════════╝

Profile: $PROFILE

SecureApp provides runtime security for your applications.

EOF

VM1_PUB=$(cat "state/team${TEAM_NUMBER}/vm1-public-ip.txt")

read -p "Press ENTER to start installation..."

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   Installation Instructions                              ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM1
  ssh appduser@$VM1_PUB

Step 2: Verify Controller is running
  appdcli ping
  # Controller should show "Success"

Step 3: (If you have a license) Import Controller license
  # Copy license file to VM1:
  # scp license.lic appduser@$VM1_PUB:/var/appd/config/license.lic
  
  # On VM1, apply license:
  appdcli license controller /var/appd/config/license.lic

Step 4: Install SecureApp
  appdcli start secapp $PROFILE

  This installs Cisco Secure Application services.

Step 5: Monitor installation (10-15 minutes)
  
  Watch pods:
    watch kubectl get pods -n cisco-secureapp

  Expected pods:
    - agent-proxy
    - api-proxy
    - alert-proxy
    - collector-server
    - postgres (database)

Step 6: Verify installation
  kubectl get pods -n cisco-secureapp
  
  All pods should be "Running"
  
  appdcli ping
  
  SecureApp should show "Success"

Step 7: Access SecureApp UI
  Navigate in Controller UI:
    Applications → <Your App> → Security

Step 8: Exit SSH
  exit

╔══════════════════════════════════════════════════════════╗
║   Common Issues & Solutions                              ║
╚══════════════════════════════════════════════════════════╝

Issue: "License required"
Fix:   Contact instructor for license file
       Or continue without - can add later

Issue: "Pod stuck in Pending"
Fix:   Check resources: kubectl top nodes
       SecureApp needs additional memory

Issue: "Postgres pod failing"
Fix:   Wait 2-3 minutes - database initialization takes time
       Check logs: kubectl logs postgres-0 -n cisco-secureapp

EOF

read -p "Press ENTER when SecureApp installation is complete..."

# Verify installation
echo ""
log_info "Verifying SecureApp installation..."

ssh -o ConnectTimeout=10 appduser@$VM1_PUB "kubectl get pods -n cisco-secureapp" 2>/dev/null && {
    log_success "SecureApp pods found!"
    echo ""
    ssh -o ConnectTimeout=10 appduser@$VM1_PUB "appdcli ping | grep -i secure" 2>/dev/null || true
} || {
    log_warning "Could not verify SecureApp - check manually"
}

cat << EOF

╔══════════════════════════════════════════════════════════╗
║   ✅ SecureApp Installation Complete!                    ║
╚══════════════════════════════════════════════════════════╝

🔒 SecureApp Features:
  - Runtime threat detection
  - Vulnerability scanning
  - Compliance monitoring
  - Security analytics

📊 Access SecureApp:
  1. Log in to Controller UI
  2. Navigate to Applications
  3. Select your application
  4. Click "Security" tab

EOF

mark_step_complete "secureapp-installed" "$TEAM_NUMBER"
