#!/usr/bin/env bash

# Create security group for AppDynamics VA

source config.cfg

echo "========================================="
echo "Creating Security Group"
echo "========================================="

# Get VPC ID
vpcID=$(aws --profile ${AWS_PROFILE} ec2 describe-vpcs --output text \
    --filters Name=tag-value,Values=${VPC_NAME} --query 'Vpcs[*].VpcId')

if [ -z "$vpcID" ]; then
    echo "❌ VPC not found: $VPC_NAME"
    exit 1
fi

echo "VPC ID: $vpcID"

# Check if security group exists
sgID=$(aws --profile ${AWS_PROFILE} ec2 describe-security-groups --output text \
    --filters Name=tag-value,Values="${SG_NAME}" --query 'SecurityGroups[*].GroupId')

if [ -n "$sgID" ]; then
    echo "✅ Security group already exists: $SG_NAME ($sgID)"
    exit 0
fi

# Create security group
echo "Creating security group: $SG_NAME"
sgID=$(aws --profile ${AWS_PROFILE} ec2 create-security-group \
    --group-name "${SG_NAME}" \
    --description "Security group for AppDynamics Virtual Appliance" \
    --vpc-id "${vpcID}" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${SG_NAME}},${TAGS}]" \
    --query 'GroupId' \
    --output text)

if [ -z "$sgID" ]; then
    echo "❌ Failed to create security group"
    exit 1
fi

echo "✅ Security group created: $sgID"

# Add ingress rules
echo "Adding security group rules..."

# SSH
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id "$sgID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

# HTTPS
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id "$sgID" \
    --protocol tcp --port 443 --cidr 0.0.0.0/0

# HTTP (for redirect)
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id "$sgID" \
    --protocol tcp --port 80 --cidr 0.0.0.0/0

# Controller UI
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id "$sgID" \
    --protocol tcp --port 8090 --cidr 0.0.0.0/0

# Allow all traffic within security group (for cluster communication)
aws --profile ${AWS_PROFILE} ec2 authorize-security-group-ingress \
    --group-id "$sgID" \
    --protocol all --source-group "$sgID"

# Allow all outbound traffic (default, but making explicit)
echo ""
echo "✅ Security group configured successfully!"
echo ""
echo "Security Group ID: $sgID"
echo "Rules added:"
echo "  - SSH (22) from anywhere"
echo "  - HTTP (80) from anywhere"
echo "  - HTTPS (443) from anywhere"
echo "  - Controller UI (8090) from anywhere"
echo "  - All traffic within security group"
echo ""
echo "⚠️  Note: For production, restrict source IP ranges!"
