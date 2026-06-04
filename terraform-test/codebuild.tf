variable "github_repo_url" {
  type    = string
  default = "https://github.com/adithyan-regobs/github-secrets-poc"
}

# Runner label is "codebuild-<project-name>-<run_id>-<attempt>", so the project
# MUST be named github-actions-runner to match the workflows' runs-on value.
variable "runner_project_name" {
  type    = string
  default = "github-actions-runner"
}

# GitHub auth for CodeBuild. Starts in PENDING; approve it once in the console
# (Developer Tools > Connections) before the webhook can register.
resource "aws_codestarconnections_connection" "github" {
  name          = "github-secrets-poc"
  provider_type = "GitHub"
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codestarconnections_connection.github.arn
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.runner_project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    sid = "UseConnection"
    actions = [
      "codeconnections:GetConnectionToken",
      "codeconnections:GetConnection",
      "codeconnections:UseConnection",
      "codestar-connections:GetConnectionToken",
      "codestar-connections:GetConnection",
      "codestar-connections:UseConnection",
    ]
    resources = [aws_codestarconnections_connection.github.arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.runner_project_name}-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "runner" {
  name         = var.runner_project_name
  service_role = aws_iam_role.codebuild.arn

  source {
    type     = "GITHUB"
    location = "${var.github_repo_url}.git"
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# Auto-start an ephemeral runner whenever a workflow job targeting this project
# is queued.
resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

output "codeconnection_arn" {
  value = aws_codestarconnections_connection.github.arn
}

output "codeconnection_status" {
  value = aws_codestarconnections_connection.github.connection_status
}

output "runner_project_name" {
  value = aws_codebuild_project.runner.name
}

output "runner_label" {
  value = "codebuild-${aws_codebuild_project.runner.name}-<run_id>-<attempt>"
}
