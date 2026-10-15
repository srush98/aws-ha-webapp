# ---------- Networking ----------
output "vpc_id" { value = aws_vpc.main.id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "db_subnet_ids" { value = aws_subnet.db[*].id }

# ---------- Database and app servers ----------
output "db_endpoint" { value = aws_db_instance.main.address }
output "instance_profile" { value = aws_iam_instance_profile.app.name }

# ---------- Public entry points ----------
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "app_url" { value = "https://${local.app_fqdn}" }

# ---------- Operations ----------
output "log_bucket" { value = aws_s3_bucket.logs.bucket }
output "monitoring_instance_id" { value = aws_instance.monitoring.id } # use with SSM Session Manager
