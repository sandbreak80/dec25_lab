# AppDynamics Virtual Appliance - Vendor Documentation Issues

**Document Purpose:** Comprehensive list of issues found in official AppDynamics VA documentation and deployment scripts during real-world deployment.

**Deployment Version:** 25.4.0  
**Date:** December 3, 2025  
**Source:** https://github.com/[vendor-repo]

---

## Executive Summary

During deployment of AppDynamics Virtual Appliance to AWS, we encountered **31 issues** with the official documentation and scripts. These issues ranged from missing prerequisites to broken automation scripts, requiring significant troubleshooting and custom script development.

**Impact:**
- Expected deployment time: 2-3 hours
- Actual deployment time: 8-12 hours (first time)
- Number of script fixes required: 12
- Number of manual workarounds needed: 15
- Custom scripts created: 18

**Severity Breakdown:**
- 🔴 **Critical (blocks deployment):** 10 issues
- 🟠 **High (requires workarounds):** 13 issues
- 🟡 **Medium (usability):** 8 issues

---

## Critical Issues (Deployment Blockers)

### 1. IAM Role Creation Missing 🔴

**Location:** `04-aws-import-iam-role.sh`

**Problem:**
```bash
# Script tries to attach policy to non-existent role
aws iam put-role-policy --role-name vmimport ...
# Error: The role with name vmimport cannot be found
```

**Root Cause:**
- Script assumes `vmimport` role already exists
- Only attempts to attach policy, never creates the role
- No documentation on creating the role manually

**Impact:**
- Snapshot import (step 6) completely fails
- No error handling to guide user
- Deployment blocked until fixed

**Fix Required:**
```bash
# Create the role first
aws iam create-role \
  --role-name vmimport \
  --assume-role-policy-document "file://trust-policy.json"

# Then attach the policy
aws iam put-role-policy \
  --role-name vmimport \
  --policy-name vmimport \
  --policy-document "file://role-policy.json"
```

**Recommendation:**
- Add role creation to script
- Check if role exists before attempting policy attachment
- Provide clear error messages

---

### 2. Incomplete IAM Permissions 🔴

**Location:** `disk-image-file-role-policy.json`

**Problem:**
```bash
# Snapshot import fails with:
# Error: The service role vmimport does not have sufficient permissions
```

**Root Cause:**
Missing EBS permissions required for snapshot import:
- `ebs:CompleteSnapshot`
- `ebs:GetSnapshotBlock`
- `ebs:PutSnapshotBlock`
- `ebs:StartSnapshot`

**Impact:**
- Step 6 (import snapshot) hangs indefinitely
- No clear error message
- Process appears to be working but is actually failed

**Fix Required:**
Add to policy document:
```json
{
  "Effect": "Allow",
  "Action": [
    "ebs:CompleteSnapshot",
    "ebs:GetSnapshotBlock",
    "ebs:PutSnapshotBlock",
    "ebs:StartSnapshot"
  ],
  "Resource": "*"
}
```

**Recommendation:**
- Update policy template in repository
- Add IAM permission validation step
- Document required permissions in README

---

### 3. Security Group Not Created 🔴

**Location:** `02-aws-add-vpc.sh`

**Problem:**
```bash
# Step 8 fails with:
# Did not find a security group with the name appd-va-sg-1, exiting
```

**Root Cause:**
- VPC script creates VPC, subnet, IGW, route table
- Does NOT create security group
- Step 8 assumes security group exists

**Impact:**
- VM creation (step 8) fails immediately
- No automation for security group creation
- Must manually create via console or CLI

**Fix Required:**
Create new script `02b-aws-create-security-group.sh`:
```bash
# Create security group
aws ec2 create-security-group \
  --group-name appd-va-sg-1 \
  --description "AppDynamics VA Security Group" \
  --vpc-id ${VPC_ID}

# Add ingress rules (SSH, HTTP, HTTPS, etc.)
```

**Recommendation:**
- Add security group creation to `02-aws-add-vpc.sh`
- Or create separate numbered script (02b)
- Document security group requirements

---

### 4. Internet Gateway Not Attached 🔴

**Location:** `02-aws-add-vpc.sh`

**Problem:**
```bash
# Elastic IP association fails:
# Error: Network vpc-xxx is not attached to any internet gateway
```

**Root Cause:**
- Script creates Internet Gateway
- Script associates IGW with VPC
- BUT: Doesn't verify the attachment succeeded
- Race condition: VPC not fully ready

**Impact:**
- Step 8 creates VMs but can't assign public IPs
- VMs are unreachable from internet
- DNS configuration fails

**Fix Required:**
```bash
# Wait for IGW attachment
aws ec2 wait internet-gateway-available \
  --internet-gateway-ids ${IGW_ID}

# Verify attachment
aws ec2 describe-internet-gateways \
  --internet-gateway-ids ${IGW_ID} \
  --query 'InternetGateways[0].Attachments[0].State' \
  --output text
# Should return: "available"
```

**Recommendation:**
- Add explicit wait for IGW attachment
- Verify before proceeding to next step
- Add validation check in step 8 before EIP allocation

---

### 5. AMI Configuration Name Mismatch 🔴

**Location:** `config.cfg`, multiple scripts

**Problem:**
```bash
# Default config has wrong AMI name pattern:
APPD_RAW_IMAGE="appd-va-24.7.0-819.ami"
APPD_IMAGE_NAME="appd-va-24.7.0-ec2-disk1"

# Actual downloaded file:
appd_va_25.4.0.2016.ami  # Note: underscores, not hyphens!
```

**Root Cause:**
- Naming convention changed between versions
- Config file has old/example values
- No validation of filenames
- Multiple scripts reference these names

**Impact:**
- Scripts can't find AMI file
- Upload fails silently
- Import step uses wrong filename

**Fix Required:**
```bash
# Update config.cfg with correct names
APPD_RAW_IMAGE="appd_va_25.4.0.2016.ami"  # Match actual file
APPD_IMAGE_NAME="appd-va-25.4.0-ec2-disk1"  # EC2 AMI name
```

**Recommendation:**
- Auto-detect AMI filename in directory
- Validate file exists before upload
- Standardize naming convention across versions

---

### 6. Missing AMI ID File 🔴

**Location:** `08-aws-create-vms.sh`

**Problem:**
```bash
# Script reads AMI ID from file:
AMI_ID=$(cat ami.id)

# But ami.id is empty or doesn't exist
# Error: Missing required AMI_ID value
```

**Root Cause:**
- Step 7 (register snapshot) should write AMI ID to `ami.id`
- File is created but remains empty
- No error checking in step 7
- No fallback in step 8

**Impact:**
- VM creation fails immediately
- Must manually get AMI ID and write to file
- Breaks automation workflow

**Fix Required:**
```bash
# In 07-aws-register-snapshot.sh, ensure we write AMI ID:
echo "${AMI_ID}" > ami.id

# In 08-aws-create-vms.sh, validate before use:
if [ ! -s "ami.id" ]; then
  echo "Error: ami.id is empty"
  # Attempt to retrieve it
  AMI_ID=$(aws ec2 describe-images --owners self \
    --filters "Name=name,Values=${APPD_IMAGE_NAME}" \
    --query 'Images[0].ImageId' --output text)
  echo "${AMI_ID}" > ami.id
fi
```

**Recommendation:**
- Add robust error checking in step 7
- Validate file contents before proceeding
- Add fallback AMI ID retrieval

---

### 7. No DNS Automation 🔴

**Location:** Documentation, all scripts

**Problem:**
- Documentation says to edit `/etc/hosts` on your laptop
- For 20-person lab, everyone needs to edit `/etc/hosts`
- Changes are lost when IP changes
- Not suitable for production or shared environments

**Root Cause:**
- No Route 53 automation provided
- No DNS record creation scripts
- Assumes manual DNS management

**Impact:**
- Major usability issue for multi-user labs
- DNS resolution doesn't work outside your machine
- Can't share Controller URL with team
- Not production-ready

**Fix Required:**
Create `09-aws-create-dns-records.sh`:
```bash
# Create A records in Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch file://dns-records.json
```

**Recommendation:**
- Provide Route 53 automation scripts
- Support multiple DNS providers (Route 53, CloudFlare, etc.)
- Document DNS requirements clearly
- Provide hosted zone creation example

---

### 8. SSH Key Setup Not Documented 🔴

**Location:** `doc2.md` - Cluster Creation section

**Problem:**
```bash
# Documentation says run:
appdctl cluster init 10.0.0.56 10.0.0.177

# But doesn't mention:
# - This is interactive (prompts for passwords)
# - Passwords are needed for VM2 and VM3
# - SSH keys are automatically set up
# - Manual ssh-copy-id is NOT needed
```

**Root Cause:**
- Documentation unclear about interactive prompts
- No mention of password entry
- Example `expect` scripts in repo don't work
- Leads to confusion about SSH key distribution

**Impact:**
- Users try to automate with broken expect scripts
- SSH key setup fails
- Cluster init fails with "permission denied"
- Significant troubleshooting time

**Fix Required:**
Documentation should state:
```
Run the following command and enter the password when prompted:

$ appdctl cluster init 10.0.0.56 10.0.0.177
Enter password for appduser@10.0.0.56: [enter password]
Enter password for appduser@10.0.0.177: [enter password]

The command will automatically set up SSH keys between nodes.
```

**Recommendation:**
- Clearly document interactive nature
- Provide exact prompts users will see
- Remove broken automation scripts from repo
- Add validation step to verify SSH key distribution

---

## High Priority Issues (Require Workarounds)

### 9. Inefficient AMI Transfer Process 🟠

**Location:** Step 5 - Upload Image

**Problem:**
- Documentation says: Download 18GB AMI to your laptop
- Then upload 18GB from laptop to S3
- This is extremely slow and wasteful

**Better Solution:**
```bash
# Download directly to EC2, then to S3
# Uses AWS network speeds, no local storage needed
# Created custom script: 05-aws-upload-image-from-url.sh
```

**Impact:**
- Wastes 30-60 minutes
- Uses bandwidth unnecessarily
- May fail on poor connections
- Not feasible for larger AMIs

**Recommendation:**
- Provide direct-to-S3 download method
- Document curl with auth token approach
- Consider pre-registering AMIs in AWS Marketplace

---

### 10. Poor Script UX (No Progress Indicators) 🟠

**Location:** All deployment scripts

**Problem:**
```bash
# Script output example:
{
  "ImportSnapshotTasks": [
    {
      "ImportTaskId": "import-snap-511516ce5ae8bd92t",
      "SnapshotTaskDetail": {
        "Status": "active"
      }
    }
  ]
}
(END)
```

**Issues:**
- Raw JSON output dumped to screen
- No indication if script is still running or finished
- No progress bars or status updates
- Difficult to tell success from failure
- `(END)` marker is confusing

**Impact:**
- Users don't know if script completed
- Users interrupt running scripts thinking they hung
- Errors are buried in JSON output
- Poor troubleshooting experience

**Fix Required:**
```bash
# Add user-friendly output:
echo "==========================================="
echo "Importing Snapshot from AMI"
echo "==========================================="
echo ""
echo "📤 Starting import task..."
echo "Task ID: ${TASK_ID}"
echo ""
echo "⏳ Waiting for import to complete (this takes 10-15 minutes)..."
# Poll with progress indicator
echo "✅ Import complete!"
echo "Snapshot ID: ${SNAPSHOT_ID}"
```

**Recommendation:**
- Add clear section headers
- Use progress indicators
- Provide status updates
- Clear success/failure messages
- Hide raw JSON output (or put in log file)

---

### 11. No Configuration Validation 🟠

**Location:** Step 3 (Configuration Files)

**Problem:**
- Documentation says "edit globals.yaml.gotmpl"
- Doesn't specify what to change
- No validation of required fields
- No example showing before/after
- Services fail to install if config is wrong

**Impact:**
- Services fail to start
- No clear error about configuration
- Must manually troubleshoot YAML syntax
- Trial and error to find correct values

**Fix Required:**
Create validation script:
```bash
# validate-config.sh
echo "Validating configuration..."

# Check DNS domain is set
grep "dnsDomain: <domain_name>" globals.yaml.gotmpl && \
  echo "❌ dnsDomain not configured" && exit 1

# Validate YAML syntax
yq eval globals.yaml.gotmpl > /dev/null || \
  echo "❌ YAML syntax error" && exit 1

echo "✅ Configuration valid"
```

**Recommendation:**
- Provide validation script
- Document required changes with examples
- Show before/after comparison
- Add pre-flight check before service installation

---

### 12. Missing Bootstrap Values 🟠

**Location:** `doc1.md` - Bootstrap section

**Problem:**
Documentation says:
```
Run: sudo appdctl host init
Specify the following:
- Hostname
- Host IP address (CIDR format)
- Default gateway IP address
- DNS server IP address
```

**But doesn't provide:**
- Exact hostnames to use (appdva-vm-1? node1? vm1?)
- CIDR notation required (/24, /16?)
- What is the gateway IP? (VPC gateway? First IP?)
- What DNS server? (AWS VPC DNS? 8.8.8.8?)

**Impact:**
- Users enter wrong values
- Networking doesn't work
- Must re-bootstrap (time consuming)
- DNS resolution fails

**Fix Required:**
Documentation should provide table:
```
| Prompt              | VM1              | VM2             | VM3             |
|---------------------|------------------|-----------------|-----------------|
| Hostname            | appdva-vm-1      | appdva-vm-2     | appdva-vm-3     |
| Host IP (CIDR)      | 10.0.0.103/24    | 10.0.0.56/24    | 10.0.0.177/24   |
| Gateway             | 10.0.0.1         | 10.0.0.1        | 10.0.0.1        |
| DNS Server          | 10.0.0.2         | 10.0.0.2        | 10.0.0.2        |
```

**Recommendation:**
- Provide exact values for each prompt
- Explain how to determine correct values
- Document AWS VPC DNS server address (always .2)
- Create interactive bootstrap script

---

### 13. No Password Security Guidance 🟠

**Location:** `doc1.md`, `doc2.md`

**Problem:**
- Documentation mentions default password: `changeme`
- Says "Note: By default, the node password is set to changeme"
- Never says to CHANGE it!
- No guidance on when/how to change
- Scripts use default password in examples

**Impact:**
- Production deployments with default passwords
- Major security vulnerability
- No process for password management
- Passwords in scripts/documentation

**Fix Required:**
Add to documentation:
```
⚠️ SECURITY: Change Default Password

Before proceeding, change the default password on all VMs:

1. SSH to each VM
2. Run: passwd
3. Old password: changeme
4. New password: [strong password]

Store the new password securely (password manager recommended).
```

**Recommendation:**
- Make password change mandatory step
- Provide password change script
- Document password requirements
- Never use default passwords in examples

---

### 14. Stale Configuration Examples 🟠

**Location:** `config.cfg`

**Problem:**
```bash
# Example values don't match current version
APPD_RAW_IMAGE="appd-va-24.7.0-819.ami"  # Old version!
VM_TYPE="t3.2xlarge"                      # Wrong instance type!
AWS_REGION="us-east-1"                    # Example region
```

**Impact:**
- Users deploy with wrong settings
- Performance issues (wrong VM type)
- Scripts fail (wrong AMI name)
- Confusion about correct values

**Fix Required:**
```bash
# Keep examples commented out, with current values filled in:
# AWS Region (update for your deployment)
AWS_REGION="us-west-2"

# AMI filename (get from download portal)
# Example: appd_va_25.4.0.2016.ami
APPD_RAW_IMAGE=""  # User must fill in

# VM Type - DO NOT CHANGE unless you know requirements
# Small profile requires m5a.4xlarge minimum
VM_TYPE="m5a.4xlarge"
```

**Recommendation:**
- Keep config.cfg up to date with each release
- Validate configuration values on script run
- Provide clear comments for each setting
- Mark required vs. optional settings

---

### 15. Cluster Init Failure Modes Not Documented 🟠

**Location:** `doc2.md` - Cluster Creation

**Problem:**
Command `appdctl cluster init` can fail for many reasons:
- SSH keys not set up
- Passwords incorrect
- VMs can't reach each other
- MicroK8s not ready

**But documentation doesn't mention:**
- How to verify prerequisites
- What error messages mean
- How to troubleshoot
- How to retry after failure

**Impact:**
- Cluster creation fails
- No guidance on fixing
- Must start over from beginning
- Lost time troubleshooting

**Fix Required:**
Add to documentation:
```
Prerequisites Checklist:
- [ ] All VMs bootstrapped (appdctl show boot = Success)
- [ ] VMs can ping each other
- [ ] SSH works between VMs
- [ ] Passwords are known
- [ ] MicroK8s is running on all VMs

Common Failures:
- "Connection refused" → Check firewall/security group
- "Permission denied" → Verify password is correct
- "No route to host" → Check VPC networking
```

**Recommendation:**
- Add prerequisite checklist
- Document common failure scenarios
- Provide troubleshooting guide
- Add validation script before cluster init

---

### 16. Service Installation Time Not Documented 🟠

**Location:** `doc2.md` - Install Services

**Problem:**
```bash
# Documentation says:
appdcli start appd small

# Monitor status:
appdcli ping
```

**Doesn't mention:**
- This takes 20-30 minutes!
- Pods will restart several times (normal)
- Status will be "Failed" initially
- When to check back

**Impact:**
- Users think installation failed
- Interrupt the process
- Retry unnecessarily
- Confusion about "Failed" status

**Fix Required:**
Add to documentation:
```
⏱️ Installation Time: 20-30 minutes

The installation process:
1. Downloads container images (5-10 min)
2. Starts infrastructure pods (MySQL, Kafka, etc.)
3. Waits for databases to initialize
4. Starts AppDynamics services
5. Performs health checks

Status will show "Failed" until all dependencies are ready.
Pods may restart 2-3 times during initialization (this is normal).

Check status periodically:
$ watch -n 30 'appdcli ping'

Wait until all services show "Success" before proceeding.
```

**Recommendation:**
- Document expected installation time
- Explain restart behavior
- Add progress indicators to appdcli
- Provide monitoring guidance

---

### 17. No Rollback/Cleanup Documentation 🟠

**Location:** Missing from documentation

**Problem:**
- No guidance on rolling back failed installation
- No cleanup scripts if deployment fails mid-way
- AWS resources left running ($$!)
- No "start over" procedure

**Impact:**
- Orphaned resources costing money
- Can't retry deployment cleanly
- Must manually find and delete resources
- Risk of incomplete cleanup

**Fix Required:**
Create cleanup documentation:
```
Cleanup Procedures:

Full Cleanup (Delete Everything):
$ ./aws-delete-vms.sh

Partial Cleanup (Keep VMs, remove services):
$ appdcli stop appd
$ appdcli stop aiops
$ appdcli stop otis

Start Over (Re-deploy):
1. Run cleanup script
2. Wait 5 minutes for AWS deletion
3. Start from step 1
```

**Recommendation:**
- Provide cleanup scripts
- Document partial vs. full cleanup
- Add cost implications
- Create rollback procedures

---

### 18. Missing Cost Estimates 🟠

**Location:** Missing from documentation

**Problem:**
- No mention of AWS costs
- Users deploy 3x large instances unknowingly
- No guidance on cost optimization
- No stop/start procedures

**Impact:**
- Unexpected AWS bills ($200+/day)
- Resources left running unnecessarily
- No cost management guidance
- Complaints from finance

**Fix Required:**
Add cost section:
```
💰 Estimated Costs (us-west-2):

Per Hour:
- 3x m5a.4xlarge: $6.19/hr
- EBS volumes: $0.05/hr
- Data transfer: ~$0.05/hr
Total: ~$8.50/hour

Per Day: ~$204
Per Month: ~$6,120

Cost Optimization:
- Stop VMs when not in use (saves compute cost)
- Use smaller instances for dev/test
- Delete deployment when done
- Set AWS Budgets alerts
```

**Recommendation:**
- Add cost estimation to documentation
- Provide cost optimization tips
- Document stop/start procedures
- Recommend AWS Budgets

---

### 19. No Health Check Script 🟠

**Location:** Missing

**Problem:**
After deployment, no single command to verify everything is working.
Must run multiple commands:
- `appdctl show cluster`
- `appdctl show boot`
- `microk8s status`
- `appdcli ping`
- `kubectl get pods --all-namespaces`
- Check DNS
- Check URLs

**Impact:**
- Can't quickly verify health
- Difficult to know if ready for use
- No single source of truth

**Fix Required:**
Create `check-health.sh`:
```bash
#!/bin/bash
echo "🏥 AppDynamics Health Check"
echo ""
echo "1️⃣ Cluster Status..."
appdctl show cluster
echo ""
echo "2️⃣ Services Status..."
appdcli ping
echo ""
echo "3️⃣ DNS Resolution..."
nslookup controller.splunkylabs.com
echo ""
echo "4️⃣ Controller UI..."
curl -k -s -o /dev/null -w "%{http_code}" \
  https://controller.splunkylabs.com/controller
echo ""
```

**Recommendation:**
- Provide comprehensive health check script
- Include in repository
- Add to documentation
- Run automatically after deployment

---

### 20. CloudFormation Not Provided 🟠

**Location:** Missing

**Problem:**
- Only bash scripts provided
- No Infrastructure as Code (IaC) option
- Can't use CloudFormation, Terraform, etc.
- Difficult to replicate deployments

**Impact:**
- Not following AWS best practices
- Can't use DevOps tooling
- Hard to maintain consistency
- No drift detection

**Fix Required:**
Provide CloudFormation templates:
- `01-appd-va-infrastructure.yaml` (VPC, S3, IAM)
- `02-appd-va-instances.yaml` (EC2, EBS, EIP)

**Recommendation:**
- Provide CloudFormation templates
- Also provide Terraform modules
- Support AWS CDK
- Document IaC approach

---

## Medium Priority Issues (Usability)

### 21. No Version Compatibility Matrix 🟡

**Location:** Documentation

**Problem:**
- No clarity on which AWS resources work with which VA versions
- No AMI compatibility information
- No region availability documented
- Instance type requirements unclear

**Recommendation:**
Provide compatibility matrix:
```
VA Version | AMI Version | Min Instance | Recommended Instance
-----------|-------------|--------------|---------------------
25.4.0     | 25.4.0.2016 | m5a.2xlarge  | m5a.4xlarge
25.3.0     | 25.3.0.1895 | m5a.2xlarge  | m5a.4xlarge
```

---

### 22. No Upgrade Path Documentation 🟡

**Location:** Missing

**Problem:**
- No guidance on upgrading VA version
- No migration documentation
- Scripts only support fresh install
- `upgrade/` directory exists but incomplete

**Recommendation:**
- Document upgrade procedures
- Test and fix upgrade scripts
- Provide rollback plan
- Document data migration

---

### 23. No Monitoring/Logging Guidance 🟡

**Location:** Missing

**Problem:**
- No CloudWatch integration
- No log aggregation guidance
- No monitoring dashboards
- No alerting setup

**Recommendation:**
- Provide CloudWatch integration guide
- Document log locations and formats
- Create sample dashboards
- Add alerting best practices

---

### 24. No Multi-Region Deployment 🟡

**Location:** Scripts are single-region only

**Problem:**
- Can't deploy across regions
- No HA across regions
- All hardcoded to single region

**Recommendation:**
- Support multi-region deployment
- Document disaster recovery
- Provide region selection guidance

---

### 25. No Backup/Restore Documentation 🟡

**Location:** Missing

**Problem:**
- No backup procedures
- No restore procedures
- No disaster recovery plan
- Data loss risk

**Recommendation:**
- Document backup procedures
- Provide restore scripts
- Test DR procedures
- Document RPO/RTO

---

### 26. No Performance Tuning Guide 🟡

**Location:** Missing

**Problem:**
- No guidance on scaling
- No performance optimization
- Default settings may not be optimal
- No benchmarking information

**Recommendation:**
- Provide performance tuning guide
- Document scaling procedures
- Include benchmarking results
- Optimize default settings

---

### 27. MySQL Installation Race Condition 🟡

**Location:** Service installation

**Problem:**
```bash
# First installation attempt fails:
Error: 1 error occurred:
  * rpc error: code = Unknown desc = exec (try: 500): database is locked
FAILED RELEASES: mysql
```

**Root Cause:**
- MySQL operator database initialization race condition
- Operator not fully ready when Helm tries to install MySQL cluster
- Transient timing issue, not a real failure

**Impact:**
- Installation appears to fail
- Users think something is wrong
- No indication that a simple retry will work
- Wastes troubleshooting time

**Solution:**
Simply retry the command - it will succeed:
```bash
appdcli start appd small
# Completes in 2-3 minutes on retry
```

**Recommendation:**
- Document this as expected behavior
- Add automatic retry logic to appdcli
- Better error message: "MySQL operator initializing, please retry"
- Or: Implement wait/retry in the installer itself

---

### 28. Password Management Not Documented 🟠

**Location:** Documentation, installation process

**Problem:**
- Default Controller password is `welcome`
- No guidance on changing it before installation
- Changing `secrets.yaml` before installation doesn't work
- File gets encrypted immediately, changes are lost
- No warning about this limitation

**Root Cause:**
- `appdcli start appd` encrypts secrets.yaml immediately
- Controller reads encrypted version only
- Pre-installation changes to plaintext file are ignored
- Documentation doesn't explain encryption process
- No pre-installation password setting method provided

**Impact:**
- Controller deployed with default password
- Security vulnerability in production
- Users assume password change worked
- Confusing when login fails with new password
- Must change password via UI after installation

**Solution:**
Change password via Controller UI after first login:
```
1. Login: admin / welcome
2. Settings → Users and Groups
3. Click admin user
4. Change Password
5. Save and re-login
```

**Recommendation:**
- Document that pre-installation password change doesn't work
- Provide proper method for setting password before installation
- Add to first-time setup wizard
- Force password change on first login
- Warn about default passwords during installation

---

### 29. No Security Hardening Guide 🟡

**Location:** Minimal security guidance

**Problem:**
- Default passwords not changed
- SSH open to 0.0.0.0/0 in examples
- No encryption at rest by default
- No security audit recommendations

**Recommendation:**
- Provide security hardening checklist
- Document encryption options
- Security group best practices
- Compliance considerations

---

## Summary of Fixes Implemented

In response to these issues, we created the following:

### New Scripts Created

1. `02b-aws-create-security-group.sh` - Creates security group
2. `05-aws-upload-image-from-url.sh` - Direct S3 upload
3. `09-aws-create-dns-records.sh` - Route 53 automation
4. `download-configs.sh` - Download config files
5. `upload-config.sh` - Upload updated configs
6. `verify-ready-for-cluster.sh` - Pre-cluster validation
7. `bootstrap-vms-guide.sh` - Interactive bootstrap
8. `change-vm-passwords.sh` - Password change guide
9. `restrict-ssh-to-my-ip.sh` - SSH security
10. `register-domain.sh` - Domain registration
11. `monitor-domain-registration.sh` - Domain monitoring
12. `check-health.sh` - Health verification

### Scripts Fixed

1. `04-aws-import-iam-role.sh` - Added role creation
2. `02-aws-add-vpc.sh` - Added IGW verification
3. `06-aws-import-snapshot.sh` - Added EBS permissions
4. `07-aws-register-snapshot.sh` - Fixed AMI ID writing
5. `08-aws-create-vms.sh` - Added EIP handling

### CloudFormation Templates Created

1. `cloudformation/01-appd-va-infrastructure.yaml`
2. `cloudformation/02-appd-va-instances.yaml`
3. `cloudformation/README.md`

### Documentation Created

1. `LAB_GUIDE.md` - Complete deployment guide
2. `VENDOR_DOC_ISSUES.md` - This document
3. `IMPROVEMENTS_ROADMAP.md` - Future improvements
4. `POST_DEPLOYMENT_ANALYSIS.md` - Post-deploy steps
5. `POST_DEPLOYMENT_AUTOMATION.md` - Automation plan
6. `SECURITY_CONFIG.md` - Security details
7. `DEPLOYMENT_STATUS.md` - Current status
8. `FINAL_STATUS.md` - Final summary
9. `CONFIG_CHANGES.md` - Configuration changes
10. `COMPLETE_CONFIG_GUIDE.md` - Config guide
11. `CREATE_CLUSTER_GUIDE.md` - Cluster creation
12. `FINAL_INSTALL_CHECKLIST.md` - Install checklist

---

## Recommendations to Vendor

### Immediate Actions (Critical)

1. ✅ Fix IAM role creation in `04-aws-import-iam-role.sh`
2. ✅ Add EBS permissions to IAM policy
3. ✅ Add security group creation to VPC script
4. ✅ Update AMI naming conventions in examples
5. ✅ Document SSH key setup for cluster init
6. ✅ Add IGW attachment verification
7. ✅ Fix AMI ID file writing
8. ✅ Add DNS automation scripts

### Short-term Actions (High Priority)

9. ✅ Add progress indicators to all scripts
10. ✅ Create configuration validation script
11. ✅ Document bootstrap values clearly
12. ✅ Add password security guidance
13. ✅ Update config.cfg with current values
14. ✅ Document cluster init troubleshooting
15. ✅ Add installation time expectations
16. ✅ Create cleanup/rollback documentation
17. ✅ Add cost estimation section
18. ✅ Provide health check script
19. ✅ Create CloudFormation templates

### Long-term Actions (Medium Priority)

20. Add version compatibility matrix
21. Document upgrade procedures
22. Add monitoring/logging guidance
23. Support multi-region deployments
24. Create backup/restore documentation
25. Provide performance tuning guide
26. Create security hardening guide
27. Add direct-to-S3 AMI download option

---

## Testing Recommendations

### Test Matrix Needed

| Test Case | Priority | Status |
|-----------|----------|--------|
| Fresh install (all default values) | P0 | ❌ Currently fails |
| Fresh install (custom values) | P0 | ❌ Not tested |
| Install with existing VPC | P1 | ❌ Not supported |
| Install in different region | P1 | ❌ Not tested |
| Install with custom domain | P1 | ✅ Tested (our lab) |
| Multi-user lab setup | P1 | ✅ Tested (20 users) |
| Upgrade from previous version | P2 | ❌ Scripts incomplete |
| Disaster recovery | P2 | ❌ Not documented |
| Stop/start VMs | P2 | ⚠️ Works but not tested |
| Backup/restore | P2 | ❌ Not documented |

### Automated Testing Needed

```bash
# Example test harness
./tests/run-deployment-test.sh
  - Creates test VPC
  - Runs all deployment scripts
  - Verifies services
  - Cleans up resources
  - Reports success/failure
```

---

## Conclusion

The AppDynamics Virtual Appliance deployment scripts and documentation require significant improvements to be production-ready. Many of the issues found are critical blockers that prevent successful deployment without manual intervention.

**Impact Summary:**
- **Time Wasted:** 6-10 hours of troubleshooting on first deployment
- **Scripts Created:** 18 custom scripts to work around issues
- **Documentation Created:** 12 new documents to fill gaps
- **Code Changes:** 50+ lines of fixes to vendor scripts

**Estimated Effort to Fix (Vendor):**
- Critical fixes: 40 hours
- High priority fixes: 80 hours  
- Medium priority fixes: 60 hours
- Testing: 40 hours
- Documentation: 60 hours
- **Total: ~280 hours (~7 weeks)**

**Value of Fixes:**
- Reduces deployment time from 8-12 hours to 2-3 hours
- Eliminates most common failure points
- Enables multi-user lab deployments
- Production-ready configuration
- Better security posture
- Cost visibility and management

---

**Document Version:** 1.0  
**Last Updated:** December 3, 2025  
**Author:** Brad Stoner / Deployment Team  
**Contact:** [Contact information]

---

## CRITICAL: Issues #30 and #31 - Commands Missing from Product

### 30. OTIS Command Missing - Documentation Says It Should Work 🔴

**What Vendor Docs Say:**
> "Run the following command to install the OpenTelemetry™ service:
> ```bash
> appdcli start otis small
> ```"

**What Actually Happens:**
```
$ appdcli start otis small
error: argument subsubcommand: invalid choice: 'otis'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**CONFIRMED:** Tested on VA 25.4.0.2016 - Command does NOT exist.

---

### 31. UIL Command Missing - Documentation Says It Should Work 🔴

**What Vendor Docs Say:**
> "To integrate Splunk AppDynamics Self Hosted Virtual Appliance with Splunk Enterprise, you must install the Universal Integration Layer (UIL) service:
> ```bash
> appdcli start uil small
> ```"

**What Actually Happens:**
```
$ appdcli start uil small
error: argument subsubcommand: invalid choice: 'uil'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**CONFIRMED:** Tested on VA 25.4.0.2016 - Command does NOT exist.

**IMPACT:** Cannot integrate with Splunk Enterprise using documented method.

---

**Conclusion:** Vendor documentation explicitly states these commands should work, but they don't exist in the product. This is a CRITICAL documentation error affecting production deployments.

**Action Required:** Contact AppDynamics Support using SUPPORT_REQUEST_UIL_OTIS.md template.

