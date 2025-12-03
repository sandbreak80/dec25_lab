# Cisco VPN Configuration - CONFIRMED

## ✅ VPN Ranges Configured

### US-West (Primary)
- **VPN IP Pool:** `10.188.0.0/17`
- **IPv6 Pool:** `2001:420:500::/112`
- **Public IPs:** 151.186.183.24/32, 151.186.183.87/32

### US-East (Secondary)
- **VPN IP Pool:** `10.189.0.0/18`
- **IPv6 Pool:** `2001:420:20c0::/112`
- **Public IPs:** 151.186.182.23/32, 151.186.182.87/32

### Shared Resources
- **Shared Pool:** 151.186.192.0/20
- **IPv6 Shared:** 2603:5004::/36

---

## 🔒 Security Configuration Applied

All team configurations updated with:

```bash
ALLOWED_SSH_CIDRS=(
    "10.188.0.0/17"  # Cisco VPN US-West
    "10.189.0.0/18"  # Cisco VPN US-East
)
```

### What This Means

✅ **Students can connect from either US region**
- West Coast students: Use US-West VPN → Get 10.188.x.x IP
- East Coast students: Use US-East VPN → Get 10.189.x.x IP
- Both regions work for SSH access

✅ **Security Groups will allow:**
- SSH (port 22): Only from 10.188.0.0/17 OR 10.189.0.0/18
- HTTPS (port 443): Public (via ALB)

✅ **No SSH access from:**
- Home/ISP IPs (not on VPN)
- Public internet
- Other networks

---

## 🎓 Student Instructions

### Before Lab Day

1. **Install Cisco AnyConnect**
   - Download from Cisco IT portal
   - Install on laptop

2. **Test VPN Connection**
   ```bash
   # Connect to VPN, then check IP:
   curl ifconfig.me
   
   # Expected output:
   10.188.x.x (US-West) or 10.189.x.x (US-East)
   ```

3. **If IP is outside these ranges:**
   - Contact IT support
   - May need VPN profile update

### During Lab

**Before running any scripts:**

1. **Connect to Cisco VPN** ⚠️ **REQUIRED!**
   - Open Cisco AnyConnect
   - Choose: "US-West" or "US-East" (either works)
   - Connect

2. **Verify VPN connection:**
   ```bash
   curl ifconfig.me
   # Should show: 10.188.x.x or 10.189.x.x
   ```

3. **If not on VPN, SSH will fail:**
   ```bash
   ssh appduser@<vm-ip>
   # Error: Connection timed out (expected without VPN)
   ```

4. **Once on VPN, SSH works:**
   ```bash
   ssh appduser@<vm-ip>
   # Connection successful!
   ```

---

## 🧪 Testing VPN Access

### Test 1: Verify Your IP

```bash
# Connect to VPN
# Then run:
curl ifconfig.me

# Expected (one of):
# 10.188.x.x (US-West VPN)
# 10.189.x.x (US-East VPN)
```

### Test 2: Test SSH Access

After deploying infrastructure:

```bash
# With VPN connected:
./scripts/ssh-vm1.sh --team 1
# Should work!

# Without VPN (disconnect and try):
./scripts/ssh-vm1.sh --team 1
# Should timeout (expected!)
```

### Test 3: Test HTTPS Access

```bash
# HTTPS works WITHOUT VPN (public via ALB):
curl -I https://controller-team1.splunkylabs.com/controller/

# Expected: HTTP 200 or 302 (redirect)
# Works from anywhere!
```

---

## 🔍 Troubleshooting

### Issue: "SSH connection timed out"

**Check 1: Are you on VPN?**
```bash
curl ifconfig.me
# If NOT 10.188.x.x or 10.189.x.x, you're not on VPN
```

**Solution:** Connect to Cisco VPN

**Check 2: Is your IP in allowed range?**
```bash
# Your IP should be in one of these ranges:
# 10.188.0.0 - 10.188.127.255 (US-West)
# 10.189.0.0 - 10.189.63.255 (US-East)
```

**Check 3: Security group configured?**
```bash
./scripts/check-status.sh --team 1
# Verify security groups exist
```

### Issue: "VPN connected but SSH still fails"

**Possible causes:**
1. Connected to wrong VPN endpoint (not US-West or US-East)
2. Corporate VPN assigned IP outside expected range
3. Security group not properly configured

**Solutions:**
```bash
# 1. Verify exact IP:
curl ifconfig.me

# 2. If IP is 10.x.x.x but not 10.188 or 10.189:
# May need to add additional CIDR range
# Contact instructor

# 3. Verify security group rules:
aws ec2 describe-security-groups \
  --filters "Name=tag:Team,Values=1" \
  --query "SecurityGroups[].IpPermissions"
```

### Issue: "Some students can SSH, others cannot"

**Cause:** Students connected to different VPN regions or endpoints

**Solution:**
- All students should use US-West or US-East VPN
- Both ranges are configured
- If student uses different VPN endpoint, may need to add range

---

## 📊 VPN Coverage

### Covered Regions ✅
- ✅ US-West: 10.188.0.0/17 (32,768 IPs)
- ✅ US-East: 10.189.0.0/18 (16,384 IPs)
- ✅ Total: 49,152 VPN IPs supported

### Total Capacity
- **49,152 concurrent VPN users supported**
- **20 students for this lab = 0.04% capacity**
- **No capacity concerns!**

---

## 🔐 Security Best Practices

### ✅ What We Did Right

1. **VPN-Only SSH**
   - No public SSH access
   - Only authenticated Cisco users
   - Corporate security policy compliant

2. **Regional Flexibility**
   - Both US regions supported
   - Students choose nearest
   - Better performance

3. **Public HTTPS**
   - Controller UI accessible
   - Valid SSL certificate
   - Agents can connect

### 🎯 Alternative: AWS Session Manager

If VPN is problematic, alternative approach:

```bash
# Instead of SSH, use AWS Session Manager:
aws ssm start-session --target i-xxxxx

# Advantages:
# - No VPN required
# - Works from anywhere
# - CloudTrail audit logs
# - IAM-based access

# Trade-offs:
# - More complex setup
# - Different commands
# - Requires AWS CLI
```

See `VPN_SETUP.md` for Session Manager setup instructions.

---

## ✅ Configuration Complete

**Status:** Ready for lab!

**VPN Ranges Configured:**
- ✅ US-West: 10.188.0.0/17
- ✅ US-East: 10.189.0.0/18

**All Team Configs Updated:**
- ✅ team1.cfg
- ✅ team2.cfg
- ✅ team3.cfg
- ✅ team4.cfg
- ✅ team5.cfg
- ✅ team-template.cfg

**Git Status:**
- ✅ Changes committed
- ✅ Ready to push

**Next Step:**
```bash
git push -u origin main
```

---

**Last Updated:** December 2025  
**VPN Provider:** Cisco AnyConnect  
**Regions:** US-West, US-East  
**Status:** ✅ Production Ready
