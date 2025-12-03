#!/bin/bash
# Create Application Load Balancer with SSL
# Internal script - called by lab-deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

log_info "Creating Application Load Balancer for Team ${TEAM_NUMBER}..."

# Get resources
VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
SUBNET2_ID=$(load_resource_id subnet2 "$TEAM_NUMBER")
ALB_SG_ID=$(load_resource_id alb-sg "$TEAM_NUMBER")

# Get shared ACM certificate
CERT_ARN="arn:aws:acm:us-west-2:314839308236:certificate/ce4f1e3b-0830-48f2-b187-a26c580637e0"

# Step 1: Create Target Group
log_info "[1/5] Creating Target Group..."

# Try to create target group
TG_ARN=$(aws elbv2 create-target-group \
    --name "$TARGET_GROUP_NAME" \
    --protocol HTTPS \
    --port 443 \
    --vpc-id "$VPC_ID" \
    --health-check-protocol HTTPS \
    --health-check-path /controller/ \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --target-type instance \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

# If creation failed, find existing target group
if [[ -z "$TG_ARN" ]] || [[ "$TG_ARN" == "None" ]]; then
    TG_ARN=$(aws elbv2 describe-target-groups \
        --names "$TARGET_GROUP_NAME" \
        --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
fi

# Validate we have a TG ARN
if [[ -z "$TG_ARN" ]] || [[ "$TG_ARN" == "None" ]]; then
    log_error "Failed to create or find Target Group"
    exit 1
fi

# Set matcher (idempotent - safe to run multiple times)
aws elbv2 modify-target-group \
    --target-group-arn "$TG_ARN" \
    --matcher HttpCode=200,301,302,405 \
    >/dev/null 2>&1 || true

save_resource_id tg "$TG_ARN" "$TEAM_NUMBER"
log_success "Target Group: $TG_ARN"

# Step 2: Register VMs to Target Group
log_info "[2/5] Registering VMs to Target Group..."
VM1_ID=$(load_resource_id vm1 "$TEAM_NUMBER")
VM2_ID=$(load_resource_id vm2 "$TEAM_NUMBER")
VM3_ID=$(load_resource_id vm3 "$TEAM_NUMBER")

aws elbv2 register-targets \
    --target-group-arn "$TG_ARN" \
    --targets Id=$VM1_ID Id=$VM2_ID Id=$VM3_ID \
    2>/dev/null || true

log_success "VMs registered to target group"

# Step 3: Create ALB
log_info "[3/5] Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$SUBNET_ID" "$SUBNET2_ID" \
    --security-groups "$ALB_SG_ID" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || get_resource_id alb "$ALB_NAME")

save_resource_id alb "$ALB_ARN" "$TEAM_NUMBER"

# Wait for ALB to be active
log_info "Waiting for ALB to become active (2-3 minutes)..."
aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].DNSName' --output text)

ALB_ZONE=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

echo "$ALB_DNS" > "state/team${TEAM_NUMBER}/alb-dns.txt"
echo "$ALB_ZONE" > "state/team${TEAM_NUMBER}/alb-zone.txt"

log_success "ALB active: $ALB_DNS"

# Step 4: Create HTTPS Listener
log_info "[4/5] Creating HTTPS Listener..."
HTTPS_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=$CERT_ARN \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || \
    aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`443`].ListenerArn' --output text)

log_success "HTTPS Listener: $HTTPS_LISTENER"

# Step 5: Create HTTP Listener (redirect)
log_info "[5/5] Creating HTTP→HTTPS Redirect..."
HTTP_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
    --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || \
    aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`80`].ListenerArn' --output text)

log_success "HTTP Redirect Listener: $HTTP_LISTENER"

log_success "ALB configuration complete!"
log_info "ALB DNS: $ALB_DNS"
log_info "Certificate: *.splunkylabs.com (ACM)"
