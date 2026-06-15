# PostgreSQL runs on EC2 localhost — these outputs return local values
output "db_endpoint" { value = "localhost:5432" }
output "db_host"     { value = "localhost" }
output "db_port"     { value = 5432 }
output "db_name"     { value = var.db_name }
output "db_username" { value = var.db_username }
