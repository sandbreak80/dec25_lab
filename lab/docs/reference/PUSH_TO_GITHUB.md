# PUSH TO GITHUB - Final Checklist

## ✅ Repository Ready

**Repository:** https://github.com/sandbreak80/dec25_lab  
**Status:** Initialized, committed, ready to push

---

## 🚀 To Push to GitHub

```bash
cd /Users/bmstoner/Downloads/appd-virtual-appliance/deploy/aws
git push -u origin main
```

If authentication is required, you may be prompted for:
- GitHub username: `sandbreak80`
- GitHub Personal Access Token (not password)

**Generate token if needed:**
- Go to: https://github.com/settings/tokens
- Generate new token (classic)
- Select scopes: `repo` (full control)
- Copy token and use as password

---

## 📦 What's in the Repository

### Scripts (65 files)
- Main deployment scripts (7)
- Helper scripts (10)
- Original vendor scripts (41)
- All executable and team-aware

### Configuration (7 files)
- `config/team-template.cfg` - Template
- `config/team1.cfg` through `team5.cfg` - Team configs
- `.gitignore` - Security exclusions

### Documentation (42 files)
- Student guides (Quick Start, Reference)
- Instructor setup guide
- Architecture documentation
- VPN setup guide
- Troubleshooting guides
- SecureApp guide
- 31 vendor issues documented

### Total
- **129 files tracked**
- **24,519 lines of code/docs**
- **744KB repository size**

---

## 🔒 Security Notes

### Safe to Push (Excluded by .gitignore)
- ✅ AMI files (`*.ami`, `*.ova`)
- ✅ License files (`*.lic`)
- ✅ AWS credentials (`*.pem`, `*.key`)
- ✅ State files (`state/`)
- ✅ Config backups (`*.original`, `*.backup`)
- ✅ Logs (`*.log`)

### What's Included (Safe)
- ✅ Scripts (no credentials embedded)
- ✅ Template configurations (placeholders only)
- ✅ Documentation (no sensitive data)
- ✅ Team configs (need VPN CIDR update)

---

## ⚠️ BEFORE STUDENTS USE

### Critical: Update VPN CIDR

The team configs currently have placeholder VPN ranges:
```bash
SSH_ALLOWED_CIDRS=("10.0.0.0/8")  # PLACEHOLDER!
```

**You MUST update these before students deploy:**

1. **Determine your Cisco VPN range:**
   ```bash
   # Connect to Cisco VPN, then:
   curl ifconfig.me
   # Note the IP (e.g., 172.16.42.100)
   
   # Determine your VPN CIDR range from IT
   # Common ranges: 172.16.0.0/12, 10.64.0.0/16, etc.
   ```

2. **Update config files:**
   ```bash
   # Edit these files:
   config/team1.cfg
   config/team2.cfg
   config/team3.cfg
   config/team4.cfg
   config/team5.cfg
   
   # Change line ~124 in each:
   SSH_ALLOWED_CIDRS=("172.16.0.0/12")  # Your actual VPN range
   ```

3. **Commit and push the update:**
   ```bash
   git add config/team*.cfg
   git commit -m "Update SSH CIDR for Cisco VPN"
   git push
   ```

### Optional: Update Instructor Email

In all team configs, line 15:
```bash
INSTRUCTOR_EMAIL="bmstoner@cisco.com"
```

Update if different instructor or distribution list.

---

## 📚 Student Instructions

After you push, students will:

### 1. Clone Repository
```bash
git clone https://github.com/sandbreak80/dec25_lab.git
cd dec25_lab
```

### 2. Review Documentation
```bash
cat WELCOME.md              # Orientation
cat docs/QUICK_START.md     # Main guide
cat VPN_SETUP.md            # VPN requirements
```

### 3. Connect to VPN
- Open Cisco AnyConnect
- Connect to corporate VPN
- Verify: `curl ifconfig.me` shows Cisco IP

### 4. Deploy Lab
```bash
./lab-deploy.sh --team 1    # Replace 1 with assigned team number
```

### 5. Follow Guided Scripts
- `./appd-bootstrap-vms.sh --team 1`
- `./appd-create-cluster.sh --team 1`
- `./appd-configure.sh --team 1`
- `./appd-install.sh --team 1`
- `./appd-check-health.sh --team 1`

### 6. Access Controller
```
https://controller-team1.splunkylabs.com/controller/
Username: admin
Password: welcome (change immediately!)
```

### 7. Cleanup at End of Day
```bash
./lab-cleanup.sh --team 1 --confirm
```

---

## 🎓 Pre-Lab Instructor Checklist

- [ ] Push repository to GitHub
- [ ] Update VPN CIDR in all team configs
- [ ] Request ACM wildcard certificate (`*.splunkylabs.com`)
- [ ] Create IAM users for 5 teams
- [ ] Upload AppDynamics AMI to S3
- [ ] Test deployment with one team
- [ ] Distribute GitHub URL to students
- [ ] Distribute VPN connection instructions
- [ ] Distribute AWS credentials
- [ ] Prepare for lab day monitoring

**See:** `lab-guide/00-INSTRUCTOR-SETUP.md` for complete checklist

---

## 📊 What Students Will Build

Each team creates:
- Complete AWS infrastructure (VPC, subnets, ALB, DNS)
- 3-node Kubernetes cluster
- Full AppDynamics deployment
- Production-grade architecture

**Time:** ~3.5 hours hands-on  
**Cost:** ~$20 per team for 8-hour lab  
**Skills:** Real production deployment experience

---

## 🆘 Support Resources

### Documentation in Repository
- `WELCOME.md` - Start here
- `docs/QUICK_START.md` - Step-by-step walkthrough
- `docs/QUICK_REFERENCE.md` - Command cheat sheet
- `VPN_SETUP.md` - VPN configuration and troubleshooting
- `LAB_GUIDE.md` - Comprehensive reference
- `VENDOR_DOC_ISSUES.md` - Known issues and fixes

### Helper Scripts
- `./scripts/check-status.sh --team N` - Infrastructure status
- `./appd-check-health.sh --team N` - AppDynamics health
- `./scripts/ssh-vm1.sh --team N` - Quick SSH access

### During Lab
1. Students check documentation
2. Students ask team members
3. Students use diagnostic scripts
4. Instructor assists if needed

---

## 🎉 Success Criteria

After pushing and students complete lab:

### Infrastructure
- ✅ 5 isolated VPCs created
- ✅ 15 EC2 instances running (3 per team)
- ✅ 5 ALBs with valid SSL certificates
- ✅ All DNS records configured

### AppDynamics
- ✅ 5 Controller instances accessible
- ✅ All services running per team
- ✅ Students can log in
- ✅ Students can deploy agents

### Learning
- ✅ Students understand AWS networking
- ✅ Students can deploy Kubernetes
- ✅ Students can install AppDynamics
- ✅ Students can troubleshoot issues
- ✅ Students understand cloud costs

### Operations
- ✅ All resources cleaned up
- ✅ Total cost within budget (~$100)
- ✅ No orphaned resources
- ✅ Positive student feedback

---

## 🚀 Ready to Push?

**Final command:**
```bash
cd /Users/bmstoner/Downloads/appd-virtual-appliance/deploy/aws
git push -u origin main
```

After pushing:
1. Verify on GitHub: https://github.com/sandbreak80/dec25_lab
2. Update VPN CIDR in config files
3. Commit and push VPN update
4. Share repository with students
5. Run your lab!

---

## 📝 Post-Push Next Steps

### Immediate (Before Lab Day)
1. Update VPN CIDR ranges
2. Test deployment with team1
3. Request ACM certificate
4. Create IAM users
5. Upload AMI to S3

### Lab Day
1. Distribute repo URL
2. Distribute VPN info
3. Distribute AWS credentials
4. Monitor student progress
5. Assist with issues

### Post-Lab
1. Verify all cleanups
2. Generate cost report
3. Collect feedback
4. Update documentation
5. Archive for next session

---

**Status:** ✅ **READY TO PUSH TO GITHUB!**

**Run:** `git push -u origin main`
