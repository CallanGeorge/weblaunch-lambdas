variable "domain_name" {
  description = "Full domain name for the API "
  type        = string
}

variable "base_domain" {
  description = "Base domain name"
  type        = string
}

variable "api_gateway_id" {
  description = "API Gateway REST API ID"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "API Gateway stage name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Get the hosted zone for the base domain
data "aws_route53_zone" "main" {
  name = var.base_domain
}

# AWS provider for us-east-1 (required for API Gateway certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Request ACM certificate in us-east-1 (required for API Gateway)
resource "aws_acm_certificate" "api" {
  provider = aws.us_east_1
  
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Name        = var.domain_name
  }
}

# Create validation records in Route 53
resource "aws_route53_record" "api_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "api" {
  provider = aws.us_east_1
  
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Create custom domain for API Gateway
resource "aws_api_gateway_domain_name" "api" {
  domain_name              = var.domain_name
  certificate_arn          = aws_acm_certificate_validation.api.certificate_arn
  security_policy          = "TLS_1_2"

  tags = {
    Environment = var.environment
    Name        = var.domain_name
  }
}

# Map the custom domain to the API Gateway
resource "aws_api_gateway_base_path_mapping" "api" {
  api_id      = var.api_gateway_id
  stage_name  = var.api_gateway_stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

# Create DNS record pointing to the custom domain
resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.main.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}

# Outputs
output "domain_name" {
  description = "Custom domain name"
  value       = aws_api_gateway_domain_name.api.domain_name
}

output "custom_domain_url" {
  description = "Full URL with custom domain"
  value       = "https://${aws_api_gateway_domain_name.api.domain_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate_validation.api.certificate_arn
}