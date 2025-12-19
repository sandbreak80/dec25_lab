# Lab Deployment Troubleshooting Guide

**Version:** 1.0  
**Last Updated:** December 19, 2025  
**Audience:** Students, Instructors, Lab Administrators

---

## Table of Contents

1. [DEFECT-001: Silent Deployment Failures](#defect-001-silent-deployment-failures)
2. [DEFECT-002: IAM Permission Issues](#defect-002-iam-permission-issues)
3. [DEFECT-003: MySQL Database Lock Errors](#defect-003-mysql-database-lock-errors)
4. [DEFECT-004: SSH Key Breaking](#defect-004-ssh-key-breaking)
5. [DEFECT-005: No Progress Feedback](#defect-005-no-progress-feedback)
6. [DEFECT-006: SecureApp Vulnerability Feeds](#defect-006-secureapp-vulnerability-feeds)
7. [DEFECT-007: EUM Configuration](#defect-007-eum-configuration)
8. [DEFECT-008: ADRUM JavaScript Hosting](#defect-008-adrum-javascript-hosting)

---

## DEFECT-001: Silent Deployment Failures

### Problem Description

Scripts exit silently with no error messages after printing initial configuration.

```
ℹ️  Using AMI: ami-092d9aa0e2874fd9c
ℹ️  Subnet: subnet-049c8d0a70c14dc65
ℹ️  Security Group: sg-041bfbf8b403c6d41

[script exits - no error]
```

### Root Cause

AWS profile mismatch - scripts configured to use `lab-student` profile but students only have `[default]` configured in `~/.aws/credentials`.

### Diagnostic Steps

**1. Check AWS Configuration:**
```bash
# View configured profiles
cat ~/.aws/credentials

# Test AWS CLI
aws sts get-caller-identity

# If you see error:
# "The config profile (lab-student) could not be found"
# Then you have the profile mismatch issue
```

**2. Test Which Profile Works:**
```bash
# Test default profile
aws sts get-caller-identity --profile default

# Test lab-student profile (will fail if not configured)
aws sts get-caller-identity --profile lab-student
```

**3. Check Script Configuration:**
```bash
# View what profile scripts are using
grep AWS_PROFILE config/team*.cfg
```

### Fix Option 1: Update Your AWS Config (STUDENT FIX)

**If you already have credentials in `[default]` profile:**

```bash
# Pull latest code (config files now use 'default')
cd dec25_lab
git pull origin main

# Verify it worked
grep AWS_PROFILE config/team1.cfg
# Should show: AWS_PROFILE="default"

# Test AWS CLI
./scripts/test-aws-cli.sh
```

**If you need to configure AWS CLI:**

```bash
# Run AWS configure (creates [default] profile)
aws configure

# Enter your credentials:
# AWS Access Key ID: [from instructor]
# AWS Secret Access Key: [from instructor]
# Default region name: us-west-2
# Default output format: json

# Verify it works
aws sts get-caller-identity
```

### Fix Option 2: Add lab-student Profile (ALTERNATIVE)

If you want to keep scripts using `lab-student` profile:

```bash
# Edit AWS credentials file
nano ~/.aws/credentials

# Add lab-student profile:
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[lab-student]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

# Save and test
aws sts get-caller-identity --profile lab-student
```

### Verification

```bash
# Test AWS CLI directly
aws sts get-caller-identity

# Should return:
{
  "UserId": "AIDAXXXXXXXXX",
  "Account": "314839308236",
  "Arn": "arn:aws:iam::314839308236:user/lab-student"
}

# Run diagnostic script
./scripts/test-aws-cli.sh

# Expected output:
# ✅ AWS CLI configured correctly
# ✅ Using credentials for: lab-student
# ✅ Region: us-west-2
# ✅ Can access AWS services

# Try deployment script
./deployment/01-deploy.sh --team 1
# Should now proceed without silent failures
```

### Code Changes Made

**Files Modified:**
- `config/team1.cfg` through `config/team5.cfg`
- `lib/common.sh` - Enhanced `check_aws_cli()` function

**Changes:**
```bash
# Before (in config files):
AWS_PROFILE="lab-student"

# After (in config files):
AWS_PROFILE="default"

# In lib/common.sh - Enhanced error detection:
check_aws_cli() {
    echo "Checking AWS CLI configuration..."
    
    # Test AWS CLI with actual call
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" &>/dev/null; then
        echo "❌ ERROR: AWS CLI authentication failed"
        echo ""
        echo "This could mean:"
        echo "  1. AWS profile '${AWS_PROFILE}' not configured"
        echo "  2. Invalid credentials"
        echo "  3. Network connectivity issues"
        echo ""
        echo "To fix:"
        echo "  aws configure --profile ${AWS_PROFILE}"
        return 1
    fi
    
    # Show which identity is being used
    IDENTITY=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --query 'Arn' --output text)
    echo "✅ AWS CLI authenticated as: $IDENTITY"
}
```

---

## DEFECT-002: IAM Permission Issues

### Problem Description

EC2 instance creation fails during Phase 3 with no error message visible.

### Root Cause

IAM policy only granted permissions on `instance/*` resource type, but `ec2:RunInstances` requires permissions on multiple resource types.

### Diagnostic Steps

**1. Test EC2 Instance Creation Permission:**
```bash
# Dry-run test (won't create instance, just tests permissions)
aws ec2 run-instances \
  --dry-run \
  --image-id ami-092d9aa0e2874fd9c \
  --instance-type m5a.4xlarge \
  --subnet-id subnet-xxxxx \
  --security-group-ids sg-xxxxx

# If you see "UnauthorizedOperation", you have permission issues
# Expected with correct permissions: "DryRunOperation"
```

**2. Check Your IAM Permissions:**
```bash
# Get your user info
aws sts get-caller-identity

# Check if you can describe instances (read permission)
aws ec2 describe-instances --max-results 5

# Try to create a volume (tests volume permission)
aws ec2 create-volume --dry-run \
  --availability-zone us-west-2a \
  --size 10 \
  --volume-type gp3
```

**3. Review Deployment Logs:**
```bash
# Check for permission errors in deployment script
./deployment/01-deploy.sh --team 1 2>&1 | tee /tmp/deploy-debug.log

# Search for UnauthorizedOperation
grep -i "unauthorized\|permission" /tmp/deploy-debug.log
```

### Fix: Update IAM Policy (INSTRUCTOR ACTION)

**Prerequisites:**
- AWS admin access
- Access to IAM console

**Steps:**

1. **Download Updated Policy:**
   ```bash
   # Policy is in repository
   cat docs/iam-student-policy.json
   ```

2. **Apply to IAM:**
   - Log into AWS Console with admin credentials
   - Navigate to: **IAM → Policies**
   - Find: **AppDynamicsLabStudentPolicy**
   - Click: **Edit policy**
   - Switch to **JSON** tab
   - Replace entire content with updated policy
   - Click: **Review policy**
   - Click: **Save changes**

**Updated Policy Key Changes:**

```json
{
  "Sid": "EC2RunInstancesWithTypeRestriction",
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": [
    "arn:aws:ec2:us-west-2:*:instance/*",
    "arn:aws:ec2:us-west-2:*:volume/*",           // ADDED
    "arn:aws:ec2:us-west-2:*:network-interface/*", // ADDED
    "arn:aws:ec2:us-west-2:*:subnet/*",           // ADDED
    "arn:aws:ec2:us-west-2:*:security-group/*",   // ADDED
    "arn:aws:ec2:*:image/*"                       // ADDED
  ],
  "Condition": {
    "StringEquals": {
      "ec2:InstanceType": [
        "m5a.xlarge",
        "m5a.2xlarge",
        "m5a.4xlarge",
        "t3.2xlarge"
      ]
    }
  }
}
```

3. **Wait for Policy Propagation:**
   ```bash
   # IAM changes can take 1-2 minutes to propagate
   sleep 60
   ```

### Verification

**1. Test Permissions:**
```bash
# Test with dry-run (recommended)
aws ec2 run-instances \
  --dry-run \
  --image-id ami-092d9aa0e2874fd9c \
  --instance-type m5a.4xlarge \
  --subnet-id $(aws ec2 describe-subnets --filters "Name=tag:Name,Values=appd-team1-subnet-1" --query 'Subnets[0].SubnetId' --output text) \
  --security-group-ids $(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=appd-team1-sg" --query 'SecurityGroups[0].GroupId' --output text)

# Expected output:
# An error occurred (DryRunOperation) when calling the RunInstances operation: 
# Request would have succeeded, but DryRun flag is set.

# If you still see "UnauthorizedOperation":
# - Check if policy was saved correctly
# - Wait another minute for propagation
# - Verify user is in correct IAM group
```

**2. Test Full Deployment:**
```bash
# Try actual deployment
./deployment/01-deploy.sh --team 1

# Should now successfully create VMs in Phase 3
```

### Student Workaround (While Waiting for Fix)

**No student workaround available** - requires IAM policy update by instructor/administrator.

Students should:
1. Report the issue to instructor
2. Provide error output from dry-run test
3. Wait for IAM policy update
4. Retry deployment after confirmation

---

## DEFECT-003: MySQL Database Lock Errors

### Problem Description

Installation appears to succeed but some services fail with database lock errors.

```
Error: rpc error: code = Unknown desc = exec (try: 500): database is locked
```

AIOps, ATD, or SecureApp pods stuck in `Pending` or `CrashLoopBackOff` state.

### Root Cause

Race condition - installation continues before MySQL InnoDB cluster is fully ready to accept writes.

### Diagnostic Steps

**1. Check Pod Status:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check all pods
kubectl get pods --all-namespaces

# Look for pods in CrashLoopBackOff or Error state
kubectl get pods -A | grep -E "CrashLoop|Error"

# Check MySQL pods specifically
kubectl get pods -n mysql
```

**2. Check MySQL Cluster Status:**
```bash
# On VM1
kubectl get pods -n mysql

# Expected: 3 MySQL pods running
# appd-mysql-0        2/2  Running
# appd-mysql-1        2/2  Running
# appd-mysql-2        2/2  Running

# Check InnoDB cluster status
kubectl get innodbclusters -n mysql -o yaml

# Look for status.cluster.status: "ONLINE"
```

**3. Check Helm Release Status:**
```bash
# On VM1
helm list --all-namespaces

# Look for releases in "failed" or "pending-install" state
helm list -A | grep -E "failed|pending"

# Get details of failed release
helm status <release-name> -n <namespace>
```

**4. Check Installation Logs:**
```bash
# On your laptop - review installation script output
grep -i "database\|mysql\|lock" /tmp/team1-install.log
```

### Fix Option 1: Prevention (Automated in Script)

**The fix has been implemented in `deployment/07-install.sh`.**

If you're using the latest scripts, this is handled automatically:

```bash
# Just run the installation script
./deployment/07-install.sh --team 1

# Script now waits for MySQL before continuing:
# Step 2: Starting AppDynamics installation... (20-30 minutes)
# Step 3: Waiting for MySQL InnoDB cluster to be ready... (up to 5 minutes)
#    MySQL pods: 1/3 ready... (10s elapsed)
#    MySQL pods: 2/3 ready... (20s elapsed)
#    MySQL pods: 3/3 ready... (30s elapsed)
#    ✅ MySQL cluster is ready (3/3 pods running)
#    ✅ MySQL InnoDB cluster status: ONLINE
# Step 4: Waiting for services to start... (checking every 60s)
```

### Fix Option 2: Manual Recovery (If Already Broken)

**Step 1: SSH to VM1**
```bash
./scripts/ssh-vm1.sh --team 1
```

**Step 2: Identify Failed Releases**
```bash
# List all Helm releases
helm list --all-namespaces

# Common failed releases:
# - aiops (namespace: cisco-aiops)
# - atd (namespace: cisco-atd)
# - secureapp (namespace: cisco-secureapp)

# Check release status
helm status aiops -n cisco-aiops
```

**Step 3: Delete Failed Releases**
```bash
# Delete the failed release(s)
helm delete aiops -n cisco-aiops
helm delete atd -n cisco-atd
helm delete secureapp -n cisco-secureapp

# Wait for resources to clean up
sleep 30

# Verify pods are gone
kubectl get pods -n cisco-aiops
kubectl get pods -n cisco-atd
kubectl get pods -n cisco-secureapp
# Should all show "No resources found"
```

**Step 4: Verify MySQL is Healthy**
```bash
# Check MySQL pods
kubectl get pods -n mysql

# All should be Running and 2/2 ready
# If not, wait or run MySQL recovery:
appdcli run mysql_restore

# Wait for MySQL cluster to be ready
watch kubectl get pods -n mysql
# Wait until all 3 pods show 2/2 Running
```

**Step 5: Reinstall Failed Components**
```bash
# Option A: Reinstall specific components
appdcli start aiops small
appdcli start atd small

# Option B: Reinstall everything
appdcli stop appd
sleep 30
appdcli start appd small

# Monitor installation
watch "kubectl get pods --all-namespaces | grep -v Running"
```

**Step 6: Exit and Re-run Installation Script**
```bash
# Exit VM
exit

# Re-run installation from laptop
./deployment/07-install.sh --team 1
```

### Fix Option 3: Complete MySQL Reset (Nuclear Option)

**Use only if MySQL cluster is broken and won't recover:**

```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Stop all AppDynamics services
appdcli stop appd
appdcli stop aiops
appdcli stop operators

# Delete MySQL completely
helm delete mysql -n mysql
kubectl delete namespace mysql

# Wait for cleanup
sleep 60

# Verify cleanup
kubectl get all -n mysql
# Should show: "No resources found"

# Exit VM
exit

# Re-run installation from scratch
./deployment/07-install.sh --team 1
```

### Verification

**1. Check All Pods Are Running:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check all namespaces
kubectl get pods --all-namespaces

# Should see mostly "Running" status
# A few may show "Completed" - that's OK
# None should be in CrashLoopBackOff or Error

# Check specific namespaces
kubectl get pods -n cisco-controller
kubectl get pods -n cisco-events
kubectl get pods -n cisco-eum
kubectl get pods -n cisco-aiops
kubectl get pods -n mysql
```

**2. Check Services are Healthy:**
```bash
# On VM1
appdcli ping

# Should show:
# Controller: Success
# Events Service: Success
# EUM: Success
# AIOps: Success
# MySQL: Success
```

**3. Test Controller Access:**
```bash
# From your laptop
curl -k https://controller-team1.splunkylabs.com/controller/rest/serverstatus

# Should return XML with status information
```

### Prevention for Future Deployments

The fix is now in `deployment/07-install.sh` (lines 212-285). Key implementation:

```bash
# Wait for MySQL InnoDB cluster to be ready
wait_for_mysql_cluster() {
    echo "Step 3: Waiting for MySQL InnoDB cluster to be ready..."
    wait_start=$(date +%s)
    max_wait=300  # 5 minutes
    
    while [ $(($(date +%s) - wait_start)) -lt $max_wait ]; do
        # Count ready MySQL pods
        mysql_ready=$(kubectl get pods -n mysql -l app=mysql \
            -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | \
            grep -o "true" | wc -l)
        
        # Need exactly 3 pods ready
        if [ "$mysql_ready" -eq 3 ]; then
            # Check InnoDB cluster status
            cluster_status=$(kubectl get innodbclusters -n mysql \
                -o jsonpath='{.items[0].status.cluster.status}' 2>/dev/null)
            
            if [ "$cluster_status" == "ONLINE" ]; then
                echo "   ✅ MySQL cluster is ready (3/3 pods running)"
                echo "   ✅ MySQL InnoDB cluster status: ONLINE"
                return 0
            fi
        fi
        
        elapsed=$(($(date +%s) - wait_start))
        echo "   MySQL pods: $mysql_ready/3 ready... (${elapsed}s elapsed)"
        sleep 10
    done
    
    echo "   ⚠️  MySQL cluster did not become ready within ${max_wait}s"
    return 1
}
```

---

## DEFECT-004: SSH Key Breaking

### Problem Description

Cluster initialization fails with password prompts or SSH connection breaks after running `appdctl cluster init`.

```
sudo: a password is required
Error: Failed to execute cluster init command
```

### Root Cause

1. Passwordless sudo not configured for `appduser`
2. Cluster init synchronizes `authorized_keys` between nodes, potentially overwriting laptop SSH keys

### Diagnostic Steps

**1. Test SSH Access:**
```bash
# Test SSH with key
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# If you get password prompt:
# - SSH key is not in authorized_keys
# - OR wrong key being used
```

**2. Test Passwordless Sudo:**
```bash
# SSH to VM
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# Test sudo without password
sudo whoami

# If you see "password for appduser:":
# - Passwordless sudo not configured
# - Cluster init will fail
```

**3. Check Authorized Keys:**
```bash
# SSH to VM
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# View authorized_keys
cat ~/.ssh/authorized_keys

# Should contain your laptop's public key
# Look for key with comment matching your laptop
```

**4. Check Sudoers Configuration:**
```bash
# SSH to VM
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# Check if passwordless sudo file exists
sudo cat /etc/sudoers.d/appduser

# Should contain:
# appduser ALL=(ALL) NOPASSWD: ALL

# If file doesn't exist or content is different:
# - Passwordless sudo not configured
```

### Fix Option 1: Prevention (Automated in Script)

**The fix is implemented in `deployment/04-bootstrap-vms.sh`.**

Using the latest script automatically configures passwordless sudo:

```bash
# Just run the bootstrap script
./deployment/04-bootstrap-vms.sh --team 1

# Script now configures passwordless sudo automatically:
# ✅ Bootstrap complete on VM1
# ⚙️  Configuring passwordless sudo on VM1...
# ✅ Passwordless sudo configured on VM1
# [repeats for VM2 and VM3]
```

Then cluster init works without passwords:

```bash
./deployment/05-create-cluster.sh --team 1

# No password prompts - fully automated
```

### Fix Option 2: Manual Configuration (If Broken)

**Step 1: Configure Passwordless Sudo on All VMs**

```bash
# For each VM (VM1, VM2, VM3):
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# Configure passwordless sudo
echo "appduser ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/appduser
sudo chmod 440 /etc/sudoers.d/appduser

# Test it
sudo whoami
# Should print "root" without asking for password

# Exit
exit
```

**Step 2: Re-add SSH Keys (If Broken After Cluster Init)**

```bash
# Get your public key
PUB_KEY=$(cat ~/.ssh/appd-team1-key.pub)

# Add to each VM
for VM_IP in 34.211.77.32 35.163.233.249 52.43.89.92; do
    ssh -o "PubkeyAuthentication=no" appduser@${VM_IP} << EOF
echo "${PUB_KEY}" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
EOF
done

# Enter password when prompted: AppDynamics123!
```

**Step 3: Test SSH Access:**

```bash
# Test all VMs
ssh -i ~/.ssh/appd-team1-key appduser@34.211.77.32 "hostname"
ssh -i ~/.ssh/appd-team1-key appduser@35.163.233.249 "hostname"
ssh -i ~/.ssh/appd-team1-key appduser@52.43.89.92 "hostname"

# Should connect without passwords
```

### Fix Option 3: Complete Cluster Rebuild

**If cluster init partially completed and is broken:**

```bash
# SSH to each VM and reset cluster
for VM_IP in VM1_IP VM2_IP VM3_IP; do
    ssh -i ~/.ssh/appd-team1-key appduser@${VM_IP} << 'EOF'
    # Stop services
    appdcli stop appd 2>/dev/null || true
    appdcli stop operators 2>/dev/null || true
    
    # Remove cluster configuration
    sudo rm -f /var/appd/config/cluster.yaml
    
    # Leave cluster
    sudo microk8s leave || true
EOF
done

# Wait for cleanup
sleep 30

# Reconfigure passwordless sudo
for VM_IP in VM1_IP VM2_IP VM3_IP; do
    ssh -i ~/.ssh/appd-team1-key appduser@${VM_IP} << 'EOF'
    echo "appduser ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/appduser
    sudo chmod 440 /etc/sudoers.d/appduser
EOF
done

# Re-run cluster creation
./deployment/05-create-cluster.sh --team 1
```

### Verification

**1. Test Passwordless Sudo:**
```bash
# Test on each VM
for VM_IP in VM1_IP VM2_IP VM3_IP; do
    echo "Testing $VM_IP..."
    ssh -i ~/.ssh/appd-team1-key appduser@${VM_IP} "sudo whoami"
done

# All should print "root" without password prompts
```

**2. Test Cluster:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check cluster status
kubectl get nodes

# Should show 3 nodes in "Ready" state
```

**3. Test Services:**
```bash
# On VM1
appdcli ping

# All services should show "Success" or "Running"
```

### Code Changes Made

**In `deployment/04-bootstrap-vms.sh`:**

```bash
# After bootstrap completes on each VM
echo "⚙️  Configuring passwordless sudo on VM${i}..."

ssh -i ~/.ssh/appd-team${TEAM_NUM}-key appduser@${VM_IP} << 'EOF'
# Create sudoers file for passwordless sudo
echo "appduser ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/appduser > /dev/null

# Set correct permissions (required for sudoers.d files)
sudo chmod 440 /etc/sudoers.d/appduser

# Validate syntax
sudo visudo -c -f /etc/sudoers.d/appduser
EOF

if [ $? -eq 0 ]; then
    echo "✅ Passwordless sudo configured on VM${i}"
else
    echo "❌ Failed to configure passwordless sudo on VM${i}"
    exit 1
fi
```

---

## DEFECT-005: No Progress Feedback

### Problem Description

Long-running operations (bootstrap, installation) provide no progress updates, leaving students uncertain if the process is working or stuck.

### Root Cause

Scripts started operations on VMs then exited immediately without waiting or monitoring progress.

### Diagnostic Steps

**1. Check if Process is Stuck or Working:**

During bootstrap (25-30 minutes):
```bash
# SSH to VM being bootstrapped
ssh -i ~/.ssh/appd-team1-key appduser@<vm-ip>

# Check bootstrap status
appdctl show boot

# Status values:
# - "Initializing" - Still working
# - "Extracting" - Still working
# - "Ready" - Complete
# - "Failed" - Error occurred

# Check running processes
ps aux | grep -E "appdctl|bootstrap|extract"

# Check disk I/O (should be high during bootstrap)
iostat -x 5 3
```

During installation (20-30 minutes):
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check pod status
kubectl get pods --all-namespaces

# Check pod events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Check service status
appdcli ping
```

**2. Check for Actual Errors:**

```bash
# On VM
journalctl -u appd-os -f

# Look for actual errors vs normal startup messages
```

### Fix: Scripts Now Include Progress Monitoring

**The fix is implemented in:**
- `deployment/04-bootstrap-vms.sh` - Bootstrap monitoring
- `deployment/07-install.sh` - Installation monitoring

**No action required** - just use the latest scripts:

```bash
# Bootstrap with progress (automated)
./deployment/04-bootstrap-vms.sh --team 1

# Example output:
# ✅ Started bootstrap on VM1
# ✅ Started bootstrap on VM2
# ✅ Started bootstrap on VM3
# ⏳ Waiting for bootstrap to complete (20-30 minutes)...
#    Still bootstrapping... (60s elapsed)
#    VM1: Extracting, VM2: Extracting, VM3: Initializing
#    Still bootstrapping... (120s elapsed)
#    VM1: Extracting, VM2: Extracting, VM3: Extracting
#    ...
#    Still bootstrapping... (1800s elapsed)
#    VM1: Ready, VM2: Ready, VM3: Ready
# ✅ All VMs bootstrapped successfully

# Installation with progress (automated)
./deployment/07-install.sh --team 1

# Example output:
# Step 2: Starting AppDynamics installation... (20-30 minutes)
# Step 3: Waiting for MySQL InnoDB cluster to be ready... (up to 5 minutes)
#    MySQL pods: 1/3 ready... (10s elapsed)
#    MySQL pods: 2/3 ready... (20s elapsed)
#    MySQL pods: 3/3 ready... (30s elapsed)
#    ✅ MySQL cluster is ready
# Step 4: Waiting for services to start... (checking every 60s)
#    Pods ready: 5/15 (60s elapsed)
#    Pods ready: 10/15 (120s elapsed)
#    Pods ready: 15/15 (1500s elapsed)
# ✅ All services started successfully
```

### Manual Monitoring (If Using Old Scripts)

**Monitor Bootstrap:**

```bash
# In one terminal - watch bootstrap status
watch -n 10 './scripts/ssh-vm1.sh --team 1 "appdctl show boot"'

# Shows status every 10 seconds
```

**Monitor Installation:**

```bash
# In one terminal - watch pod status
watch -n 30 './scripts/ssh-vm1.sh --team 1 "kubectl get pods -A"'

# Shows pod status every 30 seconds
```

### Verification

Scripts now provide regular updates. You should see:

**During Bootstrap:**
- Update every 60 seconds
- Shows elapsed time
- Shows status per VM
- Clear completion message

**During Installation:**
- Update every 60 seconds
- Shows pod counts (ready/total)
- Shows elapsed time
- Waits for MySQL before proceeding
- Clear completion message

### Code Implementation

**Bootstrap Progress Monitoring:**

```bash
# In deployment/04-bootstrap-vms.sh
echo "⏳ Waiting for bootstrap to complete (20-30 minutes)..."
wait_start=$(date +%s)
last_check=0

while true; do
    all_ready=true
    status_line=""
    
    for i in 1 2 3; do
        VM_IP=$(get_vm_ip $i)
        status=$(ssh -i ~/.ssh/appd-team${TEAM_NUM}-key appduser@${VM_IP} \
            "appdctl show boot 2>/dev/null | grep Status: | awk '{print \$2}'" || echo "Unknown")
        
        if [ "$status" != "Ready" ]; then
            all_ready=false
        fi
        status_line="${status_line}VM${i}: ${status}, "
    done
    
    if [ "$all_ready" = true ]; then
        echo "✅ All VMs bootstrapped successfully"
        break
    fi
    
    elapsed=$(($(date +%s) - wait_start))
    if [ $((elapsed - last_check)) -ge 60 ]; then
        echo "   Still bootstrapping... (${elapsed}s elapsed)"
        echo "   ${status_line%%, }"
        last_check=$elapsed
    fi
    
    sleep 10
done
```

**Installation Progress Monitoring:**

```bash
# In deployment/07-install.sh
echo "⏳ Waiting for services to start (checking every 60 seconds)..."
wait_start=$(date +%s)
max_wait=1800  # 30 minutes

while [ $(($(date +%s) - wait_start)) -lt $max_wait ]; do
    # Count total and ready pods
    total_pods=$(kubectl get pods -n cisco-controller -o json | jq '.items | length')
    ready_pods=$(kubectl get pods -n cisco-controller -o json | \
        jq '[.items[] | select(.status.phase=="Running")] | length')
    
    elapsed=$(($(date +%s) - wait_start))
    echo "   Pods ready: $ready_pods/$total_pods (${elapsed}s elapsed)"
    
    if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        echo "✅ All services started successfully"
        break
    fi
    
    sleep 60
done
```

---

## DEFECT-006: SecureApp Vulnerability Feeds

### Problem Description

`appdcli ping` shows SecureApp as "Failed" even though all pods are running. Vuln pod has high restart count.

```bash
# appdcli ping output
SecureApp: Failed
```

### Root Cause

SecureApp vulnerability feed download requires manual configuration with AppDynamics portal credentials. Installation doesn't configure this automatically.

### Diagnostic Steps

**1. Check SecureApp Status:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check overall status
appdcli ping | grep SecureApp

# Check pod status
kubectl get pods -n cisco-secureapp

# All pods should be "Running", but vuln pod may have high restart count
```

**2. Check Vuln Pod Logs:**
```bash
# On VM1
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) --tail=50

# Look for messages like:
# "on-prem feed not available, retrying later"
# "Unable to download vulnerability feeds"
```

**3. Check Feed Configuration:**
```bash
# On VM1
kubectl get configmap vuln-feed-config -n cisco-secureapp -o yaml

# Check if feed_bucket is configured
# Check if credential secret exists
kubectl get secret onprem-feed-sys -n cisco-secureapp
```

**4. Check for Feed Downloader:**
```bash
# On VM1
kubectl get cronjobs,jobs,deployments -n cisco-secureapp | grep -i feed

# Should return empty (feed downloader not configured)
```

### Fix Option 1: Configure Automatic Feed Downloads (RECOMMENDED)

**Prerequisites:**

1. **Create AppDynamics Portal User:**
   - Go to: https://accounts.appdynamics.com/
   - Log in with your AppDynamics credentials
   - Create a **non-admin user** dedicated for feed downloads
   - Note the username and password

2. **Ensure Internet Connectivity:**
   ```bash
   # On VM1
   curl -I https://download.appdynamics.com
   
   # Should return: HTTP/1.1 200 OK
   ```

**Configuration Steps:**

```bash
# Step 1: SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Step 2: Configure portal credentials
appdcli run secureapp setDownloadPortalCredentials <portal-username>

# You will be prompted:
# Enter password for <portal-username>:
# [enter password]

# Step 3: Force immediate feed download (optional)
appdcli run secureapp restartFeedProcessing

# Step 4: Monitor feed download
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) -f

# Look for:
# "Starting feed download"
# "Downloaded snyk feed"
# "Downloaded maven feed"
# "Feed processing complete"

# This may take 5-10 minutes
```

**Verification:**

```bash
# On VM1
# Wait 5-10 minutes for download, then check:

# 1. Check feed entry count
appdcli run secureapp numAgentReports

# Should show feed entries (15000+ entries for full feed)
# Example output:
# Feed entries: 15234

# 2. Check overall health
appdcli run secureapp health

# Should show feed information

# 3. Check SecureApp status
appdcli ping | grep SecureApp

# Should now show "Success" instead of "Failed"

# 4. Verify daily feed updates will occur
kubectl get cronjobs -n cisco-secureapp

# Should now show feed-sync cronjob
```

### Fix Option 2: Use SecureApp Without Feeds (LAB/TESTING)

**If vulnerability scanning isn't needed for your lab:**

SecureApp provides full runtime security monitoring without feeds:

**What Works:**
- ✅ Runtime threat detection
- ✅ Application security monitoring
- ✅ Security analytics
- ✅ Attack detection and blocking
- ✅ Security policy enforcement

**What Doesn't Work:**
- ❌ Known vulnerability (CVE) scanning
- ❌ Package vulnerability database matching

**No action required** - just accept the "Failed" status in `appdcli ping`. All core features work.

**Alternative CVE Scanning Tools:**
```bash
# Use external tools for vulnerability scanning:

# Option A: Trivy
trivy image <your-image>

# Option B: Grype
grype <your-image>

# Option C: Snyk
snyk container test <your-image>
```

### Fix Option 3: Manual Feed Upload (AIR-GAPPED ENVIRONMENTS)

**For environments without internet access:**

**Prerequisites:**
1. Obtain feed files from AppDynamics support
2. Obtain feed license key from AppDynamics support

**Steps:**

```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Copy feed files to VM (from laptop in another terminal)
scp -i ~/.ssh/appd-team1-key feed-key.txt appduser@<vm1-ip>:/tmp/
scp -i ~/.ssh/appd-team1-key snyk-feed.json.gz appduser@<vm1-ip>:/tmp/

# Back on VM1:
# Set feed license key
appdcli run secureapp setFeedKey /tmp/feed-key.txt

# Upload feed file
appdcli run secureapp uploadFeed /tmp/snyk-feed.json.gz

# Restart feed processing
appdcli run secureapp restartFeedProcessing

# Verify
appdcli run secureapp numAgentReports
```

### Troubleshooting

**Issue: "Invalid credentials" error**

```bash
# Verify portal user exists and credentials are correct
# Try logging into https://accounts.appdynamics.com/ manually

# Retry configuration
appdcli run secureapp setDownloadPortalCredentials <username>
```

**Issue: Feed download fails**

```bash
# Check internet connectivity
curl -I https://download.appdynamics.com

# Check vuln pod logs for specific errors
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) --tail=100

# Check for proxy requirements
# If behind corporate proxy, configure proxy settings
```

**Issue: Feed download times out**

```bash
# Large feed files may take 10-15 minutes
# Be patient and monitor logs
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) -f

# If truly stuck, restart vuln pod
kubectl delete pod $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) -n cisco-secureapp
```

### Verification Checklist

- [ ] Portal credentials configured successfully
- [ ] Feed download started (check vuln pod logs)
- [ ] Feed entries visible (`appdcli run secureapp numAgentReports`)
- [ ] SecureApp status changed to "Success"
- [ ] Daily feed update cronjob created
- [ ] SecureApp health check shows feed information

### Additional Resources

- Detailed Guide: `docs/SECUREAPP_FEED_FIX_GUIDE.md`
- Common Issues: `common_issues.md` (SecureApp section)
- SecureApp Documentation: https://docs.appdynamics.com/appd-cloud/en/cisco-secure-application

---

## DEFECT-007: EUM Configuration

### Problem Description

EUM pods are running but End User Monitoring functionality doesn't work. Browser agents can't send beacons, no RUM data collected.

### Root Cause

Controller Settings in admin.jsp not configured to point to correct EUM endpoints. Default values don't match team-specific hostnames.

### Diagnostic Steps

**1. Check EUM Pod Status:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check EUM pods
kubectl get pods -n cisco-eum

# Should show eum pods in "Running" state
```

**2. Test EUM Endpoints:**
```bash
# From your laptop
# Test EUM collector
curl -k https://controller-team1.splunkylabs.com/eumcollector/health

# Test EUM aggregator
curl -k https://controller-team1.splunkylabs.com/eumaggregator/health

# Test Events service
curl -k https://controller-team1.splunkylabs.com/events/health

# All should return 200 OK or {"status":"UP"}
# If 404: ingress routing issue
# If timeout: pods not running or service issue
```

**3. Check Controller Settings:**
```bash
# Access admin.jsp
# URL: https://controller-team1.splunkylabs.com/controller/admin.jsp
# Password: welcome

# Navigate to: Controller Settings
# Search for: eum.beacon.host

# If value is blank or doesn't match your hostname:
# - EUM not configured correctly
```

**4. Test Browser Agent:**
```bash
# Download ADRUM files from Controller
# Configure test page with ADRUM
# Check browser console for errors:

# Common errors when misconfigured:
# - "Failed to load resource: 404" (ADRUM files)
# - "POST /eumcollector 404" (beacon sending failed)
# - "CORS error" (beacon URL mismatch)
```

### Fix: Configure EUM Endpoints

**Step 1: Access admin.jsp**

```
URL: https://controller-team<N>.splunkylabs.com/controller/admin.jsp

Notes:
- Replace <N> with your team number
- Browser will show SSL warning - click "Advanced" → "Proceed"
- No username field (admin.jsp automatically uses 'root' user)
- Password: welcome (default - change after first login)
```

**Step 2: Navigate to Controller Settings**

```
1. In admin.jsp interface
2. Click "Controller Settings" in left navigation
3. You'll see a searchable list of properties
```

**Step 3: Configure Required Properties**

**Search for and update each property:**

| Property Name | Value Format | Example (Team 1) |
|--------------|--------------|------------------|
| `eum.beacon.host` | `controller-teamN.splunkylabs.com/eumcollector` | `controller-team1.splunkylabs.com/eumcollector` |
| `eum.beacon.https.host` | `controller-teamN.splunkylabs.com/eumcollector` | `controller-team1.splunkylabs.com/eumcollector` |
| `eum.cloud.host` | `https://controller-teamN.splunkylabs.com/eumaggregator` | `https://controller-team1.splunkylabs.com/eumaggregator` |
| `eum.es.host` | `controller-teamN.splunkylabs.com:443` | `controller-team1.splunkylabs.com:443` |
| `appdynamics.on.premise.event.service.url` | `https://controller-teamN.splunkylabs.com/events` | `https://controller-team1.splunkylabs.com/events` |
| `eum.mobile.screenshot.host` | `controller-teamN.splunkylabs.com/screenshots` | `controller-team1.splunkylabs.com/screenshots` |

**IMPORTANT NOTES:**
- Some URLs include `https://` prefix, others don't - follow table exactly
- NO trailing slashes on any URLs
- Replace `teamN` with your actual team number (team1, team2, etc.)
- Port 443 required on `eum.es.host`

**Step 4: Save and Wait**

```
1. Click "Save" or "Apply" button for each property
2. Wait 2-3 minutes for Controller to apply settings
3. (Optional) Restart Controller pod for immediate effect:

   # SSH to VM1
   ./scripts/ssh-vm1.sh --team 1
   
   # Restart Controller pod
   kubectl delete pod $(kubectl get pods -n cisco-controller -l app=controller -o name) -n cisco-controller
   
   # Wait for pod to restart
   kubectl get pods -n cisco-controller -w
```

### Verification

**1. Verify Endpoints Respond:**

```bash
# Test all EUM endpoints
curl -k https://controller-team1.splunkylabs.com/eumcollector/health
curl -k https://controller-team1.splunkylabs.com/eumaggregator/health
curl -k https://controller-team1.splunkylabs.com/events/health
curl -k https://controller-team1.splunkylabs.com/screenshots

# All should return 200 OK or {"status":"UP"}
```

**2. Create Browser Application:**

```
1. Log into Controller: https://controller-team1.splunkylabs.com/controller/
2. Go to: User Experience → Browser Apps
3. Click: "Create Browser App"
4. Configure application name and settings
5. Select: "I will host the JavaScript agent file"
6. Download ADRUM JavaScript files
```

**3. Configure ADRUM for Test:**

```javascript
// In your test HTML page
<script charset='UTF-8'>
window['adrum-start-time'] = new Date().getTime();
window['adrum-config'] = {
    appKey: 'AD-AAB-AAA-AAA',  // From Controller
    adrumExtUrlHttp: 'http://your-adrum-host/adrum',
    adrumExtUrlHttps: 'https://your-adrum-host/adrum',
    beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
    beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector',
    resTiming: {"bufSize":200,"clearResTimingOnBeaconSend":true},
    maxUrlLength: 512
};
</script>
<script src='https://your-adrum-host/adrum/adrum.js'></script>
```

**4. Test Browser Agent:**

```
1. Load test page in browser
2. Open browser developer tools (F12)
3. Go to Network tab
4. Filter for "eumcollector"
5. Refresh page
6. Should see POST requests to /eumcollector with 200 status
```

**5. Verify Data in Controller:**

```
1. Wait 2-3 minutes
2. Go to: User Experience → Browser Apps
3. Click on your application
4. Should see:
   - Page views
   - Ajax requests
   - End user response times
   - Geographic data
```

### Troubleshooting

**Issue: Can't access admin.jsp**

```bash
# Check Controller pod is running
kubectl get pods -n cisco-controller

# Check Controller logs
kubectl logs -n cisco-controller $(kubectl get pods -n cisco-controller -l app=controller -o name) --tail=50

# Try default password
Password: welcome

# If password changed and forgotten, reset via CLI:
appdcli run controller resetAdminPassword
```

**Issue: Settings not taking effect**

```bash
# Restart Controller pod
kubectl delete pod $(kubectl get pods -n cisco-controller -l app=controller -o name) -n cisco-controller

# Wait for restart
kubectl get pods -n cisco-controller -w

# Re-test endpoints
curl -k https://controller-team1.splunkylabs.com/eumcollector/health
```

**Issue: Beacon sending fails (CORS errors)**

```javascript
// Check beacon URLs match exactly
// In ADRUM config:
beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector',

// In admin.jsp:
eum.beacon.host = controller-team1.splunkylabs.com/eumcollector
eum.beacon.https.host = controller-team1.splunkylabs.com/eumcollector

// Must match (excluding https:// prefix in admin.jsp)
```

**Issue: 404 on /eumcollector**

```bash
# Check ingress routing
kubectl get ingress -n cisco-eum

# Check EUM service
kubectl get svc -n cisco-eum

# Check EUM pod logs
kubectl logs -n cisco-eum eum-ss-0 --tail=50

# Verify EUM pods are running
kubectl get pods -n cisco-eum
```

### Script-Based Configuration (Future Enhancement)

**Not currently implemented, but could be automated:**

```bash
# Example script to configure EUM via REST API
#!/bin/bash
CONTROLLER_URL="https://controller-team1.splunkylabs.com"
ADMIN_USER="admin"
ADMIN_PASS="welcome"

# Set EUM beacon host
curl -k -X POST "${CONTROLLER_URL}/controller/rest/configuration" \
  -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -d "name=eum.beacon.host" \
  -d "value=controller-team1.splunkylabs.com/eumcollector"

# Repeat for other properties...
```

### Verification Checklist

- [ ] Can access admin.jsp
- [ ] All 6 EUM properties configured
- [ ] EUM endpoints return 200 OK
- [ ] Browser application created
- [ ] ADRUM JavaScript downloaded
- [ ] Test page sends beacons successfully
- [ ] Data visible in Controller UI

### Additional Resources

- Detailed Guide: `docs/TEAM5_EUM_ADMIN_CONFIG.md`
- Common Issues: `common_issues.md` (EUM section)
- EUM Documentation: https://docs.appdynamics.com/appd/25.x/en/end-user-monitoring

---

## DEFECT-008: ADRUM JavaScript Hosting

### Problem Description

Cannot host ADRUM JavaScript files inside EUM pod. Attempting to access ADRUM files via Controller URL returns 404.

```bash
# Attempting to access ADRUM
curl https://controller-team1.splunkylabs.com/eumcollector/adrum.js
# Returns: 404 Not Found
```

### Root Cause

**Architectural limitation** - Virtual Appliance EUM pod is a containerized microservice without static file hosting capability. Classic on-premises deployments had a `wwwroot` directory for ADRUM files, but Kubernetes-based deployment doesn't include this.

### Diagnostic Steps

**1. Verify EUM Pod Contents:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team 1

# Check EUM pod filesystem
kubectl exec -it eum-ss-0 -n cisco-eum -- ls -la /

# Will show only standard application directories
# No wwwroot or adrum directory
```

**2. Confirm ADRUM Files Not Available:**
```bash
# From laptop
curl -I https://controller-team1.splunkylabs.com/eumcollector/adrum.js

# Returns: HTTP/1.1 404 Not Found

# Check ingress routes
kubectl get ingress -A

# Will show routes for /eumcollector but not /adrum
```

**3. Check Browser Application Configuration:**
```
1. Log into Controller
2. Go to: User Experience → Browser Apps
3. Create or view browser application
4. Check ADRUM hosting options:
   - ✅ "I will host the JavaScript agent file" (available)
   - ❌ "AppDynamics hosts" (not available in OVA)
```

### Fix Option 1: Python SimpleHTTPServer (QUICK TESTING)

**For quick testing/development:**

```bash
# Step 1: Download ADRUM files from Controller
# In Controller UI:
# User Experience → Browser Apps → Create/Edit App
# Select "I will host the JavaScript agent file"
# Download zip file

# Step 2: Extract files
unzip adrum-*.zip -d ~/adrum-files

# Step 3: Start simple web server
cd ~/adrum-files
python3 -m http.server 8080

# Server now running on: http://localhost:8080

# Step 4: Make accessible to test browsers
# Option A: If testing on same machine - use localhost
# Option B: If testing from other machines - use your IP
MY_IP=$(hostname -I | awk '{print $1}')
echo "ADRUM files available at: http://${MY_IP}:8080/"
```

**Configure ADRUM to use this server:**

```javascript
// In your test HTML
window['adrum-config'] = {
    appKey: 'AD-AAB-AAA-AAA',
    adrumExtUrlHttp: 'http://YOUR_IP:8080',
    adrumExtUrlHttps: 'http://YOUR_IP:8080',  // Same if no HTTPS
    beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
    beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector'
};
```

**Limitations:**
- HTTP only (no HTTPS) - OK for testing
- Server must stay running
- Not suitable for production
- No redundancy

### Fix Option 2: Nginx Web Server (RECOMMENDED FOR LAB)

**For more robust lab environment:**

**Step 1: Set up Nginx server**

You can use:
- Existing VM (VM1, VM2, or VM3)
- Separate EC2 instance
- Your laptop (if accessible from test browsers)

```bash
# SSH to chosen server
ssh -i ~/.ssh/appd-team1-key appduser@<server-ip>

# Install Nginx
sudo apt update
sudo apt install nginx -y

# Verify installation
sudo systemctl status nginx
nginx -v
```

**Step 2: Deploy ADRUM files**

```bash
# On your laptop - download ADRUM from Controller first

# Copy ADRUM files to server
scp -r -i ~/.ssh/appd-team1-key ~/adrum-files/* appduser@<server-ip>:/tmp/adrum/

# On server - move to Nginx directory
ssh -i ~/.ssh/appd-team1-key appduser@<server-ip>
sudo mkdir -p /var/www/html/adrum
sudo cp -r /tmp/adrum/* /var/www/html/adrum/
sudo chown -R www-data:www-data /var/www/html/adrum
sudo chmod -R 755 /var/www/html/adrum
```

**Step 3: Configure Nginx (Optional - for custom settings)**

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/adrum

# Add configuration:
server {
    listen 80;
    server_name _;
    
    location /adrum/ {
        alias /var/www/html/adrum/;
        
        # Enable CORS for cross-origin requests
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        
        # Enable caching
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/adrum /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

**Step 4: Test ADRUM access**

```bash
# From your laptop
curl http://<server-ip>/adrum/adrum.js

# Should return JavaScript content

# Test from browser
# Navigate to: http://<server-ip>/adrum/adrum.js
# Should download/display JavaScript file
```

**Step 5: Configure browser application**

```javascript
// In your HTML page
window['adrum-config'] = {
    appKey: 'AD-AAB-AAA-AAA',
    adrumExtUrlHttp: 'http://<server-ip>/adrum',
    adrumExtUrlHttps: 'http://<server-ip>/adrum',  // Use HTTPS if configured
    beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
    beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector'
};
```

### Fix Option 3: AWS S3 Bucket (CLOUD-NATIVE)

**For cloud-based lab environments:**

**Step 1: Create S3 bucket**

```bash
# Create bucket
aws s3 mb s3://team1-adrum-files --region us-west-2

# Enable static website hosting
aws s3 website s3://team1-adrum-files \
    --index-document index.html \
    --error-document error.html
```

**Step 2: Configure bucket policy**

```bash
# Create policy file
cat > /tmp/bucket-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::team1-adrum-files/*"
    }
  ]
}
EOF

# Apply policy
aws s3api put-bucket-policy \
    --bucket team1-adrum-files \
    --policy file:///tmp/bucket-policy.json

# Disable "Block Public Access"
aws s3api put-public-access-block \
    --bucket team1-adrum-files \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

**Step 3: Upload ADRUM files**

```bash
# Upload files
aws s3 cp ~/adrum-files/ s3://team1-adrum-files/adrum/ --recursive

# Set content types
aws s3 cp s3://team1-adrum-files/adrum/ s3://team1-adrum-files/adrum/ \
    --recursive \
    --content-type "application/javascript" \
    --metadata-directive REPLACE \
    --exclude "*" --include "*.js"

# Verify upload
aws s3 ls s3://team1-adrum-files/adrum/
```

**Step 4: Get bucket URL**

```bash
# Bucket website URL format:
# http://team1-adrum-files.s3-website-us-west-2.amazonaws.com

# Test access
curl http://team1-adrum-files.s3-website-us-west-2.amazonaws.com/adrum/adrum.js
```

**Step 5: Configure browser application**

```javascript
// In your HTML page
window['adrum-config'] = {
    appKey: 'AD-AAB-AAA-AAA',
    adrumExtUrlHttp: 'http://team1-adrum-files.s3-website-us-west-2.amazonaws.com/adrum',
    adrumExtUrlHttps: 'https://team1-adrum-files.s3.us-west-2.amazonaws.com/adrum',
    beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
    beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector'
};
```

### Fix Option 4: Apache Web Server

**Alternative to Nginx:**

```bash
# Install Apache
sudo apt update
sudo apt install apache2 -y

# Deploy ADRUM files
sudo mkdir -p /var/www/html/adrum
sudo cp -r ~/adrum-files/* /var/www/html/adrum/
sudo chown -R www-data:www-data /var/www/html/adrum

# Enable CORS (optional)
sudo nano /etc/apache2/sites-available/000-default.conf

# Add inside <VirtualHost>:
<Directory "/var/www/html/adrum">
    Header set Access-Control-Allow-Origin "*"
    Header set Access-Control-Allow-Methods "GET, OPTIONS"
</Directory>

# Enable headers module
sudo a2enmod headers

# Restart Apache
sudo systemctl restart apache2

# Test
curl http://localhost/adrum/adrum.js
```

### Verification

**1. Test ADRUM File Access:**

```bash
# Test HTTP access
curl http://<adrum-host>/adrum/adrum.js | head -20

# Should return JavaScript code starting with:
# (function(){ ... })();

# Test from browser
# Navigate to: http://<adrum-host>/adrum/adrum.js
# Should display JavaScript source code
```

**2. Test Browser Agent Loading:**

```html
<!-- Create test HTML file -->
<!DOCTYPE html>
<html>
<head>
    <title>ADRUM Test</title>
    <script charset='UTF-8'>
    window['adrum-start-time'] = new Date().getTime();
    window['adrum-config'] = {
        appKey: 'AD-AAB-AAA-AAA',
        adrumExtUrlHttp: 'http://YOUR-ADRUM-HOST/adrum',
        adrumExtUrlHttps: 'http://YOUR-ADRUM-HOST/adrum',
        beaconUrlHttp: 'https://controller-team1.splunkylabs.com/eumcollector',
        beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector'
    };
    </script>
    <script src='http://YOUR-ADRUM-HOST/adrum/adrum.js'></script>
</head>
<body>
    <h1>ADRUM Test Page</h1>
    <p>Check browser console for ADRUM loading messages.</p>
</body>
</html>
```

**Open in browser:**
- Open developer tools (F12)
- Check Console tab for ADRUM messages
- Check Network tab for adrum.js loaded successfully (200 status)
- Should see POST requests to /eumcollector

**3. Verify Data in Controller:**

```
1. Wait 2-3 minutes
2. Log into Controller
3. Go to: User Experience → Browser Apps
4. Select your application
5. Should see page views and metrics
```

### Troubleshooting

**Issue: CORS errors in browser**

```javascript
// In Nginx config:
add_header Access-Control-Allow-Origin *;
add_header Access-Control-Allow-Methods "GET, OPTIONS";

// In Apache config:
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods "GET, OPTIONS"

// Reload web server after changes
```

**Issue: ADRUM file not loading (404)**

```bash
# Check file exists
ls -la /var/www/html/adrum/adrum.js

# Check permissions
sudo chmod 644 /var/www/html/adrum/adrum.js

# Check web server error logs
sudo tail -f /var/log/nginx/error.log
# or
sudo tail -f /var/log/apache2/error.log
```

**Issue: Beacons not sending**

```javascript
// Verify beacon URLs match EUM configuration
// In ADRUM config:
beaconUrlHttps: 'https://controller-team1.splunkylabs.com/eumcollector',

// Test beacon URL manually:
curl -k https://controller-team1.splunkylabs.com/eumcollector/health
// Should return: 200 OK
```

### Best Practices

**For Production:**
1. Use HTTPS for ADRUM file hosting
2. Configure SSL certificates
3. Use CDN for better performance
4. Enable caching headers
5. Monitor web server logs

**For Lab:**
1. Simple HTTP is acceptable
2. Python SimpleHTTPServer OK for quick tests
3. Nginx recommended for longer-term lab
4. S3 bucket good for cloud-based labs
5. Document ADRUM URL for students

### Verification Checklist

- [ ] ADRUM hosting server set up
- [ ] ADRUM files deployed
- [ ] ADRUM files accessible via HTTP/HTTPS
- [ ] CORS configured (if needed)
- [ ] Browser test page created
- [ ] ADRUM loads in browser (check console)
- [ ] Beacons sent to Controller
- [ ] Data visible in Controller UI

### Additional Resources

- Common Issues: `common_issues.md` (ADRUM Hosting section)
- EUM Documentation: https://docs.appdynamics.com/appd/25.x/en/end-user-monitoring
- Nginx Documentation: https://nginx.org/en/docs/

---

## General Troubleshooting Tips

### 1. Check Logs

**VM System Logs:**
```bash
journalctl -u appd-os -f
journalctl -xe
```

**Kubernetes Pod Logs:**
```bash
kubectl logs <pod-name> -n <namespace> --tail=50
kubectl logs <pod-name> -n <namespace> --follow
kubectl logs <pod-name> -n <namespace> --previous  # Previous container
```

**Deployment Script Logs:**
```bash
# Scripts log to /tmp
ls -lh /tmp/*-deploy.log
tail -f /tmp/team1-deploy.log
```

### 2. Verify Services

**On VM:**
```bash
appdcli ping
appdctl show boot
kubectl get pods --all-namespaces
kubectl get nodes
```

**From Laptop:**
```bash
curl -k https://controller-team1.splunkylabs.com/controller/rest/serverstatus
```

### 3. Common Commands

**Reset/Retry:**
```bash
# Restart failed pods
kubectl delete pod <pod-name> -n <namespace>

# Restart services
appdcli stop appd
appdcli start appd small

# Re-run deployment phase
./deployment/07-install.sh --team 1
```

**Check Resource Usage:**
```bash
# Disk space
df -h

# Memory
free -h

# CPU
top

# Pod resources
kubectl top pods -A
kubectl top nodes
```

### 4. Getting Help

**Documentation:**
- `docs/` directory - All guides
- `common_issues.md` - FAQ
- `STUDENT_DEPLOYMENT_DEFECTS.md` - Known issues

**Diagnostic Scripts:**
- `./scripts/test-aws-cli.sh` - AWS configuration
- `./scripts/check-deployment-state.sh` - Deployment status
- `./scripts/check-mysql-health.sh` - MySQL cluster status

**Support:**
- Instructor/lab administrator
- AppDynamics documentation: https://docs.appdynamics.com/
- AppDynamics support: https://support.appdynamics.com/

---

## Quick Reference

| Issue | Quick Check | Quick Fix |
|-------|-------------|-----------|
| Silent failures | `aws sts get-caller-identity` | `git pull && ./scripts/test-aws-cli.sh` |
| Can't create VMs | `aws ec2 run-instances --dry-run ...` | Contact instructor for IAM update |
| Database locks | `kubectl get pods -n mysql` | `helm delete mysql -n mysql && ./deployment/07-install.sh --team N` |
| SSH password prompts | `ssh VM "sudo whoami"` | `./deployment/04-bootstrap-vms.sh --team N` |
| No progress shown | Check if using latest scripts | `git pull` |
| SecureApp failed | `appdcli ping \| grep SecureApp` | `appdcli run secureapp setDownloadPortalCredentials <user>` |
| EUM not working | `curl -k https://controller-teamN.splunkylabs.com/eumcollector/health` | Configure in admin.jsp |
| ADRUM 404 | `curl http://controller-teamN.splunkylabs.com/adrum/adrum.js` | Set up external web server |

---

**Document Version:** 1.0  
**Last Updated:** December 19, 2025  
**Maintained by:** Lab Administration Team
