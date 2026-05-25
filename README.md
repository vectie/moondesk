# Moondesk

Moondesk is the human desktop companion for the Moon system.

It is not another agent runtime. It is a Finder/Codex-like workspace shell for
real human users to inspect MoonBook workspaces, review MoonClaw artifacts,
submit work to Moontown, and manage files without dropping into a terminal.

The implementation should stay pure MoonBit:

- MoonBit owns domain models, workspace contracts, adapters, and Rabbita UI.
- Rabbita provides the desktop web UI.
- A MoonBit local host process provides file and workspace APIs.
- `../tauri` is only a reference for desktop architecture concepts; Moondesk
  must not contain Rust, Cargo, `src-tauri`, or Tauri runtime code.
- MoonBook remains the durable knowledge/workspace owner.
- Moontown remains the always-on agent town and scheduling layer.
- MoonClaw remains the worker/runtime/artifact layer.

Start here:

- [Product Plan](docs/PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UI Design](docs/UI_DESIGN.md)
- [Reuse Map](docs/REUSE_MAP.md)
- [Roadmap](docs/ROADMAP.md)
- [Current Status](docs/STATUS.md)

## Current Status

Moondesk currently has a pure MoonBit host plus a live Rabbita desk:

- MoonBit domain models for workspaces, file entries, previews, task
  submissions, and run projections.
- Adapters for MoonBook, Moontown, and MoonClaw workspace concepts.
- A local HTTP host that serves the built UI and scoped `/api/*` routes.
- A built Rabbita UI with live workspace discovery, explorer browsing,
  markdown/html/json/image previews, raw links, MoonClaw run artifacts,
  inbox note creation/editing, Moontown request staging, request ledger,
  town messages, standing-watch creation, daemon tick dispatch, cross-book
  search, favorites, saved views, tags, recent context, scoped Finder reveal,
  supervised daemon policy, live progress summaries, URL import staging,
  cadence summaries, a calendar-like due-tick view, ICS export, outcome
  analytics, and daily analytics.

The `desktop` command is a browser-compatible launch mode, and `bundle` now
creates a self-contained macOS `.app` distribution with the native MoonBit host
executable, bundled UI resources, ad-hoc code signing by default, and an
optional zip archive. `desktop` and bundled app launches open the browser
explicitly. `release` can write a release manifest and submit the zip through
Apple notarytool when a keychain profile is provided. It still avoids Rust,
Cargo, Tauri, and broad filesystem permissions.

See [Current Status](docs/STATUS.md) for the honest completion picture:
Moondesk is usable as a local single-user alpha, but not yet a polished
Codex-style native desktop app with notarized distribution and native window
ownership.

## Run Locally

Build the UI:

```sh
npm --prefix ui/rabbita-desk run build
```

Serve Moondesk against a Moontown workspace:

```sh
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

Desktop-compatible launch mode:

```sh
moon run cmd/main -- desktop ../moontown --ui ui/rabbita-desk/dist --port 4199
```

Create a LaunchAgent template for login startup:

```sh
moon run cmd/main -- launch-agent ../moontown --out dist/app.vectie.moondesk.plist --port 4199
```

Create a signed self-contained macOS app bundle:

```sh
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199
```

Create a release manifest and optionally notarize with an Apple keychain
profile:

```sh
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```

Open:

```text
http://127.0.0.1:4199/
```

Useful checks:

```sh
moon check
moon test
moon info
moon fmt
(cd ui/rabbita-desk && moon check --target js)
npm --prefix ui/rabbita-desk run build
```
