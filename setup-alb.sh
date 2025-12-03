#!/bin/bash
# Setup ALB with ACM Certificate for AppDynamics VA

set -e

export AWS_PROFILE=va-deployment
REGION=us-west-2

VPC_ID="vpc-092e8c8ba20e21e94"
SUBNET_ID="subnet-080c729506fb972c4"
CERT_ARN="arn:aws:acm:us-west-2:314839308236:certificate/ce4f1e3b-0830-48f2-b187-a26c580637e0"
HOSTED_ZONE_ID="Z06491142QTF1FNN8O9PR"
DOMAIN="splunkylabs.com"

INSTANCE_IDS="i-07efdcf48080a392c i-0cba6c10c4ac9b7ca i-0db2c8c6ed09a235f"

echo "========================================="
echo "🏗️  Setup ALB with ACM Certificate"
echo "========================================="
echo ""

# Step 1: Create Target Group
echo "Step 1: Creating Target Group..."
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
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
  aws elbv2 describe-target-groups --names appd-va-tg --region $REGION --query 'TargetGroups[0].TargetGroupArn' --output text)

echo "✅ Target Group: $TG_ARN"
echo ""

# Set matcher separately
aws elbv2 modify-target-group \
  --target-group-arn $TG_ARN \
  --matcher HttpCode="200,301,302" \
  --region $REGION >/dev/null

# Step 2: Register instances
echo "Step 2: Registering instances..."
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets $(for id in $INSTANCE_IDS; do echo "Id=$id"; done | tr '\n' ' ') \
  --region $REGION

echo "✅ Instances registered"
echo ""

# Step 3: Get all subnets in VPC (ALB needs at least 2)
echo "Step 3: Finding subnets for ALB..."
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' --output text)

if [ $(echo $SUBNETS | wc -w) -lt 2 ]; then
  echo "⚠️  ALB requires at least 2 subnets in different AZs"
  echo "Creating additional subnet..."
  
  SUBNET2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone us-west-2a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=appd-va-subnet-2}]' \
    --query 'Subnet.SubnetId' --output text)
  
  SUBNETS="$SUBNET_ID $SUBNET2_ID"
  echo "✅ Created subnet: $SUBNET2_ID"
fi

echo "Using subnets: $SUBNETS"
echo ""

# Step 4: Create Security Group for ALB
echo "Step 4: Creating ALB Security Group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name appd-va-alb-sg \
  --description "Security group for AppDynamics ALB" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups --filters "Name=group-name,Values=appd-va-alb-sg" --query 'SecurityGroups[0].GroupId' --output text)

# Allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || true

# Allow HTTP (for redirects)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || true

echo "✅ Security Group: $SG_ID"
echo ""

# Step 5: Create ALB
echo "Step 5: Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name appd-va-alb \
  --subnets $SUBNETS \
  --security-groups $SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
  aws elbv2 describe-load-balancers --names appd-va-alb --region $REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)

echo "✅ ALB ARN: $ALB_ARN"
echo ""

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $REGION --query 'LoadBalancers[0].DNSName' --output text)
echo "ALB DNS: $ALB_DNS"
echo ""

# Step 6: Create HTTPS Listener with ACM certificate
echo "Step 6: Creating HTTPS Listener..."
HTTPS_LISTENER=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION \
  --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || \
  aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $REGION --query 'Listeners[?Port==`443`].ListenerArn' --output text)

echo "✅ HTTPS Listener: $HTTPS_LISTENER"
echo ""

# Step 7: Create HTTP Listener (redirect to HTTPS)
echo "Step 7: Creating HTTP->HTTPS Redirect..."
HTTP_LISTENER=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
  --region $REGION \
  --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || \
  aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --region $REGION --query 'Listeners[?Port==`80`].ListenerArn' --output text)

echo "✅ HTTP Redirect Listener: $HTTP_LISTENER"
echo ""

# Step 8: Update Route 53 DNS
echo "Step 8: Updating Route 53 DNS..."

# Get ALB Hosted Zone ID
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $REGION --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

# Update DNS records to point to ALB
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
  --change-batch file:///tmp/route53-alb-update.json

echo "✅ DNS updated to point to ALB"
echo ""

echo "========================================="
echo "✅ ALB Setup Complete!"
echo "========================================="
echo ""
echo "📊 Summary:"
echo "  ALB DNS: $ALB_DNS"
echo "  Certificate: ACM Wildcard (*.splunkylabs.com)"
echo "  Target Group: 3 VMs"
echo "  Listeners: HTTPS (443) + HTTP->HTTPS (80)"
echo "  DNS: All splunkylabs.com records point to ALB"
echo ""
echo "⏳ Wait 2-3 minutes for:"
echo "  1. ALB to become active"
echo "  2. DNS to propagate"
echo "  3. Health checks to pass"
echo ""
echo "Then test:"
echo "  https://controller.splunkylabs.com/controller/"
echo ""
