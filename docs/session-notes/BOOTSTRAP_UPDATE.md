# Bootstrap Script Update - Automatic Monitoring

## What Changed

Updated `deployment/04-bootstrap-vms.sh` to **automatically wait and monitor** bootstrap progress instead of just checking once and exiting.

## New Behavior

### Before (Old Behavior)
```bash
./deployment/04-bootstrap-vms.sh --team 5

# Output:
VM1 Status:
  Error: Socket not found...
VM2 Status:
  Error: Socket not found...
VM3 Status:
  Error: Socket not found...
✅ All VMs bootstrapped successfully!  # ❌ FALSE POSITIVE!

# Script exits immediately, bootstrap incomplete!
```

### After (New Behavior)
```bash
./deployment/04-bootstrap-vms.sh --team 5

# Initial check:
VM1 Status:
  Error: Socket not found...
VM2 Status:
  Error: Socket not found...
VM3 Status:
  Error: Socket not found...

⏱️  Bootstrap is still in progress!
The bootstrap process extracts multi-GB image files and typically takes 20-30 minutes.
Waiting for bootstrap to complete...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️  Checking progress (0m elapsed)...

  VM1: ⏳ Still extracting images...
       - infra-images (10:23)
       - aiops-images (7:12)
  VM2: ⏳ Still extracting images...
       - aiops-images (7:13)
  VM3: ⏳ Still extracting images...
       - infra-images (10:25)

Waiting 30s before next check (timeout in 45m)...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️  Checking progress (1m elapsed)...

  VM1: ⏳ Still extracting images...
  VM2: ⏳ Still extracting images...
  VM3: ⏳ Still extracting images...

# ... continues monitoring every 30 seconds ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️  Checking progress (23m elapsed)...

  VM1: ✅ Complete
  VM2: ✅ Complete
  VM3: ✅ Complete

🎉 All VMs have completed bootstrapping!

╔══════════════════════════════════════════════════════════╗
║  Final Bootstrap Verification                           ║
╚══════════════════════════════════════════════════════════╝

VM1 (52.42.90.99):
  Task                    State      StartTime      Duration
  ──────────────────────────────────────────────────────────
  Selinux                 Succeeded  14:11:05       00:00:00
  Hostname                Succeeded  14:11:05       00:00:01
  Network                 Succeeded  14:11:06       00:00:00
  Storage                 Succeeded  14:11:06       00:00:02
  Firewall                Succeeded  14:11:08       00:00:00
  SSH                     Succeeded  14:11:08       00:00:01
  K8s                     Succeeded  14:11:09       00:23:45

VM2 (52.42.90.100):
  [Similar output...]

VM3 (52.42.90.101):
  [Similar output...]

✅ All VMs bootstrapped successfully!

╔══════════════════════════════════════════════════════════╗
║  Bootstrap Complete!                                    ║
╚══════════════════════════════════════════════════════════╝

# Script returns to prompt ONLY when bootstrap is truly complete!
```

## Key Features

1. **Automatic Monitoring Loop**
   - Checks progress every 30 seconds
   - Shows elapsed time
   - Shows what's being extracted on each VM
   - Waits up to 45 minutes

2. **Real-Time Progress Updates**
   - Shows which images are being extracted
   - Shows how long extraction has been running
   - Updates status for each VM independently

3. **Timeout Protection**
   - Maximum wait time: 45 minutes
   - Shows time remaining before timeout
   - Exits with error if timeout reached

4. **Final Verification**
   - Shows full `appdctl show boot` output when complete
   - Verifies all tasks succeeded
   - Only shows success message when truly complete

## Testing

Currently, Team 5 VMs are still bootstrapping (started at 14:11 UTC, now ~18 minutes in).

To test the new monitoring behavior:

```bash
# Wait a few more minutes for bootstrap to complete, then:
./deployment/04-bootstrap-vms.sh --team 5

# It will detect bootstrap is in progress and wait automatically
```

Or manually check progress:

```bash
./scripts/check-bootstrap-progress.sh --team 5
```

## Current Team 5 Status (as of 09:28 EST)

- VMs launched: 14:09 UTC
- Bootstrap started: 14:11 UTC  
- Elapsed time: ~18 minutes
- Current activity: Extracting aiops-images (~7-8 minutes running)
- **Estimated completion: 5-10 more minutes**

## Benefits

✅ **Better UX**: Script doesn't exit prematurely with false success message
✅ **Automation-friendly**: Can be used in CI/CD pipelines
✅ **Clear feedback**: Users know exactly what's happening and how long to wait
✅ **Error detection**: Timeout alerts if something is wrong
✅ **Real progress**: Shows actual extraction progress, not just generic waiting

## Files Modified

1. `deployment/04-bootstrap-vms.sh` - Added monitoring loop
2. `scripts/check-bootstrap-progress.sh` - Enhanced standalone monitoring script
3. `docs/BOOTSTRAP_MONITORING.md` - Complete documentation

## Next Steps

Once the current Team 5 bootstrap completes, the next deployment will use the improved monitoring automatically!

