terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Create Cloudflare Pages project
resource "cloudflare_pages_project" "frontend" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = var.production_branch

  # Build configuration
  build_config {
    build_command       = "pnpm install && pnpm run build"
    destination_dir     = "dist"
    root_dir            = "frontend"
  }

  # Environment variables
  deployment_configs {
    production {
      environment_variables = {
        VITE_API_BASE_URL = var.api_base_url
        NODE_VERSION      = "20"
      }
    }
  }

  # Note: GitHub source integration must be configured manually via Cloudflare dashboard
  # After Terraform creates this project:
  # 1. Go to: https://dash.cloudflare.com/<account_id>/pages
  # 2. Click on "ev-cost-tracker-frontend" project
  # 3. Go to Settings → Builds & deployments
  # 4. Click "Connect to Git" and authorize the GitHub app
  # 5. Select repository: petrmac/ev-cost-tracker
  # 6. Configure build settings (already set via deployment_configs above)
  #
  # This manual step is required because Cloudflare's GitHub App must be authorized
  # before Terraform can configure the source integration.
}

# Custom domains for production
resource "cloudflare_pages_domain" "domains" {
  for_each = toset(var.custom_domains)

  account_id   = var.account_id
  project_name = cloudflare_pages_project.frontend.name
  domain       = each.value
}
