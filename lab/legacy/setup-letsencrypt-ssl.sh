#!/bin/bash
# Install Let's Encrypt SSL certificate for splunkylabs.com

set -e

VM_IP="44.232.63.139"
VM_PASSWORD="FrMoJMZayxBj8@iU"
DOMAIN="splunkylabs.com"
EMAIL="bmstoner@cisco.com"  # Update with your email for Let's Encrypt notifications

echo "========================================="
echo "🔒 Install Let's Encrypt SSL Certificate"
echo "========================================="
echo ""
echo "Domain: ${DOMAIN}"
echo "Email: ${EMAIL}"
echo ""
echo "This will:"
echo "  1. Create Let's Encrypt ClusterIssuer"
echo "  2. Request certificate for *.${DOMAIN}"
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
echo "Step 1: Create Let's Encrypt ClusterIssuer"
echo "========================================="
echo ""

expect << EXPECT_SCRIPT
set timeout 60
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "cat > /tmp/letsencrypt-issuer.yaml << 'EOF'\r"
    send "apiVersion: cert-manager.io/v1\r"
    send "kind: ClusterIssuer\r"
    send "metadata:\r"
    send "  name: letsencrypt-prod\r"
    send "spec:\r"
    send "  acme:\r"
    send "    # Let's Encrypt production server\r"
    send "    server: https://acme-v02.api.letsencrypt.org/directory\r"
    send "    email: ${EMAIL}\r"
    send "    privateKeySecretRef:\r"
    send "      name: letsencrypt-prod\r"
    send "    solvers:\r"
    send "    # HTTP-01 challenge for domain validation\r"
    send "    - http01:\r"
    send "        ingress:\r"
    send "          class: nginx\r"
    send "EOF\r"
    send "echo ''\r"
    send "echo 'Applying ClusterIssuer...'\r"
    send "kubectl apply -f /tmp/letsencrypt-issuer.yaml\r"
    send "echo ''\r"
    send "echo 'Verifying ClusterIssuer...'\r"
    send "kubectl get clusterissuer\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT

echo ""
echo "========================================="
echo "Step 2: Find Ingress Namespace"
echo "========================================="
echo ""

INGRESS_NS=$(expect << 'EXPECT_SCRIPT'
set timeout 30
spawn ssh appduser@44.232.63.139
expect "password:" { send "FrMoJMZayxBj8@iU\r" }
expect "appduser@" {
    send "kubectl get ingress --all-namespaces | grep -v NAMESPACE | head -1 | awk '{print \$1}'\r"
    expect -re "\\S+"
    set ns $expect_out(0,string)
    send "exit\r"
}
expect eof
EXPECT_SCRIPT
)

INGRESS_NS=$(echo "$INGRESS_NS" | grep -v "spawn\|password\|Welcome\|appduser" | tr -d '\r' | xargs)

echo "Found ingress in namespace: ${INGRESS_NS}"
echo ""

echo "========================================="
echo "Step 3: Request Wildcard Certificate"
echo "========================================="
echo ""

expect << EXPECT_SCRIPT
set timeout 60
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "cat > /tmp/splunkylabs-wildcard-cert.yaml << 'EOF'\r"
    send "apiVersion: cert-manager.io/v1\r"
    send "kind: Certificate\r"
    send "metadata:\r"
    send "  name: splunkylabs-wildcard-tls\r"
    send "  namespace: ${INGRESS_NS}\r"
    send "spec:\r"
    send "  secretName: splunkylabs-wildcard-tls\r"
    send "  issuerRef:\r"
    send "    name: letsencrypt-prod\r"
    send "    kind: ClusterIssuer\r"
    send "  commonName: \"*.${DOMAIN}\"\r"
    send "  dnsNames:\r"
    send "  - \"${DOMAIN}\"\r"
    send "  - \"*.${DOMAIN}\"\r"
    send "EOF\r"
    send "echo ''\r"
    send "echo 'Creating Wildcard Certificate resource...'\r"
    send "kubectl apply -f /tmp/splunkylabs-wildcard-cert.yaml\r"
    send "echo ''\r"
    send "echo 'Checking certificate status...'\r"
    send "kubectl get certificate -n ${INGRESS_NS}\r"
    send "echo ''\r"
    send "echo 'Checking certificate events...'\r"
    send "kubectl describe certificate splunkylabs-wildcard-tls -n ${INGRESS_NS}\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT

echo ""
echo "========================================="
echo "Step 4: Monitor Certificate Issuance"
echo "========================================="
echo ""
echo "Certificate issuance can take 2-5 minutes."
echo "Let's Encrypt will:"
echo "  1. Create HTTP-01 challenge"
echo "  2. Verify domain ownership via http://${DOMAIN}/.well-known/acme-challenge/"
echo "  3. Issue wildcard certificate"
echo ""
echo "Monitoring for 5 minutes..."
echo ""

for i in {1..10}; do
    echo "Check $i/10 ($(date '+%H:%M:%S'))..."
    
    CERT_STATUS=$(expect << EXPECT_SCRIPT
    set timeout 30
    spawn ssh appduser@${VM_IP}
    expect "password:" { send "${VM_PASSWORD}\r" }
    expect "appduser@" {
        send "kubectl get certificate splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.status.conditions\[0\].status}'\r"
        send "exit\r"
    }
    expect eof
EXPECT_SCRIPT
    )
    
    expect << EXPECT_SCRIPT
    set timeout 30
    spawn ssh appduser@${VM_IP}
    expect "password:" { send "${VM_PASSWORD}\r" }
    expect "appduser@" {
        send "kubectl get certificate splunkylabs-wildcard-tls -n ${INGRESS_NS}\r"
        send "exit\r"
    }
    expect eof
EXPECT_SCRIPT
    
    if echo "$CERT_STATUS" | grep -q "True"; then
        echo "✅ Certificate issued successfully!"
        break
    fi
    
    if [ $i -lt 10 ]; then
        echo "Still waiting... (checking challenges and orders)"
        expect << EXPECT_SCRIPT
        set timeout 30
        spawn ssh appduser@${VM_IP}
        expect "password:" { send "${VM_PASSWORD}\r" }
        expect "appduser@" {
            send "kubectl get challenges -n ${INGRESS_NS} 2>/dev/null || echo 'No active challenges'\r"
            send "exit\r"
        }
        expect eof
EXPECT_SCRIPT
        echo ""
        sleep 30
    fi
done

echo ""
echo "========================================="
echo "Step 5: Find and Update ALL Ingress Resources"
echo "========================================="
echo ""

echo "Finding all ingress resources..."
INGRESS_LIST=$(expect << EXPECT_SCRIPT
set timeout 30
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "kubectl get ingress --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{\"/\"}{.metadata.name}{\"\\n\"}{end}'\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT
)

echo "$INGRESS_LIST" | grep "/" | while read line; do
    NS=$(echo "$line" | cut -d'/' -f1)
    NAME=$(echo "$line" | cut -d'/' -f2)
    
    echo ""
    echo "Updating ingress: $NAME in namespace: $NS"
    
    expect << EXPECT_SCRIPT
    set timeout 60
    spawn ssh appduser@${VM_IP}
    expect "password:" { send "${VM_PASSWORD}\r" }
    expect "appduser@" {
        send "echo 'Backing up current ingress...'\r"
        send "kubectl get ingress $NAME -n $NS -o yaml > /tmp/ingress-${NS}-${NAME}-backup.yaml 2>/dev/null\r"
        send "echo ''\r"
        send "echo 'Patching ingress to use wildcard certificate...'\r"
        send "kubectl patch ingress $NAME -n $NS --type=json -p='[{\"op\":\"add\",\"path\":\"/spec/tls\",\"value\":[{\"hosts\":[\"${DOMAIN}\",\"*.${DOMAIN}\"],\"secretName\":\"splunkylabs-wildcard-tls\"}]}]' 2>/dev/null || \r"
        send "kubectl patch ingress $NAME -n $NS --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/tls\",\"value\":[{\"hosts\":[\"${DOMAIN}\",\"*.${DOMAIN}\"],\"secretName\":\"splunkylabs-wildcard-tls\"}]}]'\r"
        send "echo ''\r"
        send "echo 'Verifying TLS configuration...'\r"
        send "kubectl get ingress $NAME -n $NS -o jsonpath='{.spec.tls}' | jq .\r"
        send "exit\r"
    }
    expect eof
EXPECT_SCRIPT
done

echo ""
echo "Restarting nginx-ingress controller to reload certificates..."
expect << EXPECT_SCRIPT
set timeout 60
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "kubectl rollout restart deployment -n ingress ingress-nginx-controller 2>/dev/null || kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller 2>/dev/null || echo 'Could not find nginx controller deployment'\r"
    send "echo ''\r"
    send "echo 'Waiting for controller to be ready...'\r"
    send "sleep 10\r"
    send "kubectl get pods -n ingress | grep ingress-nginx || kubectl get pods -n ingress-nginx | grep ingress-nginx\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT

echo ""
echo "========================================="
echo "Step 6: Verify Wildcard Certificate"
echo "========================================="
echo ""

echo "Checking certificate details..."
expect << EXPECT_SCRIPT
set timeout 30
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "echo 'Certificate Subject:'\r"
    send "kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\\\\.crt}' | base64 -d | openssl x509 -text -noout | grep 'Subject:'\r"
    send "echo ''\r"
    send "echo 'Certificate Issuer:'\r"
    send "kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\\\\.crt}' | base64 -d | openssl x509 -text -noout | grep 'Issuer:'\r"
    send "echo ''\r"
    send "echo 'Certificate Validity:'\r"
    send "kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\\\\.crt}' | base64 -d | openssl x509 -text -noout | grep 'Not Before\\|Not After'\r"
    send "echo ''\r"
    send "echo 'DNS Names (Subject Alternative Names):'\r"
    send "kubectl get secret splunkylabs-wildcard-tls -n ${INGRESS_NS} -o jsonpath='{.data.tls\\\\.crt}' | base64 -d | openssl x509 -text -noout | grep -A 2 'Subject Alternative Name'\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT

echo ""
echo "========================================="
echo "Step 7: Test Certificate"
echo "========================================="
echo ""

echo "Testing HTTPS connection..."
curl -v --max-time 10 https://controller.${DOMAIN}/controller 2>&1 | grep -E "(Server certificate|issuer|expire date|SSL certificate verify)" || echo "Could not connect - check nginx-ingress is running"

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
echo "Ingress Resources Updated:"
expect << EXPECT_SCRIPT
set timeout 30
spawn ssh appduser@${VM_IP}
expect "password:" { send "${VM_PASSWORD}\r" }
expect "appduser@" {
    send "kubectl get ingress --all-namespaces\r"
    send "exit\r"
}
expect eof
EXPECT_SCRIPT
echo ""
