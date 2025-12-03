# AppDynamics Virtual Appliance - Post-Deployment Automation

This directory contains automation scripts to complete the AppDynamics Virtual Appliance installation after AWS infrastructure is deployed.

## Problem Statement

After deploying AWS infrastructure (VPC, EC2 instances, etc.), there are **50+ manual steps** required to:
- Bootstrap each VM
- Create the 3-node cluster
- Configure AppDynamics services
- Install and verify services

This typically takes **4-6 hours** and is highly error-prone.

## Solution

These scripts automate the entire post-deployment process, reducing time to **30-60 minutes** and eliminating manual errors.

## Directory Structure

```
post-deployment/
├── 00-preflight-check.sh          # Pre-deployment validation
├── 01-bootstrap-all-vms.sh        # Bootstrap all 3 VMs
├── 02-create-cluster.sh           # Form 3-node cluster
├── 03-generate-configs.sh         # Generate configuration files
├── 04-install-services.sh         # Install AppD services
├── 05-validate-deployment.sh      # Post-install validation
├── lib/
│   └── common.sh                  # Shared functions
├── config/
│   └── deployment.conf.example    # Configuration template
├── templates/
│   ├── globals.yaml.template      # AppD globals config
│   └── secrets.yaml.template      # AppD secrets config
└── README.md                      # This file
```

## Prerequisites

### 1. AWS Infrastructure Deployed
Run the AWS deployment scripts (01-08) or CloudFormation templates to create:
- 3 EC2 instances (m5a.4xlarge or larger)
- VPC and networking
- Security groups with required ports
- Data volumes attached

### 2. SSH Access Configured
Set up SSH key-based authentication:
```bash
# From your local machine to each VM
ssh-copy-id appduser@<node1-ip>
ssh-copy-id appduser@<node2-ip>
ssh-copy-id appduser@<node3-ip>

# Default password is: changeme
```

### 3. DNS Configured
Configure DNS records BEFORE installation:
```
customer1.auth.va.mycompany.com     → 10.0.0.100 (ingress IP)
customer1-tnt-authn.va.mycompany.com → 10.0.0.100 (ingress IP)
```

### 4. Required Tools
On your local machine:
- `bash` 4.0+
- `ssh` and `scp`
- `openssl` (for password generation)
- `jq` (optional, for JSON processing)
- `yq` (optional, for YAML validation)

## Quick Start

### Step 1: Configure Deployment

Copy and customize the configuration file:

```bash
cd post-deployment
cp config/deployment.conf.example config/deployment.conf
vi config/deployment.conf
```

**Minimum required configuration:**
```bash
# Network
DNS_DOMAIN="va.mycompany.com"
TENANT_NAME="customer1"
INGRESS_IP="10.0.0.100"

# Nodes (get from AWS)
NODE1_IP="10.0.0.10"
NODE2_IP="10.0.0.11"
NODE3_IP="10.0.0.12"

# Deployment profile
DEPLOYMENT_PROFILE="small"
```

### Step 2: Run Pre-flight Checks

```bash
./00-preflight-check.sh
```

This validates:
- Network connectivity to all nodes
- SSH access
- DNS resolution
- Disk space
- Required files

**Fix any errors before proceeding!**

### Step 3: Bootstrap VMs

```bash
./01-bootstrap-all-vms.sh
```

This configures hostname, IP, gateway, and DNS on all 3 nodes.

**Time:** ~5 minutes

### Step 4: Create Cluster

```bash
./02-create-cluster.sh
```

Forms a 3-node Kubernetes cluster.

**Time:** ~5 minutes

### Step 5: Generate Configurations

```bash
./03-generate-configs.sh
```

Creates `globals.yaml` and `secrets.yaml` from templates, generates secure passwords.

**Time:** ~1 minute

### Step 6: Install Services

```bash
./04-install-services.sh
```

Installs AppDynamics services based on your configuration.

**Time:** ~20-40 minutes

### Step 7: Validate Deployment

```bash
./05-validate-deployment.sh
```

Verifies all services are running and accessible.

**Time:** ~2 minutes

## Complete End-to-End

Run all steps at once:

```bash
./00-preflight-check.sh && \
./01-bootstrap-all-vms.sh && \
./02-create-cluster.sh && \
./03-generate-configs.sh && \
./04-install-services.sh && \
./05-validate-deployment.sh
```

## Configuration Options

### Deployment Profiles

| Profile | Nodes | CPU/Node | Memory/Node | Use Case |
|---------|-------|----------|-------------|----------|
| small   | 3     | 16 vCPUs | 64 GB       | Dev/Test |
| medium  | 3     | 32 vCPUs | 128 GB      | Production |
| large   | 3     | 64 vCPUs | 256 GB      | Enterprise |

### Optional Services

Enable in `deployment.conf`:

```bash
INSTALL_CORE=true      # Required (Controller, Events, EUM)
INSTALL_AIOPS=true     # Anomaly Detection
INSTALL_OTIS=true      # OpenTelemetry
INSTALL_ATD=true       # Automatic Transaction Diagnostics
INSTALL_UIL=true       # Universal Integration Layer (Splunk)
```

### Custom Certificates

For production deployments:

```bash
USE_CUSTOM_CERTS=true
CERT_PATH="/path/to/certificate.crt"
KEY_PATH="/path/to/private.key"
```

Certificate requirements:
- Valid for 1+ year
- Includes required SANs:
  - `customer1.auth.va.mycompany.com`
  - `customer1-tnt-authn.va.mycompany.com`
  - `*.va.mycompany.com` (wildcard)

## Troubleshooting

### Script Fails on Pre-flight Check

**Problem:** DNS not resolving or SSH not accessible

**Solution:**
1. Verify DNS records: `nslookup customer1.auth.va.mycompany.com`
2. Test SSH: `ssh appduser@<node-ip>`
3. Check security groups allow ports 22, 443, 8090

### Bootstrap Fails

**Problem:** `appdctl host init` fails

**Solution:**
1. SSH to node manually
2. Check logs: `sudo journalctl -u appd-bootstrap`
3. Verify network settings in `/etc/netplan/`
4. Re-run bootstrap script

### Cluster Formation Fails

**Problem:** Nodes don't join cluster

**Solution:**
1. Check time sync: `date` on all nodes (must be within 1 minute)
2. Verify inter-node connectivity: `ping <node-ip>` from each node
3. Check firewall: `sudo ufw status`
4. Review cluster logs: `microk8s inspect`

### Service Installation Fails

**Problem:** Pods stuck in CrashLoopBackOff

**Solution:**
1. Check pod logs: `kubectl logs <pod-name> -n <namespace>`
2. Verify resources: `kubectl describe node`
3. Check PVC status: `kubectl get pvc --all-namespaces`
4. Review AppD logs: `journalctl -u appd-*`

### Services Not Accessible

**Problem:** Cannot access Controller UI

**Solution:**
1. Verify DNS resolves to ingress IP
2. Check ingress controller: `kubectl get ingress --all-namespaces`
3. Test locally: `curl https://customer1.auth.va.mycompany.com`
4. Check security group allows port 443

## Manual Steps Still Required

These must be done manually after automation:

1. **Change Default Passwords**
   ```bash
   ssh appduser@<node-ip>
   passwd
   ```

2. **Configure EUM License** (if using infrastructure-based licensing)
   - Login to Controller UI
   - Go to Account Settings → Edit account
   - Add EUM license key and account name

3. **Download and Install Agents**
   - Access Controller UI
   - Download agents from Getting Started page
   - Deploy to your applications

4. **Configure Monitoring**
   - Create applications
   - Configure business transactions
   - Set up health rules and alerts

## Rollback

If installation fails and you need to start over:

```bash
# On each node
ssh appduser@<node-ip>

# Remove cluster
appdctl cluster destroy

# Reset services
sudo apt-get purge -y appd-*
sudo rm -rf /var/appd/*
sudo rm -rf /data/*

# Reboot
sudo reboot
```

Then re-run automation scripts from Step 1.

## Advanced Usage

### Dry Run Mode

Test without making changes:

```bash
DRY_RUN=true ./01-bootstrap-all-vms.sh
```

### Skip Pre-flight Checks

(Not recommended for production):

```bash
SKIP_PREFLIGHT=true ./01-bootstrap-all-vms.sh
```

### Custom Log Directory

```bash
LOG_DIR="/custom/log/path" ./04-install-services.sh
```

### Debug Mode

Enable verbose logging:

```bash
set -x
./04-install-services.sh
```

## Files Generated

During deployment, these files are created:

- `/tmp/credentials.txt` - Generated passwords (KEEP SECURE!)
- `/var/appd/config/globals.yaml.gotmpl` - AppD configuration
- `/var/appd/config/secrets.yaml` - Encrypted secrets
- `/var/appd/config/license.lic` - License file
- `deployment.log` - Full deployment log

## Security Best Practices

1. **Change default password** immediately after first login
2. **Use custom certificates** for production
3. **Store credentials securely** (use password manager or secrets vault)
4. **Delete `/tmp/credentials.txt`** after copying passwords
5. **Restrict SSH access** with key-based auth only
6. **Enable firewall** on all nodes
7. **Regular backups** of `/var/appd/config` directory

## Integration with CI/CD

Example GitLab CI/CD pipeline:

```yaml
deploy-appd:
  stage: deploy
  script:
    - cd post-deployment
    - ./00-preflight-check.sh
    - ./01-bootstrap-all-vms.sh
    - ./02-create-cluster.sh
    - ./03-generate-configs.sh
    - ./04-install-services.sh
    - ./05-validate-deployment.sh
  only:
    - master
```

## Next Steps

After successful deployment:

1. **Access Controller UI**: `https://customer1.auth.va.mycompany.com/controller`
   - Username: `admin`
   - Password: `welcome` (change immediately!)

2. **Review Documentation**:
   - POST_DEPLOYMENT_ANALYSIS.md - Known issues
   - POST_DEPLOYMENT_AUTOMATION.md - Architecture details
   - IMPROVEMENTS_ROADMAP.md - Future enhancements

3. **Configure Monitoring**:
   - Create applications
   - Deploy agents
   - Set up dashboards

4. **Backup Configuration**:
   ```bash
   ssh appduser@<node1-ip>
   sudo tar czf /tmp/appd-config-backup.tar.gz /var/appd/config
   scp appduser@<node1-ip>:/tmp/appd-config-backup.tar.gz .
   ```

## Support

For issues:
- Check `POST_DEPLOYMENT_ANALYSIS.md` for known problems
- Review AppDynamics documentation at docs.appdynamics.com
- Check script logs in `${LOG_DIR}`
- Open issue in repository

## Contributing

Improvements welcome! Please:
1. Test thoroughly in non-production environment
2. Update documentation
3. Follow existing code style
4. Add error handling

## License

These scripts are provided as-is for AppDynamics Virtual Appliance deployment automation.
