#!/usr/bin/env bash
#
# deploy.sh — one-shot deploy of the BloomingMarvellousApp backend.
#
# What it does:
#   1. Installs Lambda npm dependencies into lambda/node_modules so the
#      Terraform archive_file picks them up.
#   2. Runs `terraform init` (idempotent) and `terraform apply`.
#   3. Prints the CloudFront URL to paste into AppConfig.swift.
#
# Requires: terraform >= 1.6, node >= 20, awscli configured.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAMBDA_DIR="$BACKEND_DIR/lambda"
TERRAFORM_DIR="$BACKEND_DIR/infrastructure/terraform"

echo "→ Installing Lambda dependencies"
( cd "$LAMBDA_DIR" && npm install --omit=dev --no-audit --no-fund )

echo "→ terraform init"
( cd "$TERRAFORM_DIR" && terraform init -input=false )

echo "→ terraform apply"
( cd "$TERRAFORM_DIR" && terraform apply -auto-approve )

echo
echo "✓ Deploy complete. Outputs:"
( cd "$TERRAFORM_DIR" && terraform output )

echo
echo "Next steps:"
echo "  • Seed content:    node scripts/seed-content.mjs"
echo "  • Create a user:   node scripts/create-user.mjs alice 'hunter2' Alice"
echo "  • Update iOS:      paste cloudfront_url + '/v1' into Sources/Config/AppConfig.swift"
