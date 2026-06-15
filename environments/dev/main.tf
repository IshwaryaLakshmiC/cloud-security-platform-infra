terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend — enable after first apply creates the state bucket
   backend "s3" {
     bucket         = "cloud-security-platform-terraform-state-bucket"
     key            = "platform/dev/terraform.tfstate"
     region         = "us-east-1"
  #   dynamodb_table = "cloud-security-platform-terraform-locks"
     encrypt        = true
   }
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

# ── RDS PostgreSQL (already running — db.t3.micro, pg 15.17) ─
module "rds" {
  source  = "../../modules/rds"
  project = local.project

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.vpc.rds_security_group_id

  tags = local.tags
}

# ── EC2 App Server ────────────────────────────────────────────
module "ec2" {
  source  = "../../modules/ec2"
  project = local.project
  region  = var.region

  public_subnet_id      = module.vpc.public_subnet_id
  app_security_group_id = module.vpc.app_security_group_id
  instance_profile_name = module.iam.instance_profile_name

  public_key      = var.public_key
  db_host         = module.rds.db_host
  db_port         = module.rds.db_port
  db_name         = module.rds.db_name
  db_username     = module.rds.db_username
  db_password     = var.db_password
  s3_cache_bucket = module.s3.app_cache_bucket_name

  tags = local.tags
}
