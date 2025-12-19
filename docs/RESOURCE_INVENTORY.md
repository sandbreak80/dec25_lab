# AppDynamics Lab - Complete Resource Inventory

This document tracks ALL AWS resources created and deleted during lab deployment.

---

## 📊 Resources Created Per Team

### **Network Infrastructure (Phase 1: create-network.sh)**
| Resource | Quantity | Created By | Tags | Cleanup Phase |
|----------|----------|------------|------|---------------|
| VPC | 1 | `create-network.sh` | `Name`, `Team` | Phase 8 |
| Internet Gateway | 1 | `create-network.sh` | `Name`, `Team` | Phase 8 |
| Subnets | 3 | `create-network.sh` | `Name`, `Team` | Phase 8 |
| Route Table | 1 | `create-network.sh` | `Name`, `Team` | Phase 8 |
| Route Table Associations | 3 | `create-network.sh` | N/A | Phase 8 |

**CIDR Blocks:**
- VPC: `10.X.0.0/16` (where X = team number)
- Subnet 1: `10.X.0.0/24` (AZ: us-west-2a)
- Subnet 2: `10.X.1.0/24` (AZ: us-west-2b)
- Subnet 3: `10.X.2.0/24` (AZ: us-west-2c)

---

### **Security (Phase 2: create-security.sh)**
| Resource | Quantity | Created By | Tags | Cleanup Phase |
|----------|----------|------------|------|---------------|
| VM Security Group | 1 | `create-security.sh` | `Name`, `Team` | Phase 7 |
| ALB Security Group | 1 | `create-security.sh` | `Name`, `Team` | Phase 7 |

**Security Group Rules:**
- VM SG: Allows SSH (22), HTTPS (443), HTTP (8090), All traffic within VPC
- ALB SG: Allows HTTP (80), HTTPS (443) from internet

---

### **Compute (Phase 3: create-vms.sh)**
| Resource | Quantity | Created By | Tags | Cleanup Phase | Auto-Delete |
|----------|----------|------------|------|---------------|-------------|
| EC2 Instances (c5a.12xlarge) | 3 | `create-vms.sh` | `Name`, `Team` | Phase 5 | N/A |
| Elastic Network Interfaces | 3 | `create-vms.sh` | `Name`, `Team` | Phase 6 | No |
| Elastic IPs | 3 | `create-vms.sh` | `Name`, `Team` | Phase 5 | No |
| EBS OS Volumes (80GB gp3) | 3 | `create-vms.sh` | Auto-tagged | Phase 5 | **Yes** ✅ |
| EBS Data Volumes (500GB gp3) | 3 | `create-vms.sh` | Auto-tagged | Phase 5 | **NO** ❌ |

**⚠️ CRITICAL:** Data volumes (`/dev/sdb`) have `DeleteOnTermination=false` and MUST be explicitly deleted!

**Total Storage per Team:**
- OS Disks: 3 × 80GB = 240GB (auto-deleted)
- Data Disks: 3 × 500GB = **1,500GB** (requires explicit deletion)
- **Total: 1,740GB per team**

---

### **Load Balancing (Phase 4: create-alb.sh)**
| Resource | Quantity | Created By | Tags | Cleanup Phase |
|----------|----------|------------|------|---------------|
| Application Load Balancer | 1 | `create-alb.sh` | `Name` (via AWS) | Phase 3 |
| Target Group | 1 | `create-alb.sh` | N/A | Phase 4 |
| HTTPS Listener (443) | 1 | `create-alb.sh` | N/A | Phase 2 |
| HTTP Listener (80) | 1 | `create-alb.sh` | N/A | Phase 2 |

**Target Group Health Checks:**
- Protocol: HTTPS
- Port: 443
- Path: `/controller/rest/serverstatus`

---

### **DNS (Phase 5: create-dns.sh)**
| Resource | Quantity | Created By | Cleanup Phase |
|----------|----------|------------|---------------|
| Route 53 A Records (Alias) | 4 | `create-dns.sh` | Phase 1 |

**DNS Records Created:**
1. `controller-teamX.splunkylabs.com` → ALB
2. `customer1-teamX.auth.splunkylabs.com` → ALB
3. `customer1-tnt-authn-teamX.splunkylabs.com` → ALB
4. `*.teamX.splunkylabs.com` (wildcard) → ALB

---

## 🗑️ Cleanup Script Coverage

### **Current Cleanup Script Phases** (`deployment/cleanup.sh`)

| Phase | What's Deleted | Status |
|-------|----------------|--------|
| **1/10** | Route 53 DNS Records | ✅ Complete |
| **2/10** | ALB Listeners | ✅ Complete |
| **3/10** | Application Load Balancer | ✅ Complete |
| **4/10** | Target Groups | ✅ Complete |
| **5/10** | EC2 Instances + EBS Data Volumes | ✅ **FIXED!** |
| **6/10** | Network Interfaces (ENIs) | ✅ Complete |
| **7/10** | Security Groups | ✅ Complete |
| **8/10** | Network Infrastructure (VPC, IGW, Subnets, Routes) | ✅ Complete |
| **9/10** | Orphan Check (Volumes, EIPs, Snapshots) | ✅ **NEW!** |
| **10/10** | State Files | ✅ Complete |

---

## 💰 Cost Implications

### **Per Team Resource Costs (us-west-2 approximate)**

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| c5a.12xlarge (on-demand) | 3 | ~$1.848/hr | ~$3,996/mo |
| EBS gp3 (OS) | 240GB | $0.08/GB-mo | $19.20/mo |
| EBS gp3 (Data) | 1,500GB | $0.08/GB-mo | **$120/mo** |
| Elastic IPs | 3 | $3.60/mo ea | $10.80/mo |
| Application Load Balancer | 1 | ~$16.20/mo + usage | $20/mo |
| Data Transfer | Varies | $0.09/GB | Variable |
| **Total (if left running)** | | | **~$4,166/mo** |

**⚠️ If data volumes are orphaned:** 1,500GB × $0.08 = **$120/mo per team** in wasted storage!

---

## 🔍 Resource Verification Commands

### **Check for Orphaned Resources After Cleanup**

```bash
# Check for ANY resources tagged with Team
TEAM=1

# Orphaned VPCs
aws ec2 describe-vpcs --filters "Name=tag:Team,Values=team${TEAM}" --region us-west-2

# Orphaned EC2 Instances
aws ec2 describe-instances \
  --filters "Name=tag:Team,Values=team${TEAM}" "Name=instance-state-name,Values=running,stopped,pending" \
  --region us-west-2

# Orphaned EBS Volumes (MOST IMPORTANT!)
aws ec2 describe-volumes \
  --filters "Name=tag:Team,Values=team${TEAM}" \
  --query 'Volumes[*].[VolumeId,Size,State,Attachments[0].InstanceId]' \
  --output table \
  --region us-west-2

# Orphaned Elastic IPs
aws ec2 describe-addresses \
  --filters "Name=tag:Team,Values=team${TEAM}" \
  --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' \
  --output table \
  --region us-west-2

# Orphaned Load Balancers
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'team${TEAM}')].[LoadBalancerName,DNSName,State.Code]" \
  --output table \
  --region us-west-2

# Orphaned Target Groups
aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName, 'team${TEAM}')].[TargetGroupName,TargetGroupArn]" \
  --output table \
  --region us-west-2

# Orphaned Security Groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Team,Values=team${TEAM}" \
  --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' \
  --output table \
  --region us-west-2

# Orphaned Snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Team,Values=team${TEAM}" \
  --query 'Snapshots[*].[SnapshotId,VolumeSize,StartTime]' \
  --output table \
  --region us-west-2
```

### **Get Total Resource Count Across All Teams**

```bash
#!/bin/bash
# Check all teams for any remaining resources

echo "=== Resource Summary Across All Teams ==="
for team in 1 2 3 4 5; do
    echo ""
    echo "Team $team:"
    
    # VPCs
    vpc_count=$(aws ec2 describe-vpcs --filters "Name=tag:Team,Values=team${team}" --region us-west-2 --query 'length(Vpcs)' --output text 2>/dev/null || echo 0)
    echo "  VPCs: $vpc_count"
    
    # Instances
    inst_count=$(aws ec2 describe-instances --filters "Name=tag:Team,Values=team${team}" "Name=instance-state-name,Values=running,stopped,pending" --region us-west-2 --query 'length(Reservations[*].Instances[])' --output text 2>/dev/null || echo 0)
    echo "  Instances: $inst_count"
    
    # Volumes
    vol_count=$(aws ec2 describe-volumes --filters "Name=tag:Team,Values=team${team}" --region us-west-2 --query 'length(Volumes)' --output text 2>/dev/null || echo 0)
    echo "  Volumes: $vol_count"
    
    # EIPs
    eip_count=$(aws ec2 describe-addresses --filters "Name=tag:Team,Values=team${team}" --region us-west-2 --query 'length(Addresses)' --output text 2>/dev/null || echo 0)
    echo "  EIPs: $eip_count"
done
```

---

## 📝 State Files Tracking

The `state/teamX/` directory contains resource IDs for cleanup:

```
state/
└── teamX/
    ├── vpc.id              # VPC ID
    ├── igw.id              # Internet Gateway ID
    ├── subnet.id           # Subnet 1 ID
    ├── subnet2.id          # Subnet 2 ID
    ├── rt.id               # Route Table ID
    ├── vm-sg.id            # VM Security Group ID
    ├── alb-sg.id           # ALB Security Group ID
    ├── vm1.id              # Instance 1 ID
    ├── vm2.id              # Instance 2 ID
    ├── vm3.id              # Instance 3 ID
    ├── alb.arn             # ALB ARN
    ├── tg.arn              # Target Group ARN
    ├── alb-dns.txt         # ALB DNS name
    └── alb-zone.txt        # ALB Hosted Zone ID
```

**Important:** State files are deleted in Phase 10, so they should be used for cleanup lookups in earlier phases.

---

## ✅ Cleanup Script Enhancements (Latest Version)

### **What Was Fixed:**

1. **EBS Data Volume Deletion** (CRITICAL)
   - Captures volume IDs BEFORE instance termination
   - Explicitly deletes data volumes with `DeleteOnTermination=false`
   - Prevents 1.5TB of orphaned storage per team

2. **Orphan Check Phase**
   - Scans for orphaned EBS volumes by Team tag
   - Scans for orphaned Elastic IPs by Team tag
   - Scans for orphaned EBS snapshots by Team tag
   - Automatically cleans up anything found

3. **VPC Deletion Retry Logic**
   - Retries VPC deletion up to 10 times with 10-second delays
   - Properly handles dependency errors
   - Reports clear errors if VPC cannot be deleted

4. **Security Group Rule Revocation**
   - Revokes all ingress/egress rules before deletion
   - Handles circular dependencies between security groups
   - Uses `jq` to parse and revoke rules individually

---

## 🎯 Best Practices

### **For Instructors:**

1. **Always run cleanup script after labs:**
   ```bash
   ./deployment/cleanup.sh --team X --confirm
   ```

2. **Verify cleanup completed:**
   ```bash
   # Check for orphaned volumes (most expensive)
   aws ec2 describe-volumes --filters "Name=tag:Team,Values=team1" --region us-west-2
   ```

3. **Monitor AWS costs:**
   - Set up billing alerts for unexpected charges
   - Check for orphaned resources weekly
   - Use AWS Cost Explorer to track EBS volume costs

### **For Students:**

1. **Always use the cleanup script** - don't manually delete resources
2. **Wait for cleanup to complete** - don't interrupt the script
3. **Check for "CLEANUP COMPLETE" message** before considering cleanup done
4. **Report any errors** to instructors if cleanup fails

---

## 🚨 Emergency Cleanup

If the normal cleanup script fails, use the orphaned VPC cleanup script:

```bash
./scripts/cleanup-orphaned-vpcs.sh
```

This script will:
- Find ALL VPCs by Team tag
- Delete all associated resources in the correct order
- Retry VPC deletion until successful
- Clean up orphaned EIPs

---

## 📊 Deployment Timeline

Typical deployment times per phase:

| Phase | Script | Duration |
|-------|--------|----------|
| 1 | Network | ~2 minutes |
| 2 | Security | ~30 seconds |
| 3 | VMs | ~5 minutes |
| 4 | ALB | ~3 minutes |
| 5 | DNS | ~30 seconds |
| 6 | Bootstrap | ~20-25 minutes |
| 7 | Cluster | ~10 minutes |
| 8 | Configure | ~1 minute |
| 9 | Install AppD | ~25-30 minutes |
| 10 | License | ~2 minutes |
| **Total** | | **~70-80 minutes** |

**Cleanup Duration:** ~5-10 minutes

---

## 🔒 IAM Permissions Required

The cleanup script requires these IAM permissions:

- `ec2:DescribeInstances`, `ec2:TerminateInstances`
- `ec2:DescribeVolumes`, `ec2:DeleteVolume`
- `ec2:DescribeAddresses`, `ec2:ReleaseAddress`
- `ec2:DescribeSnapshots`, `ec2:DeleteSnapshot`
- `ec2:DescribeNetworkInterfaces`, `ec2:DeleteNetworkInterface`
- `ec2:DescribeSecurityGroups`, `ec2:DeleteSecurityGroup`, `ec2:RevokeSecurityGroupIngress`, `ec2:RevokeSecurityGroupEgress`
- `ec2:DescribeVpcs`, `ec2:DeleteVpc`
- `ec2:DescribeSubnets`, `ec2:DeleteSubnet`
- `ec2:DescribeInternetGateways`, `ec2:DetachInternetGateway`, `ec2:DeleteInternetGateway`
- `ec2:DescribeRouteTables`, `ec2:DisassociateRouteTable`, `ec2:DeleteRouteTable`
- `elasticloadbalancing:DescribeLoadBalancers`, `elasticloadbalancing:DeleteLoadBalancer`
- `elasticloadbalancing:DescribeListeners`, `elasticloadbalancing:DeleteListener`
- `elasticloadbalancing:DescribeTargetGroups`, `elasticloadbalancing:DeleteTargetGroup`
- `route53:ChangeResourceRecordSets`

See `docs/iam-student-policy.json` for complete policy.

---

## 📚 Related Documentation

- [IAM Requirements](IAM_REQUIREMENTS.md) - Required AWS permissions
- [LICENSE Management](LICENSE_MANAGEMENT.md) - License setup and distribution
- [AWS Profile Setup](../AWS_PROFILE_SETUP.md) - Multiple profile configuration

---

**Last Updated:** December 16, 2025
**Version:** 1.0
**Maintainer:** Lab Infrastructure Team




