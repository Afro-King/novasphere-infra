variable "name" {
  description = "Nom logique du serveur (web, monitoring...)"
  type        = string
}

variable "ami_id" {
  description = "Identifiant de l'image Debian"
  type        = string
}

variable "instance_type" {
  description = "Type de l'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nom de la clé SSH AWS"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR autorisé en SSH"
  type        = string

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "Le port SSH ne doit pas être ouvert à 0.0.0.0/0."
  }
}

variable "open_ports" {
  description = "Ports TCP ouverts sur Internet, par exemple [80]"
  type        = list(number)
  default     = []
}

variable "tags" {
  description = "Tags supplémentaires à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
