# AppDynamics Virtual Appliance Lab - Quick Start Guide

## 🎯 Overview

This lab teaches you to build a production-grade AppDynamics deployment on AWS from scratch. You'll work in teams of 4 to create a complete, isolated environment.

**What You'll Build:**
- VPC with multi-AZ subnets
- 3-node Kubernetes cluster
- Application Load Balancer with SSL
- DNS configuration
- Full AppDynamics deployment

**Time:** 8 hours
**Team Size:** 4 students
**Cost:** ~$20 per team

---

## 🚀 Getting Started

### Prerequisites

1. **AWS Account Access**
   - Your instructor will provide credentials
   - IAM user or role for your team

2. **Laptop Requirements**
   - Mac, Linux, or Windows (with WSL)
   - AWS CLI installed
   - SSH client
   - Git

3. **Team Assignment**
   - You are Team **N** (1-5)
   - Your domain: `teamN.splunkylabs.com`
   - Your VPC: `10.N.0.0/16`

### Quick Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd appd-virtual-appliance/deploy/aws

# 2. Set your team number
export TEAM_NUMBER=1  # Replace with your team number (1-5)

# 3. Configure AWS CLI
./01-aws-create-profile.sh --team $TEAM_NUMBER

# Enter your AWS credentials when prompted
```

---

## 📋 Lab Workflow

### Phase 1: AWS Infrastructure Deployment (30 minutes)

**One command deploys everything:**

```bash
./lab-deploy.sh --team $TEAM_NUMBER
```

This creates:
- ✅ VPC & Subnets (2 availability zones)
- ✅ Internet Gateway & Routes
- ✅ Security Groups
- ✅ 3 EC2 Instances (m5a.4xlarge)
- ✅ Application Load Balancer
- ✅ SSL Certificate (AWS Certificate Manager)
- ✅ DNS Records (Route 53)

**Wait:** ~30 minutes for deployment to complete

### Phase 2: Bootstrap VMs (1 hour)

**Use the helper script:**

```bash
./appd-bootstrap-vms.sh --team $TEAM_NUMBER
```

This guides you through:
- SSH to each VM
- Run `sudo appdctl host init` on each
- Verify bootstrap completed
- Change VM passwords

**All VMs must show "Succeeded" for all services**

### Phase 3: Create Kubernetes Cluster (15 minutes)

**Use the helper script:**

```bash
./appd-create-cluster.sh --team $TEAM_NUMBER
```

This guides you through:
- SSH to VM1
- Run `appdctl cluster init <VM2-IP> <VM3-IP>`
- Verify cluster health

**All 3 nodes should show "Running: true"**

### Phase 4: Configure AppDynamics (10 minutes)

**Use the helper script:**

```bash
./appd-configure.sh --team $TEAM_NUMBER
```

This automatically:
- Downloads current config from VM1
- Updates it with team-specific values
- Uploads it back to VM1
- Verifies configuration

**No manual editing required!**

### Phase 5: Install AppDynamics (30 minutes)

**Use the helper script:**

```bash
./appd-install.sh --team $TEAM_NUMBER
```

This guides you through:
- SSH to VM1
- Run `appdcli start all small`
- Monitor installation progress
- Verify all services

**This installs everything:**
- Controller
- Events Service
- EUM (End User Monitoring)
- Synthetic Monitoring
- AIOps
- ATD (Automatic Transaction Diagnostics)
- SecureApp

### Phase 6: Verify Installation

**Check health:**

```bash
./appd-check-health.sh --team $TEAM_NUMBER
```

### Phase 7: Access Controller UI

Open browser:
```
https://controller-team$TEAM_NUMBER.splunkylabs.com/controller/
```

Default credentials:
- Username: `admin`
- Password: `welcome`

**⚠️ Change this password immediately!**

### Phase 8: Cleanup (End of Day)

```bash
./lab-cleanup.sh --team $TEAM_NUMBER --confirm

# Type: DELETE TEAM N  (use your team number)
```

This removes **ALL** resources to avoid charges.

---

## 🆘 Common Issues & Solutions

### Issue: "DNS not resolving"
**Solution:** Wait 2-3 minutes for DNS propagation
```bash
# Test DNS
nslookup controller-team1.splunkylabs.com
```

### Issue: "ALB targets unhealthy"
**Solution:** Wait 3-5 minutes for health checks
```bash
# Check target health
./scripts/check-status.sh --team $TEAM_NUMBER
```

### Issue: "Can't SSH to VM"
**Solution:** Check security group allows your IP
```bash
# Your instructor can update security group
```

### Issue: "Bootstrap failed"
**Solution:** Check network configuration
```bash
# Verify:
# - IP address is correct (10.N.0.X/24)
# - Gateway is 10.N.0.1
# - DNS is correct

# Re-run if needed:
sudo appdctl host init
```

### Issue: "Cluster init fails"
**Solution:** 
1. Verify all VMs bootstrapped successfully
2. Use private IPs (not public)
3. Ensure password is correct
4. Check VMs can ping each other

### Issue: "AppDynamics install fails"
**Solution:**
1. Verify cluster is healthy: `appdctl show cluster`
2. Check secrets.yaml permissions: `ls -l /var/appd/config/secrets.yaml`
3. If permissions error, fix: `sudo chmod 644 /var/appd/config/secrets.yaml`
4. Retry: `appdcli start all small`

---

## 📚 Additional Resources

### Documentation
- **Full Lab Guide:** `docs/LAB_GUIDE.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`
- **Quick Reference:** `docs/QUICK_REFERENCE.md`
- **Architecture:** `MULTI_TEAM_LAB_ARCHITECTURE.md`

### Helper Scripts
```bash
# Check deployment status
./scripts/check-status.sh --team $TEAM_NUMBER

# SSH to any VM
./scripts/ssh-vm1.sh --team $TEAM_NUMBER

# Verify everything is working
./scripts/verify-deployment.sh --team $TEAM_NUMBER
```

### URLs (Replace '1' with your team number)
- **Controller:** https://controller-team1.splunkylabs.com/controller/
- **Auth Service:** https://customer1-team1.auth.splunkylabs.com/
- **Status Dashboard:** `./scripts/check-status.sh --team 1`

---

## 💡 Tips for Success

### Team Collaboration
- **Divide tasks:** Infrastructure, VMs, Configuration, Testing
- **Document everything:** What worked, what didn't
- **Help each other:** Share solutions with other teams
- **Ask questions:** Instructors are here to help

### Best Practices
- **Take notes:** You'll use these skills in production
- **Test incrementally:** Don't wait until the end
- **Monitor progress:** Use check-status script frequently
- **Clean up:** Always run cleanup at end of day

### Time Management
- Hour 1-2: Infrastructure deployment
- Hour 3: VM bootstrap
- Hour 4: Cluster creation & configuration
- Hour 5-7: AppDynamics installation
- Hour 8: Testing & cleanup

---

## 🎓 Learning Objectives

By completing this lab, you will:

✅ Understand AWS networking (VPC, subnets, routing)
✅ Deploy and manage EC2 instances
✅ Configure load balancers with SSL
✅ Manage DNS with Route 53
✅ Build Kubernetes clusters
✅ Install enterprise software
✅ Troubleshoot complex systems
✅ Work effectively in teams
✅ Manage cloud costs

---

## 📞 Getting Help

### During Lab
1. **Check documentation first:** Most answers are documented
2. **Ask your team:** 4 heads are better than one
3. **Use check-status script:** Often shows the issue
4. **Ask instructor:** We're here to help!

### After Lab
- **Slack channel:** #appd-lab-help
- **Email instructor:** bmstoner@cisco.com
- **Office hours:** Scheduled times

---

## ✅ Success Criteria

Lab is complete when:
- ✅ All infrastructure deployed
- ✅ 3-node Kubernetes cluster running
- ✅ AppDynamics Controller accessible
- ✅ All services showing "Success"
- ✅ Can log in to Controller UI
- ✅ Resources cleaned up at end

---

**Ready to start?** Run `./lab-deploy.sh --team $TEAM_NUMBER` and let's build! 🚀
