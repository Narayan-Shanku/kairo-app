// Kairō — stateless cloud-generation proxy.
//
// Purpose: let the iOS app produce grounded, generated answers on iPhones that
// DON'T have Apple Intelligence (iPhone 11–14, SE, …). The phone does capture,
// embedding, and retrieval on-device and sends ONLY the already-built prompt
// (the top-k retrieved memory snippets + the question) here. This Worker holds
// the Anthropic API key and calls the Claude Messages API, returning the answer.
//
// Contract (matches the app's CloudGenerationService):
//   POST /            { "prompt": "<retrieved snippets + question>" }
//   200  ->           { "answer": "<grounded answer with date citations>" }
//
// It is stateless and zero-log: it stores nothing and forwards nothing except
// the prompt to the LLM for the duration of the request.
//
// Secrets / config (see wrangler.toml + README):
//   ANTHROPIC_API_KEY  (secret)  — required
//   MODEL              (var)     — defaults to claude-opus-4-8; set
//                                  "claude-haiku-4-5" for lower latency/cost
//   SHARED_TOKEN       (secret)  — optional; if set, requests must send
//                                  "Authorization: Bearer <SHARED_TOKEN>"
//   DAILY_CAP          (var)     — optional; max forwarded requests per UTC day
//   USAGE              (KV)      — optional; backs the daily-cap counter

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const DEFAULT_MODEL = "claude-opus-4-8";

// No system prompt on purpose: the app's prompts (Ask / Digest / card
// distillation) are each self-contained, and the on-device model runs
// prompt-only — so the proxy forwards the prompt verbatim to keep both paths
// identical and avoid biasing non-Q&A tasks.

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: cors() });
    if (request.method !== "POST") return json({ error: "POST only" }, 405);

    // Optional shared-secret gate (abuse control — the payload is not sensitive).
    if (env.SHARED_TOKEN) {
      const auth = request.headers.get("authorization") || "";
      if (auth !== `Bearer ${env.SHARED_TOKEN}`) return json({ error: "unauthorized" }, 401);
    }

    if (!env.ANTHROPIC_API_KEY) return json({ error: "proxy misconfigured: no API key" }, 500);

    let prompt;
    try {
      const body = await request.json();
      prompt = (body && body.prompt != null ? String(body.prompt) : "").trim();
    } catch {
      return json({ error: "invalid JSON body" }, 400);
    }
    if (!prompt) return json({ error: "empty prompt" }, 400);

    // Daily cap — a cost/abuse ceiling. Soft: skipped unless both the USAGE KV
    // binding and a positive DAILY_CAP are set. We reserve a slot BEFORE the
    // paid call, so the ceiling holds even if the upstream request later fails.
    const cap = parseInt(env.DAILY_CAP || "0", 10);
    if (env.USAGE && cap > 0) {
      const key = `count:${new Date().toISOString().slice(0, 10)}`; // per UTC day
      const used = parseInt((await env.USAGE.get(key)) || "0", 10);
      if (used >= cap) return json({ error: "daily limit reached", cap }, 429);
      // Non-atomic increment — a soft ceiling is enough for cost control.
      await env.USAGE.put(key, String(used + 1), { expirationTtl: 172800 });
    }

    let upstream;
    try {
      upstream = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body: JSON.stringify({
          model: env.MODEL || DEFAULT_MODEL,
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });
    } catch (e) {
      return json({ error: "upstream request failed", detail: String(e) }, 502);
    }

    if (!upstream.ok) {
      const detail = await upstream.text();
      return json({ error: "upstream error", status: upstream.status, detail }, 502);
    }

    const data = await upstream.json();
    const answer = (data.content || [])
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("")
      .trim();

    return json({ answer });
  },
};

function cors() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type, authorization",
  };
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json", ...cors() },
  });
}
