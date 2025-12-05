#!/bin/bash
# Check prerequisites for AppDynamics lab deployment

set +e  # Don't exit on errors, we're checking

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  AppDynamics Lab - Prerequisites Check                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Function to check and print result
check_item() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    printf "%-50s " "$name"
    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASS++))
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠️  WARN${NC}"
        [ -n "$message" ] && echo "   └─ $message"
        ((WARN++))
    else
        echo -e "${RED}❌ FAIL${NC}"
        [ -n "$message" ] && echo "   └─ $message"
        ((FAIL++))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Required Software"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
    AWS_MAJOR=$(echo $AWS_VERSION | cut -d. -f1)
    if [ "$AWS_MAJOR" -ge 2 ]; then
        check_item "AWS CLI v2" "pass"
    else
        check_item "AWS CLI v2" "fail" "Found v$AWS_VERSION, need v2.x"
    fi
else
    check_item "AWS CLI v2" "fail" "Not installed. Run: brew install awscli"
fi

# Check bash
if command -v bash &> /dev/null; then
    BASH_VERSION=$(bash --version | head -1 | awk '{print $4}')
    check_item "bash" "pass"
else
    check_item "bash" "fail" "Not found"
fi

# Check expect
if command -v expect &> /dev/null; then
    check_item "expect" "pass"
else
    check_item "expect" "fail" "Not installed. Run: brew install expect"
fi

# Check jq
if command -v jq &> /dev/null; then
    check_item "jq" "pass"
else
    check_item "jq" "fail" "Not installed. Run: brew install jq"
fi

# Check ssh
if command -v ssh &> /dev/null; then
    check_item "ssh" "pass"
else
    check_item "ssh" "fail" "Not found"
fi

# Check scp
if command -v scp &> /dev/null; then
    check_item "scp" "pass"
else
    check_item "scp" "fail" "Not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AWS Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    check_item "AWS Credentials" "pass"
    echo "   └─ Account: $ACCOUNT_ID"
    echo "   └─ User: $USER_ARN"
else
    check_item "AWS Credentials" "fail" "Not configured. Run: aws configure"
fi

# Check AWS region
if [ -n "$AWS_REGION" ]; then
    if [ "$AWS_REGION" = "us-west-2" ]; then
        check_item "AWS Region" "pass"
        echo "   └─ Region: $AWS_REGION (recommended)"
    else
        check_item "AWS Region" "warn" "Region: $AWS_REGION (us-west-2 recommended)"
    fi
else
    AWS_REGION=$(aws configure get region 2>/dev/null)
    if [ -n "$AWS_REGION" ]; then
        if [ "$AWS_REGION" = "us-west-2" ]; then
            check_item "AWS Region" "pass"
            echo "   └─ Region: $AWS_REGION (from config)"
        else
            check_item "AWS Region" "warn" "Region: $AWS_REGION (us-west-2 recommended)"
        fi
    else
        check_item "AWS Region" "fail" "Not set. Run: export AWS_REGION=us-west-2"
    fi
fi

# Check AWS profile (if set)
if [ -n "$AWS_PROFILE" ]; then
    echo "   └─ Profile: $AWS_PROFILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Network Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check public IP
MY_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null)
if [ -n "$MY_IP" ]; then
    # Check if IP is in Cisco VPN range
    if [[ "$MY_IP" =~ ^151\.186\.(183|182)\. ]] || [[ "$MY_IP" =~ ^151\.186\.19[2-9]\. ]] || [[ "$MY_IP" =~ ^151\.186\.20[0-7]\. ]]; then
        check_item "Cisco VPN Connection" "pass"
        echo "   └─ Your IP: $MY_IP (Cisco VPN)"
    else
        check_item "Cisco VPN Connection" "warn" "Your IP: $MY_IP (NOT Cisco VPN)"
        echo "   └─ SSH to VMs will fail. Connect to Cisco VPN first."
    fi
else
    check_item "Internet Connection" "fail" "Cannot determine public IP"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${GREEN}Passed:  $PASS${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo -e "${RED}Failed:   $FAIL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}❌ Prerequisites NOT met. Fix failures above before deploying.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  AWS CLI v2:  brew install awscli"
    echo "  expect:      brew install expect"
    echo "  jq:          brew install jq"
    echo "  AWS creds:   aws configure"
    echo "  AWS region:  export AWS_REGION=us-west-2"
    echo "  Cisco VPN:   Connect to VPN before deployment"
    echo ""
    exit 1
elif [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Prerequisites met with warnings.${NC}"
    echo ""
    echo "You can proceed, but:"
    echo "  - SSH access requires Cisco VPN connection"
    echo "  - Using non-us-west-2 region may require config changes"
    echo ""
    exit 0
else
    echo -e "${GREEN}✅ All prerequisites met! Ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review team configuration: vi config/team1.cfg"
    echo "  2. Start deployment: ./lab-deploy.sh --team 1"
    echo ""
    exit 0
fi
