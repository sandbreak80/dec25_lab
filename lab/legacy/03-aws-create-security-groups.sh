#!/bin/bash
# Create Security Groups for Team
# Usage: ./03-aws-create-security-groups.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Create security groups for team VMs and ALB.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help message

Example:
    $0 --team 1          # Create security groups for Team 1

Creates:
    - VM Security Group (SSH, HTTPS from ALB)
    - ALB Security Group (HTTP/HTTPS from internet)

EOF
}

# Parse arguments
TEAM_NUMBER=$(parse_team_number "$@")

# Load team configuration
load_team_config "$TEAM_NUMBER"

# Check AWS CLI
check_aws_cli

# Show header
show_header "Create Security Groups" "$TEAM_NUMBER"

# Get VPC ID
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
if [ -z "$VPC_ID" ]; then
    VPC_ID=$(get_resource_id vpc "$VPC_NAME")
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    log_error "VPC not found. Run: ./02-aws-create-vpc.sh --team $TEAM_NUMBER"
    exit 1
fi

log_info "Using VPC: $VPC_ID"
echo ""

# Step 1: Create VM Security Group
log_info "Step 1: Creating VM Security Group..."
if resource_exists sg "$SG_NAME"; then
    VM_SG_ID=$(get_resource_id sg "$SG_NAME")
    log_info "VM Security Group already exists: $VM_SG_ID"
else
    VM_SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "Security group for Team $TEAM_NUMBER AppDynamics VMs" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' --output text)
    
    log_success "VM Security Group created: $VM_SG_ID"
    save_resource_id vm-sg "$VM_SG_ID" "$TEAM_NUMBER"
fi

# Add SSH rule (from instructor IP only)
log_info "Adding SSH rule (restricted to instructor IP)..."
aws ec2 authorize-security-group-ingress \
    --group-id "$VM_SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${INSTRUCTOR_IP}" 2>/dev/null || echo "  (Rule may already exist)"

# Add HTTPS rule (will add ALB SG later)
log_info "VM Security Group configured"
echo ""

# Step 2: Create ALB Security Group
log_info "Step 2: Creating ALB Security Group..."
if resource_exists sg "$ALB_SG_NAME"; then
    ALB_SG_ID=$(get_resource_id sg "$ALB_SG_NAME")
    log_info "ALB Security Group already exists: $ALB_SG_ID"
else
    ALB_SG_ID=$(aws ec2 create-security-group \
        --group-name "$ALB_SG_NAME" \
        --description "Security group for Team $TEAM_NUMBER ALB" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' --output text)
    
    log_success "ALB Security Group created: $ALB_SG_ID"
    save_resource_id alb-sg "$ALB_SG_ID" "$TEAM_NUMBER"
fi

# Add HTTPS rule (from anywhere)
log_info "Adding HTTPS rule (from anywhere)..."
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 2>/dev/null || echo "  (Rule may already exist)"

# Add HTTP rule (from anywhere - for redirect)
log_info "Adding HTTP rule (from anywhere)..."
aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 2>/dev/null || echo "  (Rule may already exist)"

log_success "ALB Security Group configured"
echo ""

# Step 3: Allow HTTPS from ALB to VMs
log_info "Step 3: Allowing HTTPS traffic from ALB to VMs..."
aws ec2 authorize-security-group-ingress \
    --group-id "$VM_SG_ID" \
    --protocol tcp \
    --port 443 \
    --source-group "$ALB_SG_ID" 2>/dev/null || echo "  (Rule may already exist)"

log_success "VM Security Group allows HTTPS from ALB"
echo ""

# Mark step as complete
mark_step_complete "03-security-groups-created" "$TEAM_NUMBER"

# Summary
echo "========================================="
log_success "Security Groups Created!"
echo "========================================="
echo ""
echo "📊 Resources Created:"
echo "  VM Security Group:  $VM_SG_ID"
echo "    - SSH from:       ${INSTRUCTOR_IP}"
echo "    - HTTPS from:     ALB ($ALB_SG_ID)"
echo ""
echo "  ALB Security Group: $ALB_SG_ID"
echo "    - HTTP from:      0.0.0.0/0"
echo "    - HTTPS from:     0.0.0.0/0"
echo ""
echo "Next step: ./04-aws-import-ami.sh --team $TEAM_NUMBER"
