# Teams 1 & 2 Deployment Status

**Date:** December 17, 2025  
**Status:** ✅ IN PROGRESS - Automated deployment running

## Summary

Both Team 1 and Team 2 lab environments are being deployed automatically. The infrastructure is complete and AppDynamics installation is in progress.

## Current Status

### ✅ Completed Steps

1. **Infrastructure Discovery** - Found existing VPCs, ALBs, DNS records from student attempts
2. **VM Cleanup** - Terminated inaccessible VMs that were created without SSH keys
3. **VM Creation** - Deployed 3 new VMs per team with proper SSH key authentication
4. **ALB Registration** - Registered all VMs with their respective load balancers
5. **Password Setup** - Changed appduser password to `AppDynamics123!`
6. **SSH Keys** - Configured passwordless SSH access for automation

### 🔄 In Progress

7. **Bootstrap VMs** (20-30 minutes) - Currently extracting container images
8. **Create K8s Cluster** (10 minutes) - Will start after bootstrap
9. **Configure AppDynamics** (1 minute) - Automated
10. **Install Services** (20-30 minutes) - Automated
11. **Apply License** (1 minute) - Automated

**Estimated Completion:** 45-60 minutes from start (around 12:30-12:45 PM)

## Team 1 Resources

| Resource | ID/Value |
|----------|----------|
| **VPC** | `vpc-0817c954ff135b6e0` (10.1.0.0/16) |
| **Subnet 1** | `subnet-0ac4a5f35a3a96cab` (us-west-2a) |
| **Subnet 2** | `subnet-0005207d5b7c2cc60` (us-west-2b) |
| **VM1** | `i-0318d35bad78c058e` @ 34.211.77.32 |
| **VM2** | `i-0c5fe3c635b45df85` @ 35.163.233.249 |
| **VM3** | `i-04454d8ed64f8cd21` @ 52.43.89.92 |
| **ALB** | `appd-team1-alb` (active) |
| **Target Group** | `appd-team1-tg` |
| **Controller URL** | https://controller-team1.splunkylabs.com/controller/ |
| **Auth URL** | https://customer1-team1.auth.splunkylabs.com/ |

### Team 1 Access

```bash
# SSH to VMs
ssh -i ~/.ssh/appd-team1-key appduser@34.211.77.32
ssh -i ~/.ssh/appd-team1-key appduser@35.163.233.249
ssh -i ~/.ssh/appd-team1-key appduser@52.43.89.92

# Or use helper scripts
./scripts/ssh-vm1.sh --team 1
./scripts/ssh-vm2.sh --team 1
./scripts/ssh-vm3.sh --team 1
```

## Team 2 Resources

| Resource | ID/Value |
|----------|----------|
| **VPC** | `vpc-06e3cea7a0a3334c5` (10.2.0.0/16) |
| **Subnet 1** | `subnet-03dc6a97e14203b7d` (us-west-2a) |
| **Subnet 2** | `subnet-04aae34f48414a9f5` (us-west-2b) |
| **VM1** | `i-002316a645f7ff324` @ 35.160.205.112 |
| **VM2** | `i-0fed1e48ab3f6e483` @ 44.240.218.96 |
| **VM3** | `i-08c957c06ccba8ac3` @ 52.13.174.231 |
| **ALB** | `appd-team2-alb` (active) |
| **Target Group** | `appd-team2-tg` |
| **Controller URL** | https://controller-team2.splunkylabs.com/controller/ |
| **Auth URL** | https://customer1-team2.auth.splunkylabs.com/ |

### Team 2 Access

```bash
# SSH to VMs
ssh -i ~/.ssh/appd-team2-key appduser@35.160.205.112
ssh -i ~/.ssh/appd-team2-key appduser@44.240.218.96
ssh -i ~/.ssh/appd-team2-key appduser@52.13.174.231

# Or use helper scripts
./scripts/ssh-vm1.sh --team 2
./scripts/ssh-vm2.sh --team 2
./scripts/ssh-vm3.sh --team 2
```

## Credentials

### VM Access
- **Username:** `appduser`
- **Password:** `AppDynamics123!`
- **SSH Keys:** `~/.ssh/appd-team1-key` and `~/.ssh/appd-team2-key`

### AppDynamics Controller
- **Username:** `admin`
- **Password:** `welcome`
- **Change password** after first login!

## Monitoring Deployment Progress

### Check Process Status
```bash
# View running processes
ps -p 11361 11520 -o pid,etime,command

# Team 1 Process: PID 11361
# Team 2 Process: PID 11520
```

### View Logs
```bash
# Team 1 deployment log
tail -f /tmp/team1-appd-deploy.log

# Team 2 deployment log
tail -f /tmp/team2-appd-deploy.log
```

### Use Monitor Script
```bash
# Run the monitoring script (updates every 60 seconds)
/tmp/monitor-deployment.sh
```

## Deployment Timeline

| Step | Duration | Status |
|------|----------|--------|
| Prerequisites Check | 1 min | ✅ Complete |
| Create VMs | 5 min | ✅ Complete |
| Change Passwords | 2 min | ✅ Complete |
| Setup SSH Keys | 2 min | ✅ Complete |
| **Bootstrap VMs** | **20-30 min** | **🔄 In Progress** |
| Create K8s Cluster | 10 min | ⏳ Pending |
| Configure AppDynamics | 1 min | ⏳ Pending |
| Install Services | 20-30 min | ⏳ Pending |
| Apply License | 1 min | ⏳ Pending |
| Verify Deployment | 2 min | ⏳ Pending |

**Total Time:** ~60-75 minutes

## What Happens Next

The deployment is fully automated. Once complete, you'll be able to:

1. **Access Controllers**
   - Team 1: https://controller-team1.splunkylabs.com/controller/
   - Team 2: https://controller-team2.splunkylabs.com/controller/

2. **Login** with `admin` / `welcome`

3. **Verify License** is applied

4. **Test Monitoring** with sample applications

## Troubleshooting

### If Deployment Fails

Check the logs for errors:
```bash
# View full logs
less /tmp/team1-appd-deploy.log
less /tmp/team2-appd-deploy.log

# Check for specific errors
grep -i error /tmp/team1-appd-deploy.log
grep -i error /tmp/team2-appd-deploy.log
```

### Manual Verification

SSH to VM1 and check status:
```bash
ssh -i ~/.ssh/appd-team1-key appduser@34.211.77.32

# Check bootstrap status
appdctl show boot

# Check cluster status
kubectl get nodes

# Check AppD services
kubectl get pods -n appdynamics
```

## State Files

All resource IDs are saved in:
- `state/team1/` - Team 1 resource IDs
- `state/team2/` - Team 2 resource IDs

These files enable the deployment scripts to resume if interrupted.

## Next Steps After Completion

1. **Verify Controllers**
   ```bash
   ./deployment/08-verify.sh --team 1
   ./deployment/08-verify.sh --team 2
   ```

2. **Test Access**
   - Open controller URLs in browser
   - Login with admin credentials
   - Verify all services are running

3. **Student Handoff**
   - Provide controller URLs
   - Share credentials
   - Point to lab guides in `docs/student/`

## Support

If you need to check status or troubleshoot:

```bash
# Quick status check
ps -p 11361 11520

# View recent progress
tail -20 /tmp/team1-appd-deploy.log
tail -20 /tmp/team2-appd-deploy.log

# SSH to VMs
./scripts/ssh-vm1.sh --team 1
./scripts/ssh-vm1.sh --team 2
```

---

**Deployment Started:** ~11:45 AM  
**Expected Completion:** ~12:30-12:45 PM  
**Automated Process:** Running in background (PIDs 11361, 11520)




