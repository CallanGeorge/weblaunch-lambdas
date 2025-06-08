variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stg"
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "WebLaunchSchedulerAppointmentTable-stg"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "weblaunch-get-appointment-stg"
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
  default     = "weblaunch-api-stg"
}

variable "base_domain" {
  description = "Base domain name (e.g., yourdomain.co.uk)"
  type        = string
  default     = "sitehustle.co.uk"
}

locals {
  api_domain_name = "weblaunch-api-${var.environment}.${var.base_domain}"
  
  common_tags = {
    Environment = var.environment
    Project     = "weblaunch-lambdas"
    ManagedBy   = "terraform"
  }
}