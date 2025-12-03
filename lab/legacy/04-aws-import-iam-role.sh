#!/usr/bin/env bash

source config.cfg

# Create trust policy for vmimport role
cat > trust-policy.json << EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF

# Create the vmimport role if it doesn't exist
if ! aws --profile ${AWS_PROFILE} iam get-role --role-name vmimport &>/dev/null; then
    echo "Creating vmimport IAM role..."
    aws --profile ${AWS_PROFILE} iam create-role \
        --role-name vmimport \
        --assume-role-policy-document "file://trust-policy.json"
else
    echo "vmimport role already exists."
fi

# Create role policy for S3 and EC2 permissions
cat > disk-image-file-role-policy.json << EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::${IMAGE_IMPORT_BUCKET}",
            "arn:aws:s3:::${IMAGE_IMPORT_BUCKET}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
     }
   ]
}
EOF

# Attach the policy to the role
echo "Attaching policy to vmimport role..."
aws --profile ${AWS_PROFILE} iam put-role-policy \
    --role-name vmimport --policy-name vmimport \
    --policy-document "file://disk-image-file-role-policy.json"

echo "IAM role vmimport configured successfully."
