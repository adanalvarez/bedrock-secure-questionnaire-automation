resource "aws_s3_bucket" "security_data_bucket" {
  bucket        = "security-data-knowledge-base-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "security_data_bucket_public_access_block" {
  bucket = aws_s3_bucket.security_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "security_data_bucket_versioning" {
  bucket = aws_s3_bucket.security_data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "security_data_notification" {
  bucket = aws_s3_bucket.security_data_bucket.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.sync_knowledge_base.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "security_data_lambda_invoke_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync_knowledge_base.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.security_data_bucket.arn
}

resource "aws_s3_bucket" "security_questions_bucket" {
  bucket        = "security-questions-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "security_questions_bucket_public_access_block" {
  bucket = aws_s3_bucket.security_questions_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "security_questions_bucket_versioning" {
  bucket = aws_s3_bucket.security_questions_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create a placeholder key so prefix exists
resource "aws_s3_object" "security_questions_prefix" {
  bucket  = aws_s3_bucket.security_questions_bucket.bucket
  key     = "Questions/"
  content = ""
}

resource "aws_s3_bucket_notification" "security_questions_notification" {
  bucket = aws_s3_bucket.security_questions_bucket.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.security_questions.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "Questions/"
  }
}

resource "aws_lambda_permission" "security_questions_lambda_invoke_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_questions.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.security_questions_bucket.arn
}
