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

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.name}/db/password"
  type  = "SecureString" # encrypted with the AWS-managed KMS key
  value = random_password.db.result
}