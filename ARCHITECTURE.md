# Decisions d'architecture — NovaSphere

| # | Sujet | Choix | Ecarte | Pourquoi |
|---|---|---|---|---|
| 1 | State | Backend S3 `novasphere-tfstate-pls`, versionne, chiffre, `use_lockfile = true` | State local ; table DynamoDB | Partage + verrou natif (ecriture conditionnelle S3, 412) ; DynamoDB deprecie par HashiCorp |
| 2 | Environnements | Un repertoire par environnement (`envs/dev`, `envs/prod`), un state chacun | Workspaces | La cible est visible dans le chemin ; backend/droits/versions de module separables. Workspaces reserves aux environnements ephemeres identiques |
| 3 | Parametres d'environnement | Valeurs par defaut dans `envs/<env>/variables.tf` | `terraform.tfvars` commite | `*.tfvars` est ignore par Git (regle non negociable) : la CI ne le verrait pas |
| 4 | Modules | `terraform-aws-ec2-server` (depot Git, `ref=v1.1.0`) pour la supervision ; VPC du registre public | Tout ecrire soi-meme ; module pour chaque ressource | Logique NovaSphere ecrite et versionnee, briques standard reutilisees ; pas de module d'une seule ressource sans logique |
| 5 | Reseau | VPC 2 AZ, subnets publics, `enable_nat_gateway = false` | NAT Gateway + subnets prives | ~0,05 $/h + trafic ; instances protegees par leurs SG (port 80 depuis le SG de l'ALB uniquement) |
| 6 | Calcul | Launch Template + ASG (2..4), health check ELB, IMDSv2 exige | Instance unique | Haute disponibilite, remplacement automatique (mesure : ~2 min 35) |
| 7 | Deploiement d'une nouvelle version | ASG blue/green : nom = version du LT, `create_before_destroy`, `wait_for_elb_capacity = 2` | `instance_refresh` | `StartInstanceRefresh` bloque par une SCP du Learner Lab ; le blue/green donne zero coupure (23/23 requetes en 200) |
| 8 | Configuration | `bootstrap.sh` court (nginx + lecture du secret) | Ansible au demarrage ; image Packer | Exigence "amorcage court et reproductible" ; Ansible (ansible-pull / SSM Run Command) en bonus futur |
| 9 | Secret applicatif | SSM `SecureString`, `ephemeral "random_password"` -> `value_wo` (+ `value_wo_version`) | Variable `sensitive` ; Secrets Manager ; `TF_VAR_` en CI | Absent du code, du state, du user_data et de la CI ; Secrets Manager payant et rotation non requise |
| 10 | IAM des instances | Role dedie `ssm:GetParameter` sur `/novasphere/<env>/*` (`create_iam_role`) | `Resource = "*"` | Moindre privilege ; Learner Lab : `LabInstanceProfile` impose (CreateRole interdit), documente |
| 11 | CI/CD | GitHub Actions : plan en PR (commentaire), apply du plan sauvegarde au merge, prod derriere environnement protege, derive nocturne | Apply manuel depuis les postes | Revue sur l'effet reel ; plus personne n'a besoin de cles AWS pour deployer |
| 12 | Authentification CI | OIDC (code pret, `enable_oidc`) ; Learner Lab : credentials temporaires du lab en secrets | Cle d'acces statique permanente | OIDC = jeton par execution, 1 h, role restreint au depot ; le lab interdit la creation du role |
| 13 | IP d'administration | `admin_cidr` fixe en variable | `data "http" "my_ip"` | Sur la CI, l'IP du runner change a chaque run => derive permanente du SG |

Hors perimetre, assume : HTTPS (pas de domaine/ACM dans le lab), WAF, logs d'acces ALB, KMS dedie.
