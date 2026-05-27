# BloomingMarvellousApp — Backend Deployment Guide

This document is the step-by-step instruction guide for standing up the AWS
backend that the iOS app talks to. It covers prerequisites, AWS account setup,
Terraform deploy, seeding content, creating users, and wiring the iOS app to
the deployed URL.

## Architecture

```
┌───────────────┐    HTTPS    ┌──────────────┐         ┌────────────┐
│ iOS app       │ ──────────► │ CloudFront   │ ──────► │ API GW v2  │
│ NetworkService│             │ (no-cache)   │         │ (HTTP API) │
└───────┬───────┘             └──────────────┘         └─────┬──────┘
        │                                                    │
        │ Authorization: Bearer <api_token>                  ▼
        │                                              ┌──────────┐
        │                                              │  Lambda  │
        │                                              │ (Node20) │
        │                                              └────┬─────┘
        │                            ┌──────────────────────┼─────────────────────────┐
        │                            ▼                      ▼                         ▼
        │                     ┌────────────┐         ┌────────────┐           ┌─────────────┐
        │                     │ DynamoDB   │         │ DynamoDB   │           │ S3 (KMS)    │
        │                     │ users      │         │ sessions   │           │ /home.json  │
        │                     │ (scrypt PW)│         │ (SHA-256   │           │ /data.json  │
        │                     │            │         │  token TTL)│           │             │
        │                     └────────────┘         └────────────┘           └─────────────┘
```

All resources are tagged `Application=blooming-marvellous`, `Environment=<env>`,
`ManagedBy=terraform` and encrypted with a per-environment KMS key.

## API contract

The Lambda implements the endpoints declared in
`BloomingMarvellousApp/Sources/Config/AppConfig.swift`. Paths are prefixed
with `/v1` (the version segment is part of the base URL on the iOS side).

| Method | Path             | Auth   | Request body                          | Response                                            |
|--------|------------------|--------|---------------------------------------|-----------------------------------------------------|
| POST   | `/v1/auth/login` | none   | `{"username": "...", "password": "..."}` | `200 {"user_id": Int, "first_name": String, "api_token": String}` / `401` |
| GET    | `/v1/home`       | Bearer | —                                     | `200 [String]`                                      |
| GET    | `/v1/data`       | Bearer | —                                     | `200 [String]`                                      |

> **iOS gap to be aware of:** the current `NetworkService` only sets
> `Content-Type` (see `Sources/Networking/NetworkService.swift` line 86) and
> does not attach an `Authorization` header. After deployment, `/v1/home` and
> `/v1/data` will return `401` until a one-line change is made in
> `NetworkService.request(_:)` to inject the token retrieved from
> `KeychainService.retrieve(forKey: KeychainKey.authToken)`. This is left out
> of scope here; flag it as a follow-up.

## Prerequisites

| Tool        | Version | Install                                              |
|-------------|---------|------------------------------------------------------|
| AWS account | —       | https://aws.amazon.com (free tier is sufficient)     |
| AWS CLI     | v2      | `brew install awscli`                                |
| Terraform   | ≥ 1.6   | `brew install hashicorp/tap/terraform`               |
| Node.js     | ≥ 20    | `brew install node@20`                               |

Verify:

```bash
aws --version       # aws-cli/2.x
terraform --version # Terraform v1.6+
node --version      # v20+
```

## 1. Configure AWS credentials

In the AWS console, create an IAM user with programmatic access and the
`AdministratorAccess` policy (or a tighter custom policy if you have one).
Then locally:

```bash
aws configure
# AWS Access Key ID:     <from CSV>
# AWS Secret Access Key: <from CSV>
# Default region name:   eu-west-2
# Default output format: json
```

## 2. Configure Terraform variables

```bash
cd BloomingMarvellousApp/backend/infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region  = "eu-west-2"     # or "us-east-1" etc.
environment = "development"   # one of: development | staging | production
app_name    = "blooming-marvellous"
```

The chosen `environment` value should match the build configuration in
`AppConfig.swift` (`AppConfig.current` returns `.development` for DEBUG builds).

## 3. Deploy

From `BloomingMarvellousApp/backend/`:

```bash
./scripts/deploy.sh
```

The script `npm install`s Lambda dependencies into `lambda/node_modules` so
the Terraform `archive_file` picks them up, then runs `terraform init` and
`terraform apply -auto-approve`.

On success it prints outputs that include:

```
api_gateway_url      = "https://abc123.execute-api.eu-west-2.amazonaws.com"
cloudfront_url       = "https://d1234abcdef.cloudfront.net"
s3_bucket_name       = "blooming-marvellous-development-content"
users_table_name     = "blooming-marvellous-development-users"
sessions_table_name  = "blooming-marvellous-development-sessions"
```

CloudFront takes ~10–15 minutes to fully propagate the first time. The
API Gateway URL works immediately if you want to test before propagation
completes.

## 4. Seed the /home and /data content

```bash
cd BloomingMarvellousApp/backend
node scripts/seed-content.mjs
```

The script reads the bucket name from `terraform output`, then uploads
`v1/home.json` and `v1/data.json` (a small starter list each). Edit the
arrays at the top of `scripts/seed-content.mjs` and re-run to update what
the app displays — no Lambda redeploy needed.

## 5. Create a user

```bash
cd BloomingMarvellousApp/backend
node scripts/create-user.mjs alice 'hunter2' Alice
```

This writes a row to the users table with a scrypt-hashed password. Re-running
with the same username is idempotent (the derived `userId` is stable).

Verify the login flow end-to-end:

```bash
CLOUDFRONT=$(cd infrastructure/terraform && terraform output -raw cloudfront_url)

curl -s -X POST "$CLOUDFRONT/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"hunter2"}' | jq

# Expected response shape (matches UserModel in Sources/Models/UserModel.swift):
# {
#   "user_id":    123456,
#   "first_name": "Alice",
#   "api_token":  "..."
# }
```

Then exercise an authenticated read:

```bash
TOKEN=$(curl -s -X POST "$CLOUDFRONT/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"hunter2"}' | jq -r .api_token)

curl -s "$CLOUDFRONT/v1/home" -H "Authorization: Bearer $TOKEN" | jq
```

## 6. Point the iOS app at the deployed URL

In `BloomingMarvellousApp/Sources/Config/AppConfig.swift`, replace the
placeholder URL in the matching case of `Environment.baseURL`:

```swift
case .development:
    return URL(string: "https://d1234abcdef.cloudfront.net/v1")!
```

Use the `cloudfront_url` from `terraform output`, with `/v1` appended. The
`/v1` prefix is part of the base URL because the path constants
(`/auth/login`, `/home`, `/data`) do not include it.

## Updating the backend

| Change                          | Command                                                     |
|---------------------------------|-------------------------------------------------------------|
| Lambda code (`lambda/index.mjs`)| `./scripts/deploy.sh` (re-archives + re-uploads function)   |
| Infrastructure (`*.tf`)         | `./scripts/deploy.sh`                                       |
| `/home` or `/data` content      | edit `scripts/seed-content.mjs`, re-run `node scripts/seed-content.mjs` |
| Add a user                      | `node scripts/create-user.mjs <username> <password> <firstName>` |
| Revoke a session                | delete the row from the sessions table in DynamoDB console  |

## Tear down

```bash
cd BloomingMarvellousApp/backend/infrastructure/terraform
terraform destroy
```

For `environment = "production"` the S3 bucket has `force_destroy = false`,
so you must empty it manually first. For development/staging Terraform
destroys it directly.

## Cost estimate

For low-volume development use everything stays inside the AWS free tier:

| Service        | Free tier              | Typical dev cost |
|----------------|------------------------|------------------|
| Lambda         | 1M requests/month free | $0               |
| API Gateway    | 1M HTTP requests free  | $0               |
| DynamoDB       | 25 GB + on-demand free | $0               |
| S3             | 5 GB free              | $0               |
| CloudFront     | 1 TB egress free       | $0               |
| KMS            | $1/month per key       | ~$1/month        |
| CloudWatch     | 5 GB logs free         | $0               |

Production at small scale (≈1k MAU) typically lands at $5–15/month.

## Troubleshooting

**`terraform apply` fails on `aws_s3_bucket.content`: bucket already exists**
S3 bucket names are globally unique. Change `app_name` in `terraform.tfvars`
to something more specific (e.g. include your username).

**Login returns 401 with correct credentials**
Confirm the user exists: `aws dynamodb scan --table-name blooming-marvellous-development-users`.
Re-run `create-user.mjs` if the row is missing.

**`/v1/home` returns 401 from the iOS app but works with curl**
Expected — see the "iOS gap" note above. `NetworkService` doesn't attach the
Bearer token yet.

**`/v1/home` returns 404 "Content not found"**
You haven't seeded yet. Run `node scripts/seed-content.mjs`.

**CloudFront returns 403 for a few minutes after deploy**
Distribution is still propagating. Use the `api_gateway_url` output to test
in the meantime.

**Lambda errors visible nowhere**
```bash
aws logs tail /aws/lambda/blooming-marvellous-development-api --follow
```
