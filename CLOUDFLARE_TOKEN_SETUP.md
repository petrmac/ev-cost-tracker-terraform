# Cloudflare API Token Setup Guide

## Step-by-Step Token Creation

1. **Go to** [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)

2. **Click** "Create Token"

3. **Select** "Custom token" (at the bottom of the page)

4. **Configure the token:**

### Token Name
```
EV Tracker Terraform
```

### Permissions (Add these one by one)

Click "Add" and select:

1. **First permission:**
   - Resource: `Zone`
   - Permission 1: `DNS`
   - Permission 2: `Edit`

2. **Second permission (click + Add):**
   - Resource: `Zone`
   - Permission 1: `Zone`
   - Permission 2: `Read`

3. **Third permission (optional but recommended - click + Add):**
   - Resource: `Zone`
   - Permission 1: `Zone Settings`
   - Permission 2: `Edit`

### Zone Resources

In the "Zone Resources" section:
- Select: `Include`
- Select: `Specific zone`
- Add all three domains:
  - `evtracker.cz`
  - `evtracker.online`
  - `evtracker.cloud`

### IP Filtering (Optional)
- Leave blank unless you want to restrict to specific IPs

### TTL
- Start date: Today
- End date: Leave blank (no expiration) or set as needed

## Visual Summary

Your token configuration should look like:

```
Permissions:
✓ Zone - DNS - Edit
✓ Zone - Zone - Read
✓ Zone - Zone Settings - Edit (optional)

Zone Resources:
✓ Include - Specific zone - evtracker.cz
✓ Include - Specific zone - evtracker.online
✓ Include - Specific zone - evtracker.cloud
```

## Click "Continue to summary"

Review the summary and click "Create Token"

## Important!

⚠️ **Copy the token immediately!** You won't be able to see it again.

## Test Your Token

You can test if your token works:

```bash
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer YOUR_TOKEN_HERE" \
     -H "Content-Type:application/json"
```

Should return:
```json
{
  "result": {
    "id": "...",
    "status": "active"
  },
  "success": true
}
```

## Add to Terraform

Add the token to your `secrets.tfvars` or `secrets.auto.tfvars`:

```hcl
cloudflare_api_token = "your-token-here"
```

## If You Don't Want Zone Settings

If you only want basic DNS management, you can skip the "Zone Settings" permission and just use:
- Zone - DNS - Edit
- Zone - Zone - Read

Then make sure `manage_zone_settings = false` in your Terraform configuration (which is the default).

## Common Issues

1. **"Unauthorized to access requested resource"**
   - Your token is missing permissions
   - Double-check all three domains are included in Zone Resources

2. **"Invalid API Token"**
   - Token was copied incorrectly
   - Token has expired
   - Token was revoked

3. **Can't see your domains in the dropdown**
   - Make sure the domains are already added to your Cloudflare account
   - The nameservers must be pointed to Cloudflare