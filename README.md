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
  MoonClaw agent sessions, book-scoped chat/task handoff, supervised daemon
  policy, transcript progress projection, LaunchAgent install/remove controls, live
  event/failure/review summaries, URL and local file import staging, cadence
  summaries, a calendar-like due-tick view, ICS export, outcome analytics, and
  daily analytics.

Moondesk now ships a native-window macOS bundle: `bundle` creates
`Moondesk.app` with an AppKit/WebKit foreground launcher, an internal native
MoonBit host executable, bundled UI resources, version/channel metadata, and
ad-hoc or identity-based code signing. `desktop` remains a browser-compatible
developer launch alias, and `bundle --shell browser` is available as an
explicit fallback shell. Native-window packaging uses macOS system
AppKit/WebKit frameworks and `/usr/bin/clang`; it does not vendor another app
runtime. `release` creates zip/DMG artifacts,
`release-manifest.json`, `updates.json`, verifies signing, and can submit the
archive through Apple notarytool when a keychain profile is provided. It still
avoids Rust, Cargo, Tauri, and broad filesystem permissions.

See [Current Status](docs/STATUS.md) for the honest completion picture:
Moondesk is feature-complete for a local single-user native-window alpha and
roughly 95% complete for the daily-use target. The self-contained `.app` bundle
now includes the AppKit/WebKit launcher, native MoonBit host, bundled UI,
release/update manifests, and DMG creation. A production distribution is closer
to 85% complete because real Developer ID signing/notarization, update hosting,
clean-machine validation, and long-running reliability proof are release
hardening steps rather than code-only changes.

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

Install, remove, or inspect LaunchAgents:

```sh
moon run cmd/main -- install-agent ../moontown --service town
moon run cmd/main -- agent-status --service town
moon run cmd/main -- uninstall-agent --service town
```

Create a signed self-contained native-window macOS app bundle:

```sh
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --version 0.1.0 --channel local
```

Use the browser fallback shell only when explicitly needed:

```sh
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --shell browser
```

Create release artifacts, update metadata, and optionally notarize with an
Apple keychain profile:

```sh
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```

Browser dev mode opens at:

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
