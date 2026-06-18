# Kairō — Deployment & Encrypted Sync

Two deployable pieces, very different weights:

| Piece | What | Where to run |
|---|---|---|
| **Sync server** (`syncserver/`) | Zero-knowledge encrypted-blob store. No GPU, no secrets, tiny. | A cheap public host (Fly.io / Render / any VPS) |
| **Backend** (`backend/`) | The full Capture→Retrieval engine + Ollama. Heavier; needs the LLM. | The founder's Mac (+ tunnel) or a VPS with Ollama |

> The sync server is the only thing that *must* be public. The backend can stay
> self-hosted on your Mac and be reached by your phone over a free tunnel.

## Encrypted sync — how it works

`passphrase --Argon2id--> 256-bit key --AES-256-GCM--> ciphertext blob --> sync server`

All encryption happens **on the device** (`backend/sync/`). The sync server only
ever stores an opaque ciphertext blob under a passphrase-derived id. It has no key
and never sees plaintext — a breach exposes nothing readable. **Lose the passphrase
and the data is unrecoverable by design.** (Verified: pushing a store yields a blob
with no plaintext; a fresh device restores it with the passphrase; the wrong
passphrase can't even locate it.)

Use it:
```bash
# point the app at your sync server (defaults to http://localhost:8787)
export KAIRO_SYNC_SERVER=https://sync.your-domain.com

curl -X POST localhost:8000/api/sync/push -H 'Content-Type: application/json' \
     -d '{"passphrase":"your secret passphrase"}'
# on another device running Kairō:
curl -X POST localhost:8000/api/sync/pull -H 'Content-Type: application/json' \
     -d '{"passphrase":"your secret passphrase"}'
```

## Secure it before exposing (important)

An exposed backend is **wide open** unless you set a token. Both services support
optional bearer-token auth (opt-in — unset means no auth, for local dev):

```bash
# backend: gate all /api/* (except /api/health)
export KAIRO_API_TOKEN="$(openssl rand -hex 16)"   # then restart the backend
# sync server: gate /blob/*
export KAIRO_SYNC_TOKEN="$(openssl rand -hex 16)"
```
Clients send it automatically:
- **Web app** — prompts for the token on first 401 and stores it (localStorage).
- **iOS app** — set `AppConfig.apiToken`.
- **Sync client** — reads `KAIRO_SYNC_TOKEN` from the environment.

Helper scripts: `scripts/expose-backend.sh` (Cloudflare quick tunnel, warns if no
token) and `scripts/deploy-syncserver.sh` (Fly.io deploy + token).

## Deploy the sync server

**Docker (any host):**
```bash
docker build -t kairo-syncserver ./syncserver
docker run -d -p 8787:8787 -v kairo-sync:/data kairo-syncserver
```

**Fly.io:** `cd syncserver && fly launch` (it detects the Dockerfile) → add a
volume for `/data` → `fly deploy`. **Render:** new Web Service from `syncserver/`
(Docker), attach a disk at `/data`. Then set `KAIRO_SYNC_SERVER` to the public URL.

> ⚠️ Provisioning the host (Fly/Render/VPS account, a domain, TLS, payment) is
> yours to do — those are the only steps not automatable from here. The container
> itself is verified (`docker run … /health` → ok).

## Self-host the full stack (backend + Ollama + sync)

```bash
docker compose up --build
# first run, pull the models into the ollama service:
docker compose exec ollama ollama pull llama3.1:8b
docker compose exec ollama ollama pull nomic-embed-text
```
Backend → `:8000`, sync server → `:8787`, Ollama → `:11434`.

**Phone → your Mac (no cloud):** keep the backend on your Mac and expose it with a
free tunnel so the iOS app can reach it from anywhere:
```bash
# Cloudflare Tunnel (free):
cloudflared tunnel --url http://localhost:8000
# …or Tailscale: use your Mac's tailnet IP as Config.baseURL in the iOS app.
```

## Environment variables

| Var | Default | Used by |
|---|---|---|
| `KAIRO_HOME` | `~/.kairo` | backend — data dir |
| `OLLAMA_HOST` | `http://localhost:11434` | backend — LLM/embeddings |
| `KAIRO_SYNC_SERVER` | `http://localhost:8787` | backend sync client |
| `KAIRO_SYNC_DIR` | `/tmp/kairo-sync-blobs` | sync server — blob storage |
| `KAIRO_SYNC_MAX_BYTES` | `52428800` (50 MB) | sync server — max blob size |
| `KAIRO_API_TOKEN` | _(unset)_ | backend — bearer token for `/api/*` |
| `KAIRO_SYNC_TOKEN` | _(unset)_ | sync server — bearer token for `/blob/*` |

## Status / next

- ✅ Encrypted sync (Python/web ↔ server) built + verified end-to-end.
- ✅ Sync server containerized + verified.
- ⏳ **iOS sync client** — needs the same Argon2id + AES-256-GCM in Swift
  (CryptoKit has AES-GCM; Argon2 needs an SPM package). Documented as the next step.
- ⏳ Actual cloud provisioning — your accounts/payment; commands above.
