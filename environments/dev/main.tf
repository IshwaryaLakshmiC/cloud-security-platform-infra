terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend — enable after first apply creates the state bucket
  # backend "s3" {
  #   bucket         = "cloud-security-platform-terraform-state-<YOUR_ACCOUNT_ID>"
  #   key            = "platform/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "cloud-security-platform-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  project    = "cloud-security-platform"
  account_id = data.aws_caller_identity.current.account_id
  tags = {
    Project     = local.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "ishwarya"
    Repo        = "github.com/IshwaryaLakshmiC/cloud-security-platform-infra"
  }
}

# ── S3 — Terraform state + app cache ─────────────────────────
module "s3" {
  source     = "../../modules/s3"
  project    = local.project
  account_id = local.account_id
  tags       = local.tags
}

# ── VPC ──────────────────────────────────────────────────────
module "vpc" {
  source  = "../../modules/vpc"
  project = local.project
  region  = var.region
  tags    = local.tags

  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# ── IAM ──────────────────────────────────────────────────────
module "iam" {
  source  = "../../modules/iam"
  project = local.project
  region  = var.region
  tags    = local.tags
}

# ── RDS removed ───────────────────────────────────────────────
# PostgreSQL 15 + pgvector runs on the EC2 instance (installed via userdata).
# This avoids RDS free tier restrictions entirely.
# DB is accessible at localhost:5432 from within the EC2 instance.

# ── EC2 App Server ────────────────────────────────────────────
module "ec2" {
  source  = "../../modules/ec2"
  project = local.project
  region  = var.region

  public_subnet_id      = module.vpc.public_subnet_id
  app_security_group_id = module.vpc.app_security_group_id
  instance_profile_name = module.iam.instance_profile_name

  public_key      = var.public_key
  # DB runs locally on EC2 — userdata installs and configures it
  db_host         = "localhost"
  db_port         = 5432
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = var.db_password
  s3_cache_bucket = module.s3.app_cache_bucket_name

  tags = local.tags
}
