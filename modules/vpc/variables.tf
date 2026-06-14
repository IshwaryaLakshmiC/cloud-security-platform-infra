variable "project" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string default = "10.0.0.0/16" }
variable "public_subnet_cidr" { type = string default = "10.0.1.0/24" }
variable "private_subnet_cidr_a" { type = string default = "10.0.2.0/24" }
variable "private_subnet_cidr_b" { type = string default = "10.0.3.0/24" }
variable "allowed_ssh_cidr" { type = string default = "0.0.0.0/0" description = "Restrict to your IP in production" }
variable "tags" { type = map(string) default = {} }
