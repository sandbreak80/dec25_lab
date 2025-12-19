# Silent Failure Root Cause & Fix

**Date:** December 17, 2025  
**Issue:** All deployment scripts failing silently on student laptops  
**Status:** ✅ FIXED

---

## The Problem

**Symptom:** Scripts would print a few lines then silently exit with no error:

```
ℹ️  Using AMI: ami-092d9aa0e2874fd9c
ℹ️  Subnet: subnet-049c8d0a70c14dc65
ℹ️  Security Group: sg-041bfbf8b403c6d41

[script exits - no error message]
```

This happened on **ALL** deployment scripts, not just VM creation.

---

## Root Cause

### 1. The AWS Profile Mismatch

**All config files specified:**
```bash
AWS_PROFILE="lab-student"
```

**But students only configured:**
```bash
# ~/.aws/credentials
[default]
aws_access_key_id = AKIA****************
aws_secret_access_key = ********************************
```

**Result:** AWS CLI tried to use `[lab-student]` profile which **doesn't exist** → ALL AWS commands failed.

### 2. Why It Was Silent

Three factors combined to hide the errors:

1. **`set -e`** in scripts → exit immediately on any error
2. **`2>/dev/null`** in helper functions → error output hidden
3. **Profile not found** → AWS CLI fails before any command runs

### 3. Why It Worked for Instructor

Instructor's laptop had **both** profiles:

```bash
# ~/.aws/credentials
[default]
aws_access_key_id = <admin-credentials>
aws_secret_access_key = <admin-secret>

[lab-student]
aws_access_key_id = AKIA****************
aws_secret_access_key = ********************************
```

So scripts worked perfectly on instructor machine, but failed on ALL student machines.

---

## The Fix

### Changes Made

1. **Changed all config files to use `default` profile:**
   ```bash
   # config/team1.cfg, team2.cfg, etc.
   AWS_PROFILE="default"  # ← Changed from "lab-student"
   ```

2. **Enhanced error detection in `lib/common.sh`:**
   - `check_aws_cli()` now captures and displays AWS errors
   - Detects "profile not found" errors
   - Shows helpful remediation steps
   - Displays which credentials are active

3. **Fixed `get_resource_id()` to show errors:**
   - Changed `2>/dev/null` to `2>&1` (capture errors)
   - Check exit codes
   - Display authentication/permission errors
   - Allow "resource not found" (empty result) without failing

---

## What Students Need to Do

### Option 1: Fresh Setup (Recommended)

Students just run standard AWS configure:

```bash
aws configure
# AWS Access Key ID: [from START_HERE.md]
# AWS Secret Access Key: [from START_HERE.md]
# Default region: us-west-2
# Default output format: json
```

This creates the `[default]` profile, which is what scripts now use.

### Option 2: Already Configured (Update Repo)

If students already have the repo cloned:

```bash
cd dec25_lab
git pull  # Get the updated config files
./scripts/test-aws-cli.sh  # Verify AWS is working
./deployment/01-deploy.sh --team N  # Should work now!
```

---

## Verification

Students can verify their AWS config works:

```bash
# Test AWS CLI directly:
aws sts get-caller-identity

# Should show:
# {
#   "UserId": "AIDAXXXXXXXXX",
#   "Account": "314839308236",
#   "Arn": "arn:aws:iam::314839308236:user/lab-student"
# }

# Or run our diagnostic script:
./scripts/test-aws-cli.sh
```

---

## Prevention

To prevent similar issues:

1. ✅ **Use `default` profile** - What students naturally configure
2. ✅ **Capture stderr** - Don't blindly redirect errors to /dev/null
3. ✅ **Validate early** - Check AWS config before running commands
4. ✅ **Show actual errors** - Display AWS CLI error messages
5. ✅ **Test on fresh machine** - Simulate student environment

---

## Summary

| Before | After |
|--------|-------|
| Scripts used `lab-student` profile | Scripts use `default` profile |
| Errors hidden (`2>/dev/null`) | Errors captured and displayed |
| Silent failures (`set -e` + no output) | Clear error messages with remediation |
| Profile issues not detected | Profile validation in `check_aws_cli()` |
| Students confused and stuck | Students see actionable error messages |

---

## Instructor Action

1. ✅ Pull latest code
2. ✅ Notify students to pull latest code
3. ✅ Students run `./scripts/test-aws-cli.sh` to verify
4. ✅ Students retry deployments

**No AWS IAM changes needed** - This was purely a local configuration issue.

---

**Root Cause:** AWS profile mismatch  
**Impact:** ALL scripts on ALL student machines  
**Fix:** Changed configs to use `default` profile + better error handling  
**Testing:** Required on fresh student laptop to verify

