# terraform/main.tf — FINAL VERSION THAT PASSES ALL TESTS

data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}

resource "github_branch" "develop" {
  repository    = data.github_repository.this.name
  branch        = "develop"
  source_branch = data.github_repository.this.default_branch
}

resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch     = github_branch.develop.branch
}

resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.this.name
  username   = "softservedata"
  permission = "admin"
}

resource "github_branch_protection" "develop" {
  repository_id                   = data.github_repository.this.node_id
  pattern                         = "develop"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
  }
}

resource "github_branch_protection" "main" {
  repository_id                   = data.github_repository.this.node_id
  pattern                         = "main"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }
}

resource "github_repository_file" "codeowners" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = "* @softservedata"
  commit_message      = "Add CODEOWNERS"
  overwrite_on_create = true
}

resource "github_repository_file" "pr_template" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/pull_request_template.md"
  content             = <<-EOT
### Describe your changes

### Issue ticket number and link

### Checklist before requesting a review
- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update.
EOT
  commit_message      = "Add PR template"
  overwrite_on_create = true
}

resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.this.name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key_public
  read_only  = false
}

resource "github_actions_secret" "pat" {
  repository      = data.github_repository.this.name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

resource "github_actions_secret" "terraform_secret" {
  repository      = data.github_repository.this.name
  secret_name     = "TERRAFORM"
  plaintext_value = file("main.tf")
}

resource "github_repository_webhook" "discord" {
  repository = data.github_repository.this.name
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
  }
}

# Variables declaration – add this to fix the "undeclared variable" error
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
  sensitive   = true
}

variable "deploy_key_public" {
  description = "Public SSH key for DEPLOY_KEY"
  type        = string
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for PR events"
  type        = string
  sensitive   = true
}
