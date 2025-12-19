# IAM Permission Fix for VM Deployment

**Date:** December 17, 2025  
**Issue:** Students unable to create EC2 instances (Phase 3 fails silently)  
**Severity:** CRITICAL - Blocks all lab deployments

---

## Problem

Students were experiencing silent failures when running `./deployment/01-deploy.sh` at **Phase 3: Virtual Machines**. The script would show:

```
ℹ️  Using AMI: ami-092d9aa0e2874fd9c
ℹ️  Subnet: subnet-049c8d0a70c14dc65
ℹ️  Security Group: sg-041bfbf8b403c6d41
```

Then immediately exit with no error message.

---

## Root Cause

The `lab-student` IAM policy had **insufficient permissions** for `ec2:RunInstances`.

### Original (Broken) Policy

```json
{
  "Sid": "EC2InstanceTypeLimitation",
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": "arn:aws:ec2:us-west-2:*:instance/*",
  "Condition": {
    "StringEquals": {
      "ec2:InstanceType": [
        "m5a.xlarge",
        "m5a.2xlarge",
        "m5a.4xlarge"
      ]
    }
  }
}
```

**Why This Failed:**

The `ec2:RunInstances` action requires permissions on **multiple AWS resource types**, not just `instance/*`:

- ✅ `instance/*` - for the EC2 instance itself
- ❌ `volume/*` - for EBS volumes (OS disk + data disk)
- ❌ `network-interface/*` - for ENI attachment
- ❌ `subnet/*` - for subnet placement
- ❌ `security-group/*` - for security group association
- ❌ `image/*` - for AMI access

Because the policy only granted permission on `instance/*`, AWS **implicitly denied** all other required resources, causing the `RunInstances` call to fail silently.

---

## Solution

### Updated (Fixed) Policy

```json
{
  "Sid": "EC2RunInstancesWithTypeRestriction",
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": [
    "arn:aws:ec2:us-west-2:*:instance/*",
    "arn:aws:ec2:us-west-2:*:volume/*",
    "arn:aws:ec2:us-west-2:*:network-interface/*",
    "arn:aws:ec2:us-west-2:*:subnet/*",
    "arn:aws:ec2:us-west-2:*:security-group/*",
    "arn:aws:ec2:*:image/*"
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

### Additional Permissions Added

Also added missing permissions for volume and snapshot management:

```json
"ec2:CreateVolume",
"ec2:DeleteVolume",
"ec2:CreateSnapshot",
"ec2:DeleteSnapshot",
"ec2:DescribeSnapshots",
"ec2:DescribeVpcAttribute"
```

---

## How to Apply the Fix

### Step 1: Update the IAM Policy in AWS

```bash
# 1. Log into AWS Console as admin
# 2. Go to IAM → Policies → AppDynamicsLabStudentPolicy
# 3. Edit the policy
# 4. Replace the entire JSON with the updated policy from:
#    docs/iam-student-policy.json
# 5. Click "Review policy" → "Save changes"
```

### Step 2: Verify the Fix

```bash
# As a student (using lab-student credentials):
aws ec2 run-instances \
  --dry-run \
  --image-id ami-092d9aa0e2874fd9c \
  --instance-type m5a.4xlarge \
  --subnet-id <your-subnet-id> \
  --security-group-ids <your-sg-id>

# Expected output:
# An error occurred (DryRunOperation) when calling the RunInstances operation:
# Request would have succeeded, but DryRun flag is set.

# If you see "UnauthorizedOperation" → policy not updated correctly
```

### Step 3: Test with Students

```bash
# Student runs:
./deployment/01-deploy.sh --team 5

# Should now successfully create 3 VMs in Phase 3
```

---

## Why This Was Hard to Diagnose

1. **Silent Failure**: The script uses `set -e`, which exits immediately on any error. The AWS CLI failure had no visible output.

2. **Works for Admin**: Instructors using admin credentials have `ec2:*` permissions, so they never hit this issue.

3. **Implicit Deny**: AWS doesn't explicitly say "you're missing volume permissions" - it just returns `UnauthorizedOperation` for the entire `RunInstances` call.

4. **Misleading Success**: Phases 1-2 completed successfully, making it seem like the issue was with Phase 3 specifically, rather than a permissions problem.

---

## Prevention

To avoid similar issues in the future:

1. **Test with Restricted Credentials**: Always test deployment scripts using the `lab-student` IAM user, not admin credentials.

2. **Better Error Handling**: The script has been updated to validate prerequisites and show clear error messages.

3. **Diagnostic Tools**: New script `./scripts/check-deployment-state.sh` helps diagnose resource/permission issues.

4. **Resource-Level IAM Testing**: For any AWS action with resource-level permissions, explicitly test all required resource types.

---

## References

- [AWS EC2 RunInstances Required Permissions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ExamplePolicies_EC2.html#iam-example-runinstances)
- [IAM Policy Evaluation Logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)
- Updated Policy: `docs/iam-student-policy.json`

---

## Checklist for Instructor

- [ ] Update IAM policy in AWS Console
- [ ] Test with `lab-student` credentials
- [ ] Notify students of the fix
- [ ] Verify existing deployments still work
- [ ] Update `START_HERE.html` if needed

---

**Status:** ✅ Fixed  
**Testing:** Required - Instructor must update IAM policy in AWS Console  
**Impact:** HIGH - Unblocks all student deployments




