# Testing Script - Internal Use Only

**⚠️ NOT FOR STUDENTS - TESTING ONLY**

## Purpose

The `full-deploy.sh` script is for **instructors/admins** to test end-to-end deployments before running labs. It is NOT part of the student lab experience.

## Usage

```bash
# Full automated deployment for testing
./deployment/full-deploy.sh --team 5

# Fast testing mode (skip password change)
./deployment/full-deploy.sh --team 5 --skip-password-change

# Fastest mode (skip password + SSH keys)
./deployment/full-deploy.sh --team 5 --skip-password-change --skip-ssh-keys
```

## Features

- 100% non-interactive (no user prompts)
- Runs all 10 deployment steps automatically
- Comprehensive logging to `logs/full-deploy/`
- Progress tracking with step timing
- Error handling and summary report
- Exit code indicates success/failure

## When to Use

✅ **Before lab day** - Validate full deployment works  
✅ **Testing changes** - Verify script updates don't break deployment  
✅ **CI/CD integration** - Automate deployment validation  
✅ **Overnight builds** - Start unattended deployment

## When NOT to Use

❌ **During student labs** - Students should run step-by-step scripts  
❌ **In documentation** - Keep this internal only  
❌ **For learning** - Step-by-step is better for understanding

## Time: ~70-80 minutes

- Step 2: Infrastructure (10 min)
- Step 3: Password (1 min or skip)
- Step 4: SSH keys (1 min or skip)
- Step 5: Bootstrap (15-20 min)
- Step 6: Cluster (10 min)
- Step 7: Configure (1 min)
- Step 8: Install (20-30 min)
- Step 9: License (1 min)
- Step 10: Verify (1 min)

## Output

All output is logged to: `logs/full-deploy/teamN-TIMESTAMP.log`

Summary includes:
- Deployment duration
- Failed steps (if any)
- Access URLs
- Credentials
- Cleanup command

## Example

```bash
# Test Team 5 deployment before lab
./deployment/full-deploy.sh --team 5 --skip-password-change --skip-ssh-keys

# Check the log
tail -f logs/full-deploy/team5-*.log

# If successful, clean up
./deployment/cleanup.sh --team 5 --confirm
```

---

**Remember:** This is a testing tool, not part of the lab curriculum!




