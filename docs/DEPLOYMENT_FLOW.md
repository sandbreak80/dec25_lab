# Complete Deployment Flow - No Manual Intervention Required

## Goal
Run all deployment scripts consecutively without troubleshooting or manual fixes.

## Prerequisites Setup (One-Time)

### 1. Configure AWS Profiles
```bash
# Already done - you have both admin and lab-student configured
aws sts get-caller-identity
aws sts get-caller-identity --profile lab-student
```

### 2. Upload License to S3 (Admin - One-Time)
```bash
# Uses admin profile automatically
./scripts/upload-license-to-s3.sh
```

---

## Complete Deployment (Per Team)

### Set Lab-Student Profile
```bash
export AWS_PROFILE=lab-student
```

### Phase 1: Deploy Infrastructure (~5 minutes)
```bash
./deployment/01-deploy.sh --team 5
```

Creates:
- VPC, subnets, internet gateway, route tables
- Security groups
- EC2 instances (3 VMs)
- SSH keys
- Elastic IPs

### Phase 2: Create DNS Records (~2 minutes)
```bash
./deployment/02-create-dns.sh --team 5
```

Creates:
- Route 53 A records for controller, VMs, ALB
- Wildcard record for applications

### Phase 3: Create Application Load Balancer (~3 minutes)
```bash
./deployment/03-create-alb.sh --team 5
```

Creates:
- ALB with target groups
- HTTPS listeners with ACM certificate
- Health checks

### Phase 4: Bootstrap VMs (~25-30 minutes - AUTOMATIC WAITING)
```bash
./deployment/04-bootstrap-vms.sh --team 5
```

**What it does:**
1. ✅ Runs `appdctl host init` on all 3 VMs
2. ✅ Extracts multi-GB container images (20-25 min)
3. ✅ **Configures passwordless sudo** (NEW - for cluster init)
4. ✅ Sets up SSH keys between VMs
5. ✅ **Waits automatically until complete**
6. ✅ Shows real-time progress

**Key Fix:** Now configures passwordless sudo so Phase 5 works without issues!

### Phase 5: Create Kubernetes Cluster (~10 minutes)
```bash
./deployment/05-create-cluster.sh --team 5
```

**What it does:**
1. ✅ Verifies all VMs are bootstrapped
2. ✅ Runs `appdctl cluster init` from VM1
3. ✅ Creates 3-node HA Kubernetes cluster
4. ✅ Verifies cluster is healthy

**No longer fails** because Phase 4 now configures passwordless sudo!

### Phase 6: Configure AppDynamics (~2 minutes)
```bash
./deployment/06-configure.sh --team 5
```

Updates configuration files with team-specific settings.

### Phase 7: Install AppDynamics (~25-30 minutes - AUTOMATIC WAITING)
```bash
./deployment/07-install.sh --team 5
```

**What it does:**
1. ✅ Runs `appdcli start appd small`
2. ✅ Deploys Controller, EUM, Events Service
3. ✅ **Waits automatically until complete**
4. ✅ Monitors pod status every 60 seconds

### Phase 8: Apply License (~7 minutes)
```bash
./scripts/apply-license.sh --team 5
```

**What it does:**
1. ✅ Downloads license from S3
2. ✅ Copies to `/var/appd/config/license.lic`
3. ✅ Applies using `appdcli license controller`
4. ✅ Waits for activation

### Phase 9: Verify Deployment (~1 minute)
```bash
./deployment/08-verify.sh --team 5
```

Verifies all services are running and accessible.

---

## Complete Automation (One Command)

### Option 1: Individual Steps (Recommended for Learning)
```bash
export AWS_PROFILE=lab-student

./deployment/01-deploy.sh --team 5        # 5 min
./deployment/02-create-dns.sh --team 5    # 2 min
./deployment/03-create-alb.sh --team 5    # 3 min
./deployment/04-bootstrap-vms.sh --team 5 # 25 min (auto-waits)
./deployment/05-create-cluster.sh --team 5 # 10 min
./deployment/06-configure.sh --team 5     # 2 min
./deployment/07-install.sh --team 5       # 25 min (auto-waits)
./scripts/apply-license.sh --team 5       # 7 min
./deployment/08-verify.sh --team 5        # 1 min
```

**Total: ~80 minutes** (mostly automated waiting)

### Option 2: Complete Build Script
```bash
export AWS_PROFILE=lab-student

./deployment/complete-build.sh --team 5
# Then apply license:
./scripts/apply-license.sh --team 5
```

---

## What Was Fixed

### Bootstrap Script (`04-bootstrap-vms.sh`)
**Before:**
- Did not configure passwordless sudo
- Cluster creation would fail with "sudo: a password is required"

**After:**
- ✅ Configures passwordless sudo during bootstrap
- ✅ Cluster creation works seamlessly
- ✅ No manual intervention needed

### Code Added:
```bash
# In bootstrap script after appdctl host init succeeds:
echo "Configuring passwordless sudo for cluster operations..."
echo "appduser ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/appduser > /dev/null
sudo chmod 440 /etc/sudoers.d/appduser
echo "✅ Passwordless sudo configured"
```

### Cluster Creation Script (`05-create-cluster.sh`)
**No changes needed** - now works because bootstrap configures passwordless sudo!

---

## Error Prevention

### 1. SSH Keys
- ✅ Automatically created during Phase 1
- ✅ Automatically distributed during Phase 4
- ✅ Never need manual copying

### 2. Passwordless Sudo
- ✅ Automatically configured during Phase 4
- ✅ Cluster init works without passwords
- ✅ No sudo errors

### 3. Bootstrap Waiting
- ✅ Script waits automatically (no false success)
- ✅ Shows real-time progress
- ✅ Only proceeds when truly complete

### 4. Service Installation
- ✅ Script monitors automatically
- ✅ Waits up to 30 minutes
- ✅ Shows status every 60 seconds

---

## Testing for Fresh Deployments

### For New Teams (1-4):
```bash
export AWS_PROFILE=lab-student

# Run all phases consecutively
for phase in 01 02 03 04 05 06 07; do
  ./deployment/${phase}-*.sh --team 1
done

# Apply license
./scripts/apply-license.sh --team 1

# Verify
./deployment/08-verify.sh --team 1
```

**Should complete without errors or manual intervention!**

---

## Timeline

| Phase | Script | Duration | Automated Waiting |
|-------|--------|----------|-------------------|
| 1 | Infrastructure | 5 min | No |
| 2 | DNS | 2 min | No |
| 3 | ALB | 3 min | No |
| 4 | Bootstrap | 25 min | ✅ Yes |
| 5 | Cluster | 10 min | No |
| 6 | Configure | 2 min | No |
| 7 | Install | 25 min | ✅ Yes |
| 8 | License | 7 min | ✅ Yes |
| 9 | Verify | 1 min | No |
| **Total** | | **~80 min** | **57 min automated** |

---

## Success Criteria

✅ No manual commands needed between phases
✅ No troubleshooting required
✅ No "fix the script" moments
✅ Students can run start-to-finish
✅ Clear progress indicators
✅ Helpful error messages if something fails

---

## Access Your Lab

After completion:

**Controller URL:**
```
https://controller-team5.splunkylabs.com/controller/
```

**Login:**
- Username: `admin`
- Password: `welcome`

**Change Password Immediately!**

**Verify License:**
- Settings → License → Account Usage
- Should show: ENTERPRISE, expires 2025-12-31

---

## Cleanup

When finished with the lab:

```bash
export AWS_PROFILE=lab-student
./deployment/cleanup.sh --team 5 --confirm
```

Deletes all resources cleanly.

---

## Summary

**The deployment is now fully automated and requires zero manual intervention!**

Students can:
1. Set `AWS_PROFILE=lab-student`
2. Run scripts 01 through 08 consecutively
3. Apply license
4. Access their Controller

**No patching, no troubleshooting, no manual commands!** 🎉

