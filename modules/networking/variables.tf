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