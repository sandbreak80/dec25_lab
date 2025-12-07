# Quick Reference - AppDynamics AWS Lab

**Common commands for quick access during the lab.**

---

## 🚀 Deployment Commands (Run in Order)

```bash
# 1. Deploy infrastructure (~10 min)
./lab-deploy.sh --team 1

# 2. Change password (~1 min)
./appd-change-password.sh --team 1

# 3. Setup SSH keys (~1 min) - RECOMMENDED
./scripts/setup-ssh-keys.sh --team 1

# 4. Bootstrap VMs (~5 min + 15-20 min wait)
./appd-bootstrap-vms.sh --team 1

# 5. Verify bootstrap complete (wait 15-20 min after step 4)
./scripts/ssh-vm1.sh --team 1
appdctl show boot  # All should show "Succeeded"
exit

# 6. Create cluster (~10 min)
./appd-create-cluster.sh --team 1

# 7. Configure (~1 min)
./appd-configure.sh --team 1

# 8. Install (~20-30 min)
./appd-install.sh --team 1

# 9. Verify
./appd-check-health.sh --team 1

# 10. Cleanup (when done)
./lab-cleanup.sh --team 1 --confirm
```

---

## 🔗 URLs (Team 1 Example)

| Service | URL |
|---------|-----|
| Controller | https://controller-team1.splunkylabs.com/controller/ |
| Auth Service | https://customer1-team1.auth.splunkylabs.com/ |

**Default Login:**
- Username: `admin`
- Password: `welcome` (change immediately!)

---

## 💻 SSH Access

**Passwordless (after SSH key setup):**
```bash
./scripts/ssh-vm1.sh --team 1
./scripts/ssh-vm2.sh --team 1
./scripts/ssh-vm3.sh --team 1
```

**Manual SSH:**
```bash
# Get VM IPs from deployment
cat state/team1/vm-summary.txt

# SSH manually
ssh appduser@<VM-IP>
# Password: AppDynamics123!
```

---

## 🔍 Status Commands

**On VM (SSH into VM first):**
```bash
# Bootstrap status
appdctl show boot

# Cluster status
appdctl show cluster

# AppDynamics services
appdcli status
appdcli ping

# Kubernetes
microk8s status
kubectl get pods --all-namespaces
```

**From laptop:**
```bash
# Check deployment status
./scripts/check-status.sh --team 1

# Health check
./appd-check-health.sh --team 1

# View state files
ls -la state/team1/
cat state/team1/urls.txt
cat state/team1/vm-summary.txt
```

---

## 📊 Resource Information

**Per Team:**
- **VMs:** 3 × m5a.4xlarge
- **vCPUs:** 48 total (16 per VM)
- **RAM:** 192GB total (64GB per VM)
- **Storage:** 2.1TB total (700GB per VM)
- **Cost:** ~$20 for 8-hour lab

---

## 🛠 Troubleshooting

### SSH Connection Fails
```bash
# Verify VPN connection
curl ifconfig.me  # Should show your VPN IP address

# Re-setup SSH keys if broken
./scripts/setup-ssh-keys.sh --team 1
```

### Bootstrap Stuck
```bash
# Check bootstrap progress (on VM)
./scripts/ssh-vm1.sh --team 1
appdctl show boot
journalctl -u appd-bootstrap -f
```

### Cluster Init Fails
```bash
# Verify bootstrap completed first
./scripts/ssh-vm1.sh --team 1
appdctl show boot  # All must be "Succeeded"

# Check network connectivity
ping 10.1.0.20  # VM2 private IP
ping 10.1.0.30  # VM3 private IP
```

### Services Won't Start
```bash
# Check pod status
./scripts/ssh-vm1.sh --team 1
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Restart if needed
appdcli stop all
appdcli start all small
```

---

## 🧹 Cleanup Commands

**Full cleanup:**
```bash
./lab-cleanup.sh --team 1 --confirm
# Type: DELETE TEAM 1
```

**Manual cleanup (if script fails):**
```bash
# Delete VMs
aws ec2 terminate-instances --instance-ids $(cat state/team1/vm*.id)

# Delete load balancer
aws elbv2 delete-load-balancer --load-balancer-arn $(cat state/team1/alb.id)

# Delete VPC
aws ec2 delete-vpc --vpc-id $(cat state/team1/vpc.id)
```

---

## 📝 Configuration Files

**Team configs:**
```bash
config/team1.cfg  # Team 1
config/team2.cfg  # Team 2
...
```

**State files (per team):**
```bash
state/team1/vpc.id           # VPC ID
state/team1/vm-summary.txt   # VM IPs
state/team1/urls.txt         # Access URLs
state/team1/alb-dns.txt      # Load balancer DNS
```

---

## 🔐 Credentials

**VM Access:**
- User: `appduser`
- Initial password: `changeme`
- After change: `AppDynamics123!`

**Controller UI:**
- User: `admin`
- Password: `welcome` (change immediately!)

**AWS:**
- Configured via `aws configure`
- Region: `us-west-2`

---

## 📚 Additional Help

- **START_HERE.md** - Step-by-step deployment guide
- **LAB_GUIDE.md** - Detailed lab instructions
- **README.md** - Complete documentation
- **FIX-REQUIRED.md** - Known issues

---

**Need help?** Ask your instructor or check the troubleshooting section above.
