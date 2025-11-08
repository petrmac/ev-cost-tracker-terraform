#!/bin/bash

echo "Preparing secrets for Terraform..."
echo "================================="

# Check if flux keys exist
if [ ! -f "flux-key" ] || [ ! -f "flux-key.pub" ]; then
    echo "Error: flux-key or flux-key.pub not found!"
    echo "Generate them with: ssh-keygen -t ed25519 -f flux-key -N ''"
    exit 1
fi

# Create a secrets.tfvars file (auto-loaded by Terraform)
cat > secrets.tfvars <<EOF
# Auto-generated secrets file - DO NOT COMMIT
# Generated on $(date)

# Cloudflare API token
cloudflare_api_token = "your-cloudflare-token-here"

# Alert email
alert_email = "your-email@example.com"

# GitHub SSH keys for Flux
git_ssh_key = <<-EOT
$(cat flux-key)
EOT

git_ssh_key_pub = "$(cat flux-key.pub)"

EOF

# Add age key if it exists
if [ -f "age.agekey" ]; then
    cat >> secrets.tfvars <<EOF
# Age key for SOPS
age_key = <<-EOT
$(cat age.agekey)
EOT
EOF
else
    cat >> secrets.tfvars <<EOF
# Age key for SOPS (not found - using empty string)
age_key = ""
EOF
fi

echo "✓ Created secrets.auto.tfvars"
echo ""
echo "Next steps:"
echo "1. Edit secrets.auto.tfvars and add your Cloudflare API token and email"
echo "2. Make sure secrets.auto.tfvars is in .gitignore"
echo "3. Run: terraform plan -var-file=environments/prod/terraform.tfvars"