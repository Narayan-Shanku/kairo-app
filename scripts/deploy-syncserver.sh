#!/usr/bin/env bash
# Deploy the zero-knowledge sync server to Fly.io (free tier works).
# One-time:  brew install flyctl && fly auth login
# Usage:     scripts/deploy-syncserver.sh [app-name]
set -euo pipefail

if ! command -v fly >/dev/null 2>&1; then
  echo "flyctl not found. Install it:  brew install flyctl  (then: fly auth login)"
  exit 1
fi

APP="${1:-kairo-sync}"
cd "$(dirname "$0")/../syncserver"

# Create the app + volume from fly.toml if it doesn't exist yet, then deploy.
fly launch --copy-config --name "$APP" --no-deploy --yes 2>/dev/null || true
fly deploy

TOKEN="$(openssl rand -hex 16)"
echo
echo "Recommended: lock it down with a shared token:"
echo "  fly secrets set KAIRO_SYNC_TOKEN=$TOKEN --app $APP"
echo "Then on each device:  export KAIRO_SYNC_TOKEN=$TOKEN"
echo "Point the app at it:  export KAIRO_SYNC_SERVER=https://$APP.fly.dev"
