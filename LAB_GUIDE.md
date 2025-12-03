# AppDynamics Virtual Appliance - Multi-Team AWS Lab

**Quick Start for Students** | **5-Team Lab Environment** | **Complete Deployment Automation**

---

## 🎯 Lab Overview

Deploy your own isolated AppDynamics cluster in AWS! Each team builds:
- ✅ 3 EC2 instances (AppDynamics Virtual Appliance)
- ✅ Application Load Balancer with SSL certificate
- ✅ DNS records (Route 53)
- ✅ Complete AppDynamics installation (Controller, EUM, Events, AIOps, SecureApp)

**Time:** 90-120 minutes | **Difficulty:** Intermediate | **Teams:** 5 (4 students each)

---

## 📋 Prerequisites

Before starting, ensure you have:
- [ ] AWS account access (credentials from instructor)
- [ ] Cisco VPN connection (required for SSH)
- [ ] AWS CLI installed and configured
- [ ] Git installed
- [ ] Terminal/command line access

---

## 🚀 Lab Steps

### Phase 1: Initial Setup (5 minutes)

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd appd-virtual-appliance/deploy/aws
   ```

2. **Verify your team assignment:**
   - You'll be assigned Team 1-5
   - Your team config: `config/team1.cfg` (example)

3. **Connect to Cisco VPN:**
   ```bash
   # Verify VPN connection
   curl ifconfig.me
   # Should show: 151.186.* (Cisco VPN IP)
   ```

4. **Configure AWS credentials:**
   ```bash
   aws configure
   # Enter credentials provided by instructor
   
   # Test access
   aws sts get-caller-identity
   ```

---

### Phase 2: Deploy Infrastructure (10 minutes)

Deploy your team's AWS infrastructure:

```bash
# Deploy Team 1 (adjust team number for your team)
./lab-deploy.sh config/team1.cfg
```

**What gets created:**
- VPC with public subnet
- 3 EC2 instances (m5a.4xlarge, 16 vCPUs, 64GB RAM each)
- Application Load Balancer
- SSL certificate (AWS ACM)
- DNS records

**Expected output:**
```
✅ Deployment Complete!

Your Team 1 Infrastructure:
  VPC: vpc-XXXXXXXXX (10.1.0.0/16)
  VM1: 52.x.x.x (Primary - use this for cluster commands)
  VM2: 54.x.x.x
  VM3: 35.x.x.x
  
  ALB: team1-alb-XXXXXXXX.us-west-2.elb.amazonaws.com
  
  URLs:
    Controller: https://controller-team1.splunkylabs.com/controller/
    Auth: https://team1.auth.splunkylabs.com
    
Time: ~10 minutes
```

---

### Phase 3: Bootstrap VMs (5 minutes)

Initialize each VM with network and storage settings:

```bash
./appd-bootstrap-vms.sh config/team1.cfg
```

This will:
- SSH to each VM
- Configure hostname, IP, gateway, DNS
- Setup storage
- Initialize MicroK8s
- Verify bootstrap completed

**Expected output:**
```
✅ All VMs bootstrapped successfully!

Run 'appdctl show boot' on each VM to verify.
```

---

### Phase 4: Create AppDynamics Cluster (5 minutes)

Create a 3-node MicroK8s cluster:

```bash
./appd-create-cluster.sh config/team1.cfg
```

This will:
- Initialize cluster on VM1
- Join VM2 and VM3 to cluster
- Verify all nodes are ready
- Label nodes for AppDynamics

**Expected output:**
```
✅ Cluster created successfully!

NODE           ROLE    RUNNING
10.1.0.103     voter   true
10.1.0.56      voter   true
10.1.0.177     voter   true
```

---

### Phase 5: Configure AppDynamics (3 minutes)

Configure AppDynamics settings (domain, DNS, passwords):

```bash
./appd-configure.sh config/team1.cfg
```

This will:
- Update `globals.yaml.gotmpl` with your team's domain
- Set DNS names
- Configure external URLs
- Verify DNS resolution

**Expected output:**
```
✅ Configuration updated!

DNS Domain: splunkylabs.com
DNS Names:
  - controller-team1.splunkylabs.com
  - team1.auth.splunkylabs.com
  - team1-tnt-authn.splunkylabs.com
```

---

### Phase 6: Install AppDynamics Services (30 minutes)

Install all AppDynamics services:

```bash
./appd-install.sh config/team1.cfg
```

This will:
- Install operators (cert-manager, postgres, mysql, kafka, elasticsearch)
- Install core services (Controller, Events, EUM, Synthetic)
- Install AIOps (Anomaly Detection)
- Install SecureApp
- Install ATD (Automatic Transaction Diagnostics)
- Verify all services are running

**Expected output:**
```
✅ All services installed successfully!

Service Status:
  Controller        ✅ Success
  Events            ✅ Success
  EUM Collector     ✅ Success
  EUM Aggregator    ✅ Success
  Anomaly Detection ✅ Success
  SecureApp         ✅ Success
  ATD               ✅ Success

Time: ~30 minutes
```

---

### Phase 7: Verify & Access (5 minutes)

Check system health and access your Controller:

```bash
./appd-check-health.sh config/team1.cfg
```

**Access your Controller:**
1. Open browser: `https://controller-team1.splunkylabs.com/controller/`
2. Login:
   - Username: `admin`
   - Password: `welcome`
3. Explore the interface!

---

## 🔍 Verification & Testing

### Check VM Status
```bash
# SSH to primary VM
ssh appduser@<vm1-ip>

# Check bootstrap
appdctl show boot

# Check cluster
appdctl show cluster

# Check services
appdcli ping

# Check pods
kubectl get pods --all-namespaces
```

### Check Service Endpoints
- **Controller:** https://controller-team1.splunkylabs.com/controller/
- **Events:** https://controller-team1.splunkylabs.com/events
- **EUM Aggregator:** https://controller-team1.splunkylabs.com/eumaggregator

---

## 🧹 Cleanup (When Done)

Delete all your team's resources:

```bash
./lab-cleanup.sh config/team1.cfg
```

**This will delete:**
- All 3 EC2 instances
- Load balancer
- DNS records
- VPC and networking
- Security groups

**Cost:** ~$3.20/hour while running. Always cleanup when done!

---

## 📚 Additional Resources

### Documentation
- [Quick Reference](docs/QUICK_REFERENCE.md) - Commands and URLs
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues
- [SecureApp Guide](docs/SECUREAPP_GUIDE.md) - SecureApp details
- [Architecture](docs/ARCHITECTURE.md) - System design

### Help & Support
- **Lab Issues:** Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Instructor Help:** Ask your instructor
- **AppDynamics Docs:** https://docs.appdynamics.com/

---

## ⚠️ Important Notes

### Security
- **SSH Access:** Only from Cisco VPN (automatic)
- **HTTPS Only:** Valid SSL certificates (AWS ACM)
- **Credentials:** Never commit to Git

### Costs
- **Running:** ~$3.20/hour per team
- **All 5 Teams:** ~$16/hour total
- **Always cleanup when done!**

### Team Isolation
- Each team has separate VPC
- No network connectivity between teams
- Unique URLs per team
- Independent resources

---

## 🎓 Learning Objectives

By completing this lab, you will:
1. ✅ Deploy AWS infrastructure (VPC, EC2, ALB, Route 53)
2. ✅ Configure networking and security groups
3. ✅ Create Kubernetes clusters (MicroK8s)
4. ✅ Install and configure AppDynamics
5. ✅ Manage SSL certificates (AWS ACM)
6. ✅ Implement DNS (Route 53)
7. ✅ Practice infrastructure automation

---

## 📞 Getting Help

**During Lab:**
1. Check `./appd-check-health.sh config/team1.cfg`
2. Review [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. Ask your instructor
4. Check AWS Console for resource status

**Common Issues:**
- **SSH timeout:** Verify Cisco VPN connection
- **DNS not resolving:** Wait 2-3 minutes for propagation
- **Pods not starting:** Check resources with `kubectl top nodes`
- **Services failed:** Retry the installation command

---

## ✅ Success Checklist

- [ ] All VMs deployed and accessible via SSH
- [ ] Cluster created (3 nodes, all ready)
- [ ] All services show "Success" in `appdcli ping`
- [ ] Controller UI accessible via HTTPS
- [ ] Login successful (admin/welcome)
- [ ] SSL certificate valid (no browser warnings)
- [ ] DNS resolves correctly

**Congratulations! Your AppDynamics cluster is ready!** 🎉

---

## 📝 Lab Completion

When finished:
1. Take screenshots of:
   - Controller login screen
   - `appdcli ping` output showing all services
   - Controller dashboard
2. Document any issues encountered
3. **Run cleanup:** `./lab-cleanup.sh config/team1.cfg`
4. Verify all resources deleted in AWS Console

---

**Ready to start?** Begin with Phase 1: Initial Setup! 🚀
