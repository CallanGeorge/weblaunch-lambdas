variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "WebLaunchSchedulerAppointmentTable"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "weblaunch-get-appointment-prod"
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
  default     = "weblaunch-api-prod"
}

variable "base_domain" {
  description = "Base domain name "
  type        = string
  default     = "sitehustle.co.uk"  
}

variable "use_custom_domain" {
  description = "Whether to create a custom domain for the API"
  type        = bool
  default     = true
}

locals {
  api_domain_name = "weblaunch-api-${var.environment}.${var.base_domain}"
  
  common_tags = {
    Environment = var.environment
    Project     = "weblaunch-lambdas"
    ManagedBy   = "terraform"
  }
}