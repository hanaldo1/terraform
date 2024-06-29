/*
 * Data
 */

data "aws_caller_identity" "current" {}

resource "aws_eks_cluster" "common" {
  name = var.name
  version = var.k8s_version
  role_arn = "arn:aws:iam::${var.account_id}:role/eks-cluster-role"

  vpc_config {
    subnet_ids = flatten([var.public_subnet_ids, var.private_subnet_ids])
    security_group_ids = [ var.cluster_sg_id ]
    public_access_cidrs = var.public_access_allowed_cidrs
    endpoint_private_access = true
    endpoint_public_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.name}-worker-iam-instance-profile"
  role = "eks-node-role"
}

data "aws_ami" "eks" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu-eks/k8s_1.28/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_template" "worker" {
  name = "${var.name}-worker"

  block_device_mappings {
    device_name = data.aws_ami.eks.root_device_name
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 2
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name    
  }

  image_id = data.aws_ami.eks.image_id
  vpc_security_group_ids = [ var.worker_sg_id ]
  key_name = var.key_pair_name
  user_data = base64encode(templatefile("${path.module}/config/cloud-init.worker.yaml", {
    NAME = var.name
  }))
}

resource "aws_autoscaling_group" "worker" {
  name = "${var.name}-worker"
  max_size = 2
  min_size = 1
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      spot_allocation_strategy = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_name = aws_launch_template.worker.name
        version = "$Latest"
      }

      override {
        instance_type = "t3.micro"
      }
    }
  }

  tag {
    key = "Name"
    value = "${var.name}-worker"
    propagate_at_launch = true
  }

  tag {
    key = "kubernetes.io/cluster/${var.name}"
    value = "owned"
    propagate_at_launch = true
  }
}