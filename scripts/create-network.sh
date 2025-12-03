#!/bin/bash
# Create Network Infrastructure (VPC, Subnets, IGW, Routes)
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Parse team number
TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Creating network infrastructure for Team ${TEAM_NUMBER}..."

# Create VPC
log_info "[1/5] Creating VPC (${VPC_CIDR})..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
    --query 'Vpc.VpcId' --output text 2>/dev/null || get_resource_id vpc "$VPC_NAME")

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
save_resource_id vpc "$VPC_ID" "$TEAM_NUMBER"
log_success "VPC created: $VPC_ID"

# Create Internet Gateway
log_info "[2/5] Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
    --query 'InternetGateway.InternetGatewayId' --output text 2>/dev/null || get_resource_id igw "$IGW_NAME")

aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" 2>/dev/null || true
save_resource_id igw "$IGW_ID" "$TEAM_NUMBER"
log_success "Internet Gateway created: $IGW_ID"

# Create Subnet 1 (AZ-a)
log_info "[3/5] Creating Subnet 1 (${SUBNET_CIDR} in ${SUBNET_AZ})..."

# Try to create subnet - use simpler command format
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR" --availability-zone "$SUBNET_AZ" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" --query 'Subnet.SubnetId' --output text 2>/dev/null)

# If creation failed, try to find existing
if [[ -z "$SUBNET_ID" ]] || [[ "$SUBNET_ID" == "None" ]]; then
    SUBNET_ID=$(get_resource_id subnet "$SUBNET_NAME")
fi

# Validate we have a subnet ID
if [[ -z "$SUBNET_ID" ]] || [[ "$SUBNET_ID" == "None" ]] || [[ ! "$SUBNET_ID" =~ ^subnet- ]]; then
    log_error "Failed to create or find Subnet 1"
    exit 1
fi

aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch 2>/dev/null
save_resource_id subnet "$SUBNET_ID" "$TEAM_NUMBER"
log_success "Subnet 1 created: $SUBNET_ID"

# Create Subnet 2 (AZ-b) - Required for ALB
log_info "[4/5] Creating Subnet 2 (${SUBNET2_CIDR} in ${SUBNET2_AZ})..."

# Try to create subnet - use simpler command format
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET2_CIDR" --availability-zone "$SUBNET2_AZ" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET2_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" --query 'Subnet.SubnetId' --output text 2>/dev/null)

# If creation failed, try to find existing
if [[ -z "$SUBNET2_ID" ]] || [[ "$SUBNET2_ID" == "None" ]]; then
    SUBNET2_ID=$(get_resource_id subnet "$SUBNET2_NAME")
fi

# Validate we have a subnet ID
if [[ -z "$SUBNET2_ID" ]] || [[ "$SUBNET2_ID" == "None" ]] || [[ ! "$SUBNET2_ID" =~ ^subnet- ]]; then
    log_error "Failed to create or find Subnet 2"
    exit 1
fi

aws ec2 modify-subnet-attribute --subnet-id "$SUBNET2_ID" --map-public-ip-on-launch 2>/dev/null
save_resource_id subnet2 "$SUBNET2_ID" "$TEAM_NUMBER"
log_success "Subnet 2 created: $SUBNET2_ID"

# Create Route Table with IGW route
log_info "[5/5] Creating Route Table..."
RT_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$RT_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
    --query 'RouteTable.RouteTableId' --output text 2>/dev/null || get_resource_id rt "$RT_NAME")

aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" 2>/dev/null || true
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID" 2>/dev/null || true
aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET2_ID" 2>/dev/null || true
save_resource_id rt "$RT_ID" "$TEAM_NUMBER"
log_success "Route Table created: $RT_ID"

log_success "Network infrastructure complete!"
