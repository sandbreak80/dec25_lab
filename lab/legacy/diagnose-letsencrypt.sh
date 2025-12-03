#!/bin/bash
# Diagnose why Let's Encrypt certificate is failing

VM_IP="44.232.63.139"
DOMAIN="splunkylabs.com"

echo "========================================="
echo "🔍 Let's Encrypt Certificate Diagnostics"
echo "========================================="
echo ""

echo "1️⃣ Check DNS Resolution"
echo "========================================="
nslookup ${DOMAIN}
echo ""
nslookup controller.${DOMAIN}
echo ""

echo "2️⃣ Check Port 80 Accessibility"
echo "========================================="
echo "Testing HTTP access (Let's Encrypt needs this)..."
curl -v --max-time 5 http://controller.${DOMAIN}/.well-known/acme-challenge/test 2>&1 | head -20
echo ""

echo "3️⃣ Check Port 80 in Security Group"
echo "========================================="
aws ec2 describe-security-groups \
  --group-names appd-va-sg-1 \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]' 2>/dev/null || echo "Run: aws ec2 describe-security-groups --group-names appd-va-sg-1"
echo ""

echo "4️⃣ Check Certificate Status on VM"
echo "========================================="
ssh appduser@${VM_IP} << 'EOF'
echo "Certificate status:"
kubectl get certificate splunkylabs-wildcard-tls -n authn
echo ""

echo "Certificate details:"
kubectl describe certificate splunkylabs-wildcard-tls -n authn | tail -20
echo ""

echo "Active challenges:"
kubectl get challenges -n authn 2>/dev/null || echo "No challenges found"
echo ""

echo "Orders:"
kubectl get orders -n authn 2>/dev/null || echo "No orders found"
echo ""

echo "cert-manager logs (last 30 lines):"
kubectl logs -n cert-manager -l app=cert-manager --tail=30 | grep -i "error\|failed\|challenge\|splunkylabs" || echo "No obvious errors in cert-manager logs"
EOF

echo ""
echo "========================================="
echo "📋 DIAGNOSIS COMPLETE"
echo "========================================="
echo ""
echo "Common issues:"
echo "  ❌ Port 80 not open → Add ingress rule for port 80"
echo "  ❌ DNS not resolving → Check Route 53 records"
echo "  ❌ nginx not handling challenges → Check ingress controller"
echo ""
echo "To fix port 80:"
echo "  aws ec2 authorize-security-group-ingress \\"
echo "    --group-name appd-va-sg-1 \\"
echo "    --protocol tcp \\"
echo "    --port 80 \\"
echo "    --cidr 0.0.0.0/0 \\"
echo "    --description 'HTTP for Let'\''s Encrypt validation'"
echo ""
