# Moondesk

Moondesk is a pure MoonBit desktop host and Rabbita UI for browsing MoonBook
workspaces, staging inbox notes, submitting selected context to Moontown, and
inspecting MoonClaw run artifacts.

Current milestone slice:

- browser-hosted workspace explorer, previews, raw links, search, favorites, and
  inbox writes/imports
- Moontown request ledger, standing-watch creation, town messages, and one-shot
  daemon tick dispatch
- managed background daemon lifecycle: start, stop, restart, status, and
  desired-state supervision
- scoped Finder reveal through the host API
- saved views, selected-path tags, live Moontown/MoonClaw progress, daily
  cadence calendar, ICS export, and outcome analytics for standing goals and
  watcher decisions
- MoonBit-only `desktop`, `bundle`, `release`, and `launch-agent` commands; no
  Tauri/Rust app shell

See [`docs/STATUS.md`](docs/STATUS.md) for the current completeness assessment.
Short version: it is a usable local single-user alpha, not yet a polished
Codex-style native desktop app with native window ownership or a credentialed
release channel.

Run locally:

```bash
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

Create the signed self-contained macOS app bundle:

```bash
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199
```

Create a release manifest/notarization submission when credentials exist:

```bash
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```
