# Cloudflare Pages Setup Guide

**Account ID**: `17ddb4934927c0b3c238ff5345b4cf71`

## Prerequisites

### 1. Update Cloudflare API Token Permissions

Your existing `CLOUDFLARE_API_TOKEN` in `secrets.tfvars` needs additional permissions:

Go to: https://dash.cloudflare.com/profile/api-tokens

Edit your existing token to include:
- ✅ **Zone:DNS:Edit** (already have)
- ✅ **Account:Cloudflare Pages:Edit** (add this)

## Deployment Steps

### Step 1: Enable Cloudflare Pages in Terraform

Edit `secrets.tfvars`:

```hcl
use_cloudflare_pages  = true
cloudflare_account_id = "17ddb4934927c0b3c238ff5345b4cf71"
```

### Step 2: Apply Terraform (Pages Only - Test First)

```bash
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-terraform

# Preview changes
terraform plan -target=module.cloudflare_pages

# Apply Pages module only
terraform apply -target=module.cloudflare_pages
```

This will:
- Create Cloudflare Pages project: `ev-cost-tracker-frontend`
- Connect to GitHub repository
- Set up automatic deployments
- Configure environment variables (VITE_API_BASE_URL)

### Step 3: Authorize GitHub Integration

After running Terraform, you'll need to authorize Cloudflare's GitHub integration:

1. Go to: https://dash.cloudflare.com/17ddb4934927c0b3c238ff5345b4cf71/pages
2. Find project: `ev-cost-tracker-frontend`
3. Click "Set up builds and deployments"
4. Authorize Cloudflare GitHub App
5. Select repository: `petrmac/ev-cost-tracker`

**Note**: Terraform creates the project but you must authorize GitHub manually (one-time setup).

### Step 4: Verify Preview Deployment

1. Wait for initial build (check: https://dash.cloudflare.com/17ddb4934927c0b3c238ff5345b4cf71/pages)
2. Test preview URL: `https://ev-cost-tracker-frontend.pages.dev`
3. Verify:
   - ✅ Frontend loads
   - ✅ OAuth login works (all 4 providers)
   - ✅ API calls work
   - ✅ Referral tracking works

### Step 5: Switch DNS to Cloudflare Pages

When preview tests pass:

```bash
# Apply full configuration (switches DNS)
terraform apply
```

This will:
- Change root domains (evtracker.cz, .online, .cloud) from A → CNAME to Pages
- Create www → root 301 redirects
- Keep api.* pointing to GKE (unchanged)

### Step 6: Update GitOps (Remove Frontend from K8s)

The ingress configuration is already updated in `ev-cost-tracker-gitops`. Now remove the frontend deployment:

```bash
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-gitops

# Check current state
git status

# The ingress changes should already be committed
# If not, commit them first:
git add infrastructure/ingress/gke-ingress.yaml
git commit -m "feat: update ingress for Cloudflare Pages (api.* only)"

# Now remove frontend from production cluster
# Edit: clusters/ev-tracker-gke-prod/kustomization.yaml
# Remove or comment out: - ../../apps/api/frontend

git add clusters/ev-tracker-gke-prod/kustomization.yaml
git commit -m "chore: remove frontend from k8s (now on Cloudflare Pages)"
git push
```

Flux will automatically:
- Remove frontend deployment
- Remove frontend service
- Free up resources: 50m CPU, 128Mi RAM

## How Deployments Work

Once set up:

1. **Push to main** → Cloudflare automatically builds and deploys
2. **Pull Requests** → Cloudflare creates preview deployments
   - Example: `https://pr-123-ev-cost-tracker-frontend.pages.dev`
3. **Build time**: ~30 seconds (vs 5-10 minutes on GKE)
4. **No GitHub Actions needed** - Cloudflare handles everything

## Rollback Plan

If anything goes wrong:

```bash
cd /Users/petrmacek/git-mirrors/ev-cost-tracker-terraform

# Revert DNS to GKE
# Edit secrets.tfvars:
use_cloudflare_pages = false

# Apply DNS changes only
terraform apply -target=module.cloudflare_dns
```

DNS propagation: 2-5 minutes.

## OAuth Provider Updates Required

Before going live, add these redirect URIs (keep old ones during migration):

### Google OAuth Console
https://console.cloud.google.com/apis/credentials

Add redirect URIs:
```
https://api.evtracker.cz/login/oauth2/code/google
https://api.evtracker.online/login/oauth2/code/google
https://api.evtracker.cloud/login/oauth2/code/google
```

### GitHub OAuth App
https://github.com/settings/developers

Add callback URLs:
```
https://api.evtracker.cz/login/oauth2/code/github
https://api.evtracker.online/login/oauth2/code/github
https://api.evtracker.cloud/login/oauth2/code/github
```

### Apple Sign In
https://developer.apple.com/account/resources/identifiers

1. Add domains: `evtracker.cz`, `evtracker.online`, `evtracker.cloud`
2. **Download** domain association file for each domain
3. Replace placeholder at: `frontend/public/.well-known/apple-developer-domain-association.txt`
4. Add return URLs:
```
https://api.evtracker.cz/login/oauth2/code/apple
https://api.evtracker.online/login/oauth2/code/apple
https://api.evtracker.cloud/login/oauth2/code/apple
```

### Facebook Login
https://developers.facebook.com/apps

Add redirect URIs:
```
https://api.evtracker.cz/login/oauth2/code/facebook
https://api.evtracker.online/login/oauth2/code/facebook
https://api.evtracker.cloud/login/oauth2/code/facebook
```

**Keep old redirect URIs** for 7-30 days during migration, then remove them.

## Monitoring

After deployment:

1. **Cloudflare Analytics**: https://dash.cloudflare.com/17ddb4934927c0b3c238ff5345b4cf71/pages/view/ev-cost-tracker-frontend
2. **Build logs**: Same URL → Deployments tab
3. **GKE resource usage**: Should drop by 50m CPU, 128Mi RAM

## Cost Savings

- **Before**: $12-28/month (GKE frontend pod + egress bandwidth)
- **After**: $0/month (Cloudflare Pages free tier)
- **Bandwidth**: Unlimited (Cloudflare CDN)
- **Savings**: ~$144-336/year

## Support

For detailed migration steps, see:
- `/Users/petrmacek/git-mirrors/ev-cost-tracker/CLOUDFLARE_PAGES_MIGRATION.md`
