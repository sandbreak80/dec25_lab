# Team 5 - SecureApp Feed Configuration

**Quick reference for configuring vulnerability feeds on Team 5**

---

## Option 1: Run with Your Portal Credentials

If you have AppDynamics portal credentials:

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Set credentials as environment variables
export APPD_PORTAL_USERNAME="your-username"
export APPD_PORTAL_PASSWORD="your-password"

# Run the configuration script
./deployment/10-configure-secureapp.sh --team 5
```

---

## Option 2: Run Interactively

If you want to be prompted for password:

```bash
cd /Users/bmstoner/code_projects/dec25_lab

# Run with username, will prompt for password
./deployment/10-configure-secureapp.sh --team 5 --username your-username
```

---

## Option 3: Manual Configuration

If you prefer to run commands directly on the VM:

```bash
# SSH to Team 5 VM
ssh appduser@54.200.217.241
# Password: AppDynamics123!

# Configure portal credentials
appdcli run secureapp setDownloadPortalCredentials your-username
# Enter password when prompted

# Trigger immediate feed download
appdcli run secureapp restartFeedProcessing

# Exit
exit
```

---

## Verification (Run After 5-10 Minutes)

```bash
# SSH to VM
ssh appduser@54.200.217.241

# Check feed entry count
appdcli run secureapp numAgentReports
# Expected: Feed Entries: 10376 (or similar number > 0)

# Check SecureApp status
appdcli ping | grep SecureApp
# Expected: | SecureApp | Success |

# Run full health check
appdcli run secureapp health
# Expected: All checks pass, Feed Entries shown

# View vuln pod logs
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name | head -1) --tail=30
# Should show feed processing messages, not retry errors

exit
```

---

## Creating Portal User (If Needed)

1. Go to: https://accounts.appdynamics.com/
2. Log in with your AppDynamics account
3. Navigate to **Users** section
4. Click **Add User**
5. Create user:
   - Username: `feed-downloader` (or your preference)
   - Email: valid email
   - Role: Basic user (no admin needed)
6. Set password
7. Save

Use these credentials in the commands above.

---

## Troubleshooting

### "Authentication failed"
- Verify username and password are correct
- Check user exists in accounts portal
- Ensure user has active status

### "No feed entries after 15 minutes"
```bash
# Check vuln pod logs for errors
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) --tail=100

# Check network connectivity
curl -I https://download.appdynamics.com/

# Generate debug report
appdcli run secureapp debugReport
```

### "SecureApp still shows Failed"
- Wait full 15 minutes for initial download
- Check pod status: `kubectl get pods -n cisco-secureapp`
- Review logs: `kubectl logs <vuln-pod-name> -n cisco-secureapp`
- Run health check: `appdcli run secureapp health`

---

## Expected Timeline

| Time | Status |
|------|--------|
| 0 min | Configure credentials |
| 0-2 min | Restart feed processing |
| 2-10 min | Feed downloading |
| 10 min | Check numAgentReports (should be > 0) |
| 10-15 min | appdcli ping shows Success |

---

## After Configuration

Once configured:
- ✅ Feeds download automatically every 24 hours
- ✅ No manual intervention required
- ✅ SecureApp fully functional with CVE scanning
- ✅ Vulnerability data stays up-to-date


