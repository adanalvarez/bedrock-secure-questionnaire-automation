# Build and deploy security-questions-lambda
data "archive_file" "security_questions_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/securityquestions/source/"
  output_path = "${path.module}/lambdas/securityquestions/lambda_function.zip"
}

resource "aws_lambda_function" "security_questions" {
  function_name = "security-questions-lambda"
  role          = aws_iam_role.lambda_role_security_questions.arn
  handler       = "securityquestions.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.security_questions_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.security_questions_lambda_zip.output_path)

  memory_size = 1024
  timeout     = 600

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.security_data.id
      MODEL_ARN         = local.model_arn
      REGION_NAME       = var.aws_region
    }
  }
}

# Build and deploy sync-knowledge-base-lambda
data "archive_file" "sync_knowledge_base_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/syncknowledgebase/source/"
  output_path = "${path.module}/lambdas/syncknowledgebase/lambda_function.zip"
}

resource "aws_lambda_function" "sync_knowledge_base" {
  function_name = "sync-knowledgebase-lambda"
  role          = aws_iam_role.lambda_role_sync_kb.arn
  handler       = "syncknowledgebase.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.sync_knowledge_base_lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.sync_knowledge_base_lambda_zip.output_path)

  memory_size = 1024
  timeout     = 600

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.security_data.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.security_data.data_source_id
      REGION_NAME       = var.aws_region
    }
  }
}
