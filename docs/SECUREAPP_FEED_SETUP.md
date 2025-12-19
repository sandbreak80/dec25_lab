# SecureApp Vulnerability Feed Setup Guide

**Quick Start Guide for Enabling Automatic Vulnerability Feed Downloads**

---

## Overview

AppDynamics SecureApp requires vulnerability feed data to perform CVE scanning. This guide walks you through configuring automatic daily feed downloads from AppDynamics servers.

**Time Required**: 10-15 minutes (plus 5-10 minutes for initial feed download)

---

## Prerequisites

✅ SecureApp installed and running (`appdcli ping` shows SecureApp)  
✅ Internet connectivity to `download.appdynamics.com`  
✅ Access to AppDynamics accounts portal (https://accounts.appdynamics.com/)

---

## Step 1: Create Portal User for Feed Downloads

### 1.1 Log in to AppDynamics Accounts Portal

Navigate to: **https://accounts.appdynamics.com/**

### 1.2 Create Dedicated User

**Best Practice**: Create a non-admin user specifically for feed downloads.

1. Go to **Users** section
2. Click **Add User**
3. Fill in details:
   - **Username**: `feed-downloader` (or your preferred name)
   - **Email**: Valid email address
   - **Role**: Basic user (do not assign admin privileges)
   - **Purpose**: Vulnerability feed downloads
4. Set a strong password
5. **Save** the user

### 1.3 Note Credentials

Write down:
- Username: ________________
- Password: ________________

**Security Note**: Store these credentials securely. They will be used by the system to download feeds daily.

---

## Step 2: Configure Automatic Feed Downloads

### 2.1 SSH to Primary Node

```bash
ssh appduser@<vm-ip-address>
# Use your VM password
```

### 2.2 Set Portal Credentials

```bash
appdcli run secureapp setDownloadPortalCredentials <portal-username>
```

**Example**:
```bash
appdcli run secureapp setDownloadPortalCredentials feed-downloader
```

You will be prompted:
```
Enter password for portal user feed-downloader:
```

Type the password and press Enter.

**Expected Output**:
```
Portal credentials configured successfully
```

### 2.3 (Optional) Trigger Immediate Feed Download

Instead of waiting for the daily scheduled download:

```bash
appdcli run secureapp restartFeedProcessing
```

**Expected Output**:
```
Feed processing restarted
```

---

## Step 3: Verify Feed Download

### 3.1 Monitor Vuln Pod Logs

```bash
# Get vuln pod name
kubectl get pods -n cisco-secureapp | grep vuln

# Watch logs (Ctrl+C to exit)
kubectl logs -n cisco-secureapp <vuln-pod-name> --tail=50 -f
```

**What to Look For**:
- Messages about downloading feeds
- No more "on-prem feed not available" retries
- Processing messages for feed data

### 3.2 Check Feed Entry Count

Wait 5-10 minutes after restarting feed processing, then:

```bash
appdcli run secureapp numAgentReports
```

**Expected Output**:
```
Feed Entries: 10376
```

If the number is greater than 0, feeds are downloading!

### 3.3 Verify SecureApp Status

```bash
appdcli ping | grep SecureApp
```

**Expected Output (after feeds populate)**:
```
| SecureApp | Success |
```

**Note**: Status may still show "Failed" until first feed download completes (5-15 minutes).

---

## Step 4: Run Health Check

```bash
appdcli run secureapp health
```

**Look for**:
- "SecureApp checks have passed"
- "Feed Entries: XXXXX" (number greater than 0)
- All services showing "Ready"

---

## Troubleshooting

### Issue: Password Prompt Doesn't Appear

**Solution**: Ensure you're using the exact command:
```bash
appdcli run secureapp setDownloadPortalCredentials <username>
```

### Issue: "Failed to authenticate" Error

**Causes**:
1. Incorrect username or password
2. User doesn't have portal access
3. Network connectivity issue

**Solution**:
1. Verify credentials in accounts portal
2. Test network: `ping download.appdynamics.com`
3. Re-run the command with correct credentials

### Issue: Feeds Not Downloading After 15 Minutes

**Check**:
```bash
# View vuln pod logs
kubectl logs -n cisco-secureapp <vuln-pod-name> --tail=100

# Check for errors
kubectl describe pod <vuln-pod-name> -n cisco-secureapp
```

**Common Issues**:
- Network firewall blocking download.appdynamics.com
- Proxy settings required
- Invalid credentials

### Issue: SecureApp Still Shows "Failed"

**Wait Time**: Initial feed download can take 10-15 minutes

**After 30 minutes**, if still failing:
```bash
# Generate debug report
appdcli run secureapp debugReport

# Open support case with AppDynamics
```

---

## Verification Checklist

Once configured, verify all items:

- [ ] Portal user created
- [ ] Credentials configured via `setDownloadPortalCredentials`
- [ ] Feed processing restarted
- [ ] Vuln pod logs show feed download activity
- [ ] `numAgentReports` shows count > 0
- [ ] `appdcli ping` shows SecureApp as Success
- [ ] `appdcli run secureapp health` passes

---

## Ongoing Maintenance

### Automatic Updates

Once configured:
- ✅ Feeds download automatically **every 24 hours**
- ✅ No manual intervention required
- ✅ Vuln pod processes feeds automatically

### Monitoring

Periodically check feed status:
```bash
appdcli run secureapp numAgentReports
```

Number should increase over time as new vulnerabilities are published.

### Password Rotation

If portal user password changes:
```bash
appdcli run secureapp setDownloadPortalCredentials <username>
# Enter new password
```

---

## Air-Gapped Environments

If your deployment has **no internet access**:

### Alternative: Manual Feed Upload

1. **Contact AppDynamics Support** to obtain:
   - Feed license key file
   - Feed data files

2. **Set Feed Key**:
   ```bash
   appdcli run secureapp setFeedKey /path/to/feed-key-file
   ```

3. **Upload Feed**:
   ```bash
   appdcli run secureapp uploadFeed /path/to/feed-file.tar.gz
   ```

4. **Process Feed**:
   ```bash
   appdcli run secureapp restartFeedProcessing
   ```

**Note**: Manual uploads must be repeated periodically to keep vulnerability data current.

---

## Advanced Commands

### Show Current Configuration

```bash
appdcli run secureapp showConfig
```

### Check API Health

```bash
appdcli run secureapp checkApi
```

### Test Agent Authentication

```bash
appdcli run secureapp checkAgentAuth
```

### Generate Debug Report

```bash
appdcli run secureapp debugReport
```

This creates a comprehensive report for troubleshooting with AppDynamics support.

---

## Support Resources

- **AppDynamics Documentation**: https://docs.appdynamics.com/
- **Accounts Portal**: https://accounts.appdynamics.com/
- **Support Portal**: https://support.appdynamics.com/
- **SecureApp Guide**: https://docs.appdynamics.com/appd-cloud/en/cisco-secure-application

---

## Summary

**What You Accomplished**:
1. ✅ Created dedicated portal user for feed downloads
2. ✅ Configured automatic feed downloads
3. ✅ Enabled daily vulnerability feed updates
4. ✅ Verified SecureApp can scan for known CVEs

**Result**: SecureApp is now fully functional with vulnerability scanning capability!

**Next Steps**: 
- Configure agents to report to SecureApp
- Review security findings in Controller UI
- Set up alerting for critical vulnerabilities


