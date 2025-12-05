# AppDynamics Lab - Start Here

Welcome! This guide will walk you through deploying your AppDynamics lab environment in AWS.

## 📋 Before You Begin

### Prerequisites
- [ ] AWS credentials configured (`aws configure`)
- [ ] Connected to Cisco VPN
- [ ] Assigned a team number (1-5)

**Verify prerequisites:**
```bash
./scripts/check-prerequisites.sh
```

---

## 🚀 Deployment Steps

### Step 1: Deploy Infrastructure (~10 minutes)

Deploy your team's AWS resources (VPC, VMs, Load Balancer, DNS):

```bash
./lab-deploy.sh --team 1
# Replace "1" with your team number
```

**What gets created:**
- 3 EC2 instances (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- Application Load Balancer with SSL certificate
- DNS records (team1.splunkylabs.com)
- Security groups

---

### Step 2: Change Password (~1 minute)

Change the default `appduser` password:

```bash
./appd-change-password.sh --team 1
```

**Default password:** `changeme`  
**New password:** `AppDynamics123!`

---

### Step 3: Setup SSH Keys (~1 minute) **RECOMMENDED**

Setup passwordless SSH access (saves typing password 30+ times!):

```bash
./scripts/setup-ssh-keys.sh --team 1
```

After this completes, you can SSH without entering password:
```bash
./scripts/ssh-vm1.sh --team 1
```

---

### Step 4: Bootstrap VMs (~5 minutes + 15-20 minute wait)

Initialize all 3 VMs with `appdctl host init`:

```bash
./appd-bootstrap-vms.sh --team 1
```

**IMPORTANT:** After this completes, the VMs will extract a large image file (~15-20 minutes). **Do not proceed until this finishes!**

**Verify bootstrap is complete:**
```bash
./scripts/ssh-vm1.sh --team 1
appdctl show boot
# All tasks should show "Succeeded"
exit
```

---

### Step 5: Create Cluster (~10 minutes)

Create the 3-node Kubernetes cluster:

```bash
./appd-create-cluster.sh --team 1
```

This will create a highly-available MicroK8s cluster across all 3 VMs.

---

### Step 6: Configure AppDynamics (~1 minute)

Update the AppDynamics configuration with your team's DNS settings:

```bash
./appd-configure.sh --team 1
```

---

### Step 7: Install AppDynamics (~20-30 minutes)

Install all AppDynamics services:

```bash
./appd-install.sh --team 1
```

The script will automatically monitor installation progress. This takes 20-30 minutes.

---

### Step 8: Verify & Access (~1 minute)

Check that all services are running:

```bash
./appd-check-health.sh --team 1
```

**Access your Controller:**
- URL: `https://controller-team1.splunkylabs.com/controller/`
- Username: `admin`
- Password: `welcome`

⚠️ **Change the admin password immediately!**

---

## 🧹 Cleanup

When you're done with the lab, delete all resources:

```bash
./lab-cleanup.sh --team 1 --confirm
# You'll be prompted to type: DELETE TEAM 1
```

---

## 📚 Additional Documentation

- **LAB_GUIDE.md** - Detailed lab instructions
- **QUICK_REFERENCE.md** - Common commands reference
- **README.md** - Project documentation
- **FIX-REQUIRED.md** - Known issues and workarounds

---

## 🆘 Troubleshooting

### SSH Connection Issues
**Problem:** Can't SSH to VMs

**Solution:** Ensure you're connected to Cisco VPN:
```bash
curl ifconfig.me
# Should show: 151.186.*.*
```

### Bootstrap Not Complete
**Problem:** Cluster creation fails

**Solution:** Wait for image extraction to finish (~15-20 min after bootstrap):
```bash
./scripts/ssh-vm1.sh --team 1
appdctl show boot  # All should be "Succeeded"
```

### Services Not Starting
**Problem:** Installation times out

**Solution:** Services can take up to 30 minutes. Check status:
```bash
./scripts/ssh-vm1.sh --team 1
appdcli ping
```

---

**Total Time:** ~60-90 minutes (mostly automated waiting)

**Happy Learning!** 🎓
