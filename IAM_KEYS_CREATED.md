# ✅ IAM Access Keys Created Successfully

**Date:** December 19, 2025  
**Status:** COMPLETE

---

## Summary

✅ **IAM user exists:** lab-student  
✅ **IAM policy attached:** AppDynamicsLabStudentPolicy  
✅ **New access keys created and tested**  
✅ **Credentials file created:** STUDENT_AWS_CREDENTIALS.txt (local only)  
✅ **Security configured:** Credentials file added to .gitignore  

**Status:** Ready to distribute to students!

---

## What Was Completed

1. **IAM User:** lab-student (already existed)
2. **IAM Policy:** AppDynamicsLabStudentPolicy (already attached as managed policy)
3. **Access Keys:** New active access keys generated
4. **Testing:** Authentication and EC2 permissions verified
5. **Documentation:** Student credentials document created

---

## Verification Results

### Authentication Test ✅
- Command: `aws sts get-caller-identity`
- Result: PASSED
- User ARN: arn:aws:iam::314839308236:user/lab-student

### EC2 Permissions Test ✅
- Command: `aws ec2 run-instances --dry-run`
- Result: PASSED (DryRunOperation = correct permissions)
- Can create m5a.xlarge, m5a.2xlarge, m5a.4xlarge, t3.2xlarge instances

---

## Files Created

### Local Files (NOT in Git - Contains Sensitive Data)
- **STUDENT_AWS_CREDENTIALS.txt** - Complete credentials with access keys
  - Location: `/Users/bmstoner/code_projects/dec25_lab/STUDENT_AWS_CREDENTIALS.txt`
  - Contains: Access Key ID, Secret Access Key, setup instructions
  - Status: Added to .gitignore for security

### In Git Repository
- **.gitignore** - Updated to exclude credentials file
- **IAM_ACCESS_KEY_CREATION_GUIDE.md** - How to create access keys
- **IAM_POLICY_APPLY_GUIDE.md** - How to apply IAM policy
- **docs/iam-student-policy.json** - The IAM policy

---

## Distribution Instructions

The credentials are in: `STUDENT_AWS_CREDENTIALS.txt`

**Secure Distribution Options:**

1. **Via LMS:** Upload to Canvas/Moodle (students only)
2. **Via Encrypted ZIP:** `zip -e student-creds.zip STUDENT_AWS_CREDENTIALS.txt`
3. **In-Person:** Print and distribute during lab

**⚠️ NEVER:**
- Commit credentials to git
- Email unencrypted
- Post publicly

---

## Student Setup (What They Do)

```bash
# 1. Configure AWS
aws configure
# Enter credentials from STUDENT_AWS_CREDENTIALS.txt

# 2. Verify
aws sts get-caller-identity

# 3. Clone repo
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# 4. Deploy
./deployment/01-deploy.sh --team N
```

---

## Post-Lab Cleanup

After lab session:

```bash
# Deactivate keys (reusable)
aws iam update-access-key --user-name lab-student --access-key-id AKIA... --status Inactive

# OR delete keys (more secure)
aws iam delete-access-key --user-name lab-student --access-key-id AKIA...
```

---

## Access Key Details

**⚠️ Actual credentials are in:** `STUDENT_AWS_CREDENTIALS.txt` (local file only)

- Created: December 19, 2025 11:25:46 UTC
- Status: Active
- Region: us-west-2
- Account: 314839308236
- Expires: January 31, 2026 (set expiration)

---

## Security Configured

✅ Credentials NOT in git repository  
✅ Added to .gitignore  
✅ GitHub push protection active  
✅ Limited permissions (students can't create IAM users)  
✅ Region restricted (us-west-2 only)  
✅ Instance type restricted (approved types only)  

---

## Next Steps

1. **Review** `STUDENT_AWS_CREDENTIALS.txt` for any customization
2. **Choose** distribution method (LMS recommended)
3. **Distribute** to students before lab session
4. **Monitor** CloudTrail for student activity
5. **Deactivate** keys after lab session ends

---

**Created by:** Lab Administrator  
**Valid Until:** January 31, 2026  
**IAM Policy:** docs/iam-student-policy.json  
**Full Guide:** IAM_ACCESS_KEY_CREATION_GUIDE.md
