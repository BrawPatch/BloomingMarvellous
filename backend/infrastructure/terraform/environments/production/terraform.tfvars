# Production environment values.
aws_region             = "us-east-1"
app_name               = "blooming-marvellous"
throttling_rate_limit  = 500
throttling_burst_limit = 1000
session_ttl_days       = 30

# Flip to true after the apex zone exists, NS records are at the registrar,
# and `dig NS brawpatch.com` returns the four AWS nameservers.
custom_domain_enabled = true
