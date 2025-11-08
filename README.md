# EV Cost Tracker Terraform

This repository contains the Terraform configuration for deploying the EV Cost Tracker application on Google Cloud Platform (GCP) with Kubernetes (GKE) and Flux for GitOps.

## Architecture

- **GKE Autopilot**: Managed Kubernetes cluster
- **Cloudflare DNS**: Managing multiple domains (evtracker.cz, evtracker.online, evtracker.cloud)
- **Flux CD**: GitOps continuous deployment
- **Cloud Monitoring**: Alerts and observability
- **Static IP**: For ingress load balancer

## Prerequisites

1. **GCP Project**: Using `ev-cost-tracker` project
2. **Google Cloud SDK**: Install and authenticate (`gcloud auth application-default login`)
3. **Terraform**: Version 1.0 or higher
4. **Cloudflare Account**: With your domains added
5. **GitHub Repository**: For GitOps (e.g., `ev-tracker-gitops`)

## Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/yourusername/ev-cost-tracker-terraform.git
cd ev-cost-tracker-terraform
```

### 1a. Run the setup script (optional)

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This will:
- Set your GCP project to `ev-cost-tracker`
- Enable all required Google Cloud APIs
- Generate SSH keys for Flux
- Generate Age key for SOPS (if age is installed)
- Create a secrets.tfvars file from the example

### 2. Create SSH keys for Flux

```bash
ssh-keygen -t ed25519 -f flux-key -N ""
```

Add the public key (`flux-key.pub`) to your GitHub repository as a deploy key with write access.

### 3. Create Age key for SOPS (optional but recommended)

```bash
# Install age if not already installed
brew install age  # macOS
# or download from https://github.com/FiloSottile/age/releases

# Generate key
age-keygen -o age.agekey
```

### 4. Configure secrets

```bash
cp secrets.tfvars.example secrets.tfvars
# Edit secrets.tfvars with your values
```

### 5. Initialize Terraform

```bash
# Initialize with the GCS backend in pm-tf-states project
terraform init
```

Note: The Terraform state is stored in the `pm-tf-states` GCS bucket in the `pm-tf-states` project.

### 6. Create workspaces for environments

```bash
terraform workspace new dev
terraform workspace new prod
```

### 7. Deploy infrastructure

For development:
```bash
terraform workspace select dev
terraform plan -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars
```

For production:
```bash
terraform workspace select prod
terraform plan -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars
```

## Domain Configuration

The Terraform creates DNS records for all three domains:
- `evtracker.cz`
- `evtracker.online`
- `evtracker.cloud`

Make sure your domains are using Cloudflare's nameservers. The nameservers will be output after running Terraform.

### DNS Records Created

For each domain:
- `@` (root) → Points to the static IP
- `www` → CNAME to root domain
- `api` → Points to the static IP
- `dev` (dev environment only) → Points to the static IP
- `dev-api` (dev environment only) → Points to the static IP

## GitOps Repository Structure

Create a GitOps repository (`ev-tracker-gitops`) with the following structure:

```
clusters/
├── ev-tracker-gke-dev/
│   ├── flux-system/
│   │   └── gotk-components.yaml
│   │   └── gotk-sync.yaml
│   ├── infrastructure/
│   │   ├── namespace.yaml
│   │   ├── ingress-nginx/
│   │   └── cert-manager/
│   └── apps/
│       ├── backend/
│       └── frontend/
└── ev-tracker-gke-prod/
    └── ... (similar structure)
```

## Outputs

After deployment, Terraform will output:
- Cluster name and endpoint
- Static IP address
- DNS configuration
- Commands to configure kubectl and check Flux status

## Cost Optimization

The configuration includes several cost-saving measures:
- Log exclusion filters to reduce Cloud Logging costs
- Budget alerts
- GKE Autopilot for efficient resource usage

## Security

- Workload Identity enabled for secure pod authentication
- SOPS encryption for secrets in GitOps
- Cloudflare proxying for DDoS protection
- SSL/TLS enforced with strict mode

## Maintenance

### Update infrastructure
```bash
terraform plan -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars
```

### Check Flux status
```bash
kubectl get all -n flux-system
flux check
```

### View logs
```bash
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
```

## Troubleshooting

### Flux not syncing
1. Check SSH key permissions in GitHub
2. Verify Git repository URL
3. Check Flux logs: `kubectl logs -n flux-system -l app=source-controller`

### DNS not working
1. Verify domains are using Cloudflare nameservers
2. Check Cloudflare API token permissions
3. Verify in Cloudflare dashboard that records were created

### Budget alerts not working
1. Ensure billing account is correctly set
2. Verify the GCP project is linked to the billing account
3. Check email spam folder for alerts

## Clean Up

To destroy all resources:
```bash
terraform destroy -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars
```

⚠️ **Warning**: This will delete all resources including the GKE cluster and any data stored in it.