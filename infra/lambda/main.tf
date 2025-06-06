variable "function_name" {}
variable "handler" {}
variable "filename" {}
variable "role_arn" {}
variable "environment_variables" {
  type    = map(string)
  default = {}
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  filename      = var.filename
  handler       = var.handler
  runtime       = "nodejs22.x"
  role          = var.role_arn
  source_code_hash = filebase64sha256(var.filename)

  environment {
    variables = var.environment_variables
  }
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}
