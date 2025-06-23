variable "environment" {
  description = "Environment name"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# Lambda execution role
resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Purpose     = "lambda-execution"
  }
}

# DynamoDB read policy
resource "aws_iam_policy" "dynamodb_read" {
  name        = "${var.function_name}-dynamodb-read"
  description = "Allow read access to DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:BatchGetItem"
      ],
      Resource = "arn:aws:dynamodb:${var.region}:*:table/${var.table_name}"
    }]
  })
}

# DynamoDB policy for WebLaunchUsers table (business directory)
resource "aws_iam_policy" "dynamodb_users_read" {
  name        = "${var.function_name}-dynamodb-users-read"
  description = "Allow read and scan access to WebLaunchUsers table"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem"
      ],
      Resource = "arn:aws:dynamodb:${var.region}:*:table/WebLaunchUsers"
    }]
  })
}

# Attach basic execution role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach DynamoDB policy
resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_read.arn
}

# Attach DynamoDB users policy
resource "aws_iam_role_policy_attachment" "lambda_dynamo_users" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_users_read.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.name
}