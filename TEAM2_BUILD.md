# Team 2 Build Commands - Quick Reference

## Complete Sequential Commands

```bash
# STEP 1: Deploy Infrastructure (~30 min)
./lab-deploy.sh --team 2

# STEP 2: Change Password (~1 min)
./appd-change-password.sh --team 2

# STEP 3: Setup SSH Keys (~1 min) - HIGHLY RECOMMENDED
./scripts/setup-ssh-keys.sh --team 2

# STEP 4: Bootstrap VMs (~5 min + 15-20 min wait)
./appd-bootstrap-vms.sh --team 2
# WAIT 15-20 MINUTES for image decompression!

# Verify bootstrap complete:
./scripts/ssh-vm1.sh --team 2
appdctl show boot  # All should show "Succeeded"
exit

# STEP 5: Create Cluster (~10 min)
./appd-create-cluster.sh --team 2

# STEP 6: Configure Cluster (~1 min)
./appd-configure.sh --team 2

# STEP 7: Install AppDynamics (~15 min)
./appd-install.sh --team 2

# STEP 8: Verify & Access (~1 min)
./appd-check-health.sh --team 2
open https://controller-team2.splunkylabs.com/controller/
# Username: admin / Password: welcome
```

## Total Time: ~80 minutes

## Cleanup

```bash
./lab-cleanup.sh --team 2 --confirm
```

## Quick SSH Access

```bash
# Helper scripts (passwordless with SSH keys)
./scripts/ssh-vm1.sh --team 2
./scripts/ssh-vm2.sh --team 2
./scripts/ssh-vm3.sh --team 2

# Or shortcuts
ssh appd-team2-vm1
ssh appd-team2-vm2
ssh appd-team2-vm3
```

## URLs

- Controller: https://controller-team2.splunkylabs.com/controller/
- Auth: https://customer1-team2.auth.splunkylabs.com/
- AuthN: https://customer1-tnt-authn-team2.splunkylabs.com/

## Common Commands (on VM)

```bash
# Cluster status
appdctl show cluster

# Bootstrap status
appdctl show boot

# AppDynamics services
appdcli status

# Kubernetes status
microk8s status
```
