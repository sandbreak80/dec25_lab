# Team 1 Deployment Plan - NEW AMI (25.7.0.2255)

## Overview

Deploying Team 1 with:
- ✅ **New AMI:** 25.7.0.2255 (from `config/global.cfg`)
- ✅ **SecureApp DNS Configuration:** Properly configured from the start
- ✅ **Fresh Clean Deployment:** No existing state

## Prerequisites

### 1. AWS Configuration
```bash
# Verify AWS profile
AWS_PROFILE=bstoner aws sts get-caller-identity
```

### 2. AMI Configuration
```bash
# Verify new AMI is configured
source config/global.cfg
echo "AMI ID: $APPD_AMI_ID"
echo "AMI Version: $APPD_AMI_VERSION"
```

Should show:
- AMI ID: `ami-076101d21105aedfa`
- AMI Version: `25.7.0.2255`

### 3. AppDynamics Portal Credentials (for SecureApp feeds)
```bash
# Set portal credentials for SecureApp feed downloads
export APPD_PORTAL_USERNAME="your-portal-username"
export APPD_PORTAL_PASSWORD="your-portal-password"
```

**Note:** If you don't have portal credentials, SecureApp can still be configured later manually.

## Deployment Options

### Option 1: Full Automated Deployment (Recommended)

**Duration:** ~70-80 minutes  
**Interaction:** Zero (100% automated)

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Optional: Set SecureApp portal credentials
export APPD_PORTAL_USERNAME="feed-downloader"
export APPD_PORTAL_PASSWORD="YourPassword123"

# Run full deployment
./deployment/full-deploy.sh --team 1
```

**What it does:**
1. ✅ Checks prerequisites
2. ✅ Deploys infrastructure (VPC, Subnets, SGs, VMs with NEW AMI, ALB, DNS)
3. ✅ Changes VM password (automated)
4. ✅ Sets up SSH keys (automated)
5. ✅ Bootstraps VMs (15-20 min)
6. ✅ Creates Kubernetes cluster (10 min)
7. ✅ Configures globals.yaml.gotmpl with DNS
8. ✅ Installs AppDynamics services (20-30 min)
9. ✅ Applies license
10. ✅ Configures SecureApp feeds (if credentials provided)
11. ✅ Verifies deployment

### Option 2: Step-by-Step Deployment

**Duration:** ~70-80 minutes  
**Interaction:** Manual step execution

```bash
cd /Users/bmstoner/code_projects/dec25_lab/deployment

# Step 1: Deploy Infrastructure (~5-10 min)
./01-deploy.sh --team 1

# Step 2: Change Password (automated, ~30 sec)
./02-change-password.sh --team 1

# Step 3: Setup SSH Keys (automated, ~30 sec)
./03-setup-ssh-keys.sh --team 1

# Step 4: Bootstrap VMs (~1 min to initiate)
./04-bootstrap-vms.sh --team 1
# Wait 15-20 minutes for image extraction

# Step 5: Create Cluster (~10 min)
./05-create-cluster.sh --team 1

# Step 6: Configure DNS/Globals (~2 min)
./06-configure.sh --team 1

# Step 7: Install AppDynamics (~20-30 min)
./07-install.sh --team 1

# Step 8: Verify Installation (~1 min)
./08-verify.sh --team 1

# Step 9: Apply License (~1 min)
./09-apply-license.sh --team 1

# Step 10: Configure SecureApp (optional, ~2-3 min)
./10-configure-secureapp.sh --team 1 \
  --username feed-downloader \
  --password YourPassword123
```

## SecureApp Configuration Details

### What's Different About This Deployment

Previous deployments (Teams 2-5) had issues with SecureApp DNS configuration. For Team 1, we're ensuring:

1. **DNS Names in globals.yaml.gotmpl** (Step 6 - 06-configure.sh):
   - Configures `dnsDomain: team1.splunkylabs.com`
   - Adds proper DNS names for SecureApp
   - Sets before installation

2. **argento.enabled Property** (handled during install):
   - Set automatically after Controller is up
   - Required for SecureApp API access

3. **Feed Configuration** (Step 10 - optional):
   - Automatic feed downloads from AppDynamics portal
   - Requires portal credentials
   - Can be skipped and done later

### Manual SecureApp Enable (If Needed)

If SecureApp isn't enabled after installation:

```bash
# SSH to VM1
ssh appduser@<vm1-ip>  # Password: AppDynamics123!

# Enable SecureApp property
CONTROLLER_POD=$(kubectl get pods -n cisco-controller -l app=controller -o name | head -1 | cut -d'/' -f2)

kubectl exec -n cisco-controller $CONTROLLER_POD -- bash -c \
  "mysql -h localhost -u controller -pAppDynamics123 controller \
   -e \"INSERT INTO global_configuration_local (name, value) VALUES ('argento.enabled', 'true') ON DUPLICATE KEY UPDATE value='true';\""

# Restart Controller
kubectl rollout restart deployment/controller-deployment -n cisco-controller

# Wait 5 minutes, then verify
appdcli run secureapp health
```

## Expected URLs

After deployment, these URLs will be available:

| Service | URL |
|---------|-----|
| **Controller** | https://controller-team1.splunkylabs.com/controller/ |
| **Authentication** | https://customer1-team1.auth.splunkylabs.com/ |
| **Events Service** | https://events-team1.splunkylabs.com/ |
| **SecureApp** | https://secureapp-team1.splunkylabs.com/ |

## Credentials

### VM Access
- **SSH:** `ssh appduser@<vm-ip>`
- **Password:** `AppDynamics123!`

### Controller
- **URL:** https://controller-team1.splunkylabs.com/controller/
- **Username:** `admin`
- **Password:** `welcome`

### Administration Console
- **URL:** https://controller-team1.splunkylabs.com/controller/admin.jsp
- **Username:** `admin`
- **Password:** `welcome`

## Verification Steps

### 1. Check Infrastructure

```bash
./scripts/check-deployment-state.sh

# Should show:
# ✅ AMI: ami-076101d21105aedfa
# ✅ VPC, Subnets, Security Groups
# ✅ 3 VMs running
# ✅ ALB configured
# ✅ DNS records
```

### 2. Check AppDynamics Services

```bash
ssh appduser@<vm1-ip>

# Check all services
appdcli ping

# Should show all services including SecureApp
```

### 3. Check SecureApp Specifically

```bash
# SSH to VM1
ssh appduser@<vm1-ip>

# Check SecureApp health
appdcli run secureapp health

# Should show:
# ✅ Account properties are configured for Secure App
# ✅ SecureApp agent is running
# ✅ All health checks passing
```

### 4. Check DNS Resolution

```bash
# From your machine
nslookup controller-team1.splunkylabs.com
nslookup customer1-team1.auth.splunkylabs.com
nslookup secureapp-team1.splunkylabs.com

# All should resolve to ALB DNS name
```

### 5. Access Controller UI

Open browser:
```
https://controller-team1.splunkylabs.com/controller/
```

Login and verify:
- ✅ License is applied
- ✅ SecureApp menu visible
- ✅ No errors in logs

## Troubleshooting

### Issue: AMI not found

```bash
# Check global config
source config/global.cfg
echo $APPD_AMI_ID

# Should be: ami-076101d21105aedfa
# If not, update config/global.cfg
```

### Issue: SecureApp not showing in UI

```bash
# Check property is set
ssh appduser@<vm1-ip>
CONTROLLER_POD=$(kubectl get pods -n cisco-controller -l app=controller -o name | head -1 | cut -d'/' -f2)
kubectl exec -n cisco-controller $CONTROLLER_POD -- bash -c \
  "mysql -h localhost -u controller -pAppDynamics123 controller \
   -e \"SELECT * FROM global_configuration_local WHERE name='argento.enabled';\""

# Should return: argento.enabled | true
# If not, run the enable script from deployment/
```

### Issue: SecureApp feed upload fails

```bash
# 1. Check argento.enabled property (see above)
# 2. Check API connectivity
ssh appduser@<vm1-ip>
appdcli run secureapp checkApi

# If fails, verify DNS in globals.yaml.gotmpl
cat /var/appd/config/globals.yaml.gotmpl | grep -A 10 dnsNames
```

## Timeline Estimate

| Phase | Duration | Notes |
|-------|----------|-------|
| Infrastructure | 5-10 min | VPC, VMs, ALB, DNS |
| Password/SSH | 1-2 min | Automated |
| Bootstrap | 15-20 min | Image extraction |
| Cluster | 10-15 min | K8s setup |
| Configure | 2-3 min | globals.yaml |
| Install | 20-30 min | AppD services |
| Verify | 2-3 min | Health checks |
| SecureApp | 5-10 min | Optional feed config |
| **Total** | **60-90 min** | Fully automated |

## Cleanup (When Done)

```bash
# Remove all Team 1 resources
./deployment/cleanup.sh --team 1 --confirm

# This will delete:
# - VMs (and their EBS volumes)
# - Load Balancer
# - Security Groups
# - Subnets
# - VPC
# - DNS records
# - State files
```

## Success Criteria

Team 1 deployment is successful when:

- ✅ All VMs running with new AMI (25.7.0.2255)
- ✅ Kubernetes cluster healthy
- ✅ All AppDynamics services running (`appdcli ping` shows all green)
- ✅ Controller accessible at https://controller-team1.splunkylabs.com/controller/
- ✅ License applied
- ✅ SecureApp visible in UI
- ✅ SecureApp health checks passing
- ✅ DNS properly configured (no nip.io references)
- ✅ (Optional) Vulnerability feeds configured and downloading

## Next Steps After Deployment

1. **Change Controller Password:**
   - Login to Controller
   - Change admin password from `welcome` to something secure

2. **Explore SecureApp:**
   - Check Secure Application menu
   - Review security policies
   - Test application onboarding

3. **Test Monitoring:**
   - Deploy sample application
   - Configure monitoring
   - Verify data flow

4. **Students Can Access:**
   - Provide URLs and credentials
   - Begin lab exercises

---

**Ready to Deploy?**

```bash
# Quick start (recommended)
cd /Users/bmstoner/code_projects/dec25_lab
./deployment/full-deploy.sh --team 1
```

Log file will be created at: `logs/full-deploy/team1-TIMESTAMP.log`

---
Last Updated: December 18, 2025

