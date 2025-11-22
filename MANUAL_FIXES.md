# Manual Fixes Required

## 1. Delete Existing WWW Records in Cloudflare

### Option A: Via Cloudflare Dashboard (Easiest)
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. For each domain (evtracker.cz, evtracker.online, evtracker.cloud):
   - Click on the domain
   - Go to DNS
   - Find the "www" CNAME record
   - Click "Edit" then "Delete"

### Option B: Via API
```bash
# Set your token
export CLOUDFLARE_API_TOKEN="your-token-here"

# Delete www records
for domain in evtracker.cz evtracker.online evtracker.cloud; do
    echo "Processing $domain..."
    
    # Get zone ID
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    # Get www record ID
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=www.$domain" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    # Delete the record
    if [ "$RECORD_ID" != "null" ] && [ ! -z "$RECORD_ID" ]; then
        echo "Deleting www.$domain (ID: $RECORD_ID)"
        curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json"
        echo ""
    fi
done
```

## 2. Fix GKE Issue

### Option A: Skip GKE for now
Apply without GKE:
```bash
terraform apply -target=module.cloudflare_dns -var-file=environments/prod/terraform.tfvars
```

### Option B: Remove maintenance policy
Edit `modules/gke/main.tf` and comment out the maintenance_policy block:
```hcl
  # Comment out this entire block
  # maintenance_policy {
  #   recurring_window {
  #     start_time = "2024-01-07T03:00:00Z"
  #     end_time   = "2024-01-07T07:00:00Z"
  #     recurrence = "FREQ=WEEKLY;BYDAY=SU"
  #   }
  # }
```

## 3. Apply in Stages

After fixing the above issues:

```bash
# 1. First apply just the networking
terraform apply -target=module.networking -var-file=environments/prod/terraform.tfvars

# 2. Then apply DNS
terraform apply -target=module.cloudflare_dns -var-file=environments/prod/terraform.tfvars

# 3. Finally, apply everything else
terraform apply -var-file=environments/prod/terraform.tfvars
```

## 4. Alternative: Start Fresh

If you want to start completely fresh:

```bash
# Remove all state
terraform state list | grep -v "google_project_service" | xargs -n1 terraform state rm

# Then apply
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Current Status

✅ Successfully created:
- Root domain A records (evtracker.cz, evtracker.online, evtracker.cloud)
- API subdomain records (api.evtracker.cz, etc.)

❌ Failed:
- WWW CNAME records (already exist)
- GKE cluster (maintenance window issue)

## Next Steps

1. Delete the www records manually in Cloudflare
2. Fix or skip GKE for now
3. Re-run terraform apply