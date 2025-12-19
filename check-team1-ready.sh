#!/bin/bash
# Pre-Flight Check for Team 1 Deployment
# Verifies all prerequisites before starting deployment

# Note: Not using 'set -e' because we want to run all checks even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║  Team 1 Deployment Pre-Flight Check                     ║"
echo "║  New AMI: 25.7.0.2255                                   ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

check_pass() {
    log_success "$1"
    ((CHECKS_PASSED++))
}

check_fail() {
    log_error "$1"
    ((CHECKS_FAILED++))
}

check_warn() {
    log_warning "$1"
    ((WARNINGS++))
}

# ============================================================================
# CHECK 1: AWS Profile
# ============================================================================
log_info "Check 1: AWS Profile Configuration"
if AWS_PROFILE=bstoner aws sts get-caller-identity &>/dev/null; then
    AWS_USER=$(AWS_PROFILE=bstoner aws sts get-caller-identity --query 'Arn' --output text)
    check_pass "AWS profile 'bstoner' configured: $AWS_USER"
else
    check_fail "AWS profile 'bstoner' not configured or invalid"
fi
echo ""

# ============================================================================
# CHECK 2: AMI Configuration
# ============================================================================
log_info "Check 2: AMI Configuration (New Version)"
if [ -f "config/global.cfg" ]; then
    source config/global.cfg
    if [ "$APPD_AMI_ID" == "ami-076101d21105aedfa" ]; then
        check_pass "New AMI configured: $APPD_AMI_ID (v$APPD_AMI_VERSION)"
        
        # Verify AMI exists in AWS
        if AWS_PROFILE=bstoner aws ec2 describe-images --image-ids "$APPD_AMI_ID" --region us-west-2 &>/dev/null; then
            check_pass "AMI exists in AWS and is available"
        else
            check_fail "AMI not found in AWS region us-west-2"
        fi
    else
        check_fail "Wrong AMI configured: $APPD_AMI_ID (expected ami-076101d21105aedfa)"
    fi
else
    check_fail "Global config not found: config/global.cfg"
fi
echo ""

# ============================================================================
# CHECK 3: Team 1 Configuration
# ============================================================================
log_info "Check 3: Team 1 Configuration"
if [ -f "config/team1.cfg" ]; then
    source config/team1.cfg
    check_pass "Team 1 config found"
    
    if [ "$AWS_PROFILE" == "bstoner" ]; then
        check_pass "AWS profile set to: bstoner"
    else
        check_warn "AWS profile is: $AWS_PROFILE (expected: bstoner)"
    fi
    
    log_info "  Domain: $FULL_DOMAIN"
    log_info "  VPC CIDR: $VPC_CIDR"
    log_info "  VM Type: $VM_TYPE"
else
    check_fail "Team 1 config not found: config/team1.cfg"
fi
echo ""

# ============================================================================
# CHECK 4: No Existing State
# ============================================================================
log_info "Check 4: Team 1 State (Should be clean)"
if [ -d "state/team1" ]; then
    STATE_FILES=$(ls -A state/team1 2>/dev/null | wc -l)
    if [ $STATE_FILES -gt 0 ]; then
        check_warn "Team 1 has existing state ($STATE_FILES files)"
        log_warning "This may indicate previous deployment. Consider cleanup first:"
        log_warning "  ./deployment/cleanup.sh --team 1 --confirm"
    else
        check_pass "Team 1 state directory empty (fresh deployment)"
    fi
else
    check_pass "No existing Team 1 state (fresh deployment)"
fi
echo ""

# ============================================================================
# CHECK 5: DNS Configuration
# ============================================================================
log_info "Check 5: DNS Configuration"
HOSTED_ZONE_ID="Z06491142QTF1FNN8O9PR"
if AWS_PROFILE=bstoner aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" &>/dev/null; then
    check_pass "Route53 hosted zone accessible: $HOSTED_ZONE_ID"
else
    check_fail "Cannot access Route53 hosted zone: $HOSTED_ZONE_ID"
fi

# Check if team1 records already exist
if AWS_PROFILE=bstoner aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name=='controller-team1.splunkylabs.com.']" \
    --output text | grep -q controller-team1; then
    check_warn "DNS records for team1 already exist (may be from previous deployment)"
else
    check_pass "No existing DNS records for team1"
fi
echo ""

# ============================================================================
# CHECK 6: License File
# ============================================================================
log_info "Check 6: License File"
if [ -f "license.lic" ]; then
    check_pass "License file found: license.lic"
    
    # Check expiration
    EXPIRY=$(grep "property_expiration_date_iso" license.lic | cut -d'=' -f2 | tr -d ' ')
    log_info "  License expires: $EXPIRY"
else
    check_fail "License file not found: license.lic"
fi
echo ""

# ============================================================================
# CHECK 7: Required Scripts
# ============================================================================
log_info "Check 7: Required Deployment Scripts"
REQUIRED_SCRIPTS=(
    "deployment/full-deploy.sh"
    "deployment/01-deploy.sh"
    "deployment/06-configure.sh"
    "deployment/07-install.sh"
    "scripts/create-vms.sh"
)

ALL_SCRIPTS_OK=true
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        : # Script exists and is executable
    else
        check_fail "Script missing or not executable: $script"
        ALL_SCRIPTS_OK=false
    fi
done

if [ "$ALL_SCRIPTS_OK" = true ]; then
    check_pass "All required deployment scripts present"
fi
echo ""

# ============================================================================
# CHECK 8: SecureApp Portal Credentials (Optional)
# ============================================================================
log_info "Check 8: SecureApp Portal Credentials (Optional)"
if [ -n "$APPD_PORTAL_USERNAME" ] && [ -n "$APPD_PORTAL_PASSWORD" ]; then
    check_pass "Portal credentials set (SecureApp feeds will be configured)"
    log_info "  Username: $APPD_PORTAL_USERNAME"
else
    check_warn "Portal credentials not set (SecureApp feeds can be configured later)"
    log_info "  Set with: export APPD_PORTAL_USERNAME=your-username"
    log_info "           export APPD_PORTAL_PASSWORD=your-password"
fi
echo ""

# ============================================================================
# CHECK 9: Required Tools
# ============================================================================
log_info "Check 9: Required Tools"
REQUIRED_TOOLS=("aws" "jq" "expect" "ssh" "scp")
ALL_TOOLS_OK=true

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v $tool &>/dev/null; then
        : # Tool exists
    else
        check_fail "Required tool missing: $tool"
        ALL_TOOLS_OK=false
    fi
done

if [ "$ALL_TOOLS_OK" = true ]; then
    check_pass "All required tools installed"
fi
echo ""

# ============================================================================
# CHECK 10: Existing Team 1 Resources in AWS
# ============================================================================
log_info "Check 10: Existing Team 1 Resources in AWS"
VPC_EXISTS=false
if AWS_PROFILE=bstoner aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=appd-team1-vpc" \
    --region us-west-2 \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null | grep -q "vpc-"; then
    VPC_EXISTS=true
    check_warn "Team 1 VPC already exists in AWS (previous deployment?)"
    log_warning "Consider cleanup first: ./deployment/cleanup.sh --team 1 --confirm"
else
    check_pass "No existing Team 1 VPC (clean slate)"
fi

if [ "$VPC_EXISTS" = true ]; then
    # Check for instances
    INSTANCES=$(AWS_PROFILE=bstoner aws ec2 describe-instances \
        --filters "Name=tag:Team,Values=team1" "Name=instance-state-name,Values=running,pending,stopped" \
        --region us-west-2 \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text 2>/dev/null)
    
    if [ -n "$INSTANCES" ]; then
        check_warn "Existing Team 1 instances found: $(echo $INSTANCES | wc -w) instances"
    fi
fi
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 PRE-FLIGHT CHECK SUMMARY"
echo ""
echo "  ✅ Passed:   $CHECKS_PASSED"
echo "  ⚠️  Warnings: $WARNINGS"
echo "  ❌ Failed:   $CHECKS_FAILED"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        log_success "All checks passed! Ready to deploy Team 1."
        echo ""
        echo "📝 To deploy:"
        echo "   ./deployment/full-deploy.sh --team 1"
        echo ""
        echo "📖 For details:"
        echo "   cat TEAM1_DEPLOYMENT_PLAN.md"
        echo ""
        exit 0
    else
        log_warning "All critical checks passed, but there are $WARNINGS warning(s)."
        log_warning "Review warnings above before deploying."
        echo ""
        echo "📝 To deploy anyway:"
        echo "   ./deployment/full-deploy.sh --team 1"
        echo ""
        exit 0
    fi
else
    log_error "Pre-flight check FAILED with $CHECKS_FAILED critical issue(s)."
    log_error "Fix the issues above before deploying."
    echo ""
    exit 1
fi

