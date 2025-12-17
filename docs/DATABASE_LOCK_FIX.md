# MySQL Database Lock Issue - Fixed

## Problem
During AppDynamics installation, AIOps and SecureApp components would fail with:
```
Error: rpc error: code = Unknown desc = exec (try: 500): database is locked
```

## Root Cause
1. **MySQL InnoDB Cluster** takes 2-5 minutes to fully initialize after Helm install
2. **AppDynamics installation** (`appdcli start all`) continues immediately
3. **Subsequent components** (AIOps, ATD, SecureApp) try to write to database before it's ready
4. **Helm operations fail** due to locked database

## Solution Implemented

### 1. Added MySQL Readiness Check
**File**: `deployment/07-install.sh`

**New Step 3**: Wait for MySQL InnoDB Cluster to be Ready
- Checks MySQL pod status every 10 seconds
- Waits up to 5 minutes for all 3 MySQL pods to be running and ready
- Verifies Percona XtraDB Cluster (PXC) status is "ready"
- Provides helpful feedback during wait

**Code Location**: Lines 212-285 in `07-install.sh`

### 2. Added Database Lock Error Detection
**Enhancement**: Better error messages when database lock is detected

**What it does**:
- Detects "database is locked" errors in installation output
- Provides clear remediation steps:
  1. Delete MySQL release
  2. Wait for cleanup
  3. Re-run installation
- Shows manual verification commands

**Code Location**: Lines 204-221 in `07-install.sh`

## Expected Behavior After Fix

### During Installation
```
✅ Step 2: Starting AppDynamics installation...
   (20-30 minutes - installs base components including MySQL)

✅ Step 3: Waiting for MySQL InnoDB cluster to be ready...
   MySQL pods: 1/3 ready... (10s elapsed)
   MySQL pods: 2/3 ready... (20s elapsed)
   MySQL pods: 3/3 ready... (30s elapsed)
   ✅ MySQL cluster is ready (3/3 pods running)
   ✅ MySQL InnoDB cluster status: Ready

✅ Step 4: Waiting for services to start...
   (Checking every 60 seconds for up to 30 minutes)
```

### If MySQL Takes Too Long
```
⚠️  MySQL cluster did not become ready within 300s
⚠️  Installation will continue, but some services may fail
ℹ️  You can check MySQL status manually:
    ./scripts/ssh-vm1.sh --team X
    kubectl get pods -n mysql
```

## Testing Status
- ✅ Tested on Team 3 (successful MySQL recovery after manual delete)
- ⏳ Needs full validation on fresh Team deployment

## Manual Recovery (If Needed)
If you still encounter database lock errors:

```bash
# SSH to VM1
./scripts/ssh-vm1.sh --team X

# Delete MySQL release
helm delete mysql -n mysql

# Wait for cleanup
sleep 30

# Check pods are gone
kubectl get pods -n mysql  # Should show "No resources found"

# Exit VM
exit

# Re-run installation from your laptop
./deployment/07-install.sh --team X
```

## Next Steps
1. Test full deployment on fresh team
2. Update documentation
3. Commit changes to GitHub

