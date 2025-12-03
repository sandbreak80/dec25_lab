# Final Configuration Checklist - Ready to Install

## ✅ What's Complete
- [x] AWS Infrastructure deployed (3 VMs running)
- [x] DNS domain registered (splunkylabs.com)
- [x] DNS records created
- [x] VMs bootstrapped
- [x] Passwords changed
- [x] SSH secured

## 🎯 What's Left (Before Installation)

### Step 1: Edit globals.yaml.gotmpl (5 minutes)

**REQUIRED CHANGES - Only These 5 Things:**

```bash
ssh appduser@44.232.63.139
cd /var/appd/config
sudo vi globals.yaml.gotmpl
```

**Find and replace these exact values:**

| Find This | Replace With |
|-----------|--------------|
| `dnsDomain: <domain_name>` | `dnsDomain: splunkylabs.com` |
| `- <domain_name>` (in dnsNames section) | `- splunkylabs.com` |
| `externalUrl: <URL_of_EUM>` | `externalUrl: https://splunkylabs.com/eumaggregator` |
| `externalUrl: <URL_of_Events_Service>` | `externalUrl: https://splunkylabs.com/events` |
| `externalUrl: <URL_of_AIOps>` | `externalUrl: https://splunkylabs.com/aiops` |

**ALSO:** Add after `- localhost` in dnsNames section:
```yaml
  - splunkylabs.com
  - customer1.auth.splunkylabs.com
  - customer1-tnt-authn.splunkylabs.com
  - controller.splunkylabs.com
```

**AND:** Comment out this line (add # at start):
```yaml
# {{ range split " " $internalIPs }} {{ printf " - %s.%s" . "nip.io" }}
```

---

### Step 2: Verify Configuration (1 minute)

```bash
# Still on VM 1
grep "dnsDomain:" globals.yaml.gotmpl
# Should show: dnsDomain: splunkylabs.com

grep -A 8 "dnsNames:" globals.yaml.gotmpl
# Should show your domains listed
```

---

### Step 3: Run DNS Verification (1 minute)

```bash
# Create DNS check script
cat > ~/dnsinfo.sh << 'EOF'
#!/bin/bash
TENANT="customer1"
DNS_DOMAIN="splunkylabs.com"

echo "Tenant: ${TENANT}"
echo "Domain: ${DNS_DOMAIN}"
echo ""

for server_name in "${TENANT}.auth.${DNS_DOMAIN}" "${TENANT}-tnt-authn.${DNS_DOMAIN}"; do
  if getent hosts "${server_name}" > /dev/null 2>&1; then
    ip=$(getent hosts "${server_name}" | awk '{print $1}')
    echo "✓ DNS OK: ${server_name} → ${ip}"
  else
    echo "✗ DNS FAIL: ${server_name}"
  fi
done
EOF

chmod +x ~/dnsinfo.sh
./dnsinfo.sh
```

**Expected output:**
```
✓ DNS OK: customer1.auth.splunkylabs.com → 44.232.63.139
✓ DNS OK: customer1-tnt-authn.splunkylabs.com → 44.232.63.139
```

**If DNS fails:** Wait 5-10 minutes for propagation, then try again.

---

### Step 4: Create Cluster (2 minutes)

```bash
# Still on VM 1
cd /home/appduser
appdctl cluster init 10.0.0.56 10.0.0.177
# Enter password when prompted: FrMoJMZayxBj8@iU
```

**Verify cluster:**
```bash
appdctl show cluster
# All 3 nodes should show RUNNING: true

microk8s status
# Should show: microk8s is running, high-availability: yes
```

---

### Step 5: Install AppDynamics Services (20-30 minutes)

```bash
# On VM 1, logged into cluster
appdcli start appd small
```

**This installs:**
- Controller
- Events Service
- EUM (Collector, Aggregator, Screenshots)
- Synthetic services
- All required infrastructure (MySQL, Postgres, Redis, Kafka, etc.)

**Monitor installation:**
```bash
# Watch pods come up
watch -n 10 'kubectl get pods --all-namespaces'

# Check service status
appdcli ping
```

---

## 🎊 After Installation Complete

### Access Your Lab

**Controller UI:**
```
https://controller.splunkylabs.com/controller
https://customer1.auth.splunkylabs.com/controller
```

**Default Login:**
- Username: `admin`
- Password: `welcome`

**⚠️ CHANGE PASSWORD IMMEDIATELY!**

---

## 📋 Installation Timeline

| Step | Time | Status |
|------|------|--------|
| Edit config files | 5 min | ⏸️ TO DO |
| Verify DNS | 1 min | ⏸️ TO DO |
| Create cluster | 2 min | ⏸️ TO DO |
| Install services | 20-30 min | ⏸️ TO DO |
| Verify & access | 5 min | ⏸️ TO DO |
| **TOTAL** | **~35 min** | |

---

## ⚠️ Important Notes

### Special Characters to Avoid
These characters will break the configuration:
```
, { } [ ] & * # ? | -- < > = ! % @ {}
```

### Passwords
For production, change these in `secrets.yaml`:
- Controller admin password
- MySQL root password
- Database passwords

For your lab, defaults are fine initially.

### License File
If you have a license, copy to:
```bash
sudo cp /path/to/license.lic /var/appd/config/license.lic
```

If not, you can apply later with:
```bash
appdcli license controller license.lic
```

---

## 🚀 Ready to Start?

**Your exact commands:**

```bash
# 1. SSH to VM 1
ssh appduser@44.232.63.139

# 2. Edit config
cd /var/appd/config
sudo vi globals.yaml.gotmpl
# Make the 5 changes listed above

# 3. Verify DNS
cd ~
./dnsinfo.sh

# 4. Create cluster
appdctl cluster init 10.0.0.56 10.0.0.177

# 5. Install services
appdcli start appd small

# 6. Monitor
watch kubectl get pods --all-namespaces
```

---

## 📞 Troubleshooting

**If services fail to install:**
```bash
# Check logs
kubectl logs -n <namespace> <pod-name>

# Check appdcli status
appdcli ping

# Restart if needed
appdcli stop appd
appdcli start appd small
```

**If DNS isn't resolving:**
- Wait 10-15 minutes for full propagation
- Test: `nslookup customer1.auth.splunkylabs.com`
- Should return: `44.232.63.139`

---

**Total time to complete: ~35 minutes from now!** 🎉
