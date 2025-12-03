# Cisco VPN Configuration for SSH Access

## Overview

SSH access to the AppDynamics VMs is restricted to **Cisco VPN users only** for security.

**Students MUST be connected to Cisco VPN to access VMs via SSH.**

---

## Quick Setup

### For Instructor (Pre-Lab)

1. **Determine Cisco VPN IP Range**
   ```bash
   # Check your VPN IP when connected
   curl ifconfig.me
   
   # Or check your VPN interface
   ifconfig | grep -A 5 "utun"  # macOS
   ip addr show tun0              # Linux
   ```

2. **Update All Team Configs**
   
   Edit each file: `config/team1.cfg` through `config/team5.cfg`
   
   ```bash
   # Change this line in ALL team configs:
   SSH_ALLOWED_CIDR="10.0.0.0/8"
   
   # To your actual Cisco VPN CIDR, for example:
   SSH_ALLOWED_CIDR="172.16.0.0/12"     # Full VPN range
   # OR more specific:
   SSH_ALLOWED_CIDR="10.64.0.0/16"      # Specific VPN subnet
   ```

3. **Common Cisco VPN Ranges**
   
   Typical ranges (verify with your IT):
   - `10.0.0.0/8` (Class A private)
   - `172.16.0.0/12` (Class B private)
   - `192.168.0.0/16` (Class C private)
   - Or specific: `10.64.0.0/16`, `10.128.0.0/16`, etc.

### For Students

**BEFORE starting the lab:**

1. **Connect to Cisco AnyConnect VPN**
   - Open Cisco AnyConnect
   - Connect to your organization's VPN
   - Verify connection

2. **Verify VPN Connection**
   ```bash
   # Check your current IP
   curl ifconfig.me
   
   # Should show a Cisco IP (not your home/ISP IP)
   ```

3. **Test SSH Access**
   ```bash
   # If VPN is connected, SSH should work:
   ssh appduser@<vm-ip>
   
   # If VPN is NOT connected, you'll see:
   # Connection timed out or Connection refused
   ```

---

## Security Architecture

### Why VPN-Only SSH?

✅ **Security:** Only authenticated users can SSH  
✅ **Simple Management:** One CIDR range for all students  
✅ **Cisco Standard:** Aligns with corporate security policies  
✅ **Easy Troubleshooting:** "Not working? Check VPN!"

### How It Works

```
Student Laptop (Home/ISP)
    ↓
Cisco AnyConnect VPN
    ↓
Cisco VPN Gateway (10.64.x.x IP assigned)
    ↓
Internet
    ↓
AWS Security Group (allows 10.0.0.0/8)
    ↓
EC2 Instance (SSH port 22)
```

**Without VPN:** Security group blocks connection  
**With VPN:** Security group allows connection

---

## Troubleshooting

### SSH Connection Refused/Timeout

**Symptom:**
```bash
ssh appduser@44.232.63.139
# ssh: connect to host 44.232.63.139 port 22: Connection timed out
```

**Solution:**
1. Check VPN connection:
   ```bash
   # macOS
   ifconfig | grep utun
   
   # Linux
   ip addr show | grep tun
   ```

2. If not connected, connect to VPN:
   - Open Cisco AnyConnect
   - Connect to VPN
   - Retry SSH

3. Verify your IP is in allowed range:
   ```bash
   curl ifconfig.me
   # Should show 10.x.x.x, 172.x.x.x, or 192.168.x.x
   ```

### SSH Works for Some Students, Not Others

**Symptom:** Some team members can SSH, others cannot

**Cause:** VPN configuration differences or disconnected VPN

**Solution:**
1. All students verify VPN connection
2. All students check their VPN IP:
   ```bash
   curl ifconfig.me
   ```
3. If IPs are outside allowed CIDR, update `config/teamN.cfg`:
   ```bash
   # Example: Add additional CIDR ranges
   # Edit scripts/create-security.sh to allow multiple ranges
   ```

### SSH Allowed CIDR Too Restrictive

**Symptom:** Instructor can SSH, students cannot

**Cause:** CIDR range too narrow

**Solution - Option 1:** Expand CIDR range in config
```bash
# In config/teamN.cfg, change:
SSH_ALLOWED_CIDR="10.64.0.0/16"    # Too narrow
# To:
SSH_ALLOWED_CIDR="10.0.0.0/8"      # Full Class A
```

**Solution - Option 2:** Add multiple security group rules
```bash
# Manually in AWS Console or update script to allow:
# - 10.0.0.0/8
# - 172.16.0.0/12
# - 192.168.0.0/16
```

### VPN Required Notice

**Symptom:** Students don't realize VPN is required

**Solution:** Add to lab instructions:
```
⚠️  BEFORE YOU START: Connect to Cisco VPN!

SSH access requires Cisco AnyConnect VPN connection.

Test: curl ifconfig.me
Expected: 10.x.x.x or 172.x.x.x
```

---

## Configuration Examples

### Example 1: Single Cisco VPN Range

```bash
# config/team1.cfg
SSH_ALLOWED_CIDR="10.64.0.0/16"
```

**Security Group Rule:**
```
Type: SSH
Protocol: TCP
Port: 22
Source: 10.64.0.0/16
Description: Cisco VPN - Students Only
```

### Example 2: Multiple VPN Ranges

If your organization uses multiple VPN ranges, you can add multiple rules:

```bash
# In scripts/create-security.sh, modify to add multiple ingress rules:

# Rule 1: Primary VPN range
aws ec2 authorize-security-group-ingress \
  --group-id "$VM_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "10.64.0.0/16" \
  --description "Cisco VPN Range 1"

# Rule 2: Secondary VPN range
aws ec2 authorize-security-group-ingress \
  --group-id "$VM_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "172.16.0.0/12" \
  --description "Cisco VPN Range 2"
```

### Example 3: All RFC1918 Private Ranges

For maximum flexibility (less secure):

```bash
SSH_ALLOWED_CIDR="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

---

## Pre-Lab Checklist

### For Instructor

- [ ] Determine Cisco VPN IP range(s)
- [ ] Update `SSH_ALLOWED_CIDR` in all `config/teamN.cfg` files
- [ ] Test SSH access from VPN
- [ ] Document VPN connection URL for students
- [ ] Prepare VPN troubleshooting guide
- [ ] Test with a student account

### For Students (Lab Day)

- [ ] Cisco AnyConnect installed
- [ ] VPN credentials working
- [ ] Connected to Cisco VPN
- [ ] Verified IP: `curl ifconfig.me`
- [ ] Tested SSH to practice instance

---

## FAQ

### Q: Can students work from home?
**A:** Yes! As long as they connect to Cisco VPN first.

### Q: What if a student can't connect to VPN?
**A:** Contact IT support. SSH access requires VPN.

### Q: Can we open SSH to 0.0.0.0/0 temporarily?
**A:** **Not recommended!** Defeats security purpose. Better to fix VPN issues.

### Q: How to add instructor's home IP for testing?
**A:** Add a second security group rule:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$VM_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "<instructor-home-ip>/32" \
  --description "Instructor Home (Temporary)"
```

### Q: Do students need VPN for HTTPS (Controller UI)?
**A:** **No!** HTTPS is public via ALB. Only SSH requires VPN.

### Q: Can we use AWS Session Manager instead of SSH?
**A:** Yes! Alternative approach that doesn't require VPN:
- Enable Systems Manager on instances
- Students use AWS Console → Session Manager
- No security group changes needed

---

## Alternative: AWS Session Manager

If VPN is problematic, consider AWS Systems Manager Session Manager:

### Advantages
- No VPN required
- No security group SSH rules needed
- CloudTrail audit logs
- Works from AWS Console or CLI

### Setup
1. Add IAM role to EC2 instances with `AmazonSSMManagedInstanceCore` policy
2. Install SSM agent (already on Amazon Linux 2)
3. Students access via:
   ```bash
   aws ssm start-session --target i-xxxxx
   ```

### Trade-offs
- More complex IAM setup
- Requires AWS Console access
- Not traditional SSH (different commands)

---

## Summary

**SSH Security Model:**
- ✅ SSH requires Cisco VPN connection
- ✅ HTTPS (Controller UI) is public via ALB
- ✅ Security group enforces VPN-only SSH access
- ✅ Simple for students: "Connect VPN, then SSH"

**Configuration:**
- Update `SSH_ALLOWED_CIDR` in all team configs before deployment
- Test with VPN connected
- Provide VPN instructions to students

**Troubleshooting:**
- Not working? → Check VPN connection
- Still not working? → Check `curl ifconfig.me` matches allowed CIDR
- Need help? → Contact instructor or IT

---

**Status:** VPN-based SSH security configured and documented!  
**Next Step:** Update team configs with actual Cisco VPN CIDR range
