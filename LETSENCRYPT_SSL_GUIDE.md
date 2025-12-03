# Let's Encrypt SSL Certificate Setup Guide

## Overview

Replace the self-signed certificate with a free, valid SSL certificate from Let's Encrypt.

**Benefits:**
- ✅ No browser warnings
- ✅ Valid, trusted certificate
- ✅ Automatic renewal (every 90 days)
- ✅ Free forever
- ✅ Wildcard support (*.splunkylabs.com)

**Requirements:**
- ✅ Domain registered in Route 53: splunkylabs.com
- ✅ DNS records pointing to ingress IP: 44.232.63.139
- ✅ cert-manager already installed
- ✅ HTTP port 80 accessible (for domain validation)

---

## Quick Start (Automated)

```bash
cd /Users/bmstoner/Downloads/appd-virtual-appliance/deploy/aws
./setup-letsencrypt-ssl.sh
```

**Time Required:** 5-10 minutes

---

## Manual Setup (Step by Step)

### Step 1: Create Let's Encrypt ClusterIssuer

```bash
ssh appduser@44.232.63.139

cat > /tmp/letsencrypt-issuer.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Let's Encrypt production server
    server: https://acme-v02.api.letsencrypt.org/directory
    email: bmstoner@cisco.com  # Update with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    # HTTP-01 challenge for domain validation
    - http01:
        ingress:
          class: nginx
EOF

kubectl apply -f /tmp/letsencrypt-issuer.yaml
```

**Verify:**
```bash
kubectl get clusterissuer
```

**Expected:**
```
NAME               READY   AGE
letsencrypt-prod   True    10s
```

---

### Step 2: Request Certificate

```bash
cat > /tmp/splunkylabs-cert.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: splunkylabs-tls
  namespace: ingress
spec:
  secretName: splunkylabs-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: splunkylabs.com
  dnsNames:
  - splunkylabs.com
  - "*.splunkylabs.com"
  - controller.splunkylabs.com
  - customer1.auth.splunkylabs.com
  - customer1-tnt-authn.splunkylabs.com
EOF

kubectl apply -f /tmp/splunkylabs-cert.yaml
```

**Monitor Progress:**
```bash
# Watch certificate status
kubectl get certificate -n ingress -w

# Check events
kubectl describe certificate splunkylabs-tls -n ingress

# Check CertificateRequest
kubectl get certificaterequest -n ingress
```

**Expected Status:**
```
NAME              READY   SECRET            AGE
splunkylabs-tls   True    splunkylabs-tls   2m
```

**Note:** This can take 2-5 minutes. Let's Encrypt will:
1. Create an HTTP-01 challenge
2. Verify you control the domain
3. Issue the certificate

---

### Step 3: Update Ingress to Use Certificate

Find your ingress name:
```bash
kubectl get ingress -n ingress-master
```

Update ingress to use the new certificate:
```bash
kubectl patch ingress -n ingress-master appd-ingress -p '
{
  "spec": {
    "tls": [
      {
        "hosts": [
          "splunkylabs.com",
          "*.splunkylabs.com",
          "controller.splunkylabs.com",
          "customer1.auth.splunkylabs.com",
          "customer1-tnt-authn.splunkylabs.com"
        ],
        "secretName": "splunkylabs-tls"
      }
    ]
  }
}'
```

**Verify:**
```bash
kubectl describe ingress -n ingress-master appd-ingress | grep -A 10 TLS
```

**Expected:**
```
TLS:
  splunkylabs-tls terminates splunkylabs.com,*.splunkylabs.com,...
```

---

### Step 4: Verify Certificate

**Check certificate details:**
```bash
# View certificate subject
kubectl get secret splunkylabs-tls -n ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep Subject

# View issuer (should be Let's Encrypt)
kubectl get secret splunkylabs-tls -n ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep Issuer

# View expiration date
kubectl get secret splunkylabs-tls -n ingress -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep "Not After"
```

**Test in browser:**
```
https://controller.splunkylabs.com/controller
```

**Expected:**
- ✅ No security warnings
- ✅ Green padlock icon
- ✅ Certificate shows "Let's Encrypt"
- ✅ Valid for 90 days

**Test with curl:**
```bash
curl -v https://controller.splunkylabs.com/controller 2>&1 | grep -A 5 "Server certificate"
```

**Expected:**
```
* Server certificate:
*  subject: CN=splunkylabs.com
*  start date: Dec  3 16:30:00 2025 GMT
*  expire date: Mar  3 16:30:00 2026 GMT
*  issuer: C=US; O=Let's Encrypt; CN=R3
*  SSL certificate verify ok.
```

---

## Automatic Renewal

**cert-manager automatically renews certificates 30 days before expiration.**

**Check renewal status:**
```bash
kubectl get certificate -n ingress splunkylabs-tls -o yaml | grep -A 5 "status:"
```

**Expected:**
```yaml
status:
  conditions:
  - lastTransitionTime: "2025-12-03T16:30:00Z"
    message: Certificate is up to date and has not expired
    observedGeneration: 1
    reason: Ready
    status: "True"
    type: Ready
  notAfter: "2026-03-03T16:30:00Z"  # Auto-renews 30 days before this
  notBefore: "2025-12-03T16:30:00Z"
  renewalTime: "2026-02-01T16:30:00Z"  # Renewal scheduled here
```

**Manual renewal (if needed):**
```bash
kubectl delete secret splunkylabs-tls -n ingress
kubectl delete certificate splunkylabs-tls -n ingress
kubectl apply -f /tmp/splunkylabs-cert.yaml
```

---

## Troubleshooting

### Issue: Certificate stays in "Pending" state

**Check HTTP-01 challenge:**
```bash
kubectl get challenges -n ingress
kubectl describe challenge -n ingress
```

**Common causes:**
- Port 80 not accessible from internet
- DNS not pointing to ingress IP
- Security group blocking HTTP traffic

**Fix:**
```bash
# Check security group allows port 80
aws ec2 describe-security-groups --group-names appd-va-sg-1 | grep -A 5 "IpProtocol.*tcp"

# If port 80 not open, add rule:
aws ec2 authorize-security-group-ingress \
  --group-name appd-va-sg-1 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

---

### Issue: "Too many requests" error

**Cause:** Let's Encrypt rate limits (5 certs per domain per week)

**Solution:** Use Let's Encrypt staging for testing:

```yaml
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory  # Staging
```

**Note:** Staging certificates are NOT trusted by browsers, only use for testing.

---

### Issue: DNS validation fails

**Check DNS records:**
```bash
nslookup controller.splunkylabs.com
nslookup customer1.auth.splunkylabs.com
```

**Expected:** All should return `44.232.63.139`

**Fix if not working:**
```bash
# Re-run DNS setup script
cd /Users/bmstoner/Downloads/appd-virtual-appliance/deploy/aws
./09-aws-create-dns-records.sh
```

---

### Issue: Certificate issued but browser still shows self-signed

**Cause:** Ingress not updated or cached

**Solution:**
```bash
# Restart ingress nginx controller
kubectl rollout restart deployment -n ingress ingress-nginx-controller

# Wait for pod restart
kubectl get pods -n ingress -w

# Clear browser cache
# Chrome: Ctrl+Shift+R (hard refresh)
# Firefox: Ctrl+Shift+Del (clear cache)
```

---

## Alternative: AWS Certificate Manager (ACM)

If Let's Encrypt doesn't work, you can use AWS ACM with an Application Load Balancer:

**Pros:**
- Managed by AWS
- No renewal needed
- Wildcard support

**Cons:**
- Requires ALB (additional cost ~$16/month)
- More complex setup
- Certificate stays in AWS (can't be exported)

**Setup:**
```bash
# 1. Request certificate in ACM
aws acm request-certificate \
  --domain-name splunkylabs.com \
  --subject-alternative-names "*.splunkylabs.com" \
  --validation-method DNS

# 2. Create ALB targeting EC2 instances
# 3. Configure ALB to use ACM certificate
# 4. Update DNS to point to ALB
```

**Recommendation:** Try Let's Encrypt first (free, simpler).

---

## Security Group Update for Let's Encrypt

Let's Encrypt needs HTTP (port 80) access for domain validation.

**Check current rules:**
```bash
aws ec2 describe-security-groups --group-names appd-va-sg-1
```

**Add HTTP rule if missing:**
```bash
aws ec2 authorize-security-group-ingress \
  --group-name appd-va-sg-1 \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --description "HTTP for Let's Encrypt challenges"
```

**Note:** Port 80 is ONLY used for certificate validation. After issuance, all traffic uses HTTPS (443).

---

## Summary

**With Let's Encrypt:**
- ✅ Free, valid SSL certificate
- ✅ No browser warnings
- ✅ Automatic renewal
- ✅ Wildcard support
- ✅ Works with existing setup

**Time to setup:** 5-10 minutes  
**Cost:** $0  
**Renewal:** Automatic every 90 days

---

## Next Steps

After SSL setup:
1. ✅ Test Controller UI (no warnings)
2. ✅ Update QUICK_REFERENCE.md with https:// URLs
3. ✅ Share working HTTPS URLs with lab students
4. ✅ Enjoy trusted, secure connections!

---

**Questions?** Check `LAB_GUIDE.md` or `VENDOR_DOC_ISSUES.md`
