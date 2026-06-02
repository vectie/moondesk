# Moondesk Architecture

## Boundary

Moondesk is a desktop shell over existing Moon workspaces. It should not absorb
the responsibilities of the other projects.

```text
Moondesk
  human desktop, file browsing, preview, editing, inbox, submissions

MoonBook
  durable book/wiki/site/history/review workspace

Moontown
  Mayor, daemon, standing goals, scheduling, dispatch, town state

MoonClaw
  job runtime, workers, tools, artifacts, logs, ACP execution
```

For the PDF Evidence Watch pattern, the split is concrete:

- Moondesk creates, configures, edits, and publishes the reusable
  `research-book + source adapter + extractor + analysis skill + standing watch`
  workspace.
- Moontown owns the standing goal and live status/notification surface.
- MoonBook owns `book.json`, `raw/inbox/`, `raw/pdfs/`, `raw/extracted/`,
  `raw/analysis-runs/`, `wiki/`, `skills/`, `schemas/`, and generated site
  state.
- MoonClaw performs bounded browse/fetch/download/extract/analyze/package runs.
- Bookkeeper decides whether candidate results become accepted knowledge.

## Package Plan

### `core`

MoonBit domain model for the desk:

- workspace registry
- file entries
- pane/tab/window model
- preview descriptors
- inbox records
- task submission records
- adapter capability model

### `adapters/moonbook`

Reads and writes through MoonBook-owned workspace semantics:

- discover book roots
- load book metadata and health summaries
- list `wiki/`, `raw/`, `site/`, `book/`, and `reviews/`
- stage user files into book inbox
- open generated site/report/course paths
- request MoonBook build/projection commands later

### `adapters/moontown`

Talks to Moontown surfaces:

- read `.moontown/town.json`
- read `.moontown/daemon.json`
- read `.moontown/standing-goals.json`
- submit operator requests
- read watcher messages
- link desk selections to town requests

### `adapters/moonclaw`

Run/artifact projection plus a narrow interactive agent bridge:

- list run workspaces
- inspect `events.jsonl`, `meta.json`, `result.json`, `report.md`
- expose artifact preview entries
- map worker/run status back to the UI
- inspect `~/.moonclaw/daemon.json`
- proxy to MoonClaw daemon `GET /v1/models`, `GET /v1/tasks`,
  `POST /v1/task`, `POST /v1/task/:id/message`, and
  `POST /v1/task/:id/cancel`
- persist Moondesk-owned session metadata without owning MoonClaw
  conversation/runtime state

### `ui/rabbita-desk`

Rabbita desktop application:

- activity rail
- explorer tree
- tabbed preview center
- inspector panel
- bottom artifact/log drawer
- command palette
- request composer
- file drop surface
- Agents activity for book-scoped MoonClaw chat sessions

### `cmd/main`

Local development command:

- serve the Rabbita UI
- expose JSON APIs for configured roots
- run doctor checks
- run read-only indexing later

### `host`

Pure MoonBit local host APIs:

- configured workspace roots
- scoped file reads/writes
- inbox imports
- preview endpoints
- operator request endpoints
- optional OS helper commands behind explicit allowlists

## Tauri Reference Strategy

Use `../tauri` only as a design reference:

- split frontend UI from local host capabilities
- keep host APIs explicit and narrow
- avoid broad filesystem access
- keep desktop concerns outside domain logic

Do not import Tauri, write Rust, create Cargo files, or add `src-tauri`.
Moondesk should be executable as a MoonBit-hosted Rabbita application first.

## Runtime Modes

### Browser Dev Mode

```text
moon run cmd/main -- serve [root] [--ui ui/rabbita-desk/dist] \
  [--host 127.0.0.1] [--port 4188]
```

Uses a local HTTP server and built Rabbita bundle. This is the implemented
development mode.

Example:

```text
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

### MoonBit Desktop Host Mode

```text
moon run cmd/main -- desktop [root] [--ui ui/rabbita-desk/dist] \
  [--host 127.0.0.1] [--port 4188]
```

Implemented as a browser-compatible launch alias over the same pure MoonBit
host. Unlike `serve`, `desktop` opens the browser after the server binds. This
mode remains useful for development and fallback debugging, while packaged
daily use is owned by the native-window bundle.

### Packaged Mode

```text
moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist]
```

Implemented as a MoonBit-generated macOS `.app` distribution. The bundle command
builds the native MoonBit executable, copies it to
`Contents/MacOS/moondesk-host`, compiles a small AppKit/WebKit launcher as
`Contents/MacOS/moondesk`, copies the built Rabbita UI into
`Contents/Resources/ui`, writes `Contents/Resources/moondesk-config.json`,
records version/channel/native-window metadata, signs the app with `codesign`
using ad-hoc identity `-` by default, and creates `Moondesk.app.zip` unless
`--no-archive` is supplied. The packaged executable opens a foreground macOS
window and loads the bundled UI through the internal host. `bundle --shell
browser` preserves the older browser-shell bundle shape when needed. The native
launcher is compiled with the system `/usr/bin/clang` against AppKit and WebKit;
there is no Rust, Tauri, or vendored desktop runtime. `cmd/main release` wraps
the bundle output with `release-manifest.json`, `updates.json`, signing
verification, DMG creation, and optional
`xcrun notarytool submit --keychain-profile ... --wait` plus stapling, without
introducing Rust into this repository.

### Launch Agents

```text
moon run cmd/main -- launch-agent [root] [--service desk|town] \
  [--out dist/app.vectie.moondesk.plist]
moon run cmd/main -- install-agent [root] [--service desk|town]
moon run cmd/main -- uninstall-agent [--service desk|town]
moon run cmd/main -- agent-status [--service desk|town]
```

`launch-agent` writes a macOS LaunchAgent template. `install-agent`,
`uninstall-agent`, and `agent-status` manage the corresponding plist through
`launchctl` for either the desk host or the Moontown daemon. The UI also exposes
Moontown daemon agent status plus install/remove controls through
`GET|POST /api/town/daemon/agent`.

## Adapter Rules

- Adapters should expose explicit methods, not generic "run anything" methods.
- Moondesk should call `MoonBookAdapter.list_entries`, not parse arbitrary
  workspace internals everywhere.
- Moondesk should call `MoontownAdapter.submit_request`, not write daemon files
  directly except through an approved local dev API.
- Moondesk should call `MoonClawAdapter.list_runs` for artifacts and proxy
  interactive chat through the MoonClaw daemon; it should not own MoonClaw job
  execution internals.

## Initial API Surface

```text
GET  /api/workspaces
GET  /api/workspaces/:id/entries?path=...
GET  /api/workspaces/:id/preview?path=...
GET  /api/workspaces/:id/raw?path=...
POST /api/workspaces/:id/inbox
POST /api/workspaces/:id/import
GET  /api/workspaces/:id/review-diff?path=...
GET  /api/search?query=...
GET  /api/town/state
GET  /api/town/daemon
GET  /api/town/daemon/status
GET  /api/town/daemon/supervision
POST /api/town/daemon/supervision
POST /api/town/daemon/start
POST /api/town/daemon/stop
POST /api/town/daemon/restart
GET  /api/town/daemon/agent
POST /api/town/daemon/agent
GET  /api/town/analytics
GET  /api/town/events
GET  /api/town/progress
GET  /api/town/calendar.ics
GET  /api/town/messages
GET  /api/town/requests
POST /api/town/requests
GET  /api/town/standing-goals
POST /api/town/standing-goals
GET  /api/books/base-types
GET  /api/books/patterns
GET  /api/books/template-registry
POST /api/books/from-pattern
POST /api/books/pdf-evidence-watch
GET  /api/books/verify?book_id=...
POST /api/books/sync-standing-goal
POST /api/books/refresh-eb-runtime
GET  /api/books/run-health?book_id=...
POST /api/books/moonclaw-import
POST /api/books/moonclaw-run
POST /api/books/moonclaw-reconcile
POST /api/books/eb-production-proof
POST /api/town/dispatch
GET  /api/moonclaw/events?workspace=...
GET  /api/moonclaw/runs?workspace=...
GET  /api/moonclaw/progress?workspace=...
GET  /api/moonclaw/runs/:id/artifacts
GET  /api/agents/daemon
GET  /api/agents/models
GET  /api/agents/tasks
GET  /api/agents/sessions?workspace=...
POST /api/agents/sessions
POST /api/agents/sessions/:id/message
POST /api/agents/sessions/:id/cancel
GET  /api/review/items?workspace=...
POST /api/workspaces/:id/reveal
GET  /api/preferences/views
POST /api/preferences/views
GET  /api/preferences/tags
POST /api/preferences/tags
```

Implemented behavior:

- `GET /api/workspaces` discovers MoonBooks under `.moontown/books`, or returns
  the configured root as a loose folder.
- `entries`, `preview`, and `raw` scope all paths under the selected workspace
  root and reject traversal.
- `preview` returns a `DeskPreview`; image previews point to the `raw` route.
- `POST /api/workspaces/:id/inbox` writes a markdown note into `inbox/`; when a
  `path` field is provided it edits only scoped `inbox/*` paths.
- `POST /api/workspaces/:id/import` stages URL/file/data-url metadata into
  `inbox/imports/` and keeps all writes scoped under the selected workspace.
- `GET /api/workspaces/:id/review-diff?path=...` compares a selected review file
  to the nearest wiki/base/orig/previous file and returns a bounded line-level
  summary.
- `GET /api/search?query=...` searches readable text-like files across
  discovered workspaces with bounded results.
- `GET /api/town/state` returns the town state JSON when present.
- `GET /api/town/daemon` returns `.moontown/daemon.json` when present.
- `GET /api/town/daemon/status` reports the Moondesk-managed background daemon
  PID, running state, command, supervision policy, restart count, and log paths.
- `GET|POST /api/town/daemon/supervision` reads or updates the desired-state
  supervision policy. When enabled with desired state `running`, status checks
  reconcile a stopped managed daemon by starting it again.
- `POST /api/town/daemon/start` starts `moon run cmd/main -- daemon run` as a
  managed background process under the configured Moontown root.
- `POST /api/town/daemon/stop` sends the managed process `SIGTERM` and persists
  the lifecycle state.
- `POST /api/town/daemon/restart` stops then starts the managed daemon loop.
- `GET|POST /api/town/daemon/agent` reports, installs, or removes the Moontown
  daemon LaunchAgent.
- `GET /api/town/analytics` returns a flat operating summary: daemon tick,
  standing-goal counts, due/active goals, watcher decision counts, request
  count, town message count, visible MoonClaw run count, event counts, failure
  counts, review counts, latest failure, and review queue size.
- `GET /api/town/events` returns recent Moontown watcher/request/dispatch
  events with normalized severities.
- `GET /api/town/progress` returns the current daemon tick/status, supervision
  state, queued request/dispatch/message counts, and latest visible run.
- `GET /api/town/calendar.ics` exports enabled standing goals as VTODO records.
- `GET /api/town/messages` lists recent `.moontown/book-results/*.json`
  records.
- `GET /api/town/requests` lists staged request records under
  `.moontown/moondesk-requests/`.
- `POST /api/town/requests` stages a request under
  `.moontown/moondesk-requests/`.
- `GET /api/town/standing-goals` rehydrates registered PDF-watch standing goals
  from book-local receipts, then reads `.moontown/standing-goals.json`. It keeps
  the response as the raw standing-goal array for UI compatibility.
- `POST /api/town/standing-goals` validates/upserts a standing-watch record in
  `.moontown/standing-goals.json`.
- `GET /api/books/template-registry` reads the current Moontown book-template
  registry from the configured workspace when present, with a fallback to
  `../moontown/templates/books/templates.json`. It reports available templates,
  editable files, install examples, required template assets, selected registry
  path, missing template assets, and derived base types.
- `GET /api/books/base-types` returns the base MoonBook types Moondesk can
  build on, derived from the same registry-backed pattern catalog. The current
  PDF/EB creation flow supports `research-book`, while the catalog also surfaces
  other registry-discovered bases such as Moontown's current `toolbook` /
  `app-tool-book` template as selectable provenance, not as PDF/EB publish
  targets. Each base-type record carries
  provenance fields that name Moontown's template registry as the creation
  palette and MoonBook layout/docs as the durable book owner evidence, including
  `moonbook_layout_refs` and `template_registry_refs`.
- `GET /api/books/patterns` returns reusable book-builder patterns. It upserts
  the Moontown registry descriptor for `pdf-evidence-watch` over Moondesk's
  built-in fallback so the creation UI follows the latest `../moontown`
  template data while keeping the UI JSON shape stable. The current production
  patterns are `pdf-evidence-watch` and `exchangeable-bond-evidence-watch`;
  both use `research-book` as the base type, while unrelated registry templates
  remain visible as discovered patterns.
- `GET /api/books/verify?book_id=<id>` audits a generated book against its
  book-pattern contract. For EB books it checks the MoonClaw execution request,
  importable MoonClaw proposal packet, workspace-local MoonClaw profile,
  standing-watch dispatch packet, EB watch-marker contract, six lifecycle
  stages, official domains, exact workbook sheet headers, starter XLSX payload,
  schema coverage for manifest/validation/source-screen proof artifacts,
  required validation sidecar proofs (`appendix_notes`, `quality_proof`, and
  `lifecycle_stage_proof`) across the request/dispatch/proposal handoff,
  Moondesk handoff, MoonBook catalog entry, Moontown standing-watch handoff
  identity, book-local standing-goal registration receipt, and Moontown
  template request/config receipt. The verifier accepts the book-local receipt
  as durable handoff proof and separately reports
  `moontown_global_standing_goal_ready` for stale global scheduler state.
- `POST /api/books/sync-standing-goal` repairs that stale scheduler state for
  any PDF Evidence Watch pattern. It requires the book-local
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipt,
  reconstructs the standard `watch-<book-id>-pdfs` standing goal from
  `book.json`, upserts `.moontown/standing-goals.json`, and returns refreshed
  verification plus EB run-health evidence when applicable. This is the
  expected repair when Moontown maintenance rewrites the global standing-goal
  file while the book-local handoff receipt remains valid.
- Moondesk also runs a best-effort all-book repair from those same receipts
  before town progress, analytics, calendar export, standing-goal reads, and
  dispatch. The sweep recognizes explicit `pattern` / `specialization` metadata
  and legacy PDF-watch `book_type` values; plain `research-book` workspaces
  without a PDF-watch specialization are ignored. Incomplete explicit PDF-watch
  draft books without receipts are returned as skipped books in the repair
  metadata rather than hard endpoint failures.
- `POST /api/books/refresh-eb-runtime` repairs generated EB runtime artifacts
  for an existing EB Evidence Watch book without deleting the operator's method
  text. It rewrites `moonclaw.jobs.json`,
  `raw/inbox/eb-tracking-request.json`,
  `raw/inbox/eb-standing-watch-dispatch.json`,
  `raw/bootstrap/EB_WATCH_CONTRACT.md`, and
  `moonclaw-packets/eb-standing-watch-proposal.json` from current `book.json`
  and request target data. It also writes the standalone
  `raw/bootstrap/EB_OPERATOR_PROMPT.md` artifact plus
  `raw/analysis-runs/eb-prompt-contract.json` verifier receipt, so the
  operator-facing contract is owned by MoonBook and can be checked before
  Moontown/MoonClaw handoff. It also appends the canonical Chinese EB operator
  prompt contract to `wiki/methods/my-analysis-method.md` and the compatibility
  `wiki/methods/analysis-method.md` when those lifecycle/source/workbook terms
  are missing, and it backfills the book-local `wiki/evidence-matrix.md` when
  older EB books predate that MoonBook ownership artifact. Generated EB
  MoonClaw steps carry `timeout_ms: 300000` and `max_total_tokens: 48000`, so
  official-source scans that exceed the bounded
  local execution window leave terminal run evidence for Moondesk proof instead
  of remaining indefinitely orphaned. The generated step metadata also sets
  `retry_max_attempts: 1`, and the discovery prompt is scoped to write
  `outputs/official-pdf-candidates.json` or an explicit failed candidate record
  instead of retrying the same broad official-site search. The refresh then records
  `raw/analysis-runs/eb-runtime-refresh.json`.
  MoonClaw import and production proof run this refresh before launching, and
  production proof also resyncs `.moontown/standing-goals.json` from the
  book-local standing-goal receipt before evaluating run health. Production
  proof discards an old confirmed run id when refreshed runtime or method
  artifacts are newer than the import receipt, reporting
  `not_proven_refreshed_runtime_requires_new_moonclaw_import` until a new import
  is run from the refreshed packet.
- `GET /api/books/run-health?book_id=<id>` audits the durable execution surface
  for an EB watch book. It resolves the standing-watch identity from the
  book-local `raw/analysis-runs/moontown-standing-goal-registration.json`
  receipt when `.moontown/standing-goals.json` has not caught up yet, and
  reports `global_standing_goal_ready` separately so stale global scheduling is
  visible. It requires the standing-watch identity, watcher ledger update,
  MoonClaw-style `moonclaw-jobs/<run>/result.json`, accepted
  `.moontown/book-results/<run>.json`, non-placeholder EB workbook,
  `book/outputs/<workbook>.xlsx.manifest.json`,
  `book/outputs/<workbook>.xlsx.validation.json`,
  `raw/analysis-runs/*-official-source-screen.json`, and the final output gate
  to agree before reporting `durable_output_ready`. The manifest must name the
  `moondesk.exchangeable_bond_tracking.xlsx.v1` contract, mark Bookkeeper
  acceptance for final outputs, and preserve the exact headers for both
  `公告追踪主表` and `关键指标监控表`. The workbook file itself must also be an
  OOXML package containing `[Content_Types].xml`, workbook relationships,
  `xl/workbook.xml`, styles, and both worksheet parts, so a renamed or dummy
  `PK` file cannot satisfy the output gate. The sibling validation artifact
  must also bind `xlsx_sha256` to the workbook bytes and prove the exact
  `公告追踪主表` / `关键指标监控表` header contract. Moondesk also extracts
  `xl/workbook.xml`, worksheet XML, worksheet hyperlink relationship XML, style
  XML, and shared strings with `unzip -p` and checks the actual workbook for the
  required EB sheet names, header strings, frozen header panes, filters, custom
  column widths, bold header styling, and official-domain external hyperlinks
  for Sheet 1 `原文链接` cells, so a dummy `PK` file with matching sidecars cannot pass;
  production readiness rejects sample validation artifacts. The validation sidecar must also prove
  the workbook contains the prompt-required appendix notes: search keywords,
  retrieval date, and an official information-source list. It must also include
  `quality_proof` for the prompt's QA rules: official-link-only workbook rows,
  clickable source URLs plus actual workbook hyperlink relationships, summaries within 200 characters, emphasized key data,
  issuer/underlying cross-verification, disclosure-timing checks, Sheet 1 /
  Sheet 2 data reconciliation, expected-but-missing disclosure marking, and
  readable Excel formatting. It must also include `lifecycle_stage_proof` showing
  all six EB lifecycle stages were reviewed and expected-but-missing disclosures
  were marked with reasons. Production readiness
  also requires the accepted workbook filename and manifest bond code/name to
  match one configured production EB target, so a live run for `132018 /
  G三峡EB1` cannot pass with a sample `132001 / 示例EB` workbook. It also reports
  `production_ready` separately; that stricter flag requires a persisted
  MoonClaw import receipt, confirmed MoonClaw `run_id`, and non-sample MoonClaw
  result so deterministic packaging checks cannot be mistaken for live evidence
  collection. It also reads MoonClaw's persisted
  `jobs/runs/<run_id>/meta.json` from the receipt `home`, reports
  `moonclaw_confirmed_run_status` including `Pending`, `WaitingForInput`,
  `Succeeded`, and `Failed`, and requires a succeeded confirmed run plus clean
  effective execution stderr before `production_ready` can pass. A dirty
  detached launch stderr can be recovered by a later clean, successful
  `raw/analysis-runs/<run-id>-moonclaw-run.json` confirmed-run receipt; a
  timed-out or failed confirmed-run receipt remains an explicit health blocker.
  The HTTP production-proof route raises execution requests below 900 seconds to
  the generated EB workflow budget, because the profile has four 300-second
  bounded steps plus import/reconciliation overhead; shorter wrapper timeouts
  are treated as operator input but cannot manufacture an orphaned run.
  Run health also scans
  `<home>/jobs/runs/<run_id>/steps/*.json` for MoonClaw
  `best_effort_missing_input` step outputs or summaries. A production EB watch
  cannot count best-effort continuation after missing input as source
  discovery, extraction, analysis, or Bookkeeper acceptance, so the
  `moonclaw_no_missing_input` checklist item fails until a run completes with
  normal bounded step evidence.
  It also looks for the first-step candidate artifact at
  `outputs/official-pdf-candidates.json` in the MoonClaw run workspace. That
  artifact must either contain official-domain PDF candidates or an explicit
  failed record with checked domains and a failure reason. This
  `moonclaw_pdf_candidates` checklist item makes PDF discovery terminal
  evidence visible before the stricter source-screen/workbook/Bookkeeper gates
  can pass. During reconciliation, Moondesk copies that artifact into
  `raw/analysis-runs/<run>-official-pdf-candidates.json`, so partial MoonClaw
  runs still leave durable MoonBook-owned evidence even when final workbook
  publication remains blocked. The book-level
  `raw/analysis-runs/eb-output-validation.json` final gate now also requires
  that durable candidate file in addition to the accepted workbook and
  official-source screen. Accepted workbook manifests must also bind
  `pdf_candidates_path` to the canonical
  `raw/analysis-runs/<run>-official-pdf-candidates.json` evidence path, so an
  accepted spreadsheet cannot validate without a durable first-step discovery
  record. If the workbook and source screen exist but the candidate evidence is
  missing, the gate reports
  `accepted_output_waiting_for_pdf_candidates`.
  If the bounded Moondesk launcher times out while the persisted MoonClaw run
  metadata still says `Running`, run health reports
  `moonclaw_run_orphaned_after_timeout` plus
  `moonclaw_run_retry_recommended`. A production proof that is allowed to
  launch and execute, including the explicit forced retry action, treats that
  receipt as abandoned and re-imports the proposal packet to create a fresh
  confirmed run id instead of executing the stale run id again. If the
  replacement import fails or times out before MoonClaw returns a new run id,
  Moondesk archives that failed retry at
  `raw/analysis-runs/moonclaw-proposal-retry-import.json`, skips re-executing
  the orphaned run, and restores the last confirmed import receipt so health
  still points at the orphaned run. If an
  older book has already lost that canonical import context, run health can
  recover the effective confirmed-run context from
  `eb-production-proof.standing_goal_sync.run_health` or the latest confirmed
  `raw/analysis-runs/*-moonclaw-run.json` receipt, and exposes
  `moonclaw_import_receipt_recovered` plus
  `moonclaw_import_recovery_source`.
  The EB builder's Production Audit panel renders those recovered import/run
  fields together with the retry-import receipt and retry recommendation. When
  health marks an orphaned timeout, the UI exposes `Fresh Retry Orphaned Run`,
  which calls the same production-proof route with forced execution and launch
  enabled so Moondesk imports a replacement confirmed run instead of asking the
  operator to patch receipts by hand.
  The run-health handler also performs an idempotent preflight sync from the
  book-local `moontown-standing-goal-registration.json` receipt before
  computing health, so a direct audit read repairs stale global
  `.moontown/standing-goals.json` state and reports
  `global_standing_goal_ready` from the current repaired scheduler file.
  Run health also audits the generated MoonClaw runtime contract and the run
  artifacts for web-tool evidence. `production_ready` requires
  `moonclaw_web_tool_contract_ready`, meaning the packet/profile requested
  executor/full runtime access with `allow_execution_tools: true` and required
  `web_search`/`web_fetch`, and no MoonClaw output reports planner-only,
  limited, or unavailable web tools. The generated EB profile uses
  `role: "eb_pdf_evidence_worker"` plus profile/step `metadata.role_runtime`
  rather than MoonClaw's planner-only `controller` envelope, and the proposal
  packet source path/book root are absolute so MoonClaw can resolve the
  durable MoonBook context during import.
  The production source-screen gate also requires structured durable evidence:
  an official-domain source record must show download and extraction status and
  include a PDF hash/path plus an extracted-text hash/path, with the referenced
  book-local `raw/pdfs/` and `raw/extracted/` files present in the MoonBook.
  Declared `downloaded_pdf_count` and `extracted_pdf_count` values alone are
  not enough to pass production readiness.
  When the one-click production proof has been attempted, run health also
  reports the latest `raw/analysis-runs/eb-production-proof.json` receipt path,
  status, proof level, run id, and failed checks.
  The response also includes `production_checklist`, a stable array of
  `{id,label,ok,requirement,evidence}` items for the book contract, production
  target config, standing goal, MoonClaw import/run/web-tool contract/stderr, live result,
  watcher update, Moontown book result, accepted workbook, hash-bound workbook
  validation, source-backed data-row proof, appendix notes, quality proof,
  lifecycle proof, non-sample proof, workbook-to-target matching,
  official source screen, and final output
  validation. This checklist is the
  operator-facing audit trail for why an EB proof is `production_ready` or still
  `not-proven`.
- `POST /api/books/moonclaw-import` imports an EB book's
  `moonclaw-packets/eb-standing-watch-proposal.json` through the current
  MoonClaw CLI, then writes
  `raw/analysis-runs/moonclaw-proposal-import.json` with stdout/stderr, exit
  code, `proposal_id`, optional `run_id`, home/cwd, and packet path. With
  `confirm: true`, the UI's Launch MoonClaw Run action asks MoonClaw to create
  a real run and records `status: run_confirmed` when a run id is returned.
  Moondesk also writes the Moontown-compatible packet-side
  `moonclaw-packets/eb-standing-watch-proposal.json.import.json`, a sidecar
  `.err`, and
  `raw/analysis-runs/moontown-task-execution.json` so Moontown's standing-goal
  supervision can reconcile the same packet into a `RunConfirmed` execution
  record. The receipt keeps the MoonClaw `home`, command, stdout, and stderr so
  later run-health checks can prove whether the detached runner actually moved
  past `Pending`. Run health preserves raw import stderr, but marks the known
  `tcc: error: invalid option -- '--home'` Moon wrapper diagnostic as
  `moonclaw_import_stderr_tolerated` when the import exited 0 and returned a
  valid proposal/run id; that diagnostic no longer hides the actual runtime
  blocker. The EB packet and workspace-local `moonclaw.jobs.json`
  profile explicitly set executor/full runtime metadata,
  `allow_execution_tools: true`, required `web_search`/`web_fetch`, and
  non-interactive missing-input policy, so official-PDF discovery is requested
  through MoonClaw's role/runtime contract instead of being implied by prompt
  prose. Inline
  imports accept a bounded timeout and are recorded as `timed_out` instead of
  keeping the Moondesk HTTP request open indefinitely.
- `POST /api/books/moonclaw-run` executes the confirmed run id from
  `raw/analysis-runs/moonclaw-proposal-import.json` through MoonClaw's
  `proposal run` command, with a bounded timeout. It writes
  `raw/analysis-runs/<run-id>-moonclaw-run.json` with command, stdout/stderr,
  timeout state, MoonClaw `meta.json`, and refreshed run health. This gives
  Moondesk a desktop recovery path for confirmed runs that are still pending or
  running before strict reconciliation, and the health surface exposes
  `moonclaw_run_receipt_*` fields plus `moonclaw_execution_stderr_clean` so the
  operator can see whether recovery actually made the execution path clean.
- `POST /api/books/eb-production-proof` is the one-click production proof
  wrapper for EB books. It launches a confirmed MoonClaw proposal if no run id
  exists, reuses an existing successful confirmed-run receipt when present,
  otherwise runs the confirmed id through MoonClaw with a bounded timeout,
  calls strict reconciliation, refreshes run health, and writes
  `raw/analysis-runs/eb-production-proof.json`. Failed forced retry imports are
  recorded separately in `raw/analysis-runs/moonclaw-proposal-retry-import.json`
  when Moondesk needs to preserve an older confirmed import/run for orphaned-run
  recovery. The refreshed run-health object points back to the proof receipt so
  operators can audit the latest proof attempt from the normal health endpoint.
  Its `ok` flag is exactly the
  final `production_ready` health flag, so it records `not-proven` rather than
  weakening any live-source, workbook, Bookkeeper, or run-metadata gate. Before
  importing or launching MoonClaw it also checks `book.json.targets.bonds` (falling back to
  `raw/inbox/eb-tracking-request.json`) and requires every EB target to have a
  real non-sample `132XXX` code, bond name, issuer, underlying listed company,
  and `上交所`/`深交所` exchange. The default `132001 / 示例EB` target remains
  usable for deterministic sample validation but blocks production proof and
  MoonClaw import/run execution. The builder starts EB target fields empty,
  shows target-readiness blockers inline, and marks MoonClaw action buttons as
  unavailable for the just-created book until the target is production-ready.
- `POST /api/books/moonclaw-reconcile` is the strict bridge from a completed
  MoonClaw run back into Moondesk/Moontown health. It defaults the run id from
  `raw/analysis-runs/moonclaw-proposal-import.json`, reads the persisted
  MoonClaw run meta under `<home>/jobs/runs/<run>/meta.json`, imports
  `moonclaw-jobs/<run>/result.json`, normalizes/copies the run's
  production official-source screen into
  `raw/analysis-runs/<run>-official-source-screen.json`, and only appends
  `.moontown/watchers/<goal>.jsonl` plus
  `.moontown/book-results/<run>.json` when all gates pass: accepted workbook,
  accepted `.xlsx.manifest.json`, hash-bound `.xlsx.validation.json`, extracted
  workbook XML proving the required EB sheets/headers, non-sample `result.json`,
  matching receipt run
  id, succeeded persisted metadata, Bookkeeper acceptance, and a source screen
  that proves a live official PDF fetch/extract by setting
  `live_fetch_performed: true`, including official-domain URLs, and reporting
  positive `downloaded_pdf_count` plus `extracted_pdf_count`. The source screen
  may provide those proofs either as top-level counters/URL arrays or as
  structured `sources`, `checked_sources`, `accepted_sources`,
  `official_sources`, `pdf_sources`, or `source_records` entries with official
  URL fields, download/extract status, and book-local PDF/text artifact paths
  that exist under `raw/pdfs/` and `raw/extracted/`. Third-party repost URLs reject the
  production gate even if the counters look valid. Partial runs write a
  reconciliation receipt but do not become accepted knowledge. The EB builder
  calls this route through its
  `Reconcile MoonClaw Result` action after an operator launches or imports a
  MoonClaw run.
- `POST /api/books/accept-recovered-eb-output` is a separate recovery bridge,
  not a relaxed production bridge. It accepts only when run health already sees
  a verified EB book contract, production-ready target config, accepted
  non-sample workbook, valid manifest, hash-bound validation sidecar, data-row,
  hyperlink, appendix, quality, lifecycle, target-match, and production
  source-screen proofs. It then writes a recovered
  `moonclaw-jobs/<run>/result.json`, Bookkeeper recovered-output review,
  refreshed `raw/analysis-runs/eb-output-validation.json`, watcher ledger
  update, accepted Moontown book result, and
  `raw/analysis-runs/<run>-accepted-output-recovery.json`. Recovered result
  records carry `recovery_mode: accepted_output_recovery` and are explicitly
  excluded from the live MoonClaw result predicate, so they can satisfy
  `durable_ready` but cannot satisfy `production_ready`.
  The generated EB runtime includes `raw/bootstrap/eb_extract_pdf_text.py`,
  which uses the locally available pypdf library to make the MoonClaw
  extract/source-screen step deterministic: downloaded official PDFs become
  `raw/extracted/*.txt`, and missing extraction input becomes a failed
  source-screen artifact instead of a best-effort prose continuation. The
  generated runtime also includes `raw/bootstrap/eb_package_workbook.py`, a
  standard-library packager that writes the accepted EB workbook, sibling
  manifest, validation sidecar, MoonClaw `result.json`, run report, durable
  PDF-candidate artifact, and durable source-screen artifact from official
  source records after Bookkeeper acceptance. The
  MoonClaw profile and packet set `best_effort_on_missing_input: false` for
  this production path.
- `POST /api/books/from-pattern` creates a reusable book pattern under
  `.moontown/books/`, writes the durable MoonBook layout, upserts
  `.moontown/moonbooks.json`, stages a Moondesk handoff record, and registers a
  normal Moontown standing-goal record targeting the book id with Moontown's
  current `watch-<book-id>-pdfs` identity. The request may
  include explicit `book_id`, `base_type`, `purpose`, `skill_pack`, source
  websites, cadence, source policy, and notification rules either as flat
  fields or through the nested `watch` / `analysis` config shape used by the
  current Moontown PDF Evidence Watch template; Moondesk currently
  accepts `research-book` for these patterns and rejects incompatible
  base/pattern pairs. Generated `book.json` and
  `raw/analysis-runs/moontown-template-publish.json` both preserve a
  `base_type_provenance` object that binds the selected `research-book` base to
  MoonBook layout docs and Moontown template-registry refs, so the verifier can
  prove the book was built on the reusable MoonBook base rather than a hidden
  Moondesk-only type. Moondesk also writes
  `raw/analysis-runs/base-type-selection.json` as a book-local proof that the
  base came from `/api/books/base-types` before the specialized pattern was
  layered on and handed to Moontown. It writes that operator-facing nested config into the
  book as `raw/inbox/pdf-evidence-watch-config.json`, where the human can edit
  cadence, websites, PDF file type/dedupe policy, method page, and notification
  rule without touching generated receipts. It also writes a
  strict latest-Moontown `PdfEvidenceWatchInstallSpec` under
  `.moontown/book-template-configs/` with a config-relative
  `../books/<book-id>` workspace root, an `installed`
  `.moontown/book-template-requests.json` entry, and a durable
  `raw/analysis-runs/moontown-template-publish.json` receipt plus
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipt. The
  publish receipt records the owner split, target book id, standing goal id,
  reusable `research-book + source adapter + extractor + analysis skill +
  standing watch` contract, structured output-contract handoff, and
  installed-request lifecycle so Moontown can
  reconcile the lifecycle event without guessing why the request is not
  pending. Moondesk creates the local specialized research-book immediately and
  marks the template request installed so Moontown schedules the standing goal
  without re-running the generic template installer over the richer book. The latest local Moontown
  generic installer still rewrites `book.json` into an older generic shape, so
  a `pending` request is not safe for Moondesk-built research-book patterns
  until that installer preserves the richer schema. Generic PDF-watch books publish `targets.target_count:
  0`; EB books accept either the single target fields or a `target_bonds` array
  and preserve that array through `book.json`, the MoonClaw execution request,
  the Moontown dispatch packet, and the importable MoonClaw proposal packet.
- `POST /api/books/pdf-evidence-watch` remains a compatibility alias for the
  same pattern creation flow.
- The PDF evidence watch layout follows the latest Moontown contract:
  `book.json` keeps `book_type: research-book`, `specialization:
  pdf-evidence-watch`, source websites, PDF file type/dedupe rules,
  `watch.notify_on`, schema pointers, and `wiki/methods/my-analysis-method.md`.
  The local Moontown registry checked for this integration advertises
  `pdf-evidence-watch` as `book_type: research-book` and now includes a separate
  `app-tool-book` template; Moondesk intentionally keeps PDF Evidence Watch in
  the research-book family rather than hardcoding a new Moontown feature.
  The durable layout includes `raw/inbox`, `raw/pdfs`, `raw/extracted`,
  `raw/analysis-runs`, wiki sources/evidence-matrix/findings/methods/reviews/history pages,
  local `pdf-watch` and `pdf-analysis` skills, schemas, `book/Home.html`, and
  `book/site/generated/index.html`.
- The exchangeable-bond pattern is not a separate Moontown feature. It is
  `research-book + source adapter + extractor + analysis skill + standing
  watch` with EB-specific source defaults, analysis method, `eb-credit-compliance`
  skill, customizable single-bond fields or a multi-bond target list for bond
  code, short name, issuer, underlying company, and exchange, an XLSX output
  contract, and a durable starter workbook at
  `book/outputs/EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`. It also writes
  the operator's EB analyst prompt into `raw/bootstrap/EB_OPERATOR_PROMPT.md`
  with `raw/analysis-runs/eb-prompt-contract.json`, and mirrors that contract
  into the generated method and skill files:
  target-bond identity fields, P0-P4 official source priority, six disclosure
  stages, timing and cross-verification rules, official-link validation,
  `未检索到` missing-disclosure markers, the two required workbook sheets, and
  the section-seven execution directive for systematic search, extraction,
  validation, final Excel generation, and multi-bond sheet grouping.
  It also writes
  `raw/inbox/eb-tracking-request.json` as MoonClaw's bounded execution target,
  `raw/inbox/eb-standing-watch-dispatch.json` as Moontown's durable dispatch
  packet, `raw/bootstrap/EB_WATCH_CONTRACT.md` as the standing-watch marker
  contract that requires fields such as `standing_goal_decision`,
  `delta_score`, `new_source_count`, `accepted_facts_count`, and `book_changed`,
  `moonclaw.jobs.json` as a workspace-local EB evidence-watch profile, and
  `moonclaw-packets/eb-standing-watch-proposal.json` as an importable MoonClaw
  external proposal packet whose context points at the generated book method,
  skills, dispatch packet, execution request, and output schema. The packet can
  be imported or launched from Moondesk, which records the resulting MoonClaw
  receipt under `raw/analysis-runs/moonclaw-proposal-import.json`, mirrors
  MoonClaw's packet-side import receipt for Moontown, and writes
  `raw/analysis-runs/moontown-task-execution.json` with `ProposalImported`,
  `RunConfirmed`, or `Failed` state. It also writes
  `raw/analysis-runs/eb-expected-output-contract.json` as the explicit
  book-local final workbook contract,
  `raw/analysis-runs/eb-contract-verification.json` as the durable contract
  verification record, and `raw/analysis-runs/eb-output-validation.json` as the
  output gate. The output gate and EB run-health production checklist both
  require the expected-output contract receipt before reporting final workbook
  readiness. The Moontown publish, template-request, install-config, and
  standing-goal registration receipts also carry an `output_contract` handoff
  object so the scheduler-side audit can see the expected workbook contract
  without reconstructing it from MoonBook files. The EB runtime refresh route
  also rewrites stale Moontown publish and standing-goal registration receipts
  for existing books, so older EB workspaces can regain that scheduler-side
  output-contract handoff without being recreated. The Moondesk EB production
  audit panel renders the same contract path, readiness flag, and contract id
  beside workbook validation evidence. It also renders the base-type selection
  receipt, Moontown handoff target, Moontown publish receipt, standing-goal
  registration readiness, and global standing-goal readiness so operators can
  audit the full base-book-to-Moontown chain from the desktop. Its audit action refreshes stale EB
  runtime scaffolding before presenting health. The starter template and every accepted output have a sibling
  `.xlsx.manifest.json` that records the workbook path, `xlsx_sha256`,
  output contract, Bookkeeper acceptance state, and required sheet headers. The
  manifest hash must match the workbook bytes, so replacing an accepted workbook
  without regenerating its manifest invalidates the output. The gate remains
  `template_ready_waiting_for_accepted_output` until Bookkeeper/MoonClaw creates
  a non-placeholder workbook with a valid accepted manifest, required OOXML
  workbook parts, extracted workbook XML containing the required EB
  sheets/headers, and official hyperlink relationships for original-link cells, moves to
  `accepted_output_waiting_for_source_screen` if that workbook lacks a durable
  official-source screen, and reports `accepted_output_ready` only when
  accepted workbook, official-source screen, and official-PDF candidate evidence
  are all present. The generated `eb_extract_pdf_text.py` and
  `eb_package_workbook.py` helpers tolerate MoonClaw partial-run artifact shape:
  discovery can leave official URL/title evidence in a step JSON `content`
  field while extraction leaves only book-local `raw/pdfs/` and
  `raw/extracted/` paths. The helpers parse those official URLs, merge them
  with the durable PDF/text records by path/hash/title or stable order, then
  write normalized source/candidate artifacts that keep official URL, PDF hash,
  extracted text path, and workbook sidecars bound together.
  `raw/analysis-runs/*-official-source-screen.json` also passes the official
  source gate. This output gate accepts deterministic source-policy artifacts,
  but the stricter production reconciliation gate additionally requires live
  fetch/extract evidence.
- `POST /api/books/eb-sample-run` is a deterministic packaging validation path
  for EB books. It writes `moonclaw-jobs/<run>/result.json`, `report.md`,
  `outputs/official-source-screen.json`, `outputs/eb-output-validation.json`,
  `wiki/sources/eb-official-source-screen.md`,
  `wiki/reviews/bookkeeper-eb-sample-run.md`, `.moontown/watchers/<goal>.jsonl`,
  `.moontown/book-results/<run>.json`, and a non-placeholder workbook, then
  returns the same durable run-health object. This proves durable
  Moondesk/MoonBook/Moontown output wiring plus the source-screen gate; it is
  not a substitute for live MoonClaw official-site PDF discovery, download,
  extraction, and source-backed analysis.
- `POST /api/town/dispatch` runs one Moontown daemon tick when the configured
  root is a runnable Moontown checkout, repairs registered PDF-watch standing
  goals before and after the tick, then records stdout/stderr/status plus repair
  metadata under `.moontown/moondesk-dispatches/`.
- MoonClaw run routes list run workspaces and visible `report.md`,
  `result.json`, and `outputs/*.md|*.json` artifacts.
- `GET /api/moonclaw/events` projects visible MoonClaw event/result files into
  normalized live events.
- `GET /api/moonclaw/progress` returns aggregate run/ready/artifact counts and
  latest run status for a selected workspace or all workspaces.
- `GET /api/agents/daemon` reports the local MoonClaw daemon pid/port/root from
  `~/.moonclaw/daemon.json`.
- `GET /api/agents/models` lists daemon models when MoonClaw is running.
- `GET /api/agents/tasks` lists active MoonClaw daemon tasks when available.
- `GET /api/agents/sessions?workspace=...` lists persisted Moondesk agent
  sessions, enriched with live MoonClaw task status when the daemon is running
  and saved MoonClaw conversation events when a task transcript exists, with a
  bounded workspace `.moonclaw/log.jsonl` progress fallback for in-flight or
  incomplete task output.
- `POST /api/agents/sessions` validates the target workspace, starts MoonClaw
  from a native `cmd/main` executable when a runnable checkout is found,
  creating that executable when necessary, creates or reuses the workspace-root
  task, sends an initial selected-context message, and persists a session
  record.
- `POST /api/agents/sessions/:id/message` sends a follow-up contextual user
  message to the attached MoonClaw task and appends local transcript/status
  records.
- `POST /api/agents/sessions/:id/cancel` forwards cancellation to MoonClaw and
  records the result in the local session transcript.
- `GET /api/review/items` lists review/failure items from review folders and
  Moontown event signals.
- `POST /api/workspaces/:id/reveal` reveals a scoped workspace path in Finder
  on macOS or opens the containing folder on Linux.
- `GET|POST /api/preferences/views` persists saved view records under
  `.moontown/moondesk-preferences/views.json`.
- `GET|POST /api/preferences/tags` persists selected path tags under
  `.moontown/moondesk-preferences/tags.json`.

## Persistence

Moondesk should keep only desktop preferences and cache:

- known roots
- opened tabs
- layout state
- recent files
- preview cache
- UI preferences
- agent session metadata and desk-visible transcripts under
  `.moontown/moondesk-agent-sessions/`

Canonical content remains in MoonBook, Moontown, or MoonClaw.
