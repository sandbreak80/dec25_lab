#!/bin/bash
# Create Security Groups
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")

log_info "Creating security groups for Team ${TEAM_NUMBER}..."

# VM Security Group
log_info "[1/2] Creating VM Security Group..."
VM_SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Team $TEAM_NUMBER VM Security Group" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text 2>/dev/null || get_resource_id sg "$SG_NAME")

# SSH from instructor only
aws ec2 authorize-security-group-ingress \
    --group-id "$VM_SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${INSTRUCTOR_IP}" 2>/dev/null || true

save_resource_id vm-sg "$VM_SG_ID" "$TEAM_NUMBER"
log_success "VM Security Group: $VM_SG_ID"

# ALB Security Group
log_info "[2/2] Creating ALB Security Group..."
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name "$ALB_SG_NAME" \
    --description "Team $TEAM_NUMBER ALB Security Group" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text 2>/dev/null || get_resource_id sg "$ALB_SG_NAME")

# HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 2>/dev/null || true

# HTTP from anywhere (for redirect)
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 2>/dev/null || true

save_resource_id alb-sg "$ALB_SG_ID" "$TEAM_NUMBER"
log_success "ALB Security Group: $ALB_SG_ID"

# Allow HTTPS from ALB to VMs
aws ec2 authorize-security-group-ingress \
    --group-id "$VM_SG_ID" \
    --protocol tcp \
    --port 443 \
    --source-group "$ALB_SG_ID" 2>/dev/null || true

log_success "Security groups configured!"
