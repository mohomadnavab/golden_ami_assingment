#!/bin/bash
set -e
cd terraform
terraform init
terraform validate
terraform apply -auto-approve
echo "Deployment complete"
