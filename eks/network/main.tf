/*
 * Data
 */

data "aws_region" "current" {}

data "aws_availability_zones" "common" {
  filter {
    name   = "region-name"
    values = [data.aws_region.current.name]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


/*
 * Resource
 */

resource "aws_vpc" "cluster" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.default_tags, {
    "Name": "${var.name}-vpc"
  })
}

resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id = aws_vpc.cluster.id
  cidr_block = cidrsubnet(var.vpc_cidr, local.subnet_netbits, count.index)
  availability_zone = data.aws_availability_zones.common.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.default_tags, {
    "Name": "${var.name}-public-subnet",
    "kubernetes.io/role/elb": 1 # For LoadBalancer
  })
}

resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id = aws_vpc.cluster.id
  cidr_block = cidrsubnet(var.vpc_cidr, local.subnet_netbits, var.public_subnet_count + count.index)
  availability_zone = data.aws_availability_zones.common.names[count.index]

  tags = merge(local.default_tags, {
    "Name": "${var.name}-private-subnet"
  })
}

resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.cluster.id

  # Allow access for SSH from public
  dynamic "ingress" {
    for_each = { for i, v in var.public_access_allowed_cidrs : i => v }

    content {
      rule_no = 100 + ingress.key
      action = "allow"
      protocol = "tcp"
      from_port = 22
      to_port = 22
      cidr_block = ingress.value
    }
  }

  # Allow respond from internet or internal
  ingress {
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    from_port = 1024
    to_port = 65535
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no = 120
    action = "allow"
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_block = var.vpc_cidr
  }

  ingress {
    rule_no = 130
    action = "allow"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no = 140
    action = "allow"
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_block = "0.0.0.0/0"
  }
  
  egress {
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_block = "0.0.0.0/0"
  }

  # To respond for inbound to internet or internal
  egress {
    rule_no = 120
    action = "allow"
    protocol = "tcp"
    from_port = 1024
    to_port = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Allow SSH to Instance in private subnet
  egress {
    rule_no = 130
    action = "allow"
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_block = var.vpc_cidr
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-public-subnet-nacl"
  })
}

resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.cluster.id

  # Allow all from public subnet (+ SSH)
  ingress {
    rule_no = 100
    action = "allow"
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_block = var.vpc_cidr
  }

  # Allow respond from internet or internal
  ingress {
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    from_port = 1024
    to_port = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_block = "0.0.0.0/0"
  }
  
  egress {
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_block = "0.0.0.0/0"
  }

  # To respond for inbound to internet or internal
  egress {
    rule_no = 130
    action = "allow"
    protocol = "tcp"
    from_port = 1024
    to_port = 65535
    cidr_block = "0.0.0.0/0"
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-private-subnet-nacl"
  })
}

resource "aws_network_acl_association" "public" {
  count = var.public_subnet_count

  subnet_id = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.public.id
}

resource "aws_network_acl_association" "private" {
  count = var.private_subnet_count

  subnet_id = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.private.id
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = aws_vpc.cluster.id

  tags = merge(local.default_tags, {
    "Name": "${var.name}-IGW"
  })
}

resource "aws_security_group" "nat" {
  vpc_id = aws_vpc.cluster.id

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = var.public_access_allowed_cidrs
  }

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [ var.vpc_cidr ]
  }

  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = [ var.vpc_cidr ]
  }

  egress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = [ var.vpc_cidr ]
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-nat-sg"
  })
}

resource "aws_instance" "nat" {
  instance_type = local.nat_instance_type
  ami = data.aws_ami.ubuntu.id
  key_name = var.key_pair_name

  subnet_id = aws_subnet.public[0].id
  vpc_security_group_ids = [ aws_security_group.nat.id ]

  source_dest_check = false
  user_data_base64 = base64encode(templatefile("${path.module}/config/cloud-init.nat.yaml", {
    VPC_CIDR = var.vpc_cidr
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-nat-instance"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster.id
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-public-route-table"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = aws_instance.nat.primary_network_interface_id
  }

  tags = merge(local.default_tags, {
    "Name": "${var.name}-private-route-table"
  })
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "cluster" {
  vpc_id = aws_vpc.cluster.id
  name_prefix = "eks-cluster-sg-${var.name}-"

  tags = local.default_tags
}

resource "aws_security_group_rule" "cluster_in_443" {
  security_group_id = aws_security_group.cluster.id
  type = "ingress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "cluster_in_self" {
  security_group_id = aws_security_group.cluster.id
  type = "ingress"
  protocol = "-1"
  from_port = 0
  to_port = 0
  self = true
}

resource "aws_security_group_rule" "cluster_out_worker_kubelet" {
  security_group_id = aws_security_group.cluster.id
  type = "egress"
  protocol = "tcp"
  from_port = 10250
  to_port = 10250
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group" "worker" {
  vpc_id = aws_vpc.cluster.id
  name_prefix = "${var.name}-worker-sg-"

  tags = merge(local.default_tags, {
    "kubernetes.io/cluster/${var.name}": "owned"
  })
}

resource "aws_security_group_rule" "worker_in_self" {
  security_group_id = aws_security_group.worker.id
  type = "ingress"
  protocol = "-1"
  from_port = 0
  to_port = 0
  self = true
}

resource "aws_security_group_rule" "worker_in_kubelet" {
  security_group_id = aws_security_group.worker.id
  type = "ingress"
  protocol = "tcp"
  from_port = 10250
  to_port = 10250
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "worker_in_22" {
  security_group_id = aws_security_group.worker.id
  type = "ingress"
  protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_blocks = [ var.vpc_cidr ]
}

resource "aws_security_group_rule" "worker_out_80" {
  security_group_id = aws_security_group.worker.id
  type = "egress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_blocks = [ "0.0.0.0/0" ]
}

resource "aws_security_group_rule" "worker_out_443" {
  security_group_id = aws_security_group.worker.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  cidr_blocks = [ "0.0.0.0/0" ]
}