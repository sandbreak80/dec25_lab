# Complete Lab Setup Guide - Quick Start

**Essential Guide for Instructor Lab Setup**

**Version:** 1.0  
**Last Updated:** December 19, 2025  
**Est. Time:** 2-3 hours (one-time setup)

---

## Overview

This is your **master checklist** for setting up the AppDynamics lab environment. Follow these steps in order to prepare for student lab sessions.

**What This Guide Does:**
- ✅ Walks you through complete lab setup
- ✅ Provides links to detailed guides
- ✅ Gives you a checklist to track progress
- ✅ Estimates time for each step

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS account with admin access
- [ ] AWS CLI installed and configured
- [ ] Git installed
- [ ] Access to AppDynamics download portal
- [ ] ~40GB free disk space (for AMI download)
- [ ] 2-3 hours available time

---

## Part 1: Initial Repository Setup (10 minutes)

### Clone Repository

```bash
# Clone the lab repository
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# Verify you're on main branch
git status

# Pull latest changes
git pull origin main
```

**✅ Checkpoint:** You should see all lab files and documentation.

---

## Part 2: Create Student IAM Access (30 minutes)

### Follow IAM Access Key Guide

📖 **Detailed Guide:** `IAM_ACCESS_KEY_CREATION_GUIDE.md`

### Quick Steps:

1. **Create IAM User** (5 min)
   ```bash
   # Via AWS Console: IAM → Users → Add users
   # Username: lab-student
   # Access type: Programmatic access
   
   # Or via CLI:
   aws iam create-user --user-name lab-student
   ```

2. **Create & Attach Policy** (10 min)
   ```bash
   # Via Console: IAM → Policies → Create policy
   # Copy JSON from: docs/iam-student-policy.json
   # Name: AppDynamicsLabStudentPolicy
   # Attach to lab-student user
   
   # Or via CLI:
   aws iam put-user-policy \
       --user-name lab-student \
       --policy-name AppDynamicsLabStudentPolicy \
       --policy-document file://docs/iam-student-policy.json
   ```

3. **Generate Access Keys** (2 min)
   ```bash
   # Via Console: IAM → Users → lab-student → Security credentials
   # → Create access key
   # SAVE THESE IMMEDIATELY!
   
   # Or via CLI:
   aws iam create-access-key --user-name lab-student
   ```

4. **Test Permissions** (10 min)
   ```bash
   # Configure test profile
   aws configure --profile lab-student-test
   # Enter the access keys you just created
   
   # Test authentication
   aws sts get-caller-identity --profile lab-student-test
   
   # Test EC2 permissions (dry-run)
   aws ec2 run-instances --dry-run \
       --image-id ami-092d9aa0e2874fd9c \
       --instance-type m5a.4xlarge \
       --profile lab-student-test
   
   # Expected: "DryRunOperation" = SUCCESS
   ```

5. **Create Student Credentials Document** (3 min)
   ```bash
   # Use template from IAM_ACCESS_KEY_CREATION_GUIDE.md
   # Replace placeholders with actual access keys
   # Save as: STUDENT_AWS_CREDENTIALS.txt
   ```

**✅ Checkpoint:** Student access keys work, credentials document ready.

---

## Part 3: Import AppDynamics AMI (1-2 hours)

### Follow AMI Download Guide

📖 **Detailed Guide:** `AMI_DOWNLOAD_UPLOAD_GUIDE.md`

### Quick Steps:

1. **Download AMI** (15-45 min)
   - Go to: https://download.appdynamics.com/
   - Product: On-Premises Platform → Virtual Appliance
   - Download: AWS AMI / RAW disk image
   - Save to: `~/Downloads/`
   - File size: ~20-30GB

2. **Verify Download** (2 min)
   ```bash
   # Check file size
   ls -lh ~/Downloads/appd_va_*.ami
   
   # Verify checksum (if provided)
   md5sum ~/Downloads/appd_va_25.7.0.2255.ami
   ```

3. **Upload and Import** (30-90 min - mostly automated)
   ```bash
   cd dec25_lab
   
   # Run automated import script
   ./scripts/upload-ami.sh \
       --ami-file ~/Downloads/appd_va_25.7.0.2255.ami \
       --bucket appdynamics-lab-resources \
       --region us-west-2 \
       --admin-profile default
   
   # Script will:
   # ✅ Upload to S3 (15-45 min)
   # ✅ Create vmimport IAM role (1 min)
   # ✅ Import snapshot (20-30 min)
   # ✅ Register AMI (1 min)
   # ✅ Update config/global.cfg (1 min)
   ```

4. **Verify Import** (2 min)
   ```bash
   # Check AMI ID in config
   grep APPD_AMI_ID config/global.cfg
   
   # Verify AMI is available
   aws ec2 describe-images --image-ids ami-xyz123...
   ```

5. **Commit Changes** (1 min)
   ```bash
   git add config/global.cfg logs/ami-import-history.log
   git commit -m "Update AMI to 25.7.0.2255"
   git push origin main
   ```

**✅ Checkpoint:** AMI imported and configuration updated.

---

## Part 4: Test Complete Deployment (30 minutes)

### Test with Student Credentials

```bash
# Use student credentials
export AWS_PROFILE=lab-student-test

# Deploy test team
./deployment/01-deploy.sh --team 99

# Should complete successfully:
# ✅ Phase 1: VPC and Networking
# ✅ Phase 2: Security Groups
# ✅ Phase 3: Virtual Machines (uses new AMI)
# ✅ Phase 4: Elastic IPs

# Verify resources created
aws ec2 describe-instances --filters "Name=tag:Team,Values=99"

# Clean up test
./deployment/cleanup.sh --team 99 --confirm

# Verify cleanup completed
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=appd-team-99-vpc"
# Should return empty
```

**✅ Checkpoint:** Student credentials work, deployment succeeds, cleanup works.

---

## Part 5: Prepare Student Materials (15 minutes)

### 1. Student Credentials

- [ ] Edit `STUDENT_AWS_CREDENTIALS.txt`
- [ ] Replace access key placeholders
- [ ] Set expiration date
- [ ] Add your contact info

### 2. Student Documentation

```bash
# Verify these files exist and are up-to-date
ls -l QUICK_REFERENCE.md
ls -l TROUBLESHOOTING_GUIDE.md
ls -l docs/LAB_GUIDE.md
```

### 3. Choose Distribution Method

**Option A: Via LMS (Canvas/Moodle)**
- Upload STUDENT_AWS_CREDENTIALS.txt
- Upload QUICK_REFERENCE.md
- Set visibility: Students only
- Post announcement with links

**Option B: Via Email**
```bash
# Create encrypted ZIP
zip -e student-lab-credentials.zip \
    STUDENT_AWS_CREDENTIALS.txt \
    QUICK_REFERENCE.md

# Email ZIP to students
# Share password via different channel
```

**Option C: In-Person**
- Print credentials
- Distribute during first lab session
- Help students configure on the spot

**✅ Checkpoint:** Student materials prepared and ready to distribute.

---

## Part 6: Pre-Lab Verification (10 minutes)

### Final Checks

```bash
# 1. Verify AWS profile configuration
grep AWS_PROFILE config/team*.cfg
# All should show: AWS_PROFILE="default"

# 2. Verify AMI is configured
grep APPD_AMI_ID config/global.cfg
# Should show valid AMI ID

# 3. Verify IAM policy is applied
aws iam get-user-policy \
    --user-name lab-student \
    --policy-name AppDynamicsLabStudentPolicy

# 4. Test student credentials work
aws sts get-caller-identity --profile lab-student-test

# 5. Verify repository is up-to-date
git status
git pull origin main
```

**✅ Checkpoint:** All systems ready for student lab sessions.

---

## Complete Setup Checklist

### One-Time Setup (Before First Lab)

- [ ] Repository cloned and up-to-date
- [ ] IAM user `lab-student` created
- [ ] IAM policy `AppDynamicsLabStudentPolicy` attached
- [ ] Student access keys generated and saved
- [ ] Student credentials document created
- [ ] AppDynamics AMI downloaded
- [ ] AMI uploaded to S3
- [ ] AMI imported and registered in AWS
- [ ] Configuration files updated (config/global.cfg)
- [ ] Test deployment successful with student credentials
- [ ] Test cleanup successful
- [ ] Student materials prepared
- [ ] Distribution method chosen and prepared

### Before Each Lab Session

- [ ] Pull latest code: `git pull origin main`
- [ ] Verify student access keys are active
- [ ] Verify AMI is available in AWS
- [ ] Distribute credentials to students
- [ ] Post QUICK_REFERENCE.md to course site
- [ ] Be ready with TROUBLESHOOTING_GUIDE.md

### After Each Lab Session

- [ ] Verify all student resources deleted
- [ ] Check for orphaned VPCs/instances
- [ ] Consider deactivating access keys (optional)
- [ ] Gather student feedback
- [ ] Update documentation if needed

---

## Time Estimates

| Task | Time | Can Skip If Already Done |
|------|------|-------------------------|
| Repository setup | 10 min | Yes (after first time) |
| Create IAM user/policy | 30 min | Yes (reuse for next session) |
| Download AMI | 15-45 min | Yes (if version unchanged) |
| Upload/Import AMI | 30-90 min | Yes (if version unchanged) |
| Test deployment | 30 min | No (always test) |
| Prepare materials | 15 min | Mostly (update credentials) |
| **First Time Total** | **2-3 hours** | - |
| **Subsequent Labs** | **45 min** | (test + prep only) |

---

## Quick Reference Commands

### Check IAM User
```bash
aws iam get-user --user-name lab-student
```

### Check Current AMI
```bash
grep APPD_AMI_ID config/global.cfg
```

### Test Student Credentials
```bash
aws sts get-caller-identity --profile lab-student-test
```

### Test Deployment
```bash
export AWS_PROFILE=lab-student-test
./deployment/01-deploy.sh --team 99
./deployment/cleanup.sh --team 99 --confirm
```

### Check for Orphaned Resources
```bash
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws ec2 describe-vpcs --filters "Name=tag:Purpose,Values=AppDynamics-Lab"
aws elbv2 describe-load-balancers
```

---

## Troubleshooting Quick Links

**Issue: Students can't authenticate**
- Check: `IAM_ACCESS_KEY_CREATION_GUIDE.md` → Part 2: Verify Permissions

**Issue: Students can't create VMs**
- Check: `IAM_POLICY_APPLY_GUIDE.md` → Verification section
- Verify policy has all EC2 resource types

**Issue: Need to update AMI**
- Check: `AMI_DOWNLOAD_UPLOAD_GUIDE.md` → Automated Process

**Issue: Deployment fails**
- Students: `QUICK_REFERENCE.md`
- Instructor: `TROUBLESHOOTING_GUIDE.md`

**Issue: Need to create new access keys**
- Check: `IAM_ACCESS_KEY_CREATION_GUIDE.md` → Part 6: Post-Lab Cleanup

---

## Documentation Index

### For You (Instructor):

1. **THIS FILE** - Quick start overview
2. `ACTION_REQUIRED.md` - Critical fixes summary
3. `IAM_ACCESS_KEY_CREATION_GUIDE.md` - ⭐ Create student credentials
4. `IAM_POLICY_APPLY_GUIDE.md` - IAM policy details
5. `AMI_DOWNLOAD_UPLOAD_GUIDE.md` - ⭐ Import new AMI versions
6. `TROUBLESHOOTING_GUIDE.md` - Detailed fixes for all issues
7. `STUDENT_DEPLOYMENT_DEFECTS.md` - All 8 defects documented

### For Students:

1. `QUICK_REFERENCE.md` - ⭐ One-page quick reference
2. `TROUBLESHOOTING_GUIDE.md` - Detailed troubleshooting
3. `docs/LAB_GUIDE.md` - Complete lab instructions
4. `README.md` - Repository overview

---

## Support

**For setup questions:**
- Review detailed guides (linked above)
- Check troubleshooting sections
- Review `STUDENT_DEPLOYMENT_DEFECTS.md` for known issues

**For AWS issues:**
- AWS Documentation: https://docs.aws.amazon.com/
- AWS Support: https://console.aws.amazon.com/support/

**For AppDynamics issues:**
- AppDynamics Docs: https://docs.appdynamics.com/
- Download Portal: https://download.appdynamics.com/
- Support Portal: https://support.appdynamics.com/

---

## Status

- ✅ All documentation complete
- ✅ All scripts tested and working
- ✅ IAM policy ready to apply
- ✅ AMI import process documented
- ✅ Student materials prepared
- ✅ Troubleshooting guides complete

**Ready for lab sessions!**

---

## Next Steps

1. **Now:** Follow Part 2 to create student IAM access keys
2. **Next:** Follow Part 3 to import AppDynamics AMI
3. **Then:** Follow Part 4 to test complete deployment
4. **Finally:** Follow Part 5 to prepare student materials

**Estimated total time:** 2-3 hours for first-time setup

**After setup:** Only 45 minutes needed for subsequent lab sessions

---

**Version:** 1.0  
**Status:** Production Ready  
**Last Updated:** December 19, 2025  
**Repository:** https://github.com/sandbreak80/dec25_lab
