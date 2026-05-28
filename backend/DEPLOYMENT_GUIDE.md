# BloomingMarvellousApp — Backend Deployment Guide

This document is the step-by-step instruction guide for standing up the AWS
backend that the iOS app talks to. It covers prerequisites, AWS account setup,
Terraform deploy (per environment), seeding tiered content, creating users
with the right entitlements, and wiring the iOS app to the deployed URL.

## Architecture

```
┌───────────────┐   HTTPS    ┌──────────────┐         ┌────────────┐
│ iOS app       │ ─────────► │ CloudFront   │ ──────► │ API GW v2  │
│ NetworkService│            │ (no-cache)   │         │ (HTTP API) │
└───────┬───────┘            └──────────────┘         └─────┬──────┘
        │                                                   │
        │ Authorization: Bearer <api_token>                 ▼
        │                                            ┌──────────┐
        │                                            │  Lambda  │
        │                                            │ (Node20) │
        │                                            └────┬─────┘
        │                          ┌─────────────────────┼─────────────────────┐
        │                          ▼                     ▼                     ▼
        │                   ┌────────────┐        ┌────────────┐        ┌─────────────┐
        │                   │ DynamoDB   │        │ DynamoDB   │        │ S3 (KMS)    │
        │                   │ users      │        │ sessions   │        │ v1/home.json│
        │                   │ +tier      │        │ +tier      │        │ v1/data.json│
        │                   │ +packs     │        │ +packs     │        │ (v2 schema) │
        │                   └────────────┘        └────────────┘        └─────────────┘
```

Each environment (`development`, `production`) is a **separate, parallel**
AWS stack with its own KMS key, DynamoDB tables, S3 bucket, Lambda function,
API Gateway, and CloudFront distribution. There is no shared infrastructure
between environments. The custom domain (`brawpatch.com`) is the only shared
resource — its Route 53 hosted zone lives in `environments/dns/`.

All resources are tagged `Application=blooming-marvellous`, `Environment=<env>`,
`ManagedBy=terraform` and encrypted with a per-environment KMS key.

## API contract

The Lambda implements the endpoints declared in
`BloomingMarvellousApp/Sources/Config/AppConfig.swift`. Paths are prefixed
with `/v1` (the version segment is part of the base URL on the iOS side).

| Method | Path             | Auth   | Request body                              | Response |
|--------|------------------|--------|-------------------------------------------|----------|
| POST   | `/v1/auth/login` | none   | `{"username": "...", "password": "..."}` | `200 {"user_id": Int, "first_name": String, "api_token": String, "tier": "free"\|"pro", "purchased_packs": [String]}` / `401` |
| GET    | `/v1/home`       | Bearer | —                                         | `200 [String]` — filtered by the caller's tier + packs |
| GET    | `/v1/data`       | Bearer | —                                         | `200 [String]` — filtered by the caller's tier + packs |

> **Bearer token wiring:** `NetworkService` reads `KeychainKey.authToken`
> from Keychain and attaches `Authorization: Bearer <token>` to every
> endpoint where `Endpoint.requiresAuth == true` (the default). The login
> endpoint is the only one that opts out via `requiresAuth: false` so it
> can travel unauthenticated and issue the token. If the token is missing
> or the server returns 401, `NetworkService` clears the stored token and
> throws `NetworkError.unauthorized` so the UI can route to the login flow.

### Tier and pack model

* Every user record has `tier ∈ {free, pro}` and an optional
  `purchasedPacks ⊆ {pack_exotic, pack_edible}` (DynamoDB StringSet).
* Login snapshots `tier` + `purchasedPacks` into the sessions table so
  per-request reads don't need a second DynamoDB lookup. **A purchase made
  mid-session is only visible after the user re-logs in.**
* Content in S3 uses the v2 schema:
  ```json
  { "version": 2,
    "items": [ {"id": "...", "label": "...", "access": "free|pro|pack_exotic|pack_edible"}, ... ] }
  ```
* Lambda filters server-side: a free user gets only `access=="free"` items;
  a pro user gets free + pro + any pack they own. The HTTP response is
  always projected back to `[String]` (the labels) to preserve the iOS
  contract.

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

## 1. Configure AWS credentials (IAM Identity Center / SSO)

This stack is deployed using **short-lived session tokens** obtained from
AWS IAM Identity Center (formerly AWS SSO), not long-lived access keys
attached to a root or admin IAM user. The CLI refreshes the token from your
SSO portal on demand and never stores secrets on disk.

> **Why not access keys?** A long-lived `AKIA…` / secret-key pair on disk is
> a permanent compromise risk. SSO sessions expire (default 8h), are tied
> to a permission set you can scope down per environment, and can require
> MFA at sign-in. Root-account access keys should never be created at all.

### 1a. One-time: enable IAM Identity Center

In the AWS console (sign in as the account root **only** to do this once;
afterwards never use root again):

1. Open **IAM Identity Center** → **Enable** (pick the same region you'll
   deploy into, e.g. `us-east-1`). This also enables AWS Organizations if
   not already on.
2. **Users** → **Add user** — create a user for yourself with your email.
3. **Permission sets** → **Create permission set**:
   - For first-time setup, the AWS-managed `AdministratorAccess` permission
     set is the easy choice. **Tighten it later** — see the appendix at the
     bottom of this guide for a least-privilege policy that covers exactly
     the resources this Terraform manages.
   - Session duration: 8 hours (default) is fine.
4. **AWS accounts** → select your account → **Assign users or groups** →
   pick your user + permission set.
5. From the IAM Identity Center dashboard, copy the **AWS access portal URL**
   (looks like `https://d-1234567890.awsapps.com/start`). You'll need it in
   step 1b.

### 1b. Configure the CLI to use SSO

Locally, run:

```bash
aws configure sso
# SSO session name:                  blooming-marvellous
# SSO start URL:                     https://d-1234567890.awsapps.com/start
# SSO region:                        us-east-1
# SSO registration scopes:           [press Enter for the default]
# (browser opens, sign in, approve the device)
# Choose your AWS account → choose the permission set
# Default client region:             us-east-1
# Default output format:             json
# CLI profile name:                  blooming-marvellous
```

Then point the CLI at this profile for the deploy session:

```bash
export AWS_PROFILE=blooming-marvellous

# Sanity check — should print your account ID + the assumed role ARN
aws sts get-caller-identity
```

Re-running `aws sso login --profile blooming-marvellous` refreshes the token
when it expires; you don't need to repeat `aws configure sso`.

Terraform and the deploy scripts automatically use `AWS_PROFILE` from the
environment — no other configuration is needed.

## 2. Terraform layout

```
backend/infrastructure/terraform/
├── modules/api/                  # shared module — one parameterised stack
└── environments/
    ├── dns/                      # singleton Route 53 zone for brawpatch.com
    ├── development/              # dev stack (api-dev.brawpatch.com)
    └── production/               # prod stack (api.brawpatch.com)
```

Each env directory has its own `terraform.tfvars` and its own state file.
Dev and prod are independent — applying one does not affect the other.

## 3. First-time deploy

### 3a. Stand up the shared Route 53 zone

```bash
cd backend/infrastructure/terraform/environments/dns
terraform init
terraform apply -auto-approve
terraform output name_servers
```

Take the four NS values and paste them into the **123-reg** control panel
for `brawpatch.com`. ICANN may delay the change for up to 48h on freshly
registered domains; verify with `dig NS brawpatch.com` showing AWS NS values
before proceeding to step 3d.

### 3b. Deploy the development stack

From `backend/`:

```bash
./scripts/deploy.sh development
```

The script:

1. Runs `npm install --omit=dev` in `lambda/` so the archive_file picks up
   only runtime deps.
2. `terraform -chdir=environments/development init`
3. `terraform -chdir=environments/development apply -auto-approve`
4. Re-seeds S3 content via `node scripts/seed-content.mjs --env development`.
5. Prints the resulting CloudFront URL.

### 3c. Deploy the production stack

```bash
./scripts/deploy.sh production
```

Exactly the same flow with a different env directory. CloudFront takes
~5–15 minutes to propagate the first time. The `api_gateway_url` output is
usable immediately if you want to smoke-test before propagation completes.

### 3d. Attach the custom domain (once NS records propagate)

Verify nameservers point at AWS:

```bash
dig NS brawpatch.com
# Should return the four AWS NS values from step 3a.
```

Then for each env, edit `terraform.tfvars`:

```hcl
custom_domain_enabled = true
```

and re-run `./scripts/deploy.sh <env>`. The apply will:

1. Request an ACM certificate in `us-east-1` (DNS-validated against the
   apex zone).
2. Add a Route 53 A/AAAA alias record (`api.brawpatch.com` →
   prod CloudFront; `api-dev.brawpatch.com` → dev CloudFront).
3. Update the CloudFront distribution to use the new cert and aliases.

ACM validation typically completes in 1–3 minutes once DNS is in place.

## 4. Seed content (per env)

```bash
cd backend
node scripts/seed-content.mjs --env development
node scripts/seed-content.mjs --env production
```

`deploy.sh` already invokes this at the end of each deploy, so the only
time you'd run it manually is to update content **without** redeploying
infrastructure. Edit the `HOME` and `DATA` arrays at the top of
`scripts/seed-content.mjs` and re-run; the items carry `access` markers and
the Lambda filters them per request.

## 5. Create users

```bash
# A free-tier user in dev
node scripts/create-user.mjs --env development \
  --username alice --password 'hunter2' --first-name Alice

# A pro user with both content packs in prod
node scripts/create-user.mjs --env production \
  --username bob --password 'sekrit' --first-name Bob \
  --tier pro --pack pack_exotic --pack pack_edible
```

The script writes a scrypt-hashed password plus `tier` + `purchasedPacks`.
Re-running with the same username is idempotent (the derived `userId` is
stable). The script refuses to attach packs to a free-tier user — upgrade
first by re-creating with `--tier pro`.

Verify the login flow end-to-end:

```bash
API=$(cd infrastructure/terraform/environments/development && terraform output -raw api_url)

curl -s -X POST "$API/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"hunter2"}' | jq

# Expected response shape (matches UserModel in Sources/Models/UserModel.swift):
# {
#   "user_id":         123456,
#   "first_name":      "Alice",
#   "api_token":       "...",
#   "tier":            "free",
#   "purchased_packs": []
# }
```

Authenticated read:

```bash
TOKEN=$(curl -s -X POST "$API/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"hunter2"}' | jq -r .api_token)

curl -s "$API/v1/home" -H "Authorization: Bearer $TOKEN" | jq
# Free tier sees only access=="free" items.
```

## 6. iOS app configuration

`Sources/Config/AppConfig.swift` already maps build configs to env URLs:

| Build configuration | Env enum case  | Base URL                          |
|---------------------|----------------|-----------------------------------|
| DEBUG               | `.development` | `https://api-dev.brawpatch.com/v1` |
| STAGING             | `.staging`     | `https://api-staging.brawpatch.com/v1` (reserved) |
| Release             | `.production`  | `https://api.brawpatch.com/v1`     |

Before the brawpatch.com nameservers have propagated, point the iOS app at
the CloudFront URL directly by setting `BM_API_BASE_URL` in the scheme's
**Run → Arguments → Environment Variables** to e.g.
`https://d3davum6tf33oa.cloudfront.net/v1`. `Environment.baseURL` checks
that override first.

## Updating the backend

| Change                            | Command                                                              |
|-----------------------------------|----------------------------------------------------------------------|
| Lambda code (`lambda/index.mjs`)  | `./scripts/deploy.sh <env>` (re-archives + re-uploads function)     |
| Infrastructure (`modules/api/*.tf`) | `./scripts/deploy.sh <env>`                                       |
| `/home` or `/data` content        | edit `scripts/seed-content.mjs`, re-run `node scripts/seed-content.mjs --env <env>` |
| Add a user                        | `node scripts/create-user.mjs --env <env> --username ... ...`        |
| Upgrade a free user to pro        | re-run `create-user.mjs` with `--tier pro` (idempotent)              |
| Grant a pack purchase             | re-run `create-user.mjs` with `--tier pro --pack pack_exotic …`      |
| Revoke a session                  | delete the row from the sessions table in DynamoDB console           |

> Sessions cache `tier` + `purchasedPacks`. After an upgrade or pack purchase,
> the user must re-log to see new content.

## Tear down

```bash
cd backend/infrastructure/terraform/environments/<env>
terraform destroy
```

For `production` the S3 bucket has `force_destroy = false`, so you must
empty the bucket manually first. Dev's bucket is `force_destroy = true`
and is removed directly.

The `dns/` zone is a singleton — destroy it **last** and only if you are
shutting down the domain entirely.

## Cost estimate

For low-volume development everything stays inside the AWS free tier:

| Service        | Free tier              | Typical dev cost |
|----------------|------------------------|------------------|
| Lambda         | 1M requests/month free | $0               |
| API Gateway    | 1M HTTP requests free  | $0               |
| DynamoDB       | 25 GB + on-demand free | $0               |
| S3             | 5 GB free              | $0               |
| CloudFront     | 1 TB egress free       | $0               |
| KMS            | $1/month per key       | ~$1/month        |
| Route 53 zone  | n/a (no free tier)     | ~$0.50/month     |
| ACM cert       | free                   | $0               |
| CloudWatch     | 5 GB logs free         | $0               |

A parallel dev + prod stack roughly doubles the KMS line ($2/month).
Production at small scale (≈1k MAU) typically lands at $5–15/month.

## Troubleshooting

**`terraform apply` fails on `aws_s3_bucket.content`: bucket already exists**
S3 bucket names are globally unique. Change `app_name` in `terraform.tfvars`
to something more specific (e.g. include your username).

**Login returns 401 with correct credentials**
Confirm the user exists in the right env's table:
`aws dynamodb scan --table-name blooming-marvellous-development-users`.
Re-run `create-user.mjs --env <env> ...` if the row is missing.

**`/v1/home` returns 401 from the iOS app**
Either the user never logged in (no token in Keychain — `NetworkService`
throws `.unauthorized` before sending) or the server-side token has been
revoked / expired. Re-run the login flow and retry.

**`/v1/home` returns 404 "Content not found"**
You haven't seeded yet. Run `node scripts/seed-content.mjs --env <env>`.

**`/v1/home` returns 500 "Malformed content"**
The S3 object is the legacy v1 `[String]` shape, not v2. Re-seed:
`node scripts/seed-content.mjs --env <env>`.

**CloudFront returns 403 for a few minutes after deploy**
Distribution is still propagating. Use the `api_gateway_url` output to test
in the meantime.

**ACM cert apply hangs forever**
The certificate's DNS validation record can't be resolved, almost always
because the 123-reg nameservers don't yet point at Route 53 (or haven't
propagated). Verify with `dig NS brawpatch.com`; the four results must
match `terraform -chdir=environments/dns output name_servers`. Once they
match, re-run the apply.

**Lambda errors visible nowhere**
```bash
aws logs tail /aws/lambda/blooming-marvellous-development-api --follow
aws logs tail /aws/lambda/blooming-marvellous-production-api --follow
```
