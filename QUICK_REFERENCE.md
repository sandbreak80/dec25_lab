# AppDynamics VA - Quick Reference Guide

**For Lab Instructors and Students**

---

## Quick Start (Assumes Infrastructure Already Deployed)

### Student Lab Access

**Controller URL:**
```
https://controller.splunkylabs.com/controller
```

**Login:**
- Username: `admin`
- Password: `[PROVIDED_BY_INSTRUCTOR]`

**Note:** Instructor will change default password before lab starts

**VM Access (Instructor Only):**
- VM1: `ssh appduser@44.232.63.139`
- VM2: `ssh appduser@54.244.130.46`
- VM3: `ssh appduser@52.39.239.130`
- Password: `[PROVIDED_BY_INSTRUCTOR]`

---

## Quick Commands

### Check System Health

```bash
# Overall health
appdcli ping

# Cluster status
appdctl show cluster

# All pods
kubectl get pods --all-namespaces

# Node resources
kubectl top nodes
```

### Service Management

```bash
# Stop all services
appdcli stop appd

# Start services
appdcli start appd small

# Restart specific service
kubectl delete pod <pod-name> -n <namespace>
```

### Troubleshooting

```bash
# Pod logs
kubectl logs <pod-name> -n <namespace>

# Pod details
kubectl describe pod <pod-name> -n <namespace>

# Events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Controller status
curl -k https://localhost/controller/rest/serverstatus
```

---

## Deployment Timeline (Instructor)

| Phase | Task | Duration | Commands |
|-------|------|----------|----------|
| **Prep** | Download AMI, get license | 30 min | Manual |
| **Phase 1** | AWS Infrastructure | 60 min | Scripts 01-09 |
| **Phase 2** | Bootstrap VMs | 10 min | `appdctl host init` |
| **Phase 3** | Configuration | 10 min | `upload-config.sh` |
| **Phase 4** | Create Cluster | 5 min | `appdctl cluster init` |
| **Phase 5** | Install Services | 30 min | `appdcli start appd small` |
| **Phase 6** | Verification | 5 min | `appdcli ping` |
| **Total** | | **~2.5 hours** | |

---

## Common Issues & Fixes

### Issue: Can't access Controller UI

```bash
# Check ingress is running
kubectl get pods -n ingress-nginx

# Check DNS
nslookup controller.splunkylabs.com

# Test from VM
curl -k https://localhost/controller/rest/serverstatus
```

### Issue: Services show "Failed"

```bash
# Wait 5-10 minutes, services need time to initialize
watch -n 30 'appdcli ping'

# Check pod status
kubectl get pods --all-namespaces | grep -v Running

# Check specific pod
kubectl logs <pod-name> -n <namespace>
```

### Issue: DNS not resolving

```bash
# Wait 5-10 minutes for propagation
nslookup controller.splunkylabs.com

# Check Route 53 records
aws route53 list-resource-record-sets --hosted-zone-id Z06491142QTF1FNN8O9PR
```

---

## Cost Information

**Hourly:** ~$8.50  
**Daily:** ~$204  
**Monthly:** ~$6,120

**To Stop (Save ~$6/hr):**
```bash
aws ec2 stop-instances --instance-ids i-0abc123 i-0def456 i-0ghi789
```

**To Delete (Save all costs):**
```bash
./aws-delete-vms.sh
```

---

## URLs & Endpoints

### Web Interfaces

| Service | URL |
|---------|-----|
| Controller | https://controller.splunkylabs.com/controller |
| Events | https://splunkylabs.com/events |
| EUM Aggregator | https://splunkylabs.com/eumaggregator |

### API Endpoints

```bash
# Health check
curl -k https://controller.splunkylabs.com/controller/rest/serverstatus

# Agent download
https://controller.splunkylabs.com/controller/agentdownload
```

---

## Architecture Quick Reference

```
3-Node High Availability Cluster
├── VM1 (Primary): 10.0.0.103 / 44.232.63.139
│   ├── Controller
│   ├── Events Service
│   ├── EUM Services
│   └── Databases (MySQL, Postgres)
├── VM2 (Worker): 10.0.0.56 / 54.244.130.46
│   └── Additional pods & storage
└── VM3 (Worker): 10.0.0.177 / 52.39.239.130
    └── Additional pods & storage
```

---

## Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| globals.yaml.gotmpl | /var/appd/config/ | Main Helm config |
| secrets.yaml | /var/appd/config/ | Passwords & secrets |
| license.lic | /var/appd/config/ | AppD license |

---

## Useful Aliases (Add to ~/.bashrc)

```bash
alias k='kubectl'
alias kgp='kubectl get pods --all-namespaces'
alias kgs='kubectl get svc --all-namespaces'
alias appdping='appdcli ping'
alias appdstatus='appdctl show cluster'
alias watchpods='watch -n 10 kubectl get pods --all-namespaces'
```

---

## Emergency Contacts

- **Lab Instructor:** [Name/Contact]
- **AppDynamics Support:** https://www.appdynamics.com/support
- **Documentation:** `LAB_GUIDE.md` (this directory)

---

## For More Information

- **Complete Lab Guide:** `LAB_GUIDE.md`
- **Deployment Scripts:** This directory
- **Troubleshooting:** `LAB_GUIDE.md` → Troubleshooting section
- **Vendor Issues:** `VENDOR_DOC_ISSUES.md`
