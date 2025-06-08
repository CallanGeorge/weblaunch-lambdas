terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = local.common_tags
  }
}

# Provider for us-east-1 (required for API Gateway certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = local.common_tags
  }
}

# IAM module
module "iam" {
  source = "../../modules/iam"
  
  environment   = var.environment
  function_name = var.function_name
  table_name    = var.table_name
  region        = var.region
}

# Lambda module
module "lambda" {
  source = "../../modules/lambda"
  
  function_name = var.function_name
  filename      = "../../../dist/getAppointment.zip"
  handler       = "getAppointment.handler"
  role_arn      = module.iam.lambda_role_arn
  
  environment_variables = {
    NODE_OPTIONS = "--enable-source-maps"
    TABLE_NAME   = var.table_name
    ENVIRONMENT  = var.environment
  }
}

# API Gateway module
module "api_gateway" {
  source = "../../modules/api-gateway"
  
  api_name             = var.api_name
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  environment          = var.environment
  stage_name          = "api"
}

# Custom domain module (no count, always create)
module "custom_domain" {
  source = "../../modules/domain"
  
  domain_name           = local.api_domain_name
  base_domain          = var.base_domain
  api_gateway_id       = module.api_gateway.api_gateway_id
  api_gateway_stage_name = "api"
  environment          = var.environment
}