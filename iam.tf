resource "aws_iam_role" "bedrock_rds_instance_role" {
  name               = "bedrock-rds-instance-role"
  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockRDSInstanceStatementID",
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
        }
      }
    }
  ]
}
EOF
}

# S3 Policy for the RDS role
resource "aws_iam_role_policy" "bedrock_rds_s3_policy" {
  name   = "bedrock-rds-instance-s3-policy"
  role   = aws_iam_role.bedrock_rds_instance_role.id
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ListBucketStatement",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.security_data_bucket.arn}"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": [
            "${data.aws_caller_identity.current.account_id}"
          ]
        }
      }
    },
    {
      "Sid": "S3GetObjectStatement",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "${aws_s3_bucket.security_data_bucket.arn}/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceAccount": [
            "${data.aws_caller_identity.current.account_id}"
          ]
        }
      }
    }
  ]
}
EOF
}

# Policy for Bedrock, RDS, and Secrets Manager
resource "aws_iam_role_policy" "bedrock_rds_secrets_policy" {
  name   = "bedrock-rds-secrets-policy"
  role   = aws_iam_role.bedrock_rds_instance_role.id
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeModelStatement",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      ]
    },
    {
      "Sid": "RdsDescribeStatementID",
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBClusters"
      ],
      "Resource": [
        "${module.aurora_postgresql_serverless.cluster_arn}"
      ]
    },
    {
      "Sid": "DataAPIStatementID",
      "Effect": "Allow",
      "Action": [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement"
      ],
      "Resource": [
        "${module.aurora_postgresql_serverless.cluster_arn}"
      ]
    },
    {
      "Sid": "SecretsManagerGetStatement",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${module.aurora_postgresql_serverless.cluster_master_user_secret[0].secret_arn}"
      ]
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Role for security-questions-lambda
resource "aws_iam_role" "lambda_role_security_questions" {
  name               = "security-questions-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissions for logs, S3 access, and Bedrock calls
data "aws_iam_policy_document" "lambda_permissions_security_questions" {
  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.security_questions_bucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.security_questions_bucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "bedrock:RetrieveAndGenerate",
      "bedrock:Retrieve"
    ]
    resources = [
      aws_bedrockagent_knowledge_base.security_data.arn
    ]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "bedrock:getInferenceProfile",
      "bedrock:InvokeModel"
    ]
    resources = [local.model_arn]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "bedrock:InvokeModel"
    ]
    resources = [local.foundation_model_arn]
  }
}

resource "aws_iam_role_policy" "lambda_policy_security_questions" {
  name   = "security-questions-lambda-policy"
  role   = aws_iam_role.lambda_role_security_questions.id
  policy = data.aws_iam_policy_document.lambda_permissions_security_questions.json
}

# Role for sync-knowledgebase-lambda
resource "aws_iam_role" "lambda_role_sync_kb" {
  name               = "sync-knowledgebase-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Permissions for logs and starting ingestion
data "aws_iam_policy_document" "lambda_permissions_sync_kb" {
  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "bedrock:StartIngestionJob"
    ]
    resources = [aws_bedrockagent_knowledge_base.security_data.arn]
  }
}

resource "aws_iam_role_policy" "lambda_policy_sync_kb" {
  name   = "sync-knowledgebase-lambda-policy"
  role   = aws_iam_role.lambda_role_sync_kb.id
  policy = data.aws_iam_policy_document.lambda_permissions_sync_kb.json
}
