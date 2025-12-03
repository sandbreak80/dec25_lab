#!/usr/bin/env bash

# Enhanced script to download AppDynamics VA image directly to S3
# without needing to download to local machine first

source config.cfg

echo "========================================="
echo "Step 5: Upload AppD VA Image to S3"
echo "========================================="

# Check if DOWNLOAD_URL and AUTH_TOKEN are provided
if [ -z "$APPD_DOWNLOAD_URL" ] || [ -z "$APPD_AUTH_TOKEN" ]; then
    echo ""
    echo "ℹ️  Direct Download Mode Not Configured"
    echo ""
    echo "To download directly from AppDynamics portal to S3:"
    echo "1. Get your download URL and auth token from AppDynamics download portal"
    echo "2. Set these in config.cfg or environment variables:"
    echo "   export APPD_DOWNLOAD_URL='https://download.appdynamics.com/download/prox/download-file/appd-va/...'"
    echo "   export APPD_AUTH_TOKEN='Bearer eyJ...'"
    echo ""
    echo "📁 Falling back to local file upload..."
    
    if [ ! -f "${APPD_RAW_IMAGE}" ]; then
        echo "❌ Error: Local file ${APPD_RAW_IMAGE} not found"
        echo "   Please download the file or configure direct download mode"
        exit 1
    fi
    
    echo "⏳ Uploading local file: ${APPD_RAW_IMAGE}"
    echo "   Target: s3://${IMAGE_IMPORT_BUCKET}/${APPD_RAW_IMAGE}"
    
    aws --profile ${AWS_PROFILE} s3 cp ${APPD_RAW_IMAGE} s3://${IMAGE_IMPORT_BUCKET}/${APPD_RAW_IMAGE}
    
    if [ $? -eq 0 ]; then
        echo "✅ Upload completed successfully"
        aws --profile ${AWS_PROFILE} s3 ls s3://${IMAGE_IMPORT_BUCKET}/${APPD_RAW_IMAGE}
    else
        echo "❌ Upload failed"
        exit 1
    fi
else
    echo ""
    echo "🚀 Direct Download Mode: Streaming from AppDynamics portal to S3"
    echo "   This avoids downloading to your local machine"
    echo ""
    
    # Option 1: Use an EC2 instance as intermediary (recommended for large files)
    echo "⏳ Launching temporary EC2 instance for download..."
    
    # Create a temporary script to run on EC2
    cat > /tmp/download-to-s3.sh << 'EOFSCRIPT'
#!/bin/bash
# This script runs on the temporary EC2 instance
DOWNLOAD_URL="$1"
AUTH_TOKEN="$2"
S3_BUCKET="$3"
IMAGE_NAME="$4"
AWS_REGION="$5"

echo "Starting download from AppDynamics portal..."
curl -L -H "Authorization: ${AUTH_TOKEN}" "${DOWNLOAD_URL}" | \
    aws s3 cp - s3://${S3_BUCKET}/${IMAGE_NAME} --region ${AWS_REGION}

if [ $? -eq 0 ]; then
    echo "✅ Download to S3 completed successfully"
else
    echo "❌ Download failed"
    exit 1
fi
EOFSCRIPT

    # Get default subnet for temporary instance
    SUBNET_ID=$(aws --profile ${AWS_PROFILE} ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${SUBNET_NAME}" \
        --query 'Subnets[0].SubnetId' --output text --region ${AWS_REGION})
    
    # Get Amazon Linux 2023 AMI
    AL2023_AMI=$(aws --profile ${AWS_PROFILE} ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text --region ${AWS_REGION})
    
    echo "   Subnet: ${SUBNET_ID}"
    echo "   AMI: ${AL2023_AMI}"
    echo ""
    
    # Launch EC2 instance with user data
    INSTANCE_ID=$(aws --profile ${AWS_PROFILE} ec2 run-instances \
        --image-id ${AL2023_AMI} \
        --instance-type t3.medium \
        --subnet-id ${SUBNET_ID} \
        --iam-instance-profile Name=vmimport \
        --user-data file:///tmp/download-to-s3.sh \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=appd-va-downloader},{Key=Purpose,Value=Temporary}]" \
        --query 'Instances[0].InstanceId' \
        --output text --region ${AWS_REGION})
    
    echo "✅ Temporary instance launched: ${INSTANCE_ID}"
    echo "⏳ Downloading image (this will take 15-30 minutes for 18GB)..."
    echo ""
    
    # Wait for download to complete by checking S3
    while true; do
        SIZE=$(aws --profile ${AWS_PROFILE} s3 ls s3://${IMAGE_IMPORT_BUCKET}/${APPD_RAW_IMAGE} 2>/dev/null | awk '{print $3}')
        if [ ! -z "$SIZE" ] && [ "$SIZE" -gt 1000000000 ]; then
            echo "✅ File appearing in S3 (${SIZE} bytes so far)..."
        fi
        
        # Check if instance is still running
        STATE=$(aws --profile ${AWS_PROFILE} ec2 describe-instances \
            --instance-ids ${INSTANCE_ID} \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text --region ${AWS_REGION})
        
        if [ "$STATE" != "running" ]; then
            echo "Instance stopped, download should be complete"
            break
        fi
        
        sleep 60
    done
    
    # Terminate the temporary instance
    echo "🧹 Cleaning up temporary instance..."
    aws --profile ${AWS_PROFILE} ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region ${AWS_REGION}
    
    echo ""
    echo "✅ Direct download completed"
fi

echo ""
echo "📋 Final S3 Object:"
aws --profile ${AWS_PROFILE} s3 ls s3://${IMAGE_IMPORT_BUCKET}/${APPD_RAW_IMAGE} --human-readable

echo ""
echo "========================================="
echo "✅ Step 5 Complete"
echo "========================================="
echo "➡️  Next: Run ./06-aws-import-snapshot.sh"
