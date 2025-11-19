# Repository data
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}

# 1. develop + default branch
resource "github_branch" "develop" {
  repository    = data.github_repository.this.name
  branch        = "develop"
  source_branch = data.github_repository.this.default_branch
}

resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch     = github_branch.develop.branch
}

# 2. Collaborator
resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.this.name
  username   = "softservedata"
  permission = "admin"
}

# 3. Branch protection develop — 2 approvals
resource "github_branch_protection" "develop" {
  repository_id                   = data.github_repository.this.node_id
  pattern                         = "develop"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 2
  }
}

# 4. Branch protection main — approvals (0)
resource "github_branch_protection" "main" {
  repository_id                   = data.github_repository.this.node_id
  pattern                         = "main"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 0
    require_code_owner_reviews      = true  
  }
}

# 5.  .github (placeholder-file)
resource "github_repository_file" "github_folder_placeholder" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/.placeholder"
  content             = "placeholder"
  commit_message      = "Create .github folder"
  overwrite_on_create = true
}

# 6. CODEOWNERS (in .github/)
resource "github_repository_file" "codeowners" {
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = "* @softservedata"
  commit_message      = "Add CODEOWNERS"
  overwrite_on_create = true
}

# 7. PR Template (in .github/)
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

# 8. Deploy key — write access (read_only = false)
resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.this.name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key_public
  read_only  = false
}

# 9. Secret PAT
resource "github_actions_secret" "pat" {
  repository      = data.github_repository.this.name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

# 10. Discord webhook
resource "github_repository_webhook" "discord" {
  repository = data.github_repository.this.name
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
  }
}

# 11. Required variables for repository identification
variable "github_owner" {
  type    = string
  default = "Practical-DevOps-GitHub"
}

variable "repository_name" {
  type    = string
  default = "github-terraform-task-chinnk"
}

# 12. Required variables for secrets/webhook (dummy values)
variable "pat_token" {
  type    = string
  default = "dummy-pat"
}

variable "deploy_key_public" {
  type    = string
  default = "ssh-ed25519 AAAATESTKEY"
}

variable "discord_webhook_url" {
  type    = string
  default = "https://example.com/webhook"
}
