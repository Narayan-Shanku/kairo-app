# Getting started: Kairō on iOS in 10 minutes

In this tutorial you will build the Kairō iPhone app from a fresh clone, run it
in the iOS Simulator, and experience the full loop: load a demo memory set, ask
your memories a question, review a flashcard, and capture a new check-in. No
Apple developer account, no server, and no signing setup are needed — the
Simulator requires none of them.

## 1. Install the two prerequisites

Install **full Xcode** from the Mac App Store (free, ~7 GB — the Command Line
Tools alone are not enough), then install XcodeGen:

```bash
brew install xcodegen
```

## 2. Generate and open the project

From the repo root:

```bash
cd ios
xcodegen generate
open Kairo.xcodeproj
```

`xcodegen generate` reads `ios/project.yml` and prints
`Created project at .../Kairo.xcodeproj`. Xcode opens with the **Kairo** scheme
already selected.

## 3. Run it in the Simulator

In Xcode's toolbar, pick any **iPhone Simulator** (e.g. iPhone 17) as the run
destination, then press **⌘R**.

The Simulator boots and Kairō launches on the **Home** tab. Along the bottom you
see five tabs: Home, Capture, Ask, Review, Digest.

## 4. Load the demo memories

On Home, tap **"New here? Load demo memories"**.

After a moment, the app fills with **13 memories** (health, career, learning,
projects, fitness, finance, relationships) and **5 review cards**. Everything —
including the embeddings — is computed and stored on-device.

Now tap **Check in**. iOS asks for notification permission right here — this is
intentional: Kairō only asks once you've done something worth being reminded
about (your streak), not on first launch. Allow or deny; the tutorial works
either way.

## 5. Ask your memories a question

Open the **Ask** tab and tap the suggestion **"What triggers my bloating?"**.

Kairō searches the demo memories on-device and returns a grounded answer with
date-stamped citations pointing at the check-ins it drew from (the lentils and
short-sleep entries).

One honest note about the Simulator: it has no Apple Intelligence, so the
on-device generation path (Apple Foundation Models) is unavailable there. What
you see depends on `ios/Kairo/Config/AppConfig.swift`:

- If a cloud answer proxy is configured (see
  [How to set up cloud answers](../how-to/set-up-cloud-answers.md)), the
  already-retrieved snippets are sent to it and you get a fluent generated answer.
- If not — the committed default, where `cloudGenerationURL` is `nil` — the
  answer degrades to an extractive list of the most relevant memories.

Both outcomes are correct behavior. Retrieval, citations, and storage are always
on-device either way.

## 6. Review a card

Open the **Review** tab. A card is due — for example *"What's your strongest
bloating trigger?"*.

Tap **Show answer**, then rate yourself: **Again**, **Hard**, **Good**, or
**Easy**. The SM-2 scheduler reschedules the card — an easy card moves days
away, a lapsed one comes right back. Rate through a couple more if you like.

## 7. Capture your own check-in

Open the **Capture** tab, type a short check-in — for example:

> Slept badly again, but the morning run cleared my head before the standup.

Tap **Save**. The status line confirms with the life domains Kairō assigned
on-device, e.g. `✓ Saved · Health, Fitness`. Your new memory is now searchable
from Ask, exactly like the demo ones.

## 8. See where your data lives

Everything you just created — memories with embeddings, the SM-2 card state,
your check-in dates — is one JSON file, `kairo-store.json`, in the app's
Documents directory (see `ios/Kairo/Core/Storage/OnDeviceStore.swift`). No
server, no database engine, nothing leaves the device.

That's the full loop: capture → auto-organize → ask → review.

## Where next

- [Getting started: the web engine](getting-started-web.md) — the fuller
  Python/FastAPI version with hybrid RAG and an MCP server.
- [How to set up cloud answers](../how-to/set-up-cloud-answers.md) — enable
  generated answers on devices (and Simulators) without Apple Intelligence.
- [How to sideload Kairō onto your iPhone](../how-to/sideload-iphone.md) — run
  it on real hardware, where generation is fully on-device.
