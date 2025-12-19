# IAM Policy Update Guide

**CRITICAL: Apply This Before Student Lab Sessions**

**Date:** December 19, 2025  
**Status:** ⚠️ ACTION REQUIRED  
**Priority:** HIGH

---

## Overview

This guide will help you apply the updated IAM policy that gives students the minimum permissions needed to deploy lab environments **without using your admin account**.

**What's Fixed:**
- ✅ All config files now use `default` AWS profile
- ✅ IAM policy includes all required EC2 resource types
- ✅ Students can deploy independently

**What You Need to Do:**
1. Apply the updated IAM policy in AWS Console
2. Verify students can deploy with their own credentials
3. Test with student account before lab session

---

## Why This Is Critical

### Current Problem:
- ❌ Students using custom AWS profiles → silent failures
- ❌ Insufficient IAM permissions → can't create VMs
- ❌ Students blocked at deployment → need your admin account

### After This Fix:
- ✅ Students use `default` profile → no configuration issues
- ✅ Students have proper permissions → deploy independently
- ✅ You don't share admin credentials → secure

---

## Step 1: Verify Current IAM User/Policy

### Check if lab-student User Exists

```bash
# Option A: Via AWS CLI (if you have admin access configured)
aws iam get-user --user-name lab-student

# Option B: Via AWS Console
# 1. Log into AWS Console with admin credentials
# 2. Go to IAM → Users
# 3. Search for "lab-student"
```

**If User Exists:**
- Note the username (likely: `lab-student`)
- Check which policy is attached
- Proceed to Step 2

**If User Does NOT Exist:**
- You need to create it first
- See Section "Create Lab Student User" below

---

## Step 2: Apply Updated IAM Policy

### Option A: Via AWS Console (RECOMMENDED)

**1. Log into AWS Console**
   - URL: https://console.aws.amazon.com/
   - Use your **admin credentials**

**2. Navigate to IAM Policies**
   - Services → IAM
   - Left menu → Policies
   - Search for: `AppDynamicsLabStudentPolicy`

**3. Edit the Policy**
   - Click on the policy name
   - Click **Edit** button (or **Edit policy** tab)
   - Click **JSON** tab

**4. Replace Policy Content**
   - Select ALL existing JSON content
   - Delete it
   - Copy the entire contents of: `docs/iam-student-policy.json`
   - Paste into the JSON editor

**5. Review and Save**
   - Click **Next**
   - Review the summary (should show added permissions)
   - Click **Save changes**

**6. Verify Policy Applied**
   - Check that "Last updated" timestamp is current
   - Click **Policy versions** tab
   - Should show new version as "default"

### Option B: Via AWS CLI

```bash
# 1. Set admin profile (if not default)
export AWS_PROFILE=admin  # or your admin profile name

# 2. Update the policy
aws iam put-user-policy \
  --user-name lab-student \
  --policy-name AppDynamicsLabStudentPolicy \
  --policy-document file://docs/iam-student-policy.json

# 3. Verify
aws iam get-user-policy \
  --user-name lab-student \
  --policy-name AppDynamicsLabStudentPolicy
```

---

## Step 3: Verify Student Credentials Work

### Test with Student Credentials

**1. Get Student Access Keys**

```bash
# Via CLI (if you have them)
cat STUDENT_CREDENTIALS.txt

# Via Console
# IAM → Users → lab-student → Security credentials
# Should see Access Key ID (starts with AKIA...)
```

**2. Configure Test Profile**

```bash
# On your machine, create a test profile
aws configure --profile lab-student-test

# Enter:
# AWS Access Key ID: [student's access key]
# AWS Secret Access Key: [student's secret key]
# Default region: us-west-2
# Default output format: json
```

**3. Test Basic Permissions**

```bash
# Test identity
aws sts get-caller-identity --profile lab-student-test

# Expected output:
# {
#   "UserId": "AIDA...",
#   "Account": "314839308236",
#   "Arn": "arn:aws:iam::314839308236:user/lab-student"
# }

# Test EC2 read permissions
aws ec2 describe-vpcs --profile lab-student-test

# Should return list of VPCs (or empty list if none)

# Test EC2 write permissions (dry-run)
aws ec2 run-instances \
  --dry-run \
  --image-id ami-092d9aa0e2874fd9c \
  --instance-type m5a.4xlarge \
  --profile lab-student-test

# Expected:
# "An error occurred (DryRunOperation)"
# This means permissions are CORRECT

# If you see "UnauthorizedOperation":
# Permissions are INCORRECT - check policy again
```

**4. Test Route53 Permissions**

```bash
# List hosted zones
aws route53 list-hosted-zones --profile lab-student-test

# Should return splunkylabs.com zone
```

**5. Test ALB Permissions**

```bash
# List load balancers
aws elbv2 describe-load-balancers --profile lab-student-test

# Should return list (or empty if none)
```

---

## Step 4: Test Full Deployment (RECOMMENDED)

**Before student lab session, test complete deployment:**

```bash
# 1. Use student credentials
export AWS_PROFILE=lab-student-test  # or configure as 'default'

# 2. Clone repo fresh
cd /tmp
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# 3. Test deployment
./deployment/01-deploy.sh --team 99  # Use test team number

# Should complete without errors:
# ✅ Phase 1: VPC and Networking
# ✅ Phase 2: Security Groups  
# ✅ Phase 3: Virtual Machines
# ✅ Phase 4: Elastic IPs

# 4. Clean up test
./deployment/cleanup.sh --team 99 --confirm
```

---

## Create Lab Student User (If Doesn't Exist)

### Via AWS Console

**1. Create User**
   - IAM → Users → Add users
   - Username: `lab-student`
   - Access type: ☑ Programmatic access
   - Click Next

**2. Create Policy**
   - Click "Attach existing policies directly"
   - Click "Create policy"
   - Click JSON tab
   - Paste contents of `docs/iam-student-policy.json`
   - Click Next
   - Name: `AppDynamicsLabStudentPolicy`
   - Description: "Lab student permissions for AppDynamics deployment"
   - Click Create policy

**3. Attach Policy to User**
   - Go back to user creation
   - Refresh policies list
   - Search for: `AppDynamicsLabStudentPolicy`
   - Check the box next to it
   - Click Next
   - Click Create user

**4. Save Credentials**
   - **IMPORTANT:** Download CSV or copy credentials now
   - You cannot retrieve secret key later
   - Save to secure location

**5. Share with Students**
   - Provide Access Key ID
   - Provide Secret Access Key
   - Instruct to run: `aws configure`

### Via AWS CLI

```bash
# 1. Create user
aws iam create-user --user-name lab-student

# 2. Create policy
aws iam put-user-policy \
  --user-name lab-student \
  --policy-name AppDynamicsLabStudentPolicy \
  --policy-document file://docs/iam-student-policy.json

# 3. Create access key
aws iam create-access-key --user-name lab-student

# Output will show:
# {
#   "AccessKey": {
#     "AccessKeyId": "AKIA...",
#     "SecretAccessKey": "..."
#   }
# }

# 4. Save these credentials securely!
```

---

## What Students Need to Do

### Student Setup (One-Time)

**1. Configure AWS CLI**

```bash
# Students run this command
aws configure

# They enter:
AWS Access Key ID: [provided by instructor]
AWS Secret Access Key: [provided by instructor]
Default region name: us-west-2
Default output format: json
```

**2. Verify Configuration**

```bash
# Students test
aws sts get-caller-identity

# Should show:
# {
#   "UserId": "AIDA...",
#   "Account": "314839308236",
#   "Arn": "arn:aws:iam::314839308236:user/lab-student"
# }
```

**3. Clone Repository**

```bash
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab
```

**4. Deploy Their Lab**

```bash
# No profile configuration needed - uses 'default'
./deployment/01-deploy.sh --team 1
```

---

## Permissions Summary

### What Students CAN Do:

**EC2:**
- ✅ Create/delete VPCs, subnets, internet gateways
- ✅ Create/delete security groups
- ✅ Launch instances (m5a.xlarge, m5a.2xlarge, m5a.4xlarge, t3.2xlarge only)
- ✅ Create/delete key pairs
- ✅ Allocate/release Elastic IPs
- ✅ Create/delete volumes and snapshots
- ✅ Tag resources

**Load Balancers:**
- ✅ Create/delete Application Load Balancers
- ✅ Create/delete target groups
- ✅ Register/deregister targets
- ✅ Create/modify listeners

**Route53:**
- ✅ Create/delete DNS records in existing hosted zone
- ✅ List hosted zones and records

**S3:**
- ✅ Read from `appdynamics-lab-resources` bucket (for license, AMI, etc.)

**IAM:**
- ✅ View their own user info
- ✅ Get caller identity

### What Students CANNOT Do:

**EC2:**
- ❌ Launch instances outside allowed types
- ❌ Launch instances outside us-west-2
- ❌ Import AMIs or snapshots
- ❌ Register images

**IAM:**
- ❌ Create/modify users or policies
- ❌ Create/modify roles

**S3:**
- ❌ Write to S3 buckets
- ❌ Create/delete buckets

**Route53:**
- ❌ Create/delete hosted zones
- ❌ Modify zone settings

**Billing:**
- ❌ View billing information
- ❌ Modify budgets

---

## Troubleshooting

### Issue: "UnauthorizedOperation" when creating VMs

**Symptom:**
```
An error occurred (UnauthorizedOperation) when calling the RunInstances operation
```

**Fix:**
1. Verify policy was applied correctly
2. Check user has policy attached
3. Wait 1-2 minutes for IAM propagation
4. Test with dry-run command from Step 3

### Issue: Policy won't save - syntax error

**Fix:**
1. Ensure JSON is valid (use JSON validator)
2. Copy ENTIRE contents of `docs/iam-student-policy.json`
3. Don't modify the policy
4. Check for extra characters at start/end

### Issue: Student profile still not working

**Fix:**
1. Verify student ran `aws configure` (not `aws configure --profile xyz`)
2. Check they entered credentials correctly
3. Test: `aws sts get-caller-identity`
4. Verify they pulled latest code: `git pull`

### Issue: Still seeing "lab-student" profile errors

**Fix:**
```bash
# Pull latest code
cd dec25_lab
git pull origin main

# Verify configs are correct
grep AWS_PROFILE config/team*.cfg

# Should ALL show: AWS_PROFILE="default"
```

---

## Security Best Practices

### DO:
- ✅ Use least-privilege IAM policies
- ✅ Restrict to specific regions (us-west-2)
- ✅ Restrict instance types
- ✅ Share only student credentials, never admin
- ✅ Rotate credentials after lab sessions
- ✅ Monitor AWS CloudTrail for unusual activity

### DON'T:
- ❌ Give students admin or power user access
- ❌ Share your personal AWS credentials
- ❌ Allow instance types outside lab requirements
- ❌ Give write access to S3 buckets
- ❌ Allow IAM user/role creation
- ❌ Leave credentials in public repositories

---

## Cost Controls

### Instance Type Restrictions

Policy only allows:
- `m5a.xlarge` (4 vCPU, 16 GB RAM)
- `m5a.2xlarge` (8 vCPU, 32 GB RAM)
- `m5a.4xlarge` (16 vCPU, 64 GB RAM)
- `t3.2xlarge` (8 vCPU, 32 GB RAM)

Students **cannot** launch larger instances.

### Region Restrictions

All resources limited to: `us-west-2`

Students **cannot** create resources in other regions.

### Monitoring

```bash
# Check active instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime]' \
  --output table

# Check active VPCs
aws ec2 describe-vpcs \
  --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' \
  --output table
```

---

## Checklist

Before student lab session:

- [ ] IAM policy updated in AWS Console
- [ ] Policy attached to lab-student user
- [ ] Student credentials tested with test profile
- [ ] Dry-run EC2 instance creation succeeds
- [ ] Full deployment tested with student credentials
- [ ] Test deployment cleaned up
- [ ] Latest code pulled from repository
- [ ] All config files show `AWS_PROFILE="default"`
- [ ] Student credentials document prepared
- [ ] Students have AWS CLI installed

---

## Student Credentials Distribution

### Secure Method:

**Create credential document:**

```bash
cat > STUDENT_CREDENTIALS.txt << EOF
AppDynamics Lab AWS Credentials
================================

AWS Access Key ID: AKIA****************
AWS Secret Access Key: ****************************************

Region: us-west-2

Setup Instructions:
-------------------
1. Install AWS CLI: https://aws.amazon.com/cli/
2. Configure credentials:
   aws configure
   
   Enter the credentials above when prompted.
   Region: us-west-2
   Output: json

3. Verify:
   aws sts get-caller-identity

4. Clone repository:
   git clone https://github.com/sandbreak80/dec25_lab.git

5. Deploy your lab:
   cd dec25_lab
   ./deployment/01-deploy.sh --team N

Security Notes:
--------------
- Do not share these credentials
- Only valid for lab resources
- Expires after: [date]
- Report any issues to instructor

EOF
```

**Distribute via:**
- Secure LMS (Canvas, Moodle, etc.)
- Password-protected PDF
- Encrypted email
- In-person during lab session

---

## After Lab Session

### Cleanup

```bash
# Revoke access keys (optional - for security)
aws iam delete-access-key \
  --user-name lab-student \
  --access-key-id AKIA...

# Or delete entire user
aws iam delete-user-policy \
  --user-name lab-student \
  --policy-name AppDynamicsLabStudentPolicy

aws iam delete-user --user-name lab-student

# Verify all student resources deleted
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]'
aws elbv2 describe-load-balancers
```

---

## Support

**If you have issues applying this policy:**

1. Check AWS Console for error messages
2. Verify JSON syntax with: https://jsonlint.com/
3. Review IAM policy limits (default: 10 policies per user)
4. Check CloudTrail logs for IAM API calls
5. Contact AWS Support if persistent issues

**For student issues:**

- Students should reference: `TROUBLESHOOTING_GUIDE.md`
- Students should reference: `QUICK_REFERENCE.md`
- Test with student credentials yourself first

---

**Status:** Ready to Apply  
**Priority:** HIGH - Apply before next lab session  
**Estimated Time:** 15 minutes  
**Testing Time:** 30 minutes

**Questions? Check the documentation in `docs/` directory.**
