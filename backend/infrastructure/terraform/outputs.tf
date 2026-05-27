output "cloudfront_url" {
  description = "Base URL to paste into BloomingMarvellousApp/Sources/Config/AppConfig.swift (append /v1)."
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "api_gateway_url" {
  description = "Direct API Gateway invoke URL (bypasses CloudFront). Useful for debugging."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "s3_bucket_name" {
  description = "S3 bucket holding /home and /data JSON payloads. Seed it with scripts/seed-content.mjs."
  value       = aws_s3_bucket.content.id
}

output "users_table_name" {
  description = "DynamoDB table storing user accounts. Seed it with scripts/create-user.mjs."
  value       = aws_dynamodb_table.users.name
}

output "sessions_table_name" {
  description = "DynamoDB table storing SHA-256(api_token) → userId mappings, with TTL."
  value       = aws_dynamodb_table.sessions.name
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda invocations."
  value       = aws_cloudwatch_log_group.lambda.name
}
