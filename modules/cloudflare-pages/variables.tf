variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "project_name" {
  description = "Cloudflare Pages project name"
  type        = string
  default     = "ev-cost-tracker-frontend"
}

variable "production_branch" {
  description = "Git branch for production deployments"
  type        = string
  default     = "main"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (with frontend code)"
  type        = string
  default     = "ev-cost-tracker"
}

variable "api_base_url" {
  description = "Backend API base URL"
  type        = string
}

variable "custom_domains" {
  description = "Custom domains for the Pages project"
  type        = list(string)
  default     = []
}
