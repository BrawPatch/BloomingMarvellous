# Development environment values.
aws_region             = "us-east-1"
app_name               = "blooming-marvellous"
throttling_rate_limit  = 100
throttling_burst_limit = 200
session_ttl_days       = 30

# Flip to true after `aws route53 list-hosted-zones` shows brawpatch.com
# and `dig NS brawpatch.com` returns the four AWS nameservers from
# environments/dns output `name_servers`.
custom_domain_enabled = false
