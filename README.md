# AppDynamics Virtual Appliance - Multi-Team Lab

> **For Students**: Start here! This lab will guide you through deploying AppDynamics in AWS.

---

## 🚀 Quick Start

### Prerequisites
1. **AWS Account Access** - Your instructor will provide credentials
2. **Cisco VPN** - Connect before starting (required for SSH access)
3. **AWS CLI** - Already configured with your credentials
4. **Your Team Number** - You'll be assigned Team 1-5

### Lab Steps (30 minutes)

```bash
# 1. Deploy Infrastructure (10 min)
./lab-deploy.sh config/team1.cfg

# 2. Bootstrap VMs (5 min)
./appd-bootstrap-vms.sh config/team1.cfg

# 3. Create AppD Cluster (5 min)
./appd-create-cluster.sh config/team1.cfg

# 4. Configure AppDynamics (3 min)
./appd-configure.sh config/team1.cfg

# 5. Install AppDynamics Services (10 min)
./appd-install.sh config/team1.cfg

# 6. (Optional) Install SecureApp (5 min)
./appd-install-secureapp.sh config/team1.cfg

# 7. Check Health
./appd-check-health.sh config/team1.cfg
```

### When You're Done

```bash
# Cleanup everything
./lab-cleanup.sh config/team1.cfg
```

---

## 📚 Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Step-by-step for students
- **[Lab Guide](docs/LAB_GUIDE.md)** - Complete lab instructions
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Commands and URLs
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues

---

## 🏗️ What Gets Built

Each team builds their own isolated environment:

- **3 EC2 Instances** (AppDynamics nodes)
- **VPC** with public subnet
- **Application Load Balancer** (with SSL certificate)
- **DNS Records** (Route 53)
- **Security Groups** (restricted to Cisco VPN)

**Your Controller URL**: `https://controller-team1.splunkylabs.com/controller/`

---

## 🔐 Security

- **SSH Access**: Only from Cisco VPN (automatic)
- **HTTPS Only**: Valid SSL certificates via AWS ACM
- **No Credentials in Git**: `.gitignore` protects secrets
- **Isolated Teams**: Each team has separate VPC/subnet

---

## 🆘 Need Help?

1. **Check Status**: `./appd-check-health.sh config/team1.cfg`
2. **View Logs**: Check your terminal output
3. **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
4. **Ask Instructor**: They have the full setup guide

---

## 📁 Project Structure

```
.
├── README.md                   # You are here!
├── INSTRUCTOR_GUIDE.md         # For instructors only
│
├── 📁 Student Scripts (Run these)
│   ├── lab-deploy.sh           # Step 1: Deploy infrastructure
│   ├── appd-bootstrap-vms.sh   # Step 2: Bootstrap VMs
│   ├── appd-create-cluster.sh  # Step 3: Create cluster
│   ├── appd-configure.sh       # Step 4: Configure AppD
│   ├── appd-install.sh         # Step 5: Install services
│   ├── appd-install-secureapp.sh # Step 6: Optional SecureApp
│   ├── appd-check-health.sh    # Check system health
│   └── lab-cleanup.sh          # Cleanup when done
│
├── 📁 config/                  # Team configurations
│   ├── team1.cfg               # Team 1 settings
│   ├── team2.cfg               # Team 2 settings
│   └── ...                     # Teams 3-5
│
├── 📁 docs/                    # All documentation
│   ├── QUICK_START.md
│   ├── LAB_GUIDE.md
│   ├── QUICK_REFERENCE.md
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   ├── VPN_SETUP.md
│   ├── SECUREAPP_GUIDE.md
│   ├── TROUBLESHOOTING.md
│   └── VENDOR_ISSUES.md
│
├── 📁 scripts/                 # Helper scripts (internal)
├── 📁 lib/                     # Shared functions
└── 📁 archive/                 # Reference materials
```

---

## ⚙️ Advanced

### Team Configurations

Each team has a config file (`config/team1.cfg`) with:
- Team name & number
- VPC CIDR block
- DNS subdomain
- AWS region
- VM sizing

**Don't edit these unless instructed!**

### Manual Commands

If you need to SSH to your VMs:

```bash
# VM 1 (Primary)
ssh appduser@$(cat state/team1-vm1-ip.txt)

# VM 2
ssh appduser@$(cat state/team1-vm2-ip.txt)

# VM 3
ssh appduser@$(cat state/team1-vm3-ip.txt)
```

Default password: Check with your instructor

---

## 📝 Credits

- **AppDynamics**: Vendor documentation (with many fixes)
- **This Lab**: Created for multi-team learning environment
- **Fixes**: 31+ vendor documentation issues resolved

See [docs/VENDOR_ISSUES.md](docs/VENDOR_ISSUES.md) for details on fixes.

---

## 📜 License

Educational use only. AppDynamics software governed by Cisco licensing terms.

---

**Ready to start?** Run `./lab-deploy.sh config/team1.cfg`
