locals {
  # Construct the ARNs for the model references
  model_arn            = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.model_arn_base}"
  foundation_model_arn = "arn:aws:bedrock:*::foundation-model/${var.foundation_model_arn_base}"
}
