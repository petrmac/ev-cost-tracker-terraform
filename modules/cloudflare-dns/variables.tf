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