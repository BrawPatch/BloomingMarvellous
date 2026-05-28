###############################################################################
# BloomingMarvellousApp — Production environment root.
#
# Clean state — no moved blocks needed. Apply order on first turn-up:
#   1. terraform -chdir=../dns apply
#   2. (Operator updates 123-reg NS records to the four from the dns output.)
#   3. terraform apply here with custom_domain_enabled = false (initial)
#   4. After `dig NS brawpatch.com` shows AWS NS, flip the flag → apply again
#      to attach api.brawpatch.com via ACM + CloudFront alias.
###############################################################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_route53_zone" "apex" {
  count        = var.custom_domain_enabled ? 1 : 0
  name         = "brawpatch.com."
  private_zone = false
}

module "api" {
  source = "../../modules/api"

  app_name               = var.app_name
  environment            = "production"
  aws_region             = var.aws_region
  session_ttl_days       = var.session_ttl_days
  throttling_rate_limit  = var.throttling_rate_limit
  throttling_burst_limit = var.throttling_burst_limit
  lambda_source_dir      = "${path.module}/../../../../lambda"

  custom_domain_enabled = var.custom_domain_enabled
  fqdn                  = var.custom_domain_enabled ? "api.brawpatch.com" : ""
  route53_zone_id       = var.custom_domain_enabled ? data.aws_route53_zone.apex[0].zone_id : ""

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

output "api_url"              { value = module.api.api_url }
output "cloudfront_url"       { value = module.api.cloudfront_url }
output "api_gateway_url"      { value = module.api.api_gateway_url }
output "s3_bucket_name"       { value = module.api.s3_bucket_name }
output "users_table_name"     { value = module.api.users_table_name }
output "sessions_table_name"  { value = module.api.sessions_table_name }
output "lambda_log_group"     { value = module.api.lambda_log_group }
output "lambda_function_name" { value = module.api.lambda_function_name }
