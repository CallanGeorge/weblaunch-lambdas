output "api_url" {
  description = "Custom domain URL"
  value       = module.custom_domain.custom_domain_url
}

output "custom_domain_name" {
  description = "Custom domain name"
  value       = module.custom_domain.domain_name
}

output "aws_api_url" {
  description = "AWS-generated API Gateway URL"
  value       = module.api_gateway.api_gateway_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.function_arn
}

output "business_directory_lambda_function_name" {
  description = "Name of the Business Directory Lambda function"
  value       = module.business_directory_lambda.function_name
}

output "business_directory_lambda_function_arn" {
  description = "ARN of the Business Directory Lambda function"
  value       = module.business_directory_lambda.function_arn
}