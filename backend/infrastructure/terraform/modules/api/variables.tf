variable "app_name" {
  description = "Short app identifier used as a name prefix for AWS resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (development | staging | production). Must match AppConfig.Environment on iOS."
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be one of: development, staging, production."
  }
}

variable "aws_region" {
  description = "AWS region for all regional resources (DynamoDB, Lambda, S3, API Gateway)."
  type        = string
}

variable "session_ttl_days" {
  description = "How long an issued api_token is valid before DynamoDB auto-expires it."
  type        = number
  default     = 30
}

variable "throttling_rate_limit" {
  description = "API Gateway steady-state requests per second."
  type        = number
}

variable "throttling_burst_limit" {
  description = "API Gateway burst capacity."
  type        = number
}

variable "lambda_source_dir" {
  description = "Absolute or module-relative path to the Lambda source directory (contains index.mjs)."
  type        = string
}

# ── Custom domain (ACM + Route 53 + CloudFront alias) ────────────────────────
# Gated off by default so the stack can deploy on a *.cloudfront.net hostname
# while DNS / ICANN paperwork completes. Flip to true and re-apply once the
# 123-reg nameservers have propagated to point at Route 53.

variable "custom_domain_enabled" {
  description = "If true, provision ACM cert + CloudFront alias + Route 53 A record for var.fqdn."
  type        = bool
  default     = false
}

variable "fqdn" {
  description = "Fully qualified hostname for this env's API (e.g. api.brawpatch.com). Required when custom_domain_enabled = true."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Hosted zone ID for the apex domain (e.g. brawpatch.com). Required when custom_domain_enabled = true."
  type        = string
  default     = ""
}
