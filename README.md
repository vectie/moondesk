# Moondesk

Moondesk is the human desktop companion for the Moon system.

It is not an agent runtime and it is not a domain-analysis product. It is a
Finder/Codex-like workspace shell for real human users to inspect MoonBook
workspaces, review MoonClaw artifacts, submit work to Moontown, and manage files
without dropping into a terminal.

The implementation should stay pure MoonBit:

- MoonBit owns domain models, workspace contracts, adapters, and Rabbita UI.
- Rabbita provides the desktop web UI.
- A MoonBit local host process provides file and workspace APIs.
- `../tauri` is only a reference for desktop architecture concepts; Moondesk
  must not contain Rust, Cargo, `src-tauri`, or Tauri runtime code.
- MoonBook remains the durable knowledge/workspace owner.
- Moontown remains the always-on agent town, scheduling layer, and cross-book
  coordination surface.
- MoonClaw remains the worker/runtime/artifact layer.

Start here:

- [Documentation Guide](docs/README.md)
- [Product Plan](docs/PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UI Design](docs/UI_DESIGN.md)
- [MoonCode Workspace](docs/MOONCODE.md)
- [Reuse Map](docs/REUSE_MAP.md)
- [Roadmap](docs/ROADMAP.md)
- [Current Status](docs/STATUS.md)

## Current Status

Moondesk currently has a pure MoonBit host plus a live Rabbita desk:

- Desk virtual filesystem, cross-book search, favorites, saved views, tags, recent
  context, markdown/html/json/image previews, raw links, scoped Finder reveal,
  and inbox note/import staging.
- Moontown request ledger, standing-watch creation, town messages, live
  progress/events/review summaries, daemon tick dispatch, cadence summaries,
  calendar-like due-tick view, ICS export, outcome analytics, and daemon plus
  LaunchAgent lifecycle controls.
- MoonCode/MoonWiki switchable workspace shell. MoonWiki is the human-language
  book surface; MoonCode is the book-scoped coding/chat surface backed by
  MoonClaw runtime/session APIs.
- Reusable PDF Evidence Watch book creation. The wizard creates a
  `research-book` with source websites, cadence, notification rule, method page,
  `pdf-watch`/`pdf-analysis` skills, schemas, generated site placeholders, and
  a Moontown standing-watch registration.
- Portable app-tool export for books that carry generated miniapps/tools.
- Lepusa-hosted macOS bundle creation with a bundled Lepusa runtime,
  supervised Moondesk localhost sidecar, release/update metadata, DMG creation,
  and optional signing/notarization.

Domain-specific workflows are not part of Moondesk core. They should live as
standalone MoonBook/MoonClaw skill or tool packs that Moondesk can create,
configure, inspect, export, and run through generic book/tool interfaces. Export
produces a served `portable/app-tool/` bundle with local launch scripts so
generated JavaScript apps can run outside Moondesk without being built into the
desktop shell. This keeps Moondesk from hardcoding stale markets, schemas,
workbooks, or source lists.

See [Current Status](docs/STATUS.md) for the honest completion picture.
Moondesk is a usable local single-user Lepusa-hosted native-window alpha. Production
distribution still needs credentialed signing/notarization, update hosting,
clean-machine validation, and long-running reliability proof.

## Run Locally

Build the UI:

```sh
npm --prefix ui/rabbita-desk run build
```

Serve Moondesk against a Moontown workspace:

```sh
moon run cmd/main -- serve <workspace-root> --ui ui/rabbita-desk/dist --port 4199
```

Desktop launch mode:

```sh
moon run cmd/main -- desktop <workspace-root> --ui ui/rabbita-desk/dist --port 4199
```

Create a LaunchAgent template for login startup:

```sh
moon run cmd/main -- launch-agent <workspace-root> --out dist/app.vectie.moondesk.plist --port 4199
```

Install, remove, or inspect LaunchAgents:

```sh
moon run cmd/main -- install-agent <workspace-root> --service town
moon run cmd/main -- agent-status --service town
moon run cmd/main -- uninstall-agent --service town
```

Create a self-contained Lepusa native macOS app bundle:

```sh
moon run cmd/main -- bundle <workspace-root> --ui ui/rabbita-desk/dist --out dist --port 4199 --version 0.1.0 --channel local
```

Create release artifacts, update metadata, and optionally notarize with an
Apple keychain profile:

```sh
moon run cmd/main -- release <workspace-root> --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```

Browser dev mode opens at:

```text
http://127.0.0.1:4199/
```

## Optional Moontown Service

Moondesk can browse and edit a workspace without sibling source checkouts.
Starting or ticking the Moontown daemon is optional and requires an explicit
MoonSuite product-home descriptor at
`.moonsuite/products/moontown/service.json`:

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

MoonCode can also launch MoonClaw from an explicit MoonSuite product-home
descriptor at `.moonsuite/products/moonclaw/service.json`:

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

Useful checks:

```sh
moon check
moon test
moon info
moon fmt
(cd ui/rabbita-desk && moon check --target js)
npm --prefix ui/rabbita-desk run build
```
