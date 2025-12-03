# Support Request Template for AppDynamics

## Issue: UIL and OTIS Commands Missing from VA 25.4.0

**To:** AppDynamics Support  
**Subject:** UIL and OTIS installation commands missing in VA 25.4.0 - Documentation Error

---

### Summary

The official AppDynamics Virtual Appliance documentation instructs users to install UIL and OTIS using `appdcli` commands, but these commands do not exist in VA 25.4.0.2016. This appears to be a significant documentation error affecting deployments and Splunk integration.

---

### Environment

- **Product:** AppDynamics Virtual Appliance
- **Version:** 25.4.0.2016
- **AMI File:** appd_va_25.4.0.2016.ami
- **Deployment:** AWS (3-node cluster, m5a.4xlarge)
- **Deployment Date:** December 3, 2025
- **Region:** us-west-2

---

### Issue Details

#### Problem 1: UIL Command Missing

**Documentation States:** (from official docs)
```bash
appdcli start uil small
```

**Actual Result:**
```
$ appdcli start uil small
appdcli start: error: argument subsubcommand: invalid choice: 'uil'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**Impact:**
- Cannot integrate with Splunk Enterprise using documented method
- Blocks critical integration workflow
- No alternative method provided in documentation

---

#### Problem 2: OTIS Command Missing

**Documentation States:** (from official docs)
```bash
appdcli start otis small
```

**Actual Result:**
```
$ appdcli start otis small
appdcli start: error: argument subsubcommand: invalid choice: 'otis'
(choose from 'all', 'appd', 'aiops', 'secapp', 'atd')
```

**Impact:**
- Cannot install OpenTelemetry service using documented method
- No alternative method provided in documentation

---

### Available Commands in VA 25.4.0

```bash
$ appdcli start --help
Available subcommands:
  - all
  - appd
  - aiops
  - secapp
  - atd

Missing from documentation:
  - uil (documented but doesn't exist)
  - otis (documented but doesn't exist)
```

---

### Commands That DO Work

✅ Successfully installed:
```bash
appdcli start appd small     # Works - Core services
appdcli start aiops small    # Works - AIOps/Anomaly Detection
appdcli start atd small      # Works - Auto Transaction Diagnostics
appdcli start secapp small   # Available (not tested)
```

❌ Documented but don't work:
```bash
appdcli start uil small      # Fails - Command doesn't exist
appdcli start otis small     # Fails - Command doesn't exist
```

---

### Questions for Support

1. **Are UIL and OTIS available in VA 25.4.0?**
   - If yes, what is the correct installation method?
   - If no, why does the documentation include them?

2. **Version Compatibility:**
   - Which VA versions support UIL and OTIS via `appdcli`?
   - Is there a version compatibility matrix?
   - Should we upgrade to a different version?

3. **Alternative Installation Methods:**
   - Can UIL and OTIS be installed manually via Helm charts?
   - If yes, can you provide Helm chart installation instructions?
   - Where can we find the Helm charts?

4. **Splunk Integration Without UIL:**
   - What is the recommended method to integrate VA 25.4.0 with Splunk Enterprise?
   - Are there alternative integration methods besides UIL?
   - Can we use Splunk HEC or other approaches?

5. **Documentation Updates:**
   - When will the documentation be updated to match VA 25.4.0?
   - Can you provide accurate documentation for this version?
   - Is there a version-specific installation guide?

---

### Impact to Our Deployment

**Priority:** HIGH

**Business Impact:**
- 20-person lab environment deployment affected
- Splunk integration planned but cannot proceed
- OpenTelemetry ingestion unavailable
- Users losing confidence in documentation accuracy
- Additional time spent troubleshooting non-existent commands

**Current Status:**
- Core services: Fully operational ✅
- AIOps: Successfully installed ✅
- ATD: Successfully installed ✅
- UIL: Cannot install ❌
- OTIS: Cannot install ❌

---

### Requested Resolution

1. **Immediate:** Confirm whether UIL and OTIS are available in VA 25.4.0
2. **Short-term:** Provide correct installation method OR alternative approach
3. **Long-term:** Update documentation to match actual product capabilities

---

### Additional Information

**Deployment Details:**
- AWS Account: 314839308236
- VPC: vpc-092e8c8ba20e21e94
- Region: us-west-2
- Cluster: 3 nodes (m5a.4xlarge)
- DNS: splunkylabs.com
- Services: Controller, Events, EUM, Synthetic, AIOps, ATD

**Contact Information:**
- Name: [Your Name]
- Email: [Your Email]
- Phone: [Your Phone]
- Company: [Your Company]
- Use Case: Lab environment for 20 users

---

### Attachments

Would you like us to provide:
- [ ] Full `appdcli` help output
- [ ] Helm chart list from cluster
- [ ] Version information from all components
- [ ] Log files
- [ ] Screenshot of error

---

**Urgency:** Please respond with clarification on UIL/OTIS availability and Splunk integration alternatives.

Thank you,
[Your Name]

---

**Template Version:** 1.0  
**Date:** December 3, 2025  
**Issue Reference:** VENDOR_DOC_ISSUES.md #30, #31
