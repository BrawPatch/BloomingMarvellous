variable "app_name" {
  type    = string
  default = "blooming-marvellous"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "session_ttl_days" {
  type    = number
  default = 30
}

variable "throttling_rate_limit" {
  type    = number
  default = 100
}

variable "throttling_burst_limit" {
  type    = number
  default = 200
}

variable "custom_domain_enabled" {
  description = "Flip to true once brawpatch.com nameservers point at Route 53 and have propagated."
  type        = bool
  default     = false
}
