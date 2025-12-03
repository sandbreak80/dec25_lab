#!/bin/bash
# Check Team Deployment Status
# Usage: ./check-status.sh --team 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

show_usage() {
    cat << EOF
Usage: $0 --team TEAM_NUMBER

Check deployment status and health for your team.

Arguments:
    --team, -t NUMBER    Team number (1-5)
    --help, -h           Show this help

Example:
    $0 --team 1

EOF
}

TEAM_NUMBER=$(parse_team_number "$@")
load_team_config "$TEAM_NUMBER"
check_aws_cli

clear
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Team ${TEAM_NUMBER} - Deployment Status                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

# Check infrastructure
echo "📊 Infrastructure Status:"
echo ""

VPC_ID=$(load_resource_id vpc "$TEAM_NUMBER")
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "  ✅ VPC:          $VPC_ID"
else
    echo "  ❌ VPC:          Not created"
fi

SUBNET_ID=$(load_resource_id subnet "$TEAM_NUMBER")
if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "None" ]; then
    echo "  ✅ Subnet 1:     $SUBNET_ID"
else
    echo "  ❌ Subnet 1:     Not created"
fi

SUBNET2_ID=$(load_resource_id subnet2 "$TEAM_NUMBER")
if [ -n "$SUBNET2_ID" ] && [ "$SUBNET2_ID" != "None" ]; then
    echo "  ✅ Subnet 2:     $SUBNET2_ID"
else
    echo "  ❌ Subnet 2:     Not created"
fi

echo ""

# Check VMs
echo "🖥️  Virtual Machines:"
echo ""

for i in 1 2 3; do
    INSTANCE_ID=$(load_resource_id "vm${i}" "$TEAM_NUMBER")
    if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
        STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "N/A")
        
        if [ "$STATE" == "running" ]; then
            echo "  ✅ VM${i}:         $INSTANCE_ID (running) - $IP"
        else
            echo "  ⚠️  VM${i}:         $INSTANCE_ID ($STATE)"
        fi
    else
        echo "  ❌ VM${i}:         Not created"
    fi
done

echo ""

# Check ALB
echo "⚖️  Load Balancer:"
echo ""

ALB_ARN=$(load_resource_id alb "$TEAM_NUMBER")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "N/A")
    ALB_STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null || echo "unknown")
    
    if [ "$ALB_STATE" == "active" ]; then
        echo "  ✅ ALB:          $ALB_DNS (active)"
    else
        echo "  ⚠️  ALB:          $ALB_DNS ($ALB_STATE)"
    fi
    
    # Check target health
    TG_ARN=$(load_resource_id tg "$TEAM_NUMBER")
    if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
        echo ""
        echo "  Target Health:"
        aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output text 2>/dev/null | while read id state; do
            if [ "$state" == "healthy" ]; then
                echo "    ✅ $id: $state"
            else
                echo "    ⚠️  $id: $state"
            fi
        done
    fi
else
    echo "  ❌ ALB:          Not created"
fi

echo ""

# Check DNS
echo "🌐 DNS Status:"
echo ""

CONTROLLER_URL="controller-team${TEAM_NUMBER}.splunkylabs.com"
DNS_RESULT=$(dig +short "$CONTROLLER_URL" 2>/dev/null | head -1)

if [ -n "$DNS_RESULT" ]; then
    echo "  ✅ DNS:          $CONTROLLER_URL → $DNS_RESULT"
else
    echo "  ❌ DNS:          Not configured"
fi

echo ""

# Check connectivity
echo "🔗 Connectivity:"
echo ""

if [ -n "$CONTROLLER_URL" ] && [ -n "$DNS_RESULT" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$CONTROLLER_URL/controller/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "302" ] || [ "$HTTP_STATUS" == "405" ]; then
        echo "  ✅ HTTPS:        https://$CONTROLLER_URL/controller/ ($HTTP_STATUS)"
    else
        echo "  ⚠️  HTTPS:        https://$CONTROLLER_URL/controller/ ($HTTP_STATUS)"
    fi
else
    echo "  ❌ HTTPS:        Cannot test - DNS not configured"
fi

echo ""

# Show URLs
cat << EOF
╔══════════════════════════════════════════════════════════╗
║  Your URLs                                               ║
╚══════════════════════════════════════════════════════════╝

Controller UI:
  https://controller-team${TEAM_NUMBER}.splunkylabs.com/controller/

Auth Service:
  https://customer1-team${TEAM_NUMBER}.auth.splunkylabs.com/

SSH to VM1:
  ./scripts/ssh-vm1.sh --team ${TEAM_NUMBER}

EOF

# Next steps
if ! is_step_complete "cluster-initialized" "$TEAM_NUMBER"; then
    cat << EOF
📝 Next Steps:
   1. SSH to VM1
   2. Bootstrap all 3 VMs (see BOOTSTRAP_GUIDE.md)
   3. Create Kubernetes cluster
   4. Install AppDynamics

EOF
fi
