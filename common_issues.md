# Common Issues and Resolution Guide

## EUM JavaScript Agent Hosting Issues

### Why can't I host ADRUM JavaScript agent files inside the OVA EUM pod?

In the AppDynamics On-Prem Virtual Appliance (OVA) Kubernetes deployment, the End User Monitoring (EUM) pod does not support hosting ADRUM JavaScript agent files internally as in classic on-premises deployments. The EUM pod contains only a "License" folder and lacks a "wwwroot" directory or any built-in static file server to serve these files. Hence, if you attempt to place ADRUM files inside the EUM pod, you encounter 404 or unreachable errors when accessing these files via expected URLs.

#### Resolution Steps:

1. **Download ADRUM JavaScript Files**
   - Log in to the AppDynamics Controller GUI
   - Navigate to **User Experience > Browser Application**
   - Select the option to host JavaScript files locally to download the full ADRUM JavaScript package

2. **Set Up Internal Web Server**
   - Deploy a web server (e.g., Apache, Nginx, IIS) inside your internal network
   - Upload the downloaded ADRUM JavaScript files to this server

3. **Configure EUM Settings**
   - In the Controller GUI, update the EUM configuration to point to the internal web server URL hosting the ADRUM files

4. **Verify Access and Functionality**
   - Confirm internal users can access the ADRUM files via the internal URL
   - Test that browser real user monitoring is functioning correctly

---

## Beacon Sending Failures

### What causes beacon sending failures in EUM, and how do I fix them?

Incorrect beacon URLs in the ADRUM agent configuration cause beacon sending failures due to which no end-user experience data gets collected.

#### Configuration Guidance:

1. **Verify ADRUM Files Hosting**
   - Ensure ADRUM JavaScript files are hosted on an accessible internal web server

2. **Check Beacon URL Configuration**
   - Review the ADRUM agent configuration for beacon URLs:
     - `config.beaconUrlHttp`
     - `config.beaconUrlHttps`
   - Confirm these URLs point to the correct EUM server hostname

3. **Update Beacon URLs**
   - Replace incorrect URLs (e.g., `https://appdynamics.pra-rakevet.co.il`) with the valid internal hostname (e.g., `https://rkv-appdynamics1`)

4. **Save Configuration and Retest**
   - Save the updated configuration
   - Test beacon sending function to confirm beacons are received

5. **Troubleshoot Further if Needed**
   - Capture browser HAR files and console logs if issues persist
   - Verify network connectivity and DNS resolution for the EUM server hostname

### How do I verify and troubleshoot EUM beacon URL issues?

- Confirm EUM collector accessibility via browser or curl commands
- Check DNS resolution on client machines
- Collect browser HAR files and console logs if beacon sending fails
- Review EUM pod logs for beacon processing errors

---

## JVM Configuration

### How do I configure JVM options for the OVA Controller since there is no domain.xml file?

In OVA deployments, the traditional `domain.xml` file used for JVM option configuration is absent. JVM options must be configured via Helm chart modifications.

#### Configuration Steps:

1. **Understand Configuration Change Location**
   - In newer AppDynamics versions with Jetty appserver, JVM options are not set in `domain.xml`

2. **Modify JVM Options via Helm Chart (Preferred for OVA)**
   - Backup the Helm chart file: `~/appd-charts/charts/controller/templates/controller-configmap.yml`
   - Edit the file to add the JVM option:
     ```
     -Dmaximum.bts.per.application=NEW_LIMIT
     ```
     under the JVM options list

3. **Start the Controller using AppDynamics CLI**
   ```bash
   appdcli start appd <profile>
   ```

4. **Verify the Change**
   - Confirm the new Business Transaction limit is applied after restart

---

## Certificate and Cluster Setup

### What are the key steps for certificate and cluster setup in OVA deployments?

Proper hostname, IP synchronization, and certificate installation are essential for cluster node communication and secure operation in OVA deployments.

#### Steps:

1. **Prepare DNS and Certificate**
   - Create a DNS alias resolving to all cluster node IPs
   - Procure a certificate with the common hostname in CN or SAN including all FQDNs of cluster nodes

2. **Update Hostname and IP on Nodes**
   - Stop the first VM node
   - Update hostname and IP via vSphere client
   - Power on the VM to sync details

3. **Copy Certificate and Key**
   - Copy private key and signed certificate to `/var/appd/config` on the first node as `ingress.key` and `ingress.crt` in PEM format with correct permissions

4. **Modify Configuration File**
   - Edit `/var/appd/config/globals.yaml.gotmpl`:
     - Update `dnsDomain` with the common domain name
     - Update `dnsNames` with cluster node domain names
     - Comment out internal IP lines if necessary
     - Set `defaultCert: false` under ingress

5. **Restart Services**
   - Stop services:
     ```bash
     appdcli stop aiops
     appdcli stop appd
     appdcli stop operators
     ```
   - Start services:
     ```bash
     appdcli start appd medium
     appdcli start aiops medium
     ```

6. **Verify**
   - Confirm services pick up the custom certificate and function correctly

---

## Application Instrumentation

### How do I handle instrumentation and agent configuration for applications like SAP Java and .NET Reporting Services?

Advanced instrumentation techniques are required for certain applications like SAP Java and .NET reporting services behind load balancers.

#### Guidance:

1. **Enable Debug Logging**
   - Modify `log4j2.xml` in Java Agent to enable debug level logging

2. **Analyze Logs**
   - Review Java Agent logs for class loading errors and reflection exceptions

3. **Modify Java Agent Configuration**
   - Edit `app-agent-config.xml` to add excludes for problematic SAP classes in the `<excludes>` section

4. **Add JVM Startup Parameters**
   - Add OSGi boot delegation parameters:
     ```
     -Dorg.osgi.framework.bootdelegation=com.singularity.*
     -Dorg.osgi.framework.bootdelegation=com.singularity.*,com.sap.*
     ```

5. **Update Java Security Policy**
   - Modify `java.policy` file to grant necessary permissions:
     ```java
     grant codeBase "file:/-" {
       permission javax.security.AllPermission;
       permission javax.management.MBeanPermission "", "";
     };
     ```

6. **Restart Application**
   - Restart SAPPI application with updated Java Agent configuration

7. **Verify Functionality**
   - Confirm interface pages load and function without errors

---

## Pod Crashes in Virtual Appliance

### What are typical causes of pod crashes in the Cisco AppDynamics On-Premises Virtual Appliance, and how can these issues be addressed?

Pod crashes in the Virtual Appliance often stem from a combination of configuration, resource, and certificate management issues within the Kubernetes environment.

#### Common Causes:

- **Certificate and Secrets Mismanagement**: Retaining old or mismatched Kubernetes secrets and certificates after uninstallations or upgrades can cause communication failures and serialization/deserialization errors in Kafka streams, leading to pod crashes

- **Resource Constraints**: Insufficient memory allocation in the deployment profile can cause Out-Of-Memory (OOM) events, resulting in pod restarts and instability

- **Improper Service Restart Sequence**: Restarting services in an incorrect order may cause failures in dependent components, especially when certificates or configurations have changed

- **Namespace and Persistent Volume Residue**: Leftover Kubernetes namespaces, Persistent Volume Claims (PVCs), and Persistent Volumes (PVs) from previous deployments can interfere with clean reinstallation and cause unexpected pod behavior

#### Recommended Resolution Steps:

1. **Clean Up Kubernetes Environment**
   - Delete stale namespaces, secrets, PVCs, and PVs to ensure a clean state before reinstallation

2. **Regenerate and Update Certificates**
   - Generate fresh certificates and update Kubernetes secrets accordingly to avoid communication and serialization errors

3. **Adjust Resource Profiles**
   - Review and increase memory limits in the deployment profile configuration (e.g., `medium.yaml`) to prevent OOM kills, especially for memory-intensive pods

4. **Follow Correct Service Restart Procedures**
   - Stop and start services in the recommended sequence using CLI commands to ensure proper initialization and communication

5. **Monitor Pod and Service Status**
   - Use Kubernetes commands to verify pod health and monitor application-specific statuses (e.g., Anomaly Detection model states) to confirm successful recovery

6. **Handle Seccomp Warnings**
   - Recognize that some security-related warnings (e.g., seccomp) may be benign and do not necessarily indicate functional issues

---

## Troubleshoot Virtual Appliance Issues

Follow the troubleshooting steps if you face the following issues during or after installing Splunk AppDynamics On-Premises Virtual Appliance.

### Update DNS Configuration for an Air-Gapped Environment

An air-gapped environment is a network setup that does not have Internet connectivity. In this environment, DNS may become unreachable. To fix this issue, configure a DNS server that can be reached.

> **Note**: Following are example details used to explain how to update DNS configuration: The IP addresses 10.0.0.1, 10.0.0.2, and 10.0.0.3 belong to the Virtual Appliance cluster. The 10.0.0.5 is the IP address of the standalone Controller. `standalone-controller` is the DNS of the standalone on-premises Controller.

#### Steps:

1. **Update the `/etc/hosts` file**
   
   This ensures the `appdcli ping` command reaches the DNS server.
   
   **Example:**
   ```
   # AppDOS Cluster Hosts
   10.0.0.1 example-air-gap-va-node-3 10.0.0.1.nip.io
   10.0.0.2 example-air-gap-va-node-1 10.0.0.2.nip.io
   10.0.0.3 example-air-gap-va-node-2 10.0.0.3.nip.io
   ```

2. **Edit the coredns configmap file to add the external Controller IP address**
   ```bash
   kubectl -n kube-system edit configmap/coredns
   ```
   
   In the coredns configmap file, add the following entry in the `.:53` section:
   
   **Example:**
   ```
   hosts {
     10.0.0.5 standalone-controller
     fallthrough
   }
   ```

3. **Edit the `globals.yaml.gotmpl` file**
   
   Update `dnsDomain` and `dbHost` with the DNS of the standalone on-premises Controller.

---

### Update CIDR of the Pod

If you require to change the default CIDR of the pod, you can update the CIDR to the available subnet range.

#### Steps:

1. **Log in to the node console** using the appduser credentials

2. **Stop the services:**
   ```bash
   appdcli stop appd
   appdcli stop operators
   ```

3. **Back up the following files:**
   - `/var/snap/microk8s/current/args/cni-network/cni.yaml`
   - `/var/snap/microk8s/current/args/kube-proxy`

4. **Update the `cni.yaml` file**

   | Existing Content | Updated Content |
   |-----------------|-----------------|
   | `- name: CALICO_IPV4POOL_CIDR`<br>`value: "10.1.0.0/16"` | `- name: CALICO_IPV4POOL_CIDR`<br>`value: "10.<Number>.0.0/16"`<br>(Provide the available subnet range. For example: 10.2.0.0/16) |

5. **Update the `kube-proxy` file**

   | Existing Content | Updated Content |
   |-----------------|-----------------|
   | `--cluster-cidr=10.1.0.0/16` | `--cluster-cidr=10.X.0.0/16`<br>(Provide the available subnet range. For example: 10.2.0.0/16) |

6. **Run the following command to apply the changes:**
   ```bash
   microk8s kubectl apply -f /var/snap/microk8s/current/args/cni-network/cni.yaml
   ```

7. **Restart the nodes:**
   ```bash
   microk8s stop
   microk8s start
   ```

8. **Verify the node status:**
   ```bash
   microk8s status
   ```

9. **Delete the ippool and calico pod:**
   ```bash
   microk8s kubectl delete ippools default-ipv4-ippool
   microk8s kubectl rollout restart daemonset/calico-node -n kube-system
   ```

---

### Error Appears for `appdctl show boot`

When you run the `appdctl show boot` command, the following error appears if any background processes are pending:

```
Error: Get "https://127.0.0.1/boot": Socket /var/run/appd-os.sock not found. Bootstrapping maybe in progress
Please check appd-os service status with following command:
systemctl status appd-os
```

**Resolution**: Run the command after a few minutes.

---

### Insufficient Permissions to Access Microk8s

Sometimes this error appears if the terminal was inactive between installation steps. If you face this error, re-login to the terminal.

---

### Restore the MySQL Service

If a Virtual Machine restarts in the cluster, the MySQL service does not automatically start. To start the MySQL services, complete the following:

1. **Run the following command:**
   ```bash
   appdcli run mysql_restore
   ```

2. **Verify the pod status:**
   ```bash
   appdcli run infra_inspect
   ```
   
   **Expected Output:**
   ```
   NAME                              READY   STATUS    RESTARTS   AGE
   appd-mysqlsh-0                    1/1     Running   0          4m33s
   appd-mysql-0                      2/2     Running   0          4m33s
   appd-mysql-1                      2/2     Running   0          4m33s
   appd-mysql-2                      2/2     Running   0          4m33s
   appd-mysql-router-9f8bc6784-g7zx7 1/1     Running   0          5s
   appd-mysql-router-9f8bc6784-fhjnp 1/1     Running   0          5s
   appd-mysql-router-9f8bc6784-wrcwk 1/1     Running   0          5s
   ```

---

### EUM Health is Failing After Multiple Retries

Run the following commands to restart the Events and EUM pod:

```bash
kubectl delete pod events-ss-0 -n cisco-events
kubectl delete pod eum-ss-0 -n cisco-eum
```

---

### IOException Error Occurs in the Controller UI

In the Controller UI, when you select **Alert and Respond > Anomaly Detection**, the following IOException error occurs:

```
IOException while calling 'https://pi.appdynamics.com/pi-rca/alarms/modelSensitivityType/getAll?accountId=2&controllerId=onprem&startRecordNo=0&appId=7&recordCount=1'
```

#### Workaround:

1. Get the list of pods in the controller namespace:
   ```bash
   kubectl get pods -n cisco-controller
   ```

2. Delete the Controller pod:
   ```bash
   kubectl delete pod <Controller-Pod-Name> -n cisco-controller
   ```

---

## SecureApp Vulnerability Feed Not Downloading

### Why is SecureApp showing "Failed" status in appdcli ping even though I have internet connectivity?

**Affected Versions**: AppDynamics Virtual Appliance 25.4.0.2016  
**Component**: Cisco Secure Application (SecureApp)  
**Severity**: Known Limitation

In AppDynamics Virtual Appliance version 25.4.0, SecureApp is installed and functional for runtime security monitoring, but the vulnerability feed downloader component is not deployed. This causes the `vuln` pod to continuously retry looking for vulnerability feed files (snyk.gz, maven feeds, etc.) in the PostgreSQL database, resulting in a "Failed" status when running `appdcli ping`.

#### Symptoms:

- `appdcli ping` shows SecureApp status as "Failed"
- All 15 SecureApp pods are in "Running" state
- The `vuln` pod has high restart count (80+)
- Vuln pod logs show repeated messages: `"on-prem feed not available, retrying later"`
- Feed credentials exist in `onprem-feed-sys` secret but are not being used

#### Root Cause:

**The automatic feed download feature requires configuration after installation.** While the Virtual Appliance includes the feed download capability, it must be explicitly configured using portal credentials. Without this configuration, the `vuln` pod cannot download vulnerability feeds and will continuously retry looking for feed data in the PostgreSQL database.

**Technical Details:**
- Feed downloader: ✅ Available via `appdcli run secureapp` commands
- Feed bucket configured: `dev-pdx-ci-feed` (AppDynamics S3 bucket)
- Feed paths expected: `golden/snyk/snyk-new-feed.json.gz`, `golden/maven/*`, `golden/osv/*`
- Credentials present: OAuth URL, Portal Server, Key Server URL, OPFDL Key (90 bytes)
- **Missing configuration**: Portal user credentials not set via CLI

#### Verification Commands:

```bash
# Check SecureApp status
ssh appduser@<vm-ip>
appdcli ping | grep SecureApp

# Check vuln pod status
kubectl get pods -n cisco-secureapp | grep vuln

# Check vuln pod logs
kubectl logs <vuln-pod-name> -n cisco-secureapp --tail=30

# Verify feed credentials exist
kubectl get secret onprem-feed-sys -n cisco-secureapp -o jsonpath='{.data.OPFDL_PORTAL_SERVER}' | base64 -d

# Check for feed downloader (will return empty)
kubectl get cronjobs,jobs -n cisco-secureapp | grep -i feed
```

#### Resolution Options:

**Option 1: Configure Automatic Feed Downloads (RECOMMENDED)**

Enable automatic daily vulnerability feed downloads by configuring portal credentials:

**Prerequisites:**
1. Create a non-admin user in your AppDynamics accounts portal (https://accounts.appdynamics.com/)
2. This user will be dedicated for feed downloads only
3. Obtain the username and password for this user

**Configuration Steps:**

```bash
# SSH to any cluster node
ssh appduser@<vm-ip>

# Configure portal credentials for automatic feed downloads
appdcli run secureapp setDownloadPortalCredentials <portal-username>
# You will be prompted for the password

# (Optional) Force immediate feed download instead of waiting for daily schedule
appdcli run secureapp restartFeedProcessing

# Verify feed download started
kubectl logs -n cisco-secureapp <vuln-pod-name> --tail=50 -f

# Check feed status (wait 5-10 minutes for download to complete)
appdcli run secureapp numAgentReports
```

**Expected Results:**
- Feed downloads will begin automatically
- Daily updates will occur automatically
- SecureApp status will change from "Failed" to "Success" after feeds populate
- `appdcli run secureapp health` will show feed entries count

**Option 2: Accept Current State (For Lab/Testing)**

SecureApp provides full runtime security monitoring without vulnerability feeds:
- ✅ Runtime threat detection works
- ✅ Application security monitoring works
- ✅ Security analytics works
- ✅ Attack detection and blocking works
- ❌ Known vulnerability (CVE) scanning unavailable

Most SecureApp features function without feeds. Only vulnerability scanning against known CVE databases is affected.

**Option 3: Manual Feed Upload (For Air-Gapped Environments)**

For completely air-gapped deployments without internet access:

```bash
# Set feed license key (obtain from AppDynamics support)
appdcli run secureapp setFeedKey <path-to-feed-key>

# Upload feed file (obtain from AppDynamics support)
appdcli run secureapp uploadFeed <path-to-feed-file>

# Restart feed processing
appdcli run secureapp restartFeedProcessing
```

#### Troubleshooting Commands:

**Check SecureApp Health:**
```bash
ssh appduser@<vm-ip>
appdcli run secureapp health
```

**Verify Feed Downloads:**
```bash
# Check number of feed entries processed
appdcli run secureapp numAgentReports

# View vuln pod logs
kubectl logs -n cisco-secureapp $(kubectl get pods -n cisco-secureapp -l app=vuln -o name) --tail=50

# Check feed processing status
appdcli ping | grep SecureApp
```

**Test SecureApp API:**
```bash
# Check API responsiveness
appdcli run secureapp checkApi

# Verify agent authentication
appdcli run secureapp checkAgentAuth

# Show current configuration
appdcli run secureapp showConfig
```

**Debug Report (For Support Cases):**
```bash
# Generate comprehensive debug report
appdcli run secureapp debugReport
```

#### Configuration Requirements:

1. **Portal User Required**: Must create dedicated user in AppDynamics accounts portal
2. **Manual Configuration**: Automatic downloads require explicit CLI configuration
3. **Internet Access**: Requires connectivity to download.appdynamics.com
4. **Daily Schedule**: Feeds update once per day automatically after configuration
5. **Initial Setup Not Automated**: Installation does not configure feed downloads by default

#### Impact Assessment:

- **Severity**: Low - SecureApp core functionality works
- **Affected Feature**: Vulnerability scanning only
- **Workaround Availability**: Use alternative scanning tools (Snyk, Trivy, Grype)
- **User Experience**: "Failed" status in appdcli ping is cosmetic

#### Upgrade Path:

Check with AppDynamics support if vulnerability feed automation is available in:
- Version 25.7.0 or later
- Future patch releases for 25.4.x line

#### Additional Resources:

- SecureApp Documentation: https://docs.appdynamics.com/appd-cloud/en/cisco-secure-application
- Complete troubleshooting guide: `docs/SECUREAPP_FEED_FIX_GUIDE.md`
- Service status report: `docs/TEAM5_SERVICE_STATUS_REPORT.md`

---

### Configuring EUM Endpoints in admin.jsp for Virtual Appliance Deployments

When EUM pods are running but EUM functionality is not working, the Controller Settings in admin.jsp may need to be configured to point to the correct EUM and Events Service endpoints.

#### Quick Configuration (admin.jsp Controller Settings)

For a team deployment (e.g., team5 at `controller-team5.splunkylabs.com`), configure these properties:

1. **Access admin.jsp Console**
   - URL: `https://controller-teamX.splunkylabs.com/controller/admin.jsp`
   - Password: `welcome` (default - unless changed)
   - Note: admin.jsp automatically uses `root` user - no username field

2. **Required Controller Settings Properties**

   Navigate to **Controller Settings** and update these properties:

   | Property | Value | Notes |
   |----------|-------|-------|
   | `eum.beacon.host` | `controller-teamX.splunkylabs.com/eumcollector` | NO https:// |
   | `eum.beacon.https.host` | `controller-teamX.splunkylabs.com/eumcollector` | NO https:// |
   | `eum.cloud.host` | `https://controller-teamX.splunkylabs.com/eumaggregator` | Include https:// |
   | `eum.es.host` | `controller-teamX.splunkylabs.com:443` | hostname:port |
   | `appdynamics.on.premise.event.service.url` | `https://controller-teamX.splunkylabs.com/events` | Include https:// |
   | `eum.mobile.screenshot.host` | `controller-teamX.splunkylabs.com/screenshots` | NO https:// |

   Replace `X` with your team number.

3. **Verification Steps**

   After configuration, verify endpoints are accessible:
   ```bash
   curl -k https://controller-teamX.splunkylabs.com/eumcollector/health
   curl -k https://controller-teamX.splunkylabs.com/eumaggregator/health
   curl -k https://controller-teamX.splunkylabs.com/events/health
   ```

4. **Common Issues**

   - **Settings not applied**: Wait 2-3 minutes or restart Controller pod
   - **Can't access admin.jsp**: Verify password is correct (default: `welcome`)
   - **Beacon URLs incorrect**: Ensure no trailing slashes in URLs
   - **EUM still failing**: Check ingress routing and DNS resolution

**See Also**: `docs/TEAM5_EUM_ADMIN_CONFIG.md` for detailed configuration guide

---

### Issues after Restarting Virtual Appliance Services in Hybrid Deployment

You must regenerate the hybrid configure file and reconfigure the Controller properties in Kubernetes CLI. See the following sections:

- Generate the Hybrid Configuration File
- Configure Controller Properties by Using Kubernetes CLI