output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "EC2 app server public IP — access copilot at http://<this_ip>:8000"
  value       = module.ec2.public_ip
}

output "ec2_ssh_command" {
  description = "SSH command to connect to the app server"
  value       = module.ec2.ssh_command
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_endpoint
}

output "rds_host" {
  description = "RDS host (for .env file)"
  value       = module.rds.db_host
}

output "app_role_arn" {
  description = "IAM role ARN attached to EC2 — used by collectors"
  value       = module.iam.app_role_arn
}

output "next_steps" {
  description = "What to do after terraform apply"
  value = <<-EOT
    1. Run: bash ../../scripts/init-db.sh
    2. SSH in: ${module.ec2.ssh_command}
    3. Deploy app: git clone https://github.com/IshwaryaLakshmiC/aws-governance-copilot /opt/governance-copilot
    4. Start: sudo systemctl enable --now governance-copilot
    5. Access copilot: http://${module.ec2.public_ip}:8000
  EOT
}
