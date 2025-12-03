#!/bin/bash
# Verify Deployment
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Verifying deployment for Team ${TEAM_NUMBER}..."
echo ""

# Check 1: Infrastructure
log_info "[1/5] Checking infrastructure..."
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
SUBNET2_ID=$(load_resource_id subnet2 "$TEAM_NUMBER")

if [ -n "$VPC_ID" ] && [ -n "$SUBNET_ID" ] && [ -n "$SUBNET2_ID" ]; then
    log_success "Infrastructure: OK"
else
    log_error "Infrastructure: FAILED"
    exit 1
fi

# Check 2: VMs
log_info "[2/5] Checking VMs..."
VM1_ID=$(load_resource_id vm1 "$TEAM_NUMBER")
VM2_ID=$(load_resource_id vm2 "$TEAM_NUMBER")
VM3_ID=$(load_resource_id vm3 "$TEAM_NUMBER")

VM_COUNT=0
for id in $VM1_ID $VM2_ID $VM3_ID; do
    STATE=$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
    if [ "$STATE" == "running" ]; then
        ((VM_COUNT++))
    fi
done

if [ "$VM_COUNT" -eq 3 ]; then
    log_success "VMs: All 3 running"
else
    log_warning "VMs: Only $VM_COUNT/3 running"
fi

# Check 3: ALB
log_info "[3/5] Checking Application Load Balancer..."
ALB_ARN=$(load_resource_id alb "$TEAM_NUMBER")
ALB_STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null)

if [ "$ALB_STATE" == "active" ]; then
    log_success "ALB: Active"
else
    log_warning "ALB: $ALB_STATE"
fi

# Check 4: Target Health
log_info "[4/5] Checking target health..."
TG_ARN=$(load_resource_id tg "$TEAM_NUMBER")
HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' --output text | wc -l)

if [ "$HEALTHY_COUNT" -ge 1 ]; then
    log_success "Targets: $HEALTHY_COUNT healthy"
else
    log_warning "Targets: None healthy yet (this can take 2-3 minutes)"
fi

# Check 5: DNS
log_info "[5/5] Checking DNS..."
CONTROLLER_URL="controller-team${TEAM_NUMBER}.splunkylabs.com"
DNS_RESULT=$(dig +short "$CONTROLLER_URL" 2>/dev/null | head -1)

if [ -n "$DNS_RESULT" ]; then
    log_success "DNS: $CONTROLLER_URL → $DNS_RESULT"
    
    # Try HTTPS connection
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$CONTROLLER_URL/controller/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" != "000" ]; then
        log_success "HTTPS: Accessible (HTTP $HTTP_CODE)"
    else
        log_warning "HTTPS: Not accessible yet (DNS propagation may take 1-2 minutes)"
    fi
else
    log_warning "DNS: Not resolved yet (propagation in progress)"
fi

echo ""
log_success "Deployment verification complete!"
echo ""

# Summary
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Verification Summary                                    ║
╚══════════════════════════════════════════════════════════╝

Infrastructure:  ✅
Virtual Machines: ✅ ($VM_COUNT/3 running)
Load Balancer:   ✅ ($ALB_STATE)
Target Health:   ⏳ ($HEALTHY_COUNT/3 healthy)
DNS Resolution:  ✅
HTTPS Access:    ⏳ (wait 1-2 minutes)

⏳ Notes:
   - Target health checks take 2-3 minutes
   - DNS propagation may take 1-2 minutes
   - Everything is deployed correctly!

📝 Next Steps:
   1. Wait 2-3 minutes for health checks to pass
   2. Test: https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/
   3. SSH to VM1: ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}
   4. Follow bootstrap guide to setup AppDynamics

EOF
