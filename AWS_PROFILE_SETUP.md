# AWS Profile Setup - Admin + Lab Student

This guide shows how to configure multiple AWS profiles so scripts can automatically use the right credentials.

## Overview

You'll configure two profiles:
1. **default** - Your admin account (for S3 operations)
2. **lab-student** - The lab student account (for deployments)

Scripts will automatically switch between them as needed.

---

## Setup Instructions

### Step 1: Check Existing Configuration

```bash
cat ~/.aws/credentials
cat ~/.aws/config
```

### Step 2: Configure Profiles

Edit `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = YOUR_ADMIN_ACCESS_KEY
aws_secret_access_key = YOUR_ADMIN_SECRET_KEY

[lab-student]
aws_access_key_id = AKIAIOSFODNN7DQREXAMPLE
aws_secret_access_key = FVv68JSro1ymNeScx5kvsa2drWYUhEOFIQhsXXI5
```

Edit `~/.aws/config`:

```ini
[default]
region = us-west-2
output = json

[profile lab-student]
region = us-west-2
output = json
```

**Note:** Replace `YOUR_ADMIN_ACCESS_KEY` and `YOUR_ADMIN_SECRET_KEY` with your actual admin credentials.

The lab-student keys are in `STUDENT_CREDENTIALS.txt`.

### Step 3: Verify Both Profiles Work

```bash
# Test default (admin) profile
aws sts get-caller-identity
# Should show: arn:aws:iam::314839308236:user/YOUR_ADMIN_USER

# Test lab-student profile
aws sts get-caller-identity --profile lab-student
# Should show: arn:aws:iam::314839308236:user/lab-student
```

---

## How Scripts Use Profiles

### Upload License (Uses Admin)

```bash
./scripts/upload-license-to-s3.sh

# Or specify a different admin profile
./scripts/upload-license-to-s3.sh --admin-profile my-admin
```

This script uses the admin profile (default: `default`) for:
- Creating S3 bucket
- Setting bucket policies
- Uploading files

### Apply License (Uses Lab-Student)

```bash
# Uses whatever profile is default or specified
./scripts/apply-license.sh --team 1

# Or use lab-student explicitly
AWS_PROFILE=lab-student ./scripts/apply-license.sh --team 1
```

### Deployment Scripts (Uses Lab-Student)

```bash
# Set lab-student as default for deployment
export AWS_PROFILE=lab-student

./deployment/01-deploy.sh --team 1
./deployment/02-create-dns.sh --team 1
# ... etc
```

Or configure in team config files:

```bash
# In config/team1.cfg
AWS_PROFILE="lab-student"
```

---

## Quick Profile Switching

### Option 1: Environment Variable

```bash
# Use admin
export AWS_PROFILE=default
aws s3 ls

# Use lab-student
export AWS_PROFILE=lab-student
aws ec2 describe-instances

# Reset to default
unset AWS_PROFILE
```

### Option 2: Per-Command

```bash
# One-time use of specific profile
aws s3 ls --profile default
aws ec2 describe-instances --profile lab-student
```

### Option 3: Script Sets It

```bash
# Let scripts handle it automatically (recommended)
./scripts/upload-license-to-s3.sh  # Uses admin
./scripts/apply-license.sh --team 1  # Uses lab-student
```

---

## Troubleshooting

### "Unable to locate credentials"

**Problem:** No default profile configured

**Solution:**
```bash
aws configure
# Enter your admin credentials
```

### "Access Denied" When Uploading License

**Problem:** Using lab-student instead of admin

**Solution:**
```bash
# Explicitly specify admin profile
./scripts/upload-license-to-s3.sh --admin-profile default
```

### "Access Denied" When Creating EC2

**Problem:** Using admin instead of lab-student

**Solution:**
```bash
# Switch to lab-student
export AWS_PROFILE=lab-student
./deployment/01-deploy.sh --team 1
```

### Profile Not Found

**Problem:** Profile name mismatch

**Solution:**
```bash
# List all configured profiles
aws configure list-profiles

# Use the correct name
./scripts/upload-license-to-s3.sh --admin-profile <your-profile-name>
```

---

## Security Best Practices

### 1. Protect Credentials Files

```bash
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config
```

### 2. Use Different Passwords

Ensure your admin account and lab-student account have different passwords.

### 3. Rotate Keys Regularly

```bash
# Generate new keys every 90 days
aws iam create-access-key --user-name lab-student
aws iam delete-access-key --access-key-id OLD_KEY_ID --user-name lab-student
```

### 4. Enable MFA (Admin Account)

```bash
# Enable MFA for your admin account (highly recommended)
# Do this in AWS Console: IAM → Users → Your User → Security Credentials
```

### 5. Limit Admin Usage

Only use admin profile when necessary:
- ✅ Uploading license to S3
- ✅ Creating IAM policies
- ❌ NOT for daily deployment tasks

---

## Alternative: Named Profiles

If you prefer not to use `default` for admin:

```ini
# ~/.aws/credentials
[bmstoner-admin]
aws_access_key_id = YOUR_ADMIN_KEY
aws_secret_access_key = YOUR_ADMIN_SECRET

[lab-student]
aws_access_key_id = AKIAIOSFODNN7DQREXAMPLE
aws_secret_access_key = FVv68JSro1ymNeScx5kvsa2drWYUhEOFIQhsXXI5
```

Then use:

```bash
./scripts/upload-license-to-s3.sh --admin-profile bmstoner-admin
export AWS_PROFILE=lab-student
./deployment/01-deploy.sh --team 1
```

---

## Testing Your Setup

Run this test script:

```bash
#!/bin/bash

echo "Testing AWS Profile Setup..."
echo ""

echo "=== Default Profile (Admin) ==="
aws sts get-caller-identity
echo ""

echo "=== Lab-Student Profile ==="
aws sts get-caller-identity --profile lab-student
echo ""

echo "=== S3 Access (Admin) ==="
aws s3 ls --profile default 2>&1 | head -5
echo ""

echo "=== EC2 Access (Lab-Student) ==="
aws ec2 describe-vpcs --profile lab-student --query 'Vpcs[0].VpcId' 2>&1
echo ""

echo "✅ If both profiles work, you're all set!"
```

---

## Summary

**Recommended Setup:**

1. **Admin profile** (`default` or `admin`) → Full S3 access
2. **Lab-student profile** (`lab-student`) → Limited EC2/ELB/Route53 access
3. Scripts automatically use correct profile
4. No manual switching needed!

**Commands:**

```bash
# One-time admin task (upload license)
./scripts/upload-license-to-s3.sh

# Lab deployment (uses lab-student)
export AWS_PROFILE=lab-student
./deployment/complete-build.sh --team 1

# Or let team config handle it
./deployment/01-deploy.sh --team 1  # Reads AWS_PROFILE from config
```

---

**Total setup time:** ~5 minutes

**Benefit:** Scripts "just work" without manual profile switching!

