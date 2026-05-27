###############################################################################
# BloomingMarvellousApp — AWS backend infrastructure
#
# Mirrors the architecture used in BMFinal: KMS-encrypted S3 + DynamoDB,
# Lambda-only auth (no Cognito), HTTP API Gateway, CloudFront in front.
#
# Endpoints exposed (must match BloomingMarvellousApp/Sources/Config/AppConfig.swift):
#   POST /v1/auth/login   — body {username, password}; returns UserModel JSON
#   GET  /v1/home         — returns [String]
#   GET  /v1/data         — returns [String]
###############################################################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws",     version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = "us-east-1"
}


locals {
  common_tags = {
    Application = var.app_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  name_prefix   = "${var.app_name}-${var.environment}"
  bucket_name   = "${local.name_prefix}-content"
  users_table   = "${local.name_prefix}-users"
  sessions_table = "${local.name_prefix}-sessions"
  lambda_name   = "${local.name_prefix}-api"
}

# ── KMS key — encrypts S3 and DynamoDB at rest ───────────────────────────────

resource "aws_kms_key" "main" {
  description             = "${var.app_name} encryption key (${var.environment})"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# ── S3 — content bucket for /home and /data payloads ─────────────────────────

resource "aws_s3_bucket" "content" {
  bucket        = local.bucket_name
  force_destroy = var.environment != "production"
}

resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  bucket = aws_s3_bucket.content.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket                  = aws_s3_bucket.content.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "content" {
  bucket = aws_s3_bucket.content.id
  rule {
  		id     = "expire-old-versions"
  		status = "Enabled"
  		filter {}
  		noncurrent_version_expiration { noncurrent_days = 90 }
  		}
}

# ── DynamoDB — users (PII) and sessions (token hashes only) ──────────────────
#
# Two-table design:
#   users    — { username (PK), userId, firstName, passwordHash, salt, createdAt }
#   sessions — { tokenHash (PK), userId, firstName, expiresAt, ttl }
#
# Sessions table stores SHA-256(api_token); the raw token is never persisted
# server-side. TTL auto-deletes expired sessions.

resource "aws_dynamodb_table" "users" {
  name         = local.users_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }

  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "sessions" {
  name         = local.sessions_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tokenHash"

  attribute {
    name = "tokenHash"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }

  point_in_time_recovery { enabled = true }
}

# ── IAM — Lambda execution role ──────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.lambda_name}*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.content.arn, "${aws_s3_bucket.content.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.users.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.sessions.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.lambda_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── Lambda ───────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 30
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda"
  output_path = "${path.module}/lambda_package.zip"
}

resource "aws_lambda_function" "api" {
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.content.id
      USERS_TABLE      = aws_dynamodb_table.users.name
      SESSIONS_TABLE   = aws_dynamodb_table.sessions.name
      AWS_REGION_VAR   = var.aws_region
      ENVIRONMENT      = var.environment
      SESSION_TTL_DAYS = tostring(var.session_ttl_days)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# ── API Gateway v2 (HTTP API) ────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type", "X-App-Version"]
    max_age       = 86400
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /v1/auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "home" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /v1/home"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "data" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /v1/data"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      sourceIp        = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      protocol        = "$context.protocol"
      httpMethod      = "$context.httpMethod"
      resourcePath    = "$context.routeKey"
      status          = "$context.status"
      responseLength  = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ── CloudFront ───────────────────────────────────────────────────────────────
#
# Auth and dynamic responses are not cached. Only future static assets behind
# the same distribution would benefit from caching; here we keep TTLs at 0
# so token validation always hits Lambda.

resource "aws_cloudfront_cache_policy" "no_cache" {
  name        = "${local.name_prefix}-no-cache"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
    headers_config       { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
    cookies_config       { cookie_behavior = "none" }
  }
}

resource "aws_cloudfront_origin_request_policy" "auth_forward" {
  name = "${local.name_prefix}-auth-forward"
  headers_config {
    header_behavior = "whitelist"
    headers { items = ["Authorization", "Content-Type", "X-App-Version"] }
  }
  query_strings_config { query_string_behavior = "all" }
  cookies_config       { cookie_behavior = "none" }
}

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.app_name} ${var.environment} API"
  price_class     = "PriceClass_100"

  origin {
    domain_name = trimsuffix(replace(aws_apigatewayv2_stage.default.invoke_url, "https://", ""), "/")
    origin_id   = "api-gateway"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "api-gateway"
    cache_policy_id          = aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.auth_forward.id
    viewer_protocol_policy   = "redirect-to-https"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
