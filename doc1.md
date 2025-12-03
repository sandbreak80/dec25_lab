Deploy and Configure Virtual Machines in AWS
You can deploy Virtual Appliance in Amazon EC2 by using an Amazon Machine Image (AMI).
Note: This document contains links to AWS documentation. Splunk AppDynamics makes no representation as to the accuracy of AWS documentation because Amazon controls its own documentation.
Before You Begin
Download the AMI image from the Virtual Appliance tab in the Downloads portal, and verify that the file has execute permissions.
Prepare the AWS Environment
To deploy virtual machines in AWS, you require the following AWS resources. You can create or configure the AWS resources using the AWS portal or AWS CLI.
Important: To use AWS CLI, you require reference scripts. Download these script from the Splunk AppDynamics GitHub repository. We recommend that you run the scripts in the given order. Before you run these scripts, in config.cfg, ensure to update or verify the configuration details such as tags, deployment configuration, and IP addresses. For more information about AWS CLI, see AWS CLI Documentation.To create virtual machines in AWS, you must use the m5a.4xlarge instance type. See M5a instances.
Order	AWS Resources	Description	Reference Scripts
1	AWS Profile	An AWS profile helps you identify the business resources in the AWS environment. You can create or use the existing profile. See Profiles.	01-aws-create-profile.sh
2	Virtual Private Network (VPC)	
Amazon VPC provides an isolated virtual network for the Virtual Appliance where you can install the Splunk AppDynamics services. You can create or use the existing VPC. See What is Amazon VPC?
02-aws-add-vpc.sh
3	S3 Bucket	An S3 bucket is required to store an AMI and create an image. See Creating a Bucket.	03-aws-create-image-bucket.sh
4	IAM Role	You can manage permissions for your AWS resources by using an IAM role. See IAM roles.	04-aws-import-iam-role.sh
5	Image	Upload the Splunk AppDynamics image in the S3 bucket that generates the AMI for Virtual Appliance. See Uploading objects.	05-aws-upload-image.sh
6	Snapshot	Snapshots help in using the AMI that you have uploaded to S3 bucket. Complete the following steps to obtain an AMI ID:
Import the snapshot.
Register the snapshot.
Note: The AMI ID is used to create virtual machines.
06-aws-import-snapshot.sh
07-aws-register-snapshot.sh

Create Virtual Machines
Splunk AppDynamics On-Premises Virtual Appliance requires three virtual machines. Create three virtual machines in the AWS portal using the AMI ID.
Note: Ensure that the virtual machines follow the supported sizing requirements. See Sizing Requirements.
For more information about creating virtual machines, see run-instances.

Alternatively, you can run the 08-aws-create-vms.sh file by using AWS CLI to create three virtual machines.

Bootstrap the AWS Instance
After you deploy the virtual machines, you must bootstrap the AWS instance so virtual machines can use the instance details.
Log in to console of the node using the appduser credentials.
Note: By default, the node password is set to changeme.
Run the following command to bootstrap the AWS instance.
sudo appdctl host init
Specify the following AWS instance details:
Hostname
Host IP address (CIDR format)
Default gateway IP address
DNS server IP address
Verify the Configuration of the Virtual Machines
After you create three virtual machines, verify the configuration is correct on each node and the server is ready to install the Splunk AppDynamics Services.
Log in to one of the node consoles using the appduser credentials.
Run the appdctl show boot command on each node of the cluster.
Sample Output
NAME              | STATUS    | ERROR 
-------------------+-----------+-------
 firewall-setup    | Succeeded | --    
 hostname          | Succeeded | --    
 netplan           | Succeeded | --    
 ssh-setup         | Succeeded | --    
 storage-setup     | Succeeded | --    
 cert-setup        | Succeeded | --    
 enable-time-sync  | Succeeded | --    
 microk8s-setup    | Succeeded | --    
 cloud-init-config | Succeeded | --  
Note: An error might appear for the appdctl show boot command. Run the command again after few minutes to resolve this error. See Troubleshoot: Error Appears for appdctl show boot.
Next Steps
Review and update the parameters in the Helm file. For more information about the Helm file parameters, see Customize the Helm File.
Install Splunk AppDynamics Services.
