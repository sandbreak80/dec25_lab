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

---

## 🔐 Step 3: Setup SSH Keys (HIGHLY RECOMMENDED!)

**Avoid typing password 30-50 times during the lab!**

```bash
./scripts/setup-ssh-keys.sh --team 1
```

**What this does:**
- Generates SSH key pair on your laptop
- Copies public key to all 3 VMs
- Enables passwordless SSH for all automation
- Updates SSH config for easy access

**Time:** 1 minute  
**Benefit:** All subsequent SSH is passwordless! 🎉

**Note:** This is optional but HIGHLY recommended for a better lab experience!

---

## 🔐 Step 4: Bootstrap VMs (REQUIRED!)

**CRITICAL**: VMs must be bootstrapped before AppDynamics can be installed!

```bash
./appd-bootstrap-vms.sh --team 1
```

**What this does:**
- Runs `appdctl host init` on each VM
- Configures hostname, network, storage
- Sets up firewall, SSH, certificates
- Prepares VMs for AppDynamics cluster

**Note:** 
- If you setup SSH keys (Step 3), this runs passwordless!
- Without keys, you'll need to enter password multiple times

**Time:** ~5 minutes

---

## 🔗 Step 5: Create AppDynamics Cluster

```bash
./appd-create-cluster.sh --team 1
```

---

## ⚙️ Step 6: Configure & Install AppDynamics

```bash
# Configure cluster
./appd-configure.sh --team 1

# Install AppDynamics services
./appd-install.sh --team 1
```

---

## 🌐 Step 7: Access Web UI

After deployment completes and AppDynamics is installed:

```
Controller: https://controller-team1.splunkylabs.com/controller/
Username: admin
Password: welcome (change after first login)
```

---

## 🧹 Step 8: Cleanup (End of Lab)

**IMPORTANT**: Delete all resources to avoid charges!

```bash
./lab-cleanup.sh --team 1 --confirm
```

**Cost**: ~$2.50/hour = ~$20 for 8-hour lab day

---

## 🆘 Troubleshooting

### SSH Connection Issues
```bash
# Make sure you changed the password first
./appd-change-password.sh --team 1

# Setup SSH keys for passwordless access (recommended!)
./scripts/setup-ssh-keys.sh --team 1

# Then SSH works easily
./scripts/ssh-vm1.sh --team 1
```

### Can't SSH from home/non-VPN
SSH is restricted to Cisco VPN IPs only. Connect to VPN first!

---

## 📚 Full Documentation

- **Lab Guide**: `./LAB_GUIDE.md` - Complete step-by-step instructions
- **Quick Reference**: `./QUICK_REFERENCE.md` - Common commands
- **Instructor Guide**: `./docs/INSTRUCTOR_GUIDE.md` - Setup and management

---

## 🔑 SSH Access Summary

| Step | Method | Details |
|------|--------|---------|
| Initial | Password | `appduser` / `changeme` |
| After Step 2 | Password | `appduser` / `AppDynamics123!` |
| After Step 3 | Passwordless | SSH key authentication ✅ |

**To connect:**
```bash
# With SSH keys (after step 3) - EASY!
./scripts/ssh-vm1.sh --team 1  # No password needed!

# Or use SSH config shortcut
ssh appd-team1-vm1  # No password needed!

# Without SSH keys (manual)
ssh appduser@<VM-IP>
# Password: AppDynamics123!
```

**💡 Pro Tip:** Setup SSH keys (Step 3) to make the lab experience much smoother!
