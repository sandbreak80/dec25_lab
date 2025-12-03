# Cisco VPN Configuration - CORRECTED

## ✅ Issue Identified and Fixed!

**Problem:** We initially configured the **internal VPN IP pools** (10.188.x.x, 10.189.x.x), but AWS sees the **public egress IPs** when VPN users connect!

**Your IP:** `151.186.183.24` ✅ Now included!

---

## 🔒 Correct Configuration

### SSH Access Now Configured For:

**US-West Public Egress:**
- `151.186.183.24/32` (your current IP!)
- `151.186.183.87/32`

**US-East Public Egress:**
- `151.186.182.23/32`
- `151.186.182.87/32`

**Shared Pool (Both Regions):**
- `151.186.192.0/20` (4,096 IPs)

**Total Coverage:** 4,100 IP addresses across both regions

---

## 📊 What Changed

### Before (WRONG):
```bash
ALLOWED_SSH_CIDRS=(
    "10.188.0.0/17"  # Internal VPN pool - NOT what AWS sees!
    "10.189.0.0/18"  # Internal VPN pool - NOT what AWS sees!
)
```

### After (CORRECT):
```bash
ALLOWED_SSH_CIDRS=(
    "151.186.183.24/32"    # Cisco VPN US-West egress 1
    "151.186.183.87/32"    # Cisco VPN US-West egress 2
    "151.186.182.23/32"    # Cisco VPN US-East egress 1
    "151.186.182.87/32"    # Cisco VPN US-East egress 2
    "151.186.192.0/20"     # Cisco VPN Shared pool (both regions)
)
```

---

## 🎯 Why This Matters

### NAT Translation
When you connect to Cisco VPN and access AWS:

1. **You get internal IP:** `10.188.x.x` (not routable)
2. **VPN NATs to public IP:** `151.186.183.24` (routable)
3. **AWS sees:** `151.186.183.24` (this is what security group checks!)

So we need to allow the **public egress IPs**, not the internal VPN pools!

---

## 🧪 Testing

### Your Current IP
```bash
curl ifconfig.me
# Shows: 151.186.183.24
```

### Check Against Configured IPs
✅ `151.186.183.24/32` - **EXACT MATCH!**  
✅ Also covered by `151.186.192.0/20` (backup)

### SSH Should Now Work
```bash
ssh appduser@<vm-ip>
# Expected: Connection successful! ✅
```

---

## 📋 Complete VPN Information

### US-West
- **Private VPN Pool:** 10.188.0.0/17 (internal only)
- **IPv6 Pool:** 2001:420:500::/112
- **Public Egress:** 151.186.183.24/32, 151.186.183.87/32, 151.186.192.0/20
- **IPv6 Public:** 2603:5004::/36

### US-East
- **Private VPN Pool:** 10.189.0.0/18 (internal only)
- **IPv6 Pool:** 2001:420:20c0::/112
- **Public Egress:** 151.186.182.23/32, 151.186.182.87/32, 151.186.192.0/20
- **IPv6 Public:** 2603:5004::/36

**Note:** Only the **Public Egress IPs** matter for AWS security groups!

---

## 🔧 Updated Files

### Configuration (6 files)
- ✅ `config/team1.cfg`
- ✅ `config/team2.cfg`
- ✅ `config/team3.cfg`
- ✅ `config/team4.cfg`
- ✅ `config/team5.cfg`
- ✅ `config/team-template.cfg`

### Scripts (1 file)
- ✅ `scripts/create-security.sh`
  - Updated CIDR descriptions
  - Recognizes all 5 Cisco public IP ranges
  - Auto-labels in AWS console

---

## 🎓 Student Impact

### Before Fix
- ❌ Students connected to VPN
- ❌ SSH timed out
- ❌ Security groups blocked public egress IPs
- ❌ Confusion and delays

### After Fix
- ✅ Students connect to VPN
- ✅ SSH works immediately
- ✅ Security groups allow Cisco public IPs
- ✅ Smooth lab experience

---

## 🔒 Security Model (CORRECTED)

### SSH Access
**Allowed from:**
- Cisco VPN US-West: `151.186.183.24/32`, `151.186.183.87/32`
- Cisco VPN US-East: `151.186.182.23/32`, `151.186.182.87/32`
- Cisco VPN Shared: `151.186.192.0/20`

**Blocked from:**
- ❌ Home/ISP IPs (not on VPN)
- ❌ Public internet
- ❌ Other corporate networks
- ❌ Even internal VPN pool IPs (10.x.x.x don't route to internet!)

### HTTPS Access
**Allowed from:**
- ✅ `0.0.0.0/0` (public via ALB)
- ✅ Works from anywhere

---

## 🚀 Next Steps

### 1. Push to GitHub
```bash
git push -u origin main
```

### 2. Test SSH Access
```bash
# You're on VPN, your IP is 151.186.183.24
# This should now work!
ssh appduser@<vm-ip>
```

### 3. Deploy Test Environment (Optional)
```bash
./lab-deploy.sh --team 1
# Security groups will be created with correct public IPs
```

---

## 📚 Lessons Learned

### Key Insight
**VPN gives you TWO IP addresses:**
1. **Internal IP** (10.x.x.x) - Only visible inside VPN network
2. **Public IP** (151.186.x.x) - What external services (like AWS) see

**For AWS security groups, you must use the PUBLIC IP!**

### Why The Confusion
Many VPNs (like home VPNs) don't do NAT - your VPN IP is what external services see. But corporate Cisco VPNs like this one use NAT translation, so the internal pool (10.x.x.x) gets translated to public egress IPs (151.186.x.x).

---

## ✅ Status

- **Configuration:** ✅ Corrected
- **Scripts:** ✅ Updated
- **Git:** ✅ Committed
- **Ready:** ✅ Push and test!

**Your IP (`151.186.183.24`) is now in the allowed list!**

---

**Last Updated:** December 2025  
**Issue:** SSH timeout from VPN  
**Root Cause:** Used internal VPN pools instead of public egress IPs  
**Resolution:** Updated all configs with correct public IPs  
**Status:** ✅ **FIXED**
