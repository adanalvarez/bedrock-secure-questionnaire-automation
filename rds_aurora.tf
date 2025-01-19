resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "${var.database_name}-subnet-group"
  subnet_ids = data.aws_subnets.private.ids
}

module "aurora_postgresql_serverless" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "8.5.0"

  name          = var.database_name
  database_name = var.database_name

  engine         = "aurora-postgresql"
  engine_version = var.engine_version

  instance_class = "db.serverless"
  instances = {
    one = {}
  }

  serverlessv2_scaling_configuration = {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  enable_http_endpoint                = true
  master_username                     = var.admin_user_name
  manage_master_user_password         = true
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.aurora.arn
  iam_database_authentication_enabled = false
  ca_cert_identifier                  = "rds-ca-rsa2048-g1"

  vpc_id               = data.aws_vpc.vpc.id
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = [data.aws_vpc.vpc.cidr_block]
    }
  }

  apply_immediately   = true
  skip_final_snapshot = true
  deletion_protection = true
}

resource "null_resource" "enable_pgvector" {
  # Create the pgvector extension and needed schema/table
  provisioner "local-exec" {
    command = <<-EOT
      # Enable vector extension
      aws rds-data execute-statement \
        --region="${var.aws_region}" \
        --resource-arn="${module.aurora_postgresql_serverless.cluster_arn}" \
        --secret-arn="${module.aurora_postgresql_serverless.cluster_master_user_secret[0].secret_arn}" \
        --database="${var.database_name}" \
        --sql="CREATE EXTENSION IF NOT EXISTS vector"

      # Create the schema
      aws rds-data execute-statement \
        --region="${var.aws_region}" \
        --resource-arn="${module.aurora_postgresql_serverless.cluster_arn}" \
        --secret-arn="${module.aurora_postgresql_serverless.cluster_master_user_secret[0].secret_arn}" \
        --database="${var.database_name}" \
        --sql="CREATE SCHEMA IF NOT EXISTS bedrock_integration"

      # Create the table
      aws rds-data execute-statement \
        --region="${var.aws_region}" \
        --resource-arn="${module.aurora_postgresql_serverless.cluster_arn}" \
        --secret-arn="${module.aurora_postgresql_serverless.cluster_master_user_secret[0].secret_arn}" \
        --database="${var.database_name}" \
        --sql="CREATE TABLE IF NOT EXISTS bedrock_integration.bedrock_knowledge_base (
                 id UUID PRIMARY KEY,
                 metadata JSONB,
                 chunks TEXT,
                 embedding vector(1024)
               )"
    EOT
  }

  depends_on = [module.aurora_postgresql_serverless]
}
