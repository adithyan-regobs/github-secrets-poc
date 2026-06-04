terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "org" {
  type    = string
  default = "hc"
}

variable "environment" {
  type    = string
  default = "stage"
}

variable "index" {
  type    = string
  default = "01"
}

variable "service" {
  type    = string
  default = "gha-test"
}

locals {
  secret_name = "${var.org}/${var.environment}/${var.index}/${var.service}/secret"
  ssm_prefix  = "/${var.org}/${var.environment}/${var.index}/${var.service}"

  # Same shape as infrastructure-v1: keys exist with placeholder values; the
  # GitHub Action owns the values afterwards (ignore_changes below).
  secret_keys = ["API_KEY", "DB_PASSWORD"]
  ssm_keys    = ["LOG_LEVEL", "FEATURE_FLAG"]
}

resource "aws_secretsmanager_secret" "test" {
  name = local.secret_name
}

resource "aws_secretsmanager_secret_version" "test" {
  secret_id     = aws_secretsmanager_secret.test.id
  secret_string = jsonencode({ for k in local.secret_keys : k => "placeholder" })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_ssm_parameter" "test" {
  for_each = toset(local.ssm_keys)

  name  = "${local.ssm_prefix}/${each.value}"
  type  = "String"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

output "secret_name" {
  value = local.secret_name
}

output "ssm_prefix" {
  value = local.ssm_prefix
}

output "ssm_parameter_names" {
  value = [for p in aws_ssm_parameter.test : p.name]
}
