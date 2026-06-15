variable "project" {
  type = string
}

variable "account_id" {
  type        = string
  description = "AWS account ID for globally unique bucket naming"
}

variable "tags" {
  type    = map(string)
  default = {}
}
