#!/bin/bash
set -euxo pipefail

# Update packages
dnf update -y

# Install Docker
dnf install -y docker

# Enable and start Docker
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# Allow ec2-user to run Docker
usermod -aG docker ec2-user

# Verify AWS CLI
aws --version || true

# Marker file
echo "bootstrap-complete" > /home/ec2-user/bootstrap.txt
chown ec2-user:ec2-user /home/ec2-user/bootstrap.txt
