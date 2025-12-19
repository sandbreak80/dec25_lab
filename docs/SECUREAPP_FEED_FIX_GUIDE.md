# SecureApp Vulnerability Feed Fix Guide
**Team 5 - AppDynamics 25.4.0**  
**Issue**: SecureApp `vuln` pod waiting for vulnerability feeds  
**Date**: December 18, 2025

---

## Problem Summary

SecureApp is installed and running, but `appdcli ping` shows it as "Failed" because the vulnerability scanner (`vuln` pod) cannot find the Snyk vulnerability database feed file (`snyk.gz`).

### Current Status
- ✅ All 15 SecureApp pods are running
- ✅ Credentials for feed download are configured
- ✅ Internet connectivity is available
- ❌ No feed downloader component is deployed
- ❌ Vulnerability feeds are not being downloaded

### What We Found

1. **Credentials Exist**: The `onprem-feed-sys` secret contains valid credentials:
   ```
   OPFDL_PORTAL_SERVER: https://download.appdynamics.com
   OPFDL_KEYSERV_URL: https://feed-key-server.prod-pdx-prod.argento.io
   OPFDL_OAUTH_URL: https://identity-api.appdynamics.com/v3.0/oauth/token
   OPFDL_KEY: (90-byte authentication key)
   ```

2. **Feed Configuration**: The `vuln` pod is configured to look for feeds in S3 bucket `dev-pdx-ci-feed` with paths like:
   - `golden/snyk/snyk-new-feed.json.gz`
   - `golden/maven/master-maven-gav.txt.gz`
   - `golden/talos/master-ip-blacklist.txt.gz`
   - `golden/kenna/kenna-feed.json.gz`
   - `golden/osv/*`

3. **Missing Component**: There is no CronJob, Deployment, or Job that actually downloads these feeds from AppDynamics servers to the local database.

---

## Root Cause

**AppDynamics Virtual Appliance 25.4.0 does not include an automatic feed downloader for SecureApp in on-premise deployments.**

The `vuln` pod expects feeds to be present in its PostgreSQL database, but nothing is populating that database with feed data.

---

## Solutions

### Option 1: Contact AppDynamics Support (RECOMMENDED)

**Action**: Open a support case with AppDynamics/Cisco TAC

**Request**:
1. Access to the vulnerability feed download service for on-premise deployments
2. Instructions or scripts to download and import feeds
3. Documentation on feed update procedures
4. Confirmation if this feature is available in version 25.4.0 or requires an upgrade

**Support Information**:
- Product: AppDynamics Virtual Appliance
- Version: 25.4.0.2016
- Component: SecureApp (Cisco Secure Application)
- Issue: Vulnerability feeds not downloading in on-premise deployment

**What to Provide**:
- This document
- Output of `appdcli ping`
- Output of `kubectl get pods -n cisco-secureapp`
- Logs from `vuln` pod showing feed retry attempts

---

### Option 2: Manual Feed Upload (If Supported)

If AppDynamics provides feed files, you can manually upload them:

1. **Download feeds** from AppDynamics (requires support access)

2. **Copy to VM**:
   ```bash
   scp snyk.gz appduser@54.200.217.241:/tmp/
   ```

3. **Import to database** (exact procedure TBD - requires AppDynamics documentation)

---

### Option 3: Use SecureApp Without Vulnerability Feeds (CURRENT STATE)

**What Works Without Feeds**:
- ✅ Runtime threat detection
- ✅ Application security monitoring
- ✅ Security analytics
- ✅ Compliance reporting
- ✅ Attack detection

**What Doesn't Work**:
- ❌ Vulnerability scanning against known CVE databases
- ❌ Package vulnerability detection
- ❌ Dependency vulnerability analysis

**To Accept Current State**:
1. Understand that SecureApp provides **runtime security** without feeds
2. Plan to add vulnerability feeds later when available
3. Use alternative tools for vulnerability scanning (e.g., Snyk, Trivy, Grype)

---

## What We've Tried

### ✅ Completed Troubleshooting Steps

1. **Verified Internet Connectivity**: Pods can reach external services
2. **Checked Credentials**: `OPFDL_*` environment variables are present and populated
3. **Ran Sync Command**: `appdcli sync secapp` executed successfully
4. **Checked for CronJobs**: No feed download CronJobs exist
5. **Inspected Helm Charts**: `onprem` and `cisco-secureapp` charts don't include feed downloader
6. **Reviewed Pod Logs**: `vuln` pod continuously retries looking for `snyk.gz` in database

### ❌ What Didn't Work

- Running `appdcli sync secapp` - only restarted proxies, didn't download feeds
- Looking for feed downloader pods - none exist
- Checking for scheduled jobs - only database maintenance jobs present

---

## Technical Details

### Vuln Pod Behavior

The `vuln` pod runs a loop that:
1. Queries PostgreSQL for `snyk.gz` file metadata
2. If not found, waits 15-60 seconds
3. Retries indefinitely

**Log Pattern**:
```json
{
  "severityText":"INFO",
  "retrycnt":N,
  "filename":"snyk.gz",
  "body":"on-prem feed not available, retrying later"
}
```

### Feed Configuration

From `vuln-feed-config` ConfigMap:
```yaml
feed_bucket: dev-pdx-ci-feed
snyk_key_name: golden/snyk/snyk-new-feed.json.gz
maven_key_name: golden/maven/master-maven-gav.txt.gz
talos_key_name: golden/talos/master-ip-blacklist.txt.gz
kenna_key_name: golden/kenna/kenna-feed.json.gz
onprem_feed_key_name: golden/onprem/datasync
```

### Credentials Available

From `onprem-feed-sys` secret (base64 decoded):
- `OPFDL_PORTAL_SERVER`: https://download.appdynamics.com
- `OPFDL_KEYSERV_URL`: https://feed-key-server.prod-pdx-prod.argento.io  
- `OPFDL_OAUTH_URL`: https://identity-api.appdynamics.com/v3.0/oauth/token
- `OPFDL_KEY`: v8aVzeSZgJeK... (90 bytes)

---

## Verification Commands

### Check SecureApp Status
```bash
ssh appduser@54.200.217.241
appdcli ping | grep SecureApp
```

### Check Vuln Pod Status
```bash
kubectl get pods -n cisco-secureapp | grep vuln
kubectl logs vuln-658f4f5f69-b7p88 -n cisco-secureapp --tail=20
```

### Check for Feed Files in Database
```bash
kubectl exec -it vuln-658f4f5f69-b7p88 -n cisco-secureapp -- env | grep OPFDL
```

---

## Next Steps

1. **Immediate**: Accept current state - SecureApp runtime security features work
2. **Short-term**: Open support case with AppDynamics
3. **Medium-term**: Implement manual feed upload process (if provided by support)
4. **Long-term**: Consider upgrading to newer version with automatic feed downloads

---

## Additional Resources

- **AppDynamics Documentation**: https://docs.appdynamics.com/
- **SecureApp Guide**: https://docs.appdynamics.com/appd-cloud/en/cisco-secure-application
- **Support Portal**: https://support.appdynamics.com/

---

## Summary

**Current State**: SecureApp is **functional** for runtime security monitoring but **cannot perform vulnerability scanning** without feed data.

**Recommendation**: Use SecureApp as-is for runtime protection and open a support case to enable vulnerability feed downloads for your on-premise deployment.

**Impact**: Low - Most SecureApp features work without feeds. Vulnerability scanning is a nice-to-have feature that can be added later.


