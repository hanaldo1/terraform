variable "name" {
  type = string
  description = "Kubernetes cluster's name"
}

variable "k8s_version" {
  type = string
  default = "1.28"
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_sg_id" {
  type = string
}

variable "worker_sg_id" {
  type = string
}

variable "public_access_allowed_cidrs" {
  type = list(string)
}

variable "key_pair_name" {
  type = string
}

variable "account_id" {
  type = string
}