# 🚀 AppDynamics Virtual Appliance Lab - Student Guide

Welcome to the AppDynamics Virtual Appliance deployment lab! This hands-on lab will guide you through deploying a complete AppDynamics on-premises environment on AWS.

---

## 📋 Table of Contents

1. [Before You Begin](#-before-you-begin)
2. [Getting Your AWS Credentials](#-getting-your-aws-credentials)
3. [Prerequisites](#-prerequisites)
4. [Lab Deployment Steps](#-lab-deployment-steps)
5. [Accessing Your Environment](#-accessing-your-environment)
6. [Cleanup](#-cleanup)
7. [Troubleshooting](#-troubleshooting)
8. [Additional Resources](#-additional-resources)

---

## 📌 Before You Begin

### What You'll Deploy

In this lab, you will deploy a **complete AppDynamics on-premises environment** including:

- ✅ **3 Virtual Machines** (VM1, VM2, VM3) - AppDynamics Virtual Appliance cluster
- ✅ **Kubernetes Cluster** - MicroK8s 3-node cluster
- ✅ **AppDynamics Controller** - Application Performance Monitoring
- ✅ **Events Service** - Analytics and custom events
- ✅ **EUM Services** - End User Monitoring (Browser, Mobile)
- ✅ **Synthetic Monitoring** - Proactive synthetic tests
- ✅ **AIOps** - AI-powered anomaly detection and RCA
- ✅ **SecureApp** - Application security monitoring
- ✅ **ATD** - Automatic Transaction Diagnostics
- ✅ **Application Load Balancer** - With SSL/TLS termination
- ✅ **Route 53 DNS** - Custom domain names

**Total Deployment Time:** ~45 minutes (fully automated)

### Team Assignment

You will be assigned a **team number (1-5)**. Each team deploys to completely isolated resources:

- **Team 1:** `team1.splunkylabs.com`
- **Team 2:** `team2.splunkylabs.com`
- **Team 3:** `team3.splunkylabs.com`
- **Team 4:** `team4.splunkylabs.com`
- **Team 5:** `team5.splunkylabs.com`

⚠️ **IMPORTANT:** Always use your assigned team number in all commands!

---

## 🔑 Getting Your AWS Credentials

Your instructor will provide you with a file named `STUDENT_CREDENTIALS.txt` containing:

- AWS Access Key ID
- AWS Secret Access Key
- AWS Region (us-west-2)
- Setup instructions

**🔒 Security Note:** These credentials are shared among all students. **NEVER** commit them to Git or share them publicly.

---

## ✅ Prerequisites

### Required Software

Before starting, ensure you have the following installed on your laptop:

| Tool | Version | Install Command (macOS) | Install Command (Linux) |
|------|---------|------------------------|------------------------|
| **AWS CLI** | 2.x | `brew install awscli` | [AWS Docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html) |
| **jq** | 1.6+ | `brew install jq` | `sudo apt install jq` |
| **expect** | 5.45+ | `brew install expect` | `sudo apt install expect` |
| **ssh** | Built-in | N/A | N/A |
| **git** | 2.x | `brew install git` | `sudo apt install git` |

### Verify Prerequisites

Run the automated prerequisite check:

```bash
./scripts/check-prerequisites.sh
```

This will verify all required tools are installed and configured correctly.

---

## 🚀 Lab Deployment Steps

### Step 0: Clone the Repository

```bash
# Clone the lab repository
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# Verify you're in the correct directory
ls -la
```

### Step 1: Configure AWS CLI

Open your `STUDENT_CREDENTIALS.txt` file and run:

```bash
aws configure
```

When prompted:
- **AWS Access Key ID:** [from credentials file]
- **AWS Secret Access Key:** [from credentials file]
- **Default region name:** `us-west-2`
- **Default output format:** `json`

**Verify your AWS access:**

```bash
aws sts get-caller-identity
```

You should see:
```json
{
  "UserId": "...",
  "Account": "314839308236",
  "Arn": "arn:aws:iam::314839308236:user/lab-student"
}
```

### Step 2: Deploy Your Lab Environment

**Replace `N` with your assigned team number (1-5)**

Run each script in order:

```bash
# 1. Deploy infrastructure (10 minutes)
./deployment/01-deploy.sh --team N

# 2. Change default VM password (1 minute)
./deployment/02-change-password.sh --team N

# 3. Setup SSH keys (1 minute)
./deployment/03-setup-ssh-keys.sh --team N

# 4. Bootstrap VMs (20-25 minutes)
./deployment/04-bootstrap-vms.sh --team N

# 5. Create Kubernetes cluster (10 minutes)
./deployment/05-create-cluster.sh --team N

# 6. Configure AppDynamics (1 minute)
./deployment/06-configure.sh --team N

# 7. Install AppDynamics services (25-30 minutes)
./deployment/07-install.sh --team N

# 8. Apply license (1 minute)
./deployment/09-apply-license.sh --team N

# 9. Verify deployment (1 minute)
./deployment/08-verify.sh --team N
```

**Total Time:** ~45 minutes

### What's Happening?

Each script performs specific tasks:

| Script | What It Does | Time |
|--------|-------------|------|
| `01-deploy.sh` | Creates VPC, subnets, security groups, EC2 instances, ALB, DNS | 10 min |
| `02-change-password.sh` | Changes VM default password to `AppDynamics123!` | 1 min |
| `03-setup-ssh-keys.sh` | Configures SSH key-based authentication | 1 min |
| `04-bootstrap-vms.sh` | Extracts AppD container images, initializes appliance | 20-25 min |
| `05-create-cluster.sh` | Creates 3-node Kubernetes cluster using MicroK8s | 10 min |
| `06-configure.sh` | Updates AppDynamics configuration with team-specific settings | 1 min |
| `07-install.sh` | Installs all AppDynamics services (Controller, Events, AIOps, etc.) | 25-30 min |
| `09-apply-license.sh` | Downloads and applies AppDynamics license from S3 | 1 min |
| `08-verify.sh` | Validates all services are running correctly | 1 min |

---

## 🌐 Accessing Your Environment

Once deployment completes, you can access your AppDynamics environment:

### Controller UI

```
URL:      https://controller-teamN.splunkylabs.com/controller/
Username: admin
Password: welcome
```

⚠️ **IMPORTANT:** Change the admin password immediately after first login!

### Events Service

```
URL: https://events-teamN.splunkylabs.com
```

### SecureApp

```
URL: https://secureapp-teamN.splunkylabs.com
```

### SSH Access to VMs

```bash
# VM1 (Primary)
ssh appduser@<vm1-public-ip>
Password: AppDynamics123!

# Or use the helper script:
./scripts/ssh-vm1.sh --team N
```

### Useful Commands on VM1

```bash
# Check cluster status
appdctl show cluster

# Check all pods
kubectl get pods --all-namespaces

# Check service health
appdcli ping

# Check node resources
kubectl top nodes

# View Controller logs
kubectl logs -n cisco-controller -l app=controller --tail=50
```

---

## 🧹 Cleanup

**⚠️ CRITICAL:** Always clean up your resources when finished to avoid unnecessary AWS costs!

### Teardown Your Lab

```bash
./deployment/cleanup.sh --team N --confirm
```

This will delete:
- ✅ All EC2 instances
- ✅ Elastic IPs
- ✅ Application Load Balancer
- ✅ Target Groups
- ✅ Security Groups
- ✅ Subnets
- ✅ Internet Gateway
- ✅ Route Tables
- ✅ VPC
- ✅ DNS records

**Cleanup Time:** 5-10 minutes

### Verify Cleanup

After cleanup completes, verify all resources are deleted:

```bash
# Check for remaining EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Team,Values=teamN" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table

# Check for remaining VPCs
aws ec2 describe-vpcs \
  --filters "Name=tag:Team,Values=teamN" \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "No module named 'awscli'"

**Solution:** Reinstall AWS CLI:
```bash
# macOS
brew reinstall awscli

# Linux
pip3 install --upgrade awscli
```

#### 2. "Permission denied (publickey)"

**Solution:** Ensure you ran step 3 (SSH key setup):
```bash
./deployment/03-setup-ssh-keys.sh --team N
```

#### 3. "Bootstrap is taking too long"

**Cause:** VM bootstrap involves extracting 15GB+ of container images

**Solution:** Wait patiently. The script shows progress:
```
VM1 bootstrap: Extracting images (running)... (elapsed: 15m)
```

**Normal bootstrap time:** 15-20 minutes per VM

#### 4. "SecureApp shows Failed"

**Cause:** `appdcli ping` falsely reports SecureApp as "Failed"

**Solution:** Check actual pod health:
```bash
./scripts/ssh-vm1.sh --team N
kubectl get pods -n cisco-secureapp
```

If pods are Running → SecureApp is healthy (ignore `appdcli ping`)

#### 5. "Controller shows 503 after license application"

**Cause:** Controller pod restarts after license is applied

**Solution:** Wait 5-10 minutes for Controller to restart. This is normal.

#### 6. "Database is locked" error during installation

**Cause:** MySQL InnoDB cluster is still initializing

**Solution:** The script automatically waits for MySQL. If it fails:
```bash
# Re-run the installation (it's idempotent)
./deployment/07-install.sh --team N
```

### Getting Help

If you encounter issues:

1. **Check logs:**
   ```bash
   ls -la logs/teamN/
   cat logs/teamN/deployment-*.log
   ```

2. **Check script output:**
   - Scripts provide detailed error messages
   - Look for "❌ FAILED" messages

3. **Review documentation:**
   - `docs/LAB_GUIDE.md` - Detailed lab guide
   - `docs/QUICK_REFERENCE.md` - Common commands
   - `docs/DATABASE_LOCK_FIX.md` - MySQL troubleshooting

4. **Contact your instructor**

---

## 📚 Additional Resources

### Official AppDynamics Documentation

- **Virtual Appliance AWS Deployment:** [Splunk AppDynamics Docs](https://help.splunk.com/en/appdynamics-on-premises/virtual-appliance-self-hosted/25.7.0/deploy-splunk-appdynamics-on-premises-virtual-appliance/amazon-web-services-aws)
- **AppD Virtual Appliance Repository:** [GitHub - Appdynamics/appd-virtual-appliance](https://github.com/Appdynamics/appd-virtual-appliance)

### Lab Repository

- **Lab Repository:** [GitHub - sandbreak80/dec25_lab](https://github.com/sandbreak80/dec25_lab)
- **Issues/Questions:** Use GitHub Issues for non-sensitive questions

### Lab Documentation

| Document | Purpose |
|----------|---------|
| `README.md` | Project overview and quick reference |
| `docs/LAB_GUIDE.md` | Comprehensive lab guide with detailed explanations |
| `docs/QUICK_REFERENCE.md` | Quick command reference |
| `docs/IAM_REQUIREMENTS.md` | AWS IAM permissions details |
| `docs/DATABASE_LOCK_FIX.md` | MySQL troubleshooting guide |
| `docs/LICENSE_MANAGEMENT.md` | License management instructions |
| `docs/RESOURCE_INVENTORY.md` | Complete list of AWS resources created |

### Useful Scripts

| Script | Purpose |
|--------|---------|
| `scripts/check-prerequisites.sh` | Verify all required tools are installed |
| `scripts/ssh-vm1.sh` | Quick SSH to VM1 |
| `scripts/check-bootstrap-progress.sh` | Monitor bootstrap progress |

---

## 🎯 Lab Objectives

By the end of this lab, you will have:

✅ Deployed a complete AppDynamics on-premises environment on AWS  
✅ Created a 3-node Kubernetes cluster  
✅ Installed and configured the AppDynamics Controller  
✅ Deployed Events Service, EUM, Synthetic, AIOps, ATD, and SecureApp  
✅ Configured SSL/TLS with Application Load Balancer  
✅ Set up custom DNS with Route 53  
✅ Applied an AppDynamics license  
✅ Verified all services are healthy  
✅ Learned how to clean up AWS resources  

---

## ⚠️ Important Reminders

- 🔢 **Always use your assigned team number** (1-5) in all commands
- 🔒 **Never commit AWS credentials to Git**
- 🧹 **Always run cleanup when finished** to avoid AWS charges
- 🔐 **Change default passwords immediately** after first login
- 💬 **Ask for help** if you get stuck - your instructor is here to help!

---

## 🎉 Ready to Begin?

1. **Open your `STUDENT_CREDENTIALS.txt` file**
2. **Follow the deployment steps above**
3. **Enjoy the lab!**

---

**Questions?** Contact your instructor or refer to the documentation in the `docs/` folder.

**Lab Repository:** https://github.com/sandbreak80/dec25_lab  
**Last Updated:** December 17, 2025  
**Version:** 1.0
