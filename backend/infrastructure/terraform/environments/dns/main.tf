###############################################################################
# Singleton: Route 53 hosted zone for brawpatch.com.
#
# Apply this FIRST, before either development or production. It outputs four
# AWS nameservers — paste those into the 123-reg control panel so the domain
# resolves via Route 53. Once registration / ICANN paperwork completes and the
# new NS records have propagated (verify with `dig NS brawpatch.com`), each
# environment can be re-applied with `custom_domain_enabled = true` to attach
# its custom subdomain.
#
# Costs: ~$0.50 / month per hosted zone (regardless of query volume).
###############################################################################

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "apex_domain" {
  description = "Apex domain to host. NS records from the hosted zone go to the registrar."
  type        = string
  default     = "brawpatch.com"
}

resource "aws_route53_zone" "apex" {
  name    = var.apex_domain
  comment = "Apex zone for BloomingMarvellousApp; NS records must be set at 123-reg."

  tags = {
    Application = "blooming-marvellous"
    ManagedBy   = "terraform"
  }
}

output "zone_id" {
  description = "Route 53 hosted zone ID. Pass to the api module via route53_zone_id."
  value       = aws_route53_zone.apex.zone_id
}

output "name_servers" {
  description = "Set these four NS records at the registrar (123-reg control panel)."
  value       = aws_route53_zone.apex.name_servers
}
