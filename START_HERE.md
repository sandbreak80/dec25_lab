# 🚀 START HERE - AppDynamics Lab Quick Start

**Deploy your AppDynamics cluster in ~60 minutes with ONE COMMAND!**

---

## 🎯 TL;DR - Quick Deploy

**If you just want to get started:**

1. Get AWS credentials from instructor
2. Configure AWS CLI: `aws configure` (enter credentials)
3. Clone repo: `git clone https://github.com/sandbreak80/dec25_lab.git && cd dec25_lab`
4. Deploy: `./deployment/full-deploy.sh --team N` (replace N with your team number)
5. Wait 60-70 minutes ☕
6. Access Controller: `https://controller-teamN.splunkylabs.com/controller/`

**That's it!** The full deployment is 100% automated.

---

## ⚡ Quick Start (Detailed Steps)

### Step 1: Get AWS Credentials

Your instructor will provide you with:
- AWS Access Key ID
- AWS Secret Access Key
- Team number (1-5)

### Step 2: Configure AWS CLI

```bash
# Install AWS CLI (if needed)
# macOS:
brew install awscli

# Linux:
sudo apt install awscli

# Configure credentials
aws configure

# Enter when prompted:
AWS Access Key ID: [from instructor]
AWS Secret Access Key: [from instructor]
Default region name: us-west-2
Default output format: json
```

### Step 3: Verify Configuration

```bash
# Test AWS authentication
aws sts get-caller-identity

# Should show:
{
  "Account": "314839308236",
  "Arn": "arn:aws:iam::314839308236:user/lab-student"
}
```

✅ **If you see this, you're ready!**

### Step 4: Clone Repository

```bash
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab
```

### Step 5: Deploy Your Lab (ONE COMMAND!)

```bash
# Replace N with your team number (1-5)
./deployment/full-deploy.sh --team N
```

**This ONE command automatically runs all steps:**
- ✅ Checks prerequisites
- ✅ Creates VPC and networking
- ✅ Launches 3 EC2 instances
- ✅ Changes default password
- ✅ Sets up SSH keys (passwordless)
- ✅ Bootstraps all VMs
- ✅ Creates Kubernetes cluster
- ✅ Configures AppDynamics
- ✅ Installs all services (Controller, EUM, Events, AIOps, SecureApp)
- ✅ Applies license
- ✅ Verifies deployment

**Total time:** ~60-70 minutes (fully automated, no interaction needed!)

**What you'll see:**
```
╔══════════════════════════════════════════════════════════╗
║   🚀 Full Non-Interactive AppDynamics Deployment 🚀      ║
╚══════════════════════════════════════════════════════════╝

[1/11] Prerequisites Check
[2/11] Deploy Infrastructure (10 min)
[3/11] Change VM Password (1 min)
[4/11] Setup SSH Keys (1 min)
[5/11] Bootstrap VMs (20 min)
[6/11] Create Kubernetes Cluster (10 min)
[7/11] Configure AppDynamics (1 min)
[8/11] Install AppDynamics Services (30 min)
[9/11] Apply License (1 min)
[10/11] Configure SecureApp (optional)
[11/11] Verify Deployment (1 min)
```

**Just run it and wait!** The script shows real-time progress.

---

## 📊 What You'll Get

After deployment completes:

### Your Controller
- **URL:** `https://controller-teamN.splunkylabs.com/controller/`
- **Username:** `admin`
- **Password:** `welcome`
- **⚠️ Change password immediately after first login!**

### Your Infrastructure
- 3× EC2 instances (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- Load balancer with SSL certificate
- DNS: `teamN.splunkylabs.com`
- Isolated VPC with security groups

---

## 🐛 Common Issues & Quick Fixes

### ❌ "Unable to locate credentials"

**Problem:** AWS CLI not configured

**Fix:**
```bash
aws configure
# Re-enter your credentials
```

### ❌ Script exits silently with no error

**Problem:** Wrong AWS profile or permission issue

**Fix:**
```bash
# Verify authentication
aws sts get-caller-identity

# Check you're using default profile
echo $AWS_PROFILE
# Should be empty or "default"

# If not empty, unset it
unset AWS_PROFILE
```

### ❌ "An error occurred (UnauthorizedOperation)"

**Problem:** IAM permissions insufficient

**Fix:**
1. Verify your credentials are correct
2. Contact instructor (you may need updated IAM policy)
3. Test permissions:
```bash
./scripts/test-aws-cli.sh
```

### ❌ "SSH timeout" or "Connection refused"

**Problem:** Not connected to VPN

**Fix:**
1. Connect to VPN
2. Verify: `curl https://ifconfig.me`
3. Retry deployment

### ❌ "MySQL database is locked" error

**Problem:** Race condition during installation (FIXED)

**Fix:**
✅ This is now automatically handled! The script waits for MySQL to be ready.

If you still see this error, wait 2 minutes and it should resolve.

### ❌ Services stuck in "Starting" after 30 minutes

**Problem:** Possible pod crash or resource issue

**Fix:**
```bash
# SSH to VM1
ssh appduser@<VM1-IP>

# Check pod status
kubectl get pods -A | grep -v Running

# Check specific pod logs
kubectl logs <pod-name> -n <namespace>

# If needed, restart the service
appdcli stop <service-name>
appdcli start <service-name>
```

---

## 📋 Deployment Checklist

Use this to track your progress:

- [ ] AWS credentials configured
- [ ] Authentication verified (`aws sts get-caller-identity`)
- [ ] Repository cloned
- [ ] VPN connected (if required)
- [ ] Started deployment: `./deployment/01-deploy.sh --team N`
- [ ] Infrastructure created (~10 min)
- [ ] VMs bootstrapped (~20 min)
- [ ] Cluster created (~10 min)
- [ ] AppDynamics installed (~30 min)
- [ ] Controller accessible at `https://controller-teamN.splunkylabs.com/controller/`
- [ ] Logged in successfully
- [ ] Password changed
- [ ] License applied (if instructor provided)

---

## 🔍 Verify Deployment

### Check All Services Are Running

```bash
# From your laptop
ssh appduser@<VM1-IP>

# On VM1
appdcli ping

# All services should show "Success"
```

### Check Kubernetes Cluster

```bash
# On VM1
appdctl show cluster

# Should show 3 nodes, all "Running: true"
```

### Check Individual Services

```bash
# On VM1
kubectl get pods -A

# All pods should be "Running" with 1/1 or 2/2 ready
```

---

## 🧹 Cleanup (When Done)

**⚠️ IMPORTANT:** Delete resources to avoid charges!

```bash
./deployment/cleanup.sh --team N --confirm
```

This removes:
- All EC2 instances
- Load balancer
- VPC and networking
- DNS records
- Elastic IPs

**Cost:** ~$20 per team per 8-hour day

---

## 🆘 Getting Help

### Quick Troubleshooting
1. Check **QUICK_REFERENCE.md** for common commands
2. Check **TROUBLESHOOTING_GUIDE.md** for detailed fixes
3. Check **common_issues.md** for FAQ

### Test Your AWS Setup
```bash
./scripts/test-aws-cli.sh
```

### Contact Instructor
- Include your team number
- Include error messages (screenshots help!)
- Include output of `aws sts get-caller-identity`

---

## 📚 Documentation

### For Students
- **START_HERE.md** (this file) - Quick start
- **QUICK_REFERENCE.md** - Common commands
- **common_issues.md** - FAQ and troubleshooting
- **docs/LAB_GUIDE.md** - Detailed step-by-step guide

### For Instructors
- **TROUBLESHOOTING_GUIDE.md** - Detailed fixes for all issues
- **STUDENT_DEPLOYMENT_DEFECTS.md** - Known issues and resolutions
- **IAM_ACCESS_KEY_CREATION_GUIDE.md** - How to create student credentials
- **INSTRUCTOR_SETUP_GUIDE.md** - Pre-lab setup checklist

---

## ✅ Success Criteria

Your lab is successful when:

1. ✅ Controller UI loads at `https://controller-teamN.splunkylabs.com/controller/`
2. ✅ You can log in with `admin/welcome`
3. ✅ All services show "Success" in `appdcli ping`
4. ✅ Dashboard shows "Platform Services: OK"
5. ✅ You can create an application and see data flowing

---

## 🎯 Learning Objectives

After completing this lab, you will understand:

- ✅ AppDynamics architecture and components
- ✅ Kubernetes cluster deployment
- ✅ AWS infrastructure automation
- ✅ Load balancing and SSL certificates
- ✅ Application monitoring setup
- ✅ Troubleshooting distributed systems

---

## 🔒 Security Reminders

- ⚠️ **Never** commit AWS credentials to git
- ⚠️ **Never** share your credentials with other teams
- ⚠️ **Always** change default passwords
- ⚠️ **Always** clean up resources when done
- ⚠️ **Only** use for lab purposes

---

## ⚡ Advanced Options

### Option 1: One-Command Deployment (RECOMMENDED) ⭐

**The easy way - just one command!**

```bash
./deployment/full-deploy.sh --team N
```

This automatically runs ALL steps (1-11) with no interaction required!  
**Time:** 60-70 minutes  
**User interaction:** ZERO!

### Option 2: Manual Step-by-Step Deployment

If you prefer to run each phase separately or need to troubleshoot:

```bash
# Phase 1: Infrastructure (10 min)
./deployment/01-deploy.sh --team N

# Phase 2: Change password (1 min)
./deployment/02-change-password.sh --team N

# Phase 3: Setup SSH keys - Optional (1 min)
./deployment/03-setup-ssh-keys.sh --team N

# Phase 4: Bootstrap VMs (20 min)
./deployment/04-bootstrap-vms.sh --team N

# Phase 5: Create cluster (10 min)
./deployment/05-create-cluster.sh --team N

# Phase 6: Configure AppD (1 min)
./deployment/06-configure.sh --team N

# Phase 7: Install services (30 min)
./deployment/07-install.sh --team N

# Phase 8: Verify (1 min)
./deployment/08-verify.sh --team N

# Phase 9: Apply license (1 min)
./deployment/09-apply-license.sh --team N
```

**Use this if:**
- You want to understand each step
- You need to troubleshoot a specific phase
- You're testing script modifications

### SSH to Your VMs

```bash
# Quick SSH scripts
./scripts/ssh-vm1.sh --team N
./scripts/ssh-vm2.sh --team N
./scripts/ssh-vm3.sh --team N

# Manual SSH
ssh appduser@<VM-PUBLIC-IP>
# Password: AppDynamics123!
```

---

## 📈 Monitoring Progress

### During Deployment

The script shows real-time progress:
```
[INFO] Phase 1/9: Infrastructure deployment
[INFO] Phase 2/9: Changing passwords
[INFO] Phase 3/9: Bootstrapping VMs (this takes 20 minutes)
[INFO] Elapsed time: 5 minutes... VMs still bootstrapping
[INFO] Phase 4/9: Creating cluster
[INFO] Phase 5/9: Configuring AppDynamics
[INFO] Phase 6/9: Installing services (this takes 30 minutes)
[INFO] Elapsed time: 10 minutes... services still installing
```

### Manual Progress Check

```bash
# SSH to VM1
ssh appduser@<VM1-IP>

# Check bootstrap status
appdctl show boot

# Check cluster status
appdctl show cluster

# Check service status
appdcli ping
appdcli status

# Check pod status
kubectl get pods -A
```

---

**Ready? Let's go!** 🚀

**ONE COMMAND DEPLOYMENT:**
```bash
./deployment/full-deploy.sh --team <YOUR-TEAM-NUMBER>
```

Sit back, relax, and watch the magic happen! ☕

---

**Want to run steps manually?** Check the "Advanced Options" section above.

**Questions during deployment?**
- Check QUICK_REFERENCE.md
- Check common_issues.md
- Ask your instructor

---

**Last Updated:** December 19, 2025  
**Version:** 2.0  
**Status:** ✅ All critical defects fixed  
**Deployment:** ONE COMMAND! 🚀
