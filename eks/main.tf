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

data "aws_region" "current" {}
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

module "cluster" {
  source = "./cluster"
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

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.cluster.cluster_name}"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context_cluster = module.cluster.cluster_arn
  config_context = module.cluster.cluster_arn
}

module "test-page" {
  count = var.deploy_test_page ? 1 : 0

  source = "./test-page"
  depends_on = [ module.network, module.cluster, null_resource.update_kubeconfig ]
}