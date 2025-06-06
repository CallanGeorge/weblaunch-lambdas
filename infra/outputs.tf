output "api_url" {
  value = "https://${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}