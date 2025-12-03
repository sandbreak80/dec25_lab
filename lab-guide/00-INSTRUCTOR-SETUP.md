# Instructor Setup Guide
## AppDynamics Virtual Appliance - Multi-Team Lab

---

## 📋 Prerequisites

- AWS Account with sufficient permissions
- AWS CLI configured
- Domain name (we're using `splunkylabs.com`)
- This repository cloned
- 20 students organized into 5 teams of 4

---

## 🎯 Lab Overview

**Objective:** 5 teams of students will each build a complete AppDynamics Virtual Appliance deployment in AWS.

**Duration:** 8 hours (full day lab)

**Cost:** ~$95 for 8-hour lab (all 5 teams)

**Outcomes:** Students learn AWS networking, load balancing, SSL/TLS, Kubernetes, and AppDynamics deployment.

---

## 🏗️ Pre-Lab Setup (Day Before)

### Step 1: Domain & DNS Setup

```bash
# 1. Verify domain ownership
aws route53 list-hosted-zones --query 'HostedZones[?Name==`splunkylabs.com.`]'

# Should show:
# {
#   "Id": "/hostedzone/Z06491142QTF1FNN8O9PR",
#   "Name": "splunkylabs.com."
# }

# 2. Request single wildcard ACM certificate
export CERT_ARN=$(aws acm request-certificate \
  --domain-name "splunkylabs.com" \
  --subject-alternative-names "*.splunkylabs.com" "*.team1.splunkylabs.com" "*.team2.splunkylabs.com" "*.team3.splunkylabs.com" "*.team4.splunkylabs.com" "*.team5.splunkylabs.com" \
  --validation-method DNS \
  --region us-west-2 \
  --query 'CertificateArn' --output text)

echo "Certificate ARN: $CERT_ARN"

# 3. Get DNS validation records
aws acm describe-certificate --certificate-arn $CERT_ARN --region us-west-2

# 4. Add CNAME validation records to Route 53
# (See output from previous command)

# 5. Wait for certificate validation (5-10 minutes)
aws acm wait certificate-validated --certificate-arn $CERT_ARN --region us-west-2
```

### Step 2: Create IAM Users for Teams

```bash
# Create 5 IAM users (one per team)
for team in {1..5}; do
  echo "Creating user for Team $team..."
  
  aws iam create-user --user-name "appd-lab-team${team}"
  
  # Create access key
  aws iam create-access-key --user-name "appd-lab-team${team}" > "credentials/team${team}-credentials.json"
  
  # Attach policy (scoped to team resources)
  aws iam attach-user-policy \
    --user-name "appd-lab-team${team}" \
    --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"  # Or use custom policy
done

echo "✅ Created 5 team IAM users"
```

**OR** use IAM Roles with temporary credentials (more secure):

```bash
# Create IAM role for students
aws iam create-role \
  --role-name AppDLab-StudentRole \
  --assume-role-policy-document file://policies/student-trust-policy.json

# Attach permissions
aws iam attach-role-policy \
  --role-name AppDLab-StudentRole \
  --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"
```

### Step 3: Upload Shared AMI

```bash
# Create shared S3 bucket for AMI
aws s3 mb s3://appd-lab-shared-ami --region us-west-2

# Upload AMI (one time, all teams use it)
aws s3 cp appd_va_25.4.0.2016.ami s3://appd-lab-shared-ami/ --region us-west-2

# Set permissions (all team users can read)
aws s3api put-object-acl \
  --bucket appd-lab-shared-ami \
  --key appd_va_25.4.0.2016.ami \
  --grant-read uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers

echo "✅ Shared AMI uploaded"
```

### Step 4: Verify Team Configurations

```bash
# Check all team config files exist
ls -l config/team*.cfg

# Should show:
# config/team1.cfg
# config/team2.cfg
# config/team3.cfg
# config/team4.cfg
# config/team5.cfg

# Verify each config is valid
for team in {1..5}; do
  echo "Checking Team $team config..."
  source config/team${team}.cfg
  echo "  VPC: $VPC_NAME ($VPC_CIDR)"
  echo "  Domain: $FULL_DOMAIN"
  echo "  ALB: $ALB_NAME"
  echo ""
done
```

### Step 5: Create Monitoring Dashboard (Optional)

```bash
# Create CloudWatch dashboard to monitor all teams
./instructor/create-monitoring-dashboard.sh
```

### Step 6: Prepare Student Materials

```bash
# Package lab materials for students
./instructor/package-student-materials.sh

# Output:
# - lab-materials-team1.zip
# - lab-materials-team2.zip
# - lab-materials-team3.zip
# - lab-materials-team4.zip
# - lab-materials-team5.zip

# Each package contains:
#   - Team-specific config file
#   - Lab guide
#   - All scripts
#   - AWS credentials
```

---

## 📅 Lab Day Activities

### Morning: Team Setup (8:00 AM - 10:00 AM)

**Instructor Tasks:**
1. Distribute credentials to teams
2. Verify all teams can log in to AWS
3. Brief overview presentation (30 minutes)
4. Teams begin lab guide

**Student Tasks:**
- Log in to AWS Console
- Configure AWS CLI
- Verify access to shared AMI bucket
- Begin network setup (VPC, subnets)

### Mid-Morning: VM Deployment (10:00 AM - 12:00 PM)

**Monitor:**
```bash
# Check progress of all teams
./instructor/monitor-all-teams.sh

# Expected output:
# Team 1: ✅ VPC Created | ⏳ VMs Deploying
# Team 2: ✅ VPC Created | ✅ VMs Running
# Team 3: ✅ VPC Created | ⏳ VMs Deploying
# Team 4: ⏳ VPC Creating | ⚠️ Subnet Issue
# Team 5: ✅ VPC Created | ✅ VMs Running
```

**Troubleshooting:**
- If Team 4 has subnet issue, assist with debugging
- Common issues: CIDR conflicts, quota limits

### Afternoon: Load Balancer & SSL (1:00 PM - 3:00 PM)

**Critical Section:**
- ALB creation
- ACM certificate attachment
- DNS configuration
- SSL verification

**Monitor:**
```bash
./instructor/monitor-all-teams.sh

# Expected output:
# Team 1: ✅ ALB Created | ✅ HTTPS Working
# Team 2: ✅ ALB Created | ⏳ DNS Propagating
# Team 3: ✅ ALB Created | ✅ HTTPS Working
# Team 4: ✅ ALB Created | ❌ Health Check Failing
# Team 5: ⏳ ALB Creating
```

### Late Afternoon: AppDynamics Installation (3:00 PM - 5:00 PM)

**Students:**
- Bootstrap VMs
- Create Kubernetes cluster
- Install AppDynamics services
- Verify Controller UI
- Test with sample application

**Monitor:**
```bash
./instructor/check-controller-status.sh --all-teams

# Expected output:
# Team 1: ✅ Controller Running | UI Accessible
# Team 2: ✅ Controller Running | UI Accessible
# Team 3: ⏳ Installing Services
# Team 4: ✅ Controller Running | UI Accessible
# Team 5: ⏳ Bootstrap Complete | Installing
```

### End of Day: Cleanup (5:00 PM - 6:00 PM)

**CRITICAL: Cost Control**

```bash
# Option 1: Students clean up their own resources
# (Learning opportunity - they see what they created)
# Teams run: ./cleanup-team.sh --team X

# Option 2: Instructor bulk cleanup
./instructor/cleanup-all-teams.sh --confirm

# Verify nothing left running
./instructor/verify-cleanup.sh

# Generate cost report
./instructor/cost-report.sh --date today

# Expected cost: ~$95 for 8-hour lab
```

---

## 🆘 Troubleshooting Guide

### Issue: Team can't access AWS

**Symptoms:** "Access Denied" errors
**Fix:**
```bash
# Verify IAM user/role
aws iam get-user --user-name appd-lab-team1

# Check permissions
aws iam list-attached-user-policies --user-name appd-lab-team1
```

### Issue: VPC Creation Fails

**Symptoms:** "VPC Limit Exceeded"
**Fix:**
```bash
# Check VPC quota
aws ec2 describe-vpcs --query 'length(Vpcs)'

# Request quota increase (if needed)
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

### Issue: ALB Health Checks Failing

**Symptoms:** ALB shows "unhealthy" targets
**Fix:**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-names appd-team1-sg

# Verify VMs are listening on 443
ssh appduser@<team1-vm-ip> "sudo netstat -tlnp | grep 443"

# Check Controller is actually running
ssh appduser@<team1-vm-ip> "appdcli ping"
```

### Issue: DNS Not Resolving

**Symptoms:** `nslookup controller-team1.splunkylabs.com` returns NXDOMAIN
**Fix:**
```bash
# Verify Route 53 record exists
aws route53 list-resource-record-sets --hosted-zone-id Z06491142QTF1FNN8O9PR | grep team1

# Check ALB DNS name
aws elbv2 describe-load-balancers --names appd-team1-alb --query 'LoadBalancers[0].DNSName'

# Verify record points to correct ALB
```

### Issue: Certificate Not Working

**Symptoms:** Browser shows "Certificate error"
**Fix:**
```bash
# Verify ACM certificate is attached to ALB
aws elbv2 describe-listeners --load-balancer-arn <alb-arn> | grep CertificateArn

# Check certificate matches domain
aws acm describe-certificate --certificate-arn $CERT_ARN | grep DomainName
```

---

## 📊 Monitoring & Metrics

### Real-Time Monitoring

```bash
# Monitor all teams every 5 minutes
watch -n 300 './instructor/monitor-all-teams.sh'
```

### Cost Tracking

```bash
# Check current spend
aws ce get-cost-and-usage \
  --time-period Start=2025-12-03,End=2025-12-04 \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://filters/lab-resources.json
```

### CloudWatch Dashboard

Access: https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=AppDLab-AllTeams

Metrics:
- EC2 CPU/Memory per team
- ALB request count
- ALB target health
- Total cost per team

---

## ✅ Post-Lab Checklist

### Immediately After Lab

- [ ] All teams have cleaned up resources
- [ ] Verify no running EC2 instances
- [ ] Verify no orphaned EBS volumes
- [ ] Verify all ALBs deleted
- [ ] Check Route 53 records (keep or delete)
- [ ] Generate final cost report
- [ ] Collect student feedback

### Next Day

- [ ] Review cost report
- [ ] Document any issues encountered
- [ ] Update lab guide based on feedback
- [ ] Archive team credentials
- [ ] Disable IAM users (or delete if temporary)

### One Week After

- [ ] Verify no surprise charges
- [ ] Review CloudTrail logs
- [ ] Update instructor notes
- [ ] Prepare for next lab session

---

## 💰 Budget Management

### Expected Costs (8-hour lab)
- EC2 Instances: $82.56
- EBS Storage: $11.67
- ALB: $0.89
- Route 53: Negligible
- **Total: ~$95**

### Cost Alerts

```bash
# Set up budget alert
aws budgets create-budget \
  --account-id $AWS_ACCOUNT_ID \
  --budget file://budgets/lab-budget.json \
  --notifications-with-subscribers file://budgets/lab-notifications.json
```

### If Budget Exceeded

1. Check for resources left running overnight
2. Verify cleanup scripts ran successfully
3. Look for unexpected data transfer charges
4. Check for orphaned snapshots or AMIs

---

## 📝 Documentation

### Generated Artifacts

After lab, these files are created:
- `logs/instructor-log-YYYYMMDD.txt`
- `reports/cost-report-YYYYMMDD.csv`
- `reports/team-progress-YYYYMMDD.md`
- `feedback/team-feedback-YYYYMMDD.txt`

### Archive Location

All lab materials archived to:
```
s3://appd-lab-archives/2025-12-03/
├── configurations/
├── logs/
├── reports/
└── feedback/
```

---

## 🎓 Student Outcomes

By the end of this lab, students will have:

✅ Built a production-grade AWS VPC with multiple subnets
✅ Deployed and configured an Application Load Balancer
✅ Managed SSL certificates with AWS Certificate Manager
✅ Configured DNS records in Route 53
✅ Deployed a 3-node Kubernetes cluster
✅ Installed and configured AppDynamics Controller
✅ Tested application monitoring with sample apps
✅ Practiced infrastructure cleanup and cost management

---

## 📞 Support Contacts

- **Instructor:** bmstoner@cisco.com
- **AWS Support:** (if issues arise)
- **AppDynamics Support:** licensing-help@appdynamics.com (for license issues)

---

## 🔄 Next Lab Session

**Improvements for Next Time:**
- [ ] Item 1
- [ ] Item 2

**Updated Materials:**
- [ ] Updated lab guide (version X.Y)
- [ ] New troubleshooting steps
- [ ] Improved monitoring scripts

---

**Ready to run the lab!** Students will have an incredible learning experience building production-grade infrastructure from scratch.
