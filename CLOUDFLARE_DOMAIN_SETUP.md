# Moving Domains from Forpsi to Cloudflare

## Overview
You'll keep your domains registered at Forpsi but use Cloudflare for DNS management. This involves changing the nameservers at Forpsi to point to Cloudflare.

## Step-by-Step Process

### 1. Add Domains to Cloudflare

1. **Sign up/Log in** to [Cloudflare](https://dash.cloudflare.com/)

2. **Add each domain** to Cloudflare:
   - Click "Add a Site" 
   - Enter `evtracker.cz`
   - Select the Free plan (sufficient for this project)
   - Repeat for `evtracker.online` and `evtracker.cloud`

3. **Cloudflare will scan** existing DNS records (if any) and import them

4. **Note the Cloudflare nameservers** - You'll see something like:
   ```
   ns1.cloudflare.com
   ns2.cloudflare.com
   ```
   (The actual nameserver names will be specific to your account)

### 2. Update Nameservers at Forpsi

1. **Log in** to your [Forpsi admin panel](https://admin.forpsi.com/)

2. **Navigate to** Domain Management (Správa domén)

3. **For each domain** (evtracker.cz, evtracker.online, evtracker.cloud):
   - Find the domain in your list
   - Click on DNS settings or Nameservers (DNS servery)
   - Change from Forpsi nameservers to Cloudflare nameservers
   - Enter the two Cloudflare nameservers you noted earlier
   - Save the changes

### 3. Wait for DNS Propagation

- DNS changes can take 24-48 hours to propagate globally
- Usually it's much faster (within a few hours)
- You can check status in Cloudflare dashboard - it will show when the domain is "Active"

### 4. Create Cloudflare API Token

Once your domains are active on Cloudflare:

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use "Custom token" template with these permissions:
   - **Zone - DNS - Edit** (for all zones or specific zones)
   - **Zone - Zone - Read** (for all zones or specific zones)
   - Include your three domains in the zone resources
4. Create token and save it securely

### 5. Update Terraform Configuration

Add your Cloudflare API token to `secrets.tfvars`:
```hcl
cloudflare_api_token = "your-token-here"
```

## Terraform Will Then Create

Once the domains are active on Cloudflare and you run Terraform, it will automatically create:

- A records pointing to your GKE load balancer IP
- CNAME records for www subdomains
- SSL/TLS settings (automatic HTTPS)
- Any environment-specific subdomains

## Important Notes

- **Don't transfer the domain registration** - Keep domains at Forpsi, just use Cloudflare for DNS
- **Free Cloudflare plan** includes DDoS protection, SSL, and CDN
- **Existing email/MX records** - Make sure to add any existing email records in Cloudflare
- **Verification** - Cloudflare will email you to verify domain ownership

## Checking Domain Status

You can verify the nameserver change using:
```bash
# Check current nameservers
dig +short NS evtracker.cz
dig +short NS evtracker.online
dig +short NS evtracker.cloud

# Or use whois
whois evtracker.cz | grep -i "name server"
```

## Troubleshooting

If domains don't activate in Cloudflare after 48 hours:
1. Double-check nameservers are correctly set at Forpsi
2. Ensure no typos in nameserver names
3. Contact Forpsi support if nameserver changes aren't saving
4. Check Cloudflare dashboard for any error messages

## Next Steps

Once all domains show as "Active" in Cloudflare:
1. Create the API token
2. Update `secrets.tfvars` with the token
3. Run `terraform plan` to see what DNS records will be created
4. Run `terraform apply` to create the DNS configuration