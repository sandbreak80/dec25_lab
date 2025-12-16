# Next Steps - License Management Setup

## What I've Created

### Scripts:
1. **`scripts/upload-license-to-s3.sh`** - Upload license to S3 (instructor, one-time)
2. **`scripts/apply-license.sh`** - Download and apply license to team (students)

### Documentation:
1. **`docs/LICENSE_MANAGEMENT.md`** - Complete guide with troubleshooting
2. **`LICENSE_UPLOAD_INSTRUCTIONS.md`** - Quick start for instructor

---

## What You Need to Do Now

### Step 1: Upload License to S3 (Admin Credentials Required)

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Switch to YOUR admin AWS credentials (not lab-student!)
export AWS_PROFILE=default  # or whatever your admin profile is called

# Verify you're using admin
aws sts get-caller-identity
# Should show YOUR admin user, not lab-student

# Upload the license
./scripts/upload-license-to-s3.sh
```

**Expected output:**
```
✅ License Upload Complete!

S3 Location:
  s3://appdynamics-lab-resources/shared/license.lic
```

### Step 2: Switch Back to Lab-Student

```bash
unset AWS_PROFILE

# Or reconfigure lab-student credentials
aws configure
# Enter lab-student keys from STUDENT_CREDENTIALS.txt
```

### Step 3: Test License Application (Once Team 5 Bootstrap Completes)

Once Team 5's bootstrap finishes (~10 more minutes) and Controller is installed:

```bash
# After running: ./deployment/07-install.sh --team 5

# Apply the license
./scripts/apply-license.sh --team 5
```

---

## How Students Will Use This

### During Deployment:

Students follow normal deployment, then after Controller installation:

```bash
# Standard deployment
./deployment/01-deploy.sh --team 1
./deployment/02-create-dns.sh --team 1
./deployment/03-create-alb.sh --team 1
./deployment/04-bootstrap-vms.sh --team 1  # Wait 20-30 min
./deployment/05-create-cluster.sh --team 1
./deployment/06-configure.sh --team 1
./deployment/07-install.sh --team 1        # Wait 20-30 min

# NEW: Apply license
./scripts/apply-license.sh --team 1        # 7 minutes

# Verify
./deployment/08-verify.sh --team 1
```

### What It Does:

The `apply-license.sh` script:
1. Downloads `license.lic` from S3
2. Copies to VM1 at `/var/appd/config/license.lic`
3. Runs `appdcli license controller /var/appd/config/license.lic`
4. Triggers reload with `sudo touch /var/appd/config/license.lic`
5. Waits up to 5 minutes for license to activate
6. Shows verification instructions for Controller UI

---

## Verification

### In Controller UI:

1. Go to: `https://controller-team1.splunkylabs.com/controller/`
2. Login: `admin` / `welcome`
3. Navigate to: **Settings → License → Account Usage**
4. Should show:
   - Edition: ENTERPRISE
   - Expires: 2025-12-31 00:00:00 PST
   - APM Agents: 10 units

---

## Alternative: No S3 (Local File Distribution)

If you prefer NOT to use S3:

### Students copy license manually:

```bash
# Student has license.lic in their project directory

./scripts/apply-license.sh --team 1 --license-file ./license.lic
```

Or distribute via:
- Shared network drive
- Email (secure)
- USB drive
- Internal web server

---

## Current Status

- ✅ License file exists: `license.lic`
- ✅ Upload script ready: `scripts/upload-license-to-s3.sh`
- ✅ Apply script ready: `scripts/apply-license.sh`
- ⏸️ **TODO:** Upload to S3 (requires your admin credentials)
- ⏸️ **TODO:** Test application once Team 5 bootstrap completes

---

## Timeline

- Upload to S3: **2 minutes** (one-time, admin)
- Apply to each team: **7 minutes** (mostly waiting for activation)
- Verify in UI: **1 minute**

**Total per team:** ~8 minutes (can be done while Controller is installing)

---

## Quick Commands Summary

```bash
# INSTRUCTOR (ONE TIME):
export AWS_PROFILE=admin
./scripts/upload-license-to-s3.sh
unset AWS_PROFILE

# STUDENTS (PER TEAM):
./scripts/apply-license.sh --team 1

# MANUAL VERIFICATION:
./scripts/ssh-vm1.sh --team 1
ls -l /var/appd/config/license.lic
appdcli ping | grep controller
```

---

**Ready when you are!** Run the upload script with your admin credentials to complete the setup.

