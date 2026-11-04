# ---------- Security Groups chaines ----------
resource "aws_security_group" "alb" {
  #checkov:skip=CKV_AWS_260:ALB public par conception, HTTP 80 ouvert a Internet ; pas de domaine ni certificat ACM dans le Learner Lab (voir SECURITE.md)
  name        = "novasphere-${var.environment}-alb"
  description = "ALB : HTTP depuis Internet"
  vpc_id      = module.vpc.vpc_id

  ingress { # TODO S04 : 80 depuis 0.0.0.0/0
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # TODO S04 : egress tout
    description = "Vers les instances et Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "novasphere-${var.environment}-web"
  description = "Instances web : HTTP depuis le SG ALB uniquement"
  vpc_id      = module.vpc.vpc_id

  ingress { # TODO S04 : 80 par REFERENCE au SG de l'ALB, pas de CIDR
    description     = "HTTP depuis le SG ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress { # TODO S04 : egress tout (apt, et plus tard SSM)
    description = "Sortie apt et API AWS (SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Launch Template : le moule des instances ----------
resource "aws_launch_template" "web" {
  name_prefix            = "novasphere-${var.environment}-"
  image_id               = data.aws_ami.debian.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  # Le user_data ne contient QUE le nom du parametre, jamais sa valeur
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
    environment = var.environment
    param_name  = aws_ssm_parameter.db_password.name
  }))

  iam_instance_profile { # TODO S05 : attacher le profil d'instance au Launch Template
    arn = local.instance_profile_arn
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 exige (critere C du projet)
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "novasphere-${var.environment}-web" }
  }
}

# ---------- ALB + Target Group + Listener ----------
resource "aws_lb" "web" {
  name               = "novasphere-${var.environment}"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true # checkov CKV_AWS_131 corrige
}

resource "aws_lb_target_group" "web" {
  name                 = "novasphere-${var.environment}-web"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:Pas de certificat ACM sans domaine dans le Learner Lab ; HTTPS prevu sur un compte de production (voir SECURITE.md)
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ---------- Auto Scaling Group ----------
resource "aws_autoscaling_group" "web" {
  # Blue/green : le nom porte la version du Launch Template. Nouvelle version =>
  # nouvel ASG, cree AVANT la destruction de l'ancien (instance_refresh interdit
  # par la SCP du Learner Lab).
  name                      = "novasphere-${var.environment}-web-v${aws_launch_template.web.latest_version}"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = module.vpc.public_subnets
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120
  wait_for_elb_capacity     = 2 # Terraform attend 2 instances healthy dans l'ALB

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  tag { # TODO S04 : propager Name aux instances
    key                 = "Name"
    value               = "novasphere-${var.environment}-web"
    propagate_at_launch = true
  }
}
