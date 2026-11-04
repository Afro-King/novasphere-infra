# novasphere-infra

Infrastructure de NovaSphere : deux environnements (`dev`, `prod`) sur AWS, decrits en Terraform, deployes par
GitHub Actions, sans aucun secret en clair.

```
GitHub PR ──► fmt / validate / plan (commentaire PR) ──► merge main ──► apply dev ──► [approbation] ──► apply prod
                                                                    nuit : plan -detailed-exitcode (derive)

Internet ──► ALB :80 (2 AZ) ──► Target Group (health check /) ──► ASG 2..4 (Launch Template, IMDSv2)
                                                                    └─ lit /novasphere/<env>/db_password (SSM)
VPC 10.0.0.0/16 (module registre), subnets publics us-east-1a/b, pas de NAT Gateway
```

## Structure

```
envs/dev/  envs/prod/     un repertoire = un environnement = un state (S3 novasphere-tfstate-pls, verrou natif)
  versions.tf             providers + backend (key novasphere/<env>/terraform.tfstate)
  variables.tf            parametres NON secrets de l'environnement (nom, taille, CIDR admin)
  main.tf                 provider, AMI Debian 13, cle SSH, module de supervision (terraform-aws-ec2-server, tag Git)
  network.tf              VPC (terraform-aws-modules/vpc/aws ~> 6.0)
  web.tf                  SG chaines, Launch Template, ALB, Target Group, Listener, ASG blue/green
  secrets.tf              secret SSM (value_wo + ephemere), role d'instance au moindre privilege
  ci.tf (dev)             confiance OIDC GitHub -> AWS (desactivee dans le Learner Lab)
  bootstrap.sh.tftpl      amorcage court : nginx + lecture du secret par le role de l'instance
keys/novasphere.pub       cle SSH PUBLIQUE (pas un secret)
.github/workflows/        terraform-pr.yml, terraform-apply.yml
```

## Deployer de zero

Prerequis : Terraform >= 1.14 (CI : 1.17.1), AWS CLI v2, credentials valides (`aws sts get-caller-identity`).

```bash
# 1. Bucket de state (une fois par equipe)
aws s3api create-bucket --bucket novasphere-tfstate-pls --region us-east-1
aws s3api put-bucket-versioning --bucket novasphere-tfstate-pls --versioning-configuration Status=Enabled

# 2. Cle SSH (la publique est versionnee dans keys/)
ssh-keygen -t ed25519 -f ~/.ssh/novasphere -N ""

# 3. Chaque environnement, depuis son repertoire (la cible est visible dans le chemin)
cd envs/dev  && terraform init && terraform plan -out=tfplan && terraform apply tfplan
cd ../prod   && terraform init && terraform plan -out=tfplan && terraform apply tfplan
curl http://$(terraform output -raw alb_dns_name)
```

Aucune valeur secrete a fournir : le mot de passe applicatif est genere par une ressource ephemere et envoye
a Parameter Store en ecriture seule.

## Deploiement normal : par la CI

1. Branche + pull request : le workflow `Terraform PR` poste le plan de `dev` et de `prod` en commentaire.
2. Relecture du plan, merge sur `main` : `apply-dev`, puis `apply-prod` attend l'approbation (environnement `prod`).
3. Toutes les nuits (ou `Run workflow`) : job `drift`, en echec si la realite differe du code.

Configuration GitHub :
- Environnement `prod` avec relecteur requis.
- Compte standard : variable `AWS_ROLE_ARN` = output `ci_role_arn` (OIDC, apres `enable_oidc = true`).
- Learner Lab (OIDC interdit) : secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
  = credentials TEMPORAIRES du lab, a remettre a jour a chaque session (`~/set-github-secrets.sh`).

## Fin de journee

```bash
cd envs/prod && terraform destroy
cd ../dev    && terraform destroy
```

ALB et ASG sont factures a l'heure : rien ne tourne entre deux sessions. Tout se redeploie en quelques minutes.

## Documents

- [CONTRIBUTING.md](CONTRIBUTING.md) — conventions d'equipe
- [SECURITE.md](SECURITE.md) — secrets, IAM, scan checkov, contraintes du Learner Lab
- [ARCHITECTURE.md](ARCHITECTURE.md) — decisions d'architecture
