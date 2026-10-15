# =====================================================================
# Application Load Balancer (public) -> app servers on 8080
# The HTTPS listener lives in dns.tf because it needs the ACM certificate
# =====================================================================

# Internet-facing ALB spread across both public subnets
resource "aws_lb" "app" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "${var.name}-alb" }
}

# App servers (Tomcat on 8080); the ASG in compute.tf registers instances here
resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-app-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 30 # seconds to drain connections before removal

  # Healthy after 2 passing checks, unhealthy after 2 failures (20s apart)
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 20
    matcher             = "200"
  }

  # Sticky sessions: keep a user on the same server for 1 hour
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600
    enabled         = true
  }
}

# HTTP -> HTTPS (permanent redirect)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
