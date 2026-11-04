# ---------- Confiance OIDC GitHub Actions -> AWS (cible du module) ----------
# GitHub emet un jeton signe par execution ; AWS le verifie et delivre des credentials
# temporaires (1 h) pour CE role, restreint a CE depot. Aucun secret stocke.
#
# Learner Lab : iam:CreateRole / CreateOpenIDConnectProvider interdits => enable_oidc = false
# et la CI utilise les credentials temporaires du lab en secrets GitHub (voir SECURITE.md).
# Le fournisseur OIDC se cree UNE fois par compte : il n'est declare que dans envs/dev.
variable "enable_oidc" {
  description = "true sur un compte standard ; false dans le Learner Lab"
  type        = bool
  default     = false
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.enable_oidc ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Pas de thumbprint_list : optionnel depuis le provider 5.81
}

resource "aws_iam_role" "ci" {
  count = var.enable_oidc ? 1 : 0
  name  = "novasphere-ci-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github[0].arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:Afro-King/novasphere-infra:*" }
      }
    }]
  })
}

# TP : AdministratorAccess tolere ; en projet, une politique restreinte (composante securite).
resource "aws_iam_role_policy_attachment" "ci" {
  count      = var.enable_oidc ? 1 : 0
  role       = aws_iam_role.ci[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

output "ci_role_arn" {
  description = "A renseigner dans la variable GitHub AWS_ROLE_ARN (mode OIDC)"
  value       = var.enable_oidc ? aws_iam_role.ci[0].arn : "OIDC desactive (Learner Lab)"
}
