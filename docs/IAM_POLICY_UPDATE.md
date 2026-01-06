# IAM Policy Update Instructions

## 🚨 Critical Issue: Students Unable to Launch EC2 Instances

**Symptom:** Student deployment scripts fail silently at Phase 3 (VM creation) with no error output before showing:
```
ℹ️  Using AMI: ami-092d9aa0e2874fd9c
ℹ️  Subnet: subnet-049c8d0a70c14dc65
ℹ️  Security Group: sg-041bfbf8b403c6d41
```

**Root Cause:** The `EC2InstanceTypeLimitation` statement in the IAM policy only allows `ec2:RunInstances` on `instance/*` resources, but AWS requires permissions for **all resource types** involved in launching an instance.

---

## 🔧 Fix: Update IAM Policy

### Step 1: Open AWS IAM Console

1. Go to AWS Console → IAM → Policies
2. Search for: `AppDynamicsLabStudentPolicy`
3. Click the policy name
4. Click **Edit** → **JSON**

### Step 2: Find and Replace the Statement

**FIND THIS** (lines 68-82):

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

**REPLACE WITH THIS:**

```json
{
  "Sid": "EC2RunInstancesWithTypeRestriction",
  "Effect": "Allow",
  "Action": "ec2:RunInstances",
  "Resource": [
    "arn:aws:ec2:us-west-2:*:instance/*",
    "arn:aws:ec2:us-west-2:*:volume/*",
    "arn:aws:ec2:us-west-2:*:network-interface/*",
    "arn:aws:ec2:us-west-2::image/*",
    "arn:aws:ec2:us-west-2:*:subnet/*",
    "arn:aws:ec2:us-west-2:*:security-group/*"
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

### Step 3: Save and Test

1. Click **Next** → **Save changes**
2. Wait 1-2 minutes for policy to propagate
3. Have a student retry: `./deployment/01-deploy.sh --team N`

---

## 📋 Complete Updated Policy

For reference, the complete updated policy is in: `docs/iam-student-policy.json`

To apply the entire policy:
1. Copy contents of `docs/iam-student-policy.json`
2. AWS Console → IAM → Policies → `AppDynamicsLabStudentPolicy`
3. Edit → JSON → Paste entire policy
4. Save changes

---

## 🔍 Why This Fix Works

### The Problem

When you call `ec2:RunInstances`, AWS checks IAM permissions for **every resource** involved:

| Resource Type | Used For | Old Policy | New Policy |
|---------------|----------|------------|------------|
| `instance/*` | The EC2 instance | ✅ Allowed | ✅ Allowed |
| `volume/*` | EBS volumes (OS + data disks) | ❌ Not allowed | ✅ Allowed |
| `network-interface/*` | ENI (for static IPs) | ❌ Not allowed | ✅ Allowed |
| `subnet/*` | VPC subnet | ❌ Not allowed | ✅ Allowed |
| `security-group/*` | Security group | ❌ Not allowed | ✅ Allowed |
| `image/*` | AMI | ❌ Not allowed | ✅ Allowed |

**Old policy:** Only allowed RunInstances on `instance/*` → AWS denied the request  
**New policy:** Allows RunInstances on all required resources → AWS allows the request

### Instance Type Restriction Still Enforced

The `Condition` block ensures students can only launch:
- `m5a.xlarge` (4 vCPU, 16 GB RAM)
- `m5a.2xlarge` (8 vCPU, 32 GB RAM)
- `m5a.4xlarge` (16 vCPU, 64 GB RAM) ← **Used by lab**
- `t3.2xlarge` (8 vCPU, 32 GB RAM) ← **Optional**

They **cannot** launch:
- Expensive instances (m5a.8xlarge, m5a.16xlarge, etc.)
- GPU instances (p3, p4, g5, etc.)
- High-memory instances (r6, x2, etc.)

---

## 🧪 How to Test (Before Updating)

### Reproduce the Issue

```bash
# As lab-student user:
aws ec2 run-instances \
  --image-id ami-092d9aa0e2874fd9c \
  --instance-type m5a.4xlarge \
  --subnet-id subnet-XXXXXXXXX \
  --security-group-ids sg-XXXXXXXXX

# Expected error:
# UnauthorizedOperation: You are not authorized to perform this operation.
```

### Verify the Fix

```bash
# After policy update:
./deployment/01-deploy.sh --team 5

# Should successfully create:
# ✅ ENI created: eni-XXXXXXXXX
# ✅ EIP allocated: eipalloc-XXXXXXXXX
# ✅ Instance launched: i-XXXXXXXXX
```

---

## 📚 Related AWS Documentation

- [Actions, resources, and condition keys for Amazon EC2](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html#amazonec2-resources-for-iam-policies)
- [Supported resource-level permissions for Amazon EC2 API actions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-supported-iam-actions-resources.html)
- [Launching an instance (RunInstances)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ExamplePolicies_EC2.html#iam-example-runinstances)

---

## 🔄 Rollback (If Needed)

If the new policy causes issues, revert to the original:

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

But note: Students will still be unable to launch instances with this version.

---

## ✅ Checklist

- [ ] Policy updated in AWS IAM console
- [ ] Policy saved successfully
- [ ] Waited 1-2 minutes for propagation
- [ ] Tested with `aws sts get-caller-identity` (verify using lab-student credentials)
- [ ] Had a student test `./deployment/01-deploy.sh --team N`
- [ ] Verified VMs launched successfully
- [ ] Notified students they can retry deployments

---

**Questions?** Contact infrastructure team or see `docs/IAM_REQUIREMENTS.md`





