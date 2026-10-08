# Latest Amazon Linux 2023 (x86) published by Amazon
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "app" {
  name                   = "${var.name}-app-lt"
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app.id]
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tftpl", {
    repo_url   = var.repo_url
    region     = var.region
    prefix     = var.name
    db_host    = aws_db_instance.main.address
    log_bucket = aws_s3_bucket.logs.bucket
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app", Project = "srushti-ha-webapp", ManagedBy = "Terraform" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-app-asg"
  vpc_zone_identifier       = aws_subnet.app[*].id
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  health_check_type         = "ELB"
  health_check_grace_period = 360
  target_group_arns         = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Launch before terminating: capacity never drops during replacements
  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 200
  }

  # Rolling replacement whenever the launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 360
    }
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                      = "${var.name}-cpu-target-50"
  autoscaling_group_name    = aws_autoscaling_group.app.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 360

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}