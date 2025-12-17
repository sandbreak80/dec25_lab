# Instructor Guide - Student Credential Distribution

## Overview

This guide explains how to distribute credentials to students for the AppDynamics Virtual Appliance lab.

---

## Quick Setup

### Step 1: Create Student Quick-Start File

```bash
# Copy the template
cp START_HERE.md.template START_HERE.md

# Edit with real credentials
vi START_HERE.md  # or use your preferred editor
```

### Step 2: Fill in Credentials

Replace these placeholders in `START_HERE.md`:

| Placeholder | Real Value | Location |
|-------------|------------|----------|
| `[YOUR_ACCESS_KEY_ID]` | AWS Access Key ID | Lines 11, 38 |
| `[YOUR_SECRET_ACCESS_KEY]` | AWS Secret Access Key | Lines 12, 39 |
| `[YOUR_ACCOUNT_ID]` | AWS Account Number | Lines 14, 47 |
| `[EXPIRATION_DATE]` | Credential expiry date | Line 19 |
| `[YOUR_NUMBER]` | Team number (1-5) | Line 26 |

**Example:**
```
# Before
AWS Access Key ID:     [YOUR_ACCESS_KEY_ID]

# After
AWS Access Key ID:     AKIAUSTPCS7GG4F7PSBV
```

### Step 3: Distribute to Students

**Option A: Email** (Most Common)
```bash
# Attach START_HERE.md to email
# Subject: AppDynamics Lab - Team [N] Credentials
# Body: Attached is your quick-start guide with credentials
```

**Option B: LMS Upload**
- Upload `START_HERE.md` to your Learning Management System
- Make it downloadable only (not viewable in browser)

**Option C: Secure File Share**
- Upload to Google Drive / OneDrive / Dropbox
- Set to "View Only" with download enabled
- Share link with students

---

## Security Best Practices

### ✅ DO:
- Create a unique `START_HERE.md` for each class/cohort
- Rotate credentials after each lab session
- Set AWS budget alerts for the lab account
- Remind students to clean up resources

### ❌ DON'T:
- Commit `START_HERE.md` to Git (it's in `.gitignore` for this reason)
- Share credentials via Slack/Teams/public channels
- Reuse the same credentials across multiple cohorts
- Forget to delete IAM users after lab ends

---

## What Students Receive

Students get a single file: **`START_HERE.md`**

This file contains:
- ✅ Their AWS credentials (filled in by you)
- ✅ Their team assignment (you specify)
- ✅ Quick 3-step deployment instructions
- ✅ Links to complete documentation
- ✅ Essential troubleshooting tips

**Students do NOT need:**
- `STUDENT_CREDENTIALS.txt` (obsolete - replaced by `START_HERE.md`)
- Separate team assignment instructions
- Separate credential files

---

## Team Assignments

Assign teams based on class size:

| Class Size | Teams to Use | Example Distribution |
|------------|--------------|---------------------|
| 1-5 students | Teams 1-5 | 1 student per team |
| 6-10 students | Teams 1-5 | 2 students per team |
| 11-15 students | Teams 1-5 | 3 students per team |
| 16-20 students | Teams 1-5 | 4 students per team |

**Recommendation:** Keep 2-4 students per team for collaboration.

---

## Pre-Lab Checklist

Before distributing credentials:

- [ ] IAM user `lab-student` exists with proper permissions
- [ ] Access keys generated for `lab-student`
- [ ] License file uploaded to S3: `s3://appdynamics-lab-resources/shared/license.lic`
- [ ] AMI ID populated in `state/shared/ami.id`
- [ ] Route 53 hosted zone configured: `splunkylabs.com`
- [ ] SSL certificate available in ACM
- [ ] AWS budget alerts configured
- [ ] Service quotas checked (15 EC2 instances, 240 vCPUs, 15 EIPs)

---

## Post-Lab Cleanup

After the lab session:

### Step 1: Verify All Teams Cleaned Up

```bash
# Check for remaining resources
for team in 1 2 3 4 5; do
  echo "=== Team $team ==="
  aws ec2 describe-instances \
    --filters "Name=tag:Team,Values=team$team" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
    --output table
done
```

### Step 2: Force Cleanup (if needed)

```bash
# If students forgot to clean up
for team in 1 2 3 4 5; do
  ./deployment/cleanup.sh --team $team --confirm
done
```

### Step 3: Rotate Credentials

```bash
# Delete old access keys
aws iam delete-access-key --user-name lab-student --access-key-id AKIA...

# Create new access keys for next cohort
aws iam create-access-key --user-name lab-student > new-credentials.json
```

### Step 4: Delete IAM User (Optional)

```bash
# If lab is completely done
aws iam delete-access-key --user-name lab-student --access-key-id AKIA...
aws iam remove-user-from-group --user-name lab-student --group-name AppDynamicsLabStudents
aws iam delete-user --user-name lab-student
```

---

## Troubleshooting Student Issues

### "Can't clone the repository"

**Solution:** Students need Git installed
```bash
# macOS
brew install git

# Linux
sudo apt install git
```

### "AWS CLI not found"

**Solution:** Students need AWS CLI v2
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### "Access Denied" errors

**Possible causes:**
1. Credentials not configured correctly (`aws configure`)
2. IAM policy missing permissions (check `docs/iam-student-policy.json`)
3. Credentials expired or rotated

**Verify:**
```bash
aws sts get-caller-identity
# Should show: User "lab-student"
```

### "VPC already exists"

**Cause:** Student's previous deployment wasn't cleaned up

**Solution:**
```bash
# Student runs cleanup
./deployment/cleanup.sh --team N --confirm

# Or instructor force-cleans
AWS_PROFILE=admin ./deployment/cleanup.sh --team N --confirm
```

---

## Cost Management

### Expected Costs

| Resource | Cost per Team per Day | 5 Teams Total |
|----------|----------------------|---------------|
| EC2 (3 × r5.4xlarge) | $6-8 | $30-40 |
| EBS Storage | $1-2 | $5-10 |
| Data Transfer | $0.50-1 | $2.50-5 |
| ALB | $0.50 | $2.50 |
| **Total** | **~$8-12/day** | **~$40-60/day** |

### Cost Control Tips

1. **Auto-Shutdown** - Enable in `config/teamX.cfg`:
   ```bash
   AUTO_SHUTDOWN_ENABLED=true
   AUTO_SHUTDOWN_TIME=22:00  # 10 PM
   AUTO_STARTUP_TIME=14:00   # 2 PM
   ```

2. **Budget Alerts** - Set in AWS Budgets:
   - Warning at $50/day
   - Alert at $75/day
   - Critical at $100/day

3. **Regular Cleanup** - Schedule cleanup jobs:
   ```bash
   # Cron job to clean up idle resources
   0 0 * * * /path/to/cleanup-idle-resources.sh
   ```

---

## Support Resources

For instructor support:

- **Lab Repository:** https://github.com/sandbreak80/dec25_lab
- **Report Issues:** https://github.com/sandbreak80/dec25_lab/issues
- **Official AppD Docs:** https://help.splunk.com/en/appdynamics-on-premises/

---

**Questions?** Open an issue in the lab repository or contact the lab maintainer.

**Last Updated:** December 17, 2025
