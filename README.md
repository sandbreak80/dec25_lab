# AppDynamics Virtual Appliance Lab

**Multi-team lab environment for hands-on AppDynamics training.**

## 🚀 Quick Start (Students)

**→ [START HERE](START_HERE.md)** ← Begin here!

### Deployment Steps

```bash
# 1. Clone the repository
git clone <repository-url>
cd deploy/aws

# 2. Run the deployment script
./lab-deploy.sh --team <your-team-number>

# 3. Wait ~30 minutes for completion

# 4. Access your infrastructure
# VMs: SSH to public IPs (provided after password change)
# Web: https://controller-team<N>.splunkylabs.com/controller/
```

## 📚 Documentation

**For Students:**
- **[START_HERE.md](START_HERE.md)** - ⭐ Quick start guide
- **[LAB_GUIDE.md](LAB_GUIDE.md)** - Complete lab instructions  
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Command cheat sheet
- **[TEAM2_BUILD.md](TEAM2_BUILD.md)** - Example build walkthrough

**For Instructors:**
- **[INSTRUCTOR_GUIDE.md](docs/INSTRUCTOR_GUIDE.md)** - Setup and management
- **[DEPLOYMENT_SUMMARY.md](docs/DEPLOYMENT_SUMMARY.md)** - Architecture and decisions
- **[SSH_KEY_SETUP.md](docs/SSH_KEY_SETUP.md)** - SSH authentication details

**All Documentation:** See [docs/](docs/) for complete index

## 🏗️ What Gets Deployed

Each team gets an isolated environment:
- **VPC** with 2 subnets (multi-AZ)
- **3 VMs** (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- **Application Load Balancer** with SSL certificate
- **DNS** (team<N>.splunkylabs.com)
- **Security Groups** (SSH restricted to Cisco VPN)

## 🔑 Key Features

✅ **Team Isolation** - Each team has their own VPC and resources  
✅ **Automated Deployment** - One command deploys everything  
✅ **SSH Key Support** - Passwordless authentication  
✅ **Vendor-Compatible** - Matches AppDynamics official approach  
✅ **Data Preservation** - Data disks survive instance termination  
✅ **SSL Certificates** - Wildcard cert via AWS ACM  

## 🎓 Lab Structure

- **5 Teams** - Supports up to 20 students (4 per team)
- **~80 minutes** - Full deployment and installation time
- **~$20/day** - Estimated cost per team for 8-hour lab

## 🛠️ Technology Stack

- **AWS Services**: EC2, VPC, ALB, Route 53, ACM, EIP, ENI
- **AppDynamics**: Virtual Appliance 25.4.0
- **Kubernetes**: MicroK8s (3-node HA cluster)
- **Automation**: Bash, expect, AWS CLI
- **Authentication**: Password + SSH keys (hybrid approach)

## 📋 Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- Cisco VPN access (for SSH)
- `expect` installed (`brew install expect` on macOS)

## 📂 Project Structure

```
deploy/aws/
├── START_HERE.md              # ⭐ Students start here
├── README.md                  # This file
├── LAB_GUIDE.md              # Complete lab guide  
├── QUICK_REFERENCE.md        # Command reference
├── TEAM2_BUILD.md            # Example build
│
├── lab-deploy.sh             # Main deployment script
├── lab-cleanup.sh            # Teardown script
├── appd-*.sh                 # AppDynamics automation scripts
│
├── config/                    # Team configurations
│   ├── team1.cfg
│   ├── team2.cfg
│   └── ...
│
├── scripts/                   # Infrastructure scripts
│   ├── create-vms.sh
│   ├── create-network.sh
│   ├── create-security.sh
│   ├── setup-ssh-keys.sh
│   └── ...
│
├── docs/                      # Detailed documentation
│   ├── README.md             # Documentation index
│   ├── INSTRUCTOR_GUIDE.md
│   ├── DEPLOYMENT_SUMMARY.md
│   └── SSH_KEY_SETUP.md
│
└── lib/                       # Shared functions
    └── common.sh
```

## 🔒 Security

- **SSH Access**: Restricted to Cisco VPN egress IPs only
- **VM-to-VM**: All traffic allowed within security group (for K8s cluster)
- **HTTPS**: Wildcard SSL certificate via AWS ACM
- **Passwords**: Changed from default on first login
- **SSH Keys**: Optional but recommended for better security

## 🐛 Known Issues & Fixes

This project fixes 31+ issues found in the vendor's original deployment scripts:

- ✅ Data disk preservation (was being deleted!)
- ✅ Correct disk device (/dev/sdb not /dev/sdf)
- ✅ Proper EIP/ENI allocation sequence
- ✅ VM-to-VM security group rules
- ✅ SSH key automation
- ✅ Cluster init host key handling

See [docs/DEPLOYMENT_SUMMARY.md](docs/DEPLOYMENT_SUMMARY.md) for complete list.

## 🤝 Contributing

This is a training lab environment. For issues or improvements:

1. Test changes on a single team first
2. Update documentation
3. Commit with descriptive messages
4. Ensure compatibility with vendor approach

## 📧 Support

- **Lab Issues**: Check [LAB_GUIDE.md](LAB_GUIDE.md) troubleshooting section
- **Instructor Questions**: See [docs/INSTRUCTOR_GUIDE.md](docs/INSTRUCTOR_GUIDE.md)
- **Technical Details**: Review [docs/](docs/) directory

## 📝 License

Internal training use only.

---

**Ready to start?** → **[Click here to begin!](START_HERE.md)** ⭐
