# AppDynamics Multi-Team Lab - Quick Start 🚀

## Welcome! 👋

You're about to build a **complete, production-grade AppDynamics deployment** on AWS!

---

## ⚡ **Prerequisites (5 Minutes)**

### 1. Connect to Cisco VPN
- Open **Cisco AnyConnect**
- Connect to **US-West** or **US-East**
- Verify: `curl ifconfig.me` (should show `151.186.x.x`)

### 2. Get Your Team Number
- Instructor assigns: **Team 1, 2, 3, 4, or 5**
- Write it down: **Team ___**

### 3. Have AWS Credentials Ready
- Instructor provides IAM credentials
- Keep them handy

---

## 🚀 **Deploy in 7 Commands** (~3.5 hours)

```bash
# 1. Deploy AWS Infrastructure (30 min - automated)
./lab-deploy.sh --team 1

# 2. Bootstrap VMs (1 hr - guided)
./appd-bootstrap-vms.sh --team 1

# 3. Create Kubernetes Cluster (15 min - guided)
./appd-create-cluster.sh --team 1

# 4. Configure AppDynamics (10 min - automated)
./appd-configure.sh --team 1

# 5. Install AppDynamics (30 min - guided)
./appd-install.sh --team 1

# 6. Verify & Access (5 min)
./appd-check-health.sh --team 1

# 7. Cleanup at End of Day (5 min - REQUIRED!)
./lab-cleanup.sh --team 1 --confirm
```

---

## 🌐 **Access Your Controller**

After installation completes:

```
URL:      https://controller-team1.splunkylabs.com/controller/
Username: admin
Password: welcome (change immediately!)
```

---

## 📚 **Documentation**

- **This file** - Quick overview
- **lab/docs/student/QUICK_START.md** - Complete step-by-step guide
- **lab/docs/student/QUICK_REFERENCE.md** - Command cheat sheet
- **lab/docs/student/TROUBLESHOOTING.md** - Common issues

---

## 🆘 **Need Help?**

1. Check documentation in `lab/docs/student/`
2. Run: `./scripts/helpers/check-status.sh --team 1`
3. Ask your team members
4. Ask the instructor

---

## ⚠️ **IMPORTANT**

**You MUST run cleanup at end of day:**
```bash
./lab-cleanup.sh --team 1 --confirm
```

**Why?** Resources cost ~$2.50/hour if left running!
That's ~$60/day per team! 💰

---

## 🎯 **What You'll Learn**

- ✅ AWS VPC design and deployment
- ✅ Load balancer configuration with SSL
- ✅ Kubernetes cluster creation
- ✅ Enterprise software installation
- ✅ Production troubleshooting
- ✅ Cloud cost management

**Ready to build?** Let's go! 🚀

---

**Questions?** See `lab/docs/student/` for complete guides!
