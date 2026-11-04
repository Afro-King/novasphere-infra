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

variable "instance_type" {
  description = "Type des instances EC2"
  type        = string
  default     = "t3.small"
}
