#!/bin/bash
set -e

echo "Removing Cloudflare zone settings from state..."
echo "=============================================="

# List all zone settings resources in state
echo "Current zone settings in state:"
terraform state list | grep "cloudflare_zone_settings_override" || echo "No zone settings found"

# Remove each zone settings resource
for domain in evtracker.cz evtracker.online evtracker.cloud; do
    resource="module.cloudflare_dns[0].cloudflare_zone_settings_override.ssl_settings[\"$domain\"]"
    echo "Removing $resource..."
    terraform state rm "$resource" 2>/dev/null || echo "Resource not found: $resource"
done

echo "✓ Zone settings removed from state"
echo ""
echo "Now you can run terraform apply without zone settings issues."