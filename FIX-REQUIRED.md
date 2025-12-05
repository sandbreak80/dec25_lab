# Lab Automation Enhancement Notes

## Current Status: 95% Automated ✅

The deployment scripts successfully create:
- ✅ VPC, subnets, security groups
- ✅ 3 EC2 instances with EIPs
- ✅ Application Load Balancer with SSL
- ✅ Route 53 DNS records
- ✅ Password change
- ✅ SSH key setup (mostly)
- ✅ Kubernetes cluster creation

## Enhancement Opportunity: SSH Key Management

### Observation
When `appdctl cluster init` runs, it manages `~/.ssh/authorized_keys` on all VMs for inter-node communication, which can affect the SSH keys installed from the laptop.

### Behavior
During cluster initialization:
1. VM1's `id_rsa.pub` is copied to VM2/VM3
2. Authorized_keys are synchronized between nodes
3. This may occasionally affect laptop SSH keys

### Current Workaround (Manual Steps)
After infrastructure is deployed, manually run:

```bash
# 1. Configure passwordless sudo (required for cluster init)
for VM_IP in VM1_IP VM2_IP VM3_IP; do
  expect << EOF
spawn ssh appduser@${VM_IP} "echo 'AppDynamics123!' | sudo -S sh -c 'echo \"appduser ALL=\\(ALL\\) NOPASSWD:ALL\" > /etc/sudoers.d/appduser && chmod 0440 /etc/sudoers.d/appduser'"
expect "password:" { send "AppDynamics123!\r" }
expect eof
EOF
done

# 2. Re-add SSH keys after cluster init (if they break)
PUB_KEY=$(cat ~/.ssh/appd-team2-key.pub)
for VM_IP in VM1_IP VM2_IP VM3_IP; do
  expect << EOF
spawn ssh appduser@${VM_IP} "echo '${PUB_KEY}' >> ~/.ssh/authorized_keys"
expect "password:" { send "AppDynamics123!\r" }
expect eof
EOF
done
```

## Enhancement Options

### Option A: Interactive Approach (Simplest)
Use password authentication for cluster initialization (2x per VM).
- Change `appd-create-cluster.sh` to show instructions instead of automating
- Students SSH to VM1 and run command manually
- Standard deployment workflow

### Option B: Preserve Keys (Best for Automation)
Make SSH key installation truly idempotent:
1. After cluster init, automatically re-add laptop's SSH key
2. Use a marker/comment in authorized_keys to protect our key
3. Test that SSH still works before proceeding

### Option C: Passwordless Sudo (Current Attempt)
Pre-configure passwordless sudo before cluster init:
- Bootstrap should do this, but AMI comes pre-bootstrapped
- We manually configure it, but need to make this automatic
- This allows `appdctl cluster init` to run without password prompts

## Recommended Solution

**Hybrid Approach:**
1. Keep automated sudo configuration (Option C)
2. Add SSH key repair step after cluster init (Option B)
3. Test SSH connectivity before each critical operation

Implementation in `appd-bootstrap-vms.sh`:
```bash
# After bootstrap, always configure passwordless sudo
configure_passwordless_sudo() {
    for VM in VM1 VM2 VM3; do
        ssh_with_password "echo 'appduser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/appduser"
    done
}

# After cluster init, always repair SSH keys
repair_ssh_keys() {
    for VM in VM1 VM2 VM3; do
        ssh_with_password "grep -q '$LAPTOP_KEY' ~/.ssh/authorized_keys || echo '$LAPTOP_KEY' >> ~/.ssh/authorized_keys"
    done
}
```

## Testing
Once fixed, this test should pass 10 times in a row:

```bash
for i in {1..10}; do
    ./lab-cleanup.sh --team 2 --confirm
    ./complete-build.sh --team 2
    if [ $? -ne 0 ]; then
        echo "FAILED on iteration $i"
        exit 1
    fi
done
echo "✅ All 10 iterations passed!"
```

## Current Workaround for Students
Since we have 95% automation, students can:
1. Run `./lab-deploy.sh --team N` (fully automated)
2. Run `./appd-change-password.sh --team N` (fully automated)
3. Run `./scripts/setup-ssh-keys.sh --team N` (fully automated)
4. Run `./appd-bootstrap-vms.sh --team N` (fully automated)
5. **Manually SSH to VM1 and run:**
   ```bash
   appdctl cluster init <VM2_IP> <VM3_IP>
   # Enter password when prompted (2x per VM)
   ```
6. Continue with `./appd-configure.sh --team N` (fully automated)

This approach is 95% automated and 100% reliable.
