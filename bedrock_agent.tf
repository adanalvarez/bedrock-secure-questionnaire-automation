resource "aws_bedrockagent_knowledge_base" "security_data" {
  name        = "knowledge-base-security"
  description = "Security data knowledge base"
  role_arn    = aws_iam_role.bedrock_rds_instance_role.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = module.aurora_postgresql_serverless.cluster_master_user_secret[0].secret_arn
      database_name          = module.aurora_postgresql_serverless.cluster_database_name
      resource_arn           = module.aurora_postgresql_serverless.cluster_arn
      table_name             = "bedrock_integration.bedrock_knowledge_base"

      field_mapping {
        metadata_field    = "metadata"
        primary_key_field = "id"
        text_field        = "chunks"
        vector_field      = "embedding"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "security_data" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.security_data.id
  name              = "security-data-knowledge-base"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.security_data_bucket.arn
    }
  }
}
