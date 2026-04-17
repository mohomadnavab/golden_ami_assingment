#!/bin/bash
set -e

AMI_ID=$(aws ec2 describe-images   --owners self   --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId'   --output text)

SUBNET=$(aws ec2 describe-subnets --query 'Subnets[0].SubnetId' --output text)

aws ec2 run-instances   --image-id $AMI_ID   --instance-type t3.micro   --subnet-id $SUBNET   --associate-public-ip-address

echo "Instance launched with AMI: $AMI_ID"
