#!/bin/bash
# Deploy Master Script - Deploy Full Team Environment
# Usage: ./deploy-team.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER [OPTIONS]

Deploy complete AppDynamics VA environment for a team.

Arguments:
    --team, -t NUMBER    Team number (1-5) [REQUIRED]
    --skip-profile       Skip AWS profile creation
    --skip-ami           Skip AMI import (use existing)
    --help, -h           Show this help message

Example:
    $0 --team 1                  # Full deployment for Team 1
    $0 --team 2 --skip-profile   # Skip profile setup

Deployment Steps:
    1. AWS Profile Setup
    2. VPC & Network Creation
    3. Security Groups
    4. AMI Import (from shared bucket)
    5. EC2 Instance Deployment (3 VMs)
    6. ALB & SSL Setup (ACM)
    7. DNS Configuration
    8. Verification & Testing

Total Time: ~30-45 minutes

EOF
}

# Parse arguments
TEAM_NUMBER=""
SKIP_PROFILE=false
SKIP_AMI=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t)
            TEAM_NUMBER="$2"
            shift 2
            ;;
        --skip-profile)
            SKIP_PROFILE=true
            shift
            ;;
        --skip-ami)
            SKIP_AMI=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

# Validate team number
if ! [[ "$TEAM_NUMBER" =~ ^[1-5]$ ]]; then
    log_error "Team number must be between 1 and 5"
    exit 1
fi

# Load team configuration
load_team_config "$TEAM_NUMBER"

# Show deployment plan
clear
cat << EOF
========================================
🚀 AppDynamics Lab Deployment
========================================

Team:        $TEAM_NUMBER
Domain:      $FULL_DOMAIN
VPC CIDR:    $VPC_CIDR
Region:      $AWS_REGION
Profile:     $AWS_PROFILE

Deployment Plan:
  ✓ VPC & Networking
  ✓ Security Groups
  ✓ AMI Import (shared)
  ✓ 3 EC2 Instances ($VM_TYPE)
  ✓ Application Load Balancer
  ✓ ACM SSL Certificate
  ✓ DNS Records

Estimated Time: 30-45 minutes
Estimated Cost: ~\$12 for full lab day

========================================
EOF

confirm_action "Ready to start deployment?"

# Create log directory
LOG_DIR="logs/team${TEAM_NUMBER}"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log_info "Deployment started at $(date)"
log_info "Log file: $LOG_FILE"
echo ""

# Step 1: AWS Profile
if [ "$SKIP_PROFILE" = false ]; then
    if ! is_step_complete "01-aws-profile" "$TEAM_NUMBER"; then
        log_info "========== Step 1/8: AWS Profile =========="
        ./01-aws-create-profile.sh --team "$TEAM_NUMBER"
        echo ""
    else
        log_success "Step 1/8: AWS Profile (already configured)"
    fi
else
    log_info "Step 1/8: AWS Profile (skipped)"
fi

# Step 2: VPC
if ! is_step_complete "02-vpc-created" "$TEAM_NUMBER"; then
    log_info "========== Step 2/8: VPC & Network =========="
    ./02-aws-create-vpc.sh --team "$TEAM_NUMBER"
    echo ""
else
    log_success "Step 2/8: VPC & Network (already exists)"
fi

# Step 3: Security Groups
if ! is_step_complete "03-security-groups-created" "$TEAM_NUMBER"; then
    log_info "========== Step 3/8: Security Groups =========="
    ./03-aws-create-security-groups.sh --team "$TEAM_NUMBER"
    echo ""
else
    log_success "Step 3/8: Security Groups (already exist)"
fi

# Step 4: AMI Import
if [ "$SKIP_AMI" = false ]; then
    if ! is_step_complete "04-ami-imported" "$TEAM_NUMBER"; then
        log_info "========== Step 4/8: AMI Import =========="
        log_info "Using shared AMI from: s3://$SHARED_AMI_BUCKET/$APPD_RAW_IMAGE"
        # Note: AMI import is shared across all teams, so we check if it exists first
        # TODO: Implement AMI import script
        echo ""
    else
        log_success "Step 4/8: AMI Import (already completed)"
    fi
else
    log_info "Step 4/8: AMI Import (skipped)"
fi

# Step 5: EC2 Instances
# TODO: Implement VM deployment
log_warning "Step 5/8: EC2 Instances (TODO)"

# Step 6: ALB & SSL
# TODO: Implement ALB setup
log_warning "Step 6/8: ALB & SSL (TODO)"

# Step 7: DNS
# TODO: Implement DNS setup
log_warning "Step 7/8: DNS Configuration (TODO)"

# Step 8: Verification
# TODO: Implement verification
log_warning "Step 8/8: Verification (TODO)"

echo ""
echo "========================================="
log_info "Deployment Summary"
echo "========================================="
echo ""
echo "Team:   $TEAM_NUMBER"
echo "Status: IN PROGRESS"
echo ""
echo "Completed Steps:"
is_step_complete "01-aws-profile" "$TEAM_NUMBER" && echo "  ✅ AWS Profile"
is_step_complete "02-vpc-created" "$TEAM_NUMBER" && echo "  ✅ VPC & Network"
is_step_complete "03-security-groups-created" "$TEAM_NUMBER" && echo "  ✅ Security Groups"
echo ""
echo "Log file: $LOG_FILE"
echo ""
echo "To continue deployment, students should:"
echo "  1. Run VM bootstrap script"
echo "  2. Create Kubernetes cluster"
echo "  3. Install AppDynamics services"
echo ""
