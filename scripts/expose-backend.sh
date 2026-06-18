#!/usr/bin/env bash
# Expose your LOCAL Kairō backend to your phone over a free Cloudflare quick
# tunnel (no account needed). The printed https URL → put it in the iOS app's
# Config.baseURL.
#
# ⚠️ A tunnel makes your backend reachable from the internet. SET A TOKEN FIRST so
# it isn't wide open:
#     export KAIRO_API_TOKEN="$(openssl rand -hex 16)"; echo "$KAIRO_API_TOKEN"
#     # restart the backend with that env, then put the token in the client.
set -euo pipefail

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found. Install it:  brew install cloudflared"
  exit 1
fi

if [ -z "${KAIRO_API_TOKEN:-}" ]; then
  echo "WARNING: KAIRO_API_TOKEN is not set — your backend will be PUBLIC and unauthenticated."
  echo "Generate one:  export KAIRO_API_TOKEN=\$(openssl rand -hex 16)  (then restart the backend)"
fi

PORT="${1:-8000}"
echo "Exposing http://localhost:${PORT} …"
cloudflared tunnel --url "http://localhost:${PORT}"
