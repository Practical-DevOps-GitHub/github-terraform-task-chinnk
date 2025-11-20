terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "github" {
  owner = var.github_owner

}

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

  codeowners_content = <<-EOT
* @softservedata
EOT
}

# -------- Collaborator --------

resource "github_repository_collaborator" "softservedata" {
  repository = local.repo_name
  username   = local.user_name
  permission = "push"
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

# -------- Pull request template & CODEOWNERS --------

resource "github_repository_file" "pull_request_template" {
  repository          = local.repo_name
  file                = ".github/pull_request_template.md"
  content             = local.pr_tmplt_content
  branch              = data.github_repository.this.default_branch
  commit_message      = "Add pull request template"
  overwrite_on_create = true
}

resource "github_repository_file" "codeowners" {
  repository          = local.repo_name
  file                = ".github/CODEOWNERS"
  content             = local.codeowners_content
  branch              = data.github_repository.this.default_branch
  commit_message      = "Add CODEOWNERS for repository"
  overwrite_on_create = true
}

# -------- Branch protection: develop --------

resource "github_branch_protection" "develop_protection" {
  repository_id  = data.github_repository.this.node_id
  pattern        = "develop"
  enforce_admins = true

  allows_deletions    = false
  allow_force_pushes  = false
  require_signed_commits = false

  required_pull_request_reviews {
    required_approving_review_count = 2
    require_code_owner_reviews      = false
  }

  required_status_checks {
    strict   = false
    contexts = []
  }

  push_restrictions = []
}

# -------- Branch protection: main --------

resource "github_branch_protection" "main_protection" {
  repository_id  = data.github_repository.this.node_id
  pattern        = "main"
  enforce_admins = true

  allows_deletions    = false
  allow_force_pushes  = false
  require_signed_commits = false

  required_pull_request_reviews {
    required_approving_review_count = 1
    require_code_owner_reviews      = true
  }

  required_status_checks {
    strict   = false
    contexts = []
  }

  push_restrictions = []
}

# -------- Deploy key (DEPLOY_KEY) --------

resource "tls_private_key" "deploy_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "github_repository_deploy_key" "deploy_key" {
  title      = "DEPLOY_KEY"
  repository = local.repo_name
  key        = tls_private_key.deploy_key.public_key_openssh
  read_only  = true
}


output "deploy_key_private" {
  description = "Private part of the deploy key "
  value       = tls_private_key.deploy_key.private_key_pem
  sensitive   = true
}

# -------- GitHub Actions secrets --------

# 1) PAT для GitHub Actions
resource "github_actions_secret" "pat" {
  repository      = local.repo_name
  secret_name     = "PAT"
  plaintext_value = var.pat_for_actions
}

# 2) TERRAFORM
resource "github_actions_secret" "terraform_code" {
  repository      = local.repo_name
  secret_name     = "TERRAFORM"
  plaintext_value = file("${path.module}/main.tf")
}

# -------- Discord webhook for PR events --------

resource "github_repository_webhook" "discord_pr_notifications" {
  repository = local.repo_name

  configuration {
    url          = var.discord_webhook_url
    content_type = "json"
    insecure_ssl = false
  }

  events = [
    "pull_request"
  ]

  active = true
}
