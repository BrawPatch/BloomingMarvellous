###############################################################################
# BloomingMarvellousApp — Development environment root.
#
# Calls modules/api with development-tier values. The `moved` blocks below
# carry the original dev state (resources that lived at the root of the old
# terraform/ directory) into the new module addresses, with zero destroys.
###############################################################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

# Primary region for regional resources (DynamoDB / Lambda / S3 / API GW).
provider "aws" {
  region = var.aws_region
}

# CloudFront ACM certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Look up the brawpatch.com hosted zone (managed by environments/dns).
# Marked with count=0 evaluation under custom_domain_enabled=false so the
# stack still applies before the zone exists.
data "aws_route53_zone" "apex" {
  count        = var.custom_domain_enabled ? 1 : 0
  name         = "brawpatch.com."
  private_zone = false
}

module "api" {
  source = "../../modules/api"

  app_name               = var.app_name
  environment            = "development"
  aws_region             = var.aws_region
  session_ttl_days       = var.session_ttl_days
  throttling_rate_limit  = var.throttling_rate_limit
  throttling_burst_limit = var.throttling_burst_limit
  lambda_source_dir      = "${path.module}/../../../../lambda"

  custom_domain_enabled = var.custom_domain_enabled
  fqdn                  = var.custom_domain_enabled ? "api-dev.brawpatch.com" : ""
  route53_zone_id       = var.custom_domain_enabled ? data.aws_route53_zone.apex[0].zone_id : ""

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# ── State migration: existing root-level resources → module.api ──────────────
# These `moved` blocks rename addresses in state when terraform plan runs.
# Once applied, they become inert and can be removed in a future cleanup.

moved {
  from = aws_kms_key.main
  to   = module.api.aws_kms_key.main
}
moved {
  from = aws_kms_alias.main
  to   = module.api.aws_kms_alias.main
}
moved {
  from = aws_s3_bucket.content
  to   = module.api.aws_s3_bucket.content
}
moved {
  from = aws_s3_bucket_versioning.content
  to   = module.api.aws_s3_bucket_versioning.content
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.content
  to   = module.api.aws_s3_bucket_server_side_encryption_configuration.content
}
moved {
  from = aws_s3_bucket_public_access_block.content
  to   = module.api.aws_s3_bucket_public_access_block.content
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.content
  to   = module.api.aws_s3_bucket_lifecycle_configuration.content
}
moved {
  from = aws_dynamodb_table.users
  to   = module.api.aws_dynamodb_table.users
}
moved {
  from = aws_dynamodb_table.sessions
  to   = module.api.aws_dynamodb_table.sessions
}
moved {
  from = aws_iam_role.lambda
  to   = module.api.aws_iam_role.lambda
}
moved {
  from = aws_iam_role_policy.lambda
  to   = module.api.aws_iam_role_policy.lambda
}
moved {
  from = aws_iam_role_policy_attachment.lambda_basic
  to   = module.api.aws_iam_role_policy_attachment.lambda_basic
}
moved {
  from = aws_cloudwatch_log_group.lambda
  to   = module.api.aws_cloudwatch_log_group.lambda
}
moved {
  from = aws_lambda_function.api
  to   = module.api.aws_lambda_function.api
}
moved {
  from = aws_apigatewayv2_api.main
  to   = module.api.aws_apigatewayv2_api.main
}
moved {
  from = aws_apigatewayv2_integration.lambda
  to   = module.api.aws_apigatewayv2_integration.lambda
}
moved {
  from = aws_apigatewayv2_route.login
  to   = module.api.aws_apigatewayv2_route.login
}
moved {
  from = aws_apigatewayv2_route.home
  to   = module.api.aws_apigatewayv2_route.home
}
moved {
  from = aws_apigatewayv2_route.data
  to   = module.api.aws_apigatewayv2_route.data
}
moved {
  from = aws_apigatewayv2_stage.default
  to   = module.api.aws_apigatewayv2_stage.default
}
moved {
  from = aws_cloudwatch_log_group.api_gateway
  to   = module.api.aws_cloudwatch_log_group.api_gateway
}
moved {
  from = aws_lambda_permission.api_gateway
  to   = module.api.aws_lambda_permission.api_gateway
}
moved {
  from = aws_cloudfront_cache_policy.no_cache
  to   = module.api.aws_cloudfront_cache_policy.no_cache
}
moved {
  from = aws_cloudfront_origin_request_policy.auth_forward
  to   = module.api.aws_cloudfront_origin_request_policy.auth_forward
}
moved {
  from = aws_cloudfront_distribution.api
  to   = module.api.aws_cloudfront_distribution.api
}

# ── Outputs ──────────────────────────────────────────────────────────────────

output "api_url"             { value = module.api.api_url }
output "cloudfront_url"      { value = module.api.cloudfront_url }
output "api_gateway_url"     { value = module.api.api_gateway_url }
output "s3_bucket_name"      { value = module.api.s3_bucket_name }
output "users_table_name"    { value = module.api.users_table_name }
output "sessions_table_name" { value = module.api.sessions_table_name }
output "lambda_log_group"    { value = module.api.lambda_log_group }
output "lambda_function_name" { value = module.api.lambda_function_name }
