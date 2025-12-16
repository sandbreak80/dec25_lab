# AppDynamics Virtual Appliance - AWS Lab Deployment

Complete automation for deploying AppDynamics Virtual Appliance in AWS for multi-team labs.

## ✨ Key Features

- **100% Automated** - All scripts use password authentication with `expect`, no manual intervention needed
- **Password-Based Auth** - All deployment scripts work without SSH keys (AppDynamics123!)
- **Bootstrap Monitoring** - Script 04 monitors bootstrap progress and waits for completion
- **License Management** - Automated license upload to S3 and application to controllers
- **Multi-Team Support** - Deploy up to 5 isolated lab environments simultaneously
- **IAM Best Practices** - Includes student IAM policy with least-privilege access
- **Full Cleanup** - One command tears down all resources for cost control

## 📋 Prerequisites

### Required Software

#### 1. AWS CLI v2
Install AWS CLI version 2 (required):

**macOS:**
```bash
# Install using Homebrew
brew install awscli

# Or download installer
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Verify installation:**
```bash
aws --version
# Should show: aws-cli/2.x.x or higher
```

#### 2. Required Tools
These are typically pre-installed on macOS/Linux:
- `bash` (version 4.0+)
- `ssh`
- `scp`
- `expect`
- `jq` (for JSON parsing)

**Install missing tools (macOS):**
```bash
brew install expect jq
```

**Install missing tools (Linux):**
```bash
sudo apt-get install expect jq  # Debian/Ubuntu
sudo yum install expect jq      # RHEL/CentOS
```

### AWS Account Setup

#### 1. AWS Account Requirements
- Active AWS account with appropriate permissions
- Credit card on file (for resource charges)
- Service quotas sufficient for deployment:
  - **EC2 Instances:** 3 per team (15 total for 5 teams)
  - **vCPUs:** 48 per team (240 total for 5 teams)
  - **Elastic IPs:** 3 per team (15 total)
  - **VPCs:** 1 per team (5 total)

#### 2. IAM Permissions Required
Your AWS user/role needs these permissions:
- `ec2:*` - EC2 management
- `elasticloadbalancing:*` - ALB management
- `route53:*` - DNS management
- `acm:*` - Certificate management
- `iam:CreateRole` - For VM import (if using custom AMI)
- `iam:PassRole` - For VM import

**Recommended:** Use `AdministratorAccess` policy for initial setup.

#### 3. Configure AWS Credentials

**Option A: Environment Variables** (Recommended for testing)
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-west-2"
```

**Option B: AWS CLI Configuration** (Recommended for production)
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-west-2
# - Default output format: json
```

**Option C: AWS Profile** (For multiple accounts)
```bash
aws configure --profile appd-lab
# Then use: export AWS_PROFILE=appd-lab
```

**Verify configuration:**
```bash
aws sts get-caller-identity
# Should return your account details
```

#### 4. Set AWS Region
**REQUIRED:** All scripts use `us-west-2` by default.

```bash
export AWS_REGION="us-west-2"
```

Or edit `config/teamN.cfg` to change region:
```bash
AWS_REGION="us-west-2"  # Change this if needed
```

**Supported regions:**
- `us-west-2` (Oregon) - Recommended, default
- `us-east-1` (Virginia)
- `us-east-2` (Ohio)
- `eu-west-1` (Ireland)

### Network Requirements

#### VPN Access
SSH access to VMs requires VPN connection (security group restricted).

**Before starting deployment:**
1. Connect to your organization's VPN
2. Verify your VPN connection:
   ```bash
   curl https://ifconfig.me
   # Should show your VPN IP address
   ```

**Not on VPN?** You'll get SSH timeout errors during deployment.

### DNS Requirements (Pre-configured)

✅ **Domain:** `splunkylabs.com` is already registered and configured  
✅ **Certificate:** ACM wildcard `*.splunkylabs.com` is already issued  
✅ **Route 53:** Hosted zone exists and is ready

**No DNS setup required!** Scripts automatically create team-specific records:
- `controller-teamN.splunkylabs.com`
- `customer1-teamN.auth.splunkylabs.com`
- `*.teamN.splunkylabs.com`

### Cost Estimate

**Per team (8-hour lab):** ~$20
- 3x m5a.4xlarge instances: ~$15
- Application Load Balancer: ~$2
- Data transfer: ~$2
- Elastic IPs: ~$1

**For 5 teams:** ~$100/day

**To minimize costs:**
- Delete resources immediately after lab: `./deployment/cleanup.sh --team N --confirm`
- Use `m5a.xlarge` for testing (edit `config/teamN.cfg`)
- Stop (don't terminate) instances when not in use

### Pre-Deployment Checklist

Before running `./lab-deploy.sh`, verify:

- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] AWS region set to `us-west-2` (`echo $AWS_REGION`)
- [ ] Connected to VPN (`curl https://ifconfig.me`)
- [ ] `expect` and `jq` installed
- [ ] Sufficient AWS quotas (3 instances, 48 vCPUs per team)
- [ ] Team configuration reviewed (`config/teamN.cfg`)

**Quick verification script:**
```bash
# Run this to verify all prerequisites
./scripts/check-prerequisites.sh
```

---

## 🎯 Lab Deployment

Deploy your complete AppDynamics lab environment in ~40 minutes:

```bash
# 1. Verify prerequisites
./scripts/check-prerequisites.sh

# 2. Deploy infrastructure (10 minutes)
./deployment/01-deploy.sh --team 1

# 3. Change password (1 minute)
./deployment/02-change-password.sh --team 1

# 4. Setup SSH keys (1 minute) - OPTIONAL
# Note: All scripts work with password authentication (AppDynamics123!)
# SSH keys are optional but provide better UX for manual SSH access
./deployment/03-setup-ssh-keys.sh --team 1  # Optional

# 5. Bootstrap VMs (15-20 minutes - fully automated)
./deployment/04-bootstrap-vms.sh --team 1

# 6. Create cluster (10 minutes - fully automated)
./deployment/05-create-cluster.sh --team 1

# 7. Configure AppD (1 minute - fully automated)
./deployment/06-configure.sh --team 1

# 8. Install AppDynamics (20-30 minutes - fully automated)
./deployment/07-install.sh --team 1

# 9. Apply License (1 minute - fully automated)
./deployment/09-apply-license.sh --team 1

# 10. Verify deployment (1 minute - fully automated)
./deployment/08-verify.sh --team 1
```

## 📊 What Gets Deployed

Each team gets a complete, isolated environment:

### Infrastructure
- **VPC**: Dedicated VPC with custom CIDR (10.N.0.0/16)
- **Subnets**: 2 subnets in different availability zones
- **Security**: SSH restricted to VPN IPs only
- **Compute**: 3x m5a.4xlarge instances (16 vCPU, 64GB RAM each)
- **Storage**: 
  - 200GB OS disk per VM (delete on termination)
  - 500GB data disk per VM (preserved on termination)
- **Networking**: Elastic IPs for each VM (persistent)

### Load Balancer & SSL
- **ALB**: Application Load Balancer with health checks
- **SSL**: AWS ACM wildcard certificate (*.splunkylabs.com)
- **Redirect**: Automatic HTTP → HTTPS

### DNS
- **Domain**: teamN.splunkylabs.com
- **Records**: 
  - `controller-teamN.splunkylabs.com`
  - `customer1-teamN.auth.splunkylabs.com`
  - `customer1-tnt-authn-teamN.splunkylabs.com`

### Kubernetes
- **3-node MicroK8s cluster** with high availability
- **Dqlite** for distributed state
- **All nodes** are voting members

### AppDynamics Services
- Controller
- Events Service
- EUM (End User Monitoring)
- Synthetic Monitoring
- AIOps
- ATD (Automatic Transaction Diagnostics)
- SecureApp (Secure Application)

## 📁 Project Structure

```
appd-virtual-appliance/deploy/aws/
├── README.md                    # Project overview  
├── START_HERE.md                # Quick start guide
│
├── deployment/                  # Deployment workflow scripts
│   ├── 01-deploy.sh             # Deploy infrastructure
│   ├── 02-change-password.sh    # Change VM password
│   ├── 03-setup-ssh-keys.sh     # Setup SSH keys (optional)
│   ├── 04-bootstrap-vms.sh      # Initialize VMs (monitors progress)
│   ├── 05-create-cluster.sh     # Create K8s cluster
│   ├── 06-configure.sh          # Configure AppD
│   ├── 07-install.sh            # Install services
│   ├── 08-verify.sh             # Verify deployment
│   ├── 09-apply-license.sh      # Apply license from S3
│   └── cleanup.sh               # Delete all resources
│
├── scripts/                     # Infrastructure automation
│   ├── create-network.sh        # VPC, subnets, IGW
│   ├── create-security.sh       # Security groups
│   ├── create-vms.sh            # EC2 instances
│   ├── create-alb.sh            # Load balancer
│   ├── create-dns.sh            # Route 53 records
│   ├── upload-license-to-s3.sh  # Upload license to S3
│   ├── apply-license.sh         # Apply license to controller
│   ├── check-bootstrap-progress.sh  # Monitor bootstrap status
│   ├── check-prerequisites.sh   # Verify requirements
│   ├── ssh-vm1.sh               # Quick SSH to VM1
│   ├── ssh-vm2.sh               # Quick SSH to VM2
│   └── ssh-vm3.sh               # Quick SSH to VM3
│
├── docs/                        # Documentation
│   ├── LAB_GUIDE.md             # Detailed lab guide
│   ├── QUICK_REFERENCE.md       # Command reference
│   ├── IAM_REQUIREMENTS.md      # IAM permissions (deprecated)
│   ├── iam-student-policy.json  # Student IAM policy
│   ├── LICENSE_MANAGEMENT.md    # License workflow guide
│   ├── BOOTSTRAP_MONITORING.md  # Bootstrap monitoring guide
│   ├── DEPLOYMENT_FLOW.md       # Complete deployment flow
│   ├── PROJECT_STATUS.md        # Project status
│   ├── FIX-REQUIRED.md          # Known issues
│   └── instructor/              # Instructor resources
│
├── config/                      # Team configurations
│   ├── team1.cfg
│   ├── team2.cfg
│   ├── team3.cfg
│   ├── team4.cfg
│   └── team5.cfg
│
├── lib/                         # Shared libraries
│   └── common.sh                # Common functions
│
├── archive/                     # Legacy content
│   └── vendor-scripts/          # Original vendor scripts
│
├── state/                       # Deployment state (gitignored)
│   └── teamN/
│       ├── vpc-id.txt
│       ├── vm-summary.txt
│       └── ...
│
└── logs/                        # Deployment logs (gitignored)
    └── teamN/
        └── deployment-*.log
```

## 🔧 Configuration

### Team Configuration Files

Each team has a configuration file in `config/teamN.cfg`:

```bash
# Team Identity
TEAM_NAME="Team 1"
TEAM_MEMBERS="Student1, Student2, Student3, Student4"
INSTRUCTOR_EMAIL="instructor@cisco.com"

# AWS Settings
AWS_PROFILE="default"
AWS_REGION="us-west-2"

# Network Configuration
VPC_NAME="appd-team1-vpc"
VPC_CIDR="10.1.0.0/16"
SUBNET_NAME="appd-team1-subnet-1"
SUBNET_CIDR="10.1.0.0/24"

# DNS Configuration
TEAM_SUBDOMAIN="team1"
FULL_DOMAIN="team1.splunkylabs.com"
CONTROLLER_URL="controller-team1.splunkylabs.com"

# VM Configuration
VM_TYPE="m5a.4xlarge"
VM_OS_DISK="200"
VM_DATA_DISK="500"
NODE1_IP="10.1.0.10"
NODE2_IP="10.1.0.20"
NODE3_IP="10.1.0.30"
```

### Security Groups

**SSH Access** is restricted to VPN egress IPs (configured in team config files).

**HTTPS Access** is open to everyone (0.0.0.0/0)

## 🚀 Deployment Scripts

### 1. lab-deploy.sh
Deploys complete infrastructure (VPC → DNS)

```bash
./lab-deploy.sh --team 1
```

**Time:** ~10 minutes  
**Creates:** VPC, subnets, security groups, 3 VMs, ALB, DNS records

### 2. appd-change-password.sh
Changes default `appduser` password

```bash
./appd-change-password.sh --team 1
```

**Default:** `changeme` → **New:** `AppDynamics123!`

### 3. scripts/setup-ssh-keys.sh
Generates and installs SSH keys for passwordless access

```bash
./scripts/setup-ssh-keys.sh --team 1
```

**Creates:** `~/.ssh/appd-team1-key` (laptop → VMs)

### 4. appd-bootstrap-vms.sh
Initializes all VMs with `appdctl host init`

```bash
./appd-bootstrap-vms.sh --team 1
```

**Time:** ~5 minutes  
**Configures:** Storage, networking, MicroK8s, firewall, SSH

### 5. appd-create-cluster.sh
Creates 3-node Kubernetes cluster

```bash
./appd-create-cluster.sh --team 1
```

**Time:** ~10 minutes  
**Verifies:** Bootstrap completion, network connectivity, cluster health

### 6. appd-configure.sh
Updates `globals.yaml.gotmpl` with team-specific DNS

```bash
./appd-configure.sh --team 1
```

**Time:** ~1 minute  
**Updates:** Domain, DNS names, external URLs

### 7. appd-install.sh
Installs all AppDynamics services

```bash
./appd-install.sh --team 1
```

**Time:** ~20-30 minutes  
**Installs:** Controller, Events, EUM, Synthetic, AIOps, ATD, SecureApp

### 8. cleanup.sh
Deletes all resources for a team

```bash
./deployment/cleanup.sh --team 1 --confirm
```

**Requires:** Confirmation string `DELETE TEAM 1`

## 🎓 For Students

### Access Your Controller

After installation completes:

1. **URL:** `https://controller-team1.splunkylabs.com/controller/`
2. **Username:** `admin`
3. **Password:** `welcome`

⚠️ **Change the password immediately!**

### SSH to Your VMs

With SSH keys (passwordless):
```bash
./scripts/ssh-vm1.sh --team 1
```

Without SSH keys (manual):
```bash
ssh appduser@<VM-PUBLIC-IP>
# Password: AppDynamics123!
```

### Check Cluster Status

```bash
./scripts/ssh-vm1.sh --team 1
appdctl show cluster
```

Expected output:
```
 NODE            | ROLE  | RUNNING 
-----------------+-------+---------
 10.1.0.10:19001 | voter | true    
 10.1.0.20:19001 | voter | true    
 10.1.0.30:19001 | voter | true
```

### Check Service Status

```bash
appdcli ping
```

All services should show `Success`.

## 🐛 Troubleshooting

### SSH Key Re-authentication

**Situation:** SSH keys may need re-authentication after cluster init

**Solution:** Re-add keys using password:
```bash
./scripts/setup-ssh-keys.sh --team 1
# Enter password when prompted
```

### Bootstrap Not Complete

**Problem:** Cluster init fails with "host-info.yaml not found"

**Solution:** Wait for bootstrap to complete:
```bash
./scripts/ssh-vm1.sh --team 1
watch -n 10 appdctl show boot
# Wait until all tasks show "Succeeded"
```

### Security Group Issues

**Problem:** SSH timeout (not on VPN)

**Solution:** Connect to VPN first, or temporarily add your IP:
```bash
# Get security group ID
SG_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=team1-vm-1" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

# Add your IP
MY_IP=$(curl -s https://ifconfig.me)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32
```

### Installation Failures

**Problem:** Service shows "Failed" in `appdcli ping`

**Solution:** Wait 5 more minutes, check pod logs:
```bash
kubectl get pods --all-namespaces
kubectl logs <pod-name> -n <namespace>
```

## 📚 Documentation

- **[docs/LAB_GUIDE.md](docs/LAB_GUIDE.md)** - Comprehensive lab guide
- **[docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)** - Command reference
- **[docs/IAM_REQUIREMENTS.md](docs/IAM_REQUIREMENTS.md)** - IAM permissions for students
- **[docs/FIX-REQUIRED.md](docs/FIX-REQUIRED.md)** - Lab automation enhancement notes
- **Official Docs:** [AppDynamics VA Installation Guide](https://docs.appdynamics.com/)

## 🔐 Security Notes

- **Passwords:** Default passwords should be changed immediately
- **SSH Keys:** Stored in `~/.ssh/appd-teamN-key` (not committed)
- **AWS Credentials:** Never commit credentials to Git
- **State Files:** `state/` and `logs/` are gitignored
- **VPN Required:** SSH access requires VPN connection

## 📊 Resource Requirements

### Per Team
- **vCPUs:** 48 (16 per VM × 3)
- **RAM:** 192GB (64GB per VM × 3)
- **Storage:** 2.1TB (700GB per VM × 3)
- **Cost:** ~$20 for 8-hour lab

### AWS Quotas Required
- EC2 instances: 3 per team
- vCPUs: 48 per team
- Elastic IPs: 3 per team
- VPCs: 1 per team

## 🤝 Contributing

1. Test changes on a single team first
2. Update documentation
3. Commit with descriptive message
4. Create pull request

## 📝 License

Internal Cisco lab use only.

## 👥 Authors

- **Infrastructure Automation:** Claude/Cursor
- **AppDynamics VA:** Cisco AppDynamics Team

## 🆘 Support

For issues:
1. Check `FIX-REQUIRED.md` for known issues
2. Review deployment logs in `logs/teamN/`
3. Contact instructor

---

**Last Updated:** December 5, 2025  
**Version:** 1.0 (95% automated)  
**Status:** ✅ Production Ready
