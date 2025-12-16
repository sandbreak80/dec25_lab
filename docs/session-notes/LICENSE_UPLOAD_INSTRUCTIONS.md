# License Upload - Quick Start

## For Instructor (One-Time Setup)

### Step 1: Use Admin Credentials

The license upload requires **admin AWS credentials** because it creates an S3 bucket.

```bash
# Option A: Use named profile
export AWS_PROFILE=default  # your admin profile name

# Option B: Temporarily configure admin credentials
aws configure --profile admin
# Then: export AWS_PROFILE=admin
```

Verify you're using admin:
```bash
aws sts get-caller-identity
# Should show: "arn:aws:iam::314839308236:user/YOUR_ADMIN_USER"
# NOT: "arn:aws:iam::314839308236:user/lab-student"
```

### Step 2: Upload License

```bash
cd /Users/bmstoner/code_projects/dec25_lab

./scripts/upload-license-to-s3.sh
```

Expected output:
```
✅ License Upload Complete!

S3 Location:
  s3://appdynamics-lab-resources/shared/license.lic

Students can download using:
  aws s3 cp s3://appdynamics-lab-resources/shared/license.lic /tmp/license.lic
```

### Step 3: Switch Back to Lab-Student

```bash
unset AWS_PROFILE

# Or reconfigure lab-student
aws configure
# Use access keys from STUDENT_CREDENTIALS.txt
```

---

## For Students (Apply License to Team)

After the instructor uploads the license to S3, students can apply it:

```bash
# After installing Controller
./scripts/apply-license.sh --team 1
```

This will:
- ✅ Download license from S3 (no admin required)
- ✅ Copy to VM1
- ✅ Apply to Controller
- ✅ Wait for activation

---

## Verification

### Check in Controller UI:

1. Go to: `https://controller-team1.splunkylabs.com/controller/`
2. Login: admin / welcome
3. Navigate to: **Settings → License → Account Usage**
4. Verify:
   - Edition: ENTERPRISE
   - Expires: 2025-12-31
   - APM Agents: 10 units

---

## Troubleshooting

### Upload Fails with "AccessDenied"

**Problem:** Using lab-student credentials

**Solution:** Switch to admin profile (see Step 1 above)

### Students Can't Download from S3

**Problem:** Bucket policy not set correctly

**Solution:** Re-run upload script as admin:
```bash
export AWS_PROFILE=admin
./scripts/upload-license-to-s3.sh
```

---

## License Details

- **File:** `license.lic` (in project root)
- **Customer:** cust
- **Edition:** ENTERPRISE
- **Expires:** 2025-12-31
- **APM Agents:** 10 units
- **Machine Agents:** 10 units
- **Database Agents:** 5 units

---

## Alternative: Skip S3 (Use Local File)

If you don't want to use S3, students can apply the license directly from their local machine:

```bash
# Copy license.lic to your local project directory first

./scripts/apply-license.sh --team 1 --license-file ./license.lic
```

This bypasses S3 entirely and copies the local file to VM1.

---

**See full documentation:** `docs/LICENSE_MANAGEMENT.md`

