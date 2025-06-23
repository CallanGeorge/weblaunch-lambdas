resource "aws_api_gateway_rest_api" "rest_api" {
  name = "getAppointment-api"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.proxy_method.resource_id
  http_method = aws_api_gateway_method.proxy_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = module.get_appointment_lambda.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = module.get_appointment_lambda.invoke_arn
}

# Business Directory Resource
resource "aws_api_gateway_resource" "businesses" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "businesses"
}

resource "aws_api_gateway_method" "businesses_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.businesses.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "businesses_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.businesses_method.resource_id
  http_method = aws_api_gateway_method.businesses_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = module.business_directory_lambda.invoke_arn
}

# Business Detail Resource (for /businesses/{id})
resource "aws_api_gateway_resource" "business_detail" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.businesses.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "business_detail_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.business_detail.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "business_detail_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.business_detail_method.resource_id
  http_method = aws_api_gateway_method.business_detail_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = module.business_directory_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.lambda_root,
    aws_api_gateway_integration.businesses_integration,
    aws_api_gateway_integration.business_detail_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_method.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_method.proxy_root.id,
      aws_api_gateway_integration.lambda_root.id,
      aws_api_gateway_resource.businesses.id,
      aws_api_gateway_method.businesses_method.id,
      aws_api_gateway_integration.businesses_integration.id,
      aws_api_gateway_resource.business_detail.id,
      aws_api_gateway_method.business_detail_method.id,
      aws_api_gateway_integration.business_detail_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.get_appointment_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_business_directory" {
  statement_id  = "AllowAPIGatewayInvokeBusinessDirectory"
  action        = "lambda:InvokeFunction"
  function_name = module.business_directory_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/appointment/{appointmentId}/user/{userId}"
}

output "businesses_api_url" {
  value = "https://${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/businesses"
}

data "aws_region" "current" {}