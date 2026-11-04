# Importe en S06 : cree a la main dans la console, repris par Terraform sans modification
resource "aws_ssm_parameter" "app_banner" {
  name  = "/novasphere/dev/app_banner"
  type  = "String"
  value = "Bienvenue sur NovaSphere"
}
