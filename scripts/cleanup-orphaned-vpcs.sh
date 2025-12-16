#!/bin/bash
# One-time cleanup script for orphaned VPCs
# This will delete ALL specified VPCs and their associated resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# VPCs to delete
VPCS=(
    "vpc-092e8c8ba20e21e94:Old-VA-Infrastructure"
    "vpc-0d45d63936228e50a:Team-5-Duplicate-1"
    "vpc-0d5f87043fed4ed13:Team-5-Duplicate-2"
    "vpc-06d408de34edce3e9:Team-4-Orphaned"
    "vpc-087cd9639a7816b8e:Team-3-Orphaned"
    "vpc-09eae48c62d7ad537:Team-2-Orphaned"
)

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-west-2}"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║   Cleanup Orphaned VPCs and Resources                   ║
╚══════════════════════════════════════════════════════════╝

This will DELETE the following VPCs and ALL their resources:
EOF

for vpc_entry in "${VPCS[@]}"; do
    vpc_id="${vpc_entry%%:*}"
    vpc_name="${vpc_entry##*:}"
    echo "  - $vpc_id ($vpc_name)"
done

echo ""
log_warning "This action CANNOT be undone!"
echo ""
read -p "Type 'DELETE ALL' to proceed: " confirmation

if [ "$confirmation" != "DELETE ALL" ]; then
    log_error "Confirmation failed. Exiting."
    exit 1
fi

echo ""
log_info "Starting cleanup with profile: $AWS_PROFILE"

cleanup_vpc() {
    local vpc_id=$1
    local vpc_name=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Cleaning VPC: $vpc_id ($vpc_name)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if VPC exists
    if ! aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_warning "VPC $vpc_id does not exist, skipping"
        return
    fi
    
    # 1. Delete Load Balancers
    log_info "Deleting load balancers..."
    aws elbv2 describe-load-balancers --region "$AWS_REGION" 2>/dev/null | \
        jq -r --arg vpc "$vpc_id" '.LoadBalancers[] | select(.VpcId == $vpc) | .LoadBalancerArn' 2>/dev/null | \
        while read alb_arn; do
            if [ -n "$alb_arn" ]; then
                log_info "  Deleting ALB: $alb_arn"
                aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --region "$AWS_REGION" 2>/dev/null || true
            fi
        done
    
    # Wait for ALBs to delete
    sleep 10
    
    # 2. Delete Target Groups
    log_info "Deleting target groups..."
    aws elbv2 describe-target-groups --region "$AWS_REGION" 2>/dev/null | \
        jq -r --arg vpc "$vpc_id" '.TargetGroups[] | select(.VpcId == $vpc) | .TargetGroupArn' 2>/dev/null | \
        while read tg_arn; do
            if [ -n "$tg_arn" ]; then
                log_info "  Deleting TG: $tg_arn"
                aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region "$AWS_REGION" 2>/dev/null || true
            fi
        done
    
    # 3. Terminate EC2 instances
    log_info "Terminating EC2 instances..."
    instance_ids=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped,pending,stopping" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$instance_ids" ]; then
        for instance_id in $instance_ids; do
            log_info "  Terminating: $instance_id"
            # Release EIPs first
            eip_alloc_id=$(aws ec2 describe-addresses \
                --filters "Name=instance-id,Values=$instance_id" \
                --query 'Addresses[0].AllocationId' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null)
            
            if [ -n "$eip_alloc_id" ] && [ "$eip_alloc_id" != "None" ]; then
                log_info "  Releasing EIP: $eip_alloc_id"
                aws ec2 release-address --allocation-id "$eip_alloc_id" --region "$AWS_REGION" 2>/dev/null || true
            fi
        done
        
        aws ec2 terminate-instances --instance-ids $instance_ids --region "$AWS_REGION" >/dev/null 2>&1 || true
        log_info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $instance_ids --region "$AWS_REGION" 2>/dev/null || sleep 60
    fi
    
    # 4. Delete NAT Gateways
    log_info "Deleting NAT gateways..."
    nat_gw_ids=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available,pending" \
        --query 'NatGateways[*].NatGatewayId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$nat_gw_ids" ]; then
        for nat_id in $nat_gw_ids; do
            log_info "  Deleting NAT Gateway: $nat_id"
            aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region "$AWS_REGION" 2>/dev/null || true
        done
        log_info "Waiting for NAT gateways to delete..."
        sleep 30
    fi
    
    # 5. Delete Network Interfaces
    log_info "Deleting network interfaces..."
    sleep 10  # Wait for instances to fully terminate
    eni_ids=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$eni_ids" ]; then
        for eni_id in $eni_ids; do
            log_info "  Deleting ENI: $eni_id"
            aws ec2 delete-network-interface --network-interface-id "$eni_id" --region "$AWS_REGION" 2>/dev/null || true
        done
    fi
    
    # 6. Delete Security Groups (revoke rules first)
    log_info "Deleting security groups..."
    sleep 20  # Wait for dependencies
    
    sg_ids=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$sg_ids" ]; then
        for sg_id in $sg_ids; do
            log_info "  Revoking rules for SG: $sg_id"
            
            # Revoke ingress rules
            aws ec2 describe-security-groups --group-ids "$sg_id" --region "$AWS_REGION" 2>/dev/null | \
                jq -c '.SecurityGroups[0].IpPermissions[]' 2>/dev/null | \
                while read rule; do
                    aws ec2 revoke-security-group-ingress --group-id "$sg_id" --ip-permissions "$rule" --region "$AWS_REGION" 2>/dev/null || true
                done
            
            # Revoke egress rules
            aws ec2 describe-security-groups --group-ids "$sg_id" --region "$AWS_REGION" 2>/dev/null | \
                jq -c '.SecurityGroups[0].IpPermissionsEgress[]' 2>/dev/null | \
                while read rule; do
                    aws ec2 revoke-security-group-egress --group-id "$sg_id" --ip-permissions "$rule" --region "$AWS_REGION" 2>/dev/null || true
                done
        done
        
        # Now delete security groups
        for sg_id in $sg_ids; do
            log_info "  Deleting SG: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" --region "$AWS_REGION" 2>/dev/null || true
        done
    fi
    
    # 7. Disassociate and delete route tables
    log_info "Deleting route tables..."
    
    # Disassociate first
    aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'RouteTables[?Associations[0].Main!=`true`].Associations[].RouteTableAssociationId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null | \
        xargs -r -n1 -I {} aws ec2 disassociate-route-table --association-id {} --region "$AWS_REGION" 2>/dev/null || true
    
    # Delete route tables
    rt_ids=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$rt_ids" ]; then
        for rt_id in $rt_ids; do
            log_info "  Deleting Route Table: $rt_id"
            aws ec2 delete-route-table --route-table-id "$rt_id" --region "$AWS_REGION" 2>/dev/null || true
        done
    fi
    
    # 8. Delete subnets
    log_info "Deleting subnets..."
    subnet_ids=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$subnet_ids" ]; then
        for subnet_id in $subnet_ids; do
            log_info "  Deleting Subnet: $subnet_id"
            aws ec2 delete-subnet --subnet-id "$subnet_id" --region "$AWS_REGION" 2>/dev/null || true
        done
    fi
    
    # 9. Detach and delete Internet Gateway
    log_info "Deleting Internet Gateway..."
    igw_id=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$vpc_id" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null)
    
    if [ -n "$igw_id" ] && [ "$igw_id" != "None" ]; then
        log_info "  Detaching IGW: $igw_id"
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" --region "$AWS_REGION" 2>/dev/null || true
        sleep 5
        log_info "  Deleting IGW: $igw_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region "$AWS_REGION" 2>/dev/null || true
    fi
    
    # 10. Delete VPC with retries
    log_info "Deleting VPC..."
    MAX_RETRIES=10
    RETRY_COUNT=0
    VPC_DELETED=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if aws ec2 delete-vpc --vpc-id "$vpc_id" --region "$AWS_REGION" 2>/dev/null; then
            VPC_DELETED=true
            log_success "VPC $vpc_id deleted successfully!"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                log_info "VPC has dependencies, retrying in 10 seconds... (attempt $RETRY_COUNT/$MAX_RETRIES)"
                sleep 10
            fi
        fi
    done
    
    if [ "$VPC_DELETED" = false ]; then
        log_error "VPC $vpc_id could not be deleted after $MAX_RETRIES attempts"
        log_warning "Manual cleanup may be required"
    fi
}

# Cleanup each VPC
for vpc_entry in "${VPCS[@]}"; do
    vpc_id="${vpc_entry%%:*}"
    vpc_name="${vpc_entry##*:}"
    cleanup_vpc "$vpc_id" "$vpc_name"
done

# Also check for and delete orphaned EIPs
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Checking for orphaned Elastic IPs..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

orphaned_eips=$(aws ec2 describe-addresses \
    --query 'Addresses[?AssociationId==`null`].[AllocationId,PublicIp,Tags[?Key==`Name`].Value|[0]]' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

if [ -n "$orphaned_eips" ]; then
    echo "$orphaned_eips" | while read alloc_id public_ip name; do
        log_info "Found orphaned EIP: $public_ip ($alloc_id) - $name"
        read -p "Delete this EIP? (y/n): " delete_eip
        if [ "$delete_eip" = "y" ]; then
            aws ec2 release-address --allocation-id "$alloc_id" --region "$AWS_REGION" 2>/dev/null || true
            log_success "Released EIP: $public_ip"
        fi
    done
else
    log_success "No orphaned EIPs found"
fi

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ ORPHANED RESOURCE CLEANUP COMPLETE!                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

All orphaned VPCs and their resources have been processed.

EOF

log_info "Cleanup completed at $(date)"

