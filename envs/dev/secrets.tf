# ---------- Le secret : genere, envoye, jamais memorise ----------
# Ressource EPHEMERE : sa valeur n'existe que pendant l'execution de Terraform,
# elle n'est ecrite ni dans le plan ni dans le state.
ephemeral "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name = "/novasphere/${var.environment}/db_password"
  type = "SecureString" # chiffre par KMS (cle geree aws/ssm)

  # Argument en ECRITURE SEULE (TF >= 1.11) : envoye a AWS, absent du state.
  value_wo = ephemeral.random_password.db.result
  # Terraform ne connait pas la valeur => il ne peut pas detecter un changement.
  # On incremente cette version pour forcer l'envoi d'une nouvelle valeur (rotation).
  value_wo_version = 1
}

# ---------- Lecture au moindre privilege : role d'instance ----------
# Learner Lab : iam:CreateRole est interdit (403). On utilise alors le profil impose
# LabInstanceProfile (LabRole, trop large : voir SECURITE.md). Sur un vrai compte :
# create_iam_role = true => role dedie limite a /novasphere/<env>/*.
variable "create_iam_role" {
  description = "true sur un compte standard ; false dans le Learner Lab (CreateRole interdit)"
  type        = bool
  default     = false
}

data "aws_iam_instance_profile" "lab" {
  count = var.create_iam_role ? 0 : 1
  name  = "LabInstanceProfile"
}

locals {
  instance_profile_arn = var.create_iam_role ? aws_iam_instance_profile.web[0].arn : data.aws_iam_instance_profile.lab[0].arn
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  count              = var.create_iam_role ? 1 : 0
  name               = "novasphere-${var.environment}-web"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy" "read_secrets" {
  count = var.create_iam_role ? 1 : 0
  name  = "read-secrets"
  role  = aws_iam_role.web[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      # TODO S05 : l'ARN du chemin de CET environnement seulement (jamais "*")
      Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/novasphere/${var.environment}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "web" {
  count = var.create_iam_role ? 1 : 0
  name  = "novasphere-${var.environment}-web"
  role  = aws_iam_role.web[0].name
}
