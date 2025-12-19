# Team 5 EUM Fix - Complete Resolution Guide

**Date**: December 18, 2025  
**Team**: Team 5  
**Status**: 🔴 ROOT CAUSE IDENTIFIED - Configuration Fix Required  

---

## 🎯 Executive Summary

**Problem**: EUM functionality not working despite pods running  
**Root Cause**: `globals.yaml.gotmpl` configuration has incorrect external URLs pointing to internal nip.io addresses instead of public DNS  
**Impact**: EUM endpoints returning HTTP 404, Controller cannot communicate with EUM services  
**Solution**: Update globals.yaml.gotmpl with correct public DNS URLs, sync services, then configure admin.jsp  

---

## 🔍 Root Cause Analysis

### Current State (BROKEN):

**Endpoint Test Results**:
```
✅ Controller:     https://controller-team5.splunkylabs.com/controller (HTTP 200)
❌ EUM Collector:  https://controller-team5.splunkylabs.com/eumcollector (HTTP 404)
❌ EUM Aggregator: https://controller-team5.splunkylabs.com/eumaggregator (HTTP 404)  
❌ Events Service: https://controller-team5.splunkylabs.com/events (HTTP 404)
```

### Configuration Issue Found:

**File**: `/var/appd/config/globals.yaml.gotmpl` on VM1

**Current Values (INCORRECT)**:
```yaml
# Line 82-83: EUM service external URL
eum:
  externalUrl: https://10.5.0.142.nip.io

# Line 86-88: Events service configuration  
events:
  enableSsl: true
  externalUrl: https://10.5.0.142.nip.io:32105
```

**Required Values (CORRECT)**:
```yaml
# Line 82-83: EUM service external URL
eum:
  externalUrl: https://controller-team5.splunkylabs.com/eumaggregator

# Line 86-88: Events service configuration
events:
  enableSsl: true
  externalUrl: https://controller-team5.splunkylabs.com/events
```

---

## ✅ Complete Fix Procedure

### Prerequisites

- SSH access to team5-vm-1
- VM1 Public IP: `54.200.217.241` (from state/team5/vm1-public-ip.txt)
- Password: `AppDynamics123!` (or current VM password)
- Root/sudo access on VM
- Time required: 15-20 minutes

---

### Option 1: Automated Fix (RECOMMENDED)

Use the automated fix script:

```bash
cd /Users/bmstoner/code_projects/dec25_lab
./deployment/fix-eum-config.sh --team 5
```

**What it does**:
1. Backs up current globals.yaml.gotmpl
2. Updates EUM externalUrl to public DNS
3. Updates Events externalUrl to public DNS
4. Syncs AppDynamics services (5-10 minutes)
5. Restarts EUM pod
6. Verifies configuration

**Expected Duration**: 10-15 minutes

---

### Option 2: Manual Fix (Step-by-Step)

If the automated script fails or you prefer manual control:

#### Step 1: SSH to VM1

```bash
ssh appduser@54.200.217.241
# Password: AppDynamics123!
```

---

#### Step 2: Backup Current Configuration

```bash
sudo cp /var/appd/config/globals.yaml.gotmpl \
        /var/appd/config/globals.yaml.gotmpl.backup-$(date +%Y%m%d-%H%M%S)

sudo cp /var/appd/config/globals.yaml.gotmpl \
        /var/appd/config/globals.yaml.gotmpl.before-eum-fix

ls -la /var/appd/config/globals.yaml.gotmpl*
```

---

#### Step 3: Update EUM External URL

```bash
# Update EUM externalUrl
sudo sed -i 's|externalUrl: https://10.5.0.142.nip.io|externalUrl: https://controller-team5.splunkylabs.com/eumaggregator|g' \
    /var/appd/config/globals.yaml.gotmpl

# Verify the change
grep -A2 "^eum:" /var/appd/config/globals.yaml.gotmpl
```

**Expected Output**:
```yaml
eum:
  externalUrl: https://controller-team5.splunkylabs.com/eumaggregator
```

---

#### Step 4: Update Events External URL

```bash
# Update Events externalUrl
sudo sed -i 's|externalUrl: https://10.5.0.142.nip.io:32105|externalUrl: https://controller-team5.splunkylabs.com/events|g' \
    /var/appd/config/globals.yaml.gotmpl

# Verify the change
grep -A3 "^events:" /var/appd/config/globals.yaml.gotmpl
```

**Expected Output**:
```yaml
events:
  enableSsl: true
  externalUrl: https://controller-team5.splunkylabs.com/events
```

---

#### Step 5: Save Configuration to State Directory (Local Machine)

Back on your local machine:

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Download the updated configuration for backup
scp appduser@54.200.217.241:/var/appd/config/globals.yaml.gotmpl \
    state/team5/configs/globals.yaml.gotmpl.fixed
```

---

#### Step 6: Sync AppDynamics Services

**⚠️ IMPORTANT**: This step takes 5-10 minutes

Back on VM1:

```bash
appdcli sync appd
```

**What this does**:
- Regenerates Helm charts with new configuration
- Updates Kubernetes manifests
- Reconfigures ingress routing
- Updates service endpoints

**Monitor Progress**:
```bash
# Watch the sync process
kubectl get pods -A -w

# Check for any errors
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

#### Step 7: Restart EUM and Events Pods

```bash
# Restart EUM pod
kubectl delete pod -n cisco-eum eum-ss-0

# Wait for pod to restart (30 seconds)
sleep 30

# Check EUM pod status
kubectl get pods -n cisco-eum

# Restart Events pod
kubectl delete pod -n cisco-events events-ss-0

# Wait for pod to restart
sleep 30

# Check Events pod status
kubectl get pods -n cisco-events
```

**Expected**: Pods should show `Running` status with `READY 1/1`

---

#### Step 8: Verify Ingress Configuration

```bash
# Check ingress routes
kubectl get ingress -A

# Describe controller ingress (should show /eumcollector, /eumaggregator, /events paths)
kubectl describe ingress -n cisco-controller

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

---

#### Step 9: Test Endpoints from VM

```bash
# Test EUM Collector
curl -k https://controller-team5.splunkylabs.com/eumcollector/health

# Test EUM Aggregator
curl -k https://controller-team5.splunkylabs.com/eumaggregator/health

# Test Events Service
curl -k https://controller-team5.splunkylabs.com/events/health
```

**Expected**: Each should return a response (not 404)

---

#### Step 10: Verify Services Status

```bash
# Check overall service health
appdcli ping

# Check EUM-specific health
appdcli ping | grep -i eum
```

**Expected**: EUM should show "Success" or at least not "Failed" due to configuration

---

### Step 11: Test Endpoints from Outside (Local Machine)

Back on your local machine:

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Test all endpoints
./scripts/verify-eum-config.sh --team 5

# Or manually test
curl -k -I https://controller-team5.splunkylabs.com/eumcollector/health
curl -k -I https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k -I https://controller-team5.splunkylabs.com/events/health
```

**Expected**: HTTP 200 or 401/403 (indicating service is responding, just needs auth)  
**Bad**: HTTP 404 (indicates routing still broken)

---

## 🎛️ Configure admin.jsp Controller Settings

**⚠️ ONLY DO THIS AFTER THE ABOVE FIX IS APPLIED AND VERIFIED**

Once the endpoints are responding (not 404), configure the Controller to use them:

### Access admin.jsp

1. Open browser: `https://controller-team5.splunkylabs.com/controller/admin.jsp`
2. Enter password when prompted: `welcome` (default - unless changed)
3. Note: admin.jsp automatically uses `root` user - no username field

### Update Controller Settings

Click **Controller Settings** in left navigation, then update these properties (use filter box to find each):

| Property | New Value | Notes |
|----------|-----------|-------|
| `eum.beacon.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.beacon.https.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.cloud.host` | `https://controller-team5.splunkylabs.com/eumaggregator` | ✅ Include https:// |
| `eum.es.host` | `controller-team5.splunkylabs.com:443` | Use hostname:port |
| `appdynamics.on.premise.event.service.url` | `https://controller-team5.splunkylabs.com/events` | ✅ Include https:// |
| `eum.mobile.screenshot.host` | `controller-team5.splunkylabs.com/screenshots` | ⚠️ NO https:// |

**For each property**:
1. Type property name in filter box
2. Click property when it appears
3. Update **Value** field
4. Click **Save**
5. Move to next property

---

## ✅ Final Verification

### 1. Test EUM Functionality

1. Log in to Controller: `https://controller-team5.splunkylabs.com/controller/`
2. Navigate: **User Experience** → **Browser Apps**
3. Click **Create Application**
4. Follow wizard to create a test Browser App
5. Get JavaScript snippet
6. **Verify**: Beacon URLs in snippet point to `controller-team5.splunkylabs.com`

### 2. Verify Beacon Configuration

Check the generated JavaScript for correct URLs:

```javascript
window['adrum-start-time'] = new Date().getTime();
(function(config){
    config.appKey = 'AD-AAB-AAA-ABC';
    config.adrumExtUrlHttp = 'http://controller-team5.splunkylabs.com/eumcollector';
    config.adrumExtUrlHttps = 'https://controller-team5.splunkylabs.com/eumcollector';
    config.beaconUrlHttp = 'http://controller-team5.splunkylabs.com/eumcollector';
    config.beaconUrlHttps = 'https://controller-team5.splunkylabs.com/eumcollector';
    // ... rest of config
```

**Good**: URLs point to `controller-team5.splunkylabs.com`  
**Bad**: URLs still show nip.io or incorrect hostnames

### 3. Check Service Health

```bash
ssh appduser@54.200.217.241
appdcli ping | grep -A5 -B5 eum
```

Expected: EUM shows "Success" status

---

## 🔧 Troubleshooting

### Issue: Endpoints Still Return 404 After Fix

**Possible Causes**:

1. **appdcli sync not completed**
   - Wait longer (can take 10+ minutes)
   - Check: `kubectl get pods -A` - all pods should be Running
   - Check: `kubectl get events -A --sort-by='.lastTimestamp' | tail -30`

2. **Ingress not properly configured**
   ```bash
   kubectl get ingress -A
   kubectl describe ingress -n cisco-controller
   ```
   - Should show paths: `/eumcollector`, `/eumaggregator`, `/events`

3. **DNS resolution issue**
   ```bash
   nslookup controller-team5.splunkylabs.com
   ```
   - Should resolve to ALB DNS: `appd-team5-alb-2117772778.us-west-2.elb.amazonaws.com`

4. **ALB target health issue**
   ```bash
   # On local machine
   aws elbv2 describe-target-health \
     --target-group-arn $(cat state/team5/tg.id) \
     --profile appd-lab-team5 \
     --region us-west-2
   ```
   - All targets should show `healthy` status

---

### Issue: admin.jsp Properties Not Found

**Solution**:
- Properties may not exist in OVA deployment
- Focus on these critical ones:
  - `eum.cloud.host`
  - `eum.es.host`
  - `appdynamics.on.premise.event.service.url`
- Other properties may be managed via globals.yaml.gotmpl

---

### Issue: JavaScript Snippet Has Wrong URLs

**Solution**:
1. Wait 2-3 minutes for Controller to reload configuration
2. Restart Controller pod:
   ```bash
   kubectl delete pod -n cisco-controller controller-0
   ```
3. Wait for pod to restart (2-3 minutes)
4. Try generating new Browser App snippet
5. If still wrong, check admin.jsp settings again

---

### Issue: Can't SSH to VM

**Solutions**:

1. **Check VM is running**
   ```bash
   aws ec2 describe-instances \
     --instance-ids $(cat state/team5/vm1.id) \
     --profile appd-lab-team5 \
     --region us-west-2 \
     --query 'Reservations[0].Instances[0].State.Name'
   ```

2. **Verify Security Group allows your IP**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids $(cat state/team5/vm-sg.id) \
     --profile appd-lab-team5 \
     --region us-west-2 \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
   ```

3. **Try alternate SSH**
   ```bash
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       -o PubkeyAuthentication=no appduser@54.200.217.241
   ```

---

## 📚 Reference Files

### Configuration Files

- **Original config**: `state/team5/configs/globals.yaml.gotmpl.original`
- **Current config**: `state/team5/configs/globals.yaml.gotmpl.updated`  
- **Fixed config**: `state/team5/configs/globals.yaml.gotmpl.fixed` (after fix)

### Documentation

- **Detailed admin.jsp guide**: `docs/TEAM5_EUM_ADMIN_CONFIG.md`
- **Common EUM issues**: `common_issues.md` (sections on EUM)
- **Deployment scripts**: `deployment/fix-eum-config.sh`

### Useful Scripts

```bash
# Automated fix
./deployment/fix-eum-config.sh --team 5

# Verify configuration
./scripts/verify-eum-config.sh --team 5

# Check deployment status
./scripts/check-status.sh --team 5

# SSH to VM1
./scripts/ssh-vm1.sh --team 5
```

---

## 📋 Quick Command Reference

```bash
# === ON LOCAL MACHINE ===

# Test endpoints externally
curl -k -I https://controller-team5.splunkylabs.com/eumcollector/health
curl -k -I https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k -I https://controller-team5.splunkylabs.com/events/health

# SSH to VM1
ssh appduser@54.200.217.241

# === ON VM1 ===

# Backup and update configuration
sudo cp /var/appd/config/globals.yaml.gotmpl /var/appd/config/globals.yaml.gotmpl.backup
sudo sed -i 's|https://10.5.0.142.nip.io|https://controller-team5.splunkylabs.com/eumaggregator|g' /var/appd/config/globals.yaml.gotmpl
sudo sed -i 's|https://10.5.0.142.nip.io:32105|https://controller-team5.splunkylabs.com/events|g' /var/appd/config/globals.yaml.gotmpl

# Sync services (takes 5-10 minutes)
appdcli sync appd

# Restart pods
kubectl delete pod -n cisco-eum eum-ss-0
kubectl delete pod -n cisco-events events-ss-0

# Check status
appdcli ping | grep -i eum
kubectl get pods -n cisco-eum
kubectl get pods -n cisco-events
kubectl get ingress -A

# Test endpoints from VM
curl -k https://controller-team5.splunkylabs.com/eumcollector/health
curl -k https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k https://controller-team5.splunkylabs.com/events/health
```

---

## ⏱️ Estimated Timeline

- **Configuration Update**: 5 minutes
- **Service Sync**: 5-10 minutes  
- **Pod Restarts**: 2-3 minutes
- **Verification**: 5 minutes
- **admin.jsp Configuration**: 10 minutes
- **Final Testing**: 5 minutes

**Total**: 30-40 minutes

---

## ✅ Success Criteria

- [ ] globals.yaml.gotmpl updated with public DNS URLs
- [ ] appdcli sync completed without errors
- [ ] EUM and Events pods restarted and running
- [ ] EUM Collector endpoint responds (not 404)
- [ ] EUM Aggregator endpoint responds (not 404)
- [ ] Events Service endpoint responds (not 404)
- [ ] admin.jsp Controller Settings configured
- [ ] Can create Browser App in Controller UI
- [ ] JavaScript snippet has correct beacon URLs
- [ ] appdcli ping shows EUM status as "Success"

---

**Next Steps**: Follow the "Complete Fix Procedure" above, starting with Option 1 (Automated Fix) or Option 2 (Manual Fix) based on your preference.

**Support**: See `common_issues.md` for additional troubleshooting or contact bmstoner@cisco.com

---

**Last Updated**: December 18, 2025  
**Document Version**: 1.0  
**Team**: 5  
**Controller URL**: https://controller-team5.splunkylabs.com/controller

