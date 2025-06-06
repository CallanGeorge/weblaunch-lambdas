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
