# Kairō — cloud-generation proxy

A tiny **stateless** Cloudflare Worker that lets Kairō produce grounded, generated
answers on iPhones **without Apple Intelligence** (iPhone 11–14, SE, …).

Everything else in Kairō still runs on-device. The phone captures, embeds, and
retrieves locally, then sends **only the already-built prompt** — the top-k
retrieved memory snippets plus the question — to this proxy. The proxy holds the
Anthropic API key (so it never ships inside the App Store binary) and calls the
Claude [Messages API](https://docs.claude.com/en/api/messages), returning the
answer. It stores nothing.

```
iPhone 11 (on-device)                         this Worker            Anthropic
  capture · embed · retrieve top-5  ──prompt──▶  add key ──▶  POST /v1/messages
  render answer + citations         ◀──answer──                claude-opus-4-8
```

This maps 1:1 to the app's `CloudGenerationService`:

```
POST /      { "prompt": "<retrieved snippets + question>" }
200  →      { "answer": "<grounded answer with date citations>" }
```

## Deploy (free tier is plenty)

```bash
cd proxy
npm i -g wrangler                       # or: npx wrangler ...
wrangler login                          # opens the browser once

wrangler secret put ANTHROPIC_API_KEY   # paste your Anthropic API key
# optional: gate the endpoint so only your app can call it
wrangler secret put SHARED_TOKEN        # paste any random string

wrangler deploy                         # prints https://kairo-generation-proxy.<you>.workers.dev
```

Test it:

```bash
curl -s https://kairo-generation-proxy.<you>.workers.dev \
  -H 'content-type: application/json' \
  -d '{"prompt":"MEMORIES:\n[1] Jun 3 (Health): bloated after pizza.\n\nQUESTION: what triggers my bloating?"}'
# → {"answer":"Based on your Jun 3 note, dairy/pizza seems to trigger it…"}
```

## Point the app at it

In `ios/Kairo/Config/AppConfig.swift`:

```swift
static let cloudGenerationURL: URL? =
    URL(string: "https://kairo-generation-proxy.<you>.workers.dev")
```

If you set `SHARED_TOKEN`, also send it from the app — add an
`Authorization: Bearer <token>` header in `CloudGenerationService.generate`.

Rebuild and run. On an Apple-Intelligence device nothing changes (it stays 100%
on-device); on an iPhone 11–14 the **Ask** answer and **weekly Digest** now come
back generated instead of degrading to an extractive list.

## Model choice & cost

Defaults to **`claude-opus-4-8`** (highest quality). A Kairō answer is a short,
grounded reply over ~5 snippets — a great fit for **`claude-haiku-4-5`**, which is
much faster and ~5× cheaper per query. To switch, edit `MODEL` in `wrangler.toml`
and redeploy. Cost scales per query, not per user, and only non-Apple-Intelligence
devices ever hit the proxy.

## Notes

- **Stateless / zero-log.** No storage, no logging of prompts or answers.
- **Privacy.** Only the retrieved snippets + question leave the device — never the
  full memory store. This is exactly "Option C" from
  [`docs/MOBILE_ARCHITECTURE.md`](../docs/MOBILE_ARCHITECTURE.md).
- **Prompt caching** isn't used here: every request has a unique question +
  snippets and the shared system prompt is far below the cache minimum, so there's
  no reusable prefix to cache.
- Any host works (Vercel/Deno/Fly/Lambda) — keep the same `{prompt}` → `{answer}`
  contract and the app is unchanged.
