locals {
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  nextcloud_userdata = templatefile("${path.module}/userdata/nextcloud.sh.tftpl",
    {
      efs_dns = aws_efs_file_system.efs.dns_name,
      db_name = aws_db_instance.nextcloud_db.db_name,
      db_host = aws_db_instance.nextcloud_db.address,
      db_user = aws_db_instance.nextcloud_db.username,
      db_pass = random_password.rds_nextcloud.result,
      fqdn    = aws_route53_record.nextcloud.fqdn,
  })
}

resource "aws_lb" "nextcloud" {
  name               = "${local.name}-nextcloud-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nextcloud_sg.id]
  subnets            = aws_subnet.public_subnet[*].id

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-lb"
  })
}

resource "aws_lb_listener" "nextcloud_listener" {
  load_balancer_arn = aws_lb.nextcloud.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nextcloud_target_group.arn
  }
}

resource "aws_route53_record" "nextcloud" {
  zone_id = data.aws_route53_zone.training.zone_id
  name    = "lgarrabos.${data.aws_route53_zone.training.name}"
  type    = "A"
  alias {
    name                   = aws_lb.nextcloud.dns_name
    zone_id                = aws_lb.nextcloud.zone_id
    evaluate_target_health = true
  }
}

resource "random_password" "rds_nextcloud" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


data "aws_route53_zone" "training" {
  name = "training.akiros.it"
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
  encrypted      = true

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
    cidr_block     = "0.0.0.0/0"
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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}




resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet[0].id
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = merge(local.tags, {
    Name = "lgarrabos-tp04-ex02-bastion"
  })
}

resource "aws_lb_target_group" "nextcloud_target_group" {
  name     = "${local.name}-nextcloud-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lgarrabos_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-tg"
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
    cidr_blocks = ["13.38.14.53/32"] # IP de l'instance cloud9 de l'utilisateur
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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

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

resource "aws_db_subnet_group" "nextcloud_db_subnet_group" {
  name       = "${local.name}-nextcloud-db-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-db-subnet-group"
  })
}

resource "aws_security_group" "nextcloud_db_sg" {
  name   = "${local.name}-nextcloud-db-sg"
  vpc_id = aws_vpc.lgarrabos_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.nextcloud_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-db-sg"
  })
}

resource "aws_db_instance" "nextcloud_db" {
  allocated_storage      = 10
  db_name                = "nextcloud_db"
  engine                 = "mysql"
  engine_version         = "8.0"
  identifier             = "lgarrabos-db"
  instance_class         = "db.t4g.micro"
  username               = "toto"
  password               = "12345678"
  db_subnet_group_name   = aws_db_subnet_group.nextcloud_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.nextcloud_db_sg.id]
  multi_az               = true
  skip_final_snapshot    = true

  tags = merge(local.tags, {
    Name = "${local.name}-nextcloud-db"
  })
}

data "aws_ami" "nextcloud" {
  most_recent = true

  filter {
    name   = "name"
    values = ["lgarrabos-tp7-nextcloud-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = ["self"]
}

resource "aws_launch_template" "nextcloud_lt" {
  name_prefix   = "lgarrabos-tp7-nextcloud-lt-"
  image_id      = data.aws_ami.nextcloud.id
  instance_type = "t3.micro"

  key_name = aws_key_pair.nextcloud.key_name

  network_interfaces {
    subnet_id                   = aws_subnet.private_subnet[1].id
    security_groups             = [aws_security_group.nextcloud_sg.id]
    associate_public_ip_address = false
  }

  tags = merge(local.tags, {
    Name = "lgarrabos"
  })
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name  = "lgarrabos"
      Owner = "lgarrabos"
    }
  }
  tag_specifications {
    resource_type = "volume"

    tags = {
      Name  = "lgarrabos"
      Owner = "lgarrabos"
    }
  }
  tag_specifications {
    resource_type = "network-interface"

    tags = {
      Name  = "lgarrabos"
      Owner = "lgarrabos"
    }
  }

}

resource "aws_autoscaling_group" "nextcloud_asg" {
  name                      = "${local.user}-tp7-nextcloud"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.nextcloud_lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = aws_subnet.private_subnet[*].id

  target_group_arns = [aws_lb_target_group.nextcloud_target_group.arn]

  tag {
    key                 = "Owner"
    value               = local.user
    propagate_at_launch = false
  }
  tag {
    key                 = "Name"
    value               = "${local.user}-tp7-nextcloud-instance"
    propagate_at_launch = true
  }
}


output "nextcloud_fqdn" {
  value       = aws_route53_record.nextcloud.name
  description = "Le FQDN de l'application Nextcloud"
}


data "aws_availability_zones" "available" {
  state = "available"
}

