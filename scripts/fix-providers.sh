#!/bin/bash
set -e

echo "Fixing Terraform provider checksums..."
echo "====================================="

# Remove the lock file
echo "Removing existing .terraform.lock.hcl..."
rm -f .terraform.lock.hcl

# Remove the .terraform directory
echo "Cleaning .terraform directory..."
rm -rf .terraform

# Generate a new lock file for the current platform
echo "Generating new lock file..."
terraform providers lock \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=linux_amd64 \
  -platform=linux_arm64

echo "✓ Lock file regenerated for multiple platforms"

# Now run init
echo -e "\nRunning terraform init..."
terraform init

echo -e "\n✓ Terraform providers fixed and initialized!"