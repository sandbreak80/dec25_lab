# AppDynamics Virtual Appliance - AWS Lab Guide

**Complete deployment guide for multi-team AppDynamics labs.**

---

## 🎯 Lab Overview

Deploy a complete AppDynamics cluster in AWS with:
- ✅ 3 EC2 instances (AppDynamics Virtual Appliance)
- ✅ Application Load Balancer with SSL
- ✅ DNS records (Route 53)
- ✅ Full AppDynamics installation (Controller, EUM, Events, AIOps, SecureApp)

**Time:** 60-90 minutes | **Teams:** 1-5 (isolated environments)

---

## 📋 Prerequisites

### Required
- [ ] AWS account with configured credentials
- [ ] Cisco VPN connection
- [ ] AWS CLI v2 installed
- [ ] Team assignment (1-5)

### Verify Prerequisites
```bash
./scripts/check-prerequisites.sh
```

This checks:
- AWS CLI v2 installation
- AWS credentials
- Cisco VPN connection
- Required tools (`expect`, `jq`, `ssh`)

---

## 🚀 Phase 1: Infrastructure Deployment

### Step 1: Deploy Infrastructure (~10 minutes)

Deploy VPC, VMs, Load Balancer, and DNS:

```bash
./lab-deploy.sh --team 1
```

**What gets created:**
- VPC with 2 subnets (different AZs)
- 3× m5a.4xlarge instances (16 vCPU, 64GB RAM each)
  - 200GB OS disk per VM
  - 500GB data disk per VM
- Application Load Balancer with ACM SSL certificate
- Route 53 DNS records:
  - `controller-team1.splunkylabs.com`
  - `customer1-team1.auth.splunkylabs.com`
- Security groups:
  - SSH: Restricted to Cisco VPN IPs only
  - HTTPS: Open to all (0.0.0.0/0)

**Deployment completes when you see:**
```
✅ DEPLOYMENT COMPLETE!
Your URLs:
  Controller: https://controller-team1.splunkylabs.com/controller/
```

---

## 🔐 Phase 2: VM Preparation

### Step 2: Change Password (~1 minute)

Change the default `appduser` password on all VMs:

```bash
./appd-change-password.sh --team 1
```

**Changes:**
- `changeme` → `AppDynamics123!`

You can customize the password:
```bash
./appd-change-password.sh --team 1 --password "YourPassword"
```

---

### Step 3: Setup SSH Keys (~1 minute) **HIGHLY RECOMMENDED**

Avoid typing password 30-50 times during deployment!

```bash
./scripts/setup-ssh-keys.sh --team 1
```

**What this does:**
- Generates ED25519 SSH key pair: `~/.ssh/appd-team1-key`
- Copies public key to all 3 VMs
- Enables passwordless SSH

**Test passwordless access:**
```bash
./scripts/ssh-vm1.sh --team 1
# You should connect without password prompt!
exit
```

**Skip this step?** You'll need to enter `AppDynamics123!` password many times during subsequent steps.

---

## 🏗 Phase 3: Cluster Creation

### Step 4: Bootstrap VMs (~5 minutes + 15-20 minute wait)

Initialize all VMs with `appdctl host init`:

```bash
./appd-bootstrap-vms.sh --team 1
```

**What happens:**
1. Connects to each VM via SSH
2. Runs `sudo appdctl host init` on each
3. Configures:
   - Storage (LVM for data disk)
   - Networking
   - MicroK8s installation
   - Firewall rules
   - SSH keys for VM-to-VM communication
4. **Starts image extraction** (~15-20 minutes, runs in background)

**CRITICAL:** After script completes, **WAIT 15-20 MINUTES** for image extraction to finish before proceeding!

**Verify bootstrap completion:**
```bash
./scripts/ssh-vm1.sh --team 1
appdctl show boot
```

Expected output (all tasks "Succeeded"):
```
TASK                        | STATUS    | MESSAGE
----------------------------|-----------|------------------
lvm                         | Succeeded |
host-properties             | Succeeded |
microk8s-setup              | Succeeded |
firewall-ports              | Succeeded |
load-images                 | Succeeded | ← Must be "Succeeded"
certificates                | Succeeded |
appdynamics-operator        | Succeeded |
```

**If `load-images` shows "In Progress":** Wait 5-10 more minutes and check again.

---

### Step 5: Create Cluster (~10 minutes)

Create the 3-node Kubernetes cluster:

```bash
./appd-create-cluster.sh --team 1
```

**What happens:**
1. Verifies all VMs bootstrapped successfully
2. Scans and adds VM2/VM3 host keys to VM1
3. Runs `appdctl cluster init <VM2_IP> <VM3_IP>` on VM1
4. Creates highly-available MicroK8s cluster with dqlite

**Cluster creation complete when you see:**
```
✅ CLUSTER INITIALIZATION COMPLETE!
```

**Verify cluster:**
```bash
./scripts/ssh-vm1.sh --team 1
appdctl show cluster
```

Expected output:
```
NODE             | ROLE  | RUNNING
-----------------|-------|--------
10.1.0.10:19001  | voter | true
10.1.0.20:19001  | voter | true
10.1.0.30:19001  | voter | true
```

---

## ⚙️ Phase 4: Configuration

### Step 6: Configure AppDynamics (~1 minute)

Update `globals.yaml.gotmpl` with team-specific DNS:

```bash
./appd-configure.sh --team 1
```

**What happens:**
1. Downloads current `globals.yaml.gotmpl` from VM1
2. Updates these fields:
   - `wildcard_ingress_dns_domain`
   - `public_controller_host_name`
   - `events_service_external_dns_name`
   - `auth_saml_dns_name`
3. Uploads updated file back to VM1

**Configuration complete when you see:**
```
✅ CONFIGURATION COMPLETE!
```

---

## 📦 Phase 5: Installation

### Step 7: Install AppDynamics (~20-30 minutes)

Install all AppDynamics services:

```bash
./appd-install.sh --team 1
```

**What happens:**
1. Verifies cluster health
2. Runs `appdcli start all small` on VM1
3. Monitors installation progress every 60 seconds
4. Waits for all services to show "Success"

**Services installed:**
- Controller
- Events Service  
- EUM (End User Monitoring)
- Synthetic Monitoring
- AIOps
- ATD (Automatic Transaction Diagnostics)
- SecureApp (Secure Application)

**Installation takes 20-30 minutes.** The script automatically monitors progress.

**Installation complete when you see:**
```
✅ INSTALLATION COMPLETE!
```

---

## ✅ Phase 6: Verification

### Step 8: Verify & Access (~1 minute)

Check that all services are running:

```bash
./appd-check-health.sh --team 1
```

Expected output:
```
PROFILE         | SERVICE                  | STATUS
----------------|--------------------------|--------
platform        | appdynamics-infra        | Success
...
small           | appd-controller          | Success
small           | appd-events-service      | Success
...
```

**All services should show "Success".**

---

### Access Your Controller

1. **Open Controller UI:**
   ```
   https://controller-team1.splunkylabs.com/controller/
   ```

2. **Login:**
   - Username: `admin`
   - Password: `welcome`

3. **⚠️ CHANGE PASSWORD IMMEDIATELY!**
   - Click admin (top right) → My Account → Password

4. **Apply License:**
   - Wait for instructor to provide license file
   - Settings → License → Upload

---

## 🔍 Monitoring & Troubleshooting

### Check Service Status

**On VM:**
```bash
./scripts/ssh-vm1.sh --team 1
appdcli status          # Quick status
appdcli ping            # Detailed health check
kubectl get pods -A     # Kubernetes pods
```

### View Logs

**On VM:**
```bash
# AppD operator logs
kubectl logs -n appdynamics -l app=appdynamics-operator

# Controller logs
kubectl logs -n appdcontroller <controller-pod-name>

# Events Service logs
kubectl logs -n events-service <events-pod-name>
```

### Common Issues

#### SSH Key Corruption
**Problem:** SSH keys stop working after cluster creation

**Solution:** Re-setup SSH keys:
```bash
./scripts/setup-ssh-keys.sh --team 1
```

#### Services Stuck in "Starting"
**Problem:** `appdcli ping` shows services not ready after 30 minutes

**Solution:** Check pod status and logs:
```bash
./scripts/ssh-vm1.sh --team 1
kubectl get pods -A | grep -v Running
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

#### Bootstrap Not Complete
**Problem:** Cluster init fails with "host-info.yaml not found"

**Solution:** Ensure bootstrap completed and image extraction finished:
```bash
./scripts/ssh-vm1.sh --team 1
appdctl show boot  # All tasks must be "Succeeded"
```

Wait for `load-images` task to complete (~15-20 minutes after bootstrap).

---

## 🧹 Cleanup

### Delete All Resources

When lab is complete, delete all AWS resources:

```bash
./lab-cleanup.sh --team 1 --confirm
```

You'll be prompted to type: `DELETE TEAM 1`

**This deletes:**
- All EC2 instances
- Load balancer
- VPC and subnets
- Security groups
- Elastic IPs
- DNS records

**Cost savings:** Deleting resources immediately after lab prevents unnecessary charges (~$20/day per team).

---

## 📚 Additional Resources

### Documentation Files
- **START_HERE.md** - Quick start guide (this is better for students)
- **QUICK_REFERENCE.md** - Command reference
- **README.md** - Project documentation
- **FIX-REQUIRED.md** - Known issues and workarounds

### AppDynamics Documentation
- Official Docs: https://docs.appdynamics.com/
- Virtual Appliance Guide: https://docs.appdynamics.com/display/latest/Install+AppDynamics+with+the+Virtual+Appliance

---

## 🎓 Learning Objectives

By completing this lab, you will:
- ✅ Deploy infrastructure as code using AWS CLI
- ✅ Configure multi-node Kubernetes cluster (MicroK8s)
- ✅ Install and configure AppDynamics platform
- ✅ Understand AppDynamics architecture
- ✅ Troubleshoot distributed systems
- ✅ Manage SSL certificates and DNS
- ✅ Work with cloud security (VPN, security groups)

---

## 📊 Lab Metrics

**Per Team Resources:**
- **VMs:** 3
- **vCPUs:** 48 total
- **RAM:** 192GB total
- **Storage:** 2.1TB total
- **Cost:** ~$20 for 8-hour lab

**Total for 5 Teams:**
- **VMs:** 15
- **vCPUs:** 240 total
- **Cost:** ~$100 for 8-hour lab

---

**Questions?** Ask your instructor or refer to troubleshooting sections above.

**Happy Learning!** 🎓
