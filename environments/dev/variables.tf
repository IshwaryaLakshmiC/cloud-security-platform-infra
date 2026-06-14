variable "region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Your IP CIDR for SSH access. Use YOUR_IP/32 in production."
  default     = "0.0.0.0/0"
}

variable "public_key" {
  type        = string
  description = "SSH public key content. Generate with: ssh-keygen -t ed25519 -C 'governance-copilot'"
}

variable "db_name" {
  type    = string
  default = "governance_copilot"
}

variable "db_username" {
  type    = string
  default = "copilot_admin"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDS master password. Min 8 chars."
}
