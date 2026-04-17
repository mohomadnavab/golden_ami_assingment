#!/bin/bash

set -e

echo "========================================="
echo "🔍 GOLDEN AMI FULL VALIDATION"
echo "========================================="

# -------------------------------
# 1. LIST IMAGE BUILDER IMAGES
# -------------------------------
echo -e "\n✅ Checking Image Builder Images..."
aws imagebuilder list-images \
  --query 'imageVersionList[*].{Name:name,Version:version,Status:state}'

# -------------------------------
# 2. GET LATEST AMI ID
# -------------------------------
echo -e "\n📦 Fetching Latest AMI..."

AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"

# -------------------------------
# 3. CHECK AMI ENCRYPTION
# -------------------------------
echo -e "\n🔐 Checking AMI Encryption..."

aws ec2 describe-images \
  --image-ids $AMI_ID \
  --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted'

# -------------------------------
# 4. VERIFY AMI NAME
# -------------------------------
echo -e "\n📦 Checking AMI Name..."

aws ec2 describe-images \
  --image-ids $AMI_ID \
  --query 'Images[*].Name'

# -------------------------------
# 5. CHECK S3 LOGS
# -------------------------------
echo -e "\n📁 Checking S3 Logs..."

aws s3 ls | grep image-builder-logs || echo "No log bucket found"

# -------------------------------
# 6. LIST PIPELINES
# -------------------------------
echo -e "\n🔄 Checking Image Pipelines..."

aws imagebuilder list-image-pipelines \
  --query 'imagePipelineList[*].{Name:name,Status:status}'

# -------------------------------
# 7. GET DEFAULT SUBNET
# -------------------------------
echo -e "\n🌐 Fetching Subnet..."

SUBNET_ID=$(aws ec2 describe-subnets \
  --query 'Subnets[0].SubnetId' \
  --output text)

echo "Subnet: $SUBNET_ID"

# -------------------------------
# 8. LAUNCH EC2 INSTANCE
# -------------------------------
echo -e "\n🚀 Launching EC2 Instance..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --subnet-id $SUBNET_ID \
  --iam-instance-profile Name=image-builder-profile \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# -------------------------------
# 9. WAIT FOR INSTANCE
# -------------------------------
echo -e "\n⏳ Waiting for instance to be ready..."

aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID

echo "Instance is running!"

# -------------------------------
# 10. WAIT FOR SSM
# -------------------------------
echo -e "\n🔗 Waiting for SSM agent..."

sleep 40

# -------------------------------
# 11. VALIDATE USING SSM
# -------------------------------
echo -e "\n🧪 Running validation commands..."

COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunPowerShellScript" \
  --comment "Validate IIS, .NET, Hardening" \
  --parameters commands='[
    "Get-WindowsFeature Web-Server",
    "dotnet --version",
    "Get-ExecutionPolicy",
    "Get-HotFix"
  ]' \
  --query 'Command.CommandId' \
  --output text)

echo "Command ID: $COMMAND_ID"

sleep 20

echo -e "\n📋 Validation Output:"
aws ssm list-command-invocations \
  --command-id $COMMAND_ID \
  --details

# -------------------------------
# 12. TERMINATE INSTANCE
# -------------------------------
echo -e "\n🧹 Terminating Instance..."

aws ec2 terminate-instances \
  --instance-ids $INSTANCE_ID

echo "Instance terminated."

# -------------------------------
# DONE
# -------------------------------
echo -e "\n========================================="
echo "✅ FULL VALIDATION COMPLETED"
echo "========================================="
