# AppDynamics VA Deployment - Credentials

**⚠️ CONFIDENTIAL - Store securely!**

---

## VM Access (SSH)

**All 3 VMs:**
- Username: `appduser`
- Password: `FrMoJMZayxBj8@iU`

**VM IPs:**
- VM1 (Primary): `ssh appduser@44.232.63.139` (10.0.0.103)
- VM2 (Worker): `ssh appduser@54.244.130.46` (10.0.0.56)
- VM3 (Worker): `ssh appduser@52.39.239.130` (10.0.0.177)

---

## Controller Access

**URL:**
```
https://controller.splunkylabs.com/controller
https://customer1.auth.splunkylabs.com/controller
```

**Admin Login:**
- Username: `admin`
- Password: `welcome` (default - **CHANGE IMMEDIATELY after first login**)

**⚠️ SECURITY WARNING:** Password is still the default. Change it immediately via:
- Controller UI → Settings → Users and Groups → admin → Change Password
- Or via Administration Console

---

## AWS Access

**Profile:** `va-deployment`  
**Region:** `us-west-2`  
**Account ID:** `314839308236`

**To use:**
```bash
export AWS_PROFILE=va-deployment
aws ec2 describe-instances
```

---

## DNS Configuration

**Domain:** `splunkylabs.com`  
**Hosted Zone ID:** `Z06491142QTF1FNN8O9PR`  
**Tenant Name:** `customer1`

**DNS Records:**
- `customer1.auth.splunkylabs.com` → 44.232.63.139
- `customer1-tnt-authn.splunkylabs.com` → 44.232.63.139
- `controller.splunkylabs.com` → 44.232.63.139
- `*.splunkylabs.com` → 44.232.63.139

---

## Resource IDs

**VPC:** `vpc-092e8c8ba20e21e94`  
**Subnet:** `subnet-080c729506fb972c4`  
**Security Group:** `appd-va-sg-1`  
**S3 Bucket:** `appd-va-bucket-stoner-lab`  
**AMI:** `ami-092d9aa0e2874fd9c`

**EC2 Instances:**
- VM1: `i-[instance-id]` (appdva-vm-1)
- VM2: `i-[instance-id]` (appdva-vm-2)
- VM3: `i-[instance-id]` (appdva-vm-3)

**Elastic IPs:**
- VM1: `44.232.63.139`
- VM2: `54.244.130.46`
- VM3: `52.39.239.130`

---

## Database Passwords (Default - Not Changed)

**MySQL root:** `changeme`  
**PostgreSQL admin:** `changeme`

**Note:** These are internal to the cluster and not externally accessible. For production, change these in `secrets.yaml` before installation.

---

## License

**Location:** `/var/appd/config/license.lic` (on VM1)  
**Status:** Not yet uploaded (apply after installation)

---

## Security Notes

1. **SSH Access:** Restricted to `47.145.5.201/32` only
2. **HTTPS:** Self-signed certificate (change for production)
3. **Passwords:** All defaults changed except internal database passwords
4. **Backups:** Configuration backups stored on VM1 in `/var/appd/config/*.backup`

---

## For Lab Students

**Share only this information:**

**Controller Access:**
- URL: https://controller.splunkylabs.com/controller
- Username: `admin`
- Password: `welcome` (instructor will change this and share new password)

**Quick Reference:** See `QUICK_REFERENCE.md`

**DO NOT SHARE:**
- VM passwords
- SSH access
- AWS credentials
- Infrastructure details

---

**Last Updated:** December 3, 2025  
**Stored in:** `config.cfg` and this file  
**Backup:** Store in password manager (1Password, LastPass, etc.)
