# AMI Configuration Migration

## What Changed

**AMI ID is now in `config/global.cfg` instead of `state/shared/ami.id`**

### Reason
Configuration values (like which AMI to use) should not be in the state directory. The state directory is for tracking resources created during deployment (VPCs, instances, etc.), not for configuration parameters.

## New Location

**Before:**
```bash
state/shared/ami.id              # ❌ Wrong - this is config, not state
state/shared/ami-info.txt        # ❌ Wrong - this is config, not state
```

**After:**
```bash
config/global.cfg                # ✅ Correct - shared configuration
logs/ami-import-history.log      # ✅ Correct - audit trail
```

## What's in Each Location

### `config/global.cfg`
**Purpose:** Shared configuration values used across all teams
**Contains:**
- `APPD_AMI_ID` - Current AMI ID to use for deployments
- `APPD_AMI_NAME` - Descriptive name
- `APPD_AMI_VERSION` - Version number
- `APPD_SNAPSHOT_ID` - Backing snapshot
- S3 bucket names
- DNS configuration
- Default VM settings
- etc.

### `state/shared/snapshot.id`
**Purpose:** Track the EBS snapshot (kept for reference)
**Contains:**
- Snapshot ID of the most recent import

### `logs/ami-import-history.log`
**Purpose:** Audit trail of all AMI imports
**Contains:**
- History of all AMI versions imported
- Import dates, task IDs, source files

### `state/teamN/` directories
**Purpose:** Track team-specific deployment state
**Contains:**
- VPC IDs, Subnet IDs, Instance IDs
- Resources created during deployment
- Resources that need to be cleaned up

## Benefits

1. **Clearer separation** - Config vs State
2. **Version control friendly** - Config can be committed, state should not
3. **Easier to update** - One file to edit when changing AMI
4. **Better documentation** - Config file is self-documenting
5. **Audit trail** - Import history preserved separately

## Migration Complete

✅ Scripts updated to read from `config/global.cfg`
✅ Current AMI ID: `ami-076101d21105aedfa`
✅ All deployment scripts will use the new location

## Old Files (Can Be Removed)

The following files are **deprecated** and can be deleted:
```bash
state/shared/ami.id              # Replaced by config/global.cfg
state/shared/ami-info.txt        # Replaced by config/global.cfg
lab/artifacts/ami.id             # No longer used
```

These files are kept temporarily for backwards compatibility but are no longer updated or read by scripts.

## For Future AMI Updates

When importing a new AMI version:
```bash
./scripts/upload-ami.sh --ami-file /path/to/new.ami --admin-profile bstoner
```

This will automatically:
1. Upload to S3
2. Import and register as AMI
3. Update `config/global.cfg` with new AMI ID
4. Append to `logs/ami-import-history.log`

---
Migration Date: December 18, 2025

