provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NovaSphere"
      Environment = var.environment
      Owner       = var.owner
    }
  }
}

# S07 : l'IP n'est plus decouverte dynamiquement (data "http" "my_ip") : sur la CI
# ce serait l'IP du runner, differente a chaque run => derive permanente du SG.
locals {
  admin_cidr = var.admin_cidr
}

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "novasphere-${var.environment}-${var.owner}"
  public_key = file("${path.module}/../../keys/novasphere.pub")
}

# S04 : le serveur web unique (module "web") est remplace par ALB + ASG, voir web.tf

module "monitoring_dev" {
  source = "git::https://github.com/Afro-King/terraform-aws-ec2-server.git?ref=v1.1.0"

  name                   = "${var.environment}-monitoring"
  ami_id                 = data.aws_ami.debian.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  admin_cidr             = local.admin_cidr
  open_ports             = []
  enable_monitoring_port = true

  tags = {
    Environment = var.environment
    Role        = "monitoring"
  }
}
