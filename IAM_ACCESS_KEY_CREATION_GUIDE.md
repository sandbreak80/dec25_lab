# IAM Access Key Creation Guide

**Complete Guide for Creating Student IAM Access Keys**

**Version:** 1.0  
**Last Updated:** December 19, 2025  
**Audience:** Instructor/Lab Administrator

---

## Overview

This guide walks you through creating IAM access keys for lab students with the correct permissions to deploy AppDynamics lab environments independently (without needing your admin credentials).

**What You'll Create:**
- Lab student IAM user (if doesn't exist)
- IAM policy with minimum required permissions
- Access keys for student use
- Secure credential distribution document

**Time Required:** 20-30 minutes

---

## Prerequisites

- AWS account with IAM admin permissions
- AWS CLI installed and configured with admin credentials
- OR access to AWS Console

---

## Part 1: Create IAM User and Policy

### Option A: Via AWS Console (RECOMMENDED)

#### Step 1: Create IAM User

1. **Log into AWS Console**
   - URL: https://console.aws.amazon.com/
   - Use your admin credentials

2. **Navigate to IAM**
   - Services → IAM
   - Or use search: "IAM"

3. **Create User**
   - Click "Users" in left sidebar
   - Click "Add users" button
   - Username: `lab-student`
   - Access type: ☑ **Programmatic access** (NOT console access)
   - Click "Next: Permissions"

#### Step 2: Create Custom IAM Policy

1. **On the Permissions page**
   - Click "Attach existing policies directly"
   - Click "Create policy" button
   - This opens a new tab

2. **In the Create Policy tab**
   - Click "JSON" tab
   - Delete the default policy
   - Copy ENTIRE contents of `docs/iam-student-policy.json`
   - Paste into the JSON editor

3. **Review Policy**
   - The policy includes permissions for:
     - EC2 (VPC, instances, volumes, snapshots, security groups)
     - Elastic Load Balancing (ALB, target groups)
     - Route53 (DNS records)
     - ACM (certificates - read only)
     - S3 (lab resources bucket - read only)
     - IAM/STS (identity - read only)
   
   - Security restrictions:
     - Region locked to us-west-2
     - Instance types limited to: m5a.xlarge, m5a.2xlarge, m5a.4xlarge, t3.2xlarge
     - No IAM user/role creation
     - No S3 write access
     - No billing access

4. **Name the Policy**
   - Click "Next: Tags" (optional, can skip)
   - Click "Next: Review"
   - Policy name: `AppDynamicsLabStudentPolicy`
   - Description: "Lab student permissions for AppDynamics Virtual Appliance deployment"
   - Click "Create policy"

5. **Return to User Creation Tab**
   - Refresh the policies list (circular arrow icon)
   - Search for: `AppDynamicsLabStudentPolicy`
   - Check the box next to it
   - Click "Next: Tags" (optional, can skip)
   - Click "Next: Review"

#### Step 3: Review and Create

1. **Review Settings**
   - Username: `lab-student`
   - AWS access type: Programmatic access
   - Permissions: `AppDynamicsLabStudentPolicy`

2. **Create User**
   - Click "Create user"

3. **SAVE CREDENTIALS IMMEDIATELY** ⚠️
   - **Access Key ID:** AKIA****************
   - **Secret Access Key:** ****************************************
   
   **CRITICAL:** This is the ONLY time you can see the secret access key!
   
   - Click "Download .csv" button (saves credentials)
   - OR copy both values to a secure location
   - DO NOT close this page until credentials are saved!

4. **Secure Storage**
   - Save to password manager
   - Or save to encrypted file
   - Label file: `lab-student-credentials-YYYY-MM-DD.csv`

---

### Option B: Via AWS CLI

#### Step 1: Create User

```bash
# Create the IAM user
aws iam create-user \
    --user-name lab-student \
    --tags Key=Purpose,Value=Lab Key=Course,Value=AppDynamics

# Verify user created
aws iam get-user --user-name lab-student
```

#### Step 2: Attach Policy

```bash
# Attach the inline policy to the user
aws iam put-user-policy \
    --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy \
    --policy-document file://docs/iam-student-policy.json

# Verify policy attached
aws iam get-user-policy \
    --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy
```

#### Step 3: Create Access Key

```bash
# Create access key
aws iam create-access-key --user-name lab-student

# Output will be JSON with credentials
# SAVE THIS OUTPUT IMMEDIATELY!
```

**Example Output:**
```json
{
    "AccessKey": {
        "UserName": "lab-student",
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "Status": "Active",
        "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        "CreateDate": "2025-12-19T12:00:00+00:00"
    }
}
```

**Save credentials:**
```bash
# Save to secure file
cat > lab-student-credentials-$(date +%Y-%m-%d).json << EOF
{
  "UserName": "lab-student",
  "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
  "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "CreatedDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Set secure permissions
chmod 600 lab-student-credentials-*.json

# Display for verification
cat lab-student-credentials-*.json
```

---

## Part 2: Verify Permissions

### Test Access Keys Work Correctly

#### Step 1: Configure Test Profile

```bash
# Create a test profile on YOUR machine
aws configure --profile lab-student-test

# Enter the credentials:
AWS Access Key ID: [paste Access Key ID]
AWS Secret Access Key: [paste Secret Access Key]
Default region name: us-west-2
Default output format: json
```

#### Step 2: Verify Identity

```bash
# Test authentication
aws sts get-caller-identity --profile lab-student-test

# Expected output:
# {
#   "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#   "Account": "314839308236",
#   "Arn": "arn:aws:iam::314839308236:user/lab-student"
# }

# If you see error: Check credentials were entered correctly
```

#### Step 3: Test EC2 Permissions (Dry-Run)

```bash
# Test EC2 instance creation (dry-run, won't create anything)
aws ec2 run-instances \
    --dry-run \
    --image-id ami-092d9aa0e2874fd9c \
    --instance-type m5a.4xlarge \
    --profile lab-student-test

# Expected: "DryRunOperation" - This means SUCCESS!
# An error occurred (DryRunOperation) when calling the RunInstances operation: 
# Request would have succeeded, but DryRun flag is set.
```

**If you see "UnauthorizedOperation":**
- Policy not attached correctly
- Wait 60 seconds for IAM propagation
- Verify policy JSON was copied completely
- Check user has policy attached: `aws iam list-user-policies --user-name lab-student`

#### Step 4: Test Other Permissions

```bash
# Test VPC creation permissions
aws ec2 describe-vpcs --profile lab-student-test
# Should succeed (returns list of VPCs)

# Test Load Balancer permissions
aws elbv2 describe-load-balancers --profile lab-student-test
# Should succeed (returns list of ALBs)

# Test Route53 permissions
aws route53 list-hosted-zones --profile lab-student-test
# Should succeed (returns hosted zones)

# Test S3 read permissions
aws s3 ls s3://appdynamics-lab-resources --profile lab-student-test
# Should succeed (returns bucket contents)

# Test IAM write permissions (should FAIL - students shouldn't have this)
aws iam list-users --profile lab-student-test
# Should fail with "AccessDenied" - This is CORRECT!
```

---

## Part 3: Full Deployment Test

### Test Complete Lab Deployment

**This is CRITICAL - test the full deployment with student credentials before giving to students!**

#### Step 1: Setup Test Environment

```bash
# Create test directory
mkdir -p /tmp/student-test
cd /tmp/student-test

# Clone repository
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# Configure AWS to use test credentials
export AWS_PROFILE=lab-student-test
```

#### Step 2: Run Deployment

```bash
# Deploy test team (team 99)
./deployment/01-deploy.sh --team 99

# Should complete successfully:
# ✅ Phase 1: VPC and Networking (2 minutes)
# ✅ Phase 2: Security Groups (1 minute)
# ✅ Phase 3: Virtual Machines (3-5 minutes)
# ✅ Phase 4: Elastic IPs (1 minute)

# If ANY phase fails - check permissions!
```

#### Step 3: Verify Resources Created

```bash
# Check VPC
aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=appd-team-99-vpc" \
    --profile lab-student-test

# Check instances
aws ec2 describe-instances \
    --filters "Name=tag:Team,Values=99" \
    --profile lab-student-test

# Should show 3 running instances
```

#### Step 4: Clean Up Test

```bash
# Clean up test deployment
./deployment/cleanup.sh --team 99 --confirm

# Verify cleanup
aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=appd-team-99-vpc" \
    --profile lab-student-test

# Should return empty (all resources deleted)
```

#### Step 5: Remove Test Profile

```bash
# Remove test profile from your AWS config
aws configure --profile lab-student-test list
# Note the location of config files

# Edit ~/.aws/credentials - remove [lab-student-test] section
# Edit ~/.aws/config - remove [profile lab-student-test] section
```

---

## Part 4: Create Student Credentials Document

### Create Secure Credentials File

```bash
# Create student credentials document
cat > STUDENT_AWS_CREDENTIALS.txt << 'EOF'
╔══════════════════════════════════════════════════════════╗
║  AppDynamics Lab - AWS Credentials                      ║
║  Course: AppDynamics Virtual Appliance Deployment       ║
║  Valid Until: [INSERT DATE]                             ║
╚══════════════════════════════════════════════════════════╝

AWS CREDENTIALS
═══════════════

Access Key ID:     AKIA****************
Secret Access Key: ****************************************

Region: us-west-2
Output: json


SETUP INSTRUCTIONS
══════════════════

1. Install AWS CLI
   https://aws.amazon.com/cli/
   
   macOS:   brew install awscli
   Windows: Download installer from AWS
   Linux:   sudo apt install awscli  (or equivalent)

2. Configure AWS Credentials
   
   Run this command:
   $ aws configure
   
   Enter when prompted:
   AWS Access Key ID: [paste Access Key ID from above]
   AWS Secret Access Key: [paste Secret Access Key from above]
   Default region name: us-west-2
   Default output format: json

3. Verify Configuration
   
   $ aws sts get-caller-identity
   
   Should show:
   {
     "Account": "314839308236",
     "Arn": "arn:aws:iam::314839308236:user/lab-student"
   }

4. Clone Lab Repository
   
   $ git clone https://github.com/sandbreak80/dec25_lab.git
   $ cd dec25_lab

5. Deploy Your Lab Environment
   
   $ ./deployment/01-deploy.sh --team N
   
   Replace N with your assigned team number (1-5)


WHAT YOU CAN DO
════════════════

✅ Create/delete VPCs, subnets, security groups
✅ Launch EC2 instances (approved types only)
✅ Create/manage load balancers
✅ Create DNS records
✅ Read from lab resources S3 bucket


WHAT YOU CANNOT DO
═══════════════════

❌ Launch instance types outside approved list
❌ Create resources outside us-west-2 region
❌ Create/modify IAM users or policies
❌ Access billing information
❌ Write to S3 buckets


APPROVED INSTANCE TYPES
════════════════════════

m5a.xlarge   (4 vCPU, 16 GB RAM)
m5a.2xlarge  (8 vCPU, 32 GB RAM)
m5a.4xlarge  (16 vCPU, 64 GB RAM)
t3.2xlarge   (8 vCPU, 32 GB RAM)


SECURITY & USAGE GUIDELINES
════════════════════════════

⚠️  Do NOT share these credentials
⚠️  Do NOT commit credentials to git
⚠️  Do NOT use for non-lab purposes
⚠️  Report any issues immediately
✅  Always clean up resources when done
✅  Use provided cleanup scripts


GETTING HELP
═════════════

Documentation:
  - Quick Reference: QUICK_REFERENCE.md
  - Troubleshooting: TROUBLESHOOTING_GUIDE.md
  - Full Documentation: docs/

Instructor Contact:
  - Email: [INSERT EMAIL]
  - Office Hours: [INSERT HOURS]

Support Resources:
  - GitHub Issues: https://github.com/sandbreak80/dec25_lab/issues
  - Lab Forum: [INSERT FORUM URL]


TROUBLESHOOTING
═══════════════

Script fails with no error:
  $ ./scripts/test-aws-cli.sh
  
Can't create VMs:
  Check you're using approved instance type
  
Permission denied:
  Verify credentials entered correctly
  Run: aws sts get-caller-identity


CREDENTIALS EXPIRATION
═══════════════════════

These credentials will be deactivated after: [INSERT DATE]

To extend access or report issues, contact instructor.


═══════════════════════════════════════════════════════════

Generated: $(date)
Course: AppDynamics Lab - December 2025
Instructor: [INSERT NAME]

═══════════════════════════════════════════════════════════
EOF

# Replace placeholder values
echo ""
echo "⚠️  EDIT THIS FILE AND REPLACE:"
echo "  - AKIA**************** with actual Access Key ID"
echo "  - **************************************** with actual Secret Key"
echo "  - [INSERT DATE] with credential expiration date"
echo "  - [INSERT EMAIL/HOURS/FORUM] with your information"
echo ""
echo "File created: STUDENT_AWS_CREDENTIALS.txt"
```

### Customize the Document

```bash
# Edit the file
nano STUDENT_AWS_CREDENTIALS.txt

# OR
code STUDENT_AWS_CREDENTIALS.txt

# Replace:
# 1. AKIA**************** → actual Access Key ID
# 2. **************************************** → actual Secret Access Key
# 3. [INSERT DATE] → credential expiration date (e.g., January 15, 2026)
# 4. [INSERT EMAIL] → your email
# 5. [INSERT HOURS] → office hours
# 6. [INSERT FORUM URL] → forum/LMS URL
# 7. [INSERT NAME] → your name
```

---

## Part 5: Distribute Credentials Securely

### Option A: Via LMS (RECOMMENDED)

1. **Upload to Canvas/Moodle/Blackboard**
   - Go to your course page
   - Upload STUDENT_AWS_CREDENTIALS.txt
   - Set visibility: Students only
   - Set availability: Start of lab week

2. **Add Instructions**
   - Post announcement with link
   - Instructions: "Download and follow setup steps"
   - Due date: Before first lab session

### Option B: Via Encrypted Email

```bash
# Create password-protected ZIP
zip -e student-credentials.zip STUDENT_AWS_CREDENTIALS.txt

# Enter password when prompted (share separately)
# Email the ZIP file to students
# Share password via different channel (text, call, in-person)
```

### Option C: Via Password-Protected PDF

```bash
# Convert to PDF (if you have pandoc)
pandoc STUDENT_AWS_CREDENTIALS.txt -o student-credentials.pdf

# Set password in PDF viewer or use tool like:
qpdf --encrypt "" PASSWORD 128 -- student-credentials.pdf student-credentials-protected.pdf

# Or use online tool (ensure it's secure/private)
```

### Option D: In-Person Distribution

- Print credentials
- Distribute during first lab session
- Students configure on the spot
- Verify each student can authenticate

---

## Part 6: Post-Lab Cleanup

### After Lab Session Ends

#### Option 1: Deactivate Access Keys (Students Keep User)

```bash
# List access keys
aws iam list-access-keys --user-name lab-student

# Deactivate keys (keeps keys but makes them inactive)
aws iam update-access-key \
    --user-name lab-student \
    --access-key-id AKIAIOSFODNN7EXAMPLE \
    --status Inactive

# Students can no longer use credentials
# You can reactivate for next lab session
```

#### Option 2: Delete Access Keys (More Secure)

```bash
# Delete access keys completely
aws iam delete-access-key \
    --user-name lab-student \
    --access-key-id AKIAIOSFODNN7EXAMPLE

# Create new keys for next lab session
aws iam create-access-key --user-name lab-student
```

#### Option 3: Delete Entire User (Clean Slate)

```bash
# Delete policy first
aws iam delete-user-policy \
    --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy

# Delete access keys
aws iam delete-access-key \
    --user-name lab-student \
    --access-key-id AKIAIOSFODNN7EXAMPLE

# Delete user
aws iam delete-user --user-name lab-student

# For next lab, create fresh user following this guide
```

### Verify Student Resources Deleted

```bash
# Check for running instances
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Team`].Value|[0]]' \
    --output table

# Check for VPCs
aws ec2 describe-vpcs \
    --filters "Name=tag:Purpose,Values=AppDynamics-Lab" \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
    --output table

# Check for load balancers
aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' \
    --output table

# Check for EIPs
aws ec2 describe-addresses \
    --filters "Name=tag:Purpose,Values=AppDynamics-Lab" \
    --query 'Addresses[*].[PublicIp,Tags[?Key==`Team`].Value|[0]]' \
    --output table
```

**If students left resources running:**
```bash
# Contact students to clean up
# Or use admin credentials to delete orphaned resources
```

---

## Security Best Practices

### DO:
- ✅ Create separate user for lab (not your admin account)
- ✅ Use least-privilege IAM policy
- ✅ Restrict to specific region (us-west-2)
- ✅ Restrict instance types
- ✅ Set credential expiration date
- ✅ Deactivate/delete after lab
- ✅ Monitor CloudTrail for unusual activity
- ✅ Distribute credentials securely (encrypted)

### DON'T:
- ❌ Share your admin credentials
- ❌ Give students admin or power user access
- ❌ Allow unrestricted instance types
- ❌ Allow cross-region access
- ❌ Post credentials publicly
- ❌ Email credentials unencrypted
- ❌ Leave old access keys active

---

## Troubleshooting

### Issue: User already exists

```bash
# Check if user exists
aws iam get-user --user-name lab-student

# If exists, update policy instead
aws iam put-user-policy \
    --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy \
    --policy-document file://docs/iam-student-policy.json
```

### Issue: Policy won't attach

```bash
# Check JSON syntax
cat docs/iam-student-policy.json | jq .

# If error, fix JSON
# Common issues: trailing commas, missing quotes
```

### Issue: Test deployment fails with UnauthorizedOperation

```bash
# Wait for IAM propagation
sleep 60

# Retry test
aws ec2 run-instances --dry-run ... --profile lab-student-test

# If still fails, check CloudTrail for specific permission denied
```

### Issue: Can't create access key

```bash
# Check if user already has 2 keys (max per user)
aws iam list-access-keys --user-name lab-student

# Delete old key if needed
aws iam delete-access-key \
    --user-name lab-student \
    --access-key-id AKIAOLD...
```

---

## Summary Checklist

Before distributing to students:

- [ ] IAM user `lab-student` created
- [ ] Policy `AppDynamicsLabStudentPolicy` created and attached
- [ ] Access keys generated and saved securely
- [ ] Test profile configured and tested
- [ ] Dry-run EC2 instance creation successful
- [ ] Full deployment test successful (team 99)
- [ ] Test resources cleaned up
- [ ] Student credentials document created
- [ ] Placeholders replaced with actual values
- [ ] Distribution method chosen and prepared
- [ ] Expiration date set
- [ ] Post-lab cleanup plan documented

---

## Quick Reference

### Create User & Policy (Console)
1. IAM → Users → Add users → `lab-student`
2. IAM → Policies → Create policy → JSON → Paste `docs/iam-student-policy.json`
3. Attach policy to user
4. Security credentials → Create access key
5. Download/save credentials

### Create User & Policy (CLI)
```bash
aws iam create-user --user-name lab-student
aws iam put-user-policy --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy \
    --policy-document file://docs/iam-student-policy.json
aws iam create-access-key --user-name lab-student
```

### Test Credentials
```bash
aws configure --profile lab-student-test
aws sts get-caller-identity --profile lab-student-test
aws ec2 run-instances --dry-run ... --profile lab-student-test
```

### Cleanup After Lab
```bash
aws iam delete-access-key --user-name lab-student --access-key-id AKIA...
# Or
aws iam update-access-key --user-name lab-student --access-key-id AKIA... --status Inactive
```

---

**Status:** Ready to Use  
**Next Step:** Follow Part 1 to create user and credentials  
**Estimated Time:** 30 minutes total

For questions or issues, see `IAM_POLICY_APPLY_GUIDE.md` for more details.
