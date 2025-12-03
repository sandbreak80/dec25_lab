# Password Management for AppDynamics VA

## Current Status

### ❌ Pre-Installation Password Change: DOES NOT WORK

**Attempted approach:**
- Edit `secrets.yaml` before installation
- Change `adminPassword` field
- Upload to VM

**Why it doesn't work:**
1. The `appdcli start appd` command encrypts `secrets.yaml` immediately
2. It reads the file and creates `secrets.yaml.encrypted`
3. The Controller uses the **encrypted** version only
4. Changes to plaintext `secrets.yaml` after encryption have no effect
5. Our `sed` pattern was also incorrect (didn't match YAML spacing)

**Evidence:**
```yaml
# What we tried to change:
adminPassword: welcome

# Our sed pattern:
s/password: welcome/password: ${NEW_PASSWORD}/g

# Didn't match because field is "adminPassword:" not "password:"
```

---

## ✅ Correct Approach: Change Password After Installation

### Option 1: Via Controller UI (Recommended)

**After first login:**

1. Access Controller: https://controller.splunkylabs.com/controller
2. Login: `admin` / `welcome`
3. Go to **Settings** → **Users and Groups**
4. Click on **admin** user
5. Click **Change Password**
6. Enter new password
7. Save and re-login

**This is the officially supported method.**

---

### Option 2: Via Administration Console

```bash
# SSH to VM1
ssh appduser@44.232.63.139

# Access Administration Console
# (URL and credentials shown on first boot)
```

---

### Option 3: Edit Encrypted Secrets (Advanced)

**⚠️ Only if absolutely necessary before installation**

This requires editing the encrypted secrets file using helm-secrets:

```bash
# On VM1, BEFORE running appdcli start appd
cd /home/appduser

# Edit secrets.yaml with correct YAML key
sudo vi /var/appd/config/secrets.yaml

# Change line 9:
#   adminPassword: welcome
# To:
#   adminPassword: YourNewPassword

# Change line 37 (hybrid section):
#   adminPassword: welcome
# To:
#   adminPassword: YourNewPassword

# Save file

# Now run installation
appdcli start appd small
# This will encrypt the file with your new password
```

**Why this is tricky:**
- YAML spacing is critical
- Must change in multiple places (lines 9 and 37)
- Easy to make syntax errors
- File gets encrypted immediately on install
- No way to verify until after install completes

---

## 📝 Lessons Learned

### What We Documented

1. **Default password is `welcome`** - clearly documented
2. **Password must be changed via UI** - added to lab guide
3. **Pre-installation change doesn't work** - removed broken script
4. **Security warning** - added to all relevant docs

### Scripts Removed

- `change-controller-password.sh` - Deleted (didn't work)

### Documentation Updated

- ✅ `LAB_GUIDE.md` - Added proper password change instructions
- ✅ `CREDENTIALS.md` - Updated with correct password
- ✅ `QUICK_REFERENCE.md` - Note about instructor changing password
- ✅ `config.cfg` - Corrected password value
- ✅ `INSTALLATION_COMPLETE.md` - Security warning added
- ✅ `VENDOR_DOC_ISSUES.md` - Added issue #29 about password management

---

## 🎯 Recommendations for Future

### For Vendor (AppDynamics)

1. **Document the password change limitation** clearly
2. **Provide pre-installation password setting method** in documentation
3. **Add password change to first-time setup wizard**
4. **Warn about default passwords** during installation
5. **Force password change on first login** (like most systems)

### For Lab Instructors

1. **Change password immediately after installation**
2. **Before giving access to students:**
   - Login to Controller UI
   - Change admin password
   - Document new password securely
   - Share with students via secure channel (not email!)
3. **Create individual student accounts** with limited permissions
4. **Don't share admin password** with students if possible

### For Production Deployments

1. **Change ALL default passwords** (not just admin):
   - Controller admin
   - Controller root
   - MySQL root
   - Database users
   - KeyStore passwords
2. **Use strong passwords** (16+ characters, mixed)
3. **Store in password manager** (1Password, LastPass, etc.)
4. **Rotate passwords regularly**
5. **Implement least privilege** (create service accounts)

---

## 🔐 Current Passwords (Post-Installation)

### Controller
- **Admin:** `welcome` (default - **CHANGE VIA UI**)
- **Root:** `welcome` (default - change in `secrets.yaml.encrypted`)

### VMs (SSH)
- **User:** `appduser`
- **Password:** `FrMoJMZayxBj8@iU` (changed from default ✅)

### MySQL (Internal)
- **Root:** `appDmysql@123` (default)
- **EUM User:** `appDeum@123` (default)

### Other
- **KeyStore:** `changeit` (default)

**⚠️ For production:** Change ALL of these!

---

## 📚 Related Documentation

- `LAB_GUIDE.md` → Step 6.4: Change Admin Password
- `CREDENTIALS.md` → Current credentials
- `SECURITY_CONFIG.md` → Security best practices
- `VENDOR_DOC_ISSUES.md` → Issue #29: Password Management

---

**Created:** December 3, 2025  
**Status:** Documented and resolved  
**Action:** Use UI method to change password after installation
