# Team 5 EUM Configuration - admin.jsp Controller Settings

**Date**: December 18, 2025  
**Team**: Team 5  
**Controller URL**: https://controller-team5.splunkylabs.com/controller  
**Status**: EUM Pods Running - Controller Settings Need Configuration

---

## 🎯 Objective

Configure the Controller Settings in admin.jsp to connect the Controller to the EUM and Events Service endpoints running in the Kubernetes cluster.

---

## 📋 Prerequisites

1. **Verify EUM and Events Pods are Running**
   ```bash
   ssh appduser@<vm-ip>
   kubectl get pods -n cisco-eum
   kubectl get pods -n cisco-events
   ```
   All pods should show `Running` status.

2. **Access to Controller admin.jsp**
   - URL: `https://controller-team5.splunkylabs.com/controller/admin.jsp`
   - Password: The root password (default: `welcome` unless changed)
   - Note: admin.jsp automatically uses the `root` user

---

## ⚙️ Controller Settings Configuration

### Step 1: Access admin.jsp Console

1. Open your web browser
2. Navigate to: `https://controller-team5.splunkylabs.com/controller/admin.jsp`
3. Enter password when prompted (default: `welcome`)
   - Note: admin.jsp automatically uses the `root` user - no username field
4. Click **Controller Settings** in the left navigation menu

---

### Step 2: Configure EUM Beacon Endpoints

These settings tell EUM agents (browser/mobile) where to send their data.

#### Setting: `eum.beacon.host`
**Description**: HTTP collector address for EUM agents  
**Value to Set** (⚠️ NO https:// prefix):
```
controller-team5.splunkylabs.com/eumcollector
```

**Steps**:
1. In the filter box (top right), type: `eum.beacon.host`
2. Click the property name when it appears
3. Update the **Value** field with the hostname/path above (without https://)
4. Click **Save**

---

#### Setting: `eum.beacon.https.host`
**Description**: HTTPS collector address for EUM agents  
**Value to Set** (⚠️ NO https:// prefix):
```
controller-team5.splunkylabs.com/eumcollector
```

**Steps**:
1. Filter for: `eum.beacon.https.host`
2. Update value to the hostname/path above (without https://)
3. Click **Save**

**Note**: These properties should NOT include the protocol - just hostname and path.

---

### Step 3: Configure EUM Cloud Host

This setting tells the Controller where to fetch EUM data from.

#### Setting: `eum.cloud.host`
**Description**: EUM API address for Controller to fetch data  
**Value to Set**:
```
https://controller-team5.splunkylabs.com/eumaggregator
```

**Steps**:
1. Filter for: `eum.cloud.host`
2. Update value to the URL above
3. Click **Save**

---

### Step 4: Configure Events Service Endpoint

This setting tells EUM where to send analytics data.

#### Setting: `eum.es.host`
**Description**: Events Service address for analytics data  
**Value to Set**:
```
controller-team5.splunkylabs.com:443
```

**Alternative format (if the above doesn't work)**:
```
https://controller-team5.splunkylabs.com/events
```

**Steps**:
1. Filter for: `eum.es.host`
2. Update value (try first format, then alternative if needed)
3. Click **Save**

---

#### Setting: `appdynamics.on.premise.event.service.url`
**Description**: Alternative Events Service URL setting  
**Value to Set**:
```
https://controller-team5.splunkylabs.com/events
```

**Steps**:
1. Filter for: `appdynamics.on.premise.event.service.url`
2. Update value to the URL above
3. Click **Save**

---

### Step 5: Configure Mobile Screenshot Host

#### Setting: `eum.mobile.screenshot.host`
**Description**: Screenshot service for mobile monitoring  
**Value to Set** (⚠️ NO https:// prefix):
```
controller-team5.splunkylabs.com/screenshots
```

**Steps**:
1. Filter for: `eum.mobile.screenshot.host`
2. Update value to the hostname/path above (without https://)
3. Click **Save**

---

### Step 6: Verify Analytics Account Key

This key must match between Controller and EUM server.

#### Setting: `appdynamics.es.eum.key`
**Description**: Shared secret for EUM-Events Service communication  

**Action**: **DO NOT CHANGE** - Just verify it exists and has a value.

If you need to verify the EUM server's key matches:
```bash
ssh appduser@<vm-ip>
kubectl get secret -n cisco-eum eum-config -o jsonpath='{.data.analytics\.accountAccessKey}' | base64 -d
```

The values must match for EUM to send data to Events Service.

---

## ✅ Complete Configuration Summary

After completing all steps, your Controller Settings should have these values:

| Property Name | Value | Notes |
|--------------|-------|-------|
| `eum.beacon.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.beacon.https.host` | `controller-team5.splunkylabs.com/eumcollector` | ⚠️ NO https:// |
| `eum.cloud.host` | `https://controller-team5.splunkylabs.com/eumaggregator` | ✅ Include https:// |
| `eum.es.host` | `controller-team5.splunkylabs.com:443` | Use hostname:port |
| `appdynamics.on.premise.event.service.url` | `https://controller-team5.splunkylabs.com/events` | ✅ Include https:// |
| `eum.mobile.screenshot.host` | `controller-team5.splunkylabs.com/screenshots` | ⚠️ NO https:// |
| `appdynamics.es.eum.key` | *(existing value - don't change)* | Don't modify |

---

## 🔍 Verification Steps

### 1. Verify Controller Can Reach EUM

After saving all settings, test the connection:

```bash
# Test EUM collector endpoint
curl -k https://controller-team5.splunkylabs.com/eumcollector/health
curl -k https://controller-team5.splunkylabs.com/eumcollector/api/v1/status

# Test EUM aggregator endpoint
curl -k https://controller-team5.splunkylabs.com/eumaggregator/health
curl -k https://controller-team5.splunkylabs.com/eumaggregator/api/v1/status

# Test Events Service endpoint
curl -k https://controller-team5.splunkylabs.com/events/health
curl -k https://controller-team5.splunkylabs.com/events/api/v1/status
```

Expected: HTTP 200 responses or service-specific status messages.

---

### 2. Check Controller UI

1. Log in to Controller: `https://controller-team5.splunkylabs.com/controller/`
2. Navigate to **User Experience** → **Browser Apps**
3. Try to create a new Browser Application
4. Verify the JavaScript snippet generation works
5. Check that the beacon URLs in the generated snippet match your configured endpoints

---

### 3. Verify EUM Pod Logs

```bash
ssh appduser@<vm-ip>

# Check EUM pod is receiving configuration
kubectl logs -n cisco-eum eum-ss-0 --tail=100

# Look for:
# - No configuration errors
# - Successful connection to Events Service
# - Beacon endpoint initialization messages
```

---

### 4. Check Events Service Pod Logs

```bash
# Check Events Service is receiving data
kubectl logs -n cisco-events events-ss-0 --tail=100

# Look for:
# - Successful startup
# - No connection errors
# - Ready to receive analytics data
```

---

## 🐛 Troubleshooting

### Issue: Can't Access admin.jsp

**Solution**:
- Check root password (default: `welcome`)
- Note: admin.jsp doesn't ask for username - it automatically uses `root`
- Clear browser cache/try incognito mode
- Verify Controller is fully started: `ssh appduser@<vm-ip> && appdcli ping`

---

### Issue: Property Not Found in Controller Settings

**Solution**:
- Some properties may not exist in newer versions
- Check if the setting was consolidated into another property
- Verify you're on AppDynamics VA version 25.4.0.2016
- Contact AppDynamics support for version-specific settings

---

### Issue: EUM Still Shows "Failed" After Configuration

**Possible Causes**:

1. **Settings Not Applied Yet**
   - Wait 2-3 minutes for Controller to reload configuration
   - Restart Controller pod if needed:
     ```bash
     kubectl delete pod -n cisco-controller controller-0
     ```

2. **Ingress Routing Issue**
   - Verify ALB is routing to all three VMs:
     ```bash
     aws elbv2 describe-target-health --target-group-arn <tg-arn>
     ```
   - All targets should show `healthy` status

3. **DNS Resolution Issue**
   - Test DNS from within the cluster:
     ```bash
     kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
     nslookup controller-team5.splunkylabs.com
     curl -k https://controller-team5.splunkylabs.com/eumcollector/health
     exit
     ```

4. **Certificate Issue**
   - Check ingress certificate:
     ```bash
     kubectl get ingress -A
     kubectl describe ingress -n cisco-controller
     ```

---

### Issue: Beacon URLs Not Generated Correctly

**Solution**:
1. Double-check all `eum.beacon.*` settings in admin.jsp
2. Ensure no trailing slashes in URLs
3. Restart EUM pod to pick up new configuration:
   ```bash
   kubectl delete pod -n cisco-eum eum-ss-0
   ```
4. Wait 2-3 minutes for pod to fully restart
5. Create a new Browser App and check generated JavaScript

---

## 📚 Additional Resources

- **Common EUM Issues**: See `common_issues.md` sections:
  - "EUM JavaScript Agent Hosting Issues"
  - "Beacon Sending Failures"
  - "EUM Health is Failing After Multiple Retries"

- **AppDynamics Documentation**:
  - [Configure On-Premises EUM](https://docs.appdynamics.com/appd/24.x/latest/en/end-user-monitoring/browser-monitoring/configure-browser-monitoring)
  - [Events Service Configuration](https://docs.appdynamics.com/appd/24.x/latest/en/cisco-appdynamics-essentials/events-service)

- **Deployment Scripts**:
  - `deployment/fix-eum-config.sh` - Automated EUM configuration fixer
  - `scripts/check-status.sh` - Check overall deployment health

---

## 📝 Quick Reference Commands

```bash
# SSH to team5 VM1
ssh appduser@$(cat state/team5/vm1-public-ip.txt)

# Check EUM status
appdcli ping | grep -i eum

# Get all EUM pods
kubectl get pods -n cisco-eum -o wide

# Get all Events pods  
kubectl get pods -n cisco-events -o wide

# Check EUM logs
kubectl logs -n cisco-eum eum-ss-0 --tail=50 -f

# Check Events logs
kubectl logs -n cisco-events events-ss-0 --tail=50 -f

# Test EUM endpoint from VM
curl -k https://controller-team5.splunkylabs.com/eumcollector/health

# Test Events endpoint from VM
curl -k https://controller-team5.splunkylabs.com/events/health

# Restart EUM pod
kubectl delete pod -n cisco-eum eum-ss-0

# Restart Events pod
kubectl delete pod -n cisco-events events-ss-0

# Restart Controller pod (if settings not applied)
kubectl delete pod -n cisco-controller controller-0
```

---

## ⏱️ Estimated Time

- **Configuration**: 10-15 minutes
- **Verification**: 5-10 minutes
- **Troubleshooting** (if needed): 15-30 minutes
- **Total**: 30-55 minutes

---

## ✅ Success Criteria

- [ ] All Controller Settings properties configured with correct team5 URLs
- [ ] EUM collector endpoint responds to HTTP requests
- [ ] EUM aggregator endpoint responds to HTTP requests  
- [ ] Events Service endpoint responds to HTTP requests
- [ ] Can create Browser Application in Controller UI
- [ ] JavaScript snippet generates with correct beacon URLs
- [ ] `appdcli ping` shows EUM as "Success" (may take a few minutes)
- [ ] EUM pod logs show no errors
- [ ] Events pod logs show no errors

---

**Last Updated**: December 18, 2025  
**Maintainer**: bmstoner@cisco.com  
**Team 5 Resources**: `/Users/bmstoner/code_projects/dec25_lab/state/team5/`

