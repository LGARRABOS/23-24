locals {
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

resource "aws_vpc" "lgarrabos_vpc" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.lgarrabos_vpc.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name}-public-subnet-${count.index + 1}"
  })
}

resource "aws_subnet" "private_subnet" {
  count             = 3
  vpc_id            = aws_vpc.lgarrabos_vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.tags, {
    Name = "${local.name}-private-subnet-${count.index + 1}"
  })
}

resource "aws_internet_gateway" "lgarrabos_igw" {
  vpc_id = aws_vpc.lgarrabos_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = merge(local.tags, {
    Name = "${local.name}-nat-gateway"
  })
}

resource "aws_efs_file_system" "efs" {
  creation_token = "lgarrabos-tp"
  encrypted = true

  tags = merge(local.tags, {
    Name = "${local.name}-efs"
  })
}

resource "aws_efs_mount_target" "efs_mount" {
  count           = 3
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private_subnet[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  name        = "${local.name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.lgarrabos_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-efs-sg"
  })
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.lgarrabos_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lgarrabos_igw.id
  }

  tags = merge(local.tags, {
    Name = "${local.name}-public-route-table"
  })
}

resource "aws_route_table" "private_route_table" {
  count  = 3
  vpc_id = aws_vpc.lgarrabos_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = merge(local.tags, {
    Name = "${local.name}-private-route-table-${count.index + 1}"
  })
}

resource "aws_route_table_association" "public_association" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_association" {
  count          = 3
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table[count.index].id
}

data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet[0].id
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = merge(local.tags, {
    Name = "lgarrabos-tp04-ex02-bastion"
  })
}

resource "aws_instance" "nextcloud" {
  ami                         = data.aws_ami.linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_subnet[1].id
  key_name                    = aws_key_pair.nextcloud.key_name
  associate_public_ip_address = false

  vpc_security_group_ids = [aws_security_group.nextcloud_sg.id]

  user_data = <<-EOF
#!/bin/bash
yaptum update -y
apt install -y amazon-efs-utils
mkdir -p /mnt/efs
mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /mnt/efs
echo "${aws_efs_file_system.efs.id}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab
sudo chmod 777 /mnt/efs
EOF

  tags = merge(local.tags, {
    Name = "lgarrabos-tp04-ex02-nextcloud"
  })
}


resource "aws_security_group" "bastion_sg" {
  name        = "${local.name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.lgarrabos_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["35.180.44.163/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-bastion-sg"
  })
}

resource "aws_security_group" "nextcloud_sg" {
  name        = "${local.name}-nextcloud-sg"
  description = "Security group for Nextcloud instance"
  vpc_id      = aws_vpc.lgarrabos_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-sg"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}