# OpenTelemetry Service Account Setup

## Overview

This Terraform configuration creates a GCP service account for OpenTelemetry Collector with the necessary permissions to export traces, metrics, and logs to Google Cloud.

## Permissions Granted

- `roles/cloudtrace.agent` - Export traces to Cloud Trace
- `roles/monitoring.metricWriter` - Export metrics to Cloud Monitoring
- `roles/logging.logWriter` - Export logs to Cloud Logging
- `roles/iam.workloadIdentityUser` - Allow Kubernetes SA to impersonate GCP SA

## Usage

### Step 1: Enable in Terraform

In your `terraform.tfvars`:

```hcl
create_otel_collector_sa = true
```

### Step 2: Apply Terraform

```bash
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-terraform
terraform apply
```

### Step 3: Extract the Service Account Key

```bash
# Get the base64-encoded key
terraform output -raw otel_collector_key_base64

# Or save directly to a file
terraform output -raw otel_collector_key_base64 > /tmp/otel-key-base64.txt
```

### Step 4: Create SOPS-Encrypted Secret

```bash
# Base64 value from terraform output
BASE64_KEY=$(terraform output -raw otel_collector_key_base64)

# Create unencrypted YAML
cat > /tmp/google-application-credentials-plain.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: google-application-credentials
  namespace: opentelemetry
type: Opaque
data:
  key.json: ${BASE64_KEY}
EOF

# Encrypt with SOPS (uses .sops.yaml from gitops repo)
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-gitops
sops --encrypt /tmp/google-application-credentials-plain.yaml > \
    infrastructure/opentelemetry/ev-tracker-gke-prod/google-application-credentials.yaml

# Clean up
rm /tmp/google-application-credentials-plain.yaml
```

### Step 5: Commit to GitOps Repo

```bash
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-gitops
git add infrastructure/opentelemetry/ev-tracker-gke-prod/google-application-credentials.yaml
git commit -m "feat: add OpenTelemetry GCP credentials"
git push
```

### Step 6: Flux Deploys Everything

Flux will:
1. Create the `opentelemetry` namespace (if not exists)
2. Decrypt and apply the secret
3. Deploy OpenTelemetry Collector
4. Collector will use the secret to authenticate with GCP

## Verification

```bash
# Check if service account was created
terraform output otel_collector_sa_email

# After Flux deployment, verify secret in cluster
kubectl get secret google-application-credentials -n opentelemetry

# Decode and verify the key
kubectl get secret google-application-credentials -n opentelemetry \
    -o jsonpath='{.data.key\.json}' | base64 -d | jq .

# Check OpenTelemetry Collector logs
kubectl logs -n opentelemetry -l app=opentelemetry-collector
```

## Namespace Creation

The `opentelemetry` namespace will be created by Flux when it applies the Kustomization.
Your gitops repo should have something like:

```yaml
# infrastructure/opentelemetry/ev-tracker-gke-prod/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: opentelemetry
```

## Workload Identity (Alternative to JSON Key)

If you want to use Workload Identity instead of JSON keys (more secure):

1. Create Kubernetes ServiceAccount in the `opentelemetry` namespace
2. Annotate it with: `iam.gke.io/gcp-service-account=otel-collector@PROJECT_ID.iam.gserviceaccount.com`
3. Terraform already configured the Workload Identity binding

This is more secure as it doesn't require storing keys in secrets.

## Security Notes

- The JSON key is base64-encoded in the Kubernetes secret
- SOPS encrypts the secret using Age encryption
- Only users/systems with the Age private key can decrypt
- The Age key should be stored securely (e.g., in Flux secret)

## Troubleshooting

### Permission Denied

If OpenTelemetry Collector can't export to GCP:

```bash
# Verify IAM bindings
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:otel-collector@*"
```

### Invalid Credentials

If credentials are invalid:

```bash
# Regenerate the key
terraform taint 'module.iam.google_service_account_key.otel_collector_key[0]'
terraform apply

# Re-run step 3-5 to update the secret
```
