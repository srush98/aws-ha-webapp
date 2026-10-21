# =====================================================================
# Monitoring: Prometheus server (private, no inbound ports; SSM access)
# =====================================================================

# ---------- Security group ----------
resource "aws_security_group" "monitoring" {
  name        = "${var.name}-monitoring-sg"
  description = "Prometheus - no inbound; scrapes app on 9100"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.name}-monitoring-sg" }
}

# Outbound HTTPS: SSM tunnel, Slack webhook, downloads, probing the site
resource "aws_vpc_security_group_egress_rule" "mon_https" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Outbound 9100 to app servers only (node_exporter)
resource "aws_vpc_security_group_egress_rule" "mon_to_app_node" {
  security_group_id            = aws_security_group.monitoring.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
}

# App servers accept 9100 from the monitoring server only
resource "aws_vpc_security_group_ingress_rule" "app_node_from_mon" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = 9100
  to_port                      = 9100
}

# ---------- IAM ----------
resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-monitoring-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json # reused from iam.tf
}

# Session Manager access (no SSH)
resource "aws_iam_role_policy_attachment" "monitoring_ssm_core" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least privilege: discover app servers; read monitoring secrets (e.g. Slack webhook)
resource "aws_iam_role_policy" "monitoring" {
  name = "${var.name}-monitoring-policy"
  role = aws_iam_role.monitoring.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 service discovery; Describe* has no resource-level permissions
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeAvailabilityZones"]
        Resource = "*"
      },
      {
        # Only the monitoring secrets, never /tf/db/*
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name}/monitoring/*"
      },
      {
        # Read config; cannot write or delete it
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.monitoring_config.arn}/monitoring/*"
      },
      {
        # Needed by `aws s3 cp --recursive`
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.monitoring_config.arn
        Condition = { StringLike = { "s3:prefix" = ["monitoring/*"] } }
      }
    ]
  })
}

# EC2 attaches roles through an instance profile
resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.name}-monitoring-ec2-profile"
  role = aws_iam_role.monitoring.name
}

# ---------- Prometheus server ----------
# Single instance running Prometheus, Alertmanager and Blackbox exporter
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.monitoring_instance_type
  subnet_id              = aws_subnet.app[0].id # private, has NAT
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name
  depends_on             = [aws_nat_gateway.nat, aws_route_table_association.app] # Boot script downloads from GitHub: internet via the NAT must exist first
  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  user_data = templatefile("${path.module}/userdata-monitoring.sh.tftpl", {
    region               = var.region
    name                 = var.name
    config_bucket        = aws_s3_bucket.monitoring_config.bucket
    config_hash          = local.monitoring_config_hash
    prometheus_version   = var.prometheus_version
    alertmanager_version = var.alertmanager_version
    blackbox_version     = var.blackbox_version
    grafana_version      = var.grafana_version
    grafana_rpm_sha256   = var.grafana_rpm_sha256
  })

  user_data_replace_on_change = true # config change => new server

  lifecycle {
    ignore_changes = [ami] # no surprise replacement on new AMIs
  }

  tags = { Name = "${var.name}-monitoring" } # NOT tf-app, or it would scrape itself
}

# ---------- Grafana admin password ----------
# Generated, never typed by a human; stored as a SecureString (and in state, like the DB password)
resource "random_password" "grafana" {
  length           = 24
  special          = true
  override_special = "-_" # safe in env files and shells
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name  = "/${var.name}/monitoring/grafana_admin_password"
  type  = "SecureString"
  value = random_password.grafana.result
}

# ---------- Monitoring config bucket: private, encrypted, versioned, TLS-only ----------
resource "aws_s3_bucket" "monitoring_config" {
  bucket        = "${var.name}-monitoring-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lab: lets `terraform destroy` remove it
  tags          = { Name = "${var.name}-monitoring-config" }
}

resource "aws_s3_bucket_public_access_block" "monitoring_config" {
  bucket                  = aws_s3_bucket.monitoring_config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_config" {
  bucket = aws_s3_bucket.monitoring_config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "monitoring_config" {
  bucket = aws_s3_bucket.monitoring_config.id
  versioning_configuration {
    status = "Enabled" # history of every config change
  }
}

data "aws_iam_policy_document" "monitoring_config_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.monitoring_config.arn, "${aws_s3_bucket.monitoring_config.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "monitoring_config" {
  bucket     = aws_s3_bucket.monitoring_config.id
  policy     = data.aws_iam_policy_document.monitoring_config_tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.monitoring_config]
}

# ---------- Config files: rendered by Terraform, uploaded to S3 ----------
locals {
  monitoring_files = {
    "prometheus/prometheus.yml" = templatefile("${path.module}/monitoring/prometheus.yml.tftpl", {
      region   = var.region
      name     = var.name
      app_fqdn = local.app_fqdn
    })
    "prometheus/rules/alerts.yml" = templatefile("${path.module}/monitoring/alerts.yml.tftpl", {
      cpu_threshold  = var.cpu_alert_threshold
      disk_threshold = var.disk_alert_threshold
      ssl_days       = var.ssl_expiry_alert_days
    })
    "alertmanager/alertmanager.yml"                   = file("${path.module}/monitoring/alertmanager.yml")
    "blackbox/blackbox.yml"                           = file("${path.module}/monitoring/blackbox.yml")
    "grafana/grafana.ini"                             = file("${path.module}/monitoring/grafana.ini")
    "grafana/provisioning/datasources/prometheus.yml" = file("${path.module}/monitoring/grafana-datasource.yml")
    "grafana/provisioning/dashboards/dashboards.yml"  = file("${path.module}/monitoring/grafana-dashboards.yml")
  }
}

resource "aws_s3_object" "monitoring" {
  for_each     = local.monitoring_files
  bucket       = aws_s3_bucket.monitoring_config.id
  key          = "monitoring/${each.key}"
  content      = each.value
  content_type = "text/yaml"
}

# Every *.json in monitoring/dashboards/ is uploaded; adding a dashboard = adding a file
resource "aws_s3_object" "dashboards" {
  for_each     = fileset("${path.module}/monitoring/dashboards", "*.json")
  bucket       = aws_s3_bucket.monitoring_config.id
  key          = "monitoring/dashboards/${each.value}"
  source       = "${path.module}/monitoring/dashboards/${each.value}"
  etag         = filemd5("${path.module}/monitoring/dashboards/${each.value}") # re-upload on change
  content_type = "application/json"
}

locals {
  # Changes whenever any config file changes => new user data => server replaced.
  # Referencing the objects also makes Terraform upload them BEFORE the server boots.
  monitoring_config_hash = sha256(jsonencode(merge(
    { for k, o in aws_s3_object.monitoring : k => o.etag },
    { for k, o in aws_s3_object.dashboards : "dashboards/${k}" => o.etag }
  )))
}