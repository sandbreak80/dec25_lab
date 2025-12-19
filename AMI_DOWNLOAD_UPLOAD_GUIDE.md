# AMI Download, Upload, and Registration Guide

**Complete Guide for AppDynamics Virtual Appliance AMI Management**

**Version:** 1.0  
**Last Updated:** December 19, 2025  
**Audience:** Instructor/Lab Administrator

---

## Overview

This guide covers the complete process of obtaining, uploading, and registering AppDynamics Virtual Appliance AMI files for use in AWS lab environments.

**The Complete Process:**
1. Download AMI from AppDynamics Download Center
2. Verify file integrity
3. Upload to S3 bucket
4. Create vmimport IAM role
5. Import snapshot from S3
6. Register snapshot as AMI
7. Update lab configuration
8. Verify and test

**Time Required:** 1-2 hours (mostly automated waiting)  
**Prerequisites:** AWS admin access, ~40GB disk space

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Part 1: Download AMI](#part-1-download-ami)
3. [Part 2: Verify Download](#part-2-verify-download)
4. [Part 3: Upload to S3](#part-3-upload-to-s3)
5. [Part 4: Import to AWS](#part-4-import-to-aws)
6. [Part 5: Register as AMI](#part-5-register-as-ami)
7. [Part 6: Update Configuration](#part-6-update-configuration)
8. [Part 7: Verify and Test](#part-7-verify-and-test)
9. [Troubleshooting](#troubleshooting)
10. [Automated Process](#automated-process)

---

## Prerequisites

### Required

- **AWS Account:** Admin access (for vmimport role creation)
- **AWS CLI:** Installed and configured with admin profile
- **Disk Space:** ~40GB free (AMI files are large)
- **Internet:** Download bandwidth for 20-30GB file
- **AppDynamics Account:** Access to download center
- **Time:** 1-2 hours (mostly automated)

### Optional

- **MD5 tool:** For checksum verification
- **Screen/tmux:** For long-running uploads
- **Fast internet:** Upload can take 30+ minutes

### Check Prerequisites

```bash
# Check AWS CLI
aws --version
# Should show: aws-cli/2.x.x or higher

# Check authentication
aws sts get-caller-identity
# Should show your admin user

# Check disk space
df -h ~/Downloads
# Should show 40GB+ available

# Check download tool
curl --version
# or
wget --version
```

---

## Part 1: Download AMI

### Option A: Via AppDynamics Download Center (RECOMMENDED)

#### Step 1: Access Download Center

1. **Navigate to Downloads**
   - URL: https://download.appdynamics.com/
   - Or: https://accounts.appdynamics.com/ → Downloads

2. **Log In**
   - Use your AppDynamics account credentials
   - If you don't have an account, contact AppDynamics support

3. **Find Virtual Appliance**
   - Product: **On-Premises Platform**
   - Component: **Virtual Appliance** or **OVA**
   - Version: Select latest stable version (e.g., 25.7.0)

#### Step 2: Download AMI File

1. **Select Platform**
   - Look for: **AWS AMI** or **RAW disk image**
   - File extension: `.ami` or `.raw`
   - Size: Typically 20-30GB

2. **Download**
   - Click download button
   - Save to: `~/Downloads/` or dedicated directory
   - Filename example: `appd_va_25.7.0.2255.ami`

3. **Note Checksum**
   - Download page usually shows MD5 or SHA256 checksum
   - Copy checksum to text file for verification
   - Example: `abc123def456...`

#### Step 3: Monitor Download

```bash
# Watch download progress
watch -n 5 'ls -lh ~/Downloads/appd_va*.ami'

# Or use download manager's built-in progress
```

**Download Time:**
- 100 Mbps: ~30-45 minutes
- 1 Gbps: ~3-5 minutes
- Varies based on AppDynamics CDN performance

---

### Option B: Via Command Line (Alternative)

**If AppDynamics provides direct download URL:**

```bash
# Set variables
AMI_VERSION="25.7.0.2255"
AMI_URL="https://download.appdynamics.com/.../appd_va_${AMI_VERSION}.ami"
DOWNLOAD_DIR=~/Downloads

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# Download with curl (resume support)
curl -C - -O "$AMI_URL"

# Or with wget (resume support)
wget -c "$AMI_URL"

# Monitor progress
ls -lh appd_va*.ami
```

---

### Option C: Via Partner Portal (For Partners)

1. **Access Partner Portal**
   - URL provided by AppDynamics partner team
   - Log in with partner credentials

2. **Navigate to Resources**
   - Find Virtual Appliance downloads
   - Select AWS AMI variant

3. **Download**
   - Follow portal-specific instructions
   - Verify checksums provided

---

## Part 2: Verify Download

### Verify File Integrity

#### Check File Size

```bash
# Check actual file size
ls -lh ~/Downloads/appd_va_*.ami

# Expected: 20-30GB
# If much smaller, download may have failed
```

#### Verify Checksum (If Provided)

```bash
# MD5 checksum
md5sum ~/Downloads/appd_va_25.7.0.2255.ami

# Compare with checksum from download page
# Should match exactly

# SHA256 checksum (if provided)
sha256sum ~/Downloads/appd_va_25.7.0.2255.ami
```

**Example:**
```bash
# From download page:
MD5: abc123def456789...

# Your file:
$ md5sum appd_va_25.7.0.2255.ami
abc123def456789... appd_va_25.7.0.2255.ami

# ✅ Match = Good
# ❌ No match = Re-download
```

#### Verify File Format

```bash
# Check file type
file ~/Downloads/appd_va_25.7.0.2255.ami

# Should show:
# data (for RAW disk image)
# or specific filesystem type

# Check if it's a valid disk image
qemu-img info ~/Downloads/appd_va_25.7.0.2255.ami 2>/dev/null || echo "Raw disk image (cannot get details)"
```

---

## Part 3: Upload to S3

### Automated Upload (RECOMMENDED)

**Use the provided script:**

```bash
# Navigate to lab repository
cd dec25_lab

# Run upload script
./scripts/upload-ami.sh \
    --ami-file ~/Downloads/appd_va_25.7.0.2255.ami \
    --ami-name "AppD-VA-25.7.0.2255" \
    --bucket appdynamics-lab-resources \
    --region us-west-2 \
    --admin-profile default

# Script will:
# ✅ Upload to S3
# ✅ Create vmimport role
# ✅ Import snapshot
# ✅ Register AMI
# ✅ Update configuration

# Time: 20-45 minutes (mostly automated)
```

**Skip to [Part 7: Verify and Test](#part-7-verify-and-test) if using automated script.**

---

### Manual Upload Process

#### Step 1: Create/Verify S3 Bucket

```bash
# Set variables
BUCKET_NAME="appdynamics-lab-resources"
AWS_REGION="us-west-2"
AWS_PROFILE="default"  # Or your admin profile

# Check if bucket exists
aws s3 ls s3://${BUCKET_NAME} --region ${AWS_REGION} --profile ${AWS_PROFILE}

# If bucket doesn't exist, create it
if ! aws s3 ls s3://${BUCKET_NAME} --region ${AWS_REGION} --profile ${AWS_PROFILE} 2>/dev/null; then
    echo "Creating bucket..."
    
    # For us-east-1
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket ${BUCKET_NAME} \
            --region ${AWS_REGION} \
            --profile ${AWS_PROFILE}
    else
        # For other regions
        aws s3api create-bucket \
            --bucket ${BUCKET_NAME} \
            --region ${AWS_REGION} \
            --create-bucket-configuration LocationConstraint=${AWS_REGION} \
            --profile ${AWS_PROFILE}
    fi
    
    echo "✅ Bucket created"
else
    echo "✅ Bucket exists"
fi
```

#### Step 2: Upload AMI File

```bash
# Set file path
AMI_FILE=~/Downloads/appd_va_25.7.0.2255.ami
AMI_FILENAME=$(basename "$AMI_FILE")

# Upload to S3 (this takes 15-45 minutes depending on bandwidth)
echo "Uploading ${AMI_FILENAME} to S3..."
echo "This will take 15-45 minutes..."

aws s3 cp "$AMI_FILE" \
    "s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE} \
    --storage-class STANDARD \
    --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Check upload succeeded
if [ $? -eq 0 ]; then
    echo "✅ Upload complete"
    
    # Verify file in S3
    aws s3 ls "s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}" \
        --region ${AWS_REGION} \
        --profile ${AWS_PROFILE} \
        --human-readable
else
    echo "❌ Upload failed"
    exit 1
fi
```

**Upload Progress:**
```bash
# In another terminal, monitor upload
watch -n 5 "aws s3 ls s3://${BUCKET_NAME}/ami-imports/ --human-readable --summarize"
```

---

## Part 4: Import to AWS

### Step 1: Create vmimport IAM Role

**The vmimport role allows AWS VM Import/Export service to access your S3 bucket.**

#### Create Trust Policy

```bash
# Create trust policy document
cat > /tmp/vmimport-trust-policy.json << 'EOF'
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals": {
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF

# Check if role already exists
if aws iam get-role --role-name vmimport --profile ${AWS_PROFILE} 2>/dev/null; then
    echo "✅ vmimport role already exists"
else
    echo "Creating vmimport role..."
    
    # Create the role
    aws iam create-role \
        --role-name vmimport \
        --assume-role-policy-document file:///tmp/vmimport-trust-policy.json \
        --description "Role for VM Import/Export service" \
        --profile ${AWS_PROFILE}
    
    echo "✅ vmimport role created"
fi

# Clean up temp file
rm /tmp/vmimport-trust-policy.json
```

#### Attach Role Policy

```bash
# Create role policy document
cat > /tmp/vmimport-role-policy.json << EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::${BUCKET_NAME}",
            "arn:aws:s3:::${BUCKET_NAME}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
    --role-name vmimport \
    --policy-name vmimport \
    --policy-document file:///tmp/vmimport-role-policy.json \
    --profile ${AWS_PROFILE}

echo "✅ Role policy attached"

# Clean up
rm /tmp/vmimport-role-policy.json

# Verify role
aws iam get-role --role-name vmimport --profile ${AWS_PROFILE}
```

### Step 2: Import Snapshot from S3

```bash
# Set variables
AMI_NAME="AppD-VA-25.7.0.2255"
AMI_FILENAME="appd_va_25.7.0.2255.ami"
S3_URL="s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}"

echo "Starting snapshot import from S3..."
echo "S3 URL: $S3_URL"
echo "This process takes 20-30 minutes..."
echo ""

# Start import task
IMPORT_TASK_ID=$(aws ec2 import-snapshot \
    --description "AppDynamics VA - ${AMI_NAME}" \
    --disk-container "Description=${AMI_NAME},Format=RAW,Url=${S3_URL}" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE} \
    --query "ImportTaskId" \
    --output text)

if [ -z "$IMPORT_TASK_ID" ] || [ "$IMPORT_TASK_ID" == "None" ]; then
    echo "❌ Failed to start import task"
    exit 1
fi

echo "✅ Import task started: $IMPORT_TASK_ID"
echo ""
```

### Step 3: Monitor Import Progress

```bash
# Monitor progress (auto-updates every 30 seconds)
SNAPSHOT_ID=""
LAST_PROGRESS=""

while true; do
    sleep 30
    
    # Get task status
    TASK_INFO=$(aws ec2 describe-import-snapshot-tasks \
        --import-task-ids "$IMPORT_TASK_ID" \
        --region ${AWS_REGION} \
        --profile ${AWS_PROFILE} \
        --query "ImportSnapshotTasks[0].SnapshotTaskDetail" \
        --output json 2>/dev/null)
    
    STATUS=$(echo "$TASK_INFO" | jq -r '.Status // "unknown"')
    PROGRESS=$(echo "$TASK_INFO" | jq -r '.Progress // "0"')
    STATUS_MSG=$(echo "$TASK_INFO" | jq -r '.StatusMessage // ""')
    
    # Show progress if changed
    if [ "$PROGRESS" != "$LAST_PROGRESS" ]; then
        echo "[$(date '+%H:%M:%S')] Import progress: ${PROGRESS}% - ${STATUS_MSG}"
        LAST_PROGRESS="$PROGRESS"
    fi
    
    # Check if completed
    if [ "$STATUS" == "completed" ]; then
        echo ""
        echo "✅ Snapshot import completed!"
        
        SNAPSHOT_ID=$(echo "$TASK_INFO" | jq -r '.SnapshotId')
        echo "   Snapshot ID: $SNAPSHOT_ID"
        break
    elif [ "$STATUS" == "failed" ] || [ "$STATUS" == "deleted" ] || [ "$STATUS" == "deleting" ]; then
        echo ""
        echo "❌ Snapshot import failed: $STATUS"
        echo "   Message: $STATUS_MSG"
        exit 1
    fi
done

echo ""
echo "Snapshot ID: $SNAPSHOT_ID"
echo ""
```

**Typical Timeline:**
```
[12:00:00] Import progress: 0% - Pending
[12:02:00] Import progress: 5% - Converting
[12:05:00] Import progress: 25% - Converting
[12:10:00] Import progress: 50% - Converting
[12:15:00] Import progress: 75% - Converting
[12:20:00] Import progress: 95% - Converting
[12:22:00] Import progress: 100% - Completed
✅ Snapshot import completed!
```

---

## Part 5: Register as AMI

### Register Snapshot as AMI

```bash
# Verify we have snapshot ID
if [ -z "$SNAPSHOT_ID" ]; then
    echo "❌ No snapshot ID - import may have failed"
    exit 1
fi

echo "Registering AMI from snapshot: $SNAPSHOT_ID"
echo ""

# Register image
NEW_AMI_ID=$(aws ec2 register-image \
    --architecture x86_64 \
    --description "AppDynamics Virtual Appliance - ${AMI_NAME}" \
    --ena-support \
    --sriov-net-support simple \
    --virtualization-type hvm \
    --boot-mode uefi \
    --imds-support v2.0 \
    --name "${AMI_NAME}" \
    --root-device-name /dev/sda1 \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=${SNAPSHOT_ID}}" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE} \
    --query 'ImageId' \
    --output text)

if [ -z "$NEW_AMI_ID" ] || [ "$NEW_AMI_ID" == "None" ]; then
    echo "❌ Failed to register AMI"
    exit 1
fi

echo "✅ AMI registered successfully!"
echo "   AMI ID: $NEW_AMI_ID"
echo "   Name: $AMI_NAME"
echo "   Region: $AWS_REGION"
echo ""
```

### Add Tags to AMI

```bash
# Add descriptive tags
aws ec2 create-tags \
    --resources "$NEW_AMI_ID" "$SNAPSHOT_ID" \
    --tags \
        "Key=Name,Value=${AMI_NAME}" \
        "Key=Product,Value=AppDynamics" \
        "Key=Component,Value=Virtual-Appliance" \
        "Key=Version,Value=$(echo $AMI_NAME | sed 's/AppD-VA-//')" \
        "Key=ImportedDate,Value=$(date -u +%Y-%m-%d)" \
        "Key=Purpose,Value=Lab" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE}

echo "✅ Tags added"
```

---

## Part 6: Update Configuration

### Update Lab Configuration Files

```bash
# Navigate to repository
cd dec25_lab

# Backup current config
cp config/global.cfg config/global.cfg.backup.$(date +%Y%m%d_%H%M%S)

# Update global configuration
IMPORT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Update values using sed
sed -i.tmp "s|^APPD_AMI_ID=.*|APPD_AMI_ID=\"${NEW_AMI_ID}\"|" config/global.cfg
sed -i.tmp "s|^APPD_AMI_NAME=.*|APPD_AMI_NAME=\"${AMI_NAME}\"|" config/global.cfg
sed -i.tmp "s|^APPD_SNAPSHOT_ID=.*|APPD_SNAPSHOT_ID=\"${SNAPSHOT_ID}\"|" config/global.cfg
sed -i.tmp "s|^APPD_AMI_IMPORTED_DATE=.*|APPD_AMI_IMPORTED_DATE=\"${IMPORT_DATE}\"|" config/global.cfg
sed -i.tmp "s|^APPD_AMI_SOURCE_FILE=.*|APPD_AMI_SOURCE_FILE=\"${AMI_FILENAME}\"|" config/global.cfg

# Remove temp file
rm config/global.cfg.tmp

echo "✅ Configuration updated: config/global.cfg"
echo ""

# Display changes
echo "New Configuration:"
grep -E "(APPD_AMI_ID|APPD_AMI_NAME|APPD_SNAPSHOT_ID)" config/global.cfg
echo ""
```

### Create Import History Log

```bash
# Create logs directory if it doesn't exist
mkdir -p logs

# Append to history
cat >> logs/ami-import-history.log << EOF
─────────────────────────────────────────────────────────
Import Date:     ${IMPORT_DATE}
AMI ID:          ${NEW_AMI_ID}
AMI Name:        ${AMI_NAME}
Snapshot ID:     ${SNAPSHOT_ID}
Source File:     ${AMI_FILENAME}
S3 Path:         s3://${BUCKET_NAME}/ami-imports/${AMI_FILENAME}
Import Task:     ${IMPORT_TASK_ID}
Region:          ${AWS_REGION}
Status:          ✅ SUCCESS
─────────────────────────────────────────────────────────

EOF

echo "✅ Import history logged"
```

### Commit Configuration Changes

```bash
# Stage changes
git add config/global.cfg logs/ami-import-history.log

# Commit
git commit -m "Update AMI to ${AMI_NAME} (${NEW_AMI_ID})"

# Push to repository
git push origin main

echo "✅ Changes committed and pushed"
```

---

## Part 7: Verify and Test

### Verify AMI Details

```bash
# Get AMI details
aws ec2 describe-images \
    --image-ids "$NEW_AMI_ID" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE} \
    --output table

# Check AMI is available
AMI_STATE=$(aws ec2 describe-images \
    --image-ids "$NEW_AMI_ID" \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE} \
    --query 'Images[0].State' \
    --output text)

echo "AMI State: $AMI_STATE"

if [ "$AMI_STATE" == "available" ]; then
    echo "✅ AMI is ready to use"
else
    echo "⏳ AMI is still processing (state: $AMI_STATE)"
    echo "   Wait a few minutes and check again"
fi
```

### Test AMI with Dry-Run

```bash
# Test that AMI can be launched (dry-run only)
aws ec2 run-instances \
    --dry-run \
    --image-id "$NEW_AMI_ID" \
    --instance-type m5a.4xlarge \
    --region ${AWS_REGION} \
    --profile ${AWS_PROFILE}

# Expected: "DryRunOperation" = SUCCESS
# If "InvalidAMIID" = AMI not ready yet
```

### Test Actual Deployment

```bash
# Test deployment with new AMI
cd dec25_lab

# Deploy test team
./deployment/01-deploy.sh --team 99

# Should use new AMI automatically
# Check it created VMs successfully

# Clean up test
./deployment/cleanup.sh --team 99 --confirm
```

---

## Automated Process

### Use Provided Script (EASIEST)

**All the above steps automated in one script:**

```bash
# Navigate to repository
cd dec25_lab

# Run complete import process
./scripts/upload-ami.sh \
    --ami-file ~/Downloads/appd_va_25.7.0.2255.ami \
    --ami-name "AppD-VA-25.7.0.2255" \
    --bucket appdynamics-lab-resources \
    --region us-west-2 \
    --admin-profile default

# Script Output:
# ╔══════════════════════════════════════════════════════════╗
# ║  AppDynamics Virtual Appliance AMI Import               ║
# ╚══════════════════════════════════════════════════════════╝
#
# AMI File: /Users/you/Downloads/appd_va_25.7.0.2255.ami
# AMI Name: AppD-VA-25.7.0.2255
# Bucket: appdynamics-lab-resources
# Region: us-west-2
#
# Step 1/4: Uploading AMI file to S3...
# [Progress bar...]
# ✅ Upload completed!
#
# Step 2/4: Setting up vmimport IAM role...
# ✅ IAM role configured
#
# Step 3/4: Importing EBS snapshot from S3...
# Import progress: 25% - Converting
# Import progress: 50% - Converting
# Import progress: 75% - Converting
# Import progress: 100% - Completed
# ✅ Snapshot import completed!
# Snapshot ID: snap-abc123...
#
# Step 4/4: Registering AMI from snapshot...
# ✅ AMI registered: ami-xyz789...
#
# ╔══════════════════════════════════════════════════════════╗
# ║  ✅ AMI Import Complete!                                 ║
# ╚══════════════════════════════════════════════════════════╝
#
# AMI Details:
#   AMI ID: ami-xyz789...
#   Name: AppD-VA-25.7.0.2255
#   Region: us-west-2
#
# Configuration Updated:
#   config/global.cfg (APPD_AMI_ID)
#
# History Logged:
#   logs/ami-import-history.log
```

### Skip Upload (If File Already in S3)

```bash
# Use this if you already uploaded the file
./scripts/upload-ami.sh \
    --ami-file ~/Downloads/appd_va_25.7.0.2255.ami \
    --skip-upload

# Will skip Step 1 and go directly to import
```

---

## Troubleshooting

### Issue: Download Fails or Corrupts

**Symptoms:**
- File size much smaller than expected
- Checksum doesn't match
- Download interrupts

**Solutions:**
```bash
# Resume download with curl
curl -C - -O [download-url]

# Or with wget
wget -c [download-url]

# Verify checksum after download
md5sum appd_va_25.7.0.2255.ami
```

### Issue: Upload to S3 Times Out

**Symptoms:**
- Upload fails after many minutes
- Connection timeout errors

**Solutions:**
```bash
# Use multipart upload (automatic for files >5GB)
aws configure set default.s3.multipart_threshold 5GB
aws configure set default.s3.multipart_chunksize 100MB

# Retry upload
aws s3 cp appd_va_25.7.0.2255.ami s3://bucket/path/ --profile admin

# Or use screen/tmux to keep session alive
screen -S ami-upload
aws s3 cp appd_va_25.7.0.2255.ami s3://bucket/path/
# Detach: Ctrl+A, D
# Reattach: screen -r ami-upload
```

### Issue: vmimport Role Creation Fails

**Symptoms:**
- "Role already exists" but with different trust policy
- Permission denied creating role

**Solutions:**
```bash
# Check if role exists
aws iam get-role --role-name vmimport

# Delete existing role (if misconfigured)
aws iam delete-role-policy --role-name vmimport --policy-name vmimport
aws iam delete-role --role-name vmimport

# Recreate following Part 4 Step 1
```

### Issue: Import Snapshot Fails

**Symptoms:**
- Import task status: "failed"
- Error: "ClientError: Disk validation failed"
- Error: "InvalidParameter"

**Common Causes & Solutions:**

**1. Wrong file format:**
```bash
# Check file type
file appd_va_25.7.0.2255.ami

# Should be RAW disk image
# If it's OVA/VMDK, convert first (not covered here)
```

**2. S3 bucket permissions:**
```bash
# Verify vmimport role can access bucket
aws iam get-role-policy --role-name vmimport --policy-name vmimport

# Should include bucket ARN
```

**3. File corrupted:**
```bash
# Re-download and verify checksum
md5sum appd_va_25.7.0.2255.ami
# Compare with checksum from download page
```

### Issue: AMI Registration Fails

**Symptoms:**
- "InvalidSnapshot" error
- "InvalidParameter" error

**Solutions:**
```bash
# Verify snapshot exists and is complete
aws ec2 describe-snapshots --snapshot-ids snap-abc123

# Check snapshot status
# Should show: "completed"

# Wait if still copying, then retry registration
```

### Issue: New AMI Doesn't Boot

**Symptoms:**
- Instance launches but fails status checks
- Instance terminates immediately

**Solutions:**
```bash
# Check system log
aws ec2 get-console-output --instance-id i-abc123

# Common issues:
# - Wrong boot-mode (should be uefi for newer appliances)
# - Wrong virtualization-type (should be hvm)
# - Missing ena-support flag

# Re-register with correct parameters (see Part 5)
```

---

## IAM Permissions Required

### For Instructor/Admin

**Minimum permissions needed for this process:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::appdynamics-lab-resources",
        "arn:aws:s3:::appdynamics-lab-resources/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy"
      ],
      "Resource": "arn:aws:iam::*:role/vmimport"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ImportSnapshot",
        "ec2:DescribeImportSnapshotTasks",
        "ec2:RegisterImage",
        "ec2:DescribeImages",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Best Practices

### DO:
- ✅ Verify checksums after download
- ✅ Use screen/tmux for long uploads
- ✅ Tag AMIs with version and date
- ✅ Keep import history log
- ✅ Test new AMI before distributing
- ✅ Backup old AMI ID before updating config
- ✅ Commit config changes to git

### DON'T:
- ❌ Interrupt upload or import process
- ❌ Delete S3 file immediately after import (keep for recovery)
- ❌ Share AMI publicly without legal review
- ❌ Forget to update documentation
- ❌ Skip testing new AMI

---

## Quick Reference

### Complete Process (Automated)
```bash
# Download AMI from AppDynamics
# Then run:
cd dec25_lab
./scripts/upload-ami.sh --ami-file ~/Downloads/appd_va_X.Y.Z.ami
```

### Check Import Status
```bash
aws ec2 describe-import-snapshot-tasks \
    --import-task-ids import-snap-abc123 \
    --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.[Status,Progress,StatusMessage]'
```

### List Available AMIs
```bash
aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=AppD-VA-*" \
    --query 'Images[*].[ImageId,Name,CreationDate]' \
    --output table
```

### Current AMI in Use
```bash
grep APPD_AMI_ID config/global.cfg
```

---

## Timeline Summary

| Step | Duration | Automated |
|------|----------|-----------|
| Download AMI | 5-45 min | No (manual) |
| Verify checksum | 2 min | Optional |
| Upload to S3 | 15-45 min | Yes |
| Create vmimport role | 1 min | Yes |
| Import snapshot | 20-30 min | Yes (waits) |
| Register AMI | 1 min | Yes |
| Update config | 1 min | Yes |
| Test deployment | 5-10 min | Optional |
| **Total** | **45-135 min** | **Mostly** |

**Using automated script:** 30-90 minutes hands-off

---

## Support

**For issues:**
1. Check [Troubleshooting](#troubleshooting) section
2. Review AWS CloudTrail logs for API errors
3. Check `logs/ami-import-history.log` for previous imports
4. Contact AppDynamics support for download/format issues
5. Contact AWS support for import/snapshot issues

**Useful resources:**
- AWS VM Import/Export: https://docs.aws.amazon.com/vm-import/
- AppDynamics Downloads: https://download.appdynamics.com/
- Lab Repository: https://github.com/sandbreak80/dec25_lab

---

**Status:** Ready to Use  
**Automated Script:** `scripts/upload-ami.sh`  
**Documentation:** Complete

For questions or issues, refer to troubleshooting section or contact support.
