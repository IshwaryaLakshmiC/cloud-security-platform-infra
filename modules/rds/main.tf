# RDS removed — PostgreSQL runs directly on the EC2 instance.
# This avoids free tier restrictions on db.t2.micro/db.t3.micro.
# PostgreSQL 15 + pgvector is installed via EC2 userdata.
# DB connection: localhost:5432 on the EC2 instance.
#
# To re-enable RDS in future: uncomment this module and update
# environments/dev/main.tf to use module.rds outputs.
