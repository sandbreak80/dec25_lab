# AppDynamics Lab - Quick Start Guide

## 🚀 First Time Setup

### Step 1: Deploy Infrastructure

Deploy your lab environment:

```bash
./lab-deploy.sh --team 1
```

**This takes ~30 minutes and creates:**
- ✅ VPC with 2 subnets
- ✅ 3 VMs (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- ✅ Application Load Balancer
- ✅ SSL certificate (*.splunkylabs.com)
- ✅ DNS records (team1.splunkylabs.com)
- ✅ Security groups (SSH restricted to Cisco VPN)

---

## 🔑 Step 2: Change appduser Password (REQUIRED!)

**CRITICAL**: Change the default password before bootstrap!

```bash
./appd-change-password.sh --team 1
```

**Default behavior:**
- Sets password to: `AppDynamics123!`
- Or specify custom: `./appd-change-password.sh --team 1 --password "YourPassword"`

**Why?** The appduser account has default password "changeme" that must be changed.

**How SSH works:**
- VMs are configured with password-based SSH (vendor approach)
- No SSH keys needed - use password authentication
- Default user: `appduser`
- Initial password: `changeme`
- Team password: `AppDynamics123!` (or custom)

---

## 🔐 Step 3: Bootstrap VMs (REQUIRED!)

**CRITICAL**: VMs must be bootstrapped before AppDynamics can be installed!

```bash
./appd-bootstrap-vms.sh --team 1
```

**What this does:**
- Runs `appdctl host init` on each VM
- Configures hostname, network, storage
- Sets up firewall, SSH, certificates
- Prepares VMs for AppDynamics cluster

**Time:** ~5 minutes

---

## 🔗 Step 4: Create AppDynamics Cluster

```bash
./appd-create-cluster.sh --team 1
```

---

## ⚙️ Step 5: Configure & Install AppDynamics

```bash
# Configure cluster
./appd-configure.sh --team 1

# Install AppDynamics services
./appd-install.sh --team 1
```

---

## 🌐 Step 6: Access Web UI

After deployment completes and AppDynamics is installed:

```
Controller: https://controller-team1.splunkylabs.com/controller/
Username: admin
Password: welcome (change after first login)
```

---

## 🧹 Step 7: Cleanup (End of Lab)

**IMPORTANT**: Delete all resources to avoid charges!

```bash
./lab-cleanup.sh --team 1 --confirm
```

**Cost**: ~$2.50/hour = ~$20 for 8-hour lab day

---

## 🆘 Troubleshooting

### "Permission denied" SSH Error
```bash
# Make sure you changed the password first
./appd-change-password.sh --team 1

# Then use the new password when prompted
./scripts/ssh-vm1.sh --team 1
# Password: AppDynamics123!
```

### Can't SSH from home/non-VPN
SSH is restricted to Cisco VPN IPs only. Connect to VPN first!

---

## 📚 Full Documentation

- **Lab Guide**: `./docs/LAB_GUIDE.md` - Complete step-by-step instructions
- **Quick Reference**: `./docs/QUICK_REFERENCE.md` - Common commands
- **Instructor Guide**: `./INSTRUCTOR_GUIDE.md` - Setup and management

---

## 🔑 SSH Access Summary

| Team | Username | Initial Password | Team Password |
|------|----------|------------------|---------------|
| All Teams | `appduser` | `changeme` | `AppDynamics123!` |

**SSH Method:** Password-based authentication (no keys needed!)

**To connect:**
```bash
ssh appduser@<VM-IP>
# Password: AppDynamics123! (after running appd-change-password.sh)
```
