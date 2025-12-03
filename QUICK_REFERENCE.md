# Quick Reference - AppDynamics AWS Lab

**Common commands and information for quick access during the lab.**

---

## 🚀 Main Scripts (Run in Order)

```bash
# 1. Deploy infrastructure (~10 min)
./lab-deploy.sh config/team1.cfg

# 2. Bootstrap VMs (~5 min)
./appd-bootstrap-vms.sh config/team1.cfg

# 3. Create cluster (~5 min)
./appd-create-cluster.sh config/team1.cfg

# 4. Configure AppDynamics (~3 min)
./appd-configure.sh config/team1.cfg

# 5. Install services (~30 min)
./appd-install.sh config/team1.cfg

# 6. Check health
./appd-check-health.sh config/team1.cfg

# 7. Cleanup (when done)
./lab-cleanup.sh config/team1.cfg
```

---

## 🔗 URLs (Team 1 Example)

| Service | URL |
|---------|-----|
| Controller | https://controller-team1.splunkylabs.com/controller/ |
| Events | https://controller-team1.splunkylabs.com/events |
| EUM Aggregator | https://controller-team1.splunkylabs.com/eumaggregator |
| Auth Service | https://team1.auth.splunkylabs.com |

**Default Login:**
- Username: `admin`
- Password: `welcome`

---

## 💻 SSH Access

```bash
# Get IPs from deployment output or check AWS console

# VM1 (Primary - use for cluster commands)
ssh appduser@<vm1-ip>

# VM2
ssh appduser@<vm2-ip>

# VM3
ssh appduser@<vm3-ip>
```

**Default password:** `changeme` (or check with instructor)

---

## 🔍 Verification Commands

### On Your Laptop
```bash
# Check VPN
curl ifconfig.me
# Should show: 151.186.*

# Check AWS access
aws sts get-caller-identity

# Check DNS
nslookup controller-team1.splunkylabs.com

# Check health
./appd-check-health.sh config/team1.cfg
```

### On VMs (via SSH)
```bash
# Check bootstrap status
appdctl show boot

# Check cluster status
appdctl show cluster

# Verify MicroK8s
microk8s status

# Check services
appdcli ping

# List all pods
kubectl get pods --all-namespaces

# Check specific namespace
kubectl get pods -n cisco-controller
kubectl get pods -n cisco-aiops
kubectl get pods -n cisco-secureapp

# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods --all-namespaces
```

---

## 🐛 Troubleshooting

### SSH Timeout
```bash
# Verify VPN
curl ifconfig.me  # Should show 151.186.*

# Check instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Team,Values=team1" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,PublicIpAddress,State.Name]" \
  --output table
```

### DNS Not Resolving
```bash
# Wait 2-3 minutes for DNS propagation

# Check hosted zone
aws route53 list-hosted-zones

# Flush local DNS cache (Mac)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Flush local DNS cache (Windows)
ipconfig /flushdns
```

### Service Not Starting
```bash
# Check pod status
kubectl get pods -n cisco-controller

# Check pod logs
kubectl logs <pod-name> -n cisco-controller

# Check node resources
kubectl top nodes

# Restart pod (if needed)
kubectl delete pod <pod-name> -n cisco-controller
```

### Installation Failed
```bash
# SSH to VM1
ssh appduser@<vm1-ip>

# Retry installation
appdcli start appd small

# Check for permission errors
ls -la /var/appd/config/secrets.yaml

# Fix permissions if needed
sudo chmod 644 /var/appd/config/secrets.yaml
```

---

## 📊 Resource Information

### EC2 Instances
- **Type:** m5a.4xlarge
- **vCPUs:** 16
- **RAM:** 64 GB
- **Storage:** 200 GB (gp3)
- **Cost:** ~$1.07/hour per instance

### Per Team Total
- **Instances:** 3x m5a.4xlarge
- **Cost:** ~$3.20/hour
- **Monthly (24/7):** ~$2,304

### All 5 Teams
- **Total Cost:** ~$16/hour
- **Lab Duration (4 hours):** ~$64

---

## 🔧 Useful AWS Commands

```bash
# List running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,Tags[?Key=='Name'].Value|[0],PublicIpAddress]" \
  --output table

# List VPCs
aws ec2 describe-vpcs \
  --query "Vpcs[].[VpcId,CidrBlock,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# List load balancers
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[].[LoadBalancerName,DNSName,State.Code]" \
  --output table

# Check DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z06491142QTF1FNN8O9PR \
  --query "ResourceRecordSets[?contains(Name, 'team1')]" \
  --output table
```

---

## 📋 Configuration Files

### Team Configs
- `config/team1.cfg` - Team 1 configuration
- `config/team2.cfg` - Team 2 configuration
- `config/team3.cfg` - Team 3 configuration
- `config/team4.cfg` - Team 4 configuration
- `config/team5.cfg` - Team 5 configuration

### Key Settings (per team)
```bash
TEAM_NAME="Team 1"
TEAM_NUMBER=1
VPC_CIDR="10.1.0.0/16"
DNS_SUBDOMAIN="team1"
CONTROLLER_SUBDOMAIN="controller-team1"
```

---

## 🎯 Service Status Check

```bash
# Quick check all services
ssh appduser@<vm1-ip> "appdcli ping"

# Expected output:
# Controller        ✅ Success
# Events            ✅ Success  
# EUM Collector     ✅ Success
# EUM Aggregator    ✅ Success
# Anomaly Detection ✅ Success
# SecureApp         ✅ Success
# ATD               ✅ Success
```

---

## 🗑️ Cleanup

```bash
# Delete all team resources
./lab-cleanup.sh config/team1.cfg

# Verify deletion
aws ec2 describe-instances \
  --filters "Name=tag:Team,Values=team1" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" \
  --output table
```

---

## 📱 Contact

**During Lab:**
- Instructor assistance
- Check TROUBLESHOOTING.md
- AWS Console for resource status

**After Lab:**
- Document issues encountered
- Collect feedback
- Review learning objectives

---

**Quick Tip:** Bookmark this page for easy reference during the lab! 🔖
