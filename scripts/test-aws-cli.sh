#!/bin/bash
# Test AWS CLI Configuration and Permissions
# Run this if deployment scripts are failing silently

set +e  # Don't exit on errors - we want to see them!

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AWS CLI Configuration Test                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Test 1: AWS CLI installed?
echo "📋 Test 1: Checking if AWS CLI is installed..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | head -1)
    echo "✅ AWS CLI found: $AWS_VERSION"
else
    echo "❌ AWS CLI not found!"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi
echo ""

# Test 2: Credentials configured?
echo "📋 Test 2: Checking AWS credentials..."
IDENTITY=$(aws sts get-caller-identity 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ AWS credentials are valid"
    echo "$IDENTITY" | grep -E "(UserId|Account|Arn)" | sed 's/^/   /'
    
    # Check which user
    USER_ARN=$(echo "$IDENTITY" | grep "Arn" | cut -d'"' -f4)
    if echo "$USER_ARN" | grep -q "lab-student"; then
        echo "   ℹ️  Using lab-student credentials (restricted)"
    else
        echo "   ⚠️  Using admin/instructor credentials (full access)"
    fi
else
    echo "❌ AWS credentials are NOT configured or invalid"
    echo "   Error:"
    echo "$IDENTITY" | sed 's/^/   /'
    echo ""
    echo "   Fix: Run 'aws configure' and enter your credentials"
    exit 1
fi
echo ""

# Test 3: Correct region?
echo "📋 Test 3: Checking AWS region..."
REGION=$(aws configure get region 2>&1)
if [ -z "$REGION" ]; then
    REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text 2>&1)
fi

if [ "$REGION" == "us-west-2" ]; then
    echo "✅ Region is correct: $REGION"
elif [ -z "$REGION" ]; then
    echo "⚠️  No region configured"
    echo "   Run: aws configure set region us-west-2"
else
    echo "⚠️  Region is: $REGION (should be us-west-2)"
    echo "   Fix: aws configure set region us-west-2"
fi
echo ""

# Test 4: Can we query EC2?
echo "📋 Test 4: Testing EC2 permissions..."
VPC_TEST=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Can query EC2 resources"
else
    echo "❌ Cannot query EC2 resources"
    echo "   Error:"
    echo "$VPC_TEST" | sed 's/^/   /'
    
    if echo "$VPC_TEST" | grep -q "UnauthorizedOperation"; then
        echo ""
        echo "   This looks like an IAM permissions issue."
        echo "   Contact your instructor to verify lab-student policy."
    elif echo "$VPC_TEST" | grep -q "InvalidClientTokenId"; then
        echo ""
        echo "   Your AWS credentials are invalid or expired."
        echo "   Re-run: aws configure"
    fi
fi
echo ""

# Test 5: Can we query instances?
echo "📋 Test 5: Testing EC2 instance query..."
INSTANCE_TEST=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=test-vm-nonexistent" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Can query EC2 instances (result: ${INSTANCE_TEST:-None})"
else
    echo "❌ Cannot query EC2 instances"
    echo "   Error:"
    echo "$INSTANCE_TEST" | sed 's/^/   /'
fi
echo ""

# Test 6: Network connectivity
echo "📋 Test 6: Testing network connectivity to AWS..."
if curl -s --connect-timeout 5 https://ec2.us-west-2.amazonaws.com/ > /dev/null 2>&1; then
    echo "✅ Can reach AWS endpoints"
else
    echo "⚠️  Cannot reach AWS endpoints"
    echo "   Check your internet connection or VPN"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Summary:"
echo ""

# Count passed tests
PASSED=0
if command -v aws &> /dev/null; then PASSED=$((PASSED+1)); fi
if aws sts get-caller-identity &> /dev/null; then PASSED=$((PASSED+1)); fi
if [ "$REGION" == "us-west-2" ]; then PASSED=$((PASSED+1)); fi
if aws ec2 describe-vpcs &> /dev/null; then PASSED=$((PASSED+1)); fi
if aws ec2 describe-instances --filters "Name=tag:Name,Values=test" &> /dev/null; then PASSED=$((PASSED+1)); fi
if curl -s --connect-timeout 5 https://ec2.us-west-2.amazonaws.com/ > /dev/null 2>&1; then PASSED=$((PASSED+1)); fi

echo "Tests passed: $PASSED/6"
echo ""

if [ $PASSED -eq 6 ]; then
    echo "✅ AWS CLI is configured correctly!"
    echo "   You should be able to run deployment scripts."
    echo ""
    echo "   Next: ./deployment/01-deploy.sh --team [your-team-number]"
elif [ $PASSED -ge 4 ]; then
    echo "⚠️  AWS CLI mostly working, but some issues detected."
    echo "   Review the warnings above."
    echo "   You may be able to proceed, but watch for errors."
else
    echo "❌ AWS CLI has significant configuration issues."
    echo "   Fix the errors above before running deployment scripts."
    echo ""
    echo "   Quick fixes:"
    echo "   - Run: aws configure"
    echo "   - Enter your Access Key ID and Secret Access Key"
    echo "   - Set region to: us-west-2"
    echo "   - Contact instructor if credentials are invalid"
fi

echo ""





