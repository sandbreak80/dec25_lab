# IAM Requirements for AppDynamics Lab

## Overview

This document specifies the **minimum AWS IAM permissions** required for students to deploy and manage their AppDynamics lab environment. These permissions are significantly more restrictive than `AdministratorAccess` while still allowing full lab functionality.

---

## Quick Start

### For Instructors

**Option 1: Use the provided IAM policy** (Recommended)
```bash
# Create IAM policy from JSON file
aws iam create-policy \
  --policy-name AppDynamicsLabStudentPolicy \
  --policy-document file://iam-student-policy.json \
  --description "Restricted permissions for AppDynamics lab students"

# Attach policy to student user/group
aws iam attach-user-policy \
  --user-name student-username \
  --policy-arn arn:aws:iam::ACCOUNT-ID:policy/AppDynamicsLabStudentPolicy
```

**Option 2: Create inline policy for student users**
```bash
# Copy contents of iam-student-policy.json and attach directly
aws iam put-user-policy \
  --user-name student-username \
  --policy-name AppDynamicsLabAccess \
  --policy-document file://iam-student-policy.json
```

### For Students

**After receiving credentials:**
```bash
# Configure AWS CLI with your restricted credentials
aws configure
# Enter Access Key ID and Secret Access Key provided by instructor

# Verify access
aws sts get-caller-identity

# Check prerequisites
./scripts/check-prerequisites.sh

# Deploy lab
./lab-deploy.sh --team 1
```

---

## Permissions Breakdown

### 1. EC2 (Compute & Networking) - **Required**

**Why:** Create and manage VMs, networking, and storage

**Permissions:**
- **VPC Management:**
  - `ec2:CreateVpc`, `ec2:DeleteVpc`
  - `ec2:DescribeVpcs`
  - `ec2:ModifyVpcAttribute`
  - `ec2:CreateTags` (for resource tagging)

- **Subnet Management:**
  - `ec2:CreateSubnet`, `ec2:DeleteSubnet`
  - `ec2:DescribeSubnets`
  - `ec2:DescribeAvailabilityZones`

- **Internet Gateway:**
  - `ec2:CreateInternetGateway`, `ec2:DeleteInternetGateway`
  - `ec2:AttachInternetGateway`, `ec2:DetachInternetGateway`
  - `ec2:DescribeInternetGateways`

- **Route Tables:**
  - `ec2:CreateRouteTable`, `ec2:DeleteRouteTable`
  - `ec2:CreateRoute`, `ec2:DeleteRoute`
  - `ec2:AssociateRouteTable`, `ec2:DisassociateRouteTable`
  - `ec2:DescribeRouteTables`

- **Security Groups:**
  - `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`
  - `ec2:AuthorizeSecurityGroupIngress`, `ec2:RevokeSecurityGroupIngress`
  - `ec2:AuthorizeSecurityGroupEgress`, `ec2:RevokeSecurityGroupEgress`
  - `ec2:DescribeSecurityGroups`, `ec2:DescribeSecurityGroupRules`

- **EC2 Instances:**
  - `ec2:RunInstances` (create VMs)
  - `ec2:TerminateInstances` (delete VMs)
  - `ec2:DescribeInstances`, `ec2:DescribeInstanceStatus`
  - `ec2:StartInstances`, `ec2:StopInstances` (optional, for cost savings)
  - `ec2:DescribeImages` (to find AMI)
  - `ec2:DescribeVolumes` (for disk management)

- **Elastic Network Interfaces (ENI):**
  - `ec2:CreateNetworkInterface`, `ec2:DeleteNetworkInterface`
  - `ec2:DescribeNetworkInterfaces`
  - `ec2:AttachNetworkInterface`, `ec2:DetachNetworkInterface`

- **Elastic IPs:**
  - `ec2:AllocateAddress`, `ec2:ReleaseAddress`
  - `ec2:AssociateAddress`, `ec2:DisassociateAddress`
  - `ec2:DescribeAddresses`

- **Key Pairs (if using EC2 key pairs):**
  - `ec2:CreateKeyPair`, `ec2:DeleteKeyPair`
  - `ec2:DescribeKeyPairs`

**Used in:** `create-network.sh`, `create-security.sh`, `create-vms.sh`, `lab-cleanup.sh`

---

### 2. Elastic Load Balancing - **Required**

**Why:** Create Application Load Balancer for HTTPS access

**Permissions:**
- **Load Balancers:**
  - `elasticloadbalancing:CreateLoadBalancer`
  - `elasticloadbalancing:DeleteLoadBalancer`
  - `elasticloadbalancing:DescribeLoadBalancers`
  - `elasticloadbalancing:ModifyLoadBalancerAttributes`
  - `elasticloadbalancing:SetSecurityGroups`

- **Target Groups:**
  - `elasticloadbalancing:CreateTargetGroup`
  - `elasticloadbalancing:DeleteTargetGroup`
  - `elasticloadbalancing:DescribeTargetGroups`
  - `elasticloadbalancing:RegisterTargets`
  - `elasticloadbalancing:DeregisterTargets`
  - `elasticloadbalancing:DescribeTargetHealth`

- **Listeners:**
  - `elasticloadbalancing:CreateListener`
  - `elasticloadbalancing:DeleteListener`
  - `elasticloadbalancing:DescribeListeners`
  - `elasticloadbalancing:ModifyListener`

- **Tags:**
  - `elasticloadbalancing:AddTags`
  - `elasticloadbalancing:RemoveTags`

**Used in:** `create-alb.sh`, `lab-cleanup.sh`

---

### 3. Route 53 (DNS) - **Required**

**Why:** Create DNS records for team-specific URLs

**Permissions:**
- **Hosted Zones:**
  - `route53:GetHostedZone`
  - `route53:ListHostedZones`
  - `route53:ListHostedZonesByName`

- **Record Sets:**
  - `route53:ChangeResourceRecordSets` (create/update/delete DNS records)
  - `route53:ListResourceRecordSets`
  - `route53:GetChange` (check change status)

**Note:** Students do NOT need permission to create/delete hosted zones (instructor pre-creates `splunkylabs.com`)

**Used in:** `create-dns.sh`, `lab-cleanup.sh`

---

### 4. AWS Certificate Manager (ACM) - **Read-Only**

**Why:** Use existing wildcard certificate for ALB

**Permissions:**
- `acm:ListCertificates` (find certificate)
- `acm:DescribeCertificate` (get certificate ARN)

**Note:** Students do NOT need permission to request/delete certificates (instructor pre-creates `*.splunkylabs.com`)

**Used in:** `create-alb.sh`

---

### 5. IAM - **Very Limited**

**Why:** Query own identity for verification

**Permissions:**
- `iam:GetUser` (get own user info)
- `sts:GetCallerIdentity` (verify credentials)

**Note:** Students do NOT need permission to create/modify IAM roles or policies

**Used in:** `scripts/check-prerequisites.sh`

---

## Resource Restrictions

### Recommended Conditions

To further restrict student access, add these conditions to the IAM policy:

#### 1. Region Restriction
Limit to `us-west-2` only:
```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": "us-west-2"
  }
}
```

#### 2. Resource Tagging
Require all resources to be tagged with team identifier:
```json
"Condition": {
  "StringEquals": {
    "aws:RequestTag/ManagedBy": "AppDynamicsLab"
  }
}
```

#### 3. Instance Type Restriction
Limit to specific instance types:
```json
"Condition": {
  "StringEquals": {
    "ec2:InstanceType": [
      "m5a.xlarge",
      "m5a.2xlarge",
      "m5a.4xlarge"
    ]
  }
}
```

---

## Cost Controls

### Recommended Limits

**Service Quotas** (set per student):
- **EC2 Instances:** 3 (exactly what's needed)
- **Elastic IPs:** 3
- **VPCs:** 1
- **Security Groups per VPC:** 5

**Billing Alerts:**
```bash
# Create billing alarm for $30/day per student
aws cloudwatch put-metric-alarm \
  --alarm-name "student-username-spending" \
  --alarm-description "Alert if student spending exceeds $30/day" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 30 \
  --comparison-operator GreaterThanThreshold
```

---

## Security Best Practices

### For Instructors

1. **Rotate Student Credentials:**
   - Generate temporary access keys
   - Set expiration (e.g., 7 days after lab)
   - Use `aws iam update-access-key --status Inactive` after lab

2. **Use IAM Groups:**
   ```bash
   # Create group once
   aws iam create-group --group-name AppDynamicsLabStudents
   
   # Attach policy to group
   aws iam attach-group-policy \
     --group-name AppDynamicsLabStudents \
     --policy-arn arn:aws:iam::ACCOUNT-ID:policy/AppDynamicsLabStudentPolicy
   
   # Add students to group
   aws iam add-user-to-group \
     --user-name student1 \
     --group-name AppDynamicsLabStudents
   ```

3. **Monitor Usage:**
   ```bash
   # Check what students are creating
   aws ec2 describe-instances \
     --filters "Name=tag:ManagedBy,Values=AppDynamicsLab" \
     --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]'
   ```

4. **Enforce Cleanup:**
   - Require students to run `./lab-cleanup.sh` after lab
   - Run automated cleanup script nightly to delete abandoned resources
   - Use AWS Config rules to detect non-compliant resources

### For Students

1. **Protect Your Credentials:**
   - Never commit access keys to Git
   - Use `aws configure` (stores in `~/.aws/credentials`)
   - Never share access keys with classmates

2. **Clean Up Resources:**
   ```bash
   # Always run cleanup after lab
   ./lab-cleanup.sh --team N --confirm
   
   # Verify cleanup succeeded
   aws ec2 describe-instances --filters "Name=tag:Team,Values=teamN"
   ```

3. **Monitor Your Costs:**
   ```bash
   # Check current month spending
   aws ce get-cost-and-usage \
     --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics BlendedCost
   ```

---

## What Students CANNOT Do

With these restricted permissions, students **cannot:**

❌ Create/modify IAM users, roles, or policies  
❌ Access other AWS accounts  
❌ Create resources in other regions (if region restriction applied)  
❌ Launch unapproved instance types (if instance restriction applied)  
❌ Access S3 buckets (unless explicitly granted)  
❌ Use AWS Lambda, ECS, or other services  
❌ Create or modify ACM certificates  
❌ Create or delete Route 53 hosted zones  
❌ View/modify billing information  
❌ Access AWS Organizations  
❌ Modify account settings  

---

## Troubleshooting Permission Issues

### Common Error Messages

**Error:** `You are not authorized to perform this operation`

**Solution:** Check which operation failed and verify the permission is in the policy.

**Error:** `User: arn:aws:iam::XXX:user/student1 is not authorized to perform: ec2:RunInstances`

**Solution:** Missing EC2 RunInstances permission. Instructor needs to update policy.

**Error:** `Cannot create VPC: quota exceeded`

**Solution:** Student already has a VPC. Run cleanup first: `./lab-cleanup.sh --team N --confirm`

### Verification Command

Students can verify their permissions:
```bash
# Check if you can describe EC2 instances
aws ec2 describe-instances

# Check if you can list VPCs
aws ec2 describe-vpcs

# Check if you can list load balancers
aws elbv2 describe-load-balancers

# Check Route 53 access
aws route53 list-hosted-zones
```

---

## Summary

**Minimum Permissions Required:**
- ✅ EC2: Full control (within restrictions)
- ✅ ELB: Full control for ALB
- ✅ Route 53: Record management only
- ✅ ACM: Read-only (use existing certs)
- ✅ IAM/STS: Identity verification only

**Security Posture:**
- 🔒 No IAM admin access
- 🔒 No billing access
- 🔒 No cross-region access (optional)
- 🔒 Limited instance types (optional)
- 🔒 Resource tagging enforced (optional)

**Cost Controls:**
- 💰 Service quotas per student
- 💰 Billing alarms
- 💰 Automatic cleanup policies

---

## Next Steps

1. Review `iam-student-policy.json` file
2. Adjust conditions as needed for your organization
3. Create IAM policy in AWS
4. Create student IAM users or group
5. Attach policy to users/group
6. Provide students with access keys
7. Have students run `./scripts/check-prerequisites.sh`
8. Monitor usage and costs

---

## Policy File Location

The complete IAM policy JSON is in: `iam-student-policy.json`

Apply it with:
```bash
aws iam create-policy \
  --policy-name AppDynamicsLabStudentPolicy \
  --policy-document file://iam-student-policy.json
```

---

**Questions?** Contact your instructor or see AWS IAM documentation:
https://docs.aws.amazon.com/IAM/latest/UserGuide/
