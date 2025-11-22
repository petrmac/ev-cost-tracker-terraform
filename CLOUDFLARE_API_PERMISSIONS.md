# Cloudflare API Token Permissions

## Current Issues and Solutions

### 1. DNS Records (Working)
The basic DNS record creation is working with:
- **Zone:DNS:Edit**
- **Zone:Zone:Read**

### 2. Zone Settings (Requires Additional Permissions)
The zone settings override requires:
- **Zone:Settings:Edit**

If you don't have this permission or don't want to grant it, the zone settings are disabled by default.

### 3. Page Rules (Optional)
If you want to enable page rules:
- **Zone:Page Rules:Edit**

## Creating a Properly Scoped Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Choose "Custom token"
4. Configure permissions:

### Minimum Required Permissions:
- **Zone - DNS - Edit** (for creating DNS records)
- **Zone - Zone - Read** (for reading zone information)

### Optional Permissions:
- **Zone - Zone Settings - Edit** (for SSL/TLS settings)
- **Zone - Page Rules - Edit** (for caching rules)

### Zone Resources:
- Include specific zones: evtracker.cz, evtracker.online, evtracker.cloud

## Terraform Variable Configuration

If you have full permissions, you can enable optional features:
```hcl
# In your terraform.tfvars or when running apply:
manage_zone_settings = true
enable_page_rules = true
```

## SSL/TLS Settings

Even without managing zone settings through Terraform, Cloudflare provides good defaults:
- SSL/TLS encryption mode: Flexible (default)
- Always Use HTTPS: Can be enabled in Cloudflare dashboard
- Minimum TLS Version: 1.0 (default)

You can manually configure these in the Cloudflare dashboard under:
SSL/TLS > Overview > SSL/TLS encryption mode > Full (strict)

## Troubleshooting

If you see "Unauthorized to access requested resource (9109)":
- Your API token is missing required permissions
- Either add the permissions or disable the feature in Terraform

If you see "ttl must be set to 1 when proxied is true":
- This has been fixed in the latest version
- TTL is now automatically set to 1 for proxied records