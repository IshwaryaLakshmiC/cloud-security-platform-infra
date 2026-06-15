variable "project" {
  type = string
}

variable "db_name" {
  type    = string
  default = "cloud_security_platform"
}

variable "db_username" {
  type    = string
  default = "platform_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
