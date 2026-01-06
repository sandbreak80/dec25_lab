# Orphaned Volume Problem & Solution

## Problem Summary

**Issue**: 89 orphaned 500GB EBS volumes remain in AWS account after running cleanup scripts

**Root Causes**:
1. **Volumes created without tags** - The 500GB data volumes had no Name or Team tags
2. **Cleanup script relied on tags** - Original cleanup only searched for volumes with `tag:Team=teamX`
3. **Timing issue** - Script captured volume IDs while attached, but volumes may have already detached before deletion attempt
4. **Limited search criteria** - Only searched for volumes attached to `/dev/sdb` device

## Cost Impact

- **89 volumes × 500 GB = 44,500 GB (43.5 TB)**
- **Estimated monthly cost**: ~$4,450/month (at $0.10/GB-month for gp3 storage)
- **Annual cost if left uncleaned**: ~$53,400/year

## Solutions Implemented

### 1. Quick Fix: Bulk Cleanup Script

Created: `scripts/cleanup-all-orphaned-volumes.sh`

**Purpose**: Delete ALL unattached 500GB volumes in one operation

**Usage**:
```bash
./scripts/cleanup-all-orphaned-volumes.sh
```

**Features**:
- Finds all 500GB volumes in 'available' state
- Shows total count and estimated cost savings
- Requires confirmation: `DELETE ALL VOLUMES`
- Provides progress updates during deletion
- Region-aware (uses AWS_REGION or defaults to us-west-2)

### 2. Long-term Fix: Improved Cleanup Script

Modified: `deployment/cleanup.sh`

**Improvements**:

#### Phase 5 (Instance Termination) - Enhanced Volume Detection:
```bash
# OLD: Only searched for /dev/sdb attachments
VOLUME_IDS=$(aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_IDS" \
              "Name=attachment.device,Values=/dev/sdb" \
    --query 'Volumes[*].VolumeId' --output text)

# NEW: Searches for ALL volumes with DeleteOnTermination=false + 500GB volumes
VOLUME_IDS=$(aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_IDS" \
    --query 'Volumes[?Attachments[0].DeleteOnTermination==`false`].VolumeId' \
    --output text)

VOLUME_IDS_500GB=$(aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=$INSTANCE_IDS" \
              "Name=size,Values=500" \
    --query 'Volumes[*].VolumeId' --output text)

# Combines and deduplicates both lists
```

#### Phase 9 (Orphan Check) - Added Untagged Volume Detection:
```bash
# OLD: Only searched for tagged volumes
ORPHAN_VOLUMES=$(aws ec2 describe-volumes \
    --filters "Name=tag:Team,Values=team${TEAM_NUMBER}" \
              "Name=status,Values=available" \
    --query 'Volumes[*].VolumeId' --output text)

# NEW: Searches for BOTH tagged AND untagged 500GB volumes
ORPHAN_VOLUMES_TAGGED=$(aws ec2 describe-volumes \
    --filters "Name=tag:Team,Values=team${TEAM_NUMBER}" \
              "Name=status,Values=available" \
    --query 'Volumes[*].VolumeId' --output text)

ORPHAN_VOLUMES_500GB=$(aws ec2 describe-volumes \
    --filters "Name=size,Values=500" \
              "Name=status,Values=available" \
    --query 'Volumes[*].VolumeId' --output text)

# Combines and deduplicates both lists
```

## Recommended Actions

### Immediate Action (Clean up existing orphans):
```bash
# 1. Run the bulk cleanup script to remove all 89 orphaned volumes
cd /Users/bmstoner/code_projects/dec25_lab
./scripts/cleanup-all-orphaned-volumes.sh

# When prompted, type: DELETE ALL VOLUMES
```

### Future Deployments (Prevent new orphans):

1. **Always tag volumes during creation**:
   - Add Team, Name, Project tags to all volumes
   - Modify VM creation scripts to tag data volumes

2. **Use improved cleanup script**:
   - The updated `deployment/cleanup.sh` now handles untagged volumes
   - Run cleanup immediately after lab sessions

3. **Regular audits**:
   ```bash
   # Check for orphaned volumes monthly
   aws ec2 describe-volumes \
       --filters "Name=status,Values=available" "Name=size,Values=500" \
       --query 'Volumes[*].[VolumeId,Size,CreateTime]' \
       --output table
   ```

## Prevention: Fix Volume Creation Scripts

The deployment scripts that create VMs should tag volumes at creation time:

```bash
# When creating volumes, add tags:
aws ec2 create-volume \
    --size 500 \
    --volume-type gp3 \
    --availability-zone us-west-2a \
    --tag-specifications "ResourceType=volume,Tags=[
        {Key=Name,Value=team${TEAM_NUMBER}-data-volume},
        {Key=Team,Value=team${TEAM_NUMBER}},
        {Key=Project,Value=AppDynamics-Lab}
    ]"
```

## Verification

After running cleanup, verify all volumes are deleted:

```bash
# Should return 0 volumes
aws ec2 describe-volumes \
    --filters "Name=status,Values=available" "Name=size,Values=500" \
    --query 'Volumes[*].VolumeId' \
    --output text | wc -w
```

## Files Modified

1. `scripts/cleanup-all-orphaned-volumes.sh` - NEW bulk cleanup script
2. `deployment/cleanup.sh` - Enhanced volume detection in Phase 5 and Phase 9

## Next Steps

1. Run bulk cleanup to remove existing 89 orphaned volumes
2. Update VM creation scripts to tag volumes at creation
3. Test cleanup script with a new team deployment
4. Add volume cleanup verification to deployment testing checklist
