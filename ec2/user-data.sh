#!/bin/bash
# EC2 user-data: bootstrap Docker + AWS CLI on Amazon Linux 2023
# Paste this into the "User data" field when launching the instance.
set -euxo pipefail

dnf update -y
dnf install -y docker

systemctl enable --now docker
usermod -aG docker ec2-user

# AWS CLI v2 is preinstalled on Amazon Linux 2023. Verify:
aws --version || true

# Optional: pre-create a marker so you can confirm user-data ran
echo "bootstrap-complete" > /home/ec2-user/bootstrap.txt
