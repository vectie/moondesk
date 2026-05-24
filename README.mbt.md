# Moondesk

Moondesk is a pure MoonBit desktop host and Rabbita UI for browsing MoonBook
workspaces, staging inbox notes, submitting selected context to Moontown, and
inspecting MoonClaw run artifacts.

Current milestone slice:

- browser-hosted workspace explorer, previews, raw links, search, favorites, and
  inbox writes
- Moontown request ledger, standing-watch creation, town messages, and one-shot
  daemon tick dispatch
- scoped Finder reveal through the host API
- daily cadence calendar and outcome analytics for standing goals and watcher
  decisions
- MoonBit-only `desktop` and `bundle` commands; no Tauri/Rust app shell

Run locally:

```bash
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

Create the macOS app-shell bundle:

```bash
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199
```
