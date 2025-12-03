#!/usr/bin/env bash

# Update security group to restrict SSH to current public IP

source config.cfg

echo "========================================="
echo "Restrict SSH Access to Your IP Only"
echo "========================================="

# Get current public IP
MY_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')
if [ -z "$MY_IP" ]; then
    echo "❌ Could not determine your public IP"
    exit 1
fi

echo "Your current public IP: $MY_IP"
echo ""

# Get security group ID
SG_ID=$(aws --profile ${AWS_PROFILE} ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=${SG_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

if [ -z "$SG_ID" ]; then
    echo "❌ Security group not found: $SG_NAME"
    exit 1
fi

echo "Security Group: $SG_ID"
echo ""

# Remove any existing SSH rules
echo "Removing open SSH access rules..."
aws --profile ${AWS_PROFILE} ec2 revoke-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 2>/dev/null && echo "  Removed 0.0.0.0/0" || echo "  No rule found for 0.0.0.0/0"

# Add SSH rule for only your IP
echo "Adding SSH access for your IP only..."
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 \
    --query 'SecurityGroupRules[0].{Rule:SecurityGroupRuleId,CIDR:CidrIpv4}' \
    --output table

echo ""
echo "✅ SSH access restricted to: $MY_IP/32"
echo ""
echo "⚠️  Note: If your IP changes, run this script again"
echo "   Or manually update in AWS Console → EC2 → Security Groups"
