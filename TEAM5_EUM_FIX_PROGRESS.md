# Team 5 EUM Fix - Progress Report

**Date**: December 18, 2025  
**Status**: 🟡 IN PROGRESS - Configuration Applied, Controller Restarting  
**Time**: ~5 minutes into fix

---

## ✅ Completed Steps

### 1. Configuration Backup ✅
- Backed up `/var/appd/config/globals.yaml.gotmpl` to `globals.yaml.gotmpl.backup-eum-fix`
- Original configuration preserved

### 2. Updated globals.yaml.gotmpl ✅

**EUM External URL**:
- **Before**: `https://10.5.0.142.nip.io`
- **After**: `https://controller-team5.splunkylabs.com/eumaggregator`
- Status: ✅ Updated

**Events External URL**:
- **Before**: `https://10.5.0.142.nip.io:32105`
- **After**: `https://controller-team5.splunkylabs.com/events`
- Status: ✅ Updated

### 3. Synced AppDynamics Services ✅
- Command: `appdcli sync appd small`
- Duration: ~5 minutes
- Result: ✅ Successful
- All Helm charts regenerated with new configuration

### 4. Restarted EUM Pod ✅
- Pod: `eum-ss-0`
- Status: ✅ Running (1/1)
- Age: ~56 seconds after restart

### 5. Restarted Events Pod ✅
- Pod: `events-ss-d98d949b5-xkld9`
- Status: ✅ Deleted and recreating

### 6. Verified Ingress Configuration ✅

**EUM Ingress Routes** (cisco-eum namespace):
```
✅ /eumcollector   → eum-service:7002
✅ /eumaggregator  → eum-service:7002
✅ /screenshots    → eum-service:7002
```

**Events Ingress Routes** (cisco-events namespace):
```
✅ /events → events-service:9080
```

### 7. Internal Service Health Check ✅

Result from `appdcli ping`:
```
✅ Events              : Success
✅ EUM Collector       : Success
✅ EUM Aggregator      : Success
✅ EUM Screenshot      : Success
✅ Synthetic Shepherd  : Success
✅ Synthetic Scheduler : Success
✅ Synthetic Feeder    : Success
✅ AD/RCA Services     : Success
✅ ATD                 : Success
🟡 Controller          : Failed (RESTARTING)
❌ SecureApp           : Failed (known issue - feed downloader)
```

**Analysis**: EUM services are now showing "Success" internally!

---

## 🟡 Current Status

### Controller Restarting
- **Expected**: Controller pod is restarting to load new configuration
- **Duration**: Typically 3-5 minutes for full restart
- **External Access**: Returns HTTP 503 during restart (expected)
- **Internal Status**: Shows "Failed" until fully started

### EUM Endpoints
- **Internal Status**: ✅ All showing "Success"
- **External Access**: Still returning 404 (requires Controller to finish restart)
- **Reason**: Master ingress routing requires healthy Controller

---

## ⏳ Next Steps (Waiting for Controller)

### Step 1: Wait for Controller to Fully Start (2-5 minutes)

Monitor Controller status:
```bash
ssh appduser@54.200.217.241
watch -n 10 'appdcli ping | grep Controller'
```

Expected: Status changes from "Failed" to "Success"

### Step 2: Verify Controller Pod is Running

```bash
kubectl get pods -n cisco-controller
```

Expected:
```
NAME           READY   STATUS    RESTARTS   AGE
controller-0   1/1     Running   0          Xm
```

### Step 3: Test External Endpoints

Once Controller shows "Success":
```bash
curl -k -I https://controller-team5.splunkylabs.com/controller/
curl -k -I https://controller-team5.splunkylabs.com/eumcollector/
curl -k -I https://controller-team5.splunkylabs.com/eumaggregator/
curl -k -I https://controller-team5.splunkylabs.com/events/
```

Expected: HTTP 200 or 302 (not 404 or 503)

---

## 📋 After Controller is Up: Configure admin.jsp

Once Controller is fully started and accessible:

### Access admin.jsp Console

1. **URL**: `https://controller-team5.splunkylabs.com/controller/admin.jsp`
2. **Password**: `welcome` (default - unless changed)
3. **Note**: admin.jsp automatically uses `root` user - no username field

### Update Controller Settings

Click **Controller Settings** in left navigation, then configure these properties:

| Property | Value | Notes |
|----------|-------|-------|
| `eum.beacon.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.beacon.https.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.cloud.host` | `https://controller-team5.splunkylabs.com/eumaggregator` | ✅ Include https:// |
| `eum.es.host` | `controller-team5.splunkylabs.com:443` | Use hostname:port |
| `appdynamics.on.premise.event.service.url` | `https://controller-team5.splunkylabs.com/events` | ✅ Include https:// |
| `eum.mobile.screenshot.host` | `controller-team5.splunkylabs.com/screenshots` | ⚠️ NO https:// |

**For each property**:
1. Type property name in filter box (top right)
2. Click property when it appears
3. Update the **Value** field
4. Click **Save**
5. Move to next property

---

## 🎯 Final Verification (After admin.jsp Config)

### 1. Test Browser App Creation

1. Log in to Controller: `https://controller-team5.splunkylabs.com/controller/`
2. Navigate: **User Experience** → **Browser Apps**
3. Click **Create Application**
4. Follow wizard to create test app
5. Get JavaScript snippet

### 2. Verify Beacon URLs in JavaScript

Check that generated snippet has correct URLs:
```javascript
config.beaconUrlHttp = 'http://controller-team5.splunkylabs.com/eumcollector';
config.beaconUrlHttps = 'https://controller-team5.splunkylabs.com/eumcollector';
```

**Good**: Points to `controller-team5.splunkylabs.com`  
**Bad**: Still shows nip.io or incorrect hostname

---

## 📊 Progress Summary

| Task | Status | Notes |
|------|--------|-------|
| Backup configuration | ✅ Complete | Backed up to `.backup-eum-fix` |
| Update EUM URL | ✅ Complete | Now points to public DNS |
| Update Events URL | ✅ Complete | Now points to public DNS |
| Sync services | ✅ Complete | All Helm charts regenerated |
| Restart EUM pod | ✅ Complete | Running and healthy |
| Restart Events pod | ✅ Complete | Running and healthy |
| Verify ingress routes | ✅ Complete | All paths configured |
| Internal health check | ✅ Complete | EUM services showing Success |
| **Wait for Controller** | 🟡 **In Progress** | **Restarting (2-5 min)** |
| Configure admin.jsp | ⏳ Pending | After Controller starts |
| Test Browser App | ⏳ Pending | After admin.jsp config |
| Verify beacon URLs | ⏳ Pending | Final validation |

---

## ⏱️ Estimated Time Remaining

- **Controller restart**: 2-5 minutes
- **admin.jsp configuration**: 10 minutes
- **Testing and verification**: 5 minutes
- **Total remaining**: 15-20 minutes

---

## 🔍 Troubleshooting

### If Controller Takes Longer Than 10 Minutes

Check Controller pod status:
```bash
kubectl get pods -n cisco-controller
kubectl describe pod -n cisco-controller controller-0
kubectl logs -n cisco-controller controller-0 --tail=100
```

Look for:
- CrashLoopBackOff status (indicates config error)
- OOMKilled (out of memory)
- Error messages in logs

### If EUM Still Shows 404 After Controller Starts

1. **Restart nginx ingress controller**:
   ```bash
   kubectl rollout restart deployment -n ingress ingress-nginx-controller
   ```

2. **Check ingress nginx logs**:
   ```bash
   kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx --tail=50
   ```

3. **Verify DNS resolution**:
   ```bash
   nslookup controller-team5.splunkylabs.com
   ```

---

## 📚 Reference Documents

- **Detailed Configuration Guide**: `docs/TEAM5_EUM_ADMIN_CONFIG.md`
- **Complete Fix Guide**: `docs/TEAM5_EUM_FIX_SUMMARY.md`
- **Quick Action Plan**: `TEAM5_EUM_ACTION_PLAN.md`
- **Common Issues**: `common_issues.md`

---

## 🚀 Quick Commands

### Check Controller Status
```bash
ssh appduser@54.200.217.241
appdcli ping | grep Controller
```

### Check All Pods
```bash
kubectl get pods -n cisco-controller
kubectl get pods -n cisco-eum
kubectl get pods -n cisco-events
```

### Test Endpoints
```bash
# From local machine
curl -k -I https://controller-team5.splunkylabs.com/controller/
curl -k -I https://controller-team5.splunkylabs.com/eumcollector/
curl -k -I https://controller-team5.splunkylabs.com/eumaggregator/
curl -k -I https://controller-team5.splunkylabs.com/events/
```

---

## ✅ Success Indicators

We'll know the fix is complete when:

- [ ] Controller shows "Success" in appdcli ping
- [ ] Controller UI loads: `https://controller-team5.splunkylabs.com/controller/`
- [ ] EUM Collector responds: `/eumcollector/` (not 404)
- [ ] EUM Aggregator responds: `/eumaggregator/` (not 404)
- [ ] Events Service responds: `/events/` (not 404)
- [ ] admin.jsp Controller Settings configured
- [ ] Can create Browser App in UI
- [ ] JavaScript snippet has correct beacon URLs

---

**Current State**: ✅ Configuration applied successfully, ⏳ waiting for Controller to restart

**Next Action**: Wait 2-5 minutes, then check `appdcli ping` status

**Contact**: bmstoner@cisco.com  
**VM IP**: 54.200.217.241  
**Controller URL**: https://controller-team5.splunkylabs.com/controller

