Install Splunk AppDynamics Services in the Standard Deployment
With the standard deployment option, Splunk AppDynamics On-Premises Virtual Appliance installs infrastructure and Splunk AppDynamics Services in your Kubernetes cluster.
Prepare to Install Splunk AppDynamics Services
Log in to one of the node console using the appduser credentials.
Navigate to the following folder:
cd /var/appd/config
Edit the globals.yaml.gotmpl file with the required configuration.
vi globals.yaml.gotmpl
(Optional) Add any custom CA certificates for Controller outbound traffic by configuring appdController.customCaCerts in Customize the Helm File.
(Optional) Enable the self-monitoring for the Controller.
enableClusterAgent: true
(Optional) Edit the /var/appd/config/secrets.yaml file to update usernames and passwords of the Splunk AppDynamics Services.
vi /var/appd/config/secrets.yaml
Note: When you install the Splunk AppDynamics service, the secrets.yaml file becomes encrypted.
See Edit the secrets.yaml.encrypted file.
Save the following script to the console of your primary virtual appliance node as dnsinfo.sh and run it. Follow the instructions in its output:
Note: If you are running this script for the first time, copy the code for plain YAML. If you are running this script after installing the services, copy the code for encrypted YAML.
Plain YAML
Encrypted YAML
#!/bin/bash
set -euo pipefail
TENANT=$(helm secrets decrypt /var/appd/config/secrets.yaml  .hybrid.controller.tenantAccountName)
DNS_DOMAIN=$(grep -v "^ *\t* *{{" /var/appd/config/globals.yaml.gotmpl | yq -r '.dnsDomain')

echo Verify the Virtual Appliance tenant should be \'${TENANT}\'
echo Verify the Virtual Appliance domain name should be \'${DNS_DOMAIN}\'

for server_name in "${TENANT}.auth.${DNS_DOMAIN}" "${TENANT}-tnt-authn.${DNS_DOMAIN}"; do
  if ! getent hosts "${server_name}" > /dev/null; then
    echo "Please double-check that DNS can resolve '${server_name}' as the VA ingress IP"
  fi
done 
Sample output:
Verify the Virtual Appliance tenant should be 'customer1'
Verify the Virtual Appliance domain name should be 'va.mycompany.com'
Please double-check that DNS can resolve 'customer1.auth.va.mycompany.com' as the VA ingress IP
Please double-check that DNS can resolve 'customer1-tnt-authn.va.mycompany.com' as the VA ingress IP
Configure a custom ingress certificate (by default, the ingress controller installs a fully-configured self-signed certificate). The custom ingress certificate needs certain SANs added to it. See ingress in Customize the Helm File for instructions on how to configure the custom ingress certificate and key.
Copy the license files as the license.lic file to the node in the following location.
cd /var/appd/config
This license is used to provision Splunk AppDynamics Services. If you do not have the license file at this time, you can apply the license and provision the services later using appdcli.
Note: For End User Monitoring, if you are using the Infrastructure-based Licensing model, make sure to specify EUM account and license key in the Administration Console. See Access the Administration Console. Follow the steps to add EUM account and license key:
From Account Settings, select the Controller account that have EUM licenses and click Edit.
Enter the EUM license key and the EUM account name in the EUM License Key and the EUM Account Name fields.
Click Save.
Create a Three-Node Cluster
Log in to the primary node console.
Verify the boot status of each node of the cluster:
appdctl show boot
Note:
Ensure that the status of services on each node shows Success. If not, restart the affected virtual machine. If the issue persists after the restart, redeploy the virtual machine.
Ensure that you configure the same time on all the cluster nodes.
Run the following command in the primary node and specify the IP address of the peer nodes:
cd /home/appduser
appdctl cluster init <Node-2-IP> <Node-3-IP>
Run the following command to verify the node status:
appdctl show cluster
microk8s status
Ensure that the output displays the Running status as true for the nodes that are part of the cluster.
Sample Output

 NODE           | ROLE  | RUNNING 
----------------+-------+---------
 10.0.0.1:19001 | voter | true    
 10.0.0.2:19001 | voter | true    
 10.0.0.3:19001 | voter | true 
Note: You must re-login to the terminal if the following error is displayed:
Insufficient Permissions to Access Microk8s 
Install Services in the Cluster
Log in to the cluster node console.
Run the command to install services:
appdcli start appd [Profile]
Small Profile
Medium Profile
appdcli start appd small
This command installs the Splunk AppDynamics services. We recommend that you specify the same VA profile that you selected to create a virtual machine. See, Sizing Requirements.
Sample Output

NAME               CHART                     VERSION   DURATION
cert-manager-ext   charts/cert-manager-ext   0.0.1           0s
ingress-nginx      charts/ingress-nginx      4.8.3           1s
redis-ext          charts/redis-ext          0.0.1           1s
ingress            charts/ingress            0.0.1           2s
cluster            charts/cluster            0.0.1           2s
reflector          charts/reflector          7.1.216         2s
monitoring-ext     charts/monitoring-ext     0.0.1           2s
minio-ext          charts/minio-ext          0.0.1           2s
eum                charts/eum                0.0.1           2s
fluent-bit         charts/fluent-bit         0.39.0          2s
postgres           charts/postgres           0.0.1           2s
mysql              charts/mysql              0.0.1           3s
redis              charts/redis              18.1.6          3s
controller         charts/controller         0.0.1           3s
events             charts/events             0.0.1           4s
cluster-agent      charts/cluster-agent      1.16.37         4s
kafka              charts/kafka              0.0.1           6s
minio              charts/minio              5.0.14         47s
Verify the status of the installed pods and service endpoints:
Pods: kubectl get pods --all-namespaces
Service endpoints: appdcli ping
+---------------------+---------+
|  Service Endpoint   | Status  |
+=====================+=========+
| Controller          | Success |
+---------------------+---------+
| Events              | Success |
+---------------------+---------+
| EUM Collector       | Success |
+---------------------+---------+
| EUM Aggregator      | Success |
+---------------------+---------+
| EUM Screenshot      | Success |
+---------------------+---------+
| Synthetic Shepherd  | Success |
+---------------------+---------+
| Synthetic Scheduler | Success |
+---------------------+---------+
| Synthetic Feeder    | Success |
+---------------------+---------+
| AD/RCA Services     | Failed  |
+---------------------+---------+
Note:
When a Virtual Machine restarts, the MySQL service may not automatically restore. To troubleshoot this issue, see Restore the MySQL Service.
If the EUM pod Fails even after multiple retries, see EUM Health Fails After Multiple Retries.
If you want to use custom actions with your Virtual Appliance, you must follow the instructions in Build Custom Actions for Virtual Appliance.
By default, Virtual Appliance installs the Cluster Agent. This agent helps you monitor nodes, CPU, memory and storage. For more information, see View Container Details.
Install the Anomaly Detection Services in the Cluster
Log in to the cluster node console.
Run the command to install services:
Small Profile
Medium Profile
appdcli start aiops small
Verify the status of the installed pods and service endpoints:
Pods: kubectl get pods -n cisco-aiops
Service endpoints: appdcli ping
The status of the Anomaly Detection service appears as Success.

See Anomaly Detection.
Note: Sometimes, IOException error occurs when you access Anomaly Detection in the Controller UI. See Troubleshoot Virtual Appliance Issues.
Install OpenTelemetry Service
Ensure the following conditions are met:
OpenTelemetry Collector version 0.36 to 0.101.
The maximum size limit for each request sent to the trace ingestion endpoint is 10 MB.
Go to the Controller DNS to verify that the Controller is active.
Log in to the cluster node console.
Run the following command and wait until the Controller service status is Success.
appdcli ping
Sample Output:
+---------------------+---------------+
|  Service Endpoint   |    Status     |
+=====================+===============+
| Controller          | Success       |
+---------------------+---------------+
| Events              | Success       |
+---------------------+---------------+
| EUM Collector       | Success       |
+---------------------+---------------+
| EUM Aggregator      | Success       |
+---------------------+---------------+
| EUM Screenshot      | Success       |
+---------------------+---------------+
| Synthetic Shepherd  | Success       |
+---------------------+---------------+
| Synthetic Scheduler | Success       |
+---------------------+---------------+
| Synthetic Feeder    | Success       |
+---------------------+---------------+
| OTIS                | Not Installed |
+---------------------+---------------+

Run the following command to install the OpenTelemetry™ service:
Small Profile
Medium Profile
Large Profile
appdcli start otis small
This command installs the OpenTelemetry™ service in the cisco-otis namespace.
Verify the status of the installed pods and service endpoints:
Pods: kubectl get pods -n cisco-otis
Service endpoints: appdcli ping
The status of the OpenTelemetry™ service appears as Success.
+---------------------+---------------+
|  Service Endpoint   |    Status     |
+=====================+===============+
| Controller          | Success       |
+---------------------+---------------+
| Events              | Success       |
+---------------------+---------------+
| EUM Collector       | Success       |
+---------------------+---------------+
| EUM Aggregator      | Success       |
+---------------------+---------------+
| EUM Screenshot      | Success       |
+---------------------+---------------+
| Synthetic Shepherd  | Success       |
+---------------------+---------------+
| Synthetic Scheduler | Success       |
+---------------------+---------------+
| Synthetic Feeder    | Success       |
+---------------------+---------------+
| OTIS                | Success       |
+---------------------+---------------+
You can also access the endpoint URL to verify the installation. See Verify the Service Endpoints Paths.
Configure Splunk AppDynamics for OpenTelemetry.
(Optional) Install Secure Application
See Install Secure Application.
Install ATD Services
Ensure that the AuthN service is installed along with Splunk AppDynamics services.
kubectl get pods -nauthn
Follow the steps to install Automatic Transaction Diagnostics service in the Virtual Appliance:
Log in to the cluster node console.
Run the command to install services:
Demo Profile
Small Profile
Medium Profile
Large Profile
appdcli start atd demo
Verify the status of installed pods and service endpoints.
kubectl get pods -ncisco-atd
You can also access the endpoint URL to verify the installation. See Verify the Service Endpoints Paths.
For more information about ATD, see Automated Transaction Diagnostics Workflow.

Install Universal Integration Layer Service
To integrate Splunk AppDynamics Self Hosted Virtual Appliance with Splunk Enterprise, you must install the Universal Integration Layer (UIL) service in the cluster:
Log in to the cluster node console.
Run the command to install the service:
Small Profile
Medium Profile
Large Profile
appdcli start uil small
Verify the status of the installed pods and service endpoints:
Pods: kubectl get pods -n cisco-uilThe status of the universal integration layer pod must be displayed as Running.uil_pods
Service endpoints: appdcli ping
The status of the UIL service should be displayed as Success.

uil_service_endpoints
You can also access the endpoint URL to verify the installation. See Verify the Service Endpoints Paths.
To continue with the integration, see Integrate Splunk AppDynamics Self Hosted Virtual Appliance with Splunk Enterprise.
Apply Licenses to Splunk AppDynamics Services
Use appdcli to apply licenses after installing Splunk AppDynamics Services.
Log in to the cluster node console.
Copy the license files as the license.lic file to the node in the following location.
cd /var/appd/config
Run the following commands to apply licenses:
Controller
End User Monitoring
Update the Controller license.
appdcli license controller license.lic
For more information, see Virtual Appliance CLI.
Verify the Service Endpoints Paths
Log in to the Controller UI by accessing https://<DNS-Name>or<Cluster-Node-IP>/.
The Ingress controller checks the URL of an incoming request and redirects to the respective Splunk AppDynamics Service.

Service Endpoint	Installation Path
Controller	https://<ingress>/controller
Events	https://<ingress>/events
https://<Node-IP>:32105/events

End User Monitoring	Aggregator	https://<ingress>/eumaggregator
Screenshots	https://<ingress>/screenshots
Collector	https://<ingress>/eumcollector
Synthetic	Shepherd	https://<ingress>/synthetic/shepherd
Scheduler	https://<ingress>/synthetic/scheduler
Feeder	https://<ingress>/synthetic/feeder
Note: By default, the Controller UI username is set to admin and the password is set to welcome.
Download Splunk AppDynamics Agents
Download and install the AppDynamics agents from Download Portal.
For more information, see:

Install App Server Agents
End User Monitoring

