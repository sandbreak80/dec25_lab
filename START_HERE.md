# AppDynamics Lab - Quick Start Guide

## 🚀 First Time Setup (Do This FIRST!)

### Step 1: Create Your SSH Key

**IMPORTANT**: Every team must create their own SSH key before deploying infrastructure.

```bash
# Run this command with your team number (1-5)
./scripts/create-ssh-key.sh --team 1
```

**What this does:**
- Creates a new AWS EC2 key pair: `appd-lab-team1-key`
- Downloads private key to: `~/.ssh/appd-lab-team1-key.pem`
- Sets proper permissions (400)
- Updates your team config automatically

**Security Note**: 
- Do NOT commit this key to git (it's in `.gitignore`)
- Do NOT share your private key
- Each team gets their own unique key

---

## 📦 Step 2: Deploy Infrastructure

Once your SSH key is created, deploy your lab environment:

```bash
./lab-deploy.sh --team 1
```

**This takes ~30 minutes and creates:**
- ✅ VPC with 2 subnets
- ✅ 3 VMs (m5a.4xlarge: 16 vCPU, 64GB RAM each)
- ✅ Application Load Balancer
- ✅ SSL certificate (*.splunkylabs.com)
- ✅ DNS records (team1.splunkylabs.com)
- ✅ Security groups (SSH restricted to Cisco VPN)

---

## 🔐 Step 3: Connect to Your VMs

### Easy Method (Recommended)
Use the helper scripts:

```bash
# Connect to VM1 (primary node)
./scripts/ssh-vm1.sh --team 1

# Connect to VM2
./scripts/ssh-vm2.sh --team 1

# Connect to VM3
./scripts/ssh-vm3.sh --team 1
```

### Manual Method
```bash
ssh -i ~/.ssh/appd-lab-team1-key.pem appduser@<VM-IP>
```

---

## 🌐 Step 4: Access Web UI

After deployment completes and AppDynamics is installed:

```
Controller: https://controller-team1.splunkylabs.com/controller/
Username: admin
Password: welcome (change after first login)
```

---

## 🧹 Step 5: Cleanup (End of Lab)

**IMPORTANT**: Delete all resources to avoid charges!

```bash
./lab-cleanup.sh --team 1 --confirm
```

**Cost**: ~$2.50/hour = ~$20 for 8-hour lab day

---

## 🆘 Troubleshooting

### "SSH key not found" Error
```bash
# Re-run the SSH key creation script
./scripts/create-ssh-key.sh --team 1
```

### "Permission denied (publickey)" Error
```bash
# Check key permissions
ls -l ~/.ssh/appd-lab-team1-key.pem
# Should be: -r-------- (400)

# Fix if needed
chmod 400 ~/.ssh/appd-lab-team1-key.pem
```

### "Key already exists in AWS"
```bash
# Delete old key and recreate
aws ec2 delete-key-pair --key-name appd-lab-team1-key
./scripts/create-ssh-key.sh --team 1
```

### Can't SSH from home/non-VPN
SSH is restricted to Cisco VPN IPs only. Connect to VPN first!

---

## 📚 Full Documentation

- **Lab Guide**: `./docs/LAB_GUIDE.md` - Complete step-by-step instructions
- **Quick Reference**: `./docs/QUICK_REFERENCE.md` - Common commands
- **Instructor Guide**: `./INSTRUCTOR_GUIDE.md` - Setup and management

---

## 🔑 SSH Key Summary

| Team | Key Name | Key File Location |
|------|----------|-------------------|
| 1 | appd-lab-team1-key | `~/.ssh/appd-lab-team1-key.pem` |
| 2 | appd-lab-team2-key | `~/.ssh/appd-lab-team2-key.pem` |
| 3 | appd-lab-team3-key | `~/.ssh/appd-lab-team3-key.pem` |
| 4 | appd-lab-team4-key | `~/.ssh/appd-lab-team4-key.pem` |
| 5 | appd-lab-team5-key | `~/.ssh/appd-lab-team5-key.pem` |

**Remember**: Create your key BEFORE running `lab-deploy.sh`!
