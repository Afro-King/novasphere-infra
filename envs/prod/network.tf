# VPC sur deux zones : brique standard => module du registre public (regle S02)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "novasphere-${var.environment}"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway      = false # TODO S04 : pas de NAT Gateway (~0,05 $/h + trafic)
  map_public_ip_on_launch = true  # TODO S04 : IP publique au lancement => sortie Internet via l'IGW (apt install nginx)
}
