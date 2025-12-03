# Configuration Guide for AppDynamics VA

## Your Environment Values

- **DNS Domain**: `splunkylabs.com`
- **Tenant Name**: `customer1`
- **Ingress IP**: `44.232.63.139`
- **Node IPs**: 10.0.0.103, 10.0.0.56, 10.0.0.177

## Required Changes to globals.yaml.gotmpl

### 1. Update DNS Domain

Change:
```yaml
dnsDomain: <domain_name>
```

To:
```yaml
dnsDomain: splunkylabs.com
```

### 2. Update dnsNames

Change:
```yaml
dnsNames: &dnsNames
  - localhost
  - <domain_name>
```

To:
```yaml
dnsNames: &dnsNames
  - localhost
  - splunkylabs.com
  - customer1.auth.splunkylabs.com
  - customer1-tnt-authn.splunkylabs.com
  - controller.splunkylabs.com
```

### 3. Update License Keys (If you have them)

Change:
```yaml
controllerKey: &controllerKey <controller_key>
eumKey: <eum_key>
```

To your actual license keys, or leave as `<controller_key>` and `<eum_key>` for now

---

## Command to Edit

SSH to VM 1 and edit:

```bash
ssh appduser@44.232.63.139
cd /var/appd/config
sudo vi globals.yaml.gotmpl
```

Use `vi` commands:
- Press `i` to enter insert mode
- Make the changes
- Press `ESC` then type `:wq` to save and exit

---

## Minimum Required Changes

At minimum, you MUST change:
1. `dnsDomain: splunkylabs.com`
2. Update the `dnsNames` list

Everything else can use defaults for initial installation.

---

## After Editing globals.yaml.gotmpl

### Verify DNS Resolution

Create and run the DNS verification script:

```bash
cd ~
cat > dnsinfo.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Read from unencrypted secrets.yaml since we haven't installed yet
TENANT=$(grep "tenantAccountName:" /var/appd/config/secrets.yaml | awk '{print $2}' | tr -d '"')
DNS_DOMAIN=$(grep "dnsDomain:" /var/appd/config/globals.yaml.gotmpl | grep -v "^#" | awk '{print $2}')

echo "Verify the Virtual Appliance tenant should be '${TENANT}'"
echo "Verify the Virtual Appliance domain name should be '${DNS_DOMAIN}'"

for server_name in "${TENANT}.auth.${DNS_DOMAIN}" "${TENANT}-tnt-authn.${DNS_DOMAIN}"; do
  if ! getent hosts "${server_name}" > /dev/null; then
    echo "Please double-check that DNS can resolve '${server_name}' as the VA ingress IP"
  else
    echo "✓ DNS resolves: ${server_name}"
  fi
done
EOF

chmod +x dnsinfo.sh
./dnsinfo.sh
```

Expected output:
```
Verify the Virtual Appliance tenant should be 'customer1'
Verify the Virtual Appliance domain name should be 'splunkylabs.com'
✓ DNS resolves: customer1.auth.splunkylabs.com
✓ DNS resolves: customer1-tnt-authn.splunkylabs.com
```

---

## If DNS Doesn't Resolve Yet

DNS propagation can take up to 60 minutes. Check:

```bash
# Test DNS
nslookup customer1.auth.splunkylabs.com

# Check if it returns: 44.232.63.139
```

If DNS isn't resolving yet, you can still proceed with cluster creation, but you'll need working DNS before the services will be fully functional.

---

## Next Steps After Configuration

1. ✅ Edit `globals.yaml.gotmpl`
2. ✅ Verify DNS resolution
3. ⏭️ Create cluster: `appdctl cluster init 10.0.0.56 10.0.0.177`
4. ⏭️ Install services: `appdcli start appd small`
