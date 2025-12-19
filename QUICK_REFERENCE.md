# Student Quick Reference Card

**AppDynamics Lab - December 2025**  
**Keep this handy during lab deployment!**

---

## 🚀 Quick Start

```bash
# 1. Configure AWS
aws configure
# Region: us-west-2
# Output: json

# 2. Clone repository
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab

# 3. Deploy your team
./deployment/01-deploy.sh --team N     # 5 min
./deployment/04-bootstrap-vms.sh --team N  # 25 min (auto-waits)
./deployment/05-create-cluster.sh --team N  # 10 min
./deployment/07-install.sh --team N    # 25 min (auto-waits)
```

**Your Controller:** `https://controller-teamN.splunkylabs.com/controller/`  
**Login:** `admin` / `welcome` (change after first login!)

---

## ✅ Pre-Flight Checks

| Check | Command | Expected Result |
|-------|---------|-----------------|
| AWS Config | `aws sts get-caller-identity` | Shows your user ARN |
| Repository | `git status` | "On branch main" |
| Scripts | `ls deployment/01-deploy.sh` | File exists |

---

## 🔍 Common Issues & Quick Fixes

### 1. Script Exits Silently

**Symptom:** Script prints a few lines then exits with no error

**Fix:**
```bash
# Test AWS
./scripts/test-aws-cli.sh

# If fails:
aws configure  # Re-enter credentials
git pull       # Get latest fixes
```

---

### 2. Can't Create VMs (Phase 3 Fails)

**Symptom:** "UnauthorizedOperation" or silent failure at VM creation

**Fix:** Contact instructor - IAM permissions need update  
**While waiting:** Document error with `aws ec2 run-instances --dry-run ...`

---

### 3. Installation Hangs or Fails

**Check Progress:**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team N

# Check what's happening
kubectl get pods --all-namespaces
appdcli ping
```

**If MySQL Issues:**
```bash
# On VM1
kubectl get pods -n mysql
# Should see 3 pods running

# If not ready - wait 5 minutes
# If stuck - run recovery:
appdcli run mysql_restore
```

---

### 4. SSH Password Prompts

**Symptom:** Asked for password when SSH should work with key

**Fix:**
```bash
# Re-run bootstrap (configures passwordless sudo)
./deployment/04-bootstrap-vms.sh --team N
```

---

### 5. SecureApp Shows "Failed"

**Symptom:** `appdcli ping` shows SecureApp: Failed

**Fix (Optional):**
```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team N

# Configure feeds (needs AppDynamics portal account)
appdcli run secureapp setDownloadPortalCredentials <username>
# Enter password when prompted
```

**Note:** SecureApp works without feeds - only CVE scanning affected

---

### 6. EUM Not Working

**Symptom:** No browser monitoring data in Controller

**Fix:** Configure in admin.jsp

1. Go to: `https://controller-teamN.splunkylabs.com/controller/admin.jsp`
2. Password: `welcome`
3. Controller Settings → Update these properties:

```
eum.beacon.host = controller-teamN.splunkylabs.com/eumcollector
eum.beacon.https.host = controller-teamN.splunkylabs.com/eumcollector
eum.cloud.host = https://controller-teamN.splunkylabs.com/eumaggregator
eum.es.host = controller-teamN.splunkylabs.com:443
appdynamics.on.premise.event.service.url = https://controller-teamN.splunkylabs.com/events
eum.mobile.screenshot.host = controller-teamN.splunkylabs.com/screenshots
```

---

### 7. ADRUM JavaScript Files Not Found

**Symptom:** 404 when trying to load ADRUM files

**Fix:** Host ADRUM externally (can't host in EUM pod)

**Quick Test:**
```bash
# Download ADRUM from Controller UI
# Extract and run simple server:
cd ~/adrum-files
python3 -m http.server 8080

# Use in browser app config:
# adrumExtUrlHttp: 'http://YOUR-IP:8080'
```

**Production:** Use Nginx, Apache, or S3 (see troubleshooting guide)

---

## 🆘 Emergency Commands

### Check Everything

```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team N

# Quick health check
appdcli ping

# Check all pods
kubectl get pods --all-namespaces

# Check nodes
kubectl get nodes
```

### Restart Services

```bash
# On VM1
appdcli stop appd
sleep 30
appdcli start appd small
```

### Check Logs

```bash
# On VM1
# Controller logs
kubectl logs -n cisco-controller $(kubectl get pods -n cisco-controller -l app=controller -o name) --tail=50

# MySQL logs
kubectl logs -n mysql appd-mysql-0 --tail=50

# System logs
journalctl -u appd-os -n 50
```

### Nuclear Option (Complete Reinstall)

```bash
# On VM1
appdcli stop appd
appdcli stop operators

# Wait for cleanup
sleep 60

# Exit and re-run from laptop
exit
./deployment/07-install.sh --team N
```

---

## 📊 Verification Checklist

After deployment, verify:

- [ ] Can access Controller URL (https://controller-teamN.splunkylabs.com/controller/)
- [ ] Can login with admin / welcome
- [ ] License applied and valid
- [ ] All services show "Success" in `appdcli ping`
- [ ] Sample app monitored (if configured)

**Check Services:**
```bash
./scripts/ssh-vm1.sh --team N
appdcli ping
```

Expected output:
```
Controller: Success
Events Service: Success
EUM: Success
Synthetic Monitoring: Success
AIOps: Success
ATD: Success
MySQL: Success
SecureApp: Failed (OK if not configured)
```

---

## 🔧 Useful Commands

### SSH to VMs

```bash
./scripts/ssh-vm1.sh --team N
./scripts/ssh-vm2.sh --team N
./scripts/ssh-vm3.sh --team N

# Or manually:
ssh -i ~/.ssh/appd-teamN-key appduser@<vm-ip>
```

### Check Deployment Status

```bash
# From laptop
./scripts/check-deployment-state.sh --team N

# Shows:
# - VPC, subnets, security groups
# - VM instances and IPs
# - ALB and target groups
# - DNS records
```

### Monitor Long Operations

```bash
# Bootstrap (auto-monitored in script)
./deployment/04-bootstrap-vms.sh --team N
# Shows progress every 60 seconds

# Installation (auto-monitored in script)
./deployment/07-install.sh --team N
# Shows pod counts and status every 60 seconds
```

### Clean Up (When Done)

```bash
# Delete everything
./deployment/cleanup.sh --team N --confirm

# Verify cleanup
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=appd-team-N-vpc"
# Should return empty
```

---

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| `README.md` | Project overview |
| `TROUBLESHOOTING_GUIDE.md` | Detailed fixes for all issues |
| `STUDENT_DEPLOYMENT_DEFECTS.md` | Known issues and status |
| `common_issues.md` | FAQ-style Q&A |
| `docs/DEPLOYMENT_FLOW.md` | Complete deployment process |
| `docs/LAB_GUIDE.md` | Student lab instructions |

---

## 💡 Pro Tips

1. **Always run latest code:** `git pull` before starting
2. **Check AWS first:** `./scripts/test-aws-cli.sh`
3. **Be patient:** Bootstrap (25 min) and install (25 min) take time
4. **Watch progress:** Scripts now show real-time updates
5. **Read error messages:** Scripts now display clear errors with fixes
6. **Use SSH helper scripts:** `./scripts/ssh-vm1.sh --team N`
7. **Check logs:** Most issues visible in pod logs
8. **Don't interrupt:** Let long operations complete
9. **Document errors:** Screenshot/copy errors for instructor
10. **Ask for help:** Instructor/TA available for assistance

---

## 🎯 Deployment Timeline

| Phase | Script | Time | Notes |
|-------|--------|------|-------|
| 1. Infrastructure | `01-deploy.sh` | 5 min | Creates VPC, VMs, etc. |
| 2. DNS | `02-create-dns.sh` | 2 min | Optional if using ALB |
| 3. Load Balancer | `03-create-alb.sh` | 3 min | Optional |
| 4. Bootstrap | `04-bootstrap-vms.sh` | 25 min | **Auto-waits, shows progress** |
| 5. Cluster | `05-create-cluster.sh` | 10 min | Creates K8s cluster |
| 6. Configure | `06-configure.sh` | 2 min | Sets team config |
| 7. Install | `07-install.sh` | 25 min | **Auto-waits, shows progress** |
| 8. License | Apply manually | 5 min | Via Controller UI |
| 9. Verify | `08-verify.sh` | 2 min | Checks services |
| **Total** | | **~80 min** | Mostly automated |

---

## 📞 Getting Help

**First Steps:**
1. Check this card for quick fixes
2. Review `TROUBLESHOOTING_GUIDE.md`
3. Check `common_issues.md`
4. Run diagnostic: `./scripts/test-aws-cli.sh`
5. Check service status: `appdcli ping` (on VM1)

**Still Stuck?**
- Contact instructor/TA
- Provide: Error message, command run, your team number
- Share: Output of `./scripts/check-deployment-state.sh --team N`

**Useful Info to Have Ready:**
- Your team number
- Which script failed
- Error message (full text or screenshot)
- Output of `aws sts get-caller-identity`
- Output of `kubectl get pods -A` (if on VM)

---

## 🏆 Success Indicators

**You're Done When:**
- ✅ Controller accessible at your team URL
- ✅ Can login with admin credentials
- ✅ License shows in Settings → License
- ✅ All core services show "Success" in `appdcli ping`
- ✅ Can create and monitor sample applications

**Test Your Deployment:**
```bash
# From laptop
curl -k https://controller-teamN.splunkylabs.com/controller/rest/serverstatus

# Should return XML with status info

# From VM1
appdcli ping
# All services should show "Success" (except SecureApp if not configured)
```

---

## 🎓 Learning Objectives

By completing this lab, you'll learn:
- Infrastructure as Code with AWS CLI
- Kubernetes cluster management
- AppDynamics Controller deployment
- High-availability configuration
- Troubleshooting distributed systems
- Service mesh and ingress routing
- Certificate and security management

---

**Good luck! Remember: Most issues have quick fixes in TROUBLESHOOTING_GUIDE.md**

**Version:** 1.0 | **Updated:** December 19, 2025 | **Contact:** Lab Administrator
