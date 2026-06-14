terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use S3 backend (recommended)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "aws-governance-copilot/dev/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

locals {
  project = "aws-governance-copilot"
  tags = {
    Project     = local.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "ishwarya"
    Repo        = "github.com/IshwaryaLakshmiC/aws-governance-copilot-infra"
  }
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

# ── RDS PostgreSQL + pgvector ─────────────────────────────────
module "rds" {
  source  = "../../modules/rds"
  project = local.project

  db_name    = var.db_name
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

  public_key  = var.public_key
  db_host     = module.rds.db_host
  db_port     = module.rds.db_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = var.db_password

  tags = local.tags
}
