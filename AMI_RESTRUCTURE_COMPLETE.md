# ✅ AMI Configuration Restructure - Complete

## Summary

Successfully moved AMI configuration from the state directory to proper configuration management.

## What Changed

### Before (❌ Wrong Approach)
```
state/shared/ami.id           # Configuration stored as state
state/shared/ami-info.txt     # Configuration stored as state
```

**Problem:** Configuration values mixed with deployment state

### After (✅ Correct Approach)
```
config/global.cfg                  # Shared configuration (version controlled)
logs/ami-import-history.log        # Audit trail of all imports
state/shared/snapshot.id           # Actual AWS resource reference
state/shared/.deprecated/          # Old files archived
```

**Benefits:**
- Clear separation: Configuration vs State
- Version control friendly
- Self-documenting
- Easier to update
- Audit trail preserved

## Current Configuration

### Active AMI
- **AMI ID:** `ami-076101d21105aedfa`
- **Version:** 25.7.0.2255
- **Name:** AppD-VA-25.7.0.2255
- **Snapshot:** snap-01d43164a2da54233
- **Region:** us-west-2
- **Imported:** 2025-12-18T19:26:30Z

### Configuration File
**Location:** `config/global.cfg`

Contains all shared configuration:
- ✅ AMI ID and version info
- ✅ S3 bucket names
- ✅ DNS configuration
- ✅ Default VM settings
- ✅ Security defaults (Cisco VPN CIDRs)
- ✅ Cost control settings

## Updated Scripts

All scripts now read AMI ID from `config/global.cfg`:

1. **`scripts/create-vms.sh`**
   - Reads `APPD_AMI_ID` from global config
   - No longer reads from state directory

2. **`scripts/check-deployment-state.sh`**
   - Shows AMI from global config
   - Clear indication if config missing

3. **`scripts/upload-ami.sh`**
   - Updates `config/global.cfg` on new import
   - Creates backup before updating
   - Logs to history file

4. **`scripts/import-ami-from-s3.sh`**
   - Updates `config/global.cfg` on import
   - Creates backup before updating
   - Logs to history file

## File Structure

```
dec25_lab/
├── config/
│   ├── global.cfg                    # ✅ AMI ID here now
│   ├── global.cfg.backup             # Auto-created on updates
│   ├── team-template.cfg
│   └── team{1-5}.cfg
│
├── logs/
│   └── ami-import-history.log        # ✅ Audit trail
│
├── state/
│   ├── shared/
│   │   ├── snapshot.id               # ✅ AWS resource reference
│   │   └── .deprecated/
│   │       ├── ami.id                # Archived
│   │       └── ami-info.txt          # Archived
│   └── team{1-5}/                    # Team deployment state
│
└── scripts/
    ├── upload-ami.sh                 # ✅ Updated
    ├── import-ami-from-s3.sh         # ✅ Updated
    ├── create-vms.sh                 # ✅ Updated
    └── check-deployment-state.sh     # ✅ Updated
```

## Workflow

### For Future AMI Updates

```bash
# Import new AMI version
./scripts/upload-ami.sh \
  --ami-file ~/Downloads/appd_va_NEW_VERSION.ami \
  --admin-profile bstoner
```

**What happens automatically:**
1. ✅ Uploads to S3
2. ✅ Imports snapshot
3. ✅ Registers as AMI
4. ✅ **Backs up `config/global.cfg`**
5. ✅ **Updates `config/global.cfg` with new AMI ID**
6. ✅ **Appends to `logs/ami-import-history.log`**
7. ✅ All deployments automatically use new AMI

### For Deployments

```bash
# Deploy VMs (uses AMI from config/global.cfg)
./scripts/create-vms.sh --team 1
```

**No manual updates needed** - scripts automatically read from `config/global.cfg`

## Verification

### Test 1: Config Loads ✅
```bash
$ source config/global.cfg
$ echo $APPD_AMI_ID
ami-076101d21105aedfa
```

### Test 2: Scripts Parse ✅
```bash
$ bash -n scripts/create-vms.sh
✅ Syntax check passed
```

### Test 3: History Logged ✅
```bash
$ cat logs/ami-import-history.log
---
Import Date: 2025-12-18T19:26:30Z
AMI ID: ami-076101d21105aedfa
AMI Name: AppD-VA-25.7.0.2255
...
---
```

## Migration Notes

### Old Files Archived
Moved to `state/shared/.deprecated/`:
- `ami.id`
- `ami-info.txt`

**These files are no longer used.** They're kept temporarily for reference but can be deleted after verifying everything works.

### Backwards Compatibility
If you have old scripts that still reference `state/shared/ami.id`, they will fail with a clear error message directing you to update them.

## Documentation Created

1. **`AMI_MIGRATION.md`** - Detailed migration explanation
2. **`config/global.cfg`** - Well-commented configuration file
3. **`logs/ami-import-history.log`** - Audit trail format

## Benefits Realized

### 1. Clarity
- Configuration is clearly separated from state
- New team members can easily find settings
- Self-documenting code

### 2. Maintainability
- One file to update (`config/global.cfg`)
- Automatic backups on updates
- Clear audit trail

### 3. Version Control
- Config can be committed to git
- State directory remains in .gitignore
- Changes are trackable

### 4. Scalability
- Easy to add new configuration values
- Team configs can override global defaults
- Consistent structure

## Next Steps (Optional)

### Cleanup (After Testing)
```bash
# After verifying everything works (recommend waiting 1-2 weeks)
rm -rf state/shared/.deprecated/
```

### Version Control
```bash
# Commit the configuration
git add config/global.cfg
git add AMI_MIGRATION.md
git commit -m "Move AMI config from state to config directory"
```

### Team Configs (Future Enhancement)
Consider adding AMI override capability to team configs:
```bash
# In team1.cfg (if needed)
OVERRIDE_AMI_ID="ami-custom-version"  # Use specific AMI for this team
```

---

## Success Criteria ✅

- [x] AMI ID moved to `config/global.cfg`
- [x] All scripts updated to read from config
- [x] Import history logging implemented
- [x] Old state files archived
- [x] Automatic backups on updates
- [x] Documentation created
- [x] Scripts tested (syntax check)
- [x] Configuration loads correctly

**Status: COMPLETE** 🎉

All deployment scripts will now use the AMI from `config/global.cfg`. The state directory contains only actual deployment state (VPCs, instances, etc.), not configuration parameters.

---
Date: December 18, 2025
Issue: AMI ID stored in state directory
Resolution: Moved to config/global.cfg with proper separation

