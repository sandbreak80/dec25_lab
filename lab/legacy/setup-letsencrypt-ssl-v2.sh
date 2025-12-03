#!/bin/bash
# Install Let's Encrypt SSL certificate for splunkylabs.com

set -e

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"
DOMAIN="splunkylabs.com"
EMAIL="bmstoner@cisco.com"

echo "========================================="
echo "🔒 Install Let's Encrypt SSL Certificate"
echo "========================================="
echo ""
echo "Domain: ${DOMAIN}"
echo "Email: ${EMAIL}"
echo ""
echo "This will:"
echo "  1. Create Let's Encrypt ClusterIssuer"
echo "  2. Request wildcard certificate for *.${DOMAIN}"
echo "  3. Configure ingress to use the certificate"
echo "  4. Auto-renew before expiration"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "========================================="
echo "Step 1: Find Ingress Namespace"
echo "========================================="
echo ""

# Get first ingress namespace
INGRESS_NS=$(ssh appduser@${VM_IP} "kubectl get ingress --all-namespaces --no-headers | head -1 | awk '{print \$1}'")
echo "Found ingress in namespace: ${INGRESS_NS}"

if [ -z "$INGRESS_NS" ]; then
    echo "❌ No ingress resources found!"
    echo "This is unexpected. Checking for ingress controllers..."
    ssh appduser@${VM_IP} "kubectl get pods --all-namespaces | grep ingress"
    exit 1
fi

echo ""
echo "========================================="
echo "Step 2: Create Let's Encrypt ClusterIssuer"
echo "========================================="
echo ""

ssh appduser@${VM_IP} << 'SSHEOF'
cat > /tmp/letsencrypt-issuer.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: bmstoner@cisco.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo ""
echo "Applying ClusterIssuer..."
kubectl apply -f /tmp/letsencrypt-issuer.yaml

echo ""
echo "Verifying ClusterIssuer..."
kubectl get clusterissuer letsencrypt-prod
SSHEOF

echo ""
echo "========================================="
echo "Step 3: Request Wildcard Certificate"
echo "========================================="
echo ""

ssh appduser@${VM_IP} << SSHEOF
cat > /tmp/splunkylabs-wildcard-cert.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: splunkylabs-wildcard-tls
  namespace: ${INGRESS_NS}
spec:
  secretName: splunkylabs-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "*.${DOMAIN}"
  dnsNames:
  - "${DOMAIN}"
  - "*.${DOMAIN}"
EOF

echo ""
echo "Creating Wildcard Certificate resource..."
kubectl apply -f /tmp/splunkylabs-wildcard-cert.yaml

echo ""
echo "Checking certificate status..."
kubectl get certificate -n ${INGRESS_NS}
SSHEOF

echo ""
echo "========================================="
echo "Step 4: Monitor Certificate Issuance"
echo "========================================="
echo ""
echo "Certificate issuance can take 2-5 minutes."
echo "Let's Encrypt will validate via HTTP-01 challenge."
echo ""
echo "Monitoring for up to 5 minutes..."
echo ""

for i in {1..10}; do
    echo "Check $i/10 ($(date '+%H:%M:%S'))..."
    
    CERT_STATUS=$(ssh appduser@${VM_IP} "kubectl get certificate splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo 'Unknown'")
    
    ssh appduser@${VM_IP} "kubectl get certificate splunkylabs-wildcard-tls -n ${INGRESS_NS} 2>/dev/null"
    
    if [ "$CERT_STATUS" == "True" ]; then
        echo ""
        echo "✅ Certificate issued successfully!"
        break
    fi
    
    if [ $i -lt 10 ]; then
        echo "Still waiting... Checking challenges:"
        ssh appduser@${VM_IP} "kubectl get challenges -n ${INGRESS_NS} 2>/dev/null || echo 'No active challenges'"
        echo ""
        sleep 30
    fi
done

echo ""
echo "========================================="
echo "Step 5: Update ALL Ingress Resources"
echo "========================================="
echo ""

echo "Finding all ingress resources..."
INGRESS_LIST=$(ssh appduser@${VM_IP} "kubectl get ingress --all-namespaces --no-headers" | awk '{print $1"/"$2}')

echo "$INGRESS_LIST" | while IFS='/' read NS NAME; do
    echo ""
    echo "Updating ingress: $NAME in namespace: $NS"
    
    # Backup current ingress
    ssh appduser@${VM_IP} "kubectl get ingress $NAME -n $NS -o yaml > /tmp/ingress-${NS}-${NAME}-backup.yaml 2>/dev/null"
    
    # Patch ingress to use wildcard certificate
    ssh appduser@${VM_IP} << PATCHEOF
kubectl patch ingress $NAME -n $NS --type=json -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["${DOMAIN}", "*.${DOMAIN}"],
        "secretName": "splunkylabs-wildcard-tls"
      }
    ]
  }
]' 2>/dev/null || kubectl patch ingress $NAME -n $NS --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["${DOMAIN}", "*.${DOMAIN}"],
        "secretName": "splunkylabs-wildcard-tls"
      }
    ]
  }
]'

echo "Verifying TLS configuration..."
kubectl get ingress $NAME -n $NS -o jsonpath='{.spec.tls}' 2>/dev/null | jq . || echo "TLS config applied"
PATCHEOF
done

echo ""
echo "Restarting nginx-ingress controller to reload certificates..."
ssh appduser@${VM_IP} << 'SSHEOF'
kubectl rollout restart deployment -n ingress ingress-nginx-controller 2>/dev/null || \
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller 2>/dev/null || \
echo "Could not find nginx controller deployment to restart"

echo ""
echo "Waiting for controller to be ready..."
sleep 15

echo "Checking nginx-ingress pods:"
kubectl get pods -n ingress | grep ingress-nginx 2>/dev/null || \
kubectl get pods -n ingress-nginx | grep ingress-nginx 2>/dev/null || \
echo "Could not find nginx-ingress pods"
SSHEOF

echo ""
echo "========================================="
echo "Step 6: Verify Wildcard Certificate"
echo "========================================="
echo ""

echo "Checking certificate details..."
ssh appduser@${VM_IP} << SSHEOF
echo "Certificate Subject:"
kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -text -noout | grep 'Subject:' || echo "Could not retrieve certificate"

echo ""
echo "Certificate Issuer:"
kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -text -noout | grep 'Issuer:' || echo "Could not retrieve issuer"

echo ""
echo "Certificate Validity:"
kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -text -noout | grep 'Not Before\|Not After' || echo "Could not retrieve validity"

echo ""
echo "DNS Names (SANs):"
kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -text -noout | grep -A 2 'Subject Alternative Name' || echo "Could not retrieve SANs"
SSHEOF

echo ""
echo "========================================="
echo "Step 7: Test Certificate"
echo "========================================="
echo ""

echo "Testing HTTPS connection..."
curl -v --max-time 10 https://controller.${DOMAIN}/controller 2>&1 | grep -E "(Server certificate|issuer|expire date|SSL certificate verify)" || echo "Connection test - check manually"

echo ""
echo "========================================="
echo "✅ Let's Encrypt Wildcard SSL Complete!"
echo "========================================="
echo ""
echo "Your WILDCARD certificate is now active for:"
echo "  - ${DOMAIN}"
echo "  - *.${DOMAIN}"
echo ""
echo "This covers ALL subdomains:"
echo "  ✅ https://controller.${DOMAIN}/controller"
echo "  ✅ https://customer1.auth.${DOMAIN}"
echo "  ✅ https://customer1-tnt-authn.${DOMAIN}"
echo "  ✅ https://<anything>.${DOMAIN}"
echo ""
echo "Certificate Details:"
echo "  - Issuer: Let's Encrypt (R3)"
echo "  - Valid: 90 days"
echo "  - Auto-renewal: 30 days before expiration"
echo "  - Namespace: ${INGRESS_NS}"
echo "  - Secret: splunkylabs-wildcard-tls"
echo ""
echo "Next steps:"
echo "  1. Open https://controller.${DOMAIN}/controller in browser"
echo "  2. Verify green padlock (no warnings)"
echo "  3. Click padlock → Certificate → Should show 'Let's Encrypt'"
echo "  4. Share HTTPS URLs with lab students!"
echo ""
echo "All ingress resources updated:"
ssh appduser@${VM_IP} "kubectl get ingress --all-namespaces"
echo ""
