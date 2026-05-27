variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment (development | staging | production). Must match AppConfig.Environment on iOS."
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be one of: development, staging, production."
  }
}

variable "app_name" {
  description = "Short app identifier used as a name prefix for AWS resources."
  type        = string
  default     = "blooming-marvellous"
}

variable "session_ttl_days" {
  description = "How long an issued api_token is valid before DynamoDB auto-expires it."
  type        = number
  default     = 30
}

variable "throttling_rate_limit" {
  description = "API Gateway steady-state requests per second."
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "API Gateway burst capacity."
  type        = number
  default     = 200
}
