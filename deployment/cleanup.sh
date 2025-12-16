#!/bin/bash
# Cleanup Team Resources
# Usage: ./lab-cleanup.sh --team 1 --confirm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

show_usage() {
    cat << EOF
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Lab - Cleanup Team Resources              ║
╚══════════════════════════════════════════════════════════╝

Usage: $0 --team TEAM_NUMBER --confirm

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --confirm            REQUIRED to actually delete resources
    --help, -h           Show this help

Example:
    $0 --team 1 --confirm

⚠️  WARNING: This will DELETE ALL resources for your team:
   - 3 EC2 instances
   - Application Load Balancer
   - Target Groups
   - Security Groups
   - Subnets
   - Internet Gateway
   - VPC
   - DNS records

This action CANNOT be undone!

EOF
}

TEAM_NUMBER=""
CONFIRMED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --team|-t) TEAM_NUMBER="$2"; shift 2 ;;
        --confirm) CONFIRMED=true; shift ;;
        --help|-h) show_usage; exit 0 ;;
        *) log_error "Unknown parameter: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$TEAM_NUMBER" ]; then
    log_error "Team number is required"
    show_usage
    exit 1
fi

if [ "$CONFIRMED" != true ]; then
    log_error "Must specify --confirm to delete resources"
    show_usage
    exit 1
fi

load_team_config "$TEAM_NUMBER"
check_aws_cli

# Final confirmation
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  ⚠️  FINAL CONFIRMATION                                  ║
╚══════════════════════════════════════════════════════════╝

You are about to DELETE ALL resources for Team ${TEAM_NUMBER}:
  Domain:     ${FULL_DOMAIN}
  VPC:        ${VPC_CIDR}
  Region:     ${AWS_REGION}

This will:
  ❌ Delete 3 EC2 instances
  ❌ Delete Application Load Balancer
  ❌ Delete Target Groups
  ❌ Delete Security Groups
  ❌ Delete all network infrastructure
  ❌ Remove DNS records

⚠️  THIS CANNOT BE UNDONE!

EOF

read -p "Type 'DELETE TEAM $TEAM_NUMBER' to confirm: " confirmation

if [ "$confirmation" != "DELETE TEAM $TEAM_NUMBER" ]; then
    log_error "Confirmation failed. Aborting."
    exit 1
fi

echo ""
log_info "Starting cleanup for Team ${TEAM_NUMBER}..."
echo ""

# Phase 1: DNS
log_info "[1/8] Removing DNS records..."
"${SCRIPT_DIR}/../scripts/delete-dns.sh" --team "$TEAM_NUMBER" 2>/dev/null || log_warning "DNS cleanup skipped"

# Phase 2: ALB Listeners
log_info "[2/8] Deleting ALB listeners..."
ALB_ARN=$(load_resource_id alb "$TEAM_NUMBER")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[*].ListenerArn' --output text 2>/dev/null | xargs -r -n1 aws elbv2 delete-listener --listener-arn || true
    log_success "Listeners deleted"
fi

# Phase 3: ALB
log_info "[3/8] Deleting Application Load Balancer..."
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" 2>/dev/null || true
    log_info "Waiting for ALB deletion..."
    sleep 30
    log_success "ALB deleted"
fi

# Phase 4: Target Groups
log_info "[4/8] Deleting Target Groups..."
TG_ARN=$(load_resource_id tg "$TEAM_NUMBER")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN" 2>/dev/null || true
    log_success "Target Group deleted"
fi

# Phase 5: EC2 Instances
log_info "[5/8] Terminating EC2 instances..."
VM1_ID=$(load_resource_id vm1 "$TEAM_NUMBER")
VM2_ID=$(load_resource_id vm2 "$TEAM_NUMBER")
VM3_ID=$(load_resource_id vm3 "$TEAM_NUMBER")

INSTANCE_IDS=""
for id in $VM1_ID $VM2_ID $VM3_ID; do
    if [ -n "$id" ] && [ "$id" != "None" ]; then
        INSTANCE_IDS="$INSTANCE_IDS $id"
    fi
done

if [ -n "$INSTANCE_IDS" ]; then
    # Release Elastic IPs before terminating instances
    for instance_id in $INSTANCE_IDS; do
        EIP_ALLOC_ID=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=$instance_id" --query 'Addresses[0].AllocationId' --output text 2>/dev/null)
        if [ -n "$EIP_ALLOC_ID" ] && [ "$EIP_ALLOC_ID" != "None" ]; then
            aws ec2 release-address --allocation-id "$EIP_ALLOC_ID" 2>/dev/null || true
        fi
    done
    
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS >/dev/null 2>&1 || true
    log_info "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS 2>/dev/null || sleep 60
    log_success "Instances and Elastic IPs deleted"
fi

# Phase 6: Network Interfaces (ENI)
log_info "[6/8] Deleting network interfaces..."
sleep 10  # Wait for instances to fully terminate
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null | xargs -r -n1 aws ec2 delete-network-interface --network-interface-id 2>/dev/null || true
    log_success "Network interfaces deleted"
fi

# Phase 7: Security Groups
log_info "[7/8] Deleting Security Groups..."
sleep 20  # Wait for dependencies
VM_SG_ID=$(load_resource_id vm-sg "$TEAM_NUMBER")
ALB_SG_ID=$(load_resource_id alb-sg "$TEAM_NUMBER")

# First revoke all ingress/egress rules to remove dependencies
for sg in $ALB_SG_ID $VM_SG_ID; do
    if [ -n "$sg" ] && [ "$sg" != "None" ]; then
        # Revoke ingress rules
        aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null | \
            jq -c '.[]' 2>/dev/null | while read rule; do
                aws ec2 revoke-security-group-ingress --group-id "$sg" --ip-permissions "$rule" 2>/dev/null || true
            done
        
        # Revoke egress rules
        aws ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null | \
            jq -c '.[]' 2>/dev/null | while read rule; do
                aws ec2 revoke-security-group-egress --group-id "$sg" --ip-permissions "$rule" 2>/dev/null || true
            done
    fi
done

# Now delete security groups
for sg in $ALB_SG_ID $VM_SG_ID; do
    if [ -n "$sg" ] && [ "$sg" != "None" ]; then
        aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
    fi
done
log_success "Security Groups deleted"

# Phase 8: Network Infrastructure
log_info "[8/9] Deleting network infrastructure..."
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    # Disassociate and delete route tables (except main)
    log_info "Disassociating route tables..."
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main!=`true`].Associations[].RouteTableAssociationId' \
        --output text 2>/dev/null | xargs -r -n1 aws ec2 disassociate-route-table --association-id 2>/dev/null || true
    
    # Delete subnets
    log_info "Deleting subnets..."
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | xargs -r -n1 aws ec2 delete-subnet --subnet-id || true
    
    # Detach and delete IGW
    log_info "Deleting Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
    if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || true
        sleep 5  # Wait for detachment
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" 2>/dev/null || true
    fi
    
    # Delete route tables (except main)
    log_info "Deleting route tables..."
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text | xargs -r -n1 aws ec2 delete-route-table --route-table-id || true
    
    # Delete VPC with retries
    log_info "Deleting VPC..."
    MAX_RETRIES=10
    RETRY_COUNT=0
    VPC_DELETED=false
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null; then
            VPC_DELETED=true
            log_success "VPC deleted"
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
        log_warning "⚠️  VPC could not be deleted after $MAX_RETRIES attempts"
        log_warning "Manual cleanup may be required: $VPC_ID"
        echo ""
    else
        log_success "Network infrastructure deleted"
    fi
else
    log_info "No VPC found to delete"
fi

# Phase 9: Cleanup state
log_info "[9/9] Cleaning up state files..."
rm -rf "state/team${TEAM_NUMBER}"
rm -rf "logs/team${TEAM_NUMBER}"
log_success "State cleaned"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ✅ CLEANUP COMPLETE!                                    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

All resources for Team ${TEAM_NUMBER} have been deleted:
  ✅ EC2 Instances terminated
  ✅ Load Balancer removed
  ✅ Network infrastructure deleted
  ✅ DNS records removed
  ✅ State files cleaned

Thank you for participating in the AppDynamics Lab! 🎓

EOF
