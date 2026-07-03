# How to set up cloud answers for iPhones without Apple Intelligence

On Apple-Intelligence devices Kairō generates answers fully on-device
(`GenerationService`, Apple Foundation Models). On iPhones without it
(iPhone 11–14, SE, …) the app can fall back to a stateless Cloudflare Worker
proxy: the phone still captures, embeds, and retrieves locally, and sends only
the already-built prompt (top-k snippets + question). This guide deploys that
proxy and points the app at it. Without it, older devices degrade to
extractive answers — that is supported behavior, not a failure.

## Prerequisites

- A Cloudflare account (free tier is enough) and Node.js (`npx wrangler`).
- An Anthropic API key.
- The iOS project building locally (Xcode; see [sideload-iphone.md](sideload-iphone.md) for device installs).

## 1. Deploy the Worker

Follow [`proxy/README.md`](../../proxy/README.md) — the short version:

```bash
cd proxy
npx wrangler login                          # opens the browser once
npx wrangler secret put ANTHROPIC_API_KEY   # paste your Anthropic API key
npx wrangler secret put SHARED_TOKEN        # paste any random string
npx wrangler deploy
```

`SHARED_TOKEN` is technically optional, but set it: the Worker then rejects
requests without a matching `Authorization: Bearer` header.

**Expected output:** `wrangler deploy` prints your endpoint,
`https://kairo-generation-proxy.<you>.workers.dev`. Note it — it is
`<your-proxy-url>` below.

## 2. Smoke-test with curl

```bash
curl -s <your-proxy-url> \
  -H 'content-type: application/json' \
  -H 'Authorization: Bearer <token>' \
  -d '{"prompt":"MEMORIES:\n[1] Jun 3 (Health): bloated after pizza.\n\nQUESTION: what triggers my bloating?"}'
```

**Expected output:** `{"answer":"…grounded answer citing Jun 3…"}`. Anything
else, see [Troubleshooting](#troubleshooting).

## 3. Point the app at the proxy (local tree only)

Edit `ios/Kairo/Config/AppConfig.swift`:

```swift
static let cloudGenerationURL: URL? =
    URL(string: "<your-proxy-url>")          // must be HTTPS

static let cloudGenerationToken: String? = "<token>"   // must match SHARED_TOKEN
```

**The convention:** this repo is public, so both values are committed as
`nil`. The real URL and token live only as an **uncommitted local diff** —
never commit them. Consequently, any Archive/App Store build must be made
from a working tree that carries this diff; a clean checkout builds an app
with no cloud fallback (older devices then get extractive answers).

The token is a low-value abuse gate, not a real secret — it ships in the app
binary. The Worker's daily cap (step 5) is the actual cost ceiling.

**Expected output:** `git status` shows `AppConfig.swift` modified; do not
stage it.

## 4. Rebuild and verify in the Simulator

Rebuild the app (Xcode, or `scripts/deploy_device.sh` for a device — see
[sideload-iphone.md](sideload-iphone.md)). The Simulator is the ideal test
bed: Apple Foundation Models are unavailable there, so `CloudGenerationService`
is exercised exactly as on an iPhone 11–14.

1. Run the app in an iPhone Simulator.
2. Capture a memory or two.
3. Open **Ask** and ask a question about them.

**Expected output:** a generated, grounded answer with date citations instead
of an extractive snippet list. The weekly Digest is also generated via the
same path. If the proxy call fails, the app silently returns the extractive
fallback — check the Worker with `npx wrangler tail` while asking.

Users can opt out at any time via **Settings → "Use private cloud for
answers"** in the app; when off (or when no proxy is configured), everything
stays on-device.

## 5. Tune and operate

All knobs live in [`proxy/wrangler.toml`](../../proxy/wrangler.toml); edit and
`npx wrangler deploy` to apply:

- **`MODEL`** — the committed config ships `claude-haiku-4-5` (fast, cheap,
  well-suited to short grounded answers over ~5 snippets). The Worker's
  built-in default if the var is removed is `claude-opus-4-8` (highest
  quality, ~5× the cost).
- **`DAILY_CAP`** — max forwarded requests per UTC day (ships as `200`),
  backed by the `USAGE` KV namespace. Requests over the cap get HTTP 429
  without touching the paid API.

Rotate the token anytime:

```bash
cd proxy
npx wrangler secret put SHARED_TOKEN   # paste the new value
```

then update `AppConfig.cloudGenerationToken` (locally, per step 3) and
rebuild. No redeploy is needed for secret changes.

## Troubleshooting

- **`{"error":"unauthorized"}` (401)** — the `Bearer` token doesn't match the
  Worker's `SHARED_TOKEN`. Re-run `npx wrangler secret put SHARED_TOKEN` and
  make sure `AppConfig.cloudGenerationToken` is byte-identical.
- **`{"error":"daily limit reached","cap":N}` (429)** — the daily cap is hit.
  Raise `DAILY_CAP` in `wrangler.toml` and redeploy; the counter resets each
  UTC day.
- **SSL handshake error on the first curl** — fresh `workers.dev` subdomains
  can take a few minutes to get TLS certificates. Wait and retry.
- **Checking today's usage** — the counter is a KV key `count:YYYY-MM-DD`
  (UTC). It must be read from the **remote** namespace, or you'll see the
  empty local dev store:

  ```bash
  cd proxy
  npx wrangler kv key get "count:$(date -u +%F)" --binding USAGE --remote
  ```
- **Answers still extractive on an Apple-Intelligence phone** — expected: the
  proxy is only used when on-device generation is unavailable, and
  `CloudGenerationService.generate` returns nil on any error so the app
  degrades rather than breaks.
