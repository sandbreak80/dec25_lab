# Configuration Changes Summary

## Files Created

1. **`globals.yaml.gotmpl.original`** - Downloaded from VM1 (backup)
2. **`globals.yaml.gotmpl.updated`** - Ready to upload (modified for splunkylabs.com)
3. **`secrets.yaml.original`** - Downloaded from VM1 (no changes needed)

---

## Changes Made to globals.yaml.gotmpl

### Line 9: DNS Domain
**BEFORE:**
```yaml
dnsDomain: <domain_name>
```

**AFTER:**
```yaml
dnsDomain: splunkylabs.com
```

---

### Lines 10-14: DNS Names
**BEFORE:**
```yaml
dnsNames: &dnsNames
  - localhost
  - <domain_name>
{{ range split " " $internalIPs }} {{ printf " - %s.%s" . "nip.io" }}
{{ end }}
```

**AFTER:**
```yaml
dnsNames: &dnsNames
  - localhost
  - splunkylabs.com
  - customer1.auth.splunkylabs.com
  - customer1-tnt-authn.splunkylabs.com
  - controller.splunkylabs.com
# Commented out nip.io to use real DNS
# {{ range split " " $internalIPs }} {{ printf " - %s.%s" . "nip.io" }}
# {{ end }}
```

---

### Line 75: EUM External URL
**BEFORE:**
```yaml
eum:
  externalUrl: https://<domain_name>
```

**AFTER:**
```yaml
eum:
  externalUrl: https://splunkylabs.com/eumaggregator
```

---

### Line 80: Events External URL
**BEFORE:**
```yaml
events:
  enableSsl: true
  externalUrl: https://<domain_name>:32105
```

**AFTER:**
```yaml
events:
  enableSsl: true
  externalUrl: https://splunkylabs.com/events
```

---

### Line 84: AIOps External URL
**BEFORE:**
```yaml
aiops:
  externalUrl: https://<domain_name>/pi
```

**AFTER:**
```yaml
aiops:
  externalUrl: https://splunkylabs.com/aiops
```

---

### Line 142: Schema Registry External URL
**BEFORE:**
```yaml
  schemaregistry:
    externalUrl: https://<domain_name>/schemaregistry
```

**AFTER:**
```yaml
  schemaregistry:
    externalUrl: https://splunkylabs.com/schemaregistry
```

---

## No Changes Needed

**`secrets.yaml`** - No changes required. Default passwords are fine for lab environment.

---

## How to Upload

### Option 1: Use the upload script (Automated)
```bash
cd /Users/bmstoner/Downloads/appd-virtual-appliance/deploy/aws
./upload-config.sh
```

### Option 2: Manual upload
```bash
# Upload file
scp globals.yaml.gotmpl.updated appduser@44.232.63.139:/tmp/

# SSH to VM1
ssh appduser@44.232.63.139

# Backup original and replace
sudo cp /var/appd/config/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl.backup
sudo mv /tmp/globals.yaml.gotmpl.updated /var/appd/config/globals.yaml.gotmpl
sudo chown root:root /var/appd/config/globals.yaml.gotmpl
sudo chmod 644 /var/appd/config/globals.yaml.gotmpl

# Verify
grep "dnsDomain:" /var/appd/config/globals.yaml.gotmpl
```

---

## Next Steps After Upload

1. **Verify DNS** (from VM1):
   ```bash
   ssh appduser@44.232.63.139
   
   # Test DNS resolution
   nslookup customer1.auth.splunkylabs.com
   nslookup controller.splunkylabs.com
   ```

2. **Create Cluster**:
   ```bash
   cd /home/appduser
   appdctl cluster init 10.0.0.56 10.0.0.177
   # Enter password when prompted: FrMoJMZayxBj8@iU
   ```

3. **Install Services**:
   ```bash
   appdcli start appd small
   ```

---

## Verification

After upload, verify the changes on VM1:
```bash
ssh appduser@44.232.63.139
grep -E "(dnsDomain|externalUrl|dnsNames)" /var/appd/config/globals.yaml.gotmpl
```

Expected output should show `splunkylabs.com` throughout.
