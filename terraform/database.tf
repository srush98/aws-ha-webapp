# =====================================================================
# Database: RDS MySQL in the private DB subnets
# =====================================================================

# Generated password: never typed by a human, never in Git (only in state)
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "-_" # avoids characters that break shell scripts and URLs
}

# RDS needs subnets in at least two AZs
resource "aws_db_subnet_group" "main" {
  name        = "${var.name}-db-subnets"
  description = "Private DB subnets (Terraform)"
  subnet_ids  = aws_subnet.db[*].id
  tags        = { Name = "${var.name}-db-subnets" }
}

resource "aws_db_instance" "main" {
  # ----- Engine and size -----
  identifier     = "${var.name}-db"
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = "db.t3.micro"

  # ----- Storage (encrypted at rest) -----
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  # ----- Initial database and credentials (also published in parameters.tf) -----
  db_name  = "jwt"
  username = "admin"
  password = random_password.db.result

  # ----- Network: private, reachable only from the app security group -----
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # single AZ to save cost

  # ----- Backups and maintenance -----
  backup_retention_period    = 7
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  engine_lifecycle_support   = "open-source-rds-extended-support-disabled" # avoid paid extended support

  # Lab settings so `terraform destroy` works cleanly; reverse both in production
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "${var.name}-db" }
}
