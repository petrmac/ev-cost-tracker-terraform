#!/bin/bash
set -e

echo "Unlocking Terraform state..."
echo "==========================="

# First, try to remove the lock file
echo "Removing state lock file..."
gsutil rm gs://ev-cost-tracker-tfstate/terraform/default.tflock || {
    echo "Lock file not found or already removed"
}

# Also check for workspace-specific locks
WORKSPACE=$(terraform workspace show)
if [ "$WORKSPACE" != "default" ]; then
    echo "Checking for $WORKSPACE workspace lock..."
    gsutil rm "gs://ev-cost-tracker-tfstate/terraform/${WORKSPACE}.tflock" || {
        echo "No workspace-specific lock found"
    }
fi

echo "✓ State unlocked. You can now run terraform commands."

# Alternative: Force unlock with lock ID
echo -e "\nIf the lock persists, you can force unlock with:"
echo "terraform force-unlock 1762619503320827"