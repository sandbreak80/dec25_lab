# AppDynamics Virtual Appliance - Multi-Team AWS Lab Guide

**Version:** 25.4.0 (Multi-Team Edition)  
**Last Updated:** December 3, 2025  
**Lab Duration:** ~3.5 hours hands-on  
**Teams:** 5 (20 students total)  
**Difficulty:** Intermediate

---

## 🎯 Quick Navigation

**Students:** Start with [docs/QUICK_START.md](docs/QUICK_START.md) for step-by-step instructions!  
**Instructors:** See [lab-guide/00-INSTRUCTOR-SETUP.md](lab-guide/00-INSTRUCTOR-SETUP.md) for pre-lab setup!

---

## Table of Contents

1. [Overview](#overview)
2. [Multi-Team Architecture](#multi-team-architecture)
3. [Prerequisites](#prerequisites)
4. [Phase 1: AWS Infrastructure Deployment](#phase-1-aws-infrastructure-deployment)
5. [Phase 2: VM Bootstrap](#phase-2-vm-bootstrap)
6. [Phase 3: Kubernetes Cluster Creation](#phase-3-kubernetes-cluster-creation)
7. [Phase 4: AppDynamics Configuration](#phase-4-appdynamics-configuration)
8. [Phase 5: AppDynamics Installation](#phase-5-appdynamics-installation)
9. [Phase 6: Verification & Access](#phase-6-verification--access)
10. [Phase 7: Cleanup](#phase-7-cleanup)
11. [Troubleshooting](#troubleshooting)
12. [Cost Management](#cost-management)
13. [Additional Resources](#additional-resources)

---

## Overview

This lab guide provides a **complete multi-team deployment system** for AppDynamics Virtual Appliance on AWS. Each team builds their own **isolated, production-grade infrastructure** from scratch.

### What's Unique About This Lab

✅ **Multi-Team Architecture** - 5 isolated teams, no interference  
✅ **Production-Grade SSL** - ALB + ACM certificates (not self-signed!)  
✅ **Complete Automation** - 7 simple commands for full deployment  
✅ **Fixed Vendor Issues** - 31 vendor documentation bugs fixed  
✅ **Cost Optimized** - ~$20 per team for 8-hour lab  
✅ **Real Infrastructure** - Actual AWS resources, not simulation

### What Each Team Builds

```
Complete AppDynamics Environment:
├── AWS Infrastructure
│   ├── VPC (10.N.0.0/16)
│   ├── 2 Subnets (multi-AZ)
│   ├── Internet Gateway
│   ├── Security Groups (VM + ALB)
│   ├── 3 EC2 Instances (m5a.4xlarge)
│   ├── Application Load Balancer
│   └── Route 53 DNS
│
├── Kubernetes Cluster
│   └── 3-node MicroK8s (HA)
│
└── AppDynamics Services
    ├── Controller
    ├── Events Service
    ├── EUM (End User Monitoring)
    ├── Synthetic Monitoring
    ├── AIOps (Anomaly Detection)
    ├── ATD (Auto Transaction Diagnostics)
    └── SecureApp (Secure Application)
```

### Lab Environment

- **Teams:** 5 teams of 4 students (20 total)
- **Duration:** 3.5 hours hands-on work
- **Cost:** ~$20 per team (~$100 total for 8-hour lab)
- **Architecture:** Production-grade with ALB + ACM SSL
- **Isolation:** Complete per-team VPC isolation

---

## Multi-Team Architecture

### Team Isolation

Each team gets:
- **Unique VPC:** `10.N.0.0/16` (N = team number 1-5)
- **Unique DNS:** `teamN.splunkylabs.com`
- **Unique Resources:** Separate VMs, ALB, security groups
- **No Cross-Talk:** Teams cannot access each other

### Infrastructure Per Team

| Resource | Specification | Quantity |
|----------|---------------|----------|
| VPC | /16 CIDR | 1 |
| Subnets | /24 CIDR, multi-AZ | 2 |
| Internet Gateway | - | 1 |
| EC2 Instances | m5a.4xlarge (16 vCPU, 64GB RAM) | 3 |
| EBS Storage | 200GB OS + 500GB data per VM | 3 sets |
| Application Load Balancer | - | 1 |
| Target Group | - | 1 |
| Security Groups | VM + ALB | 2 |
| Route 53 A Records | - | 4 |

### Shared Resources (All Teams)

- **ACM Certificate:** `*.splunkylabs.com` (wildcard)
- **Route 53 Hosted Zone:** `splunkylabs.com`
- **S3 Bucket:** AMI storage (read-only access)
- **IAM Role:** `vmimport` (for AMI import)

### Network Architecture

```
Team 1: 10.1.0.0/16
├── Subnet 1: 10.1.0.0/24 (us-west-2a)
├── Subnet 2: 10.1.1.0/24 (us-west-2b)
├── VMs: 10.1.0.10, 10.1.0.11, 10.1.0.12
└── DNS: team1.splunkylabs.com

Team 2: 10.2.0.0/16
├── Subnet 1: 10.2.0.0/24 (us-west-2a)
├── Subnet 2: 10.2.1.0/24 (us-west-2b)
├── VMs: 10.2.0.10, 10.2.0.11, 10.2.0.12
└── DNS: team2.splunkylabs.com

... (Teams 3-5 follow same pattern)
```

### Security Architecture

**Per-Team Isolation:**
- Separate VPCs (no VPC peering)
- Isolated security groups
- Separate IAM credentials
- Individual cleanup

**SSH Access:**
- Restricted to instructor IP only
- No cross-team SSH access
- Students use instructor's access point

**HTTPS Access:**
- Public via ALB (required for agents)
- Valid ACM SSL certificate
- No browser warnings!

---

## Prerequisites

### For Students

**Required:**
- [ ] Laptop with SSH client
- [ ] Team assignment (1-5)
- [ ] AWS credentials from instructor
- [ ] Git installed
- [ ] Text editor

**Recommended:**
- [ ] Basic AWS knowledge
- [ ] Basic Linux/terminal skills
- [ ] Kubernetes concepts (helpful but not required)

### For Instructors

**Pre-Lab Setup (Required):**
- [ ] ACM wildcard certificate for `*.splunkylabs.com` requested and validated
- [ ] IAM users or roles created for 5 teams
- [ ] AppDynamics VA AMI uploaded to S3
- [ ] Route 53 hosted zone for `splunkylabs.com` configured
- [ ] Instructor IP configured in scripts
- [ ] Test deployment verified

**See:** [lab-guide/00-INSTRUCTOR-SETUP.md](lab-guide/00-INSTRUCTOR-SETUP.md) for complete pre-lab checklist.

### Software Requirements

All scripts require:
```bash
# Check on your system:
aws --version      # AWS CLI v2.x
jq --version       # JSON processor
ssh -V             # OpenSSH client
git --version      # Git
```

### AWS Quotas (Per Team)

Verify sufficient quotas in your region:
- **EC2 Instances:** 3x m5a.4xlarge (48 vCPUs)
- **EBS Volumes:** 2,100 GB total (700GB per VM)
- **Application Load Balancers:** 1
- **Elastic IPs:** Not required (using ALB)

**Total for 5 teams:** 240 vCPUs, 10,500 GB storage, 5 ALBs

---

## Phase 1: AWS Infrastructure Deployment

**Time:** 30 minutes (automated)  
**Command:** `./lab-deploy.sh --team N`

### What This Does

Automatically creates:
1. VPC with CIDR `10.N.0.0/16`
2. Two subnets in different AZs
3. Internet Gateway and route table
4. Security groups (VM and ALB)
5. 3 EC2 instances (m5a.4xlarge)
6. Application Load Balancer with SSL
7. Route 53 DNS records

### Step-by-Step

```bash
# 1. Navigate to repository
cd /path/to/appd-virtual-appliance/deploy/aws

# 2. Run deployment (replace N with your team number 1-5)
./lab-deploy.sh --team 1

# 3. Wait for completion (~30 minutes)
# Script shows progress for each phase

# 4. Verify deployment
./scripts/check-status.sh --team 1
```

### What You'll See

```
╔══════════════════════════════════════════════════════════════════╗
║   Deploy AWS Infrastructure - Team 1                            ║
╚══════════════════════════════════════════════════════════════════╝

Phase 1: Network Infrastructure
  ✅ VPC created: vpc-xxxxx
  ✅ Subnet 1 created: subnet-xxxxx (10.1.0.0/24)
  ✅ Subnet 2 created: subnet-xxxxx (10.1.1.0/24)
  ✅ Internet Gateway attached
  ✅ Route table configured

Phase 2: Security Groups
  ✅ VM security group created
  ✅ ALB security group created
  ✅ Ingress rules configured

Phase 3: EC2 Instances
  ✅ VM1 launched: i-xxxxx (10.1.0.10)
  ✅ VM2 launched: i-xxxxx (10.1.0.11)
  ✅ VM3 launched: i-xxxxx (10.1.0.12)
  ⏳ Waiting for instances to be ready...
  ✅ All instances running

Phase 4: Application Load Balancer
  ✅ Target group created
  ✅ ALB created: appd-team1-alb
  ✅ HTTPS listener configured (ACM cert)
  ✅ HTTP redirect configured (80→443)
  ✅ Targets registered
  ⏳ Waiting for ALB to be active...
  ✅ ALB active

Phase 5: DNS Configuration
  ✅ controller-team1.splunkylabs.com → ALB
  ✅ customer1-team1.auth.splunkylabs.com → ALB
  ✅ *.team1.splunkylabs.com → ALB

╔══════════════════════════════════════════════════════════════════╗
║   ✅ AWS Infrastructure Deployment Complete!                     ║
╚══════════════════════════════════════════════════════════════════╝

📊 Deployment Summary:
  VPC:         vpc-xxxxx (10.1.0.0/16)
  VMs:         3 instances running
  ALB:         appd-team1-alb (Active)
  DNS:         team1.splunkylabs.com

🔗 Access:
  SSH to VM1:  ssh appduser@<VM1-PUBLIC-IP>
  Controller:  https://controller-team1.splunkylabs.com/
              (will be available after installation)

📝 Next Step:
  ./appd-bootstrap-vms.sh --team 1
```

### Verification

Check deployment status:
```bash
./scripts/check-status.sh --team 1
```

Expected output:
```
✅ VPC:     vpc-xxxxx (10.1.0.0/16)
✅ Subnets: 2 subnets in 2 AZs
✅ VMs:     3 instances running
✅ ALB:     Active, 3 healthy targets
✅ DNS:     4 records configured
✅ SSL:     ACM certificate attached
```

### Troubleshooting Phase 1

**Issue: Script fails with "quota exceeded"**
- Check AWS quotas: EC2 Dashboard → Limits
- Request quota increase if needed
- Wait 10-15 minutes for quota increase

**Issue: ALB health checks failing**
- Expected at this stage! VMs not configured yet
- Continue to Phase 2

**Issue: DNS not resolving**
- Wait 2-3 minutes for propagation
- Test: `nslookup controller-team1.splunkylabs.com`

---

## Phase 2: VM Bootstrap

**Time:** 1 hour (guided manual steps)  
**Command:** `./appd-bootstrap-vms.sh --team N`

### What This Does

Guides you through interactive setup on each VM:
1. Configure hostname
2. Set static IP address
3. Configure network gateway
4. Set DNS servers
5. Verify connectivity

### Why Manual?

The `appdctl host init` command is **interactive** and requires:
- Manual input for each VM
- Password authentication
- Verification at each step

The script provides **all the values** you need to enter!

### Step-by-Step

```bash
# 1. Run bootstrap script
./appd-bootstrap-vms.sh --team 1

# 2. Script shows instructions for VM1
# Example output:
╔══════════════════════════════════════════════════════════╗
║   Bootstrap VM1                                          ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM1
  ssh appduser@44.232.63.139

Step 2: Run bootstrap command:
  sudo appdctl host init

Step 3: When prompted, enter:
  Hostname:   team1-vm-1
  IP Address: 10.1.0.10/24
  Gateway:    10.1.0.1
  DNS:        10.1.0.2

Step 4: Verify boot status:
  appdctl show boot
  
  All services should show "Succeeded"

Step 5: (IMPORTANT) Change default password:
  passwd

  Default password: changeme
  New password: <choose secure password>

Step 6: Exit and return to this script:
  exit

Press ENTER when VM1 bootstrap is complete...

# 3. Repeat for VM2 and VM3
# Script provides values for each VM
```

### Bootstrap Values Reference

| VM | Hostname | Private IP | Public IP | Gateway | DNS |
|----|----------|------------|-----------|---------|-----|
| VM1 | team1-vm-1 | 10.1.0.10/24 | (dynamic) | 10.1.0.1 | 10.1.0.2 |
| VM2 | team1-vm-2 | 10.1.0.11/24 | (dynamic) | 10.1.0.1 | 10.1.0.2 |
| VM3 | team1-vm-3 | 10.1.0.12/24 | (dynamic) | 10.1.0.1 | 10.1.0.2 |

### Verification

On each VM after bootstrap:

```bash
# Check boot status
appdctl show boot

# Expected output:
NAME                | STATUS    | ERROR
--------------------+-----------+-------
cert-setup          | Succeeded | --
enable-time-sync    | Succeeded | --
firewall-setup      | Succeeded | --
hostname            | Succeeded | --
microk8s-setup      | Succeeded | --
ssh-setup           | Succeeded | --
storage-setup       | Succeeded | --

# Check network connectivity
ping -c 3 10.1.0.11  # From VM1 to VM2
ping -c 3 10.1.0.12  # From VM1 to VM3
ping -c 3 google.com # Internet connectivity

# All should succeed
```

### Troubleshooting Phase 2

**Issue: SSH connection refused**
- Wait 2-3 minutes for VM to fully boot
- Verify security group allows SSH from instructor IP
- Check: `./scripts/check-status.sh --team 1`

**Issue: `appdctl show boot` shows failures**
- Most common: `microk8s-setup` takes time
- Wait 5 minutes and rerun command
- If persistent, reboot VM: `sudo reboot`

**Issue: VMs cannot ping each other**
- Verify IP addresses entered correctly
- Check: `ip addr show`
- Gateway should be `10.N.0.1` (N = team number)

**Issue: No internet connectivity**
- Verify gateway: `ip route show`
- Check DNS: `cat /etc/resolv.conf`
- Ping gateway: `ping 10.N.0.1`

---

## Phase 3: Kubernetes Cluster Creation

**Time:** 15 minutes (guided)  
**Command:** `./appd-create-cluster.sh --team N`

### What This Does

Creates a 3-node high-availability Kubernetes cluster using MicroK8s.

### Step-by-Step

```bash
# 1. Run cluster creation script
./appd-create-cluster.sh --team 1

# 2. Script shows exact command to run:
╔══════════════════════════════════════════════════════════╗
║   Create Kubernetes Cluster - Team 1                    ║
╚══════════════════════════════════════════════════════════╝

Step 1: SSH to VM1 (primary node)
  ssh appduser@<VM1-IP>

Step 2: Run cluster init command:
  appdctl cluster init 10.1.0.11 10.1.0.12

  When prompted for passwords, enter the password you set during bootstrap.
  (You'll be prompted twice - once for each worker node)

Step 3: Wait for cluster creation (~10 minutes)
  The command will:
  - Add VM2 (10.1.0.11) to cluster
  - Add VM3 (10.1.0.12) to cluster
  - Configure high availability
  - Label nodes

Step 4: Verify cluster status:
  appdctl show cluster

  Expected output:
  NODE            | ROLE  | RUNNING
  ----------------+-------+---------
  10.1.0.10:19001 | voter | true
  10.1.0.11:19001 | voter | true
  10.1.0.12:19001 | voter | true

Step 5: Verify Kubernetes:
  microk8s status

  Should show: "microk8s is running"
                "high-availability: yes"

Step 6: Exit and return:
  exit

Press ENTER when cluster creation is complete...

# 3. Follow the instructions
# 4. Cluster is created!
```

### What Happens During Cluster Creation

1. **VM2 joins cluster** (~5 minutes)
   - SSH connection to VM2
   - MicroK8s cluster join
   - Node labeling

2. **VM3 joins cluster** (~5 minutes)
   - SSH connection to VM3
   - MicroK8s cluster join
   - Node labeling

3. **Cluster finalization** (~1 minute)
   - High-availability configuration
   - Node status verification
   - Kubeconfig updates

### Verification

```bash
# On VM1, check cluster:
appdctl show cluster

# Expected output:
NODE            | ROLE  | RUNNING
----------------+-------+---------
10.1.0.10:19001 | voter | true
10.1.0.11:19001 | voter | true
10.1.0.12:19001 | voter | true

# Check MicroK8s status:
microk8s status

# Expected:
microk8s is running
high-availability: yes
datastore master nodes: 10.1.0.10:19001 10.1.0.11:19001 10.1.0.12:19001

# Check nodes:
kubectl get nodes

# Expected:
NAME            STATUS   ROLES    AGE   VERSION
team1-vm-1      Ready    master   10m   v1.30.14
team1-vm-2      Ready    master   8m    v1.30.14
team1-vm-3      Ready    master   7m    v1.30.14
```

### Troubleshooting Phase 3

**Issue: "Insufficient Permissions to Access Microk8s"**
- Log out and log back in: `exit`, then SSH again
- Groups updated, need new session

**Issue: Node stuck in "Not Ready"**
- Wait 2-3 minutes for node initialization
- Check logs: `microk8s inspect`

**Issue: Cluster join fails**
- Verify VMs can reach each other: `ping 10.N.0.11`
- Check firewall: `sudo ufw status`
- Password incorrect? Try again

**Issue: Only 2 nodes in cluster**
- One join failed - rerun for that node:
  ```bash
  microk8s add-node
  # Follow instructions on worker node
  ```

---

## Phase 4: AppDynamics Configuration

**Time:** 10 minutes (automated)  
**Command:** `./appd-configure.sh --team N`

### What This Does

Automatically updates `globals.yaml.gotmpl` on VM1 with:
- Team-specific DNS domain (`team1.splunkylabs.com`)
- Team-specific DNS names for authentication
- Team-specific external URLs for services
- Shows you the exact changes being made

### Step-by-Step

```bash
# 1. Run configuration script
./appd-configure.sh --team 1

# 2. Script automatically:
#    - Downloads globals.yaml.gotmpl from VM1
#    - Makes team-specific changes
#    - Shows you the diff
#    - Uploads updated file back to VM1

# 3. Review changes (example):
╔══════════════════════════════════════════════════════════╗
║   Auto-Configure AppDynamics - Team 1                   ║
╚══════════════════════════════════════════════════════════╝

📥 Downloading current configuration from VM1...
✅ Downloaded: globals.yaml.gotmpl

📝 Applying team-specific configuration changes...

Changes to be made:
  - dnsDomain: team1.splunkylabs.com
  - dnsNames:
      - customer1-team1.auth.splunkylabs.com
      - customer1-tnt-authn-team1.splunkylabs.com
  - externalUrl: https://team1.splunkylabs.com/...

✅ Configuration updated

📤 Uploading configuration to VM1...
✅ Configuration uploaded successfully!

✅ Configuration complete!

📝 Next Step:
  ./appd-install.sh --team 1

# 4. Done! Configuration automated!
```

### What Gets Changed

From default `nip.io` to team-specific:

| Setting | Before | After (Team 1) |
|---------|--------|----------------|
| dnsDomain | `<ingress-ip>.nip.io` | `team1.splunkylabs.com` |
| dnsNames[0] | `customer1.auth.<ip>.nip.io` | `customer1-team1.auth.splunkylabs.com` |
| dnsNames[1] | `customer1-tnt-authn.<ip>.nip.io` | `customer1-tnt-authn-team1.splunkylabs.com` |
| Events externalUrl | `https://<ip>.nip.io/events` | `https://team1.splunkylabs.com/events` |
| AIOps externalUrl | `https://<ip>.nip.io/aiops` | `https://team1.splunkylabs.com/aiops` |

### Verification

```bash
# Script automatically verifies on VM1:
ssh appduser@<VM1-IP>

# Check DNS domain:
grep 'dnsDomain:' /var/appd/config/globals.yaml.gotmpl
# Should show: dnsDomain: team1.splunkylabs.com

# Check DNS names:
grep -A 6 'dnsNames:' /var/appd/config/globals.yaml.gotmpl
# Should show team1-specific names

exit
```

### Troubleshooting Phase 4

**Issue: Cannot download file from VM1**
- Check SSH access: `ssh appduser@<VM1-IP>`
- Verify file exists: `ls /var/appd/config/globals.yaml.gotmpl`

**Issue: Configuration looks wrong**
- Review: `cat globals.yaml.gotmpl.updated` locally
- Re-run script to regenerate

**Issue: Upload fails**
- Disk space: SSH to VM1, run `df -h`
- Permissions: `ls -la /var/appd/config/`

---

## Phase 5: AppDynamics Installation

**Time:** 30 minutes (guided)  
**Command:** `./appd-install.sh --team N`

### What This Does

Guides you through installing ALL AppDynamics services with a single command:
```bash
appdcli start all small
```

This installs:
- Controller
- Events Service
- EUM (End User Monitoring)
- Synthetic Monitoring
- AIOps (Anomaly Detection)
- ATD (Automatic Transaction Diagnostics)
- SecureApp (Secure Application)
- Authentication Service

### Step-by-Step

```bash
# 1. Run installation script
./appd-install.sh --team 1

# 2. Script provides instructions:
╔══════════════════════════════════════════════════════════╗
║   Install AppDynamics Services - Team 1                 ║
╚══════════════════════════════════════════════════════════╝

Installation includes ALL services:
  ✓ Controller
  ✓ Events Service
  ✓ EUM (End User Monitoring)
  ✓ Synthetic Monitoring
  ✓ AIOps
  ✓ ATD (Auto Transaction Diagnostics)
  ✓ SecureApp (Secure Application)

Time: 20-30 minutes

Step 1: SSH to VM1
  ssh appduser@<VM1-IP>

Step 2: Start installation
  appdcli start all small

Step 3: Monitor installation
  The command will show progress as services are deployed.
  Watch for "Install successful" message.

Step 4: Monitor pods (in another terminal)
  watch kubectl get pods --all-namespaces

  Wait for all pods to show "Running" status.
  This can take 20-30 minutes.

Step 5: Verify services
  appdcli ping

  Expected:
  | Service Endpoint    | Status  |
  |=====================|=========|
  | Controller          | Success |
  | Events              | Success |
  | EUM Collector       | Success |
  | EUM Aggregator      | Success |
  | EUM Screenshot      | Success |
  | Synthetic Shepherd  | Success |
  | Synthetic Scheduler | Success |
  | Synthetic Feeder    | Success |
  | AD/RCA Services     | Success |
  | SecureApp           | Success |
  | ATD                 | Success |

Step 6: Exit
  exit

Press ENTER when installation is complete...

# 3. Follow the instructions
# 4. Wait for installation (~30 minutes)
# 5. All services installed!
```

### Installation Progress

You'll see output like:

```
Decrypting secret /var/appd/config/secrets.yaml.encrypted
Building dependency release=cert-manager, chart=charts/cert-manager
Building dependency release=mysql, chart=charts/mysql
...

UPDATED RELEASES:
NAME           NAMESPACE       CHART                  VERSION   DURATION
cert-manager   cert-manager    charts/cert-manager    v1.16.1   1s
mysql          mysql           charts/mysql           0.0.1     16s
controller     cisco-controller charts/controller     0.0.1     4s
...

Install successful
```

### Monitoring Installation

While installation runs, monitor in another terminal:

```bash
# SSH to VM1
ssh appduser@<VM1-IP>

# Watch all pods:
watch kubectl get pods --all-namespaces

# Check resource usage:
kubectl top nodes

# Check specific namespace:
kubectl get pods -n cisco-controller
```

### Expected Namespaces & Pods

After installation completes:

| Namespace | Pods | Purpose |
|-----------|------|---------|
| cert-manager | 3 | Certificate management |
| mysql | 4 | Database cluster |
| postgres | 2 | PostgreSQL for Events |
| redis | 2 | Cache layer |
| kafka | 1 | Message queue |
| cisco-controller | 10+ | Controller service |
| cisco-events | 5+ | Events service |
| cisco-eum | 8+ | End User Monitoring |
| cisco-synthetic | 3+ | Synthetic monitoring |
| cisco-aiops | 20+ | AIOps/anomaly detection |
| cisco-atd | 2+ | Auto Transaction Diagnostics |
| cisco-secureapp | 5+ | Secure Application |
| authn | 4+ | Authentication |

**Total:** ~80-100 pods across all namespaces

### Verification

```bash
# Check service status:
appdcli ping

# All should show "Success"

# Check pod status:
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Should return no results (all running)

# Check resource usage:
kubectl top nodes

# Should show reasonable CPU/memory usage
```

### Troubleshooting Phase 5

**Issue: Installation fails with "Permission denied on secrets.yaml"**
- Fix permissions:
  ```bash
  sudo chmod 644 /var/appd/config/secrets.yaml
  ```
- Retry installation

**Issue: Pods stuck in "Pending"**
- Check resources: `kubectl top nodes`
- Wait a few minutes for resource allocation
- If persistent after 10 minutes, may need larger VMs

**Issue: MySQL pods crashing**
- Common during initialization
- Wait 5 minutes for automatic recovery
- Check logs: `kubectl logs <pod-name> -n mysql`

**Issue: "AD/RCA Services" shows "Failed"**
- Wait 5-10 minutes - these services take time to initialize
- Check: `kubectl get pods -n cisco-aiops`
- Recheck: `appdcli ping`

**Issue: Controller shows "Failed" after 20 minutes**
- Check Controller pods: `kubectl get pods -n cisco-controller`
- Check logs: `kubectl logs -n cisco-controller -l app=controller`
- May need to restart Controller pod

---

## Phase 6: Verification & Access

**Time:** 10 minutes  
**Command:** `./appd-check-health.sh --team N`

### Access Controller UI

```bash
# 1. Get your team's URL from script output
URL: https://controller-team1.splunkylabs.com/controller/

# 2. Open in browser
# (Valid SSL - no warnings!)

# 3. Log in with default credentials:
Username: admin
Password: welcome

# 4. IMMEDIATELY change password!
Account Settings → Change Password
New password: (choose secure password)
```

### Verify All Services

Run health check script:
```bash
./appd-check-health.sh --team 1
```

Expected output:
```
╔══════════════════════════════════════════════════════════╗
║   AppDynamics Health Check - Team 1                     ║
╚══════════════════════════════════════════════════════════╝

📊 Service Status:
  ✅ Controller:          Success
  ✅ Events:              Success
  ✅ EUM Collector:       Success
  ✅ EUM Aggregator:      Success
  ✅ EUM Screenshot:      Success
  ✅ Synthetic Shepherd:  Success
  ✅ Synthetic Scheduler: Success
  ✅ Synthetic Feeder:    Success
  ✅ AD/RCA Services:     Success
  ✅ SecureApp:           Success
  ✅ ATD:                 Success

📦 Pod Status:
  Total Pods:    87
  Running:       84
  Pending:       3 (normal during initialization)
  Failed:        0

💻 Resource Usage:
  Node 1: CPU 42%, Memory 35%
  Node 2: CPU 38%, Memory 32%
  Node 3: CPU 35%, Memory 28%

🌐 Access URLs:
  Controller:    https://controller-team1.splunkylabs.com/controller/
  Events:        https://controller-team1.splunkylabs.com/events/
  EUM Collector: https://controller-team1.splunkylabs.com/eumcollector/

✅ All systems operational!
```

### Test Features

In Controller UI:

1. **Create Application**
   - Applications → Create Application
   - Name: "Test App"
   - Type: Java

2. **View Dashboard**
   - Navigate to application dashboard
   - Verify all widgets load

3. **Check License**
   - Settings → License
   - Apply license file if available

4. **Explore Features**
   - EUM: Applications → Test App → End User Monitoring
   - Synthetic: Synthetic Monitoring tab
   - AIOps: AI/ML menu
   - SecureApp: Security tab

### Troubleshooting Phase 6

**Issue: Browser shows SSL warning**
- Clear browser cache
- Verify URL: `https://controller-team1.splunkylabs.com/controller/`
- Check DNS: `nslookup controller-team1.splunkylabs.com`
- Should point to ALB, not direct EC2 IP

**Issue: Cannot log in with admin/welcome**
- Password may have been changed
- Contact instructor for password reset instructions

**Issue: Controller loads but features missing**
- Some services still initializing
- Wait 5-10 minutes
- Check `appdcli ping` on VM1

**Issue: 404 errors on some pages**
- DNS propagation delay
- Wait 5 minutes and retry
- Flush browser cache

---

## Phase 7: Cleanup

**Time:** 5 minutes  
**Command:** `./lab-cleanup.sh --team N --confirm`

### ⚠️ CRITICAL: Cleanup is REQUIRED

**Why cleanup matters:**
- Cost: ~$2.50/hour per team if left running
- That's $60/day per team!
- $300/day for all 5 teams if not cleaned up!

### How to Cleanup

```bash
# 1. Run cleanup script with --confirm flag
./lab-cleanup.sh --team 1 --confirm

# 2. Script will:
#    - Delete DNS records
#    - Delete ALB
#    - Delete target groups
#    - Terminate EC2 instances
#    - Delete security groups
#    - Delete subnets
#    - Delete Internet Gateway
#    - Delete VPC
#    - Clean up local state files

# 3. Verify cleanup
./scripts/check-status.sh --team 1

# Should show:
❌ VPC:  Not found (cleaned up)
❌ VMs:  Not found (cleaned up)
❌ ALB:  Not found (cleaned up)
✅ Cleanup verified!
```

### Cleanup Output

```
╔══════════════════════════════════════════════════════════╗
║   Cleanup Team 1 Resources                              ║
╚══════════════════════════════════════════════════════════╝

⚠️  This will DELETE all resources for Team 1!
   - DNS records (4)
   - Application Load Balancer
   - EC2 instances (3)
   - Security groups (2)
   - Subnets (2)
   - Internet Gateway
   - VPC

Continue? Type 'DELETE' to confirm: DELETE

🗑️  Deleting DNS records...
  ✅ controller-team1.splunkylabs.com deleted
  ✅ *.team1.splunkylabs.com deleted

🗑️  Deleting ALB...
  ✅ ALB deleted

🗑️  Terminating EC2 instances...
  ✅ i-xxxxx terminated
  ✅ i-xxxxx terminated
  ✅ i-xxxxx terminated

🗑️  Deleting security groups...
  ✅ appd-team1-vm-sg deleted
  ✅ appd-team1-alb-sg deleted

🗑️  Deleting network resources...
  ✅ Subnets deleted
  ✅ Internet Gateway deleted
  ✅ VPC deleted

🧹 Cleaning up local state files...
  ✅ state/team1/ removed

╔══════════════════════════════════════════════════════════╗
║   ✅ Cleanup Complete!                                   ║
╚══════════════════════════════════════════════════════════╝

All Team 1 resources have been deleted.
Verify: ./scripts/check-status.sh --team 1
```

### Verification After Cleanup

```bash
# Check AWS resources are gone:
./scripts/check-status.sh --team 1

# Check your AWS account:
aws ec2 describe-instances --filters "Name=tag:Team,Values=1" \
  --query "Reservations[].Instances[].InstanceId"
# Should return: []

# Check VPC:
aws ec2 describe-vpcs --filters "Name=tag:Team,Values=1" \
  --query "Vpcs[].VpcId"
# Should return: []

# Check ALB:
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'team1')]"
# Should return: []
```

### What Doesn't Get Deleted

These are shared and used by all teams:
- ✅ ACM Certificate (*.splunkylabs.com)
- ✅ Route 53 Hosted Zone (splunkylabs.com)
- ✅ S3 Bucket (AppDynamics AMI)
- ✅ IAM Role (vmimport)

Instructor will clean these up after all teams finish.

### Troubleshooting Cleanup

**Issue: Script fails to delete resources**
- Check if resources have dependencies
- Wait 2 minutes for AWS eventual consistency
- Re-run cleanup script

**Issue: VPC deletion fails**
- ENIs may still be attached
- Wait 5 minutes and retry
- Manually check: AWS Console → VPC → Your VPCs

**Issue: "Resource not found" errors**
- Already deleted - that's okay!
- Script continues with remaining resources

---

## Troubleshooting

### General Troubleshooting Steps

1. **Check documentation**
   - Most issues are documented
   - See troubleshooting sections in each phase

2. **Check status script**
   ```bash
   ./scripts/check-status.sh --team N
   ```

3. **Check health script**
   ```bash
   ./appd-check-health.sh --team N
   ```

4. **Check AWS Console**
   - EC2 instances running?
   - Security groups correct?
   - ALB healthy?

5. **Check VM logs**
   ```bash
   ssh appduser@<VM-IP>
   kubectl get pods --all-namespaces
   kubectl logs <pod-name> -n <namespace>
   ```

6. **Ask for help**
   - Ask team members
   - Ask instructor
   - Check VENDOR_DOC_ISSUES.md

### Common Issues & Solutions

#### "AWS quota exceeded"
**Symptom:** `lab-deploy.sh` fails with quota error  
**Solution:**
- Check quotas: EC2 Dashboard → Limits
- Request increase: Service Quotas → EC2
- Wait 10-15 minutes for approval

#### "Cannot SSH to VM"
**Symptom:** Connection refused or timeout  
**Solution:**
- Wait 2-3 minutes for boot
- Check security group allows your IP
- Verify instance running: `./scripts/check-status.sh --team N`

#### "DNS not resolving"
**Symptom:** `nslookup` fails or points to wrong IP  
**Solution:**
- Wait 2-3 minutes for propagation
- Flush local DNS cache
- Verify Route 53 records in AWS Console

#### "ALB health checks failing"
**Symptom:** Target group shows unhealthy  
**Solution:**
- Expected before AppD installation!
- After installation, wait 10 minutes
- Check AppD services: `appdcli ping` on VM1

#### "Pods stuck in Pending"
**Symptom:** `kubectl get pods` shows Pending  
**Solution:**
- Check resources: `kubectl top nodes`
- Wait 5 minutes for scheduling
- If persistent, check pod events:
  ```bash
  kubectl describe pod <pod-name> -n <namespace>
  ```

#### "Services show 'Failed' in appdcli ping"
**Symptom:** Some services don't start  
**Solution:**
- Wait 10-15 minutes (initialization takes time)
- Check specific namespace pods
- Review logs for errors

### Getting Help

**Priority 1: Documentation**
- Check this guide
- Check phase-specific troubleshooting
- Check VENDOR_DOC_ISSUES.md

**Priority 2: Team**
- Discuss with team members
- Compare your setup with working team

**Priority 3: Scripts**
- Run diagnostic scripts
- Check status and health

**Priority 4: Instructor**
- Describe what you tried
- Show error messages
- Share relevant logs

---

## Cost Management

### Cost Breakdown Per Team

**8-Hour Lab Day:**

| Resource | Cost |
|----------|------|
| 3× m5a.4xlarge EC2 (8 hrs) | $16.51 |
| 2,100 GB EBS storage | $2.33 |
| Application Load Balancer | $0.18 |
| Data transfer | ~$0.50 |
| **Total** | **~$19.52** |

**24 Hours (if not cleaned up):**
- ~$58.56 per team
- ~$293 for all 5 teams

**7 Days (if not cleaned up):**
- ~$410 per team
- ~$2,050 for all 5 teams ⚠️

### Cost Optimization

**REQUIRED:**
- ✅ Run cleanup at end of lab day
- ✅ Verify all resources deleted
- ✅ Check AWS bill next day

**Optional:**
- Use smaller instances for testing (m5a.2xlarge)
- Stop instances overnight (requires restart steps)
- Use Reserved Instances for longer labs

### Monitoring Costs

```bash
# Check your AWS costs:
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-04 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Team

# Set up budget alert:
# AWS Console → Billing → Budgets
# Create budget: $25 per team
# Alert at 80% ($20)
```

---

## Additional Resources

### Documentation Files

**Student Guides:**
- [QUICK_START.md](docs/QUICK_START.md) - Step-by-step walkthrough
- [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) - Command cheat sheet
- [SECUREAPP_GUIDE.md](docs/SECUREAPP_GUIDE.md) - SecureApp details

**Instructor Guides:**
- [00-INSTRUCTOR-SETUP.md](lab-guide/00-INSTRUCTOR-SETUP.md) - Pre-lab setup

**Technical Documentation:**
- [MULTI_TEAM_LAB_ARCHITECTURE.md](MULTI_TEAM_LAB_ARCHITECTURE.md) - Architecture
- [VENDOR_DOC_ISSUES.md](VENDOR_DOC_ISSUES.md) - 31 vendor issues fixed
- [OPTIONAL_SERVICES_GUIDE.md](OPTIONAL_SERVICES_GUIDE.md) - AIOps, ATD, etc.
- [PASSWORD_MANAGEMENT.md](PASSWORD_MANAGEMENT.md) - Credential handling

### External Resources

**AppDynamics Documentation:**
- Virtual Appliance: https://docs.appdynamics.com/va
- Controller: https://docs.appdynamics.com/controller
- Agents: https://docs.appdynamics.com/agents

**AWS Documentation:**
- VPC Guide: https://docs.aws.amazon.com/vpc/
- ALB Guide: https://docs.aws.amazon.com/elasticloadbalancing/
- ACM: https://docs.aws.amazon.com/acm/

**Kubernetes:**
- MicroK8s: https://microk8s.io/docs
- kubectl: https://kubernetes.io/docs/reference/kubectl/

### Support

**During Lab:**
- Check documentation first
- Ask team members
- Ask instructor

**After Lab:**
- Review recorded materials
- Practice with personal AWS account
- Join AppDynamics community forums

---

## Summary

You've built a complete, production-grade AppDynamics environment!

### What You Built

✅ AWS Infrastructure (VPC, subnets, ALB, DNS)  
✅ 3-Node Kubernetes Cluster  
✅ Complete AppDynamics Deployment  
✅ Production SSL Configuration  
✅ Multi-Service Architecture

### What You Learned

✅ AWS networking and security  
✅ Load balancer configuration  
✅ SSL certificate management  
✅ Kubernetes administration  
✅ Enterprise software deployment  
✅ Troubleshooting complex systems  
✅ Cloud cost management

### Skills You Can Use

- Deploy production infrastructure
- Configure enterprise applications
- Troubleshoot distributed systems
- Manage cloud costs
- Work in teams
- Follow best practices

**These skills are directly applicable to real production deployments!**

---

## Appendix: Command Reference

### Quick Command List

```bash
# Deploy
./lab-deploy.sh --team N
./appd-bootstrap-vms.sh --team N
./appd-create-cluster.sh --team N
./appd-configure.sh --team N
./appd-install.sh --team N

# Verify
./appd-check-health.sh --team N
./scripts/check-status.sh --team N

# Access
./scripts/ssh-vm1.sh --team N

# Cleanup
./lab-cleanup.sh --team N --confirm
```

### Helper Scripts

```bash
# Check infrastructure status
./scripts/check-status.sh --team N

# SSH to VM1
./scripts/ssh-vm1.sh --team N

# Verify deployment
./scripts/verify-deployment.sh --team N

# Check AppDynamics health
./appd-check-health.sh --team N

# Install SecureApp (optional)
./appd-install-secureapp.sh --team N
```

### On VM Commands

```bash
# Boot status
appdctl show boot

# Cluster status
appdctl show cluster
microk8s status

# Service status
appdcli ping

# Pod status
kubectl get pods --all-namespaces

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Logs
kubectl logs <pod-name> -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>
```

---

**🎉 Congratulations on completing the lab!**

**Status:** Ready for production use!  
**Version:** 1.0 Multi-Team Edition  
**Last Updated:** December 2025
