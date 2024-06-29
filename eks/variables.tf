variable "name" {
  type = string
  description = "Kubernetes cluster's name"
}

variable "vpc_cidr" {
  type = string
  description = "CIDR block used for VPC. EX) 10.0.0.0/16"
}

variable "public_access_allowed_cidrs" {
  type = list(string)
}

variable "key_pair_name" {
  type = string
  default = "common-key"
}