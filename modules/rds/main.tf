resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.project}-db-subnet-group" })
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project}-postgres"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.micro"  # Free tier eligible
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # pgvector requires postgres 15+ — enable the parameter group
  parameter_group_name = aws_db_parameter_group.postgres15.name

  # Free tier settings
  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true
  backup_retention_period = 1

  # Cost optimisation
  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = merge(var.tags, { Name = "${var.project}-postgres" })
}

# Parameter group for PostgreSQL 15 (required for pgvector)
resource "aws_db_parameter_group" "postgres15" {
  name   = "${var.project}-postgres15"
  family = "postgres15"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.tags
}
