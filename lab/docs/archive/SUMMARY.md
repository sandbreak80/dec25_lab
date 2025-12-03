# Summary: AppDynamics VA AWS Deployment Improvements

**Created**: December 3, 2025  
**Status**: In Progress - Completing initial deployment

## Issues Identified During Deployment

### 1. ✅ FIXED: IAM Role Creation Missing
- **Problem**: Script 04 tried to attach policy to non-existent role
- **Fix**: Updated script to create role with trust policy first
- **Status**: Fixed and working

### 2. ✅ FIXED: Insufficient IAM Permissions
- **Problem**: vmimport role missing EBS snapshot permissions
- **Fix**: Added EBS API permissions (CompleteSnapshot, PutSnapshotBlock, etc.)
- **Status**: Fixed and working

### 3. ⚠️ Poor User Experience
- **Problem**: Scripts output raw JSON, no progress indicators, hard to tell if running/failed
- **Fix**: Documented in IMPROVEMENTS_ROADMAP.md
- **Status**: Roadmap created, implementation pending

### 4. ⚠️ Inefficient Image Transfer
- **Problem**: 18GB download to laptop then upload to S3 is wasteful
- **Fix**: Two solutions provided:
  - Enhanced script (`05-aws-upload-image-from-url.sh`) - streams from portal to S3
  - CloudFormation templates for infrastructure-as-code approach
- **Status**: Scripts created, testing pending

### 5. ⚠️ Scripts Are Stale (>1 year old)
- **Problem**: Scripts haven't been updated, may have other hidden issues
- **Fix**: Comprehensive audit and update needed
- **Status**: Tracked in roadmap, will document issues as discovered

## Deliverables Created

### 1. Improved Scripts
- `05-aws-upload-image-from-url.sh` - Direct download from AppD portal to S3

### 2. CloudFormation Templates
- `cloudformation/01-appd-va-infrastructure.yaml` - VPC, networking, S3, IAM
- `cloudformation/02-appd-va-instances.yaml` - EC2 instances (3-node cluster)
- `cloudformation/README.md` - Complete deployment guide

### 3. Documentation
- `IMPROVEMENTS_ROADMAP.md` - Comprehensive list of issues and improvements
- This summary document

## Current Deployment Status

### Completed Steps ✅
1. AWS Profile configuration
2. VPC and subnet creation
3. S3 bucket creation
4. IAM role creation (with fixes)
5. Image upload to S3
6. **IN PROGRESS**: Snapshot import (Step 6)

### Next Steps
7. Register snapshot as AMI (Step 7)
8. Create 3 EC2 instances (Step 8)
9. Bootstrap each instance
10. Create cluster
11. Install AppDynamics services

### Current State
- **Snapshot Import**: Running with Task ID `import-snap-511516ce5ae8bd92t`
- **Expected Duration**: 15-30 minutes
- **Status**: Active/In Progress

## Recommendations

### Immediate (Current Deployment)
1. ✅ Continue with current bash script deployment to completion
2. Document any additional issues encountered
3. Update roadmap with findings

### Short Term (Next Deployment)
1. Test the improved upload script with direct download
2. Improve UX of all scripts (progress bars, clear status messages)
3. Add comprehensive error handling
4. Test upgrade scripts

### Long Term (Future Deployments)
1. **Strongly recommend**: Migrate to CloudFormation templates
   - More reliable
   - Version controlled
   - Easier to maintain
   - Better error handling
   - Automated cleanup
2. Add CI/CD pipeline for testing
3. Create Terraform alternative for multi-cloud

## CloudFormation vs Bash Scripts

| Aspect | Bash Scripts | CloudFormation |
|--------|--------------|----------------|
| **Setup** | Simple, direct execution | Requires template understanding |
| **Reliability** | Manual, error-prone | Automated, consistent |
| **Cleanup** | Manual deletion needed | Single stack delete |
| **Versioning** | Hard to track changes | Native version control |
| **Rollback** | Manual | Automatic on failure |
| **Documentation** | External docs needed | Self-documenting |
| **Learning Curve** | Low | Medium |
| **Maintenance** | High (12+ scripts) | Low (2 templates) |

**Verdict**: CloudFormation is better for production deployments. Bash scripts are fine for learning/testing.

## Image Download Optimization

### Current Method (Inefficient)
```
AppD Portal → Your Laptop (18GB) → AWS S3 (18GB)
Total: 36GB transfer, 2x time, requires local storage
```

### Improved Method (Recommended)
```
AppD Portal → Temporary EC2 → AWS S3 (18GB)
Total: 18GB transfer, 1x time, no local storage, faster
```

### Implementation
```bash
# Set these from AppD download portal
export APPD_DOWNLOAD_URL="https://download.appdynamics.com/download/prox/..."
export APPD_AUTH_TOKEN="Bearer eyJ..."

# Run enhanced script
./05-aws-upload-image-from-url.sh
```

## Cost Estimate

### Infrastructure
- VPC, Subnets, IGW: **Free**
- S3 Storage (18GB): **~$0.50/month**
- NAT Gateway (if used): **~$32/month**

### Running VMs (3-node cluster)
- 3x m5a.4xlarge: **~$1,080/month**
- EBS Storage (2,100 GB): **~$210/month**
- Data transfer: **Variable**

**Total**: ~$1,290-1,322/month for running cluster

### One-Time Setup Costs
- Snapshot storage: **~$1.50/month**
- Temporary EC2 for download: **~$0.10** (1 hour)

## Files Modified/Created

### Modified
- `04-aws-import-iam-role.sh` - Added role creation and EBS permissions

### Created
- `05-aws-upload-image-from-url.sh` - Direct download script
- `IMPROVEMENTS_ROADMAP.md` - Issue tracking and roadmap
- `cloudformation/01-appd-va-infrastructure.yaml` - Infrastructure template
- `cloudformation/02-appd-va-instances.yaml` - Instances template
- `cloudformation/README.md` - CloudFormation deployment guide
- `SUMMARY.md` - This document

## Next Actions for User

### While Waiting for Snapshot Import
- ✅ Review CloudFormation templates
- ✅ Review roadmap document
- ⏳ Wait for import to complete (~15-30 min remaining)

### After Import Completes
1. Run `./07-aws-register-snapshot.sh`
2. Run `./08-aws-create-vms.sh`
3. Bootstrap each VM
4. Create cluster
5. Install services

### For Future Deployments
1. Test direct download script
2. Consider using CloudFormation templates
3. Report any issues found to be added to roadmap

## Questions to Consider

1. **Will you do frequent deployments?** → Use CloudFormation
2. **Is this a one-time thing?** → Bash scripts are fine
3. **Need to deploy in multiple regions?** → CloudFormation with parameters
4. **Want easy cleanup?** → CloudFormation
5. **Limited local bandwidth?** → Use direct download script

## Support Resources

- **Bash Scripts**: `IMPROVEMENTS_ROADMAP.md`
- **CloudFormation**: `cloudformation/README.md`
- **AppDynamics VA**: Official documentation (doc1.md, doc2.md, doc3.md)
- **AWS Resources**: AWS Documentation

---

**Note**: All improvements and fixes are documented and ready for the next deployment iteration. Current deployment should continue with existing (now-fixed) scripts.
