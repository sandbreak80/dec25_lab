# SecureApp (Secure Application) - Installation & Management

## Overview

Cisco Secure Application (SecureApp) provides runtime security for your AppDynamics-monitored applications.

**Key Features:**
- Runtime threat detection
- Vulnerability scanning
- Compliance monitoring
- Security analytics
- Application protection

---

## Installation

### Option 1: Included in Full Installation (RECOMMENDED)

SecureApp is automatically installed when you run:

```bash
appdcli start all small
```

This is the **recommended approach** for the lab.

### Option 2: Standalone Installation

If you need to install SecureApp separately:

**For Students:**
```bash
./appd-install-secureapp.sh --team N
```

**For Reference Cluster:**
```bash
./install-secureapp-reference.sh
```

---

## Manual Installation Steps

If you prefer to install manually:

### Step 1: Verify Prerequisites

```bash
# SSH to VM1
ssh appduser@<vm1-ip>

# Verify Controller is running
appdcli ping
# Controller should show "Success"
```

### Step 2: (Optional) Apply License

If you have a license file:

```bash
# Copy license to VM1
scp license.lic appduser@<vm1-ip>:/var/appd/config/license.lic

# Apply license
appdcli license controller /var/appd/config/license.lic
```

**Note:** SecureApp can be installed without a license for evaluation.

### Step 3: Install SecureApp

```bash
# Install with small profile
appdcli start secapp small

# For medium deployments:
# appdcli start secapp medium
```

### Step 4: Verify Installation

```bash
# Check pods
kubectl get pods -n cisco-secureapp

# Expected pods:
# - agent-proxy
# - api-proxy  
# - alert-proxy
# - collector-server
# - postgres

# Check service status
appdcli ping | grep -i secure

# Should show: SecureApp | Success
```

---

## Pod Status

### Healthy State

All pods should be in `Running` state:

```
NAME                        READY   STATUS    RESTARTS   AGE
agent-proxy-xxx            1/1     Running   0          5m
api-proxy-xxx              1/1     Running   0          5m
alert-proxy-xxx            1/1     Running   0          5m
collector-server-xxx       2/2     Running   0          5m
postgres-0                 2/2     Running   0          5m
```

### Common Startup Issues

**Postgres pod initializing:**
- Status: `Init:0/1` or `PodInitializing`
- Wait: 2-3 minutes for database initialization
- This is normal during first startup

**Pod pending:**
- Check resources: `kubectl top nodes`
- SecureApp needs ~2GB additional memory
- May need to wait for other pods to stabilize

---

## Accessing SecureApp

### Via Controller UI

1. Log in to Controller: `https://controller-teamN.splunkylabs.com/controller/`
2. Navigate to **Applications**
3. Select your application
4. Click **Security** tab

### Via API

```bash
# Get SecureApp API endpoint
kubectl get svc -n cisco-secureapp

# Access API (from within cluster)
curl https://api-proxy.cisco-secureapp.svc.cluster.local/api/v1/health
```

---

## Configuration

### Security Policies

Configure security policies in Controller UI:
1. Applications → Your App → Security
2. Click "Policy" tab
3. Configure:
   - Threat detection rules
   - Vulnerability thresholds
   - Compliance requirements

### Agent Deployment

Deploy SecureApp agent with your application:

```bash
# Download agent
wget https://controller-teamN.splunkylabs.com/secureapp/agent/latest

# Install with your application
# See SecureApp agent documentation
```

---

## Verification

### Quick Health Check

```bash
# Check all pods are running
kubectl get pods -n cisco-secureapp

# Check service endpoint
appdcli ping | grep -i secure

# Check resource usage
kubectl top pods -n cisco-secureapp
```

### Detailed Health Check

```bash
# Check postgres database
kubectl exec postgres-0 -n cisco-secureapp -c postgres -- \
  psql -U postgres -c "SELECT version();"

# Check collector logs
kubectl logs -n cisco-secureapp -l app=collector-server --tail=50

# Check proxy health
kubectl exec -n cisco-secureapp deployment/api-proxy -- \
  curl -s localhost:8080/health
```

---

## Troubleshooting

### Issue: Pods not starting

**Symptoms:**
- Pods stuck in `Pending`
- Error: `Insufficient memory`

**Solution:**
```bash
# Check node resources
kubectl top nodes

# Check pod events
kubectl describe pod <pod-name> -n cisco-secureapp

# May need to reduce other services or increase VM size
```

### Issue: Postgres initialization failed

**Symptoms:**
- Postgres pod in `CrashLoopBackOff`
- Error in logs about database

**Solution:**
```bash
# Check logs
kubectl logs postgres-0 -n cisco-secureapp -c postgres

# Delete and recreate
kubectl delete pod postgres-0 -n cisco-secureapp

# Wait for automatic recreation
kubectl get pods -n cisco-secureapp -w
```

### Issue: Service shows "Failed" in appdcli ping

**Symptoms:**
- `appdcli ping` shows SecureApp as "Failed"
- But pods are running

**Solution:**
- Wait 5-10 minutes - service initialization takes time
- Check ingress: `kubectl get ingress -n cisco-secureapp`
- Verify DNS: `nslookup <secureapp-url>`

---

## Resource Requirements

### Small Profile

- **CPU:** ~1.5 cores
- **Memory:** ~2GB
- **Storage:** ~5GB

### Medium Profile

- **CPU:** ~3 cores
- **Memory:** ~4GB
- **Storage:** ~10GB

---

## Uninstallation

If you need to remove SecureApp:

```bash
# SSH to VM1
ssh appduser@<vm1-ip>

# Delete SecureApp namespace (CAUTION!)
kubectl delete namespace cisco-secureapp

# Verify deletion
kubectl get pods -n cisco-secureapp
# Should return: No resources found
```

**Note:** This is destructive and cannot be undone!

---

## Integration with Other Services

SecureApp integrates with:

- **Controller:** Application visibility
- **Events Service:** Security events
- **AIOps:** Security anomaly detection
- **ATD:** Transaction-level security

All integrations are automatic when installed via `appdcli start all`.

---

## Lab-Specific Notes

### For Students

- SecureApp is included in the main installation (`appdcli start all small`)
- No separate installation needed
- Access via Controller UI after installation

### For Instructors

- Reference cluster should have SecureApp for demo
- Use `./install-secureapp-reference.sh` if not already installed
- Can demonstrate security features to students

---

## Additional Resources

- **Official Docs:** https://docs.appdynamics.com/secureapp
- **Agent Documentation:** https://docs.appdynamics.com/secureapp/agents
- **Security Policies:** https://docs.appdynamics.com/secureapp/policies

---

## Summary

| Aspect | Details |
|--------|---------|
| **Installation** | `appdcli start secapp small` or included in `start all` |
| **Namespace** | `cisco-secureapp` |
| **Pods** | 5 (proxies, collector, postgres) |
| **Resources** | ~1.5 CPU, ~2GB RAM |
| **Access** | Controller UI → Applications → Security |
| **Time** | 10-15 minutes |

**Recommendation:** Use `appdcli start all small` which includes SecureApp automatically!
