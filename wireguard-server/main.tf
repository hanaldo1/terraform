terraform {
  # Save tfstate file as 'wireguard-server' key in S3 bucket
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "wireguard-server"
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

# Get AWS Account id and region for current user
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_lightsail_key_pair" "wireguard_server" {
  name = "wireguard-server-keypair"
  public_key = file("${path.module}/ssh/lightsail_key.pub")
}

resource "aws_lightsail_static_ip" "wireguard_server" {
  name = "wireguard-server-ip"
}

resource "aws_lightsail_instance" "wireguard_server" {
  name = "wireguard-server"
  availability_zone = "${data.aws_region.current.name}a"
  blueprint_id = "ubuntu_20_04"
  bundle_id = "nano_3_0"
  ip_address_type = "ipv4" # only allow ipv4 (default: dualstack => ipv4 & ipv6)
  key_pair_name = aws_lightsail_key_pair.wireguard_server.name
  user_data = file("${path.module}/templates/init.sh")
}

resource "aws_lightsail_static_ip_attachment" "wireguard_server" {
  instance_name = aws_lightsail_instance.wireguard_server.name
  static_ip_name = aws_lightsail_static_ip.wireguard_server.name
}

resource "aws_lightsail_instance_public_ports" "wireguard_server" {
  instance_name = aws_lightsail_instance.wireguard_server.name

  port_info {
    protocol = "tcp"
    from_port = var.ui_port
    to_port = var.ui_port
    cidrs = var.public_access_allowed_ips
  }

  port_info {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidrs = var.public_access_allowed_ips
  }
}

resource "null_resource" "set_up_wireguard" {
  connection {
    type = "ssh"
    user = aws_lightsail_instance.wireguard_server.username
    host = aws_lightsail_static_ip.wireguard_server.ip_address
    private_key = file("${path.module}/ssh/lightsail_key")
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/docker-compose.yml", {
      server_port = var.server_port
      server_network = var.server_network
      ui_port = var.ui_port
      ui_password = var.ui_password
      ui_traffic_stats = var.ui_traffic_stats
      ui_chart_type = var.ui_chart_type
    })

    destination = "/home/ubuntu/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [ 
        "sleep 30",
        "docker compose -f /home/ubuntu/docker-compose.yml up -d"
    ]
  }
}