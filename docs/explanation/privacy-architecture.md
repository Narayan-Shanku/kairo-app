# Why Kairō's privacy architecture looks the way it does

Kairō's pitch is simple: your memory store lives on your phone. This document
explains the reasoning behind the architecture that makes that claim true — why
generation is the one exception, why that exception is a proxy rather than a
direct API call, what the threat model honestly is, and why the app's privacy
labels say "User Content collected" even though almost nothing is.

For the user-facing policy itself, see [PRIVACY.md](../PRIVACY.md). For the
architecture decision record this grew out of, see
[MOBILE_ARCHITECTURE.md](../MOBILE_ARCHITECTURE.md).

## On-device-first is the spine, and generation is the one exception

Almost every layer of Kairō ports cleanly to the phone: voice capture
(`AVAudioRecorder` + WhisperKit), embeddings (`NLEmbedding`), the vector store
and metadata, hybrid retrieval and re-ranking, and the SM-2 review scheduler
all run locally with no network. The one layer that *can't* run everywhere is
LLM generation: Apple's Foundation Models are on-device but only exist on
Apple Intelligence hardware (iOS 26+), and older iPhones (11–14, SE) have no
comparable local model.

[MOBILE_ARCHITECTURE.md](../MOBILE_ARCHITECTURE.md) frames this as the LLM
decision and picks **Option C**: keep capture, storage, and retrieval
on-device, and send only the already-assembled prompt — the top-k retrieved
snippets plus the question — to a stateless endpoint when local generation is
unavailable. Option A (thin client, raw data on a server) was rejected as the
end state because it inverts the product's promise; Option B (a small local
model on every device) was deferred because it trades answer quality and
device support for a purity the retrieval design already mostly delivers.

That single constraint shaped everything downstream. Because generation is the
*only* network-touching layer, privacy stops being a policy and becomes a
property of the dataflow: there is exactly one wire to audit, and what crosses
it is minimized by construction. `CloudGenerationService` in
`ios/Kairo/Core/Services/GenerationService.swift` can only send the prompt it
was handed — the full store is never serialized for the network in the first
place.

## Why a proxy, not a direct LLM API call from the app

The obvious shortcut — put an Anthropic API key in the app and call the
Messages API directly — fails twice. An API key compiled into a binary is
extractable by anyone with the IPA, which turns a personal key into a public
one; and shipping embedded third-party API secrets is a well-known App Store
rejection path. So the key lives where keys belong: in a Cloudflare Worker
secret (`ANTHROPIC_API_KEY` in `proxy/worker.js`), server-side, rotatable
without shipping an app update.

The Worker is deliberately dumb. It is stateless and zero-log: it accepts
`{ "prompt": ... }`, forwards it verbatim to the Claude API, and returns
`{ "answer": ... }`. It adds no system prompt on purpose, so the cloud path
and the on-device path run the exact same prompts and neither biases the
other. Holding the key in one place also enables the one control a free,
account-less product needs most: a global spend ceiling (`DAILY_CAP`, backed
by a KV counter that reserves a slot *before* the paid upstream call, so the
ceiling holds even when requests fail).

## The threat model, honestly

The proxy accepts an optional shared bearer token (`SHARED_TOKEN`). That token
ships inside the app binary, which means it is **not a secret** — anyone
determined enough can extract it. It is an abuse gate: it keeps drive-by
scanners and casual freeloaders off the endpoint, nothing more. The actual
cost ceiling is the daily cap; the design assumes the token will eventually
leak and stays safe anyway. `ios/Kairo/Config/AppConfig.swift` says exactly
this in its comments — a "low-value abuse-control gate, NOT a real secret."

This honesty extends to the repository itself. The committed `AppConfig.swift`
has `nil` for both `cloudGenerationURL` and `cloudGenerationToken`; the real
values exist only as a local, never-committed diff on the maintainer's
machine. A public repo should demonstrate the convention, not the deployment.

What's *not* in the threat model matters as much: the payload is a handful of
retrieved snippets plus a question, never the store; there are no accounts, no
user identifiers, and no logs, so even the worst case — a fully compromised
proxy — sees fragments it cannot link to a person or reassemble into a life.

## Truth in labeling: why the docs say "User Content collected"

The marketing-friendly claim would be "no data ever leaves your device." It
would also be false on non-Apple-Intelligence phones, and observably so — a
network sniffer sees the HTTPS request. So the App Store privacy label
declares **User Content → Other User Content** (App Functionality only, not
linked to identity, not used for tracking), and
[PRIVACY.md](../PRIVACY.md) names Cloudflare and Anthropic as the two
processors in the request path. [APP_STORE_SUBMISSION.md](../APP_STORE_SUBMISSION.md)
is blunt about the alternative: "Data Not Collected" with observable network
calls is a Guideline 5.1.1/5.1.2 rejection.

The same reasoning motivates the opt-out. Settings → "Use private cloud for
answers" (default on) disables the proxy entirely; the app then degrades to
extractive answers — it shows your most relevant memories instead of writing
prose. The toggle exists because a privacy-first app must let the user choose
the strict interpretation, even at a quality cost. Trust comes from the app's
claims matching its observable behavior, not from the strongest claim it can
get away with.

## The same philosophy, different problem: zero-knowledge sync

The web build's optional sync (`backend/sync/`, served by `syncserver/`)
faces the opposite problem — data *must* leave the device to reach another
one — and applies the same principle: minimize what any server can learn. The
snapshot is encrypted on the client before upload: the passphrase is stretched
with Argon2id (memory-hard: 64 MB, 3 iterations) into a 256-bit key, and the
blob is sealed with AES-256-GCM, so a wrong passphrase fails loudly instead of
yielding garbage (`backend/sync/crypto.py`). The blob id is a one-way hash of
the passphrase, so the server indexes ciphertext by an opaque key it cannot
reverse. `syncserver/app.py` describes itself accurately: it "deliberately
knows nothing about Kairō" — a breach exposes nothing readable.

Generation and sync thus answer the same question two ways. Where the data
flow can be made meaningless to the server (sync), encrypt end-to-end. Where
the server must read the data to do its job (LLM generation), shrink the data
to the minimum, keep no state, and keep no logs.

## What would change at scale

The shared-token-plus-daily-cap design is right for a free app with no
accounts: there is nothing to authenticate *as*. If Kairō ever grew a paid
backend, the calculus flips — a paying user is entitled to capacity, which
requires attributing requests. The likely shape is per-user tokens issued
after App Store receipt validation: the receipt proves purchase without
Kairō operating accounts or holding emails, and per-token rate limits replace
the single global cap. That would trade a little of today's "nothing to link"
purity for abuse resistance and fairness. It is a direction, not a promise —
and notably, none of it would touch the spine: capture, embeddings, retrieval,
and the memory store would stay on the phone regardless.
