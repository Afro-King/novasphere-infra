# ---------- Security Groups chaines ----------
resource "aws_security_group" "alb" {
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
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
    environment = var.environment
  }))

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
  name                      = "novasphere-${var.environment}-web"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = module.vpc.public_subnets
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag { # TODO S04 : propager Name aux instances
    key                 = "Name"
    value               = "novasphere-${var.environment}-web"
    propagate_at_launch = true
  }
}
