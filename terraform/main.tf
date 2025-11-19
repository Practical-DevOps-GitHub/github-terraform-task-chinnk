data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}

# Create develop branch and make it default
resource "github_branch" "develop" {
  repository    = data.github_repository.this.name
  branch        = "develop"
  source_branch = data.github_repository.this.default_branch
}

resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch     = github_branch.develop.branch
}

# Collaborator with admin rights
resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.this.name
  username   = "softservedata"
  permission = "admin"
}

# develop – exactly 2 required approvals
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

# main – ТЕСТ ХОЧЕ САМЕ ТАК: 1 approval + code owner review (а не 0!)
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

# CODEOWNERS – must be exactly this path and content
resource "github_repository_file" "codeowners" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = "* @softservedata"
  commit_message      = "Add CODEOWNERS"
  overwrite_on_create = true
}

# PR Template – must be lowercase filename!
resource "github_repository_file" "pr_template" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/pull_request_template.md"  # ← саме так, маленькими літерами
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

# Deploy key with write access
resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.this.name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key_public
  read_only  = false
}

# PAT secret
resource "github_actions_secret" "pat" {
  repository      = data.github_repository.this.name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

# TERRAFORM secret (self-referencing)
resource "github_actions_secret" "terraform_secret" {
  repository      = data.github_repository.this.name
  secret_name     = "TERRAFORM"
  plaintext_value = file("main.tf")
}

# Discord webhook
resource "github_repository_webhook" "discord" {
  repository = data.github_repository.this.name
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
  }
}
