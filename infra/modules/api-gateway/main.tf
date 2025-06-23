variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to integrate"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

variable "business_directory_lambda_function_name" {
  description = "Name of the Business Directory Lambda function"
  type        = string
  default     = ""
}

variable "business_directory_lambda_invoke_arn" {
  description = "Invoke ARN of the Business Directory Lambda function"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "api"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.api_name
  description = "API Gateway for ${var.environment} environment"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
  }
}

# /appointment resource
resource "aws_api_gateway_resource" "appointment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "appointment"
}

# GET method for /appointment
resource "aws_api_gateway_method" "get_appointment" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.appointment.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.appointmentId" = true
    "method.request.querystring.user"          = true
  }
}

# OPTIONS method for CORS
resource "aws_api_gateway_method" "options_appointment" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.appointment.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Lambda integration for GET (AWS_PROXY handles responses automatically)
resource "aws_api_gateway_integration" "get_appointment_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.appointment.id
  http_method = aws_api_gateway_method.get_appointment.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_invoke_arn
}

# Mock integration for OPTIONS
resource "aws_api_gateway_integration" "options_appointment_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.appointment.id
  http_method = aws_api_gateway_method.options_appointment.http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.appointment.id
  http_method = aws_api_gateway_method.options_appointment.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.appointment.id
  http_method = aws_api_gateway_method.options_appointment.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.options_appointment_integration]
}

# Deployment
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.get_appointment_integration,
    aws_api_gateway_integration.options_appointment_integration,
    aws_api_gateway_integration_response.options_200,
    aws_api_gateway_integration.get_businesses_integration,
    aws_api_gateway_integration.options_businesses_integration,
    aws_api_gateway_integration_response.options_businesses_200,
    aws_api_gateway_integration.get_business_detail_integration,
    aws_api_gateway_integration.options_business_detail_integration,
    aws_api_gateway_integration_response.options_business_detail_200,
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    redeployment = sha1(jsonencode(concat([
      aws_api_gateway_resource.appointment.id,
      aws_api_gateway_method.get_appointment.id,
      aws_api_gateway_method.options_appointment.id,
      aws_api_gateway_integration.get_appointment_integration.id,
      aws_api_gateway_integration.options_appointment_integration.id,
    ], var.business_directory_lambda_function_name != "" ? [
      aws_api_gateway_resource.businesses[0].id,
      aws_api_gateway_method.get_businesses[0].id,
      aws_api_gateway_method.options_businesses[0].id,
      aws_api_gateway_integration.get_businesses_integration[0].id,
      aws_api_gateway_integration.options_businesses_integration[0].id,
      aws_api_gateway_resource.business_detail[0].id,
      aws_api_gateway_method.get_business_detail[0].id,
      aws_api_gateway_method.options_business_detail[0].id,
      aws_api_gateway_integration.get_business_detail_integration[0].id,
      aws_api_gateway_integration.options_business_detail_integration[0].id,
    ] : [])))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = var.stage_name

  tags = {
    Environment = var.environment
  }
}

# Lambda permission
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

# Lambda permission for business directory
resource "aws_lambda_permission" "apigw_invoke_business_directory" {
  count         = var.business_directory_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeBusinessDirectory"
  action        = "lambda:InvokeFunction"
  function_name = var.business_directory_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

# Data source for current region
data "aws_region" "current" {}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.rest_api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.rest_api.execution_arn
}

# /businesses resource
resource "aws_api_gateway_resource" "businesses" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "businesses"
}

# GET method for /businesses
resource "aws_api_gateway_method" "get_businesses" {
  count         = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.businesses[0].id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.type" = false
  }
}

# OPTIONS method for CORS on /businesses
resource "aws_api_gateway_method" "options_businesses" {
  count         = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.businesses[0].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Lambda integration for GET /businesses
resource "aws_api_gateway_integration" "get_businesses_integration" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.businesses[0].id
  http_method = aws_api_gateway_method.get_businesses[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.business_directory_lambda_invoke_arn
}

# Mock integration for OPTIONS /businesses
resource "aws_api_gateway_integration" "options_businesses_integration" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.businesses[0].id
  http_method = aws_api_gateway_method.options_businesses[0].http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS /businesses
resource "aws_api_gateway_method_response" "options_businesses_200" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.businesses[0].id
  http_method = aws_api_gateway_method.options_businesses[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integration response for OPTIONS /businesses
resource "aws_api_gateway_integration_response" "options_businesses_200" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.businesses[0].id
  http_method = aws_api_gateway_method.options_businesses[0].http_method
  status_code = aws_api_gateway_method_response.options_businesses_200[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.options_businesses_integration]
}

# Business detail resource /businesses/{id}
resource "aws_api_gateway_resource" "business_detail" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.businesses[0].id
  path_part   = "{id}"
}

# GET method for /businesses/{id}
resource "aws_api_gateway_method" "get_business_detail" {
  count         = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.business_detail[0].id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

# OPTIONS method for CORS on /businesses/{id}
resource "aws_api_gateway_method" "options_business_detail" {
  count         = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.business_detail[0].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Lambda integration for GET /businesses/{id}
resource "aws_api_gateway_integration" "get_business_detail_integration" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.business_detail[0].id
  http_method = aws_api_gateway_method.get_business_detail[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.business_directory_lambda_invoke_arn
}

# Mock integration for OPTIONS /businesses/{id}
resource "aws_api_gateway_integration" "options_business_detail_integration" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.business_detail[0].id
  http_method = aws_api_gateway_method.options_business_detail[0].http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS /businesses/{id}
resource "aws_api_gateway_method_response" "options_business_detail_200" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.business_detail[0].id
  http_method = aws_api_gateway_method.options_business_detail[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integration response for OPTIONS /businesses/{id}
resource "aws_api_gateway_integration_response" "options_business_detail_200" {
  count       = var.business_directory_lambda_function_name != "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.business_detail[0].id
  http_method = aws_api_gateway_method.options_business_detail[0].http_method
  status_code = aws_api_gateway_method_response.options_business_detail_200[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.options_business_detail_integration]
}