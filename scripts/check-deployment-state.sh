#!/bin/bash
# Check deployment state and diagnose issues
# Usage: ./scripts/check-deployment-state.sh --team N

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"

echo ""
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Deployment State Checker - Team ${TEAM_NUMBER}                   ║
╚══════════════════════════════════════════════════════════╝

This tool checks if all required resources exist for your team.

EOF

# Check state directory
if [ ! -d "state/team${TEAM_NUMBER}" ]; then
    log_error "State directory not found: state/team${TEAM_NUMBER}"
    log_info "This suggests Phase 1 (network creation) hasn't run yet."
    log_info "Run: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
    exit 1
fi

log_success "State directory exists"
echo ""

# Check Phase 1: Network
echo "📊 Phase 1: Network Infrastructure"
echo "───────────────────────────────────"

VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    log_error "VPC ID not found"
    echo "  State file: state/team${TEAM_NUMBER}/vpc.id"
else
    log_success "VPC ID: $VPC_ID"
    # Verify in AWS
    if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" &>/dev/null; then
        log_success "VPC exists in AWS"
    else
        log_error "VPC not found in AWS (stale state file?)"
    fi
fi

SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
    log_error "Subnet ID not found"
    echo "  State file: state/team${TEAM_NUMBER}/subnet.id"
else
    log_success "Subnet ID: $SUBNET_ID"
    if aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" &>/dev/null; then
        log_success "Subnet exists in AWS"
    else
        log_error "Subnet not found in AWS (stale state file?)"
    fi
fi

IGW_ID=$(load_resource_id igw "$TEAM_NUMBER")
if [ -z "$IGW_ID" ] || [ "$IGW_ID" == "None" ]; then
    log_warning "Internet Gateway ID not found"
else
    log_success "Internet Gateway ID: $IGW_ID"
fi

echo ""

# Check Phase 2: Security
echo "🔒 Phase 2: Security Groups"
echo "───────────────────────────────────"

VM_SG_ID=$(load_resource_id vm-sg "$TEAM_NUMBER")
if [ -z "$VM_SG_ID" ] || [ "$VM_SG_ID" == "None" ]; then
    log_error "VM Security Group ID not found"
    echo "  State file: state/team${TEAM_NUMBER}/vm-sg.id"
else
    log_success "VM Security Group ID: $VM_SG_ID"
    if aws ec2 describe-security-groups --group-ids "$VM_SG_ID" &>/dev/null; then
        log_success "VM Security Group exists in AWS"
    else
        log_error "VM Security Group not found in AWS (stale state file?)"
    fi
fi

ALB_SG_ID=$(load_resource_id alb-sg "$TEAM_NUMBER")
if [ -z "$ALB_SG_ID" ] || [ "$ALB_SG_ID" == "None" ]; then
    log_warning "ALB Security Group ID not found (OK if ALB not deployed yet)"
else
    log_success "ALB Security Group ID: $ALB_SG_ID"
fi

echo ""

# Check Phase 3: VMs
echo "💻 Phase 3: Virtual Machines"
echo "───────────────────────────────────"

for i in 1 2 3; do
    VM_ID=$(load_resource_id "vm${i}" "$TEAM_NUMBER")
    if [ -z "$VM_ID" ] || [ "$VM_ID" == "None" ]; then
        log_warning "VM${i} ID not found (not deployed yet)"
    else
        log_success "VM${i} ID: $VM_ID"
        if aws ec2 describe-instances --instance-ids "$VM_ID" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null | grep -q running; then
            log_success "VM${i} is running in AWS"
            
            # Get IPs
            PUB_IP=$(cat "state/team${TEAM_NUMBER}/vm${i}-public-ip.txt" 2>/dev/null)
            PRIV_IP=$(cat "state/team${TEAM_NUMBER}/vm${i}-private-ip.txt" 2>/dev/null)
            echo "    Public IP: $PUB_IP"
            echo "    Private IP: $PRIV_IP"
        else
            log_error "VM${i} not running in AWS (terminated or stale state?)"
        fi
    fi
done

echo ""

# Check AMI
echo "📦 Shared Resources"
echo "───────────────────────────────────"

# AMI Configuration (from global config)
if [ -f "config/global.cfg" ]; then
    source "config/global.cfg"
    AMI_ID="$APPD_AMI_ID"
    AMI_STATUS="configured"
else
    AMI_ID="NOT_FOUND"
    AMI_STATUS="missing config/global.cfg"
fi
if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    log_error "AMI ID not found"
    echo "  State file: state/shared/ami.id"
    echo "  Contact your instructor for the AMI ID"
else
    log_success "AMI ID: $AMI_ID"
fi

echo ""

# Progress tracker
echo "✅ Completed Steps"
echo "───────────────────────────────────"

if [ -f "state/team${TEAM_NUMBER}/progress.txt" ]; then
    while read -r step; do
        echo "  ✓ $step"
    done < "state/team${TEAM_NUMBER}/progress.txt"
else
    echo "  (No steps marked complete yet)"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count resources
VPC_OK=0; [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ] && VPC_OK=1
SUBNET_OK=0; [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "None" ] && SUBNET_OK=1
VM_SG_OK=0; [ -n "$VM_SG_ID" ] && [ "$VM_SG_ID" != "None" ] && VM_SG_OK=1

if [ $VPC_OK -eq 1 ] && [ $SUBNET_OK -eq 1 ] && [ $VM_SG_OK -eq 1 ]; then
    log_success "Prerequisites OK - Ready for VM deployment!"
    echo ""
    echo "Run: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
else
    log_error "Missing prerequisites - Cannot deploy VMs"
    echo ""
    echo "🔧 Troubleshooting:"
    echo ""
    
    if [ $VPC_OK -eq 0 ] || [ $SUBNET_OK -eq 0 ]; then
        echo "  Phase 1 (Network) incomplete or failed:"
        echo "  1. Check for errors in: logs/team${TEAM_NUMBER}/"
        echo "  2. Try re-running: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
        echo "  3. If still failing, clean up and retry:"
        echo "     ./deployment/cleanup.sh --team ${TEAM_NUMBER} --confirm"
    fi
    
    if [ $VM_SG_OK -eq 0 ]; then
        echo "  Phase 2 (Security Groups) incomplete or failed:"
        echo "  1. Check for errors in: logs/team${TEAM_NUMBER}/"
        echo "  2. Try re-running: ./deployment/01-deploy.sh --team ${TEAM_NUMBER}"
    fi
    
    echo ""
    echo "  If problems persist, contact your instructor."
fi

echo ""




