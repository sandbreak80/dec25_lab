#!/bin/bash
# Setup ALB with ACM Certificate for AppDynamics VA
# This script completes the proper AWS architecture with ALB + ACM

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

export AWS_PROFILE=${AWS_PROFILE}
REGION=${AWS_REGION}

# ACM Certificate (already issued)
CERT_ARN="arn:aws:acm:us-west-2:314839308236:certificate/ce4f1e3b-0830-48f2-b187-a26c580637e0"

# Get VPC and instance details
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=cidr,Values=10.0.0.0/16" --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=cidr-block,Values=10.0.0.0/24" --query 'Subnets[0].SubnetId' --output text)

# Get instance IDs
VM1_ID=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=10.0.0.103" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
VM2_ID=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=10.0.0.56" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
VM3_ID=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=10.0.0.177" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)

echo "========================================="
echo "🏗️  Setup ALB with ACM Certificate"
echo "========================================="
echo ""
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "Instances: $VM1_ID, $VM2_ID, $VM3_ID"
echo "Certificate: $CERT_ARN"
echo ""

# Step 1: Check if we need a second subnet (ALB requires 2+ AZs)
echo "Step 1: Checking subnets for ALB..."
SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(Subnets)' --output text)

if [ "$SUBNET_COUNT" -lt 2 ]; then
  echo "⚠️  ALB requires at least 2 subnets in different AZs"
  echo "Creating second subnet..."
  
  SUBNET2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-west-2b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=appd-va-subnet-2}]' \
    --query 'Subnet.SubnetId' --output text)
  
  # Associate with route table
  RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$RT_NAME" --query 'RouteTables[0].RouteTableId' --output text)
  aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET2_ID >/dev/null
  
  echo "✅ Created subnet: $SUBNET2_ID (10.0.1.0/24 in us-west-2b)"
  echo $SUBNET2_ID > subnet2.id
  
  SUBNETS="$SUBNET_ID $SUBNET2_ID"
else
  SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
  echo "✅ Using existing subnets: $SUBNETS"
fi
echo ""

# Step 2: Create Target Group
echo "Step 2: Creating Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names appd-va-tg --region $REGION 2>/dev/null --query 'TargetGroups[0].TargetGroupArn' --output text || echo "")

if [ -z "$TG_ARN" ] || [ "$TG_ARN" == "None" ]; then
  TG_ARN=$(aws elbv2 create-target-group \
    --name appd-va-tg \
    --protocol HTTPS \
    --port 443 \
    --vpc-id $VPC_ID \
    --health-check-enabled \
    --health-check-protocol HTTPS \
    --health-check-path /controller/ \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --target-type instance \
    --region $REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
  
  # Modify matcher (separate call due to AWS CLI parsing)
  aws elbv2 modify-target-group \
    --target-group-arn $TG_ARN \
    --matcher HttpCode=200,301,302 \
    --region $REGION >/dev/null
fi

echo "✅ Target Group: $TG_ARN"
echo $TG_ARN > tg.arn
echo ""

# Step 3: Register instances
echo "Step 3: Registering instances to target group..."
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$VM1_ID Id=$VM2_ID Id=$VM3_ID \
  --region $REGION 2>/dev/null || true

echo "✅ Instances registered"
sleep 2

# Check target health
echo ""
echo "Target Health:"
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region $REGION --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
echo ""

# Step 4: Create Security Group for ALB
echo "Step 4: Creating ALB Security Group..."
ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=appd-va-alb-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")

if [ -z "$ALB_SG_ID" ] || [ "$ALB_SG_ID" == "None" ]; then
  ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name appd-va-alb-sg \
    --description "Security group for AppDynamics ALB" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' --output text)
  
  # Allow HTTPS from anywhere
  aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || true
  
  # Allow HTTP from anywhere (for redirects)
  aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || true
fi

echo "✅ ALB Security Group: $ALB_SG_ID"
echo ""

# Step 5: Update VM security group to allow traffic from ALB
echo "Step 5: Updating VM security group for ALB traffic..."
VM_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)

# Allow HTTPS from ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id $VM_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group $ALB_SG_ID \
  --region $REGION 2>/dev/null || echo "  (Rule may already exist)"

echo "✅ VM security group updated"
echo ""

# Step 6: Create ALB
echo "Step 6: Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names appd-va-alb --region $REGION 2>/dev/null --query 'LoadBalancers[0].LoadBalancerArn' --output text || echo "")

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name appd-va-alb \
    --subnets $SUBNETS \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region $REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  
  echo "✅ ALB Created: $ALB_ARN"
  echo "⏳ Waiting for ALB to become active (this takes 2-3 minutes)..."
  aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN --region $REGION
  echo "✅ ALB is now active"
else
  echo "✅ Using existing ALB: $ALB_ARN"
fi

echo $ALB_ARN > alb.arn
echo ""

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $REGION --query 'LoadBalancers[0].DNSName' --output text)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $REGION --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

echo "ALB DNS: $ALB_DNS"
echo "ALB Zone ID: $ALB_ZONE_ID"
echo ""

# Step 7: Create HTTPS Listener with ACM certificate
echo "Step 7: Creating HTTPS Listener..."
HTTPS_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $REGION 2>/dev/null --query 'Listeners[?Port==`443`].ListenerArn' --output text || echo "")

if [ -z "$HTTPS_LISTENER" ] || [ "$HTTPS_LISTENER" == "None" ]; then
  HTTPS_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=$CERT_ARN \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --region $REGION \
    --query 'Listeners[0].ListenerArn' --output text)
  echo "✅ HTTPS Listener Created: $HTTPS_LISTENER"
else
  echo "✅ Using existing HTTPS Listener: $HTTPS_LISTENER"
fi
echo ""

# Step 8: Create HTTP Listener (redirect to HTTPS)
echo "Step 8: Creating HTTP->HTTPS Redirect..."
HTTP_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $REGION 2>/dev/null --query 'Listeners[?Port==`80`].ListenerArn' --output text || echo "")

if [ -z "$HTTP_LISTENER" ] || [ "$HTTP_LISTENER" == "None" ]; then
  HTTP_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
    --region $REGION \
    --query 'Listeners[0].ListenerArn' --output text)
  echo "✅ HTTP Redirect Listener Created: $HTTP_LISTENER"
else
  echo "✅ Using existing HTTP Redirect Listener: $HTTP_LISTENER"
fi
echo ""

# Step 9: Update Route 53 DNS to point to ALB
echo "Step 9: Updating Route 53 DNS..."

cat > /tmp/route53-alb-update.json << EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "controller.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "customer1.auth.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "customer1-tnt-authn.splunkylabs.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file:///tmp/route53-alb-update.json \
  --region $REGION

echo "✅ DNS updated to point to ALB"
echo ""

# Step 10: Save configuration
cat > alb-config.txt << EOF
ALB_ARN=$ALB_ARN
ALB_DNS=$ALB_DNS
ALB_ZONE_ID=$ALB_ZONE_ID
TG_ARN=$TG_ARN
HTTPS_LISTENER=$HTTPS_LISTENER
HTTP_LISTENER=$HTTP_LISTENER
CERT_ARN=$CERT_ARN
EOF

echo "========================================="
echo "✅ ALB Setup Complete!"
echo "========================================="
echo ""
echo "📊 Summary:"
echo "  ALB DNS: $ALB_DNS"
echo "  Certificate: ACM Wildcard (*.splunkylabs.com)"
echo "  Target Group: 3 VMs"
echo "  Listeners:"
echo "    - HTTPS (443) with ACM cert"
echo "    - HTTP (80) redirects to HTTPS"
echo "  DNS: All splunkylabs.com records point to ALB"
echo ""
echo "⏳ Wait 2-3 minutes for:"
echo "  1. DNS to propagate"
echo "  2. Health checks to pass"
echo ""
echo "Then test:"
echo "  https://controller.splunkylabs.com/controller/"
echo ""
echo "Check target health:"
echo "  ./check-alb-health.sh"
echo ""
