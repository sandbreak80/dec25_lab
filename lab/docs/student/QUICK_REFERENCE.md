# AppDynamics Lab - Quick Reference Card

## 🎯 Your Team Info

| Item | Value |
|------|-------|
| Team Number | **N** (1-5) |
| Domain | `teamN.splunkylabs.com` |
| VPC CIDR | `10.N.0.0/16` |
| Controller URL | `https://controller-teamN.splunkylabs.com/controller/` |

---

## 🚀 Essential Commands

### Complete Deployment Workflow

```bash
# 1. Deploy AWS Infrastructure (30 min)
./lab-deploy.sh --team N

# 2. Bootstrap VMs (1 hour)
./appd-bootstrap-vms.sh --team N

# 3. Create Kubernetes Cluster (15 min)
./appd-create-cluster.sh --team N

# 4. Configure AppDynamics (10 min)
./appd-configure.sh --team N

# 5. Install AppDynamics (30 min)
./appd-install.sh --team N

# 6. Verify Health
./appd-check-health.sh --team N

# 7. (Optional) Install SecureApp separately
./appd-install-secureapp.sh --team N

# 8. Check Status
./scripts/check-status.sh --team N

# 9. SSH to VM1
./scripts/ssh-vm1.sh --team N

# 10. Cleanup (End of Day)
./lab-cleanup.sh --team N --confirm
```

### On VMs
```bash
# Bootstrap VM
sudo appdctl host init

# Check bootstrap status
appdctl show boot

# Create cluster (VM1 only)
appdctl cluster init <VM2-IP> <VM3-IP>

# Check cluster
appdctl show cluster
microk8s status

# Install AppDynamics
appdcli start all small

# Check services
appdcli ping

# View pods
kubectl get pods --all-namespaces
```

---

## 📝 Configuration

### VM Bootstrap Info
```
Hostname:  team1-vm-1  (or vm-2, vm-3)
IP:        10.N.0.X/24
Gateway:   10.N.0.1
DNS:       10.N.0.2
```

### globals.yaml.gotmpl Changes
```yaml
dnsDomain: teamN.splunkylabs.com

dnsNames:
  - teamN.splunkylabs.com
  - customer1-teamN.auth.splunkylabs.com
  - controller-teamN.splunkylabs.com

externalUrl: https://teamN.splunkylabs.com/...
```

---

## 🌐 URLs

| Service | URL |
|---------|-----|
| Controller | `https://controller-teamN.splunkylabs.com/controller/` |
| Auth | `https://customer1-teamN.auth.splunkylabs.com/` |

**Default Login:**
- Username: `admin`
- Password: `welcome` (CHANGE THIS!)

---

## 🔍 Troubleshooting

### Check Infrastructure
```bash
./scripts/check-status.sh --team N
```

### Check VMs
```bash
# SSH to VM
./scripts/ssh-vm1.sh --team N

# On VM:
appdctl show boot          # Bootstrap status
appdctl show cluster       # Cluster status
appdcli ping              # Service status
kubectl get pods -A       # All pods
kubectl top nodes         # Resource usage
```

### Common Fixes
```bash
# Fix secrets.yaml permissions
sudo chmod 644 /var/appd/config/secrets.yaml

# Restart failed pod
kubectl delete pod <pod-name> -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Check service health
appdcli ping
```

---

## ⏱️ Expected Wait Times

| Task | Time |
|------|------|
| Infrastructure deployment | 30 min |
| VM bootstrap (each) | 5 min |
| Cluster creation | 10 min |
| AppDynamics install | 20-30 min |
| DNS propagation | 1-2 min |
| ALB health checks | 3-5 min |

---

## 💰 Cost Info

| Resource | Cost/Hour | Daily (8hr) |
|----------|-----------|-------------|
| 3 × m5a.4xlarge | $2.064 | $16.51 |
| EBS (2.1 TB) | - | $2.33 |
| ALB | $0.0225 | $0.18 |
| **Total** | **~$2.44** | **~$19.52** |

⚠️ **Always cleanup at end of day!**

---

## 📞 Help

1. Check `docs/QUICK_START.md`
2. Check `docs/TROUBLESHOOTING.md`
3. Ask your team
4. Ask instructor

---

## ✅ Checklist

Infrastructure:
- [ ] VPC created
- [ ] 3 VMs running
- [ ] ALB active
- [ ] DNS resolving

Configuration:
- [ ] All VMs bootstrapped
- [ ] Cluster created
- [ ] globals.yaml updated

Installation:
- [ ] AppDynamics installed
- [ ] All services "Success"
- [ ] Controller UI accessible
- [ ] Password changed

Cleanup:
- [ ] All resources deleted
- [ ] Verified in AWS Console

---

**Keep this reference handy throughout the lab!** 📋
