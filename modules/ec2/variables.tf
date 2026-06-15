variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "app_security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "public_key" {
  type        = string
  description = "SSH public key content"
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "s3_cache_bucket" {
  type        = string
  default     = ""
  description = "S3 bucket name for app cache"
}

variable "tags" {
  type    = map(string)
  default = {}
}
