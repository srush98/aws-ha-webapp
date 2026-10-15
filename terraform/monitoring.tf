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

# Outbound HTTP: package mirrors (same as the app tier)
resource "aws_vpc_security_group_egress_rule" "mon_http" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
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

resource "aws_iam_role_policy_attachment" "monitoring_ssm_core" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

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
      }
    ]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.name}-monitoring-ec2-profile"
  role = aws_iam_role.monitoring.name
}