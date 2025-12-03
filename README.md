# AppDynamics Virtual Appliance - Multi-Team Lab

**Production-grade AppDynamics deployment on AWS for 20-person training lab**

---

## 🎯 What Is This?

Complete, tested solution for deploying AppDynamics Virtual Appliance in AWS with support for **5 isolated teams** (20 students total). Each team builds their own production-grade infrastructure from scratch.

### Key Features
- ✅ **5 isolated environments** (separate VPCs, domains, resources)
- ✅ **Production architecture** (ALB + ACM SSL + Route 53)
- ✅ **Fixed vendor issues** (31 documented problems resolved)
- ✅ **Automated deployment** (single command per team)
- ✅ **Complete documentation** (student guides, troubleshooting, references)
- ✅ **Cost optimized** (~$20 per team for 8-hour lab)

---

## 👥 Who Is This For?

### Students
Learn production AWS skills by building real infrastructure:
- AWS networking (VPC, subnets, routing, security groups)
- EC2 instance management
- Load balancing with SSL/TLS
- DNS configuration
- Kubernetes cluster administration
- Enterprise software deployment

### Instructors
Run effective hands-on labs:
- Proven architecture and scripts
- Comprehensive troubleshooting guides
- Per-team cost tracking
- Automated cleanup
- Scalable to more teams

---

## 🚀 Quick Start

### For Students

```bash
# 1. Clone repository
git clone <repo-url>
cd appd-virtual-appliance/deploy/aws

# 2. Set your team number (1-5)
export TEAM_NUMBER=1

# 3. Deploy everything
./lab-deploy.sh --team $TEAM_NUMBER

# 4. Follow the prompts
# Wait ~30 minutes for deployment

# 5. Check status
./scripts/check-status.sh --team $TEAM_NUMBER

# 6. SSH to primary VM
./scripts/ssh-vm1.sh --team $TEAM_NUMBER

# 7. At end of day: cleanup
./lab-cleanup.sh --team $TEAM_NUMBER --confirm
```

**Full instructions:** [docs/QUICK_START.md](docs/QUICK_START.md)

### For Instructors

**Pre-Lab Setup (1 day before):**
1. Request ACM wildcard certificate (`*.splunkylabs.com`)
2. Create IAM users/roles for 5 teams
3. Upload shared AMI to S3
4. Review `lab-guide/00-INSTRUCTOR-SETUP.md`

**Lab Day:**
1. Distribute credentials to teams
2. Monitor progress with `instructor/monitor-all-teams.sh`
3. Assist with troubleshooting
4. Run cleanup verification at end

**Full instructions:** [lab-guide/00-INSTRUCTOR-SETUP.md](lab-guide/00-INSTRUCTOR-SETUP.md)

---

## 📁 Project Structure

```
deploy/aws/
├── lab-deploy.sh                # Main deployment script
├── lab-cleanup.sh               # Cleanup script
│
├── config/                      # Team configurations
│   ├── team1.cfg
│   ├── team2.cfg
│   ├── team3.cfg
│   ├── team4.cfg
│   └── team5.cfg
│
├── scripts/                     # Helper scripts
│   ├── create-network.sh       # VPC, subnets, IGW
│   ├── create-security.sh      # Security groups
│   ├── create-vms.sh           # EC2 instances
│   ├── create-alb.sh           # Load balancer + SSL
│   ├── create-dns.sh           # Route 53 records
│   ├── verify-deployment.sh    # Health checks
│   ├── check-status.sh         # Status dashboard
│   └── ssh-vm1.sh              # SSH helper
│
├── lib/                         # Common functions
│   └── common.sh               # Shared utilities
│
├── docs/                        # Student documentation
│   ├── QUICK_START.md          # Getting started guide
│   ├── QUICK_REFERENCE.md      # Command reference
│   └── TROUBLESHOOTING.md      # Common issues
│
├── lab-guide/                   # Instructor documentation
│   └── 00-INSTRUCTOR-SETUP.md  # Pre-lab setup
│
└── Reference Documentation:
    ├── README.md               # This file
    ├── MULTI_TEAM_LAB_ARCHITECTURE.md
    ├── VENDOR_DOC_ISSUES.md    # 31 vendor issues fixed
    ├── LAB_GUIDE.md            # Complete reference
    └── OPTIONAL_SERVICES_GUIDE.md
```

---

## 🏗️ Architecture

### Per-Team Infrastructure

Each team gets completely isolated environment:

```
Team N (1-5)
├── VPC: 10.N.0.0/16
├── Subnets: 2 (multi-AZ for ALB)
├── Internet Gateway
├── Security Groups (VM + ALB)
├── EC2 Instances: 3 × m5a.4xlarge
│   ├── VM1: 10.N.0.10 (primary)
│   ├── VM2: 10.N.0.11
│   └── VM3: 10.N.0.12
├── Application Load Balancer
│   ├── Target Group → 3 VMs
│   ├── HTTPS Listener (ACM cert)
│   └── HTTP→HTTPS Redirect
└── DNS: teamN.splunkylabs.com
    ├── controller-teamN.splunkylabs.com
    ├── customer1-teamN.auth.splunkylabs.com
    └── *.teamN.splunkylabs.com
```

### SSL/TLS

**Single ACM wildcard certificate covers all teams:**
- `*.splunkylabs.com` → All team subdomains
- Managed by AWS (auto-renewal)
- No certificate management required

### Network Flow

```
Student Browser
    ↓ HTTPS
Route 53 DNS (teamN.splunkylabs.com)
    ↓
Application Load Balancer
    ├─ ACM Certificate (*.splunkylabs.com)
    ├─ Health Checks (HTTPS /controller/)
    └─ SSL Termination
        ↓ HTTPS
    Target Group
        ├─ VM1 (healthy)
        ├─ VM2 (healthy)
        └─ VM3 (healthy)
            ↓
        AppDynamics Controller
```

---

## 💰 Cost Breakdown

### Per Team (8-hour lab)
| Resource | Cost |
|----------|------|
| 3 × EC2 m5a.4xlarge (8 hrs) | $16.51 |
| EBS Storage (2.1 TB, prorated) | $2.33 |
| Application Load Balancer | $0.18 |
| Data Transfer | ~$0.50 |
| **Total per team** | **~$19.52** |

### All 5 Teams
- **8-hour lab:** ~$97.60
- **24 hours (if left running):** ~$293
- **7 days (if left running):** ~$2,065 ⚠️

**💡 Key Point:** Cleanup is automatic and required!

---

## 🎓 Learning Objectives

Students gain hands-on experience with:

### AWS Services
- ✅ VPC design and CIDR planning
- ✅ Multi-AZ subnet architecture
- ✅ Internet Gateway and routing
- ✅ Security groups and network ACLs
- ✅ EC2 instance management
- ✅ EBS volume configuration
- ✅ Application Load Balancer
- ✅ Target groups and health checks
- ✅ AWS Certificate Manager (ACM)
- ✅ Route 53 DNS management
- ✅ IAM roles and policies

### Kubernetes
- ✅ Multi-node cluster creation
- ✅ MicroK8s administration
- ✅ Pod and service management
- ✅ Helm chart deployment
- ✅ Resource monitoring

### AppDynamics
- ✅ On-premises installation
- ✅ Cluster configuration
- ✅ Controller setup
- ✅ Service deployment
- ✅ Optional services (AIOps, ATD, SecureApp)
- ✅ Agent configuration

### DevOps Practices
- ✅ Infrastructure as Code
- ✅ Automation scripting
- ✅ Configuration management
- ✅ Troubleshooting methodologies
- ✅ Cost optimization
- ✅ Team collaboration

---

## 🔧 vs. Vendor Documentation

### Problems with Vendor Materials
- ❌ 31 critical issues in scripts/documentation
- ❌ Self-signed certificates (browser warnings)
- ❌ Direct VM exposure (no load balancer)
- ❌ No multi-team support
- ❌ No cleanup process
- ❌ No cost information
- ❌ Missing troubleshooting guidance

### Our Solution
- ✅ All issues fixed and documented
- ✅ Production-grade ACM SSL certificates
- ✅ Proper load balancing architecture
- ✅ Full multi-team isolation
- ✅ Automated cleanup
- ✅ Complete cost breakdowns
- ✅ Comprehensive troubleshooting guides

**See:** [VENDOR_DOC_ISSUES.md](VENDOR_DOC_ISSUES.md) for all 31 issues

---

## 📚 Documentation

### For Students
- **[QUICK_START.md](docs/QUICK_START.md)** - Start here!
- **[QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)** - Command cheat sheet
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues

### For Instructors
- **[INSTRUCTOR_SETUP.md](lab-guide/00-INSTRUCTOR-SETUP.md)** - Pre-lab guide
- **[MULTI_TEAM_LAB_ARCHITECTURE.md](MULTI_TEAM_LAB_ARCHITECTURE.md)** - Architecture details

### Technical Reference
- **[LAB_GUIDE.md](LAB_GUIDE.md)** - Complete deployment guide
- **[VENDOR_DOC_ISSUES.md](VENDOR_DOC_ISSUES.md)** - Known issues & fixes
- **[OPTIONAL_SERVICES_GUIDE.md](OPTIONAL_SERVICES_GUIDE.md)** - Advanced features

---

## 🆘 Support

### During Lab
1. Check documentation (most answers are there)
2. Use `./scripts/check-status.sh --team N`
3. Ask your team
4. Ask instructor

### Common Issues
All documented in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## ✅ Prerequisites

### For Students
- Laptop with SSH client
- AWS CLI installed
- Git installed
- Team assignment (1-5)
- AWS credentials (provided by instructor)

### For Instructors
- AWS account with appropriate limits
- Domain name (we use `splunkylabs.com`)
- ACM wildcard certificate
- IAM users/roles for teams
- Shared AMI in S3

---

## 🔄 Reusability

These materials are designed to be:

### Scalable
- Support 5 teams (current)
- Easily add teams 6-10 by creating new configs
- Can support 50+ students with more teams

### Adaptable
- Use for dev/staging/prod deployments
- Customize for different AppDynamics versions
- Adapt for other platforms

### Educational
- Clear documentation
- Well-commented scripts
- Learning-focused design

---

## 🚀 What Students Build

By end of lab, each team has:

- ✅ Production-grade AWS infrastructure
- ✅ 3-node Kubernetes cluster
- ✅ Load-balanced AppDynamics deployment
- ✅ SSL-secured web access
- ✅ Proper DNS configuration
- ✅ Monitoring and observability
- ✅ Real-world experience

---

## 📊 Success Metrics

Lab is successful when students can:
- ✅ Deploy complete infrastructure from command line
- ✅ Troubleshoot issues independently
- ✅ Access AppDynamics Controller via HTTPS
- ✅ Explain architecture decisions
- ✅ Clean up resources properly
- ✅ Apply skills to production scenarios

---

## 🙏 Acknowledgments

- Based on AppDynamics Virtual Appliance 25.4.0
- Vendor documentation issues identified and fixed
- Architecture designed for production use
- Tested with real student teams

---

## 📝 Version

- **Lab Version:** 1.0
- **AppDynamics Version:** 25.4.0.2016
- **Last Updated:** December 2025
- **Status:** Production Ready

---

## 📞 Contact

- **Instructor:** bmstoner@cisco.com
- **Lab Support:** #appd-lab-help (Slack)
- **Issues:** Document in repository

---

**Ready to run the lab?** Students start with [docs/QUICK_START.md](docs/QUICK_START.md)! 🚀
