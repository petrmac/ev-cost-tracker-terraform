variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/organization"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Git branch to track"
  type        = string
  default     = "main"
}

variable "git_ssh_key" {
  description = "SSH private key for Git repository access"
  type        = string
  sensitive   = true
}

variable "git_ssh_key_pub" {
  description = "SSH public key for Git repository access"
  type        = string
}

variable "known_hosts" {
  description = "SSH known_hosts content"
  type        = string
}

variable "age_key" {
  description = "Age private key for SOPS decryption"
  type        = string
  sensitive   = true
  default     = ""
}