# Kairō documentation

Organized by [Diátaxis](https://diataxis.fr): **tutorials** teach, **how-to guides**
solve, **reference** describes, **explanation** deepens. Pick by what you need
right now.

## 🎓 Tutorials — *learning by doing*

| Doc | Takes you through |
|---|---|
| [Getting started — iOS](tutorials/getting-started-ios.md) | Clone → Simulator → your first capture, cited answer, and review card (~10 min) |
| [Getting started — web engine](tutorials/getting-started-web.md) | Run the local FastAPI + Ollama engine and get your first grounded answer |

## 🛠 How-to guides — *goal-oriented recipes*

| Doc | Goal |
|---|---|
| [Sideload onto an iPhone](how-to/sideload-iphone.md) | Install on a physical device with a free Apple ID (incl. the App-Groups workaround) |
| [Set up cloud answers](how-to/set-up-cloud-answers.md) | Deploy the answer proxy and enable generation on non-Apple-Intelligence iPhones |
| [Regenerate App Store screenshots](how-to/regenerate-screenshots.md) | Re-run the automated 6.9″ screenshot harness after UI changes |
| [Operate the GitHub Pages site](how-to/operate-github-pages.md) | The hosted privacy/support pages: updating, build status, unsticking deploys |
| [Submit to the App Store](APP_STORE_SUBMISSION.md) | The full TestFlight → App Review checklist with paste-ready metadata |
| [Deploy the web backend + sync server](DEPLOYMENT.md) | Docker/compose, token auth, zero-knowledge sync server |
| [Connect AI agents via MCP](MCP_SETUP.md) | Use your memory as a context layer for Claude and other MCP clients |

## 📖 Reference — *facts, precisely*

| Doc | Describes |
|---|---|
| [iOS architecture](reference/ios-architecture.md) | Targets, schemes, layer map, `AppConfig` keys, on-device store schema, build/test commands |
| [Engine reference](reference/engine.md) | Retrieval/generation parameters on both platforms, SM-2 numbers, card-generation rules, proxy API contract |

## 💡 Explanation — *why it's built this way*

| Doc | Discusses |
|---|---|
| [Privacy architecture](explanation/privacy-architecture.md) | On-device-first, what leaves the device and why, the proxy threat model, zero-knowledge sync |
| [Design decisions](explanation/design-decisions.md) | The decision log: storage, retrieval, cards, free-team constraints, what was deferred or dropped |
| [Mobile architecture & cost](MOBILE_ARCHITECTURE.md) | The Mac→iPhone layer mapping, the LLM-placement decision, and what an MVP costs |

## 📎 Everything else

- [Privacy Policy](PRIVACY.md) — the user-facing policy ([hosted copy](privacy.html) is what App Store Connect links to)
- [`BUILD_LOG.md`](../BUILD_LOG.md) — the chronological session-by-session build record
- [`screenshots/`](screenshots/) — marketing captures; App Store set in [`screenshots/appstore/`](screenshots/appstore/)
- [`proxy/README.md`](../proxy/README.md) — the cloud answer proxy's own deploy guide
