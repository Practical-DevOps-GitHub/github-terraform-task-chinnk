# Repository data
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}

# develop branch + set as default
resource "github_branch" "develop" {
  repository    = data.github_repository.this.name
  branch        = "develop"
  source_branch = data.github_repository.this.default_branch
}

resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch     = github_branch.develop.branch
}

# Collaborator softservedata
resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.this.name
  username   = "softservedata"
  permission = "push"
}

# Branch protection: develop
resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.this.node_id
  pattern       = "develop"

  allows_deletions    = false
  allows_force_pushes = false
  enforce_admins      = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 2
    require_code_owner_reviews      = false
  }

  require_conversation_resolution = true
  required_status_checks          = []
}

# Branch protection: main
resource "github_branch_protection" "main" {
  repository_id = data.github_repository.this.node_id
  pattern       = "main"

  allows_deletions    = false
  allows_force_pushes = false
  enforce_admins      = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
    require_code_owner_reviews      = true
  }

  require_conversation_resolution = true
  required_status_checks          = []
}

# CODEOWNERS file
resource "github_repository_file" "codeowners" {
  repository          = data.github_repository.this.name
  file                = ".github/CODEOWNERS"
  branch              = "main"
  content             = "* @softservedata\n"
  commit_message      = "Add CODEOWNERS file assigning softservedata"
  overwrite_on_create = true
}

# Pull request template
resource "github_repository_file" "pull_request_template" {
  repository          = data.github_repository.this.name
  file                = ".github/pull_request_template.md"
  branch              = "main"
  commit_message      = "Add pull request template"
  overwrite_on_create = true

  content = <<-EOT
  ## Describe your changes

  Please provide a clear and concise description of the changes you are making.

  ## Issue ticket number and link

  - Ticket:

  ## Checklist before requesting a review

  - [ ] I have performed a self-review of my code
  - [ ] If it is a core feature, I have added thorough tests
  - [ ] Do we need to implement analytics?
  - [ ] Will this be part of a product update? If yes, please write one phrase about this update
  EOT
}

# Deploy key
resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.this.name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key_public
  read_only  = true
}

# GitHub Actions secrets
resource "github_actions_secret" "pat" {
  repository      = data.github_repository.this.name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

resource "github_actions_secret" "terraform_code" {
  repository      = data.github_repository.this.name
  secret_name     = "TERRAFORM"
  plaintext_value = file("${path.module}/main.tf")
}

# Discord webhook for PR notifications
resource "github_repository_webhook" "discord_pr" {
  repository = data.github_repository.this.name
  active     = true

  events = [
    "pull_request",
  ]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
    insecure_ssl = false
  }
}
