resource "aws_kms_key" "aurora" {
  description             = "CMK for Aurora PostgreSQL server-side encryption."
  deletion_window_in_days = 10
  enable_key_rotation     = false
}

resource "aws_kms_alias" "aurora_alias" {
  name          = "alias/aurora-data-store-key"
  target_key_id = aws_kms_key.aurora.id
}
