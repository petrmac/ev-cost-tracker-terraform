#!/bin/bash
set -e

echo "Creating Terraform state bucket for ev-cost-tracker"
echo "==================================================="

# Set the project to pm-tf-states
echo "Setting project context to pm-tf-states..."
gcloud config set project pm-tf-states

# Create the bucket
echo -e "\nCreating bucket 'ev-cost-tracker-tfstate'..."
gsutil mb -p pm-tf-states -l europe-west1 -b on gs://ev-cost-tracker-tfstate || {
    echo "Bucket creation failed. It might already exist."
    echo "Checking if bucket exists..."
    gsutil ls -b gs://ev-cost-tracker-tfstate && echo "✓ Bucket exists"
}

# Enable versioning for state file protection
echo -e "\nEnabling versioning on the bucket..."
gsutil versioning set on gs://ev-cost-tracker-tfstate

# Set lifecycle rule to delete old versions after 30 days (optional)
echo -e "\nSetting lifecycle rules..."
cat > /tmp/lifecycle.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set /tmp/lifecycle.json gs://ev-cost-tracker-tfstate
rm /tmp/lifecycle.json

# Grant your user appropriate permissions
echo -e "\nGranting permissions to current user..."
CURRENT_USER=$(gcloud config get-value account)
gsutil iam ch user:${CURRENT_USER}:objectAdmin gs://ev-cost-tracker-tfstate
gsutil iam ch user:${CURRENT_USER}:legacyBucketReader gs://ev-cost-tracker-tfstate

# Display bucket info
echo -e "\n✓ Bucket setup complete!"
echo -e "\nBucket details:"
gsutil ls -L -b gs://ev-cost-tracker-tfstate

# Switch back to ev-cost-tracker project
echo -e "\nSwitching back to ev-cost-tracker project..."
gcloud config set project ev-cost-tracker

echo -e "\n✓ You can now run 'terraform init' to initialize with the new backend."