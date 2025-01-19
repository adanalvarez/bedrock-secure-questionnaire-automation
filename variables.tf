variable "aws_region" {
  type        = string
  description = "The AWS region."
  default     = "us-east-1"
}

variable "database_name" {
  type        = string
  description = "Database name."
  default     = "aurorapostgres"
}

variable "admin_user_name" {
  type        = string
  description = "Admin username for Aurora."
  default     = "AuroraBedrockAdmin"
}

variable "engine_version" {
  type        = string
  description = "The PostgreSQL engine version."
  default     = "15.7"
}

variable "max_capacity" {
  type        = number
  description = "Maximum capacity for serverless v2."
  default     = 16
}

variable "min_capacity" {
  type        = number
  description = "Minimum capacity for serverless v2."
  default     = 0
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC."
  default     = "main-vpc"
}

variable "model_arn_base" {
  type        = string
  description = "Base model ARN for custom inference profile."
  default     = "us.anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "foundation_model_arn_base" {
  type        = string
  description = "Base model ARN for foundation model."
  default     = "anthropic.claude-3-5-haiku-20241022-v1:0"
}
