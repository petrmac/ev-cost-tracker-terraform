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

# Create A records for root domain pointing to API IP
resource "cloudflare_record" "root" {
  for_each = data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "@"
  type    = "A"
  content = var.api_ip
  ttl     = 1  # Must be 1 when proxied = true
  proxied = true

  comment = "EV Tracker API - ${var.environment}"
}

# Create www subdomain
resource "cloudflare_record" "www" {
  for_each = data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "www"
  type    = "CNAME"
  content = each.key
  ttl     = 1  # Must be 1 when proxied = true
  proxied = true

  comment = "EV Tracker www - ${var.environment}"
}

# Create API subdomain
resource "cloudflare_record" "api" {
  for_each = data.cloudflare_zone.zones

  zone_id = each.value.id
  name    = "api"
  type    = "A"
  content = var.api_ip
  ttl     = 1  # Must be 1 when proxied = true
  proxied = true

  comment = "EV Tracker API endpoint - ${var.environment}"
}

# Create environment-specific subdomains if enabled
resource "cloudflare_record" "env_subdomain" {
  for_each = var.create_environment_subdomains && var.environment != "prod" ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = var.environment
  type    = "A"
  content = var.api_ip
  ttl     = 1  # Must be 1 when proxied = true
  proxied = true

  comment = "EV Tracker ${var.environment} environment"
}

resource "cloudflare_record" "env_api_subdomain" {
  for_each = var.create_environment_subdomains && var.environment != "prod" ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  name    = "${var.environment}-api"
  type    = "A"
  content = var.api_ip
  ttl     = 1  # Must be 1 when proxied = true
  proxied = true

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
  
  priority = 1
}

resource "cloudflare_page_rule" "api_bypass_cache" {
  for_each = var.enable_page_rules ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id
  target  = "${each.key}/api/*"
  
  actions {
    cache_level = "bypass"
  }
  
  priority = 2
}

# SSL/TLS settings (requires additional API permissions)
resource "cloudflare_zone_settings_override" "ssl_settings" {
  for_each = var.manage_zone_settings ? data.cloudflare_zone.zones : {}

  zone_id = each.value.id

  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
  }
}