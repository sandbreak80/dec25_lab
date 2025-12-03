#!/bin/bash
# Complete Deployment Script for Team - SIMPLIFIED for Students
# Usage: ./lab-deploy.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Virtual Appliance Lab - Team Deployment   ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER
   OR: $0 config/teamN.cfg

Arguments:
    --team, -t NUMBER    Your team number (1-5)
    config/teamN.cfg     Path to team config file
    --help, -h           Show this help

Examples:
    $0 --team 1
    $0 config/team1.cfg

This script will:
  1. ✓ Create AWS infrastructure (VPC, subnets, security groups)
  2. ✓ Deploy 3 VMs for AppDynamics
  3. ✓ Create Application Load Balancer with SSL
  4. ✓ Configure DNS (teamN.splunkylabs.com)
  5. ✓ Prepare VMs for AppDynamics installation

Time: ~30 minutes
Cost: ~$20 for 8-hour lab day

EOF
}

# Parse team number
TEAM_NUMBER=""

# Check if first argument is a config file
if [[ $# -gt 0 ]] && [[ "$1" == config/team*.cfg ]]; then
    # Extract team number from config filename  
    TEAM_NUMBER=$(echo "$1" | sed -n 's/.*team\([0-9]\)\.cfg/\1/p')
    shift
fi

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

if ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be 1-5"
    exit 1
fi

# Load configuration
log_info "Loading configuration for Team ${TEAM_NUMBER}..."
load_team_config "$TEAM_NUMBER"

echo ""
log_success "Configuration loaded: $TEAM_NAME"
log_info "VPC: $VPC_NAME ($VPC_CIDR)"
log_info "Domain: $FULL_DOMAIN"
log_info "SSH: Password-based (appduser)"

# Welcome banner
clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   🚀 AppDynamics Lab Deployment - Team ${TEAM_NUMBER}                 ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Your Configuration:
  Team:        ${TEAM_NUMBER}
  Domain:      ${FULL_DOMAIN}
  VPC:         ${VPC_CIDR}
  Region:      ${AWS_REGION}

What we'll build:
  ✓ VPC with 2 subnets in different availability zones
  ✓ Internet Gateway for public access
  ✓ Security Groups (restricted SSH, open HTTPS)
  ✓ 3 EC2 instances (m5a.4xlarge with 200GB + 500GB storage)
  ✓ Application Load Balancer
  ✓ AWS Certificate Manager SSL certificate
  ✓ Route 53 DNS records

Estimated time: 30 minutes
Estimated cost: ~\$20 for 8-hour lab

Press ENTER to start deployment...
EOF
read

# Setup logging
LOG_DIR="logs/team${TEAM_NUMBER}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_info "Deployment started: $(date)"
echo ""

# Phase 1: Infrastructure
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 1: Network Infrastructure                        ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if ! is_step_complete "vpc-created" "$TEAM_NUMBER"; then
    log_info "Creating VPC and network infrastructure..."
    ./scripts/create-network.sh --team "$TEAM_NUMBER"
    mark_step_complete "vpc-created" "$TEAM_NUMBER"
else
    log_success "Network infrastructure already exists"
fi
echo ""

# Phase 2: Security
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 2: Security Groups                               ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if ! is_step_complete "security-created" "$TEAM_NUMBER"; then
    log_info "Creating security groups..."
    ./scripts/create-security.sh --team "$TEAM_NUMBER"
    mark_step_complete "security-created" "$TEAM_NUMBER"
else
    log_success "Security groups already exist"
fi
echo ""

# Phase 3: VMs
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 3: Virtual Machines (3 VMs)                      ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if ! is_step_complete "vms-created" "$TEAM_NUMBER"; then
    log_info "Deploying 3 EC2 instances..."
    log_info "This takes ~5 minutes..."
    ./scripts/create-vms.sh --team "$TEAM_NUMBER"
    mark_step_complete "vms-created" "$TEAM_NUMBER"
else
    log_success "VMs already deployed"
fi
echo ""

# Phase 4: Load Balancer
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 4: Application Load Balancer + SSL               ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if ! is_step_complete "alb-created" "$TEAM_NUMBER"; then
    log_info "Creating Application Load Balancer with SSL..."
    log_info "This takes ~3 minutes..."
    ./scripts/create-alb.sh --team "$TEAM_NUMBER"
    mark_step_complete "alb-created" "$TEAM_NUMBER"
else
    log_success "ALB already configured"
fi
echo ""

# Phase 5: DNS
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 5: DNS Configuration                             ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

if ! is_step_complete "dns-created" "$TEAM_NUMBER"; then
    log_info "Configuring DNS records..."
    ./scripts/create-dns.sh --team "$TEAM_NUMBER"
    mark_step_complete "dns-created" "$TEAM_NUMBER"
else
    log_success "DNS already configured"
fi
echo ""

# Phase 6: Verification
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  PHASE 6: Verification                                   ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

log_info "Verifying deployment..."
./scripts/verify-deployment.sh --team "$TEAM_NUMBER"
echo ""

# Success!
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ DEPLOYMENT COMPLETE!                                 ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

📊 Your Infrastructure:
   VPC:        $(load_resource_id vpc "$TEAM_NUMBER")
   Subnets:    $(load_resource_id subnet "$TEAM_NUMBER")
               $(load_resource_id subnet2 "$TEAM_NUMBER")
   VMs:        3 × m5a.4xlarge
   ALB:        $(load_resource_id alb "$TEAM_NUMBER" | cut -d'/' -f3)
   Domain:     ${FULL_DOMAIN}

🌐 Your URLs:
   Controller: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
   Auth:       https://customer1-team${TEAM_NUMBER}.auth.splunkylabs.com/

📝 Next Steps:
   1. Change appduser password (REQUIRED!):
      ./appd-change-password.sh --team ${TEAM_NUMBER}
      Default: changeme → AppDynamics123!
   
   2. Setup SSH keys (HIGHLY RECOMMENDED - avoid typing password 30-50x!):
      ./scripts/setup-ssh-keys.sh --team ${TEAM_NUMBER}
      Time: 1 minute | Benefit: Passwordless SSH! 🎉
   
   3. Bootstrap VMs (wait for image extraction ~15 min):
      ./appd-bootstrap-vms.sh --team ${TEAM_NUMBER}
   
   4. Test SSH access:
      ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}
      (With keys: no password! Without keys: enter password)
   
   5. Create cluster:
      ./appd-create-cluster.sh --team ${TEAM_NUMBER}
   
   6. Install AppDynamics:
      ./appd-install.sh --team ${TEAM_NUMBER}
      
SSH Info:
   User: appduser
   Initial password: changeme
   Team password: AppDynamics123! (after step 1)
   SSH keys: Optional but HIGHLY recommended! (step 2)

📚 Documentation:
   Quick Start:     ./docs/QUICK_START.md
   Bootstrap Guide: ./docs/BOOTSTRAP_GUIDE.md
   Lab Guide:       ./docs/LAB_GUIDE.md

🔍 Check Status:
   ./scripts/check-status.sh --team ${TEAM_NUMBER}

📋 Log File:
   ${LOG_FILE}

Happy Learning! 🎓
EOF
