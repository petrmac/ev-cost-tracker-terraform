variable "api_ip_name" {
  description = "Name for the API static IP resource"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "firewall_rule_prefix" {
  description = "Prefix for firewall rule names"
  type        = string
  default     = "ev-cost-tracker"
}

variable "https_firewall_target_tags" {
  description = "Network tags for instances that should allow HTTPS traffic"
  type        = list(string)
  default     = ["https-server", "gke-node"]
}