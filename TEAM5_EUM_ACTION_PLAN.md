# Team 5 EUM - Action Plan

**Date**: December 18, 2025  
**Status**: 🔴 Issue Identified - Action Required  
**Priority**: HIGH

---

## 🎯 The Problem

EUM pods are running, but EUM functionality not working because:

1. **Root Cause**: `globals.yaml.gotmpl` has wrong external URLs
   - Currently pointing to: `https://10.5.0.142.nip.io` (internal IP)
   - Should point to: `https://controller-team5.splunkylabs.com/eumaggregator`

2. **Result**: Endpoints returning HTTP 404
   ```
   ❌ /eumcollector   → HTTP 404
   ❌ /eumaggregator  → HTTP 404
   ❌ /events         → HTTP 404
   ```

3. **admin.jsp configuration alone won't fix this** - Need to fix globals.yaml.gotmpl first

---

## ✅ The Fix (Two Steps)

### Step 1: Fix globals.yaml.gotmpl Configuration (MUST DO FIRST)

**Option A - Automated (RECOMMENDED)**:
```bash
cd /Users/bmstoner/code_projects/dec25_lab
./deployment/fix-eum-config.sh --team 5
```

**Option B - Manual**:
```bash
# SSH to VM1
ssh appduser@54.200.217.241

# Update configuration
sudo sed -i 's|https://10.5.0.142.nip.io|https://controller-team5.splunkylabs.com/eumaggregator|g' \
    /var/appd/config/globals.yaml.gotmpl

sudo sed -i 's|https://10.5.0.142.nip.io:32105|https://controller-team5.splunkylabs.com/events|g' \
    /var/appd/config/globals.yaml.gotmpl

# Sync services (takes 5-10 minutes)
appdcli sync appd

# Restart EUM pod
kubectl delete pod -n cisco-eum eum-ss-0

# Verify endpoints work
curl -k https://controller-team5.splunkylabs.com/eumcollector/health
curl -k https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k https://controller-team5.splunkylabs.com/events/health
```

**Expected Result**: Endpoints should return HTTP 200 (not 404)

---

### Step 2: Configure admin.jsp Controller Settings (AFTER Step 1)

**URL**: `https://controller-team5.splunkylabs.com/controller/admin.jsp`  
**Password**: `welcome` (default)  
**Note**: admin.jsp automatically uses `root` user - no username field

**Navigate to**: Controller Settings

**Update these properties** (use filter box to find):

| Property | Value | Notes |
|----------|-------|-------|
| `eum.beacon.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.beacon.https.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.cloud.host` | `https://controller-team5.splunkylabs.com/eumaggregator` | ✅ Include https:// |
| `eum.es.host` | `controller-team5.splunkylabs.com:443` | Use hostname:port |
| `appdynamics.on.premise.event.service.url` | `https://controller-team5.splunkylabs.com/events` | ✅ Include https:// |
| `eum.mobile.screenshot.host` | `controller-team5.splunkylabs.com/screenshots` | ⚠️ NO https:// |

---

## 📋 Quick Verification

After completing both steps:

```bash
# Test endpoints
curl -k -I https://controller-team5.splunkylabs.com/eumcollector/health
curl -k -I https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k -I https://controller-team5.splunkylabs.com/events/health
```

**Expected**: HTTP 200 (or at least not 404)

Then:
1. Log in to Controller UI: `https://controller-team5.splunkylabs.com/controller/`
2. Create a Browser Application
3. Verify JavaScript snippet has correct beacon URLs

---

## 📚 Detailed Documentation

- **Complete Fix Guide**: `docs/TEAM5_EUM_FIX_SUMMARY.md`
- **admin.jsp Configuration**: `docs/TEAM5_EUM_ADMIN_CONFIG.md`
- **Common Issues**: `common_issues.md` (EUM sections)

---

## ⏱️ Time Estimate

- **Step 1 (Configuration Fix)**: 15-20 minutes
- **Step 2 (admin.jsp)**: 10 minutes
- **Total**: 25-30 minutes

---

## 🚨 Critical Points

1. **Order matters**: Fix globals.yaml.gotmpl FIRST, then admin.jsp
2. **appdcli sync takes time**: Wait full 5-10 minutes for completion
3. **Use 'root' user**: admin.jsp requires root credentials, not regular admin
4. **Test endpoints**: Verify HTTP 200 before moving to admin.jsp configuration
5. **Wait for reload**: Controller needs 2-3 minutes to apply admin.jsp changes

---

## 🆘 Quick Help

**If SSH fails**:
- Verify password: `AppDynamics123!`
- Try: `ssh -o PubkeyAuthentication=no appduser@54.200.217.241`

**If endpoints still 404 after fix**:
- Wait longer for `appdcli sync` to complete
- Check: `kubectl get pods -A` (all should be Running)
- Check: `kubectl get ingress -A` (should show /eumcollector, /eumaggregator, /events paths)

**If admin.jsp won't load**:
- Verify Controller is running: `appdcli ping`
- Try incognito browser window
- Clear browser cache

---

**Contact**: bmstoner@cisco.com  
**Team 5 Resources**: `/Users/bmstoner/code_projects/dec25_lab/state/team5/`

---

**START HERE** → Follow Step 1 above, verify it works, then move to Step 2

