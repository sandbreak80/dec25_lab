# Post-Deployment Installation Analysis

## Current State: Manual Process Hell

After AWS infrastructure deployment (steps 1-8), the following manual tasks remain:

### Phase 1: Bootstrap VMs (Per doc1.md)
- [ ] SSH to each of 3 VMs
- [ ] Run `sudo appdctl host init` on each
- [ ] Manually enter: hostname, IP/CIDR, gateway, DNS
- [ ] Run `appdctl show boot` to verify
- [ ] Repeat for all 3 nodes

**Issues**:
- 3x repetition of same process
- Manual data entry = typos
- No validation until after
- If one fails, hard to diagnose

### Phase 2: Prepare for Service Installation (Per doc2.md)
- [ ] SSH to primary node
- [ ] Navigate to `/var/appd/config`
- [ ] Edit `globals.yaml.gotmpl` with vi/vim
  - Configure DNS domain
  - Configure tenant name
  - Configure ingress settings
  - Configure certificates
  - Many other parameters
- [ ] Edit `secrets.yaml` with vi/vim
  - Set passwords for all services
  - Set admin credentials
  - Configure database passwords
- [ ] Create and run DNS verification script (`dnsinfo.sh`)
- [ ] Copy license file to `/var/appd/config/license.lic`
- [ ] Configure custom ingress certificates (optional)

**Issues**:
- Complex YAML editing in vi (error-prone)
- No validation until installation
- Easy to miss required fields
- Password management unclear
- DNS must be configured externally first
- Certificate management manual

### Phase 3: Create Cluster (Per doc2.md)
- [ ] Verify boot status on all nodes: `appdctl show boot`
- [ ] SSH to primary node
- [ ] Run: `appdctl cluster init <Node-2-IP> <Node-3-IP>`
- [ ] Verify: `appdctl show cluster`
- [ ] Verify: `microk8s status`
- [ ] Check all 3 nodes show "Running: true"

**Issues**:
- Need to track IP addresses
- No pre-flight validation
- If fails, cluster state unclear
- Manual verification required

### Phase 4: Install Services (Per doc2.md)
- [ ] Run: `appdcli start appd small|medium`
- [ ] Wait for pods to start
- [ ] Verify: `kubectl get pods --all-namespaces`
- [ ] Verify: `appdcli ping`
- [ ] Check each service status

**Issues**:
- Long running process (20-30 minutes)
- No progress indication
- Some services may fail silently
- Troubleshooting is manual

### Phase 5: Install Optional Services (Per doc2.md)
Each service has separate install process:
- [ ] Install AIOPS: `appdcli start aiops small`
- [ ] Install OTIS: `appdcli start otis small`
- [ ] Install ATD: `appdcli start atd demo|small|medium|large`
- [ ] Install UIL: `appdcli start uil small`
- [ ] Verify each with `kubectl get pods -n <namespace>`
- [ ] Verify each with `appdcli ping`

**Issues**:
- Repetitive verification steps
- Dependencies not clear
- Order matters but not enforced

### Phase 6: Apply Licenses (Per doc2.md)
- [ ] Copy license files
- [ ] Run: `appdcli license controller license.lic`
- [ ] For EUM: Configure in Admin Console
  - Access Admin Console UI
  - Navigate to Account Settings
  - Edit Controller account
  - Enter EUM license key and account name
  - Save

**Issues**:
- Multiple license types
- Some via CLI, some via UI
- Easy to miss

### Phase 7: Verify Installation (Per doc2.md)
- [ ] Access Controller UI: `https://<DNS-Name>/`
- [ ] Login (admin/welcome)
- [ ] Check all endpoints:
  - Controller: `https://<ingress>/controller`
  - Events: `https://<ingress>/events`
  - EUM Aggregator: `https://<ingress>/eumaggregator`
  - EUM Screenshots: `https://<ingress>/screenshots`
  - EUM Collector: `https://<ingress>/eumcollector`
  - Synthetic services (3 endpoints)
- [ ] Download agents from portal
- [ ] Configure monitoring

**Issues**:
- Many endpoints to check manually
- Self-signed certs cause browser warnings
- No automated health check

## Total Manual Steps: ~50+
## Estimated Time: 4-6 hours (if no errors)
## Error Probability: HIGH

---

## Problems with Current Documentation

### 1. Outdated Information
- Last updated >1 year ago
- May reference old versions
- Commands may have changed
- Paths may have changed

### 2. Missing Error Handling
- No troubleshooting for common failures
- No rollback procedures
- No validation checkpoints
- Assumes everything works first try

### 3. Prerequisites Not Clear
- DNS must be configured BEFORE installation
- Network requirements unclear
- Certificate requirements unclear
- Storage requirements unclear

### 4. Configuration Complexity
- `globals.yaml.gotmpl` has 100+ parameters
- Many interdependent settings
- No validation tool
- No templates for common scenarios

### 5. No Automation
- Everything is manual
- No scripts provided
- No configuration management
- No infrastructure as code

### 6. Poor Visibility
- No health check dashboard
- No installation progress tracking
- No centralized logging
- Manual checks required

---

## Expected Issues

Based on documentation age and complexity:

### High Probability Issues
1. **DNS Resolution Failures**
   - Tenant FQDN not resolving
   - Ingress IP not configured in DNS
   - Certificate SAN mismatches

2. **Certificate Issues**
   - Self-signed cert warnings
   - Missing SANs for all required domains
   - Certificate trust chain problems

3. **Storage Issues**
   - Data volumes not mounted correctly
   - Insufficient space
   - Permission problems

4. **Network Issues**
   - Security group rules blocking required ports
   - Inter-node communication failures
   - Ingress not accessible from outside

5. **Service Startup Failures**
   - Pods stuck in CrashLoopBackOff
   - Resource constraints (memory/CPU)
   - Configuration errors in YAML files

6. **Version Incompatibilities**
   - AppDynamics version vs script version
   - Kubernetes version incompatibilities
   - Helm chart version mismatches

### Medium Probability Issues
7. **Password/Secret Issues**
   - Password complexity requirements
   - Special characters breaking YAML
   - Secrets not encrypted properly

8. **License Issues**
   - Wrong license type
   - Expired licenses
   - License key format problems

9. **Cluster Formation Issues**
   - Nodes not joining cluster
   - Clock skew between nodes
   - Firewall blocking cluster ports

10. **Performance Issues**
    - Insufficient resources for selected profile
    - Slow storage performance
    - Network latency

---

## Automation Strategy

See `POST_DEPLOYMENT_AUTOMATION.md` for detailed automation plan using:
- Ansible playbooks
- Pre-flight validation scripts
- Configuration templates
- Health check automation
- Rollback procedures
