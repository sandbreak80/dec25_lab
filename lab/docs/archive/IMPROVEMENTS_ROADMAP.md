# AWS Deployment Scripts - Improvement Roadmap

## CRITICAL: Scripts Are Stale (Last Updated >1 Year Ago)

### Overview
All AWS deployment scripts require comprehensive review and updates. They were last updated over a year ago and have functional issues that impact deployment success.

### Known Functional Issues

#### 1. **04-aws-import-iam-role.sh** ❌ FIXED
- **Issue**: Script attempted to attach policy to role before creating the role
- **Impact**: Script fails with "role cannot be found" error
- **Fix Applied**: Added role creation with trust policy before attaching permissions
- **Status**: ✅ Patched during deployment

#### 2. **IAM Role Permissions Incomplete** ❌ FIXED
- **Issue**: vmimport role missing EBS snapshot permissions
- **Impact**: Import snapshot fails with "insufficient permissions" error
- **Fix Applied**: Added EBS API permissions (CompleteSnapshot, PutSnapshotBlock, etc.)
- **Status**: ✅ Patched during deployment

#### 3. **Potential Issues Not Yet Discovered**
- Other scripts may have similar issues
- AWS API changes in past year may break functionality
- Deprecated AWS CLI commands or parameters
- Changed resource naming conventions
- Updated AWS service requirements

### Required Actions

#### Phase 1: Audit & Testing (Immediate)
- [ ] Test each script in isolated AWS environment
- [ ] Document all errors and warnings encountered
- [ ] Check AWS CLI version compatibility
- [ ] Review AWS API changelog for breaking changes
- [ ] Verify all resource tags and naming conventions
- [ ] Test with latest AppDynamics VA versions

#### Phase 2: Update Scripts for AWS Best Practices
- [ ] Update IAM policies to follow least-privilege principle
- [ ] Add IMDSv2 support for EC2 instances
- [ ] Update to latest AWS CLI command syntax
- [ ] Implement proper error handling
- [ ] Add resource tagging consistency
- [ ] Update security group rules to current standards
- [ ] Review VPC and networking configurations

#### Phase 3: Modernization
- [ ] Update to use AWS CloudFormation or Terraform as alternative
- [ ] Add support for AWS Systems Manager
- [ ] Implement proper logging to CloudWatch
- [ ] Add cost estimation before deployment
- [ ] Support for multiple regions
- [ ] Add disaster recovery procedures

### Scripts Requiring Review & Updates

| Script | Status | Priority | Known Issues |
|--------|--------|----------|--------------|
| `01-aws-create-profile.sh` | ⚠️ Unknown | Medium | Not tested in current environment |
| `02-aws-add-vpc.sh` | ⚠️ Unknown | High | Networking configurations may be outdated |
| `03-aws-create-image-bucket.sh` | ⚠️ Unknown | Medium | S3 security policies may need updates |
| `04-aws-import-iam-role.sh` | ✅ Fixed | Critical | Role creation was missing - NOW FIXED |
| `05-aws-upload-image.sh` | ⚠️ Unknown | Low | May need multipart upload for large files |
| `06-aws-import-snapshot.sh` | ⚠️ Partial | Critical | Permissions fixed, UX needs improvement |
| `07-aws-register-snapshot.sh` | ⚠️ Unknown | High | Not yet tested |
| `08-aws-create-vms.sh` | ⚠️ Unknown | Critical | May have instance type/AMI issues |
| `aws-delete-vms.sh` | ⚠️ Unknown | High | Cleanup may be incomplete |
| **Upgrade Scripts** | | | |
| `upgrade/01-aws-get-vm-details.sh` | ⚠️ Unknown | High | Not tested |
| `upgrade/02-aws-terminate-vms.sh` | ⚠️ Unknown | High | Not tested |
| `upgrade/03-aws-get-vm-status.sh` | ⚠️ Unknown | Medium | Not tested |
| `upgrade/04-aws-create-vms.sh` | ⚠️ Unknown | Critical | Not tested |

### Testing Checklist
- [ ] Fresh AWS account deployment test
- [ ] Existing infrastructure deployment test
- [ ] Upgrade path testing
- [ ] Rollback/cleanup testing
- [ ] Multi-region testing
- [ ] Different instance types testing
- [ ] Network isolation testing
- [ ] Security group rules validation

---

## Priority 0: Critical Inefficiency - Image Download/Upload

### Problem
Current process requires:
1. Download 18GB AMI file to local laptop
2. Upload 18GB file from laptop to S3
This is wasteful, slow, and may fail on poor connections.

### Solution Implemented
**CloudFormation Templates** (See `cloudformation/` directory)
- Complete infrastructure as code deployment
- Automated resource creation and cleanup
- Better error handling and consistency

**Direct Download Script** (`05-aws-upload-image-from-url.sh`)
- Uses temporary EC2 instance to download directly from AppDynamics portal
- Streams file directly to S3 without local storage
- Much faster for large files
- Uses curl with Bearer token authentication from download portal

### Usage
```bash
# Get download URL and token from AppDynamics download portal
export APPD_DOWNLOAD_URL="https://download.appdynamics.com/download/prox/download-file/appd-va/..."
export APPD_AUTH_TOKEN="Bearer eyJ..."

# Script will automatically use direct download mode
./05-aws-upload-image-from-url.sh
```

**Benefits:**
- No local storage required
- Faster transfer (AWS network speeds)
- Less error-prone
- Can handle very large files
- Works from any machine, even low-bandwidth

### Alternative: CloudFormation Deployment
See `cloudformation/README.md` for complete Infrastructure as Code approach.

---

## Priority 1: User Experience & Status Feedback

### Problem
Current scripts have poor user feedback making it difficult to understand:
- Whether a script is still running, completed, or failed
- Current progress/status of long-running operations
- What the next action should be
- Interpreting raw JSON output

### Proposed Improvements

#### 1. Standardize Script Output Format
- **Clear Start/End Markers**: Each script should print clear banners
  ```
  ========================================
  Starting: Create S3 Bucket
  ========================================
  ```
- **Status Indicators**: Use symbols and colors
  - ✓ Success (green)
  - ✗ Error (red)
  - ⏳ In Progress (yellow)
  - ℹ Info (blue)

#### 2. Long-Running Operations (e.g., 06-aws-import-snapshot.sh)
- **Progress Bar or Percentage**: Show import progress if available
- **Time Estimates**: Display elapsed time and estimated completion
- **Better Status Messages**: Replace raw JSON with:
  ```
  ⏳ Import Status: Active
  📊 Progress: Processing... (Elapsed: 5m 23s)
  🔄 Checking again in 30 seconds...
  ```
- **Final Summary**:
  ```
  ✓ Snapshot Import Completed Successfully!
  📝 Snapshot ID: snap-0123456789abcdef0
  ⏱  Total Time: 23 minutes 14 seconds
  ➡️  Next Step: Run ./07-aws-register-snapshot.sh
  ```

#### 3. Error Handling Improvements
- **Clear Error Messages**: Explain what went wrong and why
- **Suggested Fixes**: Provide actionable next steps
- **Exit Codes**: Consistent exit codes for automation
- **Rollback Guidance**: Instructions for cleanup if needed

#### 4. JSON Output Control
- **Hide by Default**: Raw JSON should be optional
- **Summary View**: Show only relevant information
- **Verbose Flag**: Add `--verbose` or `--json` flag for full output
- **Log Files**: Save detailed output to log files automatically

#### 5. Overall Script Improvements
- **Pre-flight Checks**: Verify prerequisites before running
- **Dry-run Mode**: Show what would happen without executing
- **Resume Capability**: For long operations, allow resuming after interruption
- **Idempotency**: Scripts should be safe to re-run
- **Help Text**: Add `--help` flag to all scripts
- **Status Command**: Add a script to check overall deployment status

#### 6. Example: Improved 06-aws-import-snapshot.sh Output
```bash
========================================
Step 6: Import Snapshot from S3 to EBS
========================================

ℹ  Source: s3://appd-va-bucket-stoner-lab/appd_va_25.4.0.2016.ami
ℹ  Image Size: 18 GB

⏳ Starting import task...
✓  Import Task Created: import-snap-511516ce5ae8bd92t

⏳ Importing snapshot (this may take 15-30 minutes)...

[Progress Updates]
⏱  00:00:30 - Status: Active - Validating image format...
⏱  00:01:00 - Status: Active - Processing disk image...
⏱  00:15:23 - Status: Active - Creating EBS snapshot (78% complete)...
⏱  00:23:14 - Status: Completed

========================================
✓  Snapshot Import Completed Successfully!
========================================

📋 Summary:
   Snapshot ID: snap-0123456789abcdef0
   Size: 200 GB
   Duration: 23 minutes 14 seconds
   
💾 Saved to: snapshot.id

➡️  Next Step: Run ./07-aws-register-snapshot.sh

========================================
```

### Implementation Notes
- Consider using `jq` for JSON parsing
- Add color support with `tput` or ANSI codes
- Create a shared library for common functions
- Add logging framework for debugging

### Files to Update
1. `01-aws-create-profile.sh`
2. `02-aws-add-vpc.sh`
3. `03-aws-create-image-bucket.sh`
4. `04-aws-import-iam-role.sh`
5. `05-aws-upload-image.sh`
6. `06-aws-import-snapshot.sh` ⭐ High Priority
7. `07-aws-register-snapshot.sh`
8. `08-aws-create-vms.sh`
9. All upgrade scripts

---

## Priority 2: Error Recovery & Validation

### Issues
- Scripts fail without proper cleanup
- Hard to recover from partial failures
- No validation of prerequisites

### Improvements Needed
- Pre-execution validation checks
- Graceful error handling with cleanup
- State tracking for resume capability
- Validation of resources before proceeding

---

## Priority 3: Documentation in Scripts

### Add to Each Script
- Purpose and what it does
- Prerequisites
- Expected runtime
- Resources created
- Cost implications (if any)
- Rollback procedure

---

**Created**: December 3, 2025
**Reported by**: User feedback during deployment
**Priority**: High - Impacts user experience significantly
