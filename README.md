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
- [MoonCode Workspace](docs/MOONCODE.md)
- [Reuse Map](docs/REUSE_MAP.md)
- [Roadmap](docs/ROADMAP.md)
- [Current Status](docs/STATUS.md)

## Current Status

Moondesk currently has a pure MoonBit host plus a live Rabbita desk:

- MoonBit domain models for workspaces, file entries, previews, task
  submissions, and run projections.
- Adapters for MoonBook, Moontown, and MoonClaw workspace concepts.
- A local MoonWiki host that serves the built UI and scoped `/api/*` routes.
- A built Rabbita UI with live workspace discovery, explorer browsing,
  markdown/html/json/image previews, raw links, MoonClaw run artifacts,
  inbox note creation/editing, Moontown request staging, request ledger,
  town messages, a 7-step reusable book pattern wizard for PDF Evidence Watch
  and Exchangeable Bond Evidence Watch with explicit book id, purpose, cadence,
  notification rule, source websites, and selected skill pack,
  dynamic base-type selection from the Moontown template registry, Moontown template-registry discovery for available book patterns,
  editable files, install examples, and required template assets, EB prompt
  materialization as a durable `raw/bootstrap/EB_OPERATOR_PROMPT.md` book
  artifact plus `raw/analysis-runs/eb-prompt-contract.json` receipt, with the
  official-source priority list, six lifecycle stages,
  quality rules, required workbook headers, and execution directive, EB MoonClaw
  execution request and proposal packet creation,
  EB standing-watch dispatch packet and required watch-marker contract,
  operator-owned `wiki/methods/my-analysis-method.md` creation,
  book-owned editable `raw/inbox/pdf-evidence-watch-config.json` with the
  nested `watch` and `analysis` shape,
  durable `raw/analysis-runs/base-type-selection.json` proof that Moondesk
  selected the `research-book` MoonBook base from `/api/books/base-types`
  before layering the PDF/EB watch pattern on top,
  exact PDF Evidence Watch layout metadata for `raw/inbox/`, `raw/pdfs/`,
  `raw/extracted/`, `raw/analysis-runs/`, `wiki/`, `skills/`, `schemas/`, and
  `site/generated/`,
  durable MoonBook `wiki/evidence-matrix.md` ownership,
  EB single-bond or multi-bond target capture, installed Moontown template
  request plus strict `PdfEvidenceWatchInstallSpec` config/publish receipt,
  durable Moontown standing-goal registration receipt, contract verification,
  publish receipts that prove the owner split, reusable
  `research-book + source adapter + extractor + analysis skill + standing watch`
  contract, and accepted-new-knowledge-only notification rule,
  output-readiness gating with an official-source screen requirement that
  verifies existing book-local `raw/pdfs/` and `raw/extracted/` artifacts for
  production proof,
  generated `raw/bootstrap/eb_discover_pdf_candidates.py` official-seed
  materializer plus `raw/bootstrap/eb_extract_pdf_text.py` pypdf extraction
  helper so MoonClaw can run bounded deterministic discovery/extraction steps
  instead of improvising PDF tooling,
  generated `raw/bootstrap/eb_package_workbook.py` helper so an accepted
  MoonClaw run can deterministically bind the final workbook, manifest,
  validation sidecar, result, PDF-candidate artifact, and source-screen
  artifact,
  accepted EB `.xlsx.manifest.json` output-contract, hash-bound
  `.xlsx.validation.json` sidecar contract carried through the execution
  request, Moontown dispatch, and MoonClaw proposal packet, sheet/header
  validation, generated schema coverage for manifest/validation/source-screen
  proof artifacts, workbook-hash validation,
  appendix-note proof for search keywords/retrieval date/source list,
  workbook data-row proof for source-backed rows in both required sheets,
  actual workbook hyperlink checks for official original-link cells,
  workbook quality proof for official-link-only rows, clickable source URLs,
  summaries within 200 characters, emphasized key data, cross-verification,
  timing checks, data reconciliation, missing-disclosure marking, and readable
  Excel formatting, lifecycle-stage proof that all six EB stages were reviewed
  or explicitly marked missing, and
  extracted workbook XML checks for the required EB sheet names, headers,
  frozen header panes, filters, custom column widths, bold header styling, and
  official-domain hyperlink relationships,
  durable run-health checks across watcher/result/run/output artifacts with a
  stable production checklist of requirement/evidence rows, visible base-type
  selection and Moontown handoff receipt readiness, and workbook-to-target
  matching,
  MoonClaw proposal import receipt tracking, confirmed MoonClaw run launch,
  bounded confirmed-run execution/recovery receipts,
  one-click EB production-proof receipts that launch/reuse a confirmed run,
  reconcile, audit, and record `production_ready` versus `not-proven` blockers,
  surface the latest proof attempt in run-health, and include production
  target-readiness preflights in the builder,
  executor/full MoonClaw runtime metadata with required `web_search` and
  `web_fetch` tools plus a `moonclaw_web_tools` production checklist gate that
  rejects stale planner-only or web-tool-blocked runs,
  an EB runtime refresh route for existing books that rewrites only generated
  MoonClaw request/dispatch/profile/packet artifacts, repairs the durable EB
  operator prompt plus prompt-contract receipt, repairs the durable
  `raw/analysis-runs/eb-expected-output-contract.json` workbook contract,
  repairs stale Moontown publish/standing-goal output-contract handoff receipts,
  repairs missing canonical EB method-contract sections without deleting operator text, and resyncs the
  Moontown standing goal before import or production proof,
  MoonClaw import/run routes, and proof route that reject the default
  `132001 / 示例EB` sample target before live MoonClaw execution,
  Moontown-compatible packet-side import receipts and task execution receipts,
  MoonClaw run-meta/stderr health checks,
  timeout-bounded inline MoonClaw import receipts,
  strict reconciliation of completed live MoonClaw run outputs, including
  MoonClaw's final `package_result` wrapper shape, into watcher/book-result
  health only after the workbook, run-id-matching manifest, official-source
  screen with live fetch/extract proof, and run metadata pass through a desk
  gate, plus helper-side recovery for partial MoonClaw artifacts where official
  PDF URLs were captured in step output and downloaded/extracted files were
  captured separately,
  an `Accept Recovered Output` action that can publish an already validated
  non-sample EB workbook/source-screen package into the durable watcher and
  book-result ledgers while keeping `production_ready` blocked until the live
  MoonClaw lifecycle is proven,
  deterministic EB output validation against the expected-output contract,
  EB starter workbook creation,
  standing-watch creation with the latest `watch-<book-id>-pdfs` Moontown
  identity, daemon tick dispatch, cross-book search, favorites,
  saved views,
  tags, recent context, scoped Finder reveal,
  a switchable MoonWiki/MoonCode workspace shell, native MoonClaw MoonCode
  command sessions, book-scoped chat/task handoff, supervised daemon
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
