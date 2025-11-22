variable "domains" {
  description = "List of domain names to configure"
  type        = list(string)
}

variable "api_ip" {
  description = "Static IP address for the API"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "create_environment_subdomains" {
  description = "Create environment-specific subdomains"
  type        = bool
  default     = true
}

variable "create_wildcard" {
  description = "Create wildcard DNS record"
  type        = bool
  default     = false
}

variable "enable_page_rules" {
  description = "Enable Cloudflare page rules for caching"
  type        = bool
  default     = false
}

variable "manage_zone_settings" {
  description = "Manage zone settings (requires Zone:Settings:Edit permission)"
  type        = bool
  default     = false
}

variable "use_pages" {
  description = "Whether frontend is hosted on Cloudflare Pages"
  type        = bool
  default     = false
}

variable "pages_project_name" {
  description = "Cloudflare Pages project name"
  type        = string
  default     = "ev-cost-tracker-frontend"
}