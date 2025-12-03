# AppDynamics Virtual Appliance - CloudFormation Deployment

This directory contains AWS CloudFormation templates for deploying AppDynamics Virtual Appliance infrastructure and instances.

## Overview

The deployment is split into two CloudFormation stacks:

1. **Infrastructure Stack** (`01-appd-va-infrastructure.yaml`): Creates VPC, networking, S3 bucket, IAM roles
2. **Instances Stack** (`02-appd-va-instances.yaml`): Creates 3 EC2 instances with data volumes

## Why Two Stacks?

The snapshot import and AMI registration process cannot be fully automated in CloudFormation without custom resources. The two-stack approach allows you to:
1. Deploy infrastructure
2. Import and register the AMI (manual or scripted)
3. Deploy EC2 instances using the AMI

## Prerequisites

- AWS CLI configured with appropriate credentials
- AppDynamics VA AMI file downloaded or accessible via URL
- Globally unique S3 bucket name chosen

## Deployment Steps

### Step 1: Deploy Infrastructure

```bash
aws cloudformation create-stack \
  --stack-name appd-va-infrastructure \
  --template-body file://01-appd-va-infrastructure.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=appd-va \
    ParameterKey=AppDImageBucketName,ParameterValue=appd-va-bucket-YOUR-UNIQUE-NAME \
    ParameterKey=AppDImageFileName,ParameterValue=appd_va_25.4.0.2016.ami \
    ParameterKey=ResourceOwner,ParameterValue=yourname@company.com \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

**Wait for stack to complete:**
```bash
aws cloudformation wait stack-create-complete \
  --stack-name appd-va-infrastructure \
  --region us-west-2
```

**Get outputs:**
```bash
aws cloudformation describe-stacks \
  --stack-name appd-va-infrastructure \
  --query 'Stacks[0].Outputs' \
  --region us-west-2
```

### Step 2: Upload and Import AMI

#### Option A: Upload from Local Machine

If you already downloaded the AMI:

```bash
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name appd-va-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`ImageBucketName`].OutputValue' \
  --output text --region us-west-2)

aws s3 cp appd_va_25.4.0.2016.ami s3://${BUCKET_NAME}/ --region us-west-2
```

#### Option B: Direct Download to S3 (Recommended)

Use an EC2 instance to download directly from AppDynamics portal to S3:

```bash
# Launch a temporary t3.medium instance
# Use the subnet from the infrastructure stack
SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name appd-va-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`SubnetId`].OutputValue' \
  --output text --region us-west-2)

# Get Amazon Linux 2023 AMI
AL2023_AMI=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text --region us-west-2)

# Create download script
cat > /tmp/download-script.sh << 'EOF'
#!/bin/bash
# Replace with your actual download URL and token
DOWNLOAD_URL="https://download.appdynamics.com/download/prox/download-file/appd-va/25.4.0.2016/appd_va_25.4.0.2016.ami"
AUTH_TOKEN="Bearer YOUR_TOKEN_HERE"
BUCKET_NAME="YOUR_BUCKET_NAME"

curl -L -H "Authorization: ${AUTH_TOKEN}" "${DOWNLOAD_URL}" | \
  aws s3 cp - s3://${BUCKET_NAME}/appd_va_25.4.0.2016.ami --region us-west-2

# Signal completion
aws ec2 stop-instances --instance-ids $(ec2-metadata --instance-id | cut -d" " -f2) --region us-west-2
EOF

# Launch instance with download script
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AL2023_AMI} \
  --instance-type t3.medium \
  --subnet-id ${SUBNET_ID} \
  --iam-instance-profile Name=appd-va-ec2-profile \
  --user-data file:///tmp/download-script.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=appd-downloader}]" \
  --query 'Instances[0].InstanceId' \
  --output text --region us-west-2)

echo "Download instance launched: ${INSTANCE_ID}"
echo "Monitor progress with: aws ec2 describe-instances --instance-ids ${INSTANCE_ID}"
```

#### Import Snapshot

```bash
# Start import
IMPORT_TASK_ID=$(aws ec2 import-snapshot \
  --disk-container Description=appd-va-25.4.0.2016,Format=RAW,Url=s3://${BUCKET_NAME}/appd_va_25.4.0.2016.ami \
  --query "ImportTaskId" \
  --output text \
  --region us-west-2)

echo "Import task started: ${IMPORT_TASK_ID}"

# Monitor progress (takes 15-30 minutes)
watch -n 30 "aws ec2 describe-import-snapshot-tasks \
  --import-task-ids ${IMPORT_TASK_ID} \
  --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.{Status:Status,Progress:Progress,SnapshotId:SnapshotId}' \
  --region us-west-2"
```

#### Register AMI

```bash
# Get snapshot ID (after import completes)
SNAPSHOT_ID=$(aws ec2 describe-import-snapshot-tasks \
  --import-task-ids ${IMPORT_TASK_ID} \
  --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' \
  --output text \
  --region us-west-2)

# Register AMI
AMI_ID=$(aws ec2 register-image \
  --name appd-va-25.4.0.2016-$(date +%Y%m%d) \
  --description "AppDynamics Virtual Appliance 25.4.0.2016" \
  --architecture x86_64 \
  --root-device-name /dev/sda1 \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=${SNAPSHOT_ID},VolumeSize=200,VolumeType=gp3}" \
  --ena-support \
  --virtualization-type hvm \
  --query 'ImageId' \
  --output text \
  --region us-west-2)

echo "AMI registered: ${AMI_ID}"
```

### Step 3: Deploy EC2 Instances

Create a parameters file:

```bash
cat > instance-parameters.json << EOF
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "appd-va"
  },
  {
    "ParameterKey": "AMIId",
    "ParameterValue": "${AMI_ID}"
  },
  {
    "ParameterKey": "VMInstanceType",
    "ParameterValue": "m5a.4xlarge"
  },
  {
    "ParameterKey": "VMOSDiskSize",
    "ParameterValue": "200"
  },
  {
    "ParameterKey": "VMDataDiskSize",
    "ParameterValue": "500"
  },
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "YOUR_KEY_PAIR_NAME"
  },
  {
    "ParameterKey": "ResourceOwner",
    "ParameterValue": "yourname@company.com"
  }
]
EOF
```

Deploy the instances:

```bash
aws cloudformation create-stack \
  --stack-name appd-va-instances \
  --template-body file://02-appd-va-instances.yaml \
  --parameters file://instance-parameters.json \
  --region us-west-2

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name appd-va-instances \
  --region us-west-2

# Get instance IPs
aws cloudformation describe-stacks \
  --stack-name appd-va-instances \
  --query 'Stacks[0].Outputs' \
  --region us-west-2
```

### Step 4: Bootstrap Instances

SSH into each instance and bootstrap:

```bash
# Get instance IPs from stack outputs
INSTANCE1_IP=$(aws cloudformation describe-stacks \
  --stack-name appd-va-instances \
  --query 'Stacks[0].Outputs[?OutputKey==`Instance1PublicIP`].OutputValue' \
  --output text --region us-west-2)

# SSH to instance 1
ssh appduser@${INSTANCE1_IP}

# On each instance, run:
sudo appdctl host init

# Provide network configuration:
# - Hostname
# - IP address (CIDR format)
# - Default gateway
# - DNS server

# Verify bootstrap
appdctl show boot
```

### Step 5: Create Cluster

On the primary node (Instance 1):

```bash
# Get private IPs for nodes 2 and 3
INSTANCE2_IP=$(aws cloudformation describe-stacks \
  --stack-name appd-va-instances \
  --query 'Stacks[0].Outputs[?OutputKey==`Instance2PrivateIP`].OutputValue' \
  --output text --region us-west-2)

INSTANCE3_IP=$(aws cloudformation describe-stacks \
  --stack-name appd-va-instances \
  --query 'Stacks[0].Outputs[?OutputKey==`Instance3PrivateIP`].OutputValue' \
  --output text --region us-west-2)

# SSH to primary node and run:
appdctl cluster init ${INSTANCE2_IP} ${INSTANCE3_IP}

# Verify cluster
appdctl show cluster
microk8s status
```

### Step 6: Install AppDynamics Services

On the primary node:

```bash
# Configure globals
cd /var/appd/config
sudo vi globals.yaml.gotmpl

# Configure secrets
sudo vi secrets.yaml

# Copy license
sudo cp /path/to/license.lic /var/appd/config/license.lic

# Install services
appdcli start appd small

# Verify installation
kubectl get pods --all-namespaces
appdcli ping
```

## Cleanup

To remove all resources:

```bash
# Delete instances stack
aws cloudformation delete-stack \
  --stack-name appd-va-instances \
  --region us-west-2

aws cloudformation wait stack-delete-complete \
  --stack-name appd-va-instances \
  --region us-west-2

# Delete AMI
aws ec2 deregister-image --image-id ${AMI_ID} --region us-west-2

# Delete snapshot
aws ec2 delete-snapshot --snapshot-id ${SNAPSHOT_ID} --region us-west-2

# Empty S3 bucket
aws s3 rm s3://${BUCKET_NAME} --recursive --region us-west-2

# Delete infrastructure stack
aws cloudformation delete-stack \
  --stack-name appd-va-infrastructure \
  --region us-west-2

aws cloudformation wait stack-delete-complete \
  --stack-name appd-va-infrastructure \
  --region us-west-2
```

## Advantages of CloudFormation Deployment

1. **Infrastructure as Code**: Version controlled, repeatable deployments
2. **Automated Cleanup**: Easy to tear down and rebuild
3. **Consistent Configuration**: Reduces human error
4. **Stack Outputs**: Easy reference to resource IDs and IPs
5. **Change Sets**: Preview changes before applying
6. **Rollback**: Automatic rollback on failure

## Cost Considerations

- **EC2 Instances**: 3x m5a.4xlarge = ~$1.50/hour ($1,080/month)
- **EBS Storage**: 3x 200GB (OS) + 3x 500GB (Data) = 2,100 GB = ~$210/month
- **S3 Storage**: ~$5/month for image storage
- **Data Transfer**: Varies based on usage

**Total estimated cost: ~$1,300/month** (us-west-2 pricing)

## Troubleshooting

### Stack Creation Fails

```bash
# Check events
aws cloudformation describe-stack-events \
  --stack-name appd-va-infrastructure \
  --region us-west-2 \
  --max-items 20
```

### Import Snapshot Fails

- Verify IAM role has correct permissions
- Check S3 bucket access
- Ensure image format is RAW
- Allow 15-30 minutes for large files

### Instances Won't Start

- Check AMI ID is correct
- Verify subnet has available IPs
- Check security group rules
- Review CloudWatch logs

## Support

For issues with:
- **Scripts**: Check IMPROVEMENTS_ROADMAP.md
- **AppDynamics**: Refer to official documentation
- **AWS Resources**: AWS Support or documentation
