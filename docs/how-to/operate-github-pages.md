# How to operate the GitHub Pages site

The Pages site hosts the two URLs App Store Connect requires (see
[../APP_STORE_SUBMISSION.md](../APP_STORE_SUBMISSION.md)):

| Page | URL | Source file |
|---|---|---|
| Support URL | https://narayan-shanku.github.io/kairo-app/ | `docs/index.html` |
| Privacy Policy URL | https://narayan-shanku.github.io/kairo-app/privacy.html | `docs/privacy.html` |

Pages is configured to serve the `main` branch `/docs` folder with the **legacy**
(Jekyll-era) builder. `docs/.nojekyll` disables Jekyll processing, so files are
served as-is. There is no deploy step to run — pushing to `main` redeploys
automatically.

## Prerequisites

- Push access to `Narayan-Shanku/kairo-app`.
- `gh` CLI authenticated (`gh auth status`).

## Publish a change

1. Edit the page under `docs/` (for example `docs/privacy.html`), commit, and push to `main`:

   ```sh
   git push origin main
   ```

   Expected: the push itself triggers a Pages build; nothing else to do.

2. Check the build status:

   ```sh
   gh api repos/Narayan-Shanku/kairo-app/pages/builds --jq '.[0] | {status, duration, created_at, error}'
   ```

   Expected within ~30 seconds of pushing:

   ```json
   {"status":"built","duration":26029,"created_at":"...","error":{"message":null}}
   ```

   A healthy build takes ~20–30s (`duration` is in milliseconds). While it is
   in flight you will see `"status":"building"` — re-run the command.

3. Verify the live page. Pages sits behind a CDN, so bust the cache when checking:

   ```sh
   curl -s "https://narayan-shanku.github.io/kairo-app/privacy.html?v=$(date +%s)" | head -20
   ```

   Expected: the HTML you just pushed.

## Check overall Pages configuration

```sh
gh api repos/Narayan-Shanku/kairo-app/pages --jq '{build_type, source, html_url, status}'
```

Expected:

```json
{"build_type":"legacy","source":{"branch":"main","path":"/docs"},"html_url":"https://narayan-shanku.github.io/kairo-app/","status":"built"}
```

## Optional: switch to an Actions-based deploy

The legacy builder is flaky (see Troubleshooting). An Actions workflow deploys
deterministically and shows real logs. Two prerequisites, **in this order**:

1. Get the workflow file onto `main`. Your `gh` token needs the `workflow`
   scope to push files under `.github/workflows/`:

   ```sh
   gh auth refresh -h github.com -s workflow
   ```

   Run this in a real interactive terminal — the device-code flow times out if
   run detached (e.g. from a script or agent). Alternatively, create the file
   via GitHub's web editor, which needs no token change.

   Commit this as `.github/workflows/pages.yml`:

   ```yaml
   name: Deploy GitHub Pages

   on:
     push:
       branches: [main]
     workflow_dispatch:

   permissions:
     contents: read
     pages: write
     id-token: write

   concurrency:
     group: pages
     cancel-in-progress: true

   jobs:
     deploy:
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - uses: actions/checkout@v4
         - uses: actions/configure-pages@v5
         - uses: actions/upload-pages-artifact@v3
           with:
             path: docs
         - id: deployment
           uses: actions/deploy-pages@v4
   ```

2. Only after the workflow file exists on `main`, flip the build type:

   ```sh
   gh api -X PUT repos/Narayan-Shanku/kairo-app/pages -f build_type=workflow
   ```

   Expected: JSON response with `"build_type":"workflow"`.

> **Warning:** do not set `build_type=workflow` before `pages.yml` is on
> `main`. The legacy builder stops immediately and, with no workflow to take
> over, deploys silently stop — the site keeps serving the last build forever.

## Troubleshooting

**"Page build failed" email or red ✗, but the site updated anyway.**
Rapid back-to-back pushes make the legacy builder cancel superseded builds,
which report as phantom failures. Ignore the email; check the *latest* build:

```sh
gh api repos/Narayan-Shanku/kairo-app/pages/builds --jq '.[0].status'
```

If it says `built`, everything is fine.

**Build stuck in `building` with `duration: 0` indefinitely.**
The legacy builder occasionally hangs. Re-queue a build manually:

```sh
gh api -X POST repos/Narayan-Shanku/kairo-app/pages/builds
```

This resolves in ~30s; confirm with the status command from step 2.

**Page renders but styles/underscored files are missing.**
Confirm `docs/.nojekyll` still exists — without it the legacy builder runs
Jekyll, which drops files and directories starting with `_`.
