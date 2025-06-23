provider "aws" {
  region = "eu-west-1"
}

module "get_appointment_lambda" {
  source                = "./lambda"
  function_name         = "get-appointment"
  filename              = "../dist/getAppointment.zip"
  handler               = "getAppointment.handler"
  role_arn              = aws_iam_role.lambda_exec.arn
  environment_variables = {
    NODE_OPTIONS = "--enable-source-maps"
  }
}

module "business_directory_lambda" {
  source                = "./lambda"
  function_name         = "business-directory"
  filename              = "../dist/businessDirectory.zip"
  handler               = "businessDirectory.handler"
  role_arn              = aws_iam_role.lambda_exec.arn
  environment_variables = {
    NODE_OPTIONS = "--enable-source-maps"
    USERS_TABLE_NAME = "WebLaunchUsers"
  }
}
