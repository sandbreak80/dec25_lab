# ✅ Team 1 Deployment - Ready to Go!

## Quick Summary

**YES - We can deploy Team 1 with:**
- ✅ New AMI version 25.7.0.2255
- ✅ Proper SecureApp DNS configuration
- ✅ Using the deployment scripts

## Pre-Flight Check Results

```
✅ Passed:   11 checks
⚠️  Warnings: 2 (non-critical)
❌ Failed:   0
```

### What's Verified

1. ✅ **AWS Profile:** `bstoner` configured and working
2. ✅ **AMI Configuration:** New AMI `ami-076101d21105aedfa` (v25.7.0.2255) ready
3. ✅ **Team 1 Config:** Properly configured with correct AWS profile
4. ✅ **No Existing State:** Clean deployment (no previous state files)
5. ✅ **DNS Access:** Route53 hosted zone accessible
6. ✅ **License File:** Present and valid until 2025-12-31
7. ✅ **Scripts:** All deployment scripts present and executable
8. ⚠️  **SecureApp Credentials:** Not set (can configure later)
9. ✅ **Required Tools:** All tools installed (aws, jq, expect, ssh, scp)
10. ✅ **No Existing VPC:** Clean slate in AWS

### Warnings (Non-Critical)

1. **DNS Records Exist:** Team 1 DNS records found (likely from previous testing)
   - **Impact:** Will be updated during deployment
   - **Action:** None required

2. **SecureApp Portal Credentials:** Not set  
   - **Impact:** SecureApp will work, but vulnerability feeds won't auto-download
   - **Action:** Can configure later with `10-configure-secureapp.sh`

## How to Deploy

### Option 1: Full Automated (Recommended)

**One command, ~70 minutes, zero interaction:**

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Deploy everything
./deployment/full-deploy.sh --team 1
```

**What it does:**
- Infrastructure (VPC, VMs with NEW AMI, ALB, DNS)
- Password change (automated)
- SSH keys (automated)
- Bootstrap (15-20 min)
- K8s cluster (10 min)
- Configure DNS properly
- Install AppDynamics (20-30 min)
- Apply license
- Verify deployment

### Option 2: With SecureApp Portal Credentials

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Set credentials first
export APPD_PORTAL_USERNAME="your-username"
export APPD_PORTAL_PASSWORD="your-password"

# Deploy with SecureApp feed configuration
./deployment/full-deploy.sh --team 1
```

## What Makes This Different from Teams 2-5

### Fixed Issues:

1. **AMI Version:**
   - Teams 2-5: Old AMI (25.4.0.2016)
   - **Team 1: New AMI (25.7.0.2255)** ✅

2. **SecureApp DNS:**
   - Teams 2-5: DNS not properly configured in `globals.yaml.gotmpl`
   - **Team 1: DNS configured correctly from the start** ✅
   
3. **Configuration Source:**
   - Teams 2-5: AMI ID from state directory (wrong)
   - **Team 1: AMI ID from config/global.cfg (correct)** ✅

### Deployment Flow for Team 1:

```
1. Infrastructure Deploy (01-deploy.sh)
   └─> Uses NEW AMI from config/global.cfg
   └─> Creates VMs with 25.7.0.2255

2. Password/SSH (02-03)
   └─> Automated

3. Bootstrap (04)
   └─> Extracts container images (15-20 min)

4. Cluster Create (05)
   └─> K8s cluster setup (10 min)

5. Configure DNS (06-configure.sh)  ← KEY DIFFERENCE
   └─> Sets dnsDomain: team1.splunkylabs.com
   └─> Adds SecureApp DNS names
   └─> No nip.io references

6. Install AppD (07-install.sh)
   └─> Installs with proper DNS config
   └─> SecureApp knows its DNS names

7. Apply License (09)
   └─> License activation

8. [Optional] Configure SecureApp Feeds (10)
   └─> Auto-download vulnerability data
```

## Expected URLs After Deployment

| Service | URL |
|---------|-----|
| Controller | https://controller-team1.splunkylabs.com/controller/ |
| Auth | https://customer1-team1.auth.splunkylabs.com/ |
| Events | https://events-team1.splunkylabs.com/ |
| SecureApp | https://secureapp-team1.splunkylabs.com/ |

## Credentials

**VMs:**
- SSH: `ssh appduser@<vm-ip>`
- Password: `AppDynamics123!`

**Controller:**
- URL: https://controller-team1.splunkylabs.com/controller/
- Username: `admin`
- Password: `welcome`

## Timeline

| Phase | Duration |
|-------|----------|
| Infrastructure | 5-10 min |
| Password/SSH | 1-2 min |
| Bootstrap | 15-20 min |
| Cluster | 10-15 min |
| Configure | 2-3 min |
| Install | 20-30 min |
| Verify/License | 2-3 min |
| **Total** | **~60-80 min** |

## Monitoring Progress

The `full-deploy.sh` script will:
- Show progress for each step
- Display timing information
- Create a log file at: `logs/full-deploy/team1-TIMESTAMP.log`
- Show clear success/failure messages

You can watch it run and walk away - it's 100% automated.

## Next Steps After Deployment

1. **Verify AMI Version:**
   ```bash
   ssh appduser@<vm1-ip>
   cat /etc/appd-release  # Should show 25.7.0.2255
   ```

2. **Check SecureApp:**
   ```bash
   ssh appduser@<vm1-ip>
   appdcli run secureapp health
   # Should show proper DNS configuration
   ```

3. **Access Controller:**
   - Open: https://controller-team1.splunkylabs.com/controller/
   - Login: admin / welcome
   - Verify SecureApp menu is visible

4. **Configure Feeds (Optional):**
   ```bash
   ./deployment/10-configure-secureapp.sh --team 1 \
     --username your-username \
     --password your-password
   ```

## Cleanup (When Done)

```bash
./deployment/cleanup.sh --team 1 --confirm
```

## Documentation

- **Deployment Plan:** `TEAM1_DEPLOYMENT_PLAN.md`
- **Pre-Flight Check:** `check-team1-ready.sh`
- **AMI Info:** `config/global.cfg`
- **Team Config:** `config/team1.cfg`

---

## Ready to Deploy?

```bash
cd /Users/bmstoner/code_projects/dec25_lab
./deployment/full-deploy.sh --team 1
```

**Estimated completion:** ~70 minutes from now

The script is fully automated - no interaction needed!

---

**Questions to Consider:**

1. **Do you want to configure SecureApp feeds now or later?**
   - Now: Set APPD_PORTAL_USERNAME and APPD_PORTAL_PASSWORD before running
   - Later: Run `10-configure-secureapp.sh` after deployment

2. **Should we clean up old Team 1 DNS records first?**
   - Probably not needed - they'll be updated automatically
   - But if you want: `./scripts/delete-dns.sh --team 1`

3. **Want to test with one step at a time instead?**
   - See `TEAM1_DEPLOYMENT_PLAN.md` for step-by-step approach
   - Good for learning/debugging

---

**Status: READY TO DEPLOY** ✅

All systems go for Team 1 deployment with new AMI!

---
Date: December 18, 2025
Pre-Flight Check: PASSED (11/11 critical checks)

