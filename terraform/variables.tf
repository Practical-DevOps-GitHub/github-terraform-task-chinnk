variable "github_token" {
  description = "GitHub Personal Access Token for Terraform"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user owner"
  type        = string
  default     = "Practical-DevOps-GitHub"
}

variable "repository_name" {
  description = "Repository name to configure"
  type        = string
  default     = "github-terraform-task-chinnk"
}

variable "pat_token" {
  description = "PAT stored as Actions secret PAT"
  type        = string
  default = "ghp_"
}

variable "deploy_key_public" {
  description = "Public SSH key for DEPLOY_KEY"
  type        = string
  default = "ssh-ed25519 AAAAC"
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for PR events"
  type        = string
  default = "https://discord.com/api/webhooks/../github"
}
