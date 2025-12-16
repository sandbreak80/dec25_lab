# Bootstrap Monitoring Guide

## Overview

The AppDynamics Virtual Appliance bootstrap process extracts multi-GB container images and typically takes **20-30 minutes** to complete. The bootstrap script now includes automatic monitoring to wait for completion.

## How It Works

### Automatic Monitoring (Default Behavior)

When you run the bootstrap script, it will:

```bash
./deployment/04-bootstrap-vms.sh --team 5
```

1. ✅ Execute `appdctl host init` on all 3 VMs
2. ✅ Configure SSH keys for VM-to-VM communication
3. ⏳ **Monitor bootstrap progress automatically**
4. 📊 Check every 30 seconds and show status updates
5. ⏱️  Wait up to 45 minutes for completion
6. ✅ Return to prompt only when all VMs are fully bootstrapped

### Sample Output During Monitoring

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️  Checking progress (5m elapsed)...

  VM1: ⏳ Still extracting images...
       - infra-images (8:23)
       - aiops-images (5:12)
  VM2: ⏳ Still extracting images...
       - infra-images (8:24)
       - aiops-images (5:13)
  VM3: ⏳ Still extracting images...
       - infra-images (8:25)
       - aiops-images (5:14)

Waiting 30s before next check (timeout in 40m)...
```

### When Complete

```
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

VM2 (52.42.90.100): ...
VM3 (52.42.90.101): ...

✅ All VMs bootstrapped successfully!

╔══════════════════════════════════════════════════════════╗
║  Bootstrap Complete!                                    ║
╚══════════════════════════════════════════════════════════╝
```

## Manual Monitoring (Optional)

If you want to check status separately or monitor an existing bootstrap:

### One-Time Check

```bash
./scripts/check-bootstrap-progress.sh --team 5
```

### Continuous Monitoring (Auto-Refresh)

```bash
./scripts/check-bootstrap-progress.sh --team 5 --watch
```

This will refresh every 30 seconds until complete.

## Bootstrap Process Stages

The bootstrap runs these tasks in sequence:

1. **Selinux** (~1 second) - Disable SELinux
2. **Hostname** (~1 second) - Configure hostname
3. **Network** (~1 second) - Configure network settings
4. **Storage** (~2 seconds) - Initialize storage
5. **Firewall** (~1 second) - Configure firewall rules
6. **SSH** (~1 second) - Configure SSH access
7. **K8s** (~20-30 minutes) - Extract container images and setup MicroK8s
   - Extracts `infra-images-25.4.0-932.txz` (multi-GB)
   - Extracts `aiops-images-25.4.0-125.txz` (multi-GB)
   - Imports images into containerd
   - Initializes MicroK8s cluster

## Timeouts

- **Per-VM bootstrap execution**: No timeout (completes when done)
- **Monitoring loop**: 45 minutes maximum
- **SSH connection timeout**: 10 seconds per check

If the 45-minute timeout is reached, the script will exit with an error and provide instructions for manual checking.

## Troubleshooting

### Bootstrap Seems Stuck

Check if the extraction processes are running:

```bash
# SSH to a VM
ssh -i ~/.ssh/appd-team5-key appduser@<VM_IP>

# Check for extraction processes
sudo ps aux | grep unxz

# Check service status
sudo systemctl status appd-os

# Check service logs
sudo journalctl -u appd-os -f
```

### Manual Bootstrap Verification

```bash
# SSH to a VM
ssh -i ~/.ssh/appd-team5-key appduser@<VM_IP>

# Check bootstrap status
appdctl show boot

# Expected output when complete:
# All tasks show "Succeeded" status
```

### Socket Not Found Error

If you see "Socket /var/run/appd-os.sock not found", this means:
- ✅ The bootstrap process is running
- ⏳ Image extraction is still in progress
- ⏱️  Wait 10-20 more minutes

This is **normal** during the first 20-30 minutes after VM launch.

## Integration with Complete Build

The complete build script (`deployment/complete-build.sh`) automatically includes this monitoring, so when you run a full deployment, it will wait for bootstrap to complete before proceeding.

## Performance Notes

- **Parallel extraction**: Each VM extracts images independently
- **CPU usage**: High CPU usage (30-45%) during extraction is normal
- **Memory usage**: Up to 40GB RAM used during bootstrap
- **Disk I/O**: Heavy disk I/O during extraction
- **Network**: No network traffic (all images are pre-loaded in the AMI)

## Exit Codes

- `0` - Bootstrap completed successfully on all VMs
- `1` - Bootstrap incomplete, timed out, or failed

## Next Steps After Bootstrap

Once bootstrap is complete, you can proceed with cluster initialization:

```bash
./deployment/05-create-cluster.sh --team 5
```

