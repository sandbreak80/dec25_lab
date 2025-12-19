# 🚀 START HERE - AppDynamics Lab Quick Start

**Deploy your AppDynamics cluster step-by-step in ~60 minutes**

**Learning Goal:** Understand each phase of deployment and practice troubleshooting.

---

## 🎯 Lab Objectives

In this lab, you will:
- ✅ Deploy AWS infrastructure (VPC, EC2, Load Balancer, DNS)
- ✅ Bootstrap AppDynamics Virtual Appliances  
- ✅ Create a Kubernetes cluster
- ✅ Install and configure AppDynamics platform
- ✅ Troubleshoot issues as they arise
- ✅ Verify deployment success

**Learning approach:** You'll run each deployment phase separately to understand the process and practice troubleshooting.

---

## ⚡ Quick Start (Step-by-Step)

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

### Step 5: Deploy Your Lab (9 Steps)

Now you'll run 9 deployment scripts, one at a time. This helps you understand each phase and practice troubleshooting.

---

#### Phase 1: Infrastructure (10 minutes)

```bash
./deployment/01-deploy.sh --team N
```

**What this does:**
- Creates VPC, subnets, internet gateway
- Launches 3 EC2 instances (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- Creates Application Load Balancer with SSL
- Sets up DNS records (`controller-teamN.splunkylabs.com`)
- Configures security groups

**Wait for:** "✅ DEPLOYMENT COMPLETE!"

---

#### Phase 2: Change Password (1 minute)

```bash
./deployment/02-change-password.sh --team N
```

**What this does:**
- Changes default password from `changeme` to `AppDynamics123!`

**Why:** The Virtual Appliance requires password change on first login.

---

#### Phase 3: Setup SSH Keys (1 minute)

```bash
./deployment/03-setup-ssh-keys.sh --team N
```

**What this does:**
- Generates SSH key pair
- Installs public key on all 3 VMs
- Enables passwordless access

**Why:** Makes subsequent steps easier (no password prompts).

---

#### Phase 4: Bootstrap VMs (20 minutes)

```bash
./deployment/04-bootstrap-vms.sh --team N
```

**What this does:**
- Runs `appdctl host init` on each VM
- Configures storage (LVM for data disk)
- Installs MicroK8s
- Extracts container images (this takes 15-20 min)
- Configures networking and firewall
- Sets up passwordless sudo (fixes DEFECT-004)

**Wait for:** "✅ BOOTSTRAP COMPLETE on all VMs!"

**Script shows progress:** Updates every 60 seconds with elapsed time.

**Learning moment:** If bootstrap takes longer than expected, SSH to a VM and run `appdctl show boot` to see detailed status.

---

#### Phase 5: Create Cluster (10 minutes)

```bash
./deployment/05-create-cluster.sh --team N
```

**What this does:**
- Verifies bootstrap completed successfully
- Runs `appdctl cluster init <VM2_IP> <VM3_IP>` on VM1
- Creates 3-node high-availability Kubernetes cluster

**Wait for:** "✅ CLUSTER INITIALIZATION COMPLETE!"

**Learning moment:** After completion, run `appdctl show cluster` on VM1 to see all 3 nodes.

---

#### Phase 6: Configure AppDynamics (1 minute)

```bash
./deployment/06-configure.sh --team N
```

**What this does:**
- Updates `globals.yaml.gotmpl` with your team's DNS names
- Sets Controller URL, Events Service URL, etc.

---

#### Phase 7: Install Services (30 minutes)

```bash
./deployment/07-install.sh --team N
```

**What this does:**
- Runs `appdcli start all small`
- Waits for MySQL InnoDB cluster to be ready (fixes DEFECT-003)
- Installs Controller, EUM, Events Service, AIOps, ATD, SecureApp

**Script shows progress:** Updates every 60 seconds with elapsed time.

**Wait for:** "✅ INSTALLATION COMPLETE!"

**Learning moment:** During the wait, SSH to VM1 and watch pods being created with `kubectl get pods -A -w`

---

#### Phase 8: Verify Deployment (1 minute)

```bash
./deployment/08-verify.sh --team N
```

**What this does:**
- Checks all services are running
- Verifies cluster health
- Shows Controller URL

**Look for:** All services showing "Success"

---

#### Phase 9: Apply License (1 minute)

```bash
./deployment/09-apply-license.sh --team N
```

**What this does:**
- Uploads license from S3 to Controller
- Applies license

**Total time:** ~60-70 minutes for all 9 phases

---

## 📊 What You'll Get

After all 9 phases complete:

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
- 3-node Kubernetes cluster

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

**Problem:** Wrong AWS profile or permission issue (DEFECT-001 - FIXED)

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

**Problem:** IAM permissions insufficient (DEFECT-002 - FIXED)

**Fix:**
1. Verify your credentials are correct
2. Contact instructor (they may need to update your IAM policy)
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

**Problem:** Race condition during installation (DEFECT-003 - FIXED)

**Fix:**
✅ This is now automatically handled! The script waits for MySQL to be ready before proceeding.

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

Use this to track your progress through all 9 phases:

- [ ] **Prerequisites**
  - [ ] AWS credentials configured
  - [ ] Authentication verified (`aws sts get-caller-identity`)
  - [ ] Repository cloned
  - [ ] VPN connected (if required)

- [ ] **Phase 1:** Infrastructure deployed (`01-deploy.sh`)
- [ ] **Phase 2:** Password changed (`02-change-password.sh`)
- [ ] **Phase 3:** SSH keys setup (`03-setup-ssh-keys.sh`)
- [ ] **Phase 4:** VMs bootstrapped (`04-bootstrap-vms.sh`)
- [ ] **Phase 5:** Cluster created (`05-create-cluster.sh`)
- [ ] **Phase 6:** AppD configured (`06-configure.sh`)
- [ ] **Phase 7:** Services installed (`07-install.sh`)
- [ ] **Phase 8:** Deployment verified (`08-verify.sh`)
- [ ] **Phase 9:** License applied (`09-apply-license.sh`)

- [ ] **Verification**
  - [ ] Controller accessible at URL
  - [ ] Logged in successfully
  - [ ] Password changed
  - [ ] All services show "Success"

---

## 🔍 Verify Deployment

### Check All Services Are Running

```bash
# SSH to VM1
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
- Mention which phase failed (1-9)

---

## 📚 Documentation

### For Students
- **START_HERE.md** (this file) - Quick start guide
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

1. ✅ All 9 deployment phases completed without errors
2. ✅ Controller UI loads at `https://controller-teamN.splunkylabs.com/controller/`
3. ✅ You can log in with `admin/welcome`
4. ✅ All services show "Success" in `appdcli ping`
5. ✅ Dashboard shows "Platform Services: OK"

---

## 🎯 Learning Objectives

By completing this 9-step deployment, you will learn:

- ✅ AWS infrastructure components (VPC, EC2, ALB, Route53)
- ✅ Kubernetes cluster architecture and setup
- ✅ AppDynamics platform components and their roles
- ✅ Troubleshooting distributed systems
- ✅ Service health monitoring and verification
- ✅ Common deployment issues and their fixes

---

## 🔒 Security Reminders

- ⚠️ **Never** commit AWS credentials to git
- ⚠️ **Never** share your credentials with other teams
- ⚠️ **Always** change default passwords
- ⚠️ **Always** clean up resources when done
- ⚠️ **Only** use for lab purposes

---

## ⚡ Alternative: Automated Deployment (For Instructors Only)

**Note:** This is for instructor testing only. Students should use the 9-step process above for learning.

If you need to deploy quickly without the learning experience:

```bash
./deployment/full-deploy.sh --team N
```

This runs all 9 phases automatically with no interaction required (60-70 minutes).

**Why students shouldn't use this:**
- You miss learning what each phase does
- You can't practice troubleshooting between steps
- You don't see intermediate outputs
- It's harder to debug if something fails

---

## 📈 Monitoring Your Progress

### Between Phases

After each phase completes, you can check status:

```bash
# SSH to VM1
ssh appduser@<VM1-IP>

# Check bootstrap status (after Phase 4)
appdctl show boot

# Check cluster status (after Phase 5)
appdctl show cluster

# Check service status (after Phase 7)
appdcli ping
appdcli status

# Check pod status (after Phase 7)
kubectl get pods -A
```

---

**Ready? Let's start!** 🚀

**Begin with Phase 1:**
```bash
./deployment/01-deploy.sh --team <YOUR-TEAM-NUMBER>
```

Then proceed through phases 2-9 as shown above.

**Between phases:**
- Read what each script does
- Observe the output
- If you hit an error, check the troubleshooting sections
- Ask questions!
- Don't rush - understanding is more important than speed

---

**Questions during deployment?**
- Check QUICK_REFERENCE.md for commands
- Check common_issues.md for known issues
- Review the troubleshooting section above
- Ask your instructor

---

**Last Updated:** December 19, 2025  
**Version:** 2.0 - Step-by-Step Edition  
**Status:** ✅ All critical defects fixed  
**Approach:** 9 steps for hands-on learning 📚
