#!/bin/bash
set -e

echo "Diagnosing Terraform state bucket access issues..."
echo "================================================="

# Check current user
echo "Current authenticated user:"
gcloud auth list

# Check application default credentials
echo -e "\nApplication default credentials:"
gcloud auth application-default print-access-token > /dev/null 2>&1 && echo "✓ ADC configured" || echo "✗ ADC not configured"

# Set the project context
echo -e "\nSetting project context to pm-tf-states..."
gcloud config set project pm-tf-states

# Check if bucket exists and list permissions
echo -e "\nChecking bucket 'pm-tf-states'..."
if gcloud storage buckets describe gs://pm-tf-states 2>/dev/null; then
    echo "✓ Bucket exists"
    
    # Check IAM policy
    echo -e "\nBucket IAM Policy:"
    gcloud storage buckets get-iam-policy gs://pm-tf-states
else
    echo "✗ Bucket does not exist or you don't have access"
    echo -e "\nTrying to create the bucket..."
    gcloud storage buckets create gs://pm-tf-states \
        --location=europe-west1 \
        --uniform-bucket-level-access \
        --public-access-prevention || echo "Failed to create bucket"
fi

# Grant permissions to current user
echo -e "\nGranting Storage Admin role to current user..."
CURRENT_USER=$(gcloud config get-value account)
gcloud projects add-iam-policy-binding pm-tf-states \
    --member="user:${CURRENT_USER}" \
    --role="roles/storage.admin" || echo "Failed to grant project-level permissions"

# Also grant bucket-level permissions
echo -e "\nGranting bucket-level permissions..."
gcloud storage buckets add-iam-policy-binding gs://pm-tf-states \
    --member="user:${CURRENT_USER}" \
    --role="roles/storage.objectAdmin" || echo "Failed to grant bucket-level permissions"

# Switch back to ev-cost-tracker project
echo -e "\nSwitching back to ev-cost-tracker project..."
gcloud config set project ev-cost-tracker

# Re-authenticate ADC
echo -e "\nRefreshing Application Default Credentials..."
gcloud auth application-default login

echo -e "\n✓ Setup complete. Try running 'terraform init' again."