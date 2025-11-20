# -------- Repository data --------
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.repository_name}"
}

# -------- Locals --------

locals {
  repo_name = data.github_repository.this.name
  user_name = "softservedata"

  pr_tmplt_content = <<-EOT
### Describe your changes

### Issue ticket number and link

### Checklist before requesting a review
- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update.
EOT
}

# -------- Branches --------

# develop branch
resource "github_branch" "develop" {
  repository    = local.repo_name
  branch        = "develop"
  source_branch = data.github_repository.this.default_branch
}

# set develop as default
resource "github_branch_default" "default" {
  repository = local.repo_name
  branch     = github_branch.develop.branch
}

# -------- Collaborator --------

resource "github_repository_collaborator" "a_repo_collaborator" {
  repository = local.repo_name
  username   = local.user_name
  permission = "push"
}

# -------- CODEOWNERS  --------

resource "github_repository_file" "codeowners" {
  repository          = local.repo_name
  branch              = "main"
  file                = ".github/CODEOWNERS"
  content             = "* @${local.user_name}"
  overwrite_on_create = true
  commit_message      = "Add CODEOWNERS"
}

# -------- PR templates (main + develop) --------

resource "github_repository_file" "main_pr_template" {
  repository          = local.repo_name
  branch              = "main"
  file                = ".github/pull_request_template.md"
  content             = local.pr_tmplt_content
  overwrite_on_create = true
  commit_message      = "Add PR template for main"
}

resource "github_repository_file" "develop_pr_template" {
  repository          = local.repo_name
  branch              = "develop"
  file                = ".github/pull_request_template.md"
  content             = local.pr_tmplt_content
  overwrite_on_create = true
  commit_message      = "Add PR template for develop"
  depends_on          = [github_branch.develop]
}

# -------- Branch protection: develop (2 approvals) --------

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

# -------- Branch protection: main (0 approval) --------

resource "github_branch_protection" "main" {
  repository_id                   = data.github_repository.this.node_id
  pattern                         = "main"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true

  required_pull_request_reviews {
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  depends_on = [
    github_repository_file.codeowners,
    github_repository_file.main_pr_template
  ]
}

# -------- Deploy key --------

resource "github_repository_deploy_key" "deploy_key" {
  repository = local.repo_name
  title      = "DEPLOY_KEY"
  key        = var.deploy_key_public
  read_only  = false
}

# -------- Actions secret: PAT --------

resource "github_actions_secret" "pat" {
  repository      = local.repo_name
  secret_name     = "PAT"
  plaintext_value = var.pat_token
}

# -------- Discord webhook --------

resource "github_repository_webhook" "discord" {
  repository = local.repo_name
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
  }
}

# -------- Variables --------

variable "github_owner" {
  type    = string
  default = "Practical-DevOps-GitHub"
}

variable "repository_name" {
  type    = string
  default = "github-terraform-task-chinnk"
}

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
