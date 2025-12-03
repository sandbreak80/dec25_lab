# SSH Key Setup Guide

## Overview

This guide explains the SSH authentication strategy for the AppDynamics lab environment. We use a **hybrid approach** that supports both password-based and key-based SSH.

## Authentication Methods

### Default: Password-Based SSH

The AppDynamics Virtual Appliance VMs are deployed with password-based SSH enabled by default (vendor approach):

- **User:** `appduser`
- **Initial password:** `changeme` (must be changed on first login)
- **Team password:** `AppDynamics123!` (or custom, set by `appd-change-password.sh`)

### Recommended: SSH Key-Based Authentication

For a much better experience, students can setup SSH keys for passwordless access:

```bash
./scripts/setup-ssh-keys.sh --team 1
```

## Why Use SSH Keys?

**Without SSH keys**, students will need to enter passwords **30-50+ times** during the lab:

| Task | Password Prompts |
|------|------------------|
| Password change | 3 (1 per VM) |
| Bootstrap | 6+ (scp + ssh per VM) |
| Manual SSH | Every connection |
| Cluster creation | 5-10 |
| Install/verify | 10-20 |
| **TOTAL** | **30-50+** 😱 |

**With SSH keys**, all SSH operations are passwordless! 🎉

## How It Works

### 1. VMs Deployed with Password SSH

When VMs are created (`lab-deploy.sh`), they include cloud-init user-data:

```yaml
#cloud-config
ssh_pwauth: True
```

This enables password authentication for the `appduser` account.

### 2. Change Default Password (REQUIRED)

```bash
./appd-change-password.sh --team 1
```

This script uses `expect` to automate the forced password change from `changeme` to `AppDynamics123!`.

### 3. Setup SSH Keys (OPTIONAL but RECOMMENDED)

```bash
./scripts/setup-ssh-keys.sh --team 1
```

**What this does:**

1. Generates SSH key pair on student laptop:
   - Key type: `ed25519` (modern, secure)
   - Location: `~/.ssh/appd-team1-key`
   - No passphrase (for automation)

2. Copies public key to all 3 VMs:
   - Uses `ssh-copy-id` with password authentication
   - Installs key in `~/.ssh/authorized_keys` for `appduser`

3. Creates SSH config entries:
   - Adds shortcuts: `ssh appd-team1-vm1`, `ssh appd-team1-vm2`, etc.
   - Stores key path in `state/team1/ssh-key-path.txt`

4. Tests passwordless SSH access

### 4. All Scripts Auto-Detect Keys

All scripts that use SSH automatically detect if keys are configured:

```bash
KEY_PATH=$(cat "state/team${TEAM_NUMBER}/ssh-key-path.txt" 2>/dev/null || echo "")

if [[ -n "$KEY_PATH" ]] && [[ -f "$KEY_PATH" ]]; then
    # Use SSH key (passwordless)
    ssh -i "$KEY_PATH" appduser@${VM_IP}
else
    # Fall back to password
    ssh appduser@${VM_IP}  # Prompts for password
fi
```

**Scripts with smart detection:**
- `scripts/ssh-vm1.sh`, `ssh-vm2.sh`, `ssh-vm3.sh`
- `appd-bootstrap-vms.sh`
- All future automation scripts

## Student Workflow

### Option A: With SSH Keys (RECOMMENDED)

```bash
# 1. Deploy infrastructure
./lab-deploy.sh --team 1

# 2. Change password (REQUIRED)
./appd-change-password.sh --team 1

# 3. Setup SSH keys (1 minute, huge benefit!)
./scripts/setup-ssh-keys.sh --team 1

# 4. Bootstrap VMs (passwordless!)
./appd-bootstrap-vms.sh --team 1

# 5. SSH to VMs (passwordless!)
./scripts/ssh-vm1.sh --team 1  # No password needed!
```

### Option B: Without SSH Keys (Works but tedious)

```bash
# 1. Deploy infrastructure
./lab-deploy.sh --team 1

# 2. Change password (REQUIRED)
./appd-change-password.sh --team 1

# 3. Bootstrap VMs (enter password multiple times)
./appd-bootstrap-vms.sh --team 1
# ... prompted for password 6+ times ...

# 4. SSH to VMs (enter password each time)
./scripts/ssh-vm1.sh --team 1
# Password: AppDynamics123!
```

## Benefits

✅ **No typing password 30-50 times**  
✅ **Automation scripts run seamlessly**  
✅ **Better student experience**  
✅ **Still works without keys (graceful fallback)**  
✅ **Matches industry standard practice**  
✅ **Easy to setup (1 minute)**  

## Security

- SSH keys are **local to student laptop** (never committed to git)
- Keys are **unique per team** (`appd-team1-key`, `appd-team2-key`, etc.)
- Keys have **no passphrase** for automation (lab environment, short-lived)
- VMs have **security groups** restricting SSH to Cisco VPN IPs only
- Password authentication **still available** as fallback

## Troubleshooting

### "Permission denied (publickey)" Error

If you see this error when trying to use SSH keys:

```bash
# Re-run SSH key setup
./scripts/setup-ssh-keys.sh --team 1

# Verify key exists
ls -la ~/.ssh/appd-team1-key*

# Verify key is on VMs
ssh appduser@<VM-IP> "cat ~/.ssh/authorized_keys"
# (enter password when prompted)
```

### SSH Keys Not Working After Setup

```bash
# Check key path is saved
cat state/team1/ssh-key-path.txt

# Manually test SSH with key
ssh -i ~/.ssh/appd-team1-key appduser@<VM-IP>

# If that works but scripts don't, verify key path file exists
ls -la state/team1/ssh-key-path.txt
```

### Want to Remove SSH Keys

```bash
# Remove from VMs
ssh appduser@<VM1-IP> "rm ~/.ssh/authorized_keys"
ssh appduser@<VM2-IP> "rm ~/.ssh/authorized_keys"
ssh appduser@<VM3-IP> "rm ~/.ssh/authorized_keys"

# Remove from laptop
rm ~/.ssh/appd-team1-key*

# Remove state file
rm state/team1/ssh-key-path.txt

# Scripts will now fall back to password auth
```

## Technical Details

### SSH Key Generation Command

```bash
ssh-keygen -t ed25519 \
    -f ~/.ssh/appd-team1-key \
    -N "" \
    -C "appd-lab-team1"
```

- `-t ed25519`: Modern, secure key type
- `-f`: Key file path
- `-N ""`: No passphrase (for automation)
- `-C`: Comment (for identification)

### SSH Copy-ID with Expect

The `setup-ssh-keys.sh` script uses `expect` to automate `ssh-copy-id`:

```bash
expect << EOF
set timeout 30
spawn ssh-copy-id -i ~/.ssh/appd-team1-key.pub appduser@${VM_IP}
expect "password:" { send "AppDynamics123!\r" }
expect eof
EOF
```

This allows the script to run non-interactively while still using password authentication to install the key.

### SSH Config Entries

The script creates shortcuts in `~/.ssh/config`:

```
Host appd-team1-vm1
    HostName 44.252.44.29
    User appduser
    IdentityFile ~/.ssh/appd-team1-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Students can then simply run: `ssh appd-team1-vm1`

## Comparison to Vendor Approach

### Original Vendor Scripts (01-08)

The vendor's approach:
- Used password-based SSH only
- No SSH key setup
- Scripts assumed manual SSH with password entry
- Students had to manually run commands on each VM

### Our Improved Approach

Our approach:
- **Supports both** password and key-based SSH
- **Graceful fallback** if keys not setup
- **Automated key setup** script
- **Smart detection** in all scripts
- **Better student experience** while maintaining compatibility

## Summary

The SSH key setup script provides a **much better student experience** while maintaining **full backward compatibility** with password-based authentication. It's:

- ✅ **Optional** (password auth always works)
- ✅ **Recommended** (saves 30-50 password entries)
- ✅ **Easy** (1 minute to setup)
- ✅ **Automatic** (all scripts detect and use keys)
- ✅ **Standard practice** (mirrors real-world usage)

Students who skip SSH key setup will still have a working lab experience, just with more password prompts. Students who setup SSH keys will have a seamless, passwordless experience throughout the entire lab! 🎉
