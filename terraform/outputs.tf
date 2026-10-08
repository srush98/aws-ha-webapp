output "vpc_id" { value = aws_vpc.main.id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "db_subnet_ids" { value = aws_subnet.db[*].id }
output "db_endpoint" { value = aws_db_instance.main.address }
output "instance_profile" { value = aws_iam_instance_profile.app.name }