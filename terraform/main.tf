terraform {
  required_providers {
    github = {
      source = "integrations/github"
      version = "~> 6.0"
    }
  }
}
# -------- Variables --------
variable "github_owner" {
  type = string
  default = "Practical-DevOps-GitHub"
}
variable "repository_name" {
  type = string
  default = "github-terraform-task-chinnk"
}
variable "github_token" {
  type = string
  # In workflow usually exported as TF_VAR_github_token from SECRETS_TOKEN
  default = ""
}
variable "pat_token" {
  type = string
  default = "dummy-pat"
}
variable "deploy_key_public" {
  type = string
  default = "ssh-ed25519 AAAATESTKEY"
}
variable "discord_webhook_url" {
  type = string
  default = "https://example.com/webhook"
}
# -------- Provider --------
provider "github" {
  token = var.github_token
  owner = var.github_owner
}
# -------- Repository data --------
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}
# -------- Branches --------
resource "github_branch" "develop" {
  repository = data.github_repository.this.name
  branch = "develop"
  source_branch = data.github_repository.this.default_branch

  lifecycle {
    ignore_changes = [source_branch]
  }
}
resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch = github_branch.develop.branch
}
# -------- Collaborator --------
resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.this.name
  username = "softservedata"
  permission = "admin"
}
# -------- Branch protection: develop (2 approvals) --------
resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.this.node_id
  pattern = "develop"
  enforce_admins = true
  allows_deletions = false
  allows_force_pushes = false
  require_conversation_resolution = true
  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews = true
  }
}
# -------- Branch protection: main (0 approvals, code owner review required) --------
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.this.node_id
  pattern = "main"
  enforce_admins = true
  allows_deletions = false
  allows_force_pushes = false
  require_conversation_resolution = true
  required_pull_request_reviews {
    required_approving_review_count = 0
    dismiss_stale_reviews = true
    require_code_owner_reviews = true
  }

  depends_on = [
    github_repository_file.codeowners_github,
    github_repository_file.codeowners_root,
    github_repository_file.pr_template
  ]
}
# -------- CODEOWNERS --------
resource "github_repository_file" "codeowners_github" {
  repository = data.github_repository.this.name
  branch = "main"
  file = ".github/CODEOWNERS"
  content = "* @softservedata"
  commit_message = "Add CODEOWNERS in .github"
  overwrite_on_create = true
}
resource "github_repository_file" "codeowners_root" {
  repository = data.github_repository.this.name
  branch = "main"
  file = "CODEOWNERS"
  content = "* @softservedata"
  commit_message = "Add root CODEOWNERS"
  overwrite_on_create = true
}
# -------- PR template --------
resource "github_repository_file" "pr_template" {
  repository = data.github_repository.this.name
  branch = "main"
  file = ".github/pull_request_template.md"
  content = <<-EOT
### Describe your changes
### Issue ticket number and link
### Checklist before requesting a review
- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update.
EOT
  commit_message = "Add PR template"
  overwrite_on_create = true
}
# -------- Deploy key --------
resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.this.name
  title = "DEPLOY_KEY"
  key = var.deploy_key_public
  read_only = false
}
# -------- Actions secret: PAT --------
resource "github_actions_secret" "pat" {
  repository = data.github_repository.this.name
  secret_name = "PAT"
  plaintext_value = var.pat_token
}
# -------- Discord webhook --------
resource "github_repository_webhook" "discord" {
  repository = data.github_repository.this.name
  active = true
  events = ["pull_request"]
  configuration {
    url = var.discord_webhook_url
    content_type = "json"
  }
}
