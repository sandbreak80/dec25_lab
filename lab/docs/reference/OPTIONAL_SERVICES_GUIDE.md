# Optional Services Installation Guide

## Overview

AppDynamics Virtual Appliance supports several optional services beyond the core platform. This guide covers which services are available, how to install them, and known issues.

---

## Available Optional Services (VA 25.4.0)

| Service | Command | Status | Duration | Purpose |
|---------|---------|--------|----------|---------|
| **AIOps** | `appdcli start aiops small` | ✅ Available | 10-15 min | Anomaly detection, RCA, AI insights |
| **ATD** | `appdcli start atd small` | ✅ Available | 5-10 min | Auto transaction diagnostics |
| **SecureApp** | `appdcli start secapp small` | ✅ Available | 10-15 min | Security monitoring |
| **OTIS** | ~~`appdcli start otis small`~~ | ❌ Not Available | N/A | OpenTelemetry (missing in this version) |
| **UIL** | ~~`appdcli start uil small`~~ | ❌ Not Available | N/A | Splunk integration (missing in this version) |

---

## Installation Methods

### Method 1: Automated Script (Recommended)

```bash
./install-optional-services.sh
```

**Installs:**
- AIOps
- ATD
- Attempts OTIS and UIL (will fail gracefully with documentation)

**Total time:** ~20 minutes

---

### Method 2: Manual Installation

#### Install AIOps (Anomaly Detection)

```bash
# SSH to VM1
ssh appduser@44.232.63.139

# Install AIOps
appdcli start aiops small

# Monitor progress
watch -n 10 'kubectl get pods -n cisco-aiops'

# Verify (wait until all pods Running)
appdcli ping | grep 'AD/RCA'
```

**Expected output when complete:**
```
| AD/RCA Services | Success |
```

**What gets installed:**
- 20 microservices
- Services: alarm-gen, alarm-service, ast-service, contextual-binning, graph-service, historical-anomaly, historical-trainer, metric-ingest, model-service, pi-metric-metadata-relay, pi-metric-relay, pi-routing-svc, rca-store-service, rca30-service, topology-apm, and more

**Resource impact:**
- CPU usage will spike to 60-80% during installation
- 20 pods consuming ~8-12GB RAM total
- Settles down after 15-20 minutes

---

#### Install ATD (Automatic Transaction Diagnostics)

**Prerequisites:**
- AuthN service installed (done automatically with core services)

**Verify AuthN:**
```bash
kubectl get pods -n authn | grep auth
# Should show: auth-mysql-0 and auth-service pods Running
```

**Install:**
```bash
# On VM1
appdcli start atd small

# Monitor
watch -n 10 'kubectl get pods -n cisco-atd'

# Verify
appdcli ping | grep 'ATD'
```

**Expected output when complete:**
```
| ATD | Success |
```

**What gets installed:**
- 2 pods: ds-sa-svc, snapshot-analyze
- Code-level diagnostics
- Transaction analysis

---

#### Install SecureApp (Security Monitoring)

```bash
# On VM1
appdcli start secapp small

# Monitor
watch -n 10 'kubectl get pods -n cisco-secureapp'

# Verify
appdcli ping | grep 'SecureApp'
```

**Expected output when complete:**
```
| SecureApp | Success |
```

---

## Known Issues

### OTIS (OpenTelemetry) - NOT AVAILABLE

**Documentation says:**
```bash
appdcli start otis small
```

**Actual result:**
```
appdcli start: error: argument subsubcommand: invalid choice: 'otis'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**Why:** OTIS is not available as an `appdcli` command in VA 25.4.0. The vendor documentation is incorrect or outdated.

**Alternatives:**
1. Check if your version of VA includes OTIS (may be different release)
2. Manual Helm chart installation (if charts are available)
3. Use different OpenTelemetry ingestion method
4. Contact AppDynamics support for OTIS availability

**Documented:** See VENDOR_DOC_ISSUES.md #30

---

### UIL (Universal Integration Layer) - NOT AVAILABLE

**Documentation says:**
```bash
appdcli start uil small
```

**Actual result:**
```
appdcli start: error: argument subsubcommand: invalid choice: 'uil'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**Why:** UIL is not available as an `appdcli` command in VA 25.4.0. The vendor documentation is incorrect or outdated.

**Alternatives for Splunk Integration:**
1. Check if your version of VA includes UIL (may be different release)
2. Manual Helm chart installation (if charts are available)
3. Use Splunk HTTP Event Collector (HEC) directly
4. Configure Controller to forward metrics via REST API
5. Contact AppDynamics support for UIL availability

**Documented:** See VENDOR_DOC_ISSUES.md #31

---

## Monitoring Installation

### Use the Monitoring Script

```bash
./monitor-optional-services.sh
```

**Shows:**
- Number of pods running vs. total
- Pods pending/starting
- Service status from `appdcli ping`
- Resource usage
- Updates every 30 seconds

**Press Ctrl+C to stop monitoring**

---

### Manual Monitoring Commands

```bash
# Check all optional service pods
kubectl get pods -n cisco-aiops
kubectl get pods -n cisco-atd
kubectl get pods -n cisco-secureapp

# Check service status
appdcli ping

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Watch specific namespace
watch -n 10 'kubectl get pods -n cisco-aiops'
```

---

## Verification Checklist

After installation, verify each service:

```bash
# Complete service status
appdcli ping
```

**Expected output (all optional services installed):**
```
+---------------------+---------+
|  Service Endpoint   | Status  |
+=====================+=========+
| Controller          | Success |
| Events              | Success |
| EUM Collector       | Success |
| EUM Aggregator      | Success |
| EUM Screenshot      | Success |
| Synthetic Shepherd  | Success |
| Synthetic Scheduler | Success |
| Synthetic Feeder    | Success |
| AD/RCA Services     | Success |  ← AIOps
| SecureApp           | Success |  ← If installed
| ATD                 | Success |  ← ATD
+---------------------+---------+
```

**All pods running:**
```bash
# Count running pods
kubectl get pods --all-namespaces | grep Running | wc -l
# Should be 50+ with all optional services
```

**Resource usage stabilized:**
```bash
kubectl top nodes
# CPU should drop below 30% after all pods initialized
```

---

## Troubleshooting

### Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n cisco-aiops
# Shows many pods in "Pending" state for >10 minutes
```

**Solutions:**
1. Check node resources:
   ```bash
   kubectl describe nodes
   # Look for resource pressure
   ```

2. Check PV availability:
   ```bash
   kubectl get pv
   kubectl get pvc --all-namespaces
   ```

3. Check for scheduling issues:
   ```bash
   kubectl describe pod <pod-name> -n cisco-aiops
   # Look at Events section
   ```

---

### Pods CrashLooping

**Symptoms:**
```bash
kubectl get pods -n cisco-aiops
# Shows CrashLoopBackOff
```

**Solutions:**
1. Check pod logs:
   ```bash
   kubectl logs <pod-name> -n cisco-aiops
   kubectl logs <pod-name> -n cisco-aiops --previous
   ```

2. Check dependencies:
   ```bash
   # Ensure MySQL, Kafka, Redis are healthy
   kubectl get pods -n mysql
   kubectl get pods -n kafka
   kubectl get pods -n redis
   ```

3. Restart the pod:
   ```bash
   kubectl delete pod <pod-name> -n cisco-aiops
   # Let Kubernetes recreate it
   ```

---

### Service Shows "Failed" After Installation

**Symptoms:**
```bash
appdcli ping
# Shows "Failed" for AD/RCA or ATD
```

**Solutions:**
1. Wait longer - some services take 15-20 minutes
2. Check if all pods are Running:
   ```bash
   kubectl get pods -n cisco-aiops
   kubectl get pods -n cisco-atd
   ```

3. Check pod health:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

4. Restart the service:
   ```bash
   appdcli stop aiops
   appdcli start aiops small
   ```

---

## Resource Requirements

### AIOps Resource Usage

**During Installation:**
- CPU: 60-80% cluster-wide spike
- Memory: +8-12GB
- Disk: +5GB
- Time: 10-15 minutes

**After Stabilization:**
- CPU: +10-15% baseline
- Memory: +6-8GB
- 20 pods running

### ATD Resource Usage

**During Installation:**
- CPU: Small spike (~5-10%)
- Memory: +2-3GB
- Disk: +2GB
- Time: 5-10 minutes

**After Stabilization:**
- CPU: +2-5% baseline
- Memory: +2GB
- 2 pods running

### Combined (Core + AIOps + ATD)

**Total cluster usage (steady state):**
- CPU: 20-30%
- Memory: 30-40%
- ~70 pods running
- Plenty of headroom on m5a.4xlarge x3

---

## Cost Impact

**Optional services add minimal cost** since you're already paying for the VMs:

- No additional AWS charges (same VMs)
- Increased EBS I/O (minimal cost)
- Additional ~10GB disk usage
- Higher CPU/Memory usage (but within VM capacity)

**Recommendation:** Install optional services you'll use. They don't increase your AWS bill significantly.

---

## Uninstalling Optional Services

### Remove AIOps

```bash
appdcli stop aiops
```

### Remove ATD

```bash
appdcli stop atd
```

### Remove SecureApp

```bash
appdcli stop secapp
```

**Note:** Stopping services removes pods but may leave some configuration. Full cleanup requires Helm uninstall of individual charts.

---

## Summary Table

| Service | Available? | Install Command | Pods | Time | CPU Impact | Memory Impact |
|---------|-----------|-----------------|------|------|------------|---------------|
| Core Services | ✅ | `appdcli start appd small` | ~50 | 20-30 min | 15% | 20GB |
| AIOps | ✅ | `appdcli start aiops small` | 20 | 10-15 min | +10% | +8GB |
| ATD | ✅ | `appdcli start atd small` | 2 | 5-10 min | +3% | +2GB |
| SecureApp | ✅ | `appdcli start secapp small` | ~10 | 10-15 min | +5% | +4GB |
| OTIS | ❌ | N/A | N/A | N/A | N/A | N/A |
| UIL | ❌ | N/A | N/A | N/A | N/A | N/A |

---

## References

- Main Lab Guide: `LAB_GUIDE.md`
- Vendor Issues: `VENDOR_DOC_ISSUES.md` (#30, #31)
- Installation Script: `install-optional-services.sh`
- Monitoring Script: `monitor-optional-services.sh`

---

**Last Updated:** December 3, 2025  
**VA Version:** 25.4.0  
**Status:** Tested and verified
