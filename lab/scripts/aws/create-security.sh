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

# SSH from allowed CIDRs (Cisco VPN public egress IPs)
log_info "Configuring SSH access from Cisco VPN egress IPs..."
for cidr in "${ALLOWED_SSH_CIDRS[@]}"; do
    # Determine description based on CIDR
    DESCRIPTION=""
    case "$cidr" in
        "151.186.183.24/32")
            DESCRIPTION="Cisco VPN US-West egress 1"
            ;;
        "151.186.183.87/32")
            DESCRIPTION="Cisco VPN US-West egress 2"
            ;;
        "151.186.182.23/32")
            DESCRIPTION="Cisco VPN US-East egress 1"
            ;;
        "151.186.182.87/32")
            DESCRIPTION="Cisco VPN US-East egress 2"
            ;;
        "151.186.192.0/20")
            DESCRIPTION="Cisco VPN Shared pool"
            ;;
        *)
            DESCRIPTION="Team access"
            ;;
    esac
    
    log_info "  Adding SSH rule: $cidr ($DESCRIPTION)"
    aws ec2 authorize-security-group-ingress \
        --group-id "$VM_SG_ID" \
        --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$cidr,Description='$DESCRIPTION'}]" \
        --region "$AWS_REGION" 2>/dev/null || log_warning "    Rule may already exist"
done

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
