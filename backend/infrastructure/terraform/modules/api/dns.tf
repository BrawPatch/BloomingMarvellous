###############################################################################
# Custom domain (ACM + Route 53 + CloudFront alias).
#
# Gated entirely on var.custom_domain_enabled. When disabled, none of these
# resources are created and CloudFront serves on its default *.cloudfront.net
# hostname with the AWS-issued certificate. When enabled:
#
#   - ACM cert is issued in us-east-1 (CloudFront only honours certs from
#     that region).
#   - DNS validation records are created in the existing hosted zone for the
#     apex domain (var.route53_zone_id).
#   - A Route 53 alias A/AAAA record points var.fqdn at the CloudFront
#     distribution from main.tf.
#
# Apply path on first turn-up:
#   1. Apply environments/dns first → user updates 123-reg NS records.
#   2. Wait for nameserver propagation (verify with `dig NS brawpatch.com`).
#   3. Set custom_domain_enabled = true in the env's tfvars, re-apply.
###############################################################################

resource "aws_acm_certificate" "api" {
  count = var.custom_domain_enabled ? 1 : 0

  provider          = aws.us_east_1
  domain_name       = var.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.custom_domain_enabled ? {
    for dvo in aws_acm_certificate.api[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  count = var.custom_domain_enabled ? 1 : 0

  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "api_alias" {
  count = var.custom_domain_enabled ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_alias_ipv6" {
  count = var.custom_domain_enabled ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.fqdn
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}
