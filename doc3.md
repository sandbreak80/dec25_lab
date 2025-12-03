appd-virtual-appliance
AppD Virtual Appliance (VA) Deployment Utils

VA AWS deployment reference scripts
Set of reference deployment scripts (deploy/aws) are provided to deploy VA on AWS. Scripts use AWS CLI. Scripts are numbered in the order to be executed.

Typical deployment steps below. Steps can be skipped if existing resources (e.g existing VPC) are used.

Configure config.cfg with custom config as needed.
Create an AWS profile (01-aws-create-profile.sh). Skip if a profile exists
Create VPC (02-aws-add-vpc.sh). Skip if an existing VPC is used
Create S3 bucket to upload va raw disk image (03-aws-create-image-bucket.sh). Skip if an existing S3 bucket is used.
Create IAM role to provide access to S3 bucket (04-aws-import-iam-role.sh).
Upload va raw disk image (05-aws-upload-image.sh) to S3 bucket.
Import a disk image to EBS snapshot (06-aws-import-snapshot.sh).
Register snapshot as AMI (07-aws-register-snapshot.sh).
Now proceed to create the VMs using the AMI (08-aws-create-vms.sh)
Typical upgrade steps below. Upgrade involves reusing the network interface and data disk of existing VMs to a new VM.

Capture the current running VM details (01-aws-get-vm-details.sh). Reads the network interface identifier and data disk details.
Terminate the current VMs (02-aws-terminate-vms.sh).
Validate if VMs are terminate (03-aws-get-vm-status.sh).
Create new VMs and attach an existing network interface and data disk. (04-aws-create-vms.sh)
VA Azure deployment reference scripts
Set of reference deployment scripts (deploy/vhd) are provided to deploy VA on Azure. Scripts use Azure CLI. Scripts are numbered in the order to be executed.

Configure config.cfg with custom config as needed.
Create an Azure resource group. (01-azure-create-rg.sh). Skip if an existing resource group is being used.
Create a network security group. (02-azure-create-nsg.sh). Skip if an existing network security group is being used.
Create a virtual network. (03-azure-vnet.sh). Skip if an existing virtual network is being used.
Create a storage account (04-azure-storage-account.sh). Skip if an existing storage account is used.
Upload the va image and create a disk image (05-azure-create-disk.sh).
Create a image gallery (06-azure-image-gallery.sh). Skip if an existing image gallery is used.
Create the image definition (07-azure-shared-image-def.sh).
Create the image version (08-azure-shared-image-version.sh).
Now proceed to create the VMs using the image definition (09-azure-vm-create.sh).
Typical upgrade steps below. Upgrade involves reusing the network interface and data disk of existing VMs to a new VM.

Capture the current running VM details (01-azure-get-vm-details.sh). Reads the network interface identifier and data disk details.
Power off the VMs (02-azure-power-off-vm.sh).
Associate a dummy NIC to enable dis-association of the primary NIC (03-azure-associate-dummy-nic.sh)
Dis-associate NIC and data disk (04-azure-disassociate-nic-and-data-disk.sh)
Delete the VMs (05-azure-delete-vms.sh).
Create new VMs and attach an existing network interface and data disk. (06-azure-create-vms.sh)
VA KVM deployment reference scripts
Set of reference deployment scripts (deploy/kvm) are provided to deploy VA on KVM/Libvirt Hypervisors. Scripts make use of virsh CLI. Please refer to the README.md in deploy/kvm for further guidance.

Configure config.cfg with custom config as needed
Run deploy/kvm/01-prepare-hypervisor.sh script on each node to prepare hypervisor
Copy the AppD OnPrem Virtual Appliance KVM QCOW2 image to one of the nodes in the cluster.
Run deploy/kvm/run-cluster script providing the KVM QCOW2 Appliance Image which handles ssh virsh connections between nodes, configures libvirt storage, exchanges generated ssh keys, creates template images on each node, defines VMs on each peer node in the cluster and launches the VM providing static network configuration information.
Typical upgrade steps below. Upgrade involves resuing the network interface and data disk of existing VMs. The VMs will be stop and the OS disk is replaced. Upon restarting, VMs will need complete appdctl cluster init to rebuild cluster.

Run the deploy/kvm/upgrade-cluster script passing the newer AppD Virtual Appliance QCOW2 image and optionally supply at cluster config.cfg file
The upgrade script will for each VM in the cluster:
Create a new OS disk from the template image provided
Stop the VM
Delete the old OS disk
Attach new OS disk
Start VM
Update ~/.ssh/known_hosts to remove old host ssh keys
