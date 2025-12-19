# AMI Import Status

## Overview
Importing new AppDynamics Virtual Appliance AMI version 25.7.0.2255

## Current Status

### ✅ Completed Steps

1. **Upload to S3** - COMPLETED
   - File: `appd_va_25.7.0.2255.ami` (21 GiB)
   - Location: `s3://appdynamics-lab-resources/ami-imports/appd_va_25.7.0.2255.ami`
   - Region: `us-west-2`

2. **IAM Configuration** - COMPLETED
   - vmimport role configured
   - Permissions updated for S3 access
   - KMS permissions added

3. **Snapshot Import** - IN PROGRESS
   - Import Task ID: `import-snap-aba44b4755ebee77t`
   - Expected Duration: 20-30 minutes
   - Started: December 18, 2025

### ⏳ Pending Steps

4. **Register AMI** - PENDING
   - Will execute automatically after snapshot import completes
   - AMI Name: `AppD-VA-25.7.0.2255`

5. **Update State Files** - PENDING
   - `state/shared/ami.id`
   - `state/shared/ami-info.txt`
   - `state/shared/snapshot.id`

## Monitoring

### Background Process
The import process is running in the background in terminal 3.

**Check progress:**
```bash
# View terminal output
tail -f /Users/bmstoner/.cursor/projects/Users-bmstoner-code-projects-dec25-lab/terminals/3.txt

# Or use the status script
./scripts/check-ami-import-status.sh
```

### Manual Status Check
```bash
AWS_PROFILE=bstoner aws ec2 describe-import-snapshot-tasks \
  --import-task-ids import-snap-aba44b4755ebee77t \
  --region us-west-2
```

## What Happens Next

1. **Snapshot Import Completes** (20-30 minutes)
   - AWS will convert the raw disk image to an EBS snapshot
   - Progress updates every 30 seconds in the background script

2. **AMI Registration** (automatic)
   - Script will register the snapshot as an AMI
   - Configuration:
     - Architecture: x86_64
     - Virtualization: HVM
     - Boot Mode: UEFI
     - ENA Support: Enabled
     - IMDS: v2.0

3. **State Files Updated** (automatic)
   - New AMI ID written to state files
   - Lab deployments will automatically use new AMI

## Scripts Created

### 1. `scripts/upload-ami.sh`
Complete upload and import pipeline (for future AMI updates)
```bash
./scripts/upload-ami.sh --ami-file /path/to/ami --admin-profile bstoner
```

### 2. `scripts/import-ami-from-s3.sh`
Import existing S3 file (currently running)
```bash
./scripts/import-ami-from-s3.sh
```

### 3. `scripts/check-ami-import-status.sh`
Quick status check (use anytime)
```bash
./scripts/check-ami-import-status.sh
```

## Troubleshooting

### If Import Fails

1. Check IAM permissions:
```bash
AWS_PROFILE=bstoner aws iam get-role-policy \
  --role-name vmimport \
  --policy-name vmimport
```

2. Check S3 file:
```bash
AWS_PROFILE=bstoner aws s3 ls s3://appdynamics-lab-resources/ami-imports/
```

3. Check import task details:
```bash
./scripts/check-ami-import-status.sh
```

### If You Need to Restart

The upload is complete, so you can skip it:
```bash
./scripts/import-ami-from-s3.sh
```

## Expected Completion

**Estimated Time:** ~30 minutes from start  
**Script Will:**
- Show progress updates
- Display success message with new AMI ID
- Update all state files automatically

## After Completion

Once complete, verify the new AMI:
```bash
# Get the new AMI ID
cat state/shared/ami.id

# Describe the AMI
AWS_PROFILE=bstoner aws ec2 describe-images \
  --image-ids $(cat state/shared/ami.id) \
  --region us-west-2
```

New VM deployments will automatically use the new AMI version 25.7.0.2255.

---
Last Updated: December 18, 2025

