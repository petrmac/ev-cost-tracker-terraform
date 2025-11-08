#!/bin/bash
set -e

echo "EV Cost Tracker Terraform Setup"
echo "==============================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Set the project
echo "Setting GCP project to ev-cost-tracker..."
gcloud config set project ev-cost-tracker

# Enable required APIs
echo "Enabling required Google Cloud APIs..."
gcloud services enable compute.googleapis.com \
    container.googleapis.com \
    dns.googleapis.com \
    certificatemanager.googleapis.com \
    servicenetworking.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    containerregistry.googleapis.com \
    artifactregistry.googleapis.com \
    sqladmin.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    cloudtrace.googleapis.com \
    storage.googleapis.com \
    bigquery.googleapis.com \
    billingbudgets.googleapis.com

# Create Application Default Credentials
echo "Setting up Application Default Credentials..."
gcloud auth application-default login

# Generate SSH key for Flux if it doesn't exist
if [ ! -f "flux-key" ]; then
    echo "Generating SSH key for Flux..."
    ssh-keygen -t ed25519 -f flux-key -N "" -C "flux@ev-tracker"
    echo "SSH key generated. Add flux-key.pub to your GitHub repository as a deploy key with write access."
else
    echo "Flux SSH key already exists."
fi

# Generate Age key for SOPS if it doesn't exist
if [ ! -f "age.agekey" ]; then
    echo "Generating Age key for SOPS..."
    if command -v age-keygen &> /dev/null; then
        age-keygen -o age.agekey
        echo "Age key generated. The public key is:"
        grep "public key:" age.agekey
    else
        echo "Warning: age-keygen not found. Install it with: brew install age (macOS) or from https://github.com/FiloSottile/age/releases"
    fi
else
    echo "Age key already exists."
fi

# Create secrets.tfvars from example if it doesn't exist
if [ ! -f "secrets.tfvars" ]; then
    echo "Creating secrets.tfvars from example..."
    cp secrets.tfvars.example secrets.tfvars
    echo "Please edit secrets.tfvars with your actual values."
else
    echo "secrets.tfvars already exists."
fi

echo ""
echo "Setup complete! Next steps:"
echo "1. Edit secrets.tfvars with your Cloudflare API token and alert email"
echo "2. Add flux-key.pub to your GitHub repository (ev-tracker-gitops) as a deploy key"
echo "3. Run 'terraform init' to initialize Terraform"
echo "4. Run 'make plan-dev' to see what will be created"