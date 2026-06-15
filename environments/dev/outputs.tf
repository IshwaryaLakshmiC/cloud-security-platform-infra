output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "EC2 app server public IP"
  value       = module.ec2.public_ip
}

output "ec2_ssh_command" {
  description = "SSH into the app server"
  value       = module.ec2.ssh_command
}

output "database_info" {
  description = "PostgreSQL runs locally on the EC2 instance — localhost:5432"
  value       = "PostgreSQL 15 + pgvector installed on EC2 via userdata. Connect via SSH tunnel if needed."
}

output "s3_state_bucket" {
  description = "Terraform state S3 bucket — update backend config after first apply"
  value       = module.s3.state_bucket_name
}

output "s3_cache_bucket" {
  description = "App cache S3 bucket"
  value       = module.s3.app_cache_bucket_name
}

output "dynamodb_locks_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = module.s3.dynamodb_table_name
}

output "governance_copilot_url" {
  description = "Governance Copilot API (via Nginx)"
  value       = "http://${module.ec2.public_ip}/governance"
}

output "discovery_copilot_url" {
  description = "Security Discovery Copilot API (via Nginx)"
  value       = "http://${module.ec2.public_ip}/discovery"
}

output "health_check_url" {
  description = "Platform health check"
  value       = "http://${module.ec2.public_ip}/health"
}

output "app_role_arn" {
  description = "IAM role ARN for EC2 — used by both services"
  value       = module.iam.app_role_arn
}

output "next_steps" {
  description = "Deployment steps after terraform apply"
  value = <<-EOT

    ── Infrastructure ready ──────────────────────────────────────

    1. SSH into EC2:
       ${module.ec2.ssh_command}

    2. Deploy Governance Copilot:
       git clone https://github.com/IshwaryaLakshmiC/aws-governance-copilot /opt/governance-copilot
       sudo systemctl enable --now governance-copilot

    3. Deploy Discovery Copilot:
       git clone https://github.com/IshwaryaLakshmiC/security-discovery-copilot /opt/discovery-copilot
       sudo systemctl enable --now discovery-copilot

    4. Verify health:
       curl http://${module.ec2.public_ip}/health

    Note: PostgreSQL runs locally on EC2 — no RDS needed.
    DB is initialised automatically via userdata on first boot.

    ─────────────────────────────────────────────────────────────
    Governance Copilot:  http://${module.ec2.public_ip}/governance
    Discovery Copilot:   http://${module.ec2.public_ip}/discovery
    ─────────────────────────────────────────────────────────────
  EOT
}
