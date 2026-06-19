# Moondesk

Moondesk is a pure MoonBit desktop host and Rabbita UI for browsing MoonBook
workspaces, staging inbox notes, submitting selected context to Moontown, and
inspecting MoonClaw run artifacts.

Current milestone slice:

- workspace explorer, previews, raw links, search, favorites, and inbox
  writes/imports
- Moontown request ledger, standing-watch creation, town messages, live
  progress/events/review summaries, daemon lifecycle controls, and one-shot
  daemon tick dispatch
- reusable PDF Evidence Watch publishing: a 7-step wizard creates a
  `research-book` with source websites, cadence, notification rule, method
  document, `pdf-watch`/`pdf-analysis` skills, schemas, generated site
  placeholders, a book-local config, Moontown publish receipts, and a standing
  watch registration
- portable app-tool export for books that carry generated miniapps/tools
- saved views, selected-path tags, daily cadence calendar, ICS export, and
  outcome analytics for standing goals and watcher decisions
- switchable MoonWiki/MoonCode workspace shell: MoonWiki for human-language
  book editing, MoonCode for book-scoped coding/chat sessions backed by
  MoonClaw runtime APIs
- MoonBit-only `desktop`, `bundle`, `release`, and `launch-agent` commands; the
  default app bundle uses a native AppKit/WebKit window plus an internal MoonBit
  host, with no Tauri/Rust app shell

Domain-specific examples are intentionally not Moondesk core. They should be
packaged as standalone MoonBook/MoonClaw skill or app-tool packs that Moondesk
can create, configure, inspect, export, and launch through generic book/tool
interfaces.

See [`docs/STATUS.md`](docs/STATUS.md) for the current completeness assessment.
Short version: it is a usable local single-user alpha with native window
ownership in the generated macOS app bundle; production distribution still
needs a credentialed release channel.

Run locally:

```bash
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve <workspace-root> --ui ui/rabbita-desk/dist --port 4199
```

Create the signed self-contained native-window macOS app bundle:

```bash
moon run cmd/main -- bundle <workspace-root> --ui ui/rabbita-desk/dist --out dist --port 4199
```

Create a release manifest/notarization submission when credentials exist:

```bash
moon run cmd/main -- release <workspace-root> --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```

Optional external services:

Moondesk can browse and edit a workspace without sibling source checkouts.
Starting or ticking the Moontown daemon is optional and requires an explicit
workspace-local descriptor at `.moontown/moondesk-daemon/service.json`:

```json
{
  "kind": "moondesk-town-service.v1",
  "cwd": "/absolute/path/to/moontown-runtime",
  "daemon": {
    "command": "/usr/local/bin/moontown",
    "args": ["daemon", "run"]
  },
  "tick": {
    "command": "/usr/local/bin/moontown",
    "args": ["daemon", "tick"]
  }
}
```

Without that file, daemon start/tick and town LaunchAgent creation return
`not-configured` instead of assuming the workspace is a Moontown source tree.

MoonCode can also launch MoonClaw from an explicit workspace-local descriptor at
`.moontown/moondesk-daemon/moonclaw-service.json`:

```json
{
  "kind": "moondesk-moonclaw-service.v1",
  "cwd": "/absolute/path/to/moonclaw-runtime",
  "daemon": {
    "command": "/usr/local/bin/moonclaw",
    "args": ["daemon", "--port", "0"]
  }
}
```

Without that file, Moondesk can still report an already-running MoonClaw daemon
from its daemon-info file, but it will not discover, build, or launch a sibling
MoonClaw source checkout.

Validation:

```bash
moon check
moon test
moon info
moon fmt
cd ui/rabbita-desk && moon check --target js
```
