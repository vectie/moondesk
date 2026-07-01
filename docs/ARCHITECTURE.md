# Moondesk Architecture

See [Executable Book Architecture](EXECUTABLE_BOOK_ARCHITECTURE.md) for the
canonical product boundary: MoonBook is the executable book, Moondesk is the
desktop shell, MoonClaw owns execution, and Moontown coordinates books. See
[Desk Mode Design](DESK_MODE_DESIGN.md) for the current UI decision: Desk is
the read-only virtual filesystem mode, while MoonWiki and MoonCode are
activities on the selected book/path context.

MoonSuite filesystem contracts are a shared foundation owned by MoonLib.
MoonStat consumes those contracts to validate/report workspace health and
legacy-path drift; it does not define product-home or book-layout paths.

## Boundary

Moondesk is a desktop shell over existing Moon workspaces. It should not absorb
the responsibilities of the other projects.

```text
Moondesk
  human desktop, MoonWiki workspace, MoonCode workspace, file browsing,
  preview, editing, inbox, submissions, app-tool export

MoonBook
  durable executable book, wiki, source files, generated site, code,
  history, review queue, accepted knowledge

Moontown
  Mayor, daemon, standing goals, scheduling, coordination, notifications,
  book-to-book communication, town state

MoonClaw
  agent runtime, workers, tools, bounded execution, artifacts, logs

MoonLib
  shared suite root, product registry, product-home, temp, and book path
  contracts

MoonStat
  health reporting, metrics, snapshots, analytics, and contract-drift audits
```

Moondesk treats the selected book as a desk-centered workspace:

```text
Desk
  browse MoonBooks, directories, files, source layers, and metadata

MoonWiki
  read/edit/preview/publish/review durable book knowledge

MoonCode
  chat with MoonClaw to create, modify, test, and package executable book code
```

## Source Ownership

- `core/`: product-neutral desktop records and host-facing DTOs.
- `internal/mooncore/`: reusable JSON field, durable record-file, session, and
  transcript primitives shared by request, agent, and code surfaces.
- `internal/moonwiki/`: MoonWiki HTTP routes, desktop persistence, book/wiki
  adapters, workspace, search, town, and book-pattern APIs, PDF Evidence Watch scaffolding,
  app-tool portable export, daemon/session support, and host-side IO.
- `internal/mooncode/`: MoonCode protocol, command, runtime, review, package,
  readiness, stream, and session contracts. This package should remain
  standalone from the desktop shell.
- `cmd/main/`: CLI entrypoint for serving, desktop launch, bundle, release, and
  LaunchAgent actions.
- `ui/rabbita-desk/main/`: Rabbita UI package for Desk, Files, Search, Inbox,
  MoonWiki, MoonCode, Town, Runs, and Settings surfaces.

Moondesk path construction should call the MoonLib MoonSuite contract package
instead of carrying product-local string helpers for `.moonsuite`, `.tmp`,
`books`, or product registry paths. During migration, local helpers may remain
only as thin compatibility adapters over MoonLib.

MoonCode is intentionally standalone. Moondesk renders the native shell and
review surfaces, MoonClaw owns the agent loop and tool execution, and MoonBook
owns generated code/artifacts. See [MoonCode Workspace](MOONCODE.md) for the
contract.

## HTTP Surface

The host exposes scoped local routes. Important families:

- `/api/workspaces`, `/api/workspaces/:id/*`: workspace discovery, file lists,
  previews, raw files, edits, search, tags, saved views, and imports.
- `/api/town/*`: Moontown requests, standing goals, progress, events, review
  queue, analytics, and daemon coordination.
- `/api/books/*`: base-type/pattern registry, PDF Evidence Watch creation,
  standing-goal sync, template registry reads, and portable app-tool export.
- `/api/mooncode/*`: book-scoped coding sessions, stream checkpoints, runtime
  queues, tool approval/readiness, changes, tests, package/readiness reports,
  and MoonClaw handoff records.
- `/api/moonclaw/*`: MoonClaw daemon/model status needed by the MoonCode UI.
- `/api/daemon/*`: local Moondesk daemon and LaunchAgent lifecycle controls.

Domain-specific workflows should not add permanent first-class route families
inside Moondesk. They should be exposed through book-local tools, MoonClaw
skills, app-tool manifests, or generic MoonCode/MoonWiki operations.

## Reusable Book Pattern

Moondesk currently ships a generic PDF Evidence Watch creator:

```text
research-book
  + source adapter config
  + PDF extractor skill
  + analysis method page
  + standing watch
  + Bookkeeper review queue
  + generated site/app-tool placeholders
```

Standing-watch sync is driven by the book-pattern registry capability flag, not
by a hard-coded pattern route. New source-backed watch patterns should add
registry metadata and book-local skills/templates, then reuse the same sync and
portable app-tool surfaces.

The created book owns:

```text
books/research-<topic>/
  book.json
  raw/
    inbox/
    pdfs/
    extracted/
    analysis-runs/
  wiki/
    index.md
    sources/
    findings/
    methods/
    reviews/
  skills/
    pdf-watch/SKILL.md
    pdf-analysis/SKILL.md
  schemas/
  site/generated/
```

Moondesk writes the operator-facing config, method document, skills, schemas,
layout metadata, publish receipts, and standing-goal registration. Moontown
schedules the recurring watch. MoonClaw performs bounded fetch/extract/analyze
work. MoonBook owns accepted durable knowledge and generated outputs.

## Domain Packs

Domain-specific discovery workflows are experiments for testing information
discovery and app-tool generation. They are no longer built into Moondesk.

The correct shape for any domain workflow is a standalone pack:

```text
MoonBook/MoonClaw domain pack
  skills/
  schemas/
  app/
  generated-site templates
  source adapters
  extractor/analyzer prompts
  Bookkeeper acceptance rules
  optional portable app-tool output
```

Moondesk can manage such a pack through generic book creation, file editing,
MoonCode sessions, MoonClaw execution, review surfaces, and portable export.
Moondesk should not hardcode the pack's source list, target universe, workbook
schema, or validation rules.

Portable export has one generic detection rule: explicit `toolbook` /
`app-tool-book` manifests are preferred, and any book with a real
`app/index.html` can also be packaged as a standalone app-tool. This lets
generated tools leave Moondesk cleanly without adding domain-specific product
code. Exported app-tools include `serve.py` and `run-local.command` so the
generated JavaScript runs from a served local origin instead of a fragile raw
`file://` open. The exporter discovers local assets referenced by generated
HTML, CSS, and JavaScript, including root-absolute `/assets/...` links,
side-effect imports, and `new URL(..., import.meta.url)` asset references, so
book-local tools do not need Moondesk code changes just to ship their UI. The
portable runtime also handles generic read-only workspace file APIs such as
`/api/workspaces/<id>/raw?path=...`, `/file/...`, `/site/...`, and preview
requests by serving copied book files from the static bundle. Runtime file
resolution is relative to the injected portable runtime script, so the same
bundle works in Moondesk's nested workspace-file iframe preview and under the
standalone static host. That keeps generated JavaScript tools usable after
export without adding domain-specific Moondesk endpoints.
Generated app-tools that still call unsupported Moondesk APIs are exported for
inspection, but they are not treated as launchable standalone apps. Their
portable manifest sets `auto_open_allowed: false`; the fix belongs either in
the generated pack or in the portable runtime, not in domain-specific
Moondesk code.

## Native App

`cmd/main bundle` now defaults to the Lepusa-native host path. It creates
`moondesk-lepusa.app` with:

- a bundled Lepusa runtime
- a generated `lepusa/runtime.json`
- a bundled `moondesk-sidecar` executable supervised as the localhost service
- the existing Rabbita UI served by that sidecar
- version/channel metadata

The old direct AppKit/WebKit launcher and browser-shell app bundle paths have
been removed from the active product path. Browser-based development uses
`serve` or `desktop`; packaging goes through Lepusa.

`cmd/main release` creates zip/DMG/update metadata and can invoke Apple
notarization when a keychain profile is available. Production distribution still
depends on external credentials, update hosting, and clean-machine validation.

## Validation

The expected validation loop is:

```sh
moon fmt
moon check --target all --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon info --target native
moon info --target js
(cd ui/rabbita-desk && moon check --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000)
npm --prefix ui/rabbita-desk run build
git diff --check
```
