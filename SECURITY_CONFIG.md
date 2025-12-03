# Security Configuration - AppDynamics VA

**Last Updated**: December 3, 2025  
**Security Group**: sg-0736e30e6145f20a6 (appd-va-sg-1)

---

## 🔒 Current Security Rules

### Inbound (Ingress) Rules

| Protocol | Port | Source | Purpose | Status |
|----------|------|--------|---------|--------|
| TCP | 22 (SSH) | **47.145.5.201/32** | SSH access (YOUR IP ONLY) | ✅ Secure |
| TCP | 80 (HTTP) | 0.0.0.0/0 | HTTP (redirects to HTTPS) | ⚠️ Open |
| TCP | 443 (HTTPS) | 0.0.0.0/0 | HTTPS for Controller UI | ✅ Required for lab |
| TCP | 8090 | 0.0.0.0/0 | Controller UI (legacy) | ⚠️ Open |
| ALL | ALL | 10.0.0.0/24 | Inter-VM communication | ✅ Required |

### Outbound (Egress) Rules

| Protocol | Port | Destination | Purpose |
|----------|------|-------------|---------|
| ALL | ALL | 0.0.0.0/0 | Allow all outbound | ✅ Required |

---

## ✅ Security Improvements Made

### Original Issues (FIXED):
- ❌ SSH was open to 0.0.0.0/0 (entire internet)
- ❌ Placeholder VPN IPs were in security group

### Current State (SECURE):
- ✅ SSH restricted to YOUR IP only (47.145.5.201/32)
- ✅ Placeholder IPs removed
- ✅ HTTPS open for lab participants (required)
- ✅ Inter-VM communication secured to VPC subnet only

---

## 🎓 For Your 20-Person Lab

### What's Open (Intentional):
- **HTTPS (443)**: Required for lab participants to access Controller UI
- **HTTP (80)**: For automatic redirect to HTTPS
- **Controller UI (8090)**: Legacy port for Controller access

### What's Restricted:
- **SSH (22)**: Only YOU can SSH in (47.145.5.201/32)

This is **correct for a lab environment** - participants need web access, but only you need SSH access.

---

## ⚠️ Security Considerations

### Current Setup (Lab Environment) ✅
**Acceptable for:**
- Training/demo labs
- Internal corporate networks
- Short-term testing
- Non-production environments

**Protection Level:**
- SSH: ✅ Highly restricted (your IP only)
- Web Access: ✅ Open as needed for lab participants
- Inter-VM: ✅ Restricted to VPC subnet

### For Production Deployment ⚠️

If moving to production, add these restrictions:

1. **Restrict HTTPS Access**
   ```bash
   # Limit to corporate IP ranges
   aws ec2 revoke-security-group-ingress --group-id sg-0736e30e6145f20a6 --protocol tcp --port 443 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id sg-0736e30e6145f20a6 --protocol tcp --port 443 --cidr YOUR_CORP_CIDR
   ```

2. **Add Web Application Firewall (WAF)**
   - Protect against DDoS, SQL injection, XSS
   - Rate limiting for API endpoints

3. **Use Application Load Balancer**
   - SSL termination
   - Health checks
   - More robust than direct access

4. **Enable VPC Flow Logs**
   - Monitor all network traffic
   - Detect anomalies

5. **Implement Bastion Host**
   - Remove SSH from VMs entirely
   - SSH only through hardened bastion

6. **Add CloudWatch Alarms**
   - Alert on suspicious activity
   - Monitor failed login attempts

---

## 🔧 Managing SSH Access

### If Your IP Changes

Run the helper script:
```bash
./restrict-ssh-to-my-ip.sh
```

This will:
1. Detect your new public IP
2. Remove old SSH rules
3. Add new rule for your current IP

### To Add Additional Admin IPs

```bash
# Add another admin's IP
aws --profile va-deployment ec2 authorize-security-group-ingress \
    --group-id sg-0736e30e6145f20a6 \
    --protocol tcp \
    --port 22 \
    --cidr ADMIN_IP/32
```

### To Temporarily Allow Access

```bash
# Allow from anywhere (NOT RECOMMENDED)
aws --profile va-deployment ec2 authorize-security-group-ingress \
    --group-id sg-0736e30e6145f20a6 \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# REMEMBER TO REMOVE AFTER!
aws --profile va-deployment ec2 revoke-security-group-ingress \
    --group-id sg-0736e30e6145f20a6 \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

---

## 📋 Security Checklist

Current status for your deployment:

- [x] SSH restricted to specific IP (not 0.0.0.0/0)
- [x] Security group attached to all VMs
- [x] Inter-VM communication restricted to subnet
- [x] Outbound traffic allowed (required for updates)
- [ ] **TODO**: Change default VM passwords (currently: `changeme`)
- [ ] **TODO**: Change AppDynamics admin password (currently: `welcome`)
- [ ] **TODO**: Enable CloudWatch monitoring
- [ ] **TODO**: Set up backup schedules
- [ ] **TODO**: Enable MFA on AWS account
- [ ] **TODO**: Configure CloudWatch alarms
- [ ] **TODO**: Enable VPC Flow Logs (optional)

---

## 🚨 Security Incident Response

If you suspect unauthorized access:

1. **Immediately revoke all SSH access**
   ```bash
   aws ec2 revoke-security-group-ingress --group-id sg-0736e30e6145f20a6 --protocol tcp --port 22 --cidr 0.0.0.0/0
   ```

2. **Check CloudWatch Logs**
   - Look for unusual activity
   - Check login attempts

3. **Rotate All Credentials**
   - VM passwords
   - AppDynamics passwords
   - AWS access keys

4. **Review Security Group Changes**
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::EC2::SecurityGroup
   ```

---

## 📞 Quick Reference

**Your Current IP**: 47.145.5.201  
**Security Group ID**: sg-0736e30e6145f20a6  
**VPC**: vpc-092e8c8ba20e21e94 (10.0.0.0/16)  
**Subnet**: subnet-080c729506fb972c4 (10.0.0.0/24)

**Scripts**:
- `./restrict-ssh-to-my-ip.sh` - Update SSH access to current IP
- `./02b-aws-create-security-group.sh` - Recreate security group if needed

---

**Security Status**: ✅ **Appropriate for Lab Environment**

SSH is properly restricted, web access is open for lab participants. This is the correct configuration for a 20-person training lab.
