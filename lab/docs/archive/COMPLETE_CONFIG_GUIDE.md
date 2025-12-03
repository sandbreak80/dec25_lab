# AppDynamics VA Configuration for splunkylabs.com
# Complete configuration reference

## ========================================
## REQUIRED CHANGES for globals.yaml.gotmpl
## ========================================

### 1. DNS Domain (LINE ~9)
Change:
```yaml
dnsDomain: <domain_name>
```
To:
```yaml
dnsDomain: splunkylabs.com
```

### 2. DNS Names (LINE ~10-15)
Change:
```yaml
dnsNames: &dnsNames
  - localhost
  - <domain_name>
{{ range split " " $internalIPs }} {{ printf " - %s.%s" . "nip.io" }}
{{ end }}
```

To:
```yaml
dnsNames: &dnsNames
  - localhost
  - splunkylabs.com
  - customer1.auth.splunkylabs.com
  - customer1-tnt-authn.splunkylabs.com
  - controller.splunkylabs.com
# Comment out the nip.io range since we're using real DNS
# {{ range split " " $internalIPs }} {{ printf " - %s.%s" . "nip.io" }}
# {{ end }}
```

### 3. EUM External URL (FIND "eum:" section)
Change:
```yaml
eum:
  externalUrl: <URL_of_EUM>
```
To:
```yaml
eum:
  externalUrl: https://splunkylabs.com/eumaggregator
```

### 4. Events External URL (FIND "events:" section)
Change:
```yaml
events:
  enableSsl: true
  externalUrl: <URL_of_Events_Service>
```
To:
```yaml
events:
  enableSsl: true
  externalUrl: https://splunkylabs.com/events
```

### 5. AIOps External URL (FIND "aiops:" section - if installing AIOps)
Change:
```yaml
aiops:
  externalUrl: <URL_of_AIOps>
```
To:
```yaml
aiops:
  externalUrl: https://splunkylabs.com/aiops
```

### 6. Verify appdController section (should already be correct)
```yaml
appdController:
  tenantAccountName: &account customer1
  nodeLocked: false
  customCaCerts: false
```

### 7. Keep these defaults (no changes needed):
```yaml
enableClusterAgent: true  # Self-monitoring enabled
promstack: false
enableTelemetryJob: false
enableServiceMesh: true
enableIngressHttp: false
ingress:
  defaultCert: true  # Use self-signed certs (fine for lab)
hybrid:
  enable: false  # Standard deployment, not hybrid
```

## ========================================
## OPTIONAL: secrets.yaml Changes
## ========================================

Default passwords (can change if desired):

```yaml
appdController:
  rootUsername: root
  rootPassword: welcome  # CHANGE for production!
  rootAccountname: system
  adminUsername: admin
  adminPassword: welcome  # CHANGE for production!

mysql:
  secret:
    rootUser: root
    rootPassword: changeit
    rootHost: '%'
    eumDb: eum_db
    eumDbUser: eum_user
    eumDbPassword: changeit

tls:
  keyStorePassword: changeit
```

For your lab, you can leave these as defaults initially.

## ========================================
## COMPLETE CONFIGURATION SCRIPT
## ========================================

Run this on VM 1 to make all changes:

```bash
#!/bin/bash
cd /var/appd/config

# Backup original
sudo cp globals.yaml.gotmpl globals.yaml.gotmpl.backup.$(date +%Y%m%d_%H%M%S)

# 1. Update dnsDomain
sudo sed -i 's/dnsDomain: <domain_name>/dnsDomain: splunkylabs.com/' globals.yaml.gotmpl

# 2. Update dnsNames (complex multiline - may need manual edit)
# Comment out the range split line
sudo sed -i 's/{{ range split " " \$internalIPs }}/# {{ range split " " \$internalIPs }}/' globals.yaml.gotmpl
sudo sed -i 's/{{ end }}/# {{ end }}/' globals.yaml.gotmpl

# Add your domain names after localhost
sudo sed -i '/  - localhost/a\  - splunkylabs.com\n  - customer1.auth.splunkylabs.com\n  - customer1-tnt-authn.splunkylabs.com\n  - controller.splunkylabs.com' globals.yaml.gotmpl

# 3. Update EUM URL (find and replace in eum section)
sudo sed -i 's|externalUrl: <URL_of_EUM>|externalUrl: https://splunkylabs.com/eumaggregator|' globals.yaml.gotmpl

# 4. Update Events URL
sudo sed -i 's|externalUrl: <URL_of_Events_Service>|externalUrl: https://splunkylabs.com/events|' globals.yaml.gotmpl

# 5. Update AIOps URL
sudo sed -i 's|externalUrl: <URL_of_AIOps>|externalUrl: https://splunkylabs.com/aiops|' globals.yaml.gotmpl

echo "Configuration updated!"
echo ""
echo "Verify changes:"
grep -A 10 "dnsDomain:" globals.yaml.gotmpl
```

## ========================================
## MANUAL VERIFICATION STEPS
## ========================================

After running the script, SSH to VM 1 and verify:

```bash
ssh appduser@44.232.63.139
cd /var/appd/config

# Check dnsDomain
grep "dnsDomain:" globals.yaml.gotmpl

# Check dnsNames
grep -A 10 "dnsNames:" globals.yaml.gotmpl

# Check URLs
grep "externalUrl:" globals.yaml.gotmpl

# Should see:
# dnsDomain: splunkylabs.com
# dnsNames:
#   - localhost
#   - splunkylabs.com
#   - customer1.auth.splunkylabs.com
#   - customer1-tnt-authn.splunkylabs.com
#   - controller.splunkylabs.com
```

## ========================================
## DNS VERIFICATION
## ========================================

Create and run this DNS check script:

```bash
cat > ~/dnsinfo.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Read tenant from secrets (unencrypted version)
if [ -f /var/appd/config/secrets.yaml ]; then
    TENANT=$(grep "tenantAccountName:" /var/appd/config/secrets.yaml | awk '{print $2}' | tr -d '"')
else
    TENANT="customer1"
fi

# Read domain from globals
DNS_DOMAIN=$(grep "dnsDomain:" /var/appd/config/globals.yaml.gotmpl | grep -v "^#" | awk '{print $2}')

echo "Verify the Virtual Appliance tenant should be '${TENANT}'"
echo "Verify the Virtual Appliance domain name should be '${DNS_DOMAIN}'"
echo ""

for server_name in "${TENANT}.auth.${DNS_DOMAIN}" "${TENANT}-tnt-authn.${DNS_DOMAIN}"; do
  if getent hosts "${server_name}" > /dev/null 2>&1; then
    ip=$(getent hosts "${server_name}" | awk '{print $1}')
    echo "✓ DNS resolves: ${server_name} → ${ip}"
  else
    echo "✗ Please double-check that DNS can resolve '${server_name}' as the VA ingress IP"
  fi
done
EOF

chmod +x ~/dnsinfo.sh
./dnsinfo.sh
```

Expected output:
```
Verify the Virtual Appliance tenant should be 'customer1'
Verify the Virtual Appliance domain name should be 'splunkylabs.com'
✓ DNS resolves: customer1.auth.splunkylabs.com → 44.232.63.139
✓ DNS resolves: customer1-tnt-authn.splunkylabs.com → 44.232.63.139
```

## ========================================
## NEXT STEPS AFTER CONFIGURATION
## ========================================

1. ✅ Edit globals.yaml.gotmpl (using script above or manually)
2. ✅ Verify DNS resolution (run dnsinfo.sh)
3. ⏭️ Create cluster: `appdctl cluster init 10.0.0.56 10.0.0.177`
4. ⏭️ Install services: `appdcli start appd small`

## ========================================
## SUMMARY OF YOUR CONFIGURATION
## ========================================

Domain: splunkylabs.com
Tenant: customer1
Access URLs after installation:
  - Controller: https://controller.splunkylabs.com/controller
  - Auth: https://customer1.auth.splunkylabs.com
  - Events: https://splunkylabs.com/events
  - EUM: https://splunkylabs.com/eumaggregator

Default credentials:
  - Username: admin
  - Password: welcome (CHANGE after first login!)
