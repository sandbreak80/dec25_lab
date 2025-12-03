#!/bin/bash
# Create VPC and Network Infrastructure for Team
# Usage: ./02-aws-create-vpc.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Create VPC, subnets, IGW, and route tables for a team.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help message

Example:
    $0 --team 1          # Create VPC for Team 1

Creates:
    - VPC with CIDR 10.N.0.0/16 (where N = team number)
    - Subnet 1 in AZ-a (10.N.0.0/24)
    - Subnet 2 in AZ-b (10.N.1.0/24)
    - Internet Gateway
    - Route Table with IGW route

EOF
}

# Parse arguments
TEAM_NUMBER=$(parse_team_number "$@")

# Load team configuration
load_team_config "$TEAM_NUMBER"

# Check AWS CLI
check_aws_cli

# Show header
show_header "Create VPC Infrastructure" "$TEAM_NUMBER"

echo "Configuration:"
echo "  VPC Name: $VPC_NAME"
echo "  VPC CIDR: $VPC_CIDR"
echo "  Subnet 1: $SUBNET_CIDR (${SUBNET_AZ})"
echo "  Subnet 2: $SUBNET2_CIDR (${SUBNET2_AZ})"
echo ""

# Step 1: Create VPC
log_info "Step 1: Creating VPC..."
if resource_exists vpc "$VPC_NAME"; then
    VPC_ID=$(get_resource_id vpc "$VPC_NAME")
    log_info "VPC already exists: $VPC_ID"
else
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block "$VPC_CIDR" \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
        --query 'Vpc.VpcId' --output text)
    
    # Enable DNS hostnames
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
    
    log_success "VPC created: $VPC_ID ($VPC_CIDR)"
    save_resource_id vpc "$VPC_ID" "$TEAM_NUMBER"
fi
echo ""

# Step 2: Create Internet Gateway
log_info "Step 2: Creating Internet Gateway..."
if resource_exists igw "$IGW_NAME"; then
    IGW_ID=$(get_resource_id igw "$IGW_NAME")
    log_info "Internet Gateway already exists: $IGW_ID"
else
    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
        --query 'InternetGateway.InternetGatewayId' --output text)
    
    # Attach to VPC
    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
    
    log_success "Internet Gateway created and attached: $IGW_ID"
    save_resource_id igw "$IGW_ID" "$TEAM_NUMBER"
fi
echo ""

# Step 3: Create Subnet 1
log_info "Step 3: Creating Subnet 1..."
if resource_exists subnet "$SUBNET_NAME"; then
    SUBNET_ID=$(get_resource_id subnet "$SUBNET_NAME")
    log_info "Subnet 1 already exists: $SUBNET_ID"
else
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$SUBNET_CIDR" \
        --availability-zone "$SUBNET_AZ" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
        --query 'Subnet.SubnetId' --output text)
    
    # Enable auto-assign public IP
    aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch
    
    log_success "Subnet 1 created: $SUBNET_ID ($SUBNET_CIDR)"
    save_resource_id subnet "$SUBNET_ID" "$TEAM_NUMBER"
fi
echo ""

# Step 4: Create Subnet 2 (for ALB - requires 2+ AZs)
log_info "Step 4: Creating Subnet 2..."
if resource_exists subnet "$SUBNET2_NAME"; then
    SUBNET2_ID=$(get_resource_id subnet "$SUBNET2_NAME")
    log_info "Subnet 2 already exists: $SUBNET2_ID"
else
    SUBNET2_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block "$SUBNET2_CIDR" \
        --availability-zone "$SUBNET2_AZ" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET2_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
        --query 'Subnet.SubnetId' --output text)
    
    # Enable auto-assign public IP
    aws ec2 modify-subnet-attribute --subnet-id "$SUBNET2_ID" --map-public-ip-on-launch
    
    log_success "Subnet 2 created: $SUBNET2_ID ($SUBNET2_CIDR)"
    save_resource_id subnet2 "$SUBNET2_ID" "$TEAM_NUMBER"
fi
echo ""

# Step 5: Create Route Table
log_info "Step 5: Creating Route Table..."
if resource_exists rt "$RT_NAME"; then
    RT_ID=$(get_resource_id rt "$RT_NAME")
    log_info "Route Table already exists: $RT_ID"
else
    RT_ID=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$RT_NAME},{Key=Team,Value=team${TEAM_NUMBER}}]" \
        --query 'RouteTable.RouteTableId' --output text)
    
    # Add route to Internet Gateway
    aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
    
    # Associate with both subnets
    aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET_ID"
    aws ec2 associate-route-table --route-table-id "$RT_ID" --subnet-id "$SUBNET2_ID"
    
    log_success "Route Table created: $RT_ID"
    save_resource_id rt "$RT_ID" "$TEAM_NUMBER"
fi
echo ""

# Mark step as complete
mark_step_complete "02-vpc-created" "$TEAM_NUMBER"

# Summary
echo "========================================="
log_success "VPC Infrastructure Created!"
echo "========================================="
echo ""
echo "📊 Resources Created:"
echo "  VPC:           $VPC_ID ($VPC_CIDR)"
echo "  IGW:           $IGW_ID"
echo "  Subnet 1:      $SUBNET_ID ($SUBNET_CIDR)"
echo "  Subnet 2:      $SUBNET2_ID ($SUBNET2_CIDR)"
echo "  Route Table:   $RT_ID"
echo ""
echo "Next step: ./03-aws-create-security-groups.sh --team $TEAM_NUMBER"
