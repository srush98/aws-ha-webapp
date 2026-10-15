# ---------- DB connection settings in SSM Parameter Store ----------
# App servers read these at boot (see iam.tf: ssm:GetParameter on /<name>/db/*)

# JDBC URL; TLS is required for the connection to RDS
resource "aws_ssm_parameter" "db_url" {
  name  = "/${var.name}/db/url"
  type  = "String"
  value = "jdbc:mysql://${aws_db_instance.main.address}:3306/jwt?sslMode=REQUIRED"
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.name}/db/user"
  type  = "String"
  value = aws_db_instance.main.username
}

# Generated password from database.tf
resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.name}/db/password"
  type  = "SecureString" # encrypted with the AWS-managed KMS key
  value = random_password.db.result
}
