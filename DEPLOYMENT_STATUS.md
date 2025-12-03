# AppDynamics VA Deployment - AWS Infrastructure Complete

**Date**: December 3, 2025  
**Status**: ✅ AWS Infrastructure Deployed Successfully

---

## ✅ Deployment Summary

### Virtual Machines (3 Nodes)

| VM Name | Instance ID | Private IP | Public IP | Status |
|---------|-------------|------------|-----------|--------|
| appdva-vm-1 | i-07efdcf48080a392c | 10.0.0.103 | 44.232.63.139 | ✅ Running |
| appdva-vm-2 | i-0db2c8c6ed09a235f | 10.0.0.56 | 54.244.130.46 | ✅ Running |
| appdva-vm-3 | i-0cba6c10c4ac9b7ca | 10.0.0.177 | 52.39.239.130 | ✅ Running |

**Instance Type**: m5a.4xlarge (16 vCPUs, 64 GB RAM per node)  
**AMI**: ami-092d9aa0e2874fd9c (appd-va-25.4.0.2016-ec2-disk1)  
**Region**: us-west-2

### Network Configuration

- **VPC**: vpc-092e8c8ba20e21e94 (10.0.0.0/16)
- **Subnet**: subnet-080c729506fb972c4 (10.0.0.0/24)
- **Security Group**: sg-0736e30e6145f20a6 (appd-va-sg-1)
- **Internet Gateway**: Configured
- **Route Table**: Configured with public internet access

### DNS Configuration

- **Domain**: splunkylabs.com (✅ Registered)
- **Hosted Zone**: Z06491142QTF1FNN8O9PR
- **Status**: ⏳ Domain registration in progress (5-15 minutes)
- **Tenant Name**: customer1

**DNS Records to be created:**
- `customer1.auth.splunkylabs.com`
- `customer1-tnt-authn.splunkylabs.com`
- `controller.splunkylabs.com`
- `*.splunkylabs.com` (wildcard)

### Storage

Each VM has:
- **OS Disk**: 200 GB (root volume)
- **Data Disk**: To be added in next step

---

## 🎯 Next Steps

### 1. Wait for Domain Registration (⏳ In Progress)

Monitor registration:
```bash
./monitor-domain-registration.sh
```

Or check manually in AWS Console:
- Route 53 → Registered Domains → splunkylabs.com

### 2. Create DNS Records

Once domain registration completes:

```bash
# Use VM 1's public IP as ingress
echo 'INGRESS_IP="44.232.63.139"' >> config.cfg

# Create DNS records
./09-aws-create-dns-records.sh
```

This will make your VMs accessible at:
- `https://customer1.auth.splunkylabs.com`
- `https://controller.splunkylabs.com`

### 3. SSH Access

Test SSH access to VMs:

```bash
# Default password is: changeme
ssh appduser@44.232.63.139   # VM 1
ssh appduser@54.244.130.46   # VM 2
ssh appduser@52.39.239.130   # VM 3
```

**Set up SSH keys for easier access:**
```bash
ssh-copy-id appduser@44.232.63.139
ssh-copy-id appduser@54.244.130.46
ssh-copy-id appduser@52.39.239.130
```

### 4. Bootstrap VMs

Configure each VM with network settings:

```bash
# On each VM, run:
sudo appdctl host init
# Enter: hostname, IP/CIDR, gateway, DNS
```

**Or use automation** (when ready):
```bash
cd post-deployment
cp config/deployment.conf.example config/deployment.conf
# Edit with VM IPs
./00-preflight-check.sh
./01-bootstrap-all-vms.sh
```

### 5. Create Cluster

On primary node (VM 1):
```bash
appdctl cluster init 10.0.0.56 10.0.0.177
```

### 6. Install AppDynamics Services

```bash
# Edit configuration files
cd /var/appd/config
sudo vi globals.yaml.gotmpl
sudo vi secrets.yaml

# Copy license
sudo cp license.lic /var/appd/config/

# Install services
appdcli start appd small
```

---

## 💰 Cost Estimate

### Running Costs

| Resource | Cost |
|----------|------|
| 3x m5a.4xlarge EC2 instances | ~$1,080/month |
| 3x 200GB EBS (OS disks) | ~$60/month |
| 3x Elastic IPs | ~$11/month |
| Domain (splunkylabs.com) | $13/year |
| Route 53 Hosted Zone | $0.50/month |
| **Total** | **~$1,151/month** |

### One-Time Costs

- Domain registration: $13 (paid)
- Snapshot storage: ~$1.50/month

**Note**: Remember to stop/terminate instances when not in use to avoid charges!

---

## 📋 Resources Created

### AWS Resources
- ✅ 3 EC2 Instances (m5a.4xlarge)
- ✅ 3 Elastic IPs
- ✅ 1 VPC
- ✅ 1 Subnet
- ✅ 1 Internet Gateway
- ✅ 1 Route Table
- ✅ 1 Security Group
- ✅ 1 AMI
- ✅ 1 EBS Snapshot
- ✅ 1 S3 Bucket
- ✅ 1 IAM Role (vmimport)
- ✅ 1 Route 53 Hosted Zone
- ⏳ 1 Domain Registration (in progress)

### Configuration Files
- ✅ config.cfg (updated)
- ✅ ami.id
- ✅ snapshot.id
- ✅ post-deployment/config/deployment.conf

### Scripts Created/Fixed
- ✅ 04-aws-import-iam-role.sh (fixed)
- ✅ 02b-aws-create-security-group.sh (created)
- ✅ 09-aws-create-dns-records.sh (created)
- ✅ monitor-domain-registration.sh (created)

---

## 🔐 Security Notes

### Current Configuration
- ⚠️ SSH (port 22) open to 0.0.0.0/0
- ⚠️ HTTP (port 80) open to 0.0.0.0/0
- ⚠️ HTTPS (port 443) open to 0.0.0.0/0
- ⚠️ Controller UI (port 8090) open to 0.0.0.0/0

### For Production
1. **Restrict security group** to specific IP ranges
2. **Use custom SSL certificates** (not self-signed)
3. **Change default password** on all VMs immediately
4. **Enable MFA** on AWS account
5. **Set up CloudWatch monitoring**
6. **Configure backup schedules**
7. **Implement disaster recovery**

---

## 🎓 For Your 20-Person Lab

Once DNS is configured, share these URLs with lab participants:

**Access URLs:**
- Controller: `https://controller.splunkylabs.com/controller`
- Auth: `https://customer1.auth.splunkylabs.com`

**Default Credentials:**
- Username: `admin`
- Password: `welcome` (change after first login!)

**No local configuration needed** - all participants can access via the domain!

---

## 📞 Troubleshooting

### Can't SSH to VMs
- Check security group allows your IP
- Verify Elastic IPs are associated
- Try: `ssh -v appduser@44.232.63.139` for debug info

### DNS Not Resolving
- Wait 5-10 minutes after creating records
- Check: `nslookup customer1.auth.splunkylabs.com`
- Verify nameservers are correct

### VMs Not Starting
- Check AWS Console → EC2 → Instances
- Review System Log in console
- Verify AMI is compatible with instance type

---

## ✅ Deployment Checklist

- [x] AWS Profile configured
- [x] VPC and networking created
- [x] S3 bucket created
- [x] IAM roles configured
- [x] AMI uploaded and registered
- [x] Security group created
- [x] 3 VMs deployed and running
- [x] Elastic IPs assigned
- [x] Domain registered (splunkylabs.com)
- [x] Hosted zone created
- [ ] Domain registration completed (⏳ waiting)
- [ ] DNS records created
- [ ] SSH access configured
- [ ] VMs bootstrapped
- [ ] Cluster created
- [ ] AppDynamics services installed

---

**Current Status**: Infrastructure complete, ready for AppDynamics installation once DNS is ready!
