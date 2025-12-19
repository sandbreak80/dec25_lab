# Known Issues - AppDynamics Virtual Appliance 25.4.0.2016

**Document Version**: 1.0  
**Release Version**: 25.4.0.2016  
**Last Updated**: December 18, 2025

---

## Critical Issues

None identified.

---

## High Priority Issues

### ISSUE-001: SecureApp Vulnerability Feed Requires Post-Installation Configuration

**Component**: Cisco Secure Application (SecureApp)  
**Severity**: Medium (Configuration Required)  
**Status**: Configuration Step Not Automated  
**Affects**: All deployments with SecureApp installed

#### Description

AppDynamics Virtual Appliance 25.4.0 includes vulnerability feed download capability but **requires manual configuration after installation**. The automatic feed download feature must be explicitly enabled by providing AppDynamics portal credentials via CLI. Without this configuration step, SecureApp operates in runtime-only mode without vulnerability scanning.

#### Symptoms

1. `appdcli ping` reports SecureApp status as "Failed"
2. Vuln pod shows high restart count (80+ restarts)
3. Vuln pod logs show repeated "on-prem feed not available, retrying later" messages
4. No CronJob or Job exists for feed downloads
5. Feed credentials (`onprem-feed-sys` secret) exist but are unused

#### Impact

- **Runtime Security**: ✅ Fully functional
- **Threat Detection**: ✅ Fully functional
- **Security Analytics**: ✅ Fully functional
- **Vulnerability Scanning**: ❌ Not available without feeds
- **CVE Detection**: ❌ Not available without feeds

**Overall Impact**: Low to Medium - Core SecureApp features work; only vulnerability scanning affected

#### Root Cause

The installation process creates all required components:
- ✅ All 15 SecureApp pods including feed processing capability
- ✅ Feed configuration (`vuln-feed-config` ConfigMap)
- ✅ Feed credentials framework (`onprem-feed-sys` Secret)
- ✅ Feed download commands (`appdcli run secureapp` tasks)
- ❌ **Portal credentials not configured by default**

The automatic feed download feature exists but requires explicit configuration with AppDynamics portal user credentials using `appdcli run secureapp setDownloadPortalCredentials`.

#### Resolution

**Option A**: Configure Automatic Feed Downloads (RECOMMENDED)

1. **Create Portal User**:
   - Log in to https://accounts.appdynamics.com/
   - Create a non-admin user for feed downloads
   - Note the username and password

2. **Configure Feed Downloads**:
   ```bash
   ssh appduser@<vm-ip>
   appdcli run secureapp setDownloadPortalCredentials <username>
   # Enter password when prompted
   
   # Optional: Force immediate download
   appdcli run secureapp restartFeedProcessing
   ```

3. **Verify Configuration**:
   ```bash
   # Wait 5-10 minutes, then check
   appdcli run secureapp numAgentReports
   appdcli ping | grep SecureApp
   ```

**Option B**: Use SecureApp Without Feeds (For Lab/Testing)
- All runtime protection features work
- Use alternative tools for CVE scanning if needed

**Option C**: Manual Feed Upload (For Air-Gapped Deployments)
- Use `appdcli run secureapp setFeedKey` and `uploadFeed` commands
- Requires feed files from AppDynamics support

#### Affected Versions

- 25.4.0.2016 (confirmed)
- Potentially other 25.4.x versions

#### Resolution Status

- **Workaround Available**: Yes (use without feeds)
- **Fix Version**: TBD (check 25.7.0 or later)
- **Support Case Required**: Yes, if vulnerability scanning needed

#### Technical Details

**Feed Configuration**:
```yaml
feed_bucket: dev-pdx-ci-feed
snyk_key_name: golden/snyk/snyk-new-feed.json.gz
maven_key_name: golden/maven/master-maven-gav.txt.gz
talos_key_name: golden/talos/master-ip-blacklist.txt.gz
kenna_key_name: golden/kenna/kenna-feed.json.gz
```

**Credentials Present**:
- `OPFDL_PORTAL_SERVER`: https://download.appdynamics.com
- `OPFDL_KEYSERV_URL`: https://feed-key-server.prod-pdx-prod.argento.io
- `OPFDL_OAUTH_URL`: https://identity-api.appdynamics.com/v3.0/oauth/token
- `OPFDL_KEY`: (90-byte authentication key)

**Missing Components**:
- No `feed-downloader` Deployment
- No `feed-sync` CronJob
- No feed import Job

#### Verification

```bash
# Check SecureApp health
ssh appduser@<vm-ip>
appdcli ping | grep SecureApp

# Verify feed downloader absence
kubectl get cronjobs,jobs,deployments -n cisco-secureapp | grep -i feed
# Returns: (empty - no feed components)

# Check vuln pod status
kubectl get pods -n cisco-secureapp | grep vuln
kubectl logs <vuln-pod-name> -n cisco-secureapp --tail=20
```

#### References

- Detailed Guide: `docs/SECUREAPP_FEED_FIX_GUIDE.md`
- Common Issues: `common_issues.md` (SecureApp Vulnerability Feed Not Downloading)
- Service Report: `docs/TEAM5_SERVICE_STATUS_REPORT.md`

---

## Medium Priority Issues

None identified.

---

## Low Priority Issues

### Cosmetic Issues

**ISSUE-002**: High Zombie Process Count
- **Component**: System/Kubernetes
- **Impact**: None (cosmetic only)
- **Description**: 27,000+ zombie processes reported by system
- **Cause**: Kubernetes pod lifecycle management
- **Resolution**: Not required - harmless artifacts

---

## Resolved Issues

None in this release.

---

## Limitations

### Optional Services Not Available

**OTIS (OpenTelemetry Integration Service)**
- Status: Not available in 25.4.0
- Command: `appdcli start otis` - not recognized
- Availability: Check version 25.7.0 or later

**UIL (Universal Integration Layer)**
- Status: Not available in 25.4.0
- Command: `appdcli start uil` - not recognized
- Purpose: Splunk Enterprise integration
- Availability: Check version 25.7.0 or later

---

## Version Comparison

| Feature | 25.4.0 | Expected in 25.7.0+ |
|---------|--------|---------------------|
| Core Controller | ✅ | ✅ |
| Events Service | ✅ | ✅ |
| EUM | ✅ | ✅ |
| Synthetic Monitoring | ✅ | ✅ |
| AIOps/Anomaly Detection | ✅ | ✅ |
| ATD | ✅ | ✅ |
| SecureApp (Runtime) | ✅ | ✅ |
| SecureApp (Vuln Feeds) | ❌ | ✅ (TBD) |
| OTIS | ❌ | ✅ (TBD) |
| UIL | ❌ | ✅ (TBD) |

---

## Support Information

### How to Report Issues

1. **AppDynamics Support Portal**: https://support.appdynamics.com/
2. **Cisco TAC**: Standard support channels
3. **Documentation**: https://docs.appdynamics.com/

### Required Information for Support Cases

When reporting issues, include:
- Virtual Appliance version: `25.4.0.2016`
- Output of `appdcli ping`
- Relevant pod logs: `kubectl logs <pod-name> -n <namespace>`
- System info: `appdctl show cluster`
- This document reference

---

## Change Log

| Date | Version | Change |
|------|---------|--------|
| 2025-12-18 | 1.0 | Initial documentation of known issues |

---

## Notes

This document will be updated as new issues are discovered or existing issues are resolved. Check for updates regularly or when applying patches/upgrades.

For the most current information, consult:
- AppDynamics Release Notes
- Product Documentation
- Support Portal Knowledge Base

