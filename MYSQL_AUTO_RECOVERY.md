# MySQL Auto-Recovery Solution

## Problem Statement

**Issue**: MySQL service fails to start properly 80% of the time during AppDynamics Virtual Appliance deployments, particularly after cluster creation.

**Reference**: `common_issues.md` - "Restore the MySQL Service"

**Symptoms**:
- Cluster creation appears to complete but MySQL pods don't auto-start
- `appdcli run infra_inspect` shows MySQL pods not running or not ready (0/2, 1/2)
- MySQL router pods missing or not running
- AppDynamics installation fails due to database unavailability

## Solution Overview

We've created an automated MySQL recovery system with two components:

### 1. MySQL Health Check Script
**Location**: `scripts/check-mysql-health.sh`

Monitors and auto-recovers MySQL service.

**Features**:
- Detects MySQL cluster health issues
- Automatically runs `appdcli run mysql_restore` if needed
- Configurable retry attempts and wait times
- Returns different exit codes for different scenarios

**Usage**:
```bash
# Check health only
./scripts/check-mysql-health.sh --team 1

# Check and auto-fix
./scripts/check-mysql-health.sh --team 1 --fix

# Check with custom retries
./scripts/check-mysql-health.sh --team 1 --fix --max-retries 5 --wait-time 90
```

**Exit Codes**:
- `0` = MySQL healthy (no action needed)
- `1` = MySQL unhealthy (not fixed)
- `2` = MySQL was unhealthy but successfully restored

### 2. Enhanced Deployment Script
**Location**: `deployment/deploy-with-mysql-recovery.sh`

Wraps the entire deployment process with MySQL health checking.

**Features**:
- Runs deployment steps in sequence
- Automatically checks MySQL health after cluster creation (where it fails 80% of the time)
- Retries cluster creation if MySQL fails
- Verifies MySQL before AppDynamics installation
- Final health check before completion

**Usage**:
```bash
# Deploy with automatic MySQL recovery
./deployment/deploy-with-mysql-recovery.sh --team 1

# Deploy with more aggressive recovery
./deployment/deploy-with-mysql-recovery.sh --team 1 --mysql-retries 5
```

## How It Works

### Detection Logic

The health check script connects to VM1 and runs:
```bash
appdcli run infra_inspect
```

Then verifies:
- ✅ 3 MySQL pods (appd-mysql-0, appd-mysql-1, appd-mysql-2) with status `2/2 Running`
- ✅ 3 MySQL router pods with status `1/1 Running`

**Unhealthy indicators**:
- MySQL pods showing `0/2` or `1/2` (not fully ready)
- Missing MySQL router pods
- Pods in `CrashLoopBackOff` or `Pending` state

### Recovery Process

When MySQL is detected as unhealthy:

1. **Run mysql_restore command**:
   ```bash
   appdcli run mysql_restore
   ```

2. **Wait for stabilization** (60 seconds default)

3. **Verify health** again

4. **Retry if needed** (up to 3 times by default)

### Integration Points

The deployment script checks MySQL at critical points:

1. **After Cluster Creation** ← Most common failure point (80%)
   - If unhealthy: Auto-restore and retry
   - If still fails: Retry entire cluster creation

2. **Before AppDynamics Installation**
   - Ensures MySQL is healthy before proceeding
   - Prevents installation failures

3. **Final Verification**
   - Confirms everything is stable before completion

## Deployment Flow Comparison

### Standard Deployment (No Recovery)
```
01-deploy.sh
02-change-password.sh
03-setup-ssh-keys.sh
04-bootstrap-vms.sh
05-create-cluster.sh          ← 80% chance MySQL fails here
06-configure.sh               ← May fail due to MySQL
07-install.sh                 ← Will fail if MySQL down
```

**Result**: Manual intervention required 80% of the time

### Enhanced Deployment (With Recovery)
```
01-deploy.sh
02-change-password.sh
03-setup-ssh-keys.sh
04-bootstrap-vms.sh
05-create-cluster.sh
  ↓
  MySQL Health Check          ← Automatic detection
  ↓ (if unhealthy)
  MySQL Restore (auto)        ← Automatic fix
  ↓ (verify)
  Retry if needed             ← Automatic retry
  ↓
06-configure.sh               ← Only runs when MySQL healthy
07-install.sh                 ← Guaranteed MySQL availability
```

**Result**: Automatic recovery, minimal manual intervention

## Usage Examples

### For Team 1 Deployment

**Option 1: Use enhanced deployment (recommended)**
```bash
cd /Users/bmstoner/code_projects/dec25_lab
./deployment/deploy-with-mysql-recovery.sh --team 1
```

**Option 2: Manual with health checks**
```bash
# Run deployment steps
./deployment/01-deploy.sh --team 1
./deployment/02-change-password.sh --team 1
./deployment/03-setup-ssh-keys.sh --team 1
./deployment/04-bootstrap-vms.sh --team 1
# Wait 15 minutes
./deployment/05-create-cluster.sh --team 1

# Check and fix MySQL
./scripts/check-mysql-health.sh --team 1 --fix

# Continue if healthy
./deployment/06-configure.sh --team 1
./deployment/07-install.sh --team 1
```

### For Existing Deployments

If you have an existing deployment with MySQL issues:

```bash
# Check current health
./scripts/check-mysql-health.sh --team 1

# Auto-fix if unhealthy
./scripts/check-mysql-health.sh --team 1 --fix --max-retries 5
```

## Expected Output

### Healthy MySQL
```
╔══════════════════════════════════════════════════════════╗
║   MySQL Health Check & Auto-Recovery                    ║
╚══════════════════════════════════════════════════════════╝

ℹ️  Checking MySQL health for Team 1...
ℹ️  Running infrastructure inspection...

ℹ️  MySQL Cluster Status:
  Total MySQL pods found: 6
  MySQL pods running: 6
  MySQL pods ready (2/2): 3
  MySQL router pods running: 3

✅ MySQL cluster is healthy!
✅ MySQL health check passed
```

### Unhealthy MySQL (Auto-Fixed)
```
ℹ️  Checking MySQL health for Team 1...

⚠️  MySQL cluster is unhealthy or not fully started

Detailed Status:
  appd-mysql-0      1/2  Running
  appd-mysql-1      1/2  Running
  appd-mysql-2      0/2  Pending
  appd-mysql-router-xxx  0/1  Pending

⚠️  MySQL is unhealthy. Attempting automatic recovery...

ℹ️  Recovery attempt 1 of 3...
ℹ️  Attempting MySQL restore...
✅ MySQL restore command completed
ℹ️  Waiting 60 seconds for MySQL to stabilize...
ℹ️  Verifying MySQL health after restore...

✅ MySQL cluster is healthy!
✅ MySQL successfully restored and verified!
✅ Cluster is now healthy
```

## Configuration Options

### check-mysql-health.sh Options

| Option | Default | Description |
|--------|---------|-------------|
| `--max-retries` | 3 | Number of restore attempts |
| `--wait-time` | 60 | Seconds to wait between attempts |
| `--fix` | false | Attempt automatic recovery |

### deploy-with-mysql-recovery.sh Options

| Option | Default | Description |
|--------|---------|-------------|
| `--mysql-retries` | 3 | MySQL recovery attempts |
| `--skip-mysql-check` | false | Disable MySQL checking |

## Troubleshooting

### If Auto-Recovery Fails

Manual recovery steps:
```bash
# SSH to VM1
ssh appduser@<vm1-ip>  # Password: AppDynamics123!

# Restore MySQL
appdcli run mysql_restore

# Wait 2-3 minutes
sleep 180

# Verify
appdcli run infra_inspect
```

Expected healthy output:
```
NAME                              READY   STATUS    RESTARTS   AGE
appd-mysql-0                      2/2     Running   0          5m
appd-mysql-1                      2/2     Running   0          5m
appd-mysql-2                      2/2     Running   0          5m
appd-mysql-router-xxx             1/1     Running   0          5m
appd-mysql-router-yyy             1/1     Running   0          5m
appd-mysql-router-zzz             1/1     Running   0          5m
```

### Common Issues

**Issue**: "Failed to connect to VM1"
- **Solution**: Verify VM is running and accessible
- Check: `./scripts/check-deployment-state.sh`

**Issue**: "MySQL restore command failed"
- **Solution**: Check VM logs
- Command: `ssh appduser@<vm-ip> "journalctl -u appd-os -n 100"`

**Issue**: "MySQL unhealthy after multiple retries"
- **Solution**: May indicate deeper issues
- Check disk space: `df -h`
- Check memory: `free -h`
- Review pod logs: `kubectl logs -n cisco-mysql <pod-name>`

## Benefits

1. **Reduced Manual Intervention**: Handles 80% failure rate automatically
2. **Faster Deployments**: No waiting for manual MySQL restores
3. **Reliable Builds**: Consistent MySQL health before proceeding
4. **Better Logging**: Detailed health status and recovery attempts
5. **Configurable**: Adjust retry logic per environment

## Integration with Existing Scripts

The solution integrates seamlessly with existing deployment scripts:

**For standard deployment** - Use as-is:
```bash
./deployment/full-deploy.sh --team 1
```

**For enhanced deployment** - Use new wrapper:
```bash
./deployment/deploy-with-mysql-recovery.sh --team 1
```

**For troubleshooting** - Use health check:
```bash
./scripts/check-mysql-health.sh --team 1 --fix
```

## Future Enhancements

Potential improvements:
- Pre-deployment MySQL health check
- MySQL performance monitoring
- Automatic log collection on failures
- Integration with monitoring/alerting
- Predictive failure detection

## References

- **Source Issue**: `common_issues.md` - "Restore the MySQL Service"
- **MySQL Restore Command**: `appdcli run mysql_restore`
- **Health Check Command**: `appdcli run infra_inspect`
- **Scripts**: 
  - `scripts/check-mysql-health.sh`
  - `deployment/deploy-with-mysql-recovery.sh`

---

**Status**: Ready for Team 1 deployment with automatic MySQL recovery

---
Created: December 18, 2025

