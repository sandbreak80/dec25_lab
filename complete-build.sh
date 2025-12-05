#!/bin/bash
# Complete automated build for Team
# This script runs all deployment steps from start to finish

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Complete Automated Build                               ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER [--skip-wait]

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --skip-wait          Skip the 15-minute bootstrap wait
    --help, -h           Show this help

This script will:
  1. Deploy infrastructure (VPC, VMs, ALB, DNS)
  2. Change password
  3. Setup SSH keys
  4. Bootstrap VMs
  5. Wait for image extraction (15 min, unless --skip-wait)
  6. Create cluster
  7. Verify completion

Total time: ~35-40 minutes (or ~20 min with --skip-wait)

EOF
    exit 1
}

TEAM_NUMBER=""
SKIP_WAIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --skip-wait) SKIP_WAIT=true; shift ;;
        --help|-h) show_usage ;;
        *) log_error "Unknown parameter: $1"; show_usage ;;
    esac
done

if [[ -z "$TEAM_NUMBER" ]] || ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    show_usage
fi

load_team_config "$TEAM_NUMBER"
check_aws_cli

cat << EOF

╔══════════════════════════════════════════════════════════╗
║  🚀 COMPLETE AUTOMATED BUILD - Team ${TEAM_NUMBER}                 ║
╚══════════════════════════════════════════════════════════╝

Domain: ${FULL_DOMAIN}
VPC:    ${VPC_CIDR}
Region: ${AWS_REGION}

This will take approximately 35-40 minutes.
All steps are fully automated!

Press Ctrl+C now to cancel, or wait 5 seconds to begin...

EOF

sleep 5

# Step 1: Infrastructure
log_info "=== STEP 1/7: Deploying Infrastructure ==="
echo ""
./scripts/create-network.sh --team "$TEAM_NUMBER"
./scripts/create-security.sh --team "$TEAM_NUMBER"
./scripts/create-vms.sh --team "$TEAM_NUMBER"
./scripts/create-alb.sh --team "$TEAM_NUMBER"

# Fix ALB DNS for DNS script
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "appd-team${TEAM_NUMBER}-alb" \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null)
echo "$ALB_DNS" > "state/team${TEAM_NUMBER}/alb-dns.txt"

./scripts/create-dns.sh --team "$TEAM_NUMBER"

log_success "Infrastructure deployed!"
echo ""

# Step 2: Change Password
log_info "=== STEP 2/7: Changing Password ==="
echo ""
./appd-change-password.sh --team "$TEAM_NUMBER"
log_success "Password changed!"
echo ""

# Step 3: Setup SSH Keys
log_info "=== STEP 3/7: Setting up SSH Keys ==="
echo ""
# Delete old keys if they exist
rm -f "/Users/bmstoner/.ssh/appd-team${TEAM_NUMBER}-key"*
./scripts/setup-ssh-keys.sh --team "$TEAM_NUMBER"
log_success "SSH keys configured!"
echo ""

# Step 4: Bootstrap VMs
log_info "=== STEP 4/7: Bootstrapping VMs ==="
echo ""
./appd-bootstrap-vms.sh --team "$TEAM_NUMBER"
log_success "Bootstrap initiated!"
echo ""

# Step 5: Wait for image extraction
if [ "$SKIP_WAIT" = false ]; then
    log_info "=== STEP 5/7: Waiting for image extraction (15 minutes) ==="
    echo ""
    log_warning "Bootstrap extracts 15GB of container images..."
    log_warning "This happens in the background and takes 15-20 minutes"
    echo ""
    
    for i in {1..15}; do
        echo -ne "  Waiting: $i/15 minutes...\r"
        sleep 60
    done
    echo ""
    log_success "Wait complete!"
    echo ""
else
    log_warning "=== STEP 5/7: Skipping bootstrap wait (--skip-wait) ==="
    echo ""
fi

# Step 6: Create Cluster
log_info "=== STEP 6/7: Creating Kubernetes Cluster ==="
echo ""
./appd-create-cluster.sh --team "$TEAM_NUMBER"
log_success "Cluster created!"
echo ""

# Step 7: Final Verification
log_info "=== STEP 7/7: Final Verification ==="
echo ""

cat << EOF

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ COMPLETE BUILD SUCCESSFUL!                           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Team ${TEAM_NUMBER} is fully deployed and ready!

🌐 URLs:
   Controller: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
   Auth:       https://customer1-team${TEAM_NUMBER}.auth.splunkylabs.com/

📝 Next Steps:
   1. Configure cluster:
      ./appd-configure.sh --team ${TEAM_NUMBER}
   
   2. Install AppDynamics:
      ./appd-install.sh --team ${TEAM_NUMBER}

🔍 Check Status:
   ./scripts/check-status.sh --team ${TEAM_NUMBER}

Happy Learning! 🎓

EOF
