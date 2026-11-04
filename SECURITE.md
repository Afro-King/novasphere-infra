# SECURITE.md — NovaSphere

## 1. Les quatre lieux de fuite d'un secret

| Lieu | Risque | Parade retenue |
|---|---|---|
| Code (variable avec `default`, tfvars commite) | `git grep` le trouve en une seconde | Aucune valeur dans le code ; `*.tfvars` ignore par Git |
| State (`terraform.tfstate`, donc le bucket S3) | `sensitive = true` masque l'affichage console **mais la valeur reste en clair dans le state** | Argument en ecriture seule `value_wo` + valeur **ephemere** |
| user_data | Lisible par quiconque a `ec2:DescribeInstanceAttribute` / `DescribeLaunchTemplateVersions` | Le user_data ne contient que le **nom** du parametre |
| Logs (playbook sans `no_log`, plan dans une PR, historique shell) | Fuite indirecte | Le secret ne transite jamais par Terraform vers l'instance : l'instance le lit elle-meme |

## 2. Stockage : Parameter Store SecureString

- `/novasphere/<env>/db_password`, type `SecureString` (chiffre par KMS, cle geree `aws/ssm`, gratuit).
- Secrets Manager ecarte : ~0,40 $/secret/mois, utile seulement si la rotation automatique est exigee (ex. RDS).
- La valeur est produite par `ephemeral "random_password"` et envoyee via `value_wo` : **aucun humain ni aucune CI ne la connait**, rien a stocker dans GitHub.
- **Pourquoi `value_wo_version` est obligatoire avec `value_wo`** : Terraform ne memorise pas une valeur en ecriture seule, il ne peut donc pas detecter qu'elle a change ; c'est l'increment de `value_wo_version` qui declenche l'envoi d'une nouvelle valeur (rotation).

## 3. Preuves (dev, 2026-11-04)

```
git grep "<secret>" $(git rev-list --all)          -> 0 occurrence (historique compris)
terraform state pull | grep -c "<secret>"          -> 0
state : value='' | value_wo=None | has_value_wo=True | value_wo_version=1
user_data du Launch Template | grep -c "<secret>"  -> 0   (contient seulement Name='/novasphere/dev/db_password')
Page servie par l'ALB : "Secret lu depuis Parameter Store : OK" (la valeur n'est jamais affichee)
```

## 4. IAM au moindre privilege

Politique ecrite (`envs/<env>/secrets.tf`) : `ssm:GetParameter` sur
`arn:aws:ssm:us-east-1:<compte>:parameter/novasphere/<env>/*` uniquement, jamais `Resource = "*"`.

Preuve par le simulateur IAM (`aws iam simulate-custom-policy`) sur la politique dev :

```
GetParameter /novasphere/dev/db_password  -> allowed
GetParameter /novasphere/prod/db_password -> implicitDeny
```

**Contrainte du Learner Lab (choix assume)** : `iam:CreateRole` est refuse (403) et
`autoscaling:StartInstanceRefresh` est bloque par une SCP de l'organisation. Le code garde le role dedie
derriere `create_iam_role` (true sur un compte standard) ; dans le lab, les instances utilisent le profil
impose `LabInstanceProfile` (LabRole, qui porte `AmazonSSMManagedInstanceCore` donc `ssm:GetParameter` sur `*`).
Dans le lab, une instance dev **pourrait** donc lire `/novasphere/prod/` : c'est une limite de l'environnement,
pas du code. Sur un compte de production, `create_iam_role = true` applique la politique ci-dessus.

Autres durcissements : IMDSv2 exige (`http_tokens = "required"`), instances joignables uniquement depuis le SG
de l'ALB, pas de SSH sur les instances web.

## 5. Scan statique checkov

`checkov -d envs/dev --framework terraform --compact`

Corriges :
1. **CKV_AWS_23** — toutes les regles de Security Group ont une description (egress ALB et web).
2. **CKV_AWS_131** — l'ALB rejette les en-tetes HTTP invalides (`drop_invalid_header_fields = true`).

Documentes, non corriges (commentaire `#checkov:skip` sur la ressource) :
- **CKV_AWS_260 / CKV_AWS_2** — ALB en HTTP 80 ouvert a Internet : c'est le point d'entree public par conception ;
  le HTTPS demande un domaine et un certificat ACM, indisponibles dans le Learner Lab. Sur un compte de production :
  listener 443 + redirection 80 -> 443.

Ecartes en connaissance de cause (cout / perimetre du module) : logs d'acces ALB (CKV_AWS_91), WAF (CKV2_AWS_28),
cle KMS dediee pour SSM (CKV_AWS_337, 1 $/mois), deletion protection de l'ALB (CKV_AWS_150, incompatible avec le
destroy quotidien).
