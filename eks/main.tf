terraform {
  # Save tfstate file as 'k8s-cluster' key in S3 bucket
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "eks"
    region = "ap-northeast-2"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.51.1"
    }
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}

data "aws_key_pair" "eks" {
  key_name = var.key_pair_name
}


module "network" {
  source = "./network"

  name = var.name
  vpc_cidr = var.vpc_cidr
  public_access_allowed_cidrs = var.public_access_allowed_cidrs
  key_pair_name = data.aws_key_pair.eks.key_name
}

module "eks" {
  source = "./eks"
  depends_on = [ module.network ]

  name = var.name
  worker_sg_id = module.network.worker_sg_id
  cluster_sg_id = module.network.cluster_sg_id
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  public_access_allowed_cidrs = var.public_access_allowed_cidrs
  key_pair_name = data.aws_key_pair.eks.key_name

  account_id = data.aws_caller_identity.current.account_id
}