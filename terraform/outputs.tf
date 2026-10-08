output "vpc_id" { value = aws_vpc.main.id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "db_subnet_ids" { value = aws_subnet.db[*].id }