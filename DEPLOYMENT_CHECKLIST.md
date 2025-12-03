# Pre-Deployment Checklist

Before deploying a team infrastructure, verify all prerequisites:

## ✅ Prerequisites Checklist

### 1. AWS Environment
- [ ] AWS CLI installed and configured
- [ ] AWS credentials set up (via `aws configure` or environment variables)
- [ ] Sufficient AWS service limits:
  - [ ] EC2: Can launch 3x m5a.4xlarge instances
  - [ ] VPC: Can create 1 more VPC
  - [ ] EIP: Can allocate 3 Elastic IPs
  - [ ] ALB: Can create 1 Application Load Balancer

### 2. Network Access
- [ ] Connected to Cisco VPN
- [ ] Current IP shown by `curl ifconfig.me` starts with `151.186.*`
- [ ] VPN IP included in config files (already done ✅)

### 3. Domain & DNS
- [ ] Domain registered: `splunkylabs.com` (✅ Done)
- [ ] Route 53 hosted zone exists
- [ ] Hosted Zone ID known: `Z06491142QTF1FNN8O9PR`

### 4. AMI Preparation
- [ ] AMI imported to AWS (snap-095a1ccef15549269 ✅)
- [ ] AMI registered (ami-XXXXX - need to verify)
- [ ] AMI ID added to team config files

### 5. Configuration Files
- [ ] Team config exists: `config/team1.cfg` (✅ Done)
- [ ] VPN IPs configured in config (✅ Done)
- [ ] Team-specific values set:
  - [ ] TEAM_NAME="team1"
  - [ ] TEAM_NUMBER=1
  - [ ] VPC_CIDR="10.1.0.0/16"
  - [ ] DNS_SUBDOMAIN="team1"

### 6. Deployment Scripts
- [ ] All scripts executable: `chmod +x *.sh scripts/*.sh`
- [ ] `lab-deploy.sh` exists and tested
- [ ] Helper scripts in `scripts/` directory

### 7. AppDynamics Resources
- [ ] License file obtained (license.lic)
- [ ] License file ready to upload to VMs

---

## 🚀 Ready to Deploy?

If all items above are checked, you're ready to deploy:

```bash
# Deploy Team 1 infrastructure
./lab-deploy.sh config/team1.cfg
```

**Deployment time:** ~10-15 minutes

**What gets created:**
- VPC: 10.1.0.0/16
- Subnet: 10.1.0.0/24
- Security Groups (with VPN access)
- 3x EC2 instances (m5a.4xlarge)
- 3x Elastic IPs
- Application Load Balancer
- SSL Certificate (AWS ACM)
- DNS Records:
  - controller-team1.splunkylabs.com
  - team1.auth.splunkylabs.com
  - team1-tnt-authn.splunkylabs.com

---

## ⚠️ Important Notes

### Current Infrastructure
You already have a **reference cluster** running:
- VMs: 44.232.63.139, 54.244.130.46, 52.39.239.130
- VPC: vpc-092e8c8ba20e21e94
- This is separate from team infrastructures

### Team Infrastructure
Each team deployment creates **completely isolated** resources:
- Different VPC
- Different instances
- Different URLs
- No conflicts with reference cluster

### Cost Awareness
Running multiple environments simultaneously:
- Reference cluster: 3x m5a.4xlarge (~$3.20/hr)
- Team1 cluster: 3x m5a.4xlarge (~$3.20/hr)
- **Total: ~$6.40/hr** if both running

Consider stopping reference cluster before deploying teams.

---

## 🔍 Verify Before Deploying

```bash
# Check AWS access
aws sts get-caller-identity

# Check VPN
curl ifconfig.me

# Verify config
cat config/team1.cfg | grep -E "TEAM|VPC|DNS"

# Check AMI
aws ec2 describe-images --owners self --query "Images[*].[ImageId,Name,State]" --output table
```

---

## 📋 Post-Deployment Steps

After deployment completes:

1. **Note the IPs** (script will output them)
2. **Test SSH**: `ssh appduser@<vm1-ip>`
3. **Bootstrap VMs**: `./appd-bootstrap-vms.sh config/team1.cfg`
4. **Create Cluster**: `./appd-create-cluster.sh config/team1.cfg`
5. **Configure AppD**: `./appd-configure.sh config/team1.cfg`
6. **Install Services**: `./appd-install.sh config/team1.cfg`
7. **Check Health**: `./appd-check-health.sh config/team1.cfg`

---

**Ready? Let's deploy! 🚀**
