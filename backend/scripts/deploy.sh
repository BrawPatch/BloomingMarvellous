#!/usr/bin/env bash
#
# deploy.sh — one-shot deploy of the BloomingMarvellousApp backend for one env.
#
# Usage:
#   ./scripts/deploy.sh development
#   ./scripts/deploy.sh production
#
# What it does, in order:
#   1. Installs Lambda npm dependencies into lambda/node_modules so the
#      Terraform archive_file picks them up.
#   2. Runs `terraform init` + `terraform apply` against
#      environments/<env>/.
#   3. Re-seeds the env's S3 bucket via `node scripts/seed-content.mjs`.
#      Idempotent — re-running a deploy is safe.
#   4. Prints the canonical API URL for that env.
#
# Requires: terraform >= 1.6, node >= 22, awscli configured (AWS_PROFILE
# pointing at an SSO profile for the target account).

set -euo pipefail

ENV="${1:-}"
case "$ENV" in
  development|production) ;;
  *)
    echo "Usage: $0 <development|production>" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAMBDA_DIR="$BACKEND_DIR/lambda"
ENV_DIR="$BACKEND_DIR/infrastructure/terraform/environments/$ENV"

echo "→ Deploying $ENV from $ENV_DIR"

echo "→ Installing Lambda dependencies"
( cd "$LAMBDA_DIR" && npm install --omit=dev --no-audit --no-fund )

echo "→ Installing deploy-script dependencies"
( cd "$SCRIPT_DIR" && npm install --omit=dev --no-audit --no-fund )

echo "→ terraform init ($ENV)"
( cd "$ENV_DIR" && terraform init -input=false )

echo "→ terraform apply ($ENV)"
( cd "$ENV_DIR" && terraform apply -auto-approve )

echo "→ Seeding S3 content ($ENV)"
( cd "$BACKEND_DIR" && node scripts/seed-content.mjs --env "$ENV" )

echo
echo "✓ Deploy complete for $ENV. Outputs:"
( cd "$ENV_DIR" && terraform output )

echo
API_URL="$( cd "$ENV_DIR" && terraform output -raw api_url )"
echo "API base URL: $API_URL"
echo
echo "Next steps:"
echo "  • Create a user: node scripts/create-user.mjs --env $ENV --username … --password … --first-name …"
echo "  • Smoke test:    curl -X POST $API_URL/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"…\",\"password\":\"…\"}'"
