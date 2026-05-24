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

## Current Status

Moondesk currently has a pure MoonBit host plus a live Rabbita desk:

- MoonBit domain models for workspaces, file entries, previews, task
  submissions, and run projections.
- Adapters for MoonBook, Moontown, and MoonClaw workspace concepts.
- A local HTTP host that serves the built UI and scoped `/api/*` routes.
- A built Rabbita UI with live workspace discovery, explorer browsing,
  markdown/html/json/image previews, raw links, MoonClaw run artifacts,
  inbox note creation/editing, Moontown request staging, request ledger,
  town messages, cross-book search, favorites, recent context, and a daily
  operating summary.

It is still a local MoonBit-hosted browser application, not a packaged `.app`.
The `desktop` command is a browser-compatible launch mode that keeps the host
pure MoonBit and avoids Rust, Cargo, Tauri, and broad filesystem permissions.

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
