# AppDynamics License Management

This guide covers how to distribute and apply the AppDynamics license file to all lab teams.

## Overview

The license file (`license.lic`) needs to be:
1. Uploaded to S3 for centralized distribution
2. Downloaded and applied to each team's Controller
3. Verified in the Controller UI

## License Information

**Current License:**
- Customer: cust
- Edition: ENTERPRISE
- Expires: 2025-12-31
- APM Agents: 10 units
- Machine Agents: 10 units
- EUM: PRO license

---

## Part 1: Upload License to S3 (Instructor - One Time)

**⚠️ Important:** This step requires **admin AWS credentials** (not lab-student).

### Step 1: Switch to Admin Credentials

```bash
# Temporarily use your admin AWS profile
export AWS_PROFILE=default  # or your admin profile name

# Verify admin access
aws sts get-caller-identity
# Should show your admin IAM user, not lab-student
```

### Step 2: Upload License

```bash
cd /Users/bmstoner/code_projects/dec25_lab

./scripts/upload-license-to-s3.sh
```

**What this does:**
- Creates S3 bucket: `appdynamics-lab-resources`
- Uploads `license.lic` to `s3://appdynamics-lab-resources/shared/license.lic`
- Sets bucket policy to allow lab students to download
- Enables versioning for safety

**Output:**
```
✅ License Upload Complete!

S3 Location:
  s3://appdynamics-lab-resources/shared/license.lic

Download URL (for scripts):
  https://appdynamics-lab-resources.s3.us-west-2.amazonaws.com/shared/license.lic

Students can download using:
  aws s3 cp s3://appdynamics-lab-resources/shared/license.lic /tmp/license.lic
```

### Step 3: Switch Back to Lab-Student Credentials

```bash
unset AWS_PROFILE
# Or configure lab-student credentials
aws configure
```

---

## Part 2: Apply License to Teams (Students or Instructor)

Once the license is uploaded to S3, any lab user (including lab-student) can download and apply it.

### Option A: Automatic Application (Recommended)

During deployment, integrate license application:

```bash
# After Controller installation
./deployment/07-install.sh --team 1

# Then apply license
./scripts/apply-license.sh --team 1
```

### Option B: Manual Application

```bash
# Download and apply license from S3
./scripts/apply-license.sh --team 1
```

**What this does:**
1. Downloads license from S3
2. Copies to VM1 at `/var/appd/config/license.lic`
3. Applies using `appdcli license controller`
4. Triggers license reload with `touch`
5. Waits up to 5 minutes for activation

### Option C: Apply Local License File

If you have a license file locally and don't want to use S3:

```bash
./scripts/apply-license.sh --team 1 --license-file /path/to/license.lic
```

---

## Part 3: Verify License

### Via Script

```bash
./scripts/ssh-vm1.sh --team 1

# Check license file exists
ls -l /var/appd/config/license.lic

# Verify Controller sees the license
appdcli ping | grep controller
```

### Via Controller UI

1. **Log in to Controller:**
   - URL: `https://controller-team1.splunkylabs.com/controller/`
   - User: `admin`
   - Pass: `welcome` (or changed password)

2. **Navigate to License Page:**
   - Settings → License → Account Usage

3. **Verify License Details:**
   - Edition: ENTERPRISE
   - Expires: 2025-12-31
   - APM Agents: 10 units available

4. **Check Peak Usage:**
   - Should show current usage
   - Warnings if approaching limits

---

## Troubleshooting

### License Not Detected After 5 Minutes

**Problem:** Controller doesn't show new license

**Solution:**
```bash
./scripts/ssh-vm1.sh --team 1

# Force Controller to reload license
sudo touch /var/appd/config/license.lic

# Wait 2-3 minutes
sleep 180

# Check in UI again
```

### S3 Download Fails

**Problem:** `aws s3 cp` returns 403 Forbidden

**Solution 1:** Verify lab-student has read access
```bash
# Test download
aws s3 ls s3://appdynamics-lab-resources/shared/

# If this fails, the bucket policy may not be set correctly
```

**Solution 2:** Use admin to fix bucket policy
```bash
export AWS_PROFILE=admin

# Re-run upload script to fix policy
./scripts/upload-license-to-s3.sh
```

### License File Permissions Error

**Problem:** Cannot write to `/var/appd/config/`

**Solution:**
```bash
# On VM1, fix permissions
sudo chmod 755 /var/appd/config
sudo chmod 644 /var/appd/config/license.lic
```

### Wrong License Applied

**Problem:** Applied old or incorrect license

**Solution:**
```bash
# On VM1
sudo rm /var/appd/config/license.lic

# Re-download and apply correct license
./scripts/apply-license.sh --team 1
```

---

## For Multi-Tenant Deployments

If you're running a multi-tenant Controller, additional steps are required:

1. **Apply the license file first** (as above)

2. **Update each tenant account:**
   ```bash
   # SSH to VM1
   ./scripts/ssh-vm1.sh --team 1
   
   # Access admin.jsp
   # http://localhost:8090/controller/admin.jsp
   ```

3. **For each account:**
   - Click "Accounts"
   - Select the account
   - Update license expiration date
   - Update license units allocation
   - Save changes

**Note:** For this lab, we're using single-tenant, so this is not required.

---

## Updating License (When You Purchase More Units)

When you receive an updated license file:

### Step 1: Backup Old License

```bash
# On VM1
sudo cp /var/appd/config/license.lic /var/appd/config/license.lic.backup-$(date +%Y%m%d)
```

### Step 2: Upload New License to S3

```bash
# As admin
export AWS_PROFILE=admin
./scripts/upload-license-to-s3.sh --license-file /path/to/new-license.lic
```

**Note:** S3 versioning is enabled, so old versions are preserved.

### Step 3: Apply to All Teams

```bash
# For each team
for team in 1 2 3 4 5; do
  echo "Updating team $team..."
  ./scripts/apply-license.sh --team $team
done
```

### Step 4: Verify

Check each Controller UI to ensure the new license units appear.

---

## License Expiration Handling

**Current license expires:** 2025-12-31

**Two weeks before expiration:**
1. Contact AppDynamics licensing: licensing-help@appdynamics.com
2. Request license renewal
3. Provide:
   - Customer ID: cust
   - Current opportunity ID: 006Hr00001Vj7MBIAZ
   - Deployment type: On-premises lab environment

**When you receive the new license:**
1. Upload to S3 (replaces old)
2. Apply to all teams
3. Verify expiration date updated in UI

---

## Security Notes

### License File Contents

The license file contains:
- License key
- Customer information
- Edition and features
- Expiration date
- Digital signature

**Do NOT:**
- Share license files publicly
- Commit license files to public repositories
- Email unencrypted license files

### S3 Bucket Security

The bucket policy allows:
- ✅ Read access to `shared/*` for all lab students
- ❌ No write access for students
- ❌ No public internet access
- ✅ AWS authenticated users only

### Access Control

Only instructors with admin AWS credentials can:
- Upload licenses to S3
- Modify bucket policies
- Delete or replace licenses

---

## Alternative: Local Distribution

If you don't want to use S3:

### Option 1: Direct SCP

```bash
# From your local machine
VM1_IP=$(cat state/team1/vm1-public-ip.txt)
KEY_PATH=$(cat state/team1/ssh-key-path.txt)

scp -i $KEY_PATH license.lic appduser@${VM1_IP}:/tmp/
ssh -i $KEY_PATH appduser@${VM1_IP} "sudo cp /tmp/license.lic /var/appd/config/ && appdcli license controller /var/appd/config/license.lic"
```

### Option 2: Network Share

Host license on internal web server:
```bash
# On each VM
wget http://internal-server/license.lic -O /tmp/license.lic
sudo cp /tmp/license.lic /var/appd/config/
appdcli license controller /var/appd/config/license.lic
```

---

## API-Based License Management (Advanced)

For automation, you can use the Controller REST API:

```bash
# Get license info
curl -u admin:password \
  https://controller-team1.splunkylabs.com/controller/rest/licenseusage/account

# Check license expiration
curl -u admin:password \
  https://controller-team1.splunkylabs.com/controller/rest/licenseinfo
```

---

## Summary Checklist

### Instructor Setup (One Time):
- [ ] Upload license to S3 using admin credentials
- [ ] Verify S3 bucket policy allows student read access
- [ ] Test download with lab-student credentials
- [ ] Document S3 bucket name in lab guide

### Per-Team Deployment:
- [ ] Deploy infrastructure (phases 1-3)
- [ ] Install Controller (phase 7)
- [ ] Apply license using script
- [ ] Verify in Controller UI
- [ ] Document license expiration for students

### Monitoring:
- [ ] Check license usage weekly
- [ ] Alert if approaching limits
- [ ] Renew 2 weeks before expiration

---

**Total Time:**
- Initial S3 upload: ~2 minutes
- Per-team application: ~7 minutes (mostly waiting)
- Verification: ~2 minutes

**Automation:** Fully scripted, can be integrated into deployment pipeline

