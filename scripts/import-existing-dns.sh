#!/bin/bash
set -e

echo "Importing existing Cloudflare DNS records..."
echo "==========================================="

CLOUDFLARE_API_TOKEN='ZXFihC51za1cbPuS0wbjE8SX8I7CCzY3bO15e4-q'

# Function to get zone ID
get_zone_id() {
    domain=$1
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
         -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
         -H "Content-Type: application/json" | \
    jq -r '.result[0].id'
}

# Function to get record ID
get_record_id() {
    zone_id=$1
    record_name=$2
    record_type=$3
    
    if [ "$record_name" == "@" ]; then
        # For root domain
        name_param=$(echo "$4" | cut -d. -f1-2)
    else
        name_param="$record_name.$4"
    fi
    
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$name_param" \
         -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
         -H "Content-Type: application/json" | \
    jq -r '.result[0].id'
}

# Check if token is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Error: CLOUDFLARE_API_TOKEN environment variable not set"
    echo "Please run: export CLOUDFLARE_API_TOKEN='your-token-here'"
    exit 1
fi

# Workspace check
WORKSPACE=$(terraform workspace show)
echo "Current workspace: $WORKSPACE"

# Import existing DNS records
for domain in evtracker.cz evtracker.online evtracker.cloud; do
    echo -e "\nProcessing domain: $domain"
    
    # Get zone ID
    zone_id=$(get_zone_id "$domain")
    if [ -z "$zone_id" ] || [ "$zone_id" == "null" ]; then
        echo "Warning: Could not find zone ID for $domain"
        continue
    fi
    echo "Zone ID: $zone_id"
    
    # Import www record if it exists
    www_id=$(get_record_id "$zone_id" "www" "CNAME" "$domain")
    if [ ! -z "$www_id" ] && [ "$www_id" != "null" ]; then
        echo "Importing www.$domain (ID: $www_id)"
        terraform import -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars "module.cloudflare_dns[0].cloudflare_record.www[\"$domain\"]" "$zone_id/$www_id" || true
    fi
    
    # Import root record if it exists
    root_id=$(get_record_id "$zone_id" "@" "A" "$domain")
    if [ ! -z "$root_id" ] && [ "$root_id" != "null" ]; then
        echo "Importing root $domain (ID: $root_id)"
        terraform import -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars "module.cloudflare_dns[0].cloudflare_record.root[\"$domain\"]" "$zone_id/$root_id" || true
    fi
    
    # Import api record if it exists
    api_id=$(get_record_id "$zone_id" "api" "A" "$domain")
    if [ ! -z "$api_id" ] && [ "$api_id" != "null" ]; then
        echo "Importing api.$domain (ID: $api_id)"
        terraform import -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars "module.cloudflare_dns[0].cloudflare_record.api[\"$domain\"]" "$zone_id/$api_id" || true
    fi
done

echo -e "\n✓ Import complete. Now run 'terraform plan' to see the changes."