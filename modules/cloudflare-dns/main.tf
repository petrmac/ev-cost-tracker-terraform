terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Data source to get zone IDs for each domain
data "cloudflare_zone" "zones" {
  for_each = toset(var.domains)
  name     = each.value
}

# Create A records for root domain pointing to GKE (when NOT using Pages)
resource "cloudflare_record" "root_gke" {
  for_each = var.use_pages ? {} : data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "@"
  type    = "A"
  content = var.api_ip
  ttl     = 300
  proxied = false  # Disabled to allow Google managed certificates to work

  comment = "EV Tracker - ${var.environment} (GKE)"
}

# Create CNAME records for root domain pointing to Pages (when using Pages)
resource "cloudflare_record" "root_pages" {
  for_each = var.use_pages ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = "@"
  type    = "CNAME"
  content = "${var.pages_project_name}.pages.dev"
  ttl     = 1  # Auto TTL
  proxied = true  # Enable CDN

  comment = "EV Tracker - ${var.environment} (Pages CDN)"
}

# Create www subdomain (always CNAME to root, proxied when using Pages)
resource "cloudflare_record" "www" {
  for_each = data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "www"
  type    = "CNAME"
  content = each.key
  ttl     = var.use_pages ? 1 : 300  # Auto TTL when using Pages
  proxied = var.use_pages ? true : false  # Enable proxy for Pages (for redirect rule)

  comment = "EV Tracker www - ${var.environment}"
}

# Create API subdomain
resource "cloudflare_record" "api" {
  for_each = data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "api"
  type    = "A"
  content = var.api_ip
  ttl     = 300
  proxied = false  # Disabled to allow Google managed certificates to work

  comment = "EV Tracker API endpoint - ${var.environment}"
}

# Create environment-specific subdomains if enabled
resource "cloudflare_record" "env_subdomain" {
  for_each = var.create_environment_subdomains && var.environment != "prod" ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = var.environment
  type    = "A"
  content = var.api_ip
  ttl     = 300
  proxied = false  # Disabled to allow Google managed certificates to work

  comment = "EV Tracker ${var.environment} environment"
}

resource "cloudflare_record" "env_api_subdomain" {
  for_each = var.create_environment_subdomains && var.environment != "prod" ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = "${var.environment}-api"
  type    = "A"
  content = var.api_ip
  ttl     = 300
  proxied = false  # Disabled to allow Google managed certificates to work

  comment = "EV Tracker ${var.environment} API endpoint"
}

# Create wildcard for catch-all (optional, disabled by default)
resource "cloudflare_record" "wildcard" {
  for_each = var.create_wildcard ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = "*"
  type    = "A"
  content = var.api_ip
  ttl     = 300  # Can use longer TTL when not proxied
  proxied = false  # Wildcards can't be proxied

  comment = "EV Tracker wildcard - ${var.environment}"
}

# Note: www redirects are handled by Cloudflare Pages _redirects file
# See: frontend/public/_redirects
# This avoids requiring Zone:Page Rules:Edit permission on the API token

# Page rules for caching and security (optional)
resource "cloudflare_page_rule" "cache_static" {
  for_each = var.enable_page_rules ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  target  = "${each.key}/static/*"

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 7200
    browser_cache_ttl = 86400
  }

  priority = 2
}

resource "cloudflare_page_rule" "api_bypass_cache" {
  for_each = var.enable_page_rules ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  target  = "${each.key}/api/*"

  actions {
    cache_level = "bypass"
  }

  priority = 3
}

# SSL/TLS settings - REMOVED due to Cloudflare API issues
# These settings can be configured manually in the Cloudflare dashboard:
# 1. Go to SSL/TLS > Overview
# 2. Set encryption mode to "Full (strict)"
# 3. Enable "Always Use HTTPS" in SSL/TLS > Edge Certificates
# 4. Set Minimum TLS Version to 1.2 in SSL/TLS > Edge Certificates