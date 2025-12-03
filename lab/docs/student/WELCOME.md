# Welcome to the AppDynamics Lab! 🎓

## 👋 Getting Started

You're about to build a complete, production-grade AppDynamics deployment on AWS from scratch!

### What You'll Build
- Complete AWS infrastructure (VPC, subnets, security groups)
- 3 high-powered VMs (16 CPU, 64GB RAM each)
- Application Load Balancer with SSL certificate
- DNS configuration
- 3-node Kubernetes cluster
- Full AppDynamics installation

### Time Required
**~3.5 hours** hands-on work

### Cost
**~$20** for your team (8-hour lab day)
⚠️ **Must cleanup at end!**

---

## 🚀 Quick Start (7 Commands)

### 1. Deploy AWS Infrastructure (30 minutes)
```bash
./lab-deploy.sh --team 1
```
Creates: VPC, VMs, Load Balancer, DNS

### 2. Bootstrap VMs (1 hour)
```bash
./appd-bootstrap-vms.sh --team 1
```
Sets up all 3 VMs for Kubernetes

### 3. Create Kubernetes Cluster (15 minutes)
```bash
./appd-create-cluster.sh --team 1
```
Creates 3-node high-availability cluster

### 4. Configure AppDynamics (10 minutes)
```bash
./appd-configure.sh --team 1
```
Automatically updates configuration with your team's settings

### 5. Install AppDynamics (30 minutes)
```bash
./appd-install.sh --team 1
```
Installs Controller and all services

### 6. Verify Everything Works
```bash
./appd-check-health.sh --team 1
```
Opens: https://controller-team1.splunkylabs.com/

### 7. Cleanup (REQUIRED at end of day!)
```bash
./lab-cleanup.sh --team 1 --confirm
```
Deletes all resources to avoid charges

---

## 📚 Documentation

- **Start Here:** [docs/QUICK_START.md](docs/QUICK_START.md) - Complete walkthrough
- **Commands:** [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) - Cheat sheet
- **Help:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

---

## 🆘 Need Help?

1. Check the documentation (most answers are there!)
2. Run: `./scripts/check-status.sh --team 1`
3. Ask your team members
4. Ask the instructor

---

## ✅ What You'll Learn

By the end of this lab, you'll know how to:
- ✅ Design and deploy AWS VPCs
- ✅ Configure load balancers with SSL
- ✅ Create Kubernetes clusters
- ✅ Install enterprise software
- ✅ Troubleshoot complex systems
- ✅ Manage cloud costs

**These are REAL production skills!**

---

## ⚠️ Important Notes

### Before You Start
- Make sure you have your team number (1-5)
- Have your AWS credentials ready
- SSH client installed on your laptop

### During Lab
- Follow the scripts in order
- Don't skip steps
- Take notes on what you learn
- Help your teammates

### At End of Day
- **MUST run cleanup script**
- Verify all resources deleted
- Share feedback with instructor

---

## 🎯 Your Team

**Team Number:** _____ (1-5)

**Team Members:**
1. _______________
2. _______________
3. _______________
4. _______________

**Your URLs:**
- Controller: `https://controller-team__.splunkylabs.com/controller/`
- Domain: `team__.splunkylabs.com`

---

**Ready to build?** Start with [docs/QUICK_START.md](docs/QUICK_START.md)! 🚀

Good luck and have fun! This is going to be an amazing learning experience! 🎓
