variable "aws_region" {
  description = "Région AWS utilisée"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environnement déployé"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Trigramme du propriétaire"
  type        = string
  default     = "pls"
}

variable "admin_cidr" {
  description = "CIDR administrateur (SSH et port 9100 de la supervision), jamais 0.0.0.0/0"
  type        = string
  default     = "46.193.58.47/32"
}

variable "instance_type" {
  description = "Type des instances EC2"
  type        = string
  default     = "t3.small"
}
