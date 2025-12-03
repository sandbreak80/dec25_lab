#!/bin/bash
# Check ALB and Target Health

export AWS_PROFILE=va-deployment
REGION=us-west-2

# Get Target Group ARN
TG_ARN=$(cat tg.arn 2>/dev/null || aws elbv2 describe-target-groups --names appd-va-tg --region $REGION --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

if [ -z "$TG_ARN" ] || [ "$TG_ARN" == "None" ]; then
  echo "❌ Target group not found"
  exit 1
fi

echo "========================================="
echo "🏥 ALB Health Check"
echo "========================================="
echo ""

echo "Target Health:"
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region $REGION --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' --output table

echo ""
echo "Target Details:"
for target in $(aws elbv2 describe-target-health --target-group-arn $TG_ARN --region $REGION --query 'TargetHealthDescriptions[*].Target.Id' --output text); do
  PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $target --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
  STATE=$(aws elbv2 describe-target-health --target-group-arn $TG_ARN --targets Id=$target --region $REGION --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)
  
  echo "  $target ($PRIVATE_IP): $STATE"
done

echo ""
echo "========================================="

# Check if all healthy
UNHEALTHY=$(aws elbv2 describe-target-health --target-group-arn $TG_ARN --region $REGION --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`]' --output text)

if [ -z "$UNHEALTHY" ]; then
  echo "✅ All targets are healthy!"
  echo ""
  echo "Test the Controller:"
  echo "  https://controller.splunkylabs.com/controller/"
else
  echo "⚠️  Some targets are unhealthy"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check security group allows traffic from ALB"
  echo "  2. Verify Controller is running: ssh appduser@10.0.0.103 'appdcli ping'"
  echo "  3. Check nginx is listening on 443: ssh appduser@10.0.0.103 'sudo netstat -tlnp | grep 443'"
  echo "  4. Review ALB target group health check settings"
fi
