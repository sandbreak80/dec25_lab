# Instructor Guide - AppDynamics Multi-Team Lab

> **For Instructors Only**: Complete setup and management guide.

---

## 🎯 Lab Overview

**Duration**: 60-90 minutes  
**Students**: 20 (5 teams of 4)  
**AWS Cost**: ~$50-100 per day (all teams)  
**Cleanup**: Teams delete their own infrastructure

### What Students Learn

1. AWS Infrastructure Deployment (VPC, EC2, ALB, Route 53)
2. AppDynamics On-Premises Installation
3. Kubernetes/MicroK8s cluster creation
4. SSL/TLS certificate management (AWS ACM)
5. DNS configuration
6. Security best practices (VPN-only access)
7. Service health monitoring

---

## 📋 Prerequisites

### AWS Account Setup

1. **AWS Account** with sufficient limits:
   - EC2 instances: 15 (3 per team)
   - Elastic IPs: 15
   - VPCs: 5
   - Application Load Balancers: 5
   - Route 53 Hosted Zone: 1 (shared)

2. **IAM Permissions**:
   - EC2 (full)
   - VPC (full)
   - ELB (full)
   - Route 53 (full)
   - ACM (full)
   - S3 (limited to lab bucket)

3. **AWS CLI** installed and configured

4. **Domain**: Register domain (e.g., `splunkylabs.com`) in Route 53

### Student Access

Create 5 IAM users (one per team) with:
```
- EC2: Full access to their team's resources only
- VPC: Full access to their team's VPC only
- Route 53: Record management in shared hosted zone
- ACM: Certificate management for their subdomain
```

Use resource tags to isolate teams:
```
Team: team1, team2, team3, team4, team5
```

### Network Setup

Students **must** be on Cisco VPN for SSH access. The security groups are pre-configured with Cisco VPN egress IPs:

- US-West: `151.186.183.24/32`, `151.186.183.87/32`
- US-East: `151.186.182.23/32`, `151.186.182.87/32`
- Shared: `151.186.192.0/20`

**Test VPN access before lab!**

---

## 🚀 Pre-Lab Setup (1-2 hours)

### 1. Prepare AWS Environment

```bash
# Clone/download this repository
git clone <repo-url>
cd deploy/aws

# Verify AWS CLI access
aws sts get-caller-identity

# Create S3 bucket for AMI import (shared across teams)
aws s3 mb s3://appd-va-lab-images-<unique-id> --region us-west-2

# Register domain (if not already done)
# Manual: Route 53 console
```

### 2. Upload AppDynamics AMI

Download AMI from AppDynamics portal:

```bash
# Upload to S3 (one time, all teams share)
aws s3 cp appd_va_25.4.0.2016.ami s3://appd-va-lab-images-<unique-id>/

# Import snapshot (one time)
# See docs/QUICK_REFERENCE.md for import commands

# Share AMI with student accounts (or keep in shared account)
```

**AMI ID**: Save this - students need it in their config files

### 3. Create Team Config Files

Already done! See `config/team1.cfg` through `config/team5.cfg`

Verify each team config has:
- Unique CIDR block
- Unique subdomain
- Correct AMI ID
- Correct S3 bucket name

### 4. Create Student Credentials

```bash
# Create IAM users
for i in {1..5}; do
  aws iam create-user --user-name lab-team$i
  aws iam create-access-key --user-name lab-team$i > team$i-credentials.json
done

# Attach team-specific policies (use tags for isolation)
```

**Distribute credentials securely** (not via email!)

### 5. Request AppDynamics Licenses

Contact AppDynamics licensing:
- Email: licensing-help@appdynamics.com
- Request: 5 lab licenses (small, temporary)
- Include: Your company, use case, duration

**You'll get 5 `license.lic` files** - one per team.

### 6. Test Deployment (Dry Run)

```bash
# Test with team1 config
./lab-deploy.sh config/team1.cfg

# Verify everything works
./appd-check-health.sh config/team1.cfg

# Cleanup test
./lab-cleanup.sh config/team1.cfg
```

---

## 👥 Day of Lab

### 30 Minutes Before

1. **Verify VPN** is accessible for students
2. **Test AWS access** for each team
3. **Confirm domain/DNS** is working
4. **Check AWS limits** (EC2, EIPs, VPCs)
5. **Prepare licenses** (5 files ready to distribute)

### Lab Start (10 min)

1. **Introduce Lab**:
   - Objectives
   - Architecture diagram (docs/ARCHITECTURE.md)
   - Time expectations
   - Team assignments

2. **Distribute Credentials**:
   - AWS access keys (per team)
   - AppDynamics license files (per team)
   - Team config file assignments

3. **Verify VPN**:
   - All students connect to Cisco VPN
   - Test with: `curl ifconfig.me` (should show `151.186.183.*` or similar)

4. **Clone Repository**:
   ```bash
   git clone <repo-url>
   cd appd-virtual-appliance/deploy/aws
   ```

5. **Show README**:
   - Walk through `README.md`
   - Point out 6 simple scripts
   - Show docs folder

### During Lab (60 min)

**Let students work independently**, but monitor:

```bash
# Watch all team deployments (from your admin account)
watch -n 30 'aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=appd-lab" \
  --query "Reservations[].Instances[].[Tags[?Key==`Team`].Value|[0],State.Name,PublicIpAddress]" \
  --output table'
```

**Common Issues**:

| Issue | Solution |
|-------|----------|
| SSH timeout | Check VPN connection (`curl ifconfig.me`) |
| AMI not found | Verify AMI ID in config file |
| VPC limit | Check AWS service quotas |
| DNS not resolving | Wait 2-3 minutes for propagation |
| secrets.yaml permission denied | Run `sudo chmod 644 /var/appd/config/secrets.yaml` |
| `appdcli start appd small` fails | Retry once (known GPG key issue) |

### Lab End (20 min)

1. **Verify Completion**:
   - All teams access their Controller UI
   - All services show "Success" in `appdcli ping`
   - SecureApp installed (if time permits)

2. **Cleanup**:
   ```bash
   # Each team runs
   ./lab-cleanup.sh config/team1.cfg
   ```

3. **Verify Cleanup**:
   ```bash
   # Check no instances remain
   aws ec2 describe-instances \
     --filters "Name=tag:Project,Values=appd-lab" \
     --query "Reservations[].Instances[].State.Name"
   ```

4. **Debrief** (5 min):
   - What did you learn?
   - Challenges?
   - Real-world applications?

---

## 💰 Cost Management

### Estimated Costs (us-west-2)

Per Team:
- 3x t3.2xlarge (8 vCPU, 32GB RAM): $0.33/hr × 3 = $0.99/hr
- 3x Elastic IPs: $0.005/hr × 3 = $0.015/hr
- ALB: $0.0225/hr
- Data transfer: ~$0.10/hr
- **Total per team**: ~$1.13/hr

All 5 Teams:
- **Per hour**: $5.65/hr
- **4 hour lab**: ~$23
- **Full day**: ~$135

**Cost Savings**:
- Use spot instances (not recommended for lab)
- Smaller instances (t3.xlarge) - may be too small
- Turn off when not in use

### Cleanup Verification

```bash
# Verify no running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"

# Verify no EIPs
aws ec2 describe-addresses

# Verify no ALBs
aws elbv2 describe-load-balancers

# Check billing dashboard
```

---

## 🔧 Troubleshooting

### Student Can't SSH

1. Check VPN: `curl ifconfig.me` → Should show `151.186.*`
2. Check security group: `scripts/check-status.sh config/team1.cfg`
3. Manually add IP:
   ```bash
   SG_ID=$(aws ec2 describe-instances --filters "Name=tag:Team,Values=team1" \
     --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text)
   
   STUDENT_IP=$(curl -s ifconfig.me)
   
   aws ec2 authorize-security-group-ingress \
     --group-id $SG_ID \
     --protocol tcp --port 22 \
     --cidr $STUDENT_IP/32
   ```

### Deployment Fails

```bash
# Check logs
./lab-deploy.sh config/team1.cfg 2>&1 | tee deploy.log

# Verify AWS credentials
aws sts get-caller-identity

# Check service limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A  # Running On-Demand instances
```

### AppDynamics Installation Fails

```bash
# SSH to primary VM
ssh appduser@<vm1-ip>

# Check cluster status
appdctl show cluster

# Check pod status
kubectl get pods --all-namespaces

# Retry installation
appdcli start appd small

# Check logs
kubectl logs -n cisco-controller <pod-name>
```

### SSL Certificate Issues

Browser shows self-signed cert:

1. **Check ACM certificate**:
   ```bash
   aws acm list-certificates --region us-west-2
   aws acm describe-certificate --certificate-arn <arn>
   ```

2. **Check ALB listener**:
   ```bash
   aws elbv2 describe-listeners --load-balancer-arn <arn>
   ```

3. **Flush DNS cache** (client side):
   ```bash
   # Mac
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   
   # Windows
   ipconfig /flushdns
   ```

### Cluster Won't Form

```bash
# On VM1
appdctl cluster init <VM2-IP> <VM3-IP>

# If fails, check:
# 1. Network connectivity
ping <VM2-IP>

# 2. Firewall
appdctl show boot | grep firewall

# 3. Time sync
timedatectl

# 4. Start over
# Terminate VMs and redeploy
```

---

## 📊 Monitoring (Instructor Dashboard)

### Real-time Lab Status

```bash
# Watch all deployments
watch -n 10 './scripts/check-status.sh config/team1.cfg; \
              ./scripts/check-status.sh config/team2.cfg; \
              ./scripts/check-status.sh config/team3.cfg; \
              ./scripts/check-status.sh config/team4.cfg; \
              ./scripts/check-status.sh config/team5.cfg'
```

### Team Progress Checklist

| Team | VPC | VMs | ALB | DNS | Cluster | AppD | SecureApp |
|------|-----|-----|-----|-----|---------|------|-----------|
| 1    | ✅  | ✅  | ✅  | ✅  | ⏳      | ❌   | ❌        |
| 2    | ✅  | ⏳  | ❌  | ❌  | ❌      | ❌   | ❌        |
| ...  |     |     |     |     |         |      |           |

Update manually or script it!

---

## 📚 Additional Resources

- [AWS Best Practices](docs/ARCHITECTURE.md)
- [AppDynamics Documentation](https://docs.appdynamics.com/)
- [Vendor Issues Fixed](docs/VENDOR_ISSUES.md)
- [Security Configuration](docs/SECURITY.md)

---

## 🆘 Emergency Contacts

- **AWS Support**: https://console.aws.amazon.com/support/
- **AppDynamics Support**: https://help.appdynamics.com/
- **Your Company IT**: [Add contact info]

---

## ✅ Post-Lab Checklist

- [ ] All teams completed cleanup
- [ ] No running EC2 instances
- [ ] No allocated Elastic IPs
- [ ] No Application Load Balancers
- [ ] DNS records deleted (or marked for deletion)
- [ ] IAM access keys rotated/deleted
- [ ] S3 bucket cleaned (optional - reuse for next lab)
- [ ] Cost report generated
- [ ] Student feedback collected

---

**Questions?** Review [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or check vendor issues docs.
