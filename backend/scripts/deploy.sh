#!/usr/bin/env bash
#
# deploy.sh — one-shot deploy of the BloomingMarvellousApp backend for one env.
#
# Usage:
#   ./scripts/deploy.sh development
#   ./scripts/deploy.sh production
#
# Flags (via env var):
#   NO_SEED=1   skip the plant-library ingest + seed-content steps. Use when
#               the only thing changing is Lambda code / Terraform infra and
#               you don't want to spend an hour re-running Gemini calls.
#
# What it does, in order:
#   1. Installs Lambda npm dependencies into lambda/node_modules so the
#      Terraform archive_file picks them up.
#   2. Runs `terraform init` + `terraform apply` against
#      environments/<env>/.
#   3. (Skipped under NO_SEED=1) Syncs the local Gemini API key to S3,
#      refreshes the plant library via ingest, and re-seeds the env's
#      S3 content via `node scripts/seed-content.mjs`. Idempotent —
#      re-running a deploy is safe.
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

if [ "${NO_SEED:-}" = "1" ]; then
  echo "→ NO_SEED=1 set — skipping Gemini key sync, ingest, and seed-content."
else
  # Sync the Gemini API key to the env's S3 bucket, KMS-encrypted by the
  # bucket's default server-side encryption. The local file is gitignored
  # (canonical store is S3). Skipped silently when no local copy exists —
  # in that case the ingest will fall back to whatever's already in S3 or
  # to family-level grower's tips.
  CONTENT_BUCKET="$( cd "$ENV_DIR" && terraform output -raw s3_bucket_name )"

  LOCAL_GEMINI_KEY="$BACKEND_DIR/../API_Keys/GeminiKey.txt"
  if [ -f "$LOCAL_GEMINI_KEY" ]; then
    echo "→ Syncing Gemini API key to s3://$CONTENT_BUCKET/secrets/gemini.key"
    aws s3 cp "$LOCAL_GEMINI_KEY" "s3://$CONTENT_BUCKET/secrets/gemini.key" \
      --content-type "text/plain" \
      --metadata "purpose=gemini-ingest,managed-by=deploy.sh" \
      --no-progress
  else
    echo "→ Skipping Gemini key sync (no local API_Keys/GeminiKey.txt)"
  fi

  LOCAL_TREFLE_KEY="$BACKEND_DIR/../API_Keys/TrefleKey.txt"
  if [ -f "$LOCAL_TREFLE_KEY" ]; then
    echo "→ Syncing Trefle API key to s3://$CONTENT_BUCKET/secrets/trefle.key"
    aws s3 cp "$LOCAL_TREFLE_KEY" "s3://$CONTENT_BUCKET/secrets/trefle.key" \
      --content-type "text/plain" \
      --metadata "purpose=trefle-ingest,managed-by=deploy.sh" \
      --no-progress
  else
    echo "→ Skipping Trefle key sync (no local API_Keys/TrefleKey.txt)"
  fi

  echo "→ Refreshing plant library from Wikidata / Wikipedia / Commons"
  # --soft-fail keeps the deploy moving even if an external API is down — the
  # already-committed backend/data/library.json is the fallback in that case.
  # GEMINI_KEY_S3_ENV scopes the S3-key fallback to the env we're deploying.
  ( cd "$BACKEND_DIR" && GEMINI_KEY_S3_ENV="$ENV" node scripts/ingest-plants.mjs --soft-fail )

  echo "→ Seeding S3 content ($ENV)"
  ( cd "$BACKEND_DIR" && node scripts/seed-content.mjs --env "$ENV" )
fi

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
