# Moondesk Status

Last validated: 2026-06-03. Latest local Moontown reference checked:
`e060e6e Implement live autonomy spine`.

## Summary

Moondesk is a usable local alpha for a single operator working against an
existing Moontown/MoonBook/MoonClaw checkout. The desk, scoped host APIs,
Moontown request flow, managed daemon lifecycle controls, and self-contained
macOS bundle all have working implementations. The latest slice replaces the
browser-shell-only package with a native AppKit/WebKit window launcher, keeps a
browser-shell fallback via `bundle --shell browser`, and includes
release/update manifests, DMG creation, LaunchAgent install/remove/status
flows, event/failure/review queues, local file import staging, richer review
diffs, expanded operating analytics, a Codex-like Agents activity, and stricter
PDF Evidence Watch production gating for MoonClaw web-tool execution.

The host implementation has also been refactored from a monolithic
`internal/moonwiki/server.mbt` into responsibility-sized package-local modules:
router shell, workspace/search/town/book/MoonClaw API handlers, request helpers,
book-pattern registry support, PDF-watch builder/publish/verification logic, EB
prompt/lifecycle/script/MoonClaw/output contracts, EB runtime
refresh/flow/result/validation/health/proof logic, runtime projections,
daemon/session support, and focused whitebox test files. This is a
behavior-preserving modular split: public HTTP/API contracts are unchanged,
while dated EB fixture seeds now live only in
`moonwiki_fixtures_wbtest.mbt` so production EB discovery continues to rely on
dynamic source discovery rather than baked-in prompt hints.

The current `.app` is a foreground native macOS window. The bundle executable
is an AppKit/WebKit launcher, and the MoonBit MoonWiki host runs as an internal
`moondesk-host` helper from the same bundle. Browser dev mode remains available
through `serve`/`desktop` and as an explicit fallback shell.
Developer ID notarization is wired through `cmd/main release`, but real
distribution still depends on external Apple credentials, update hosting, and
clean-machine validation.

## Standalone App Answer

Moondesk is standalone at the host/package level and now owns a native macOS
window in the packaged app.

- Standalone today: `cmd/main bundle` creates `Moondesk.app` with a native
  AppKit/WebKit launcher, the internal `moondesk-host` MoonBit executable, and
  bundled UI assets. Launching the bundle does not require `moon run`, Cargo,
  Rust, Tauri, or a dev server.
- Windowing decision: the bundled app opens a real macOS window and loads the
  local Rabbita UI in WebKit. `bundle --shell browser` preserves the previous
  browser-shell behavior for fallback/debug use.
- Release-ready shape exists: `cmd/main release` creates a release manifest,
  update manifest, zip, and DMG, verifies signing, and can submit the zip
  through Apple notarytool when a real keychain profile is supplied.
- App-tool books now have a separate portable artifact: `POST
  /api/books/app-tool-portable` writes `portable/app-tool/index.html`,
  `portable/app-tool/portable-manifest.json`, copied entrypoints, declared
  outputs, app assets, generated site assets, skills, schemas, and tool docs.
  This is a static per-book bundle that another standalone shell can open
  without Moondesk when the book has an existing HTML entrypoint. Exports now
  include `moondesk-api-snapshot.json` and
  `moondesk-api-shim.js`; copied HTML entrypoints load the shim so supported
  read-only Moondesk API calls such as `/api/books/patterns`,
  `/api/books/base-types`, `/api/books/template-registry`, and
  `/api/workspaces` resolve from the portable bundle. The validator reports
  `portable_with_api_warnings` only when copied assets still contain API
  dependencies the shim cannot cover, such as unsupported `/api/*` routes or
  direct resource links.
- Workspace-wide export is available through
  `GET/POST /api/books/app-tool-portable/all`: it discovers every MoonBook under
  `.moontown/books` that declares direct `toolbook` or `app-tool-book` metadata,
  ignores ordinary research books, and returns per-book portability status plus
  aggregate counts. The Town book tools expose this as `Export All Portable Apps`.
- Production distribution dependency: a real notarized artifact still requires
  Developer ID credentials, hosting the update manifest/artifacts, and validating
  the installed app on a clean machine.

## Functional Readiness

| Area | Status | Notes |
| --- | --- | --- |
| Workspace discovery and explorer | Working | Discovers MoonBooks under `.moontown/books`, lists scoped entries, and opens common book paths. |
| Previews and raw files | Working | Markdown, HTML/site, JSON, image, text, and artifact previews are available through scoped routes. |
| Inbox notes | Working | Creates markdown inbox notes, edits scoped `inbox/*` paths, imports URLs/data-url attachments, and stages local file picker/drop/paste imports into `inbox/imports`. |
| Search and context assembly | Working first slice | Cross-book text search, favorites, recent paths, copy-to-inbox, saved views, path tags, review queues, and review diff summaries are present. Richer output-library navigation can still be refined. |
| Moontown submissions | Working first slice | Stages request records, shows request ledger and town messages, creates standing-watch records, publishes reusable book patterns from Moondesk, upserts `.moontown/moonbooks.json`, registers standing goals, runs one daemon tick, and exposes progress plus event/failure/review summaries. |
| Book pattern builder | Working first slice | Moondesk exposes a creation UI for `pdf-evidence-watch` and `exchangeable-bond-evidence-watch` with editable book id, purpose, websites, cadence, notification rule, skill pack, and method document. It reads the latest Moontown book-template registry when available, surfaces registry-backed base types/patterns, and reports template readiness through `/api/books/template-registry`. Both patterns remain `research-book` based. Generic PDF-watch books publish the reusable `research-book + source adapter + extractor + analysis skill + standing watch` contract without fake EB targets. The publish path keeps Moondesk-created books as the authoritative richer workspace: Moondesk writes the operator-facing nested config to `raw/inbox/pdf-evidence-watch-config.json`, writes `wiki/methods/my-analysis-method.md` plus the latest Moontown-compatible `wiki/methods/analysis-method.md` alias, records explicit layout metadata for `raw/inbox/`, `raw/pdfs/`, `raw/extracted/`, `raw/analysis-runs/`, `wiki/`, `skills/`, `schemas/`, and `site/generated/`, writes a flat `PdfEvidenceWatchInstallSpec` using a Moontown-local `../books/<book-id>` workspace root, records an `installed` book-template request/event, writes `raw/analysis-runs/moontown-template-publish.json`, and writes `raw/analysis-runs/moontown-standing-goal-registration.json`. The publish receipt now names the owner split, standing goal id, target book id, installed-request lifecycle, accepted-new-knowledge-only notification rule, and reason Moontown should reconcile the event rather than re-run the generic installer. This is intentional because the current Moontown generic `pdf-evidence-watch` installer still rewrites `book.json` into its older generic shape; Moondesk therefore asks Moontown to schedule the standing goal without re-running that installer over the richer research-book. `POST /api/books/sync-standing-goal` repairs the global `.moontown/standing-goals.json` registry from the book-local receipt when Moontown maintenance rewrites or drops non-core goals. The EB pattern preloads official source sites, captures either one target bond or a multi-bond list into the MoonClaw execution request, writes a workspace-local MoonClaw EB profile plus importable proposal packet, writes a durable Moontown standing-watch dispatch packet plus required EB watch-marker contract, writes bounded MoonClaw execution metadata (`timeout_ms: 300000`, `max_total_tokens: 48000`) into generated EB steps so long official-source scans produce durable terminal evidence instead of silent orphaned runs, writes the EB analyst prompt into the lifecycle/credit/compliance analysis method and skill files, and now also writes the same prompt as `raw/bootstrap/EB_OPERATOR_PROMPT.md` with `raw/analysis-runs/eb-prompt-contract.json` verification so MoonClaw/Bookkeeper can execute from the book without relying on external prompt memory. That prompt carries official-source priority, six disclosure stages, quality rules, missing-disclosure markers, exact workbook headers, and the section-seven execution directive for systematic search/extraction/validation plus multi-bond sheet grouping. The EB path writes schemas, generated site, Moontown handoff, a durable MoonBook evidence matrix, an XLSX output contract, a durable starter workbook with the required two sheets, a contract verification record, and an output-readiness record that distinguishes the placeholder template from accepted final EB workbooks. The UI can import the generated packet through MoonClaw, launch a confirmed MoonClaw run, persist the local proposal receipt, mirror the packet-side `.import.json` receipt for Moontown reconciliation, write a Moontown-style task execution receipt, reconcile completed live MoonClaw run outputs from the desk through strict workbook/manifest/source-screen/run-meta gates, then run a deterministic EB output validation pass that writes MoonClaw-style run artifacts, Bookkeeper review, watcher ledger, town result, accepted sample workbook, and a durable run-health check. |
| MoonClaw agent sessions | Working | The Agents activity lists per-book sessions, starts or connects to the MoonClaw daemon through a native MoonClaw executable, creates/reuses the book-scoped task for the workspace root, sends contextual user messages, folds saved MoonClaw assistant/tool/failure events and workspace `.moonclaw/log.jsonl` progress rows into the transcript, supports web-search/model selection, cancels active task work, and persists local session metadata under `.moontown/moondesk-agent-sessions/`. The MoonCode protocol view now knows about MoonClaw's native `runtime-turn` endpoint for claim -> explicit/deterministic/model-planned tool execution -> runtime-completed/runtime-failed receipts, native `runtime-loop` queue supervision for run-until-idle/failure/cancel/max-turns execution, native package manifest/index creation with `package_built`/`package_verified` proof for generated tools and miniapps, native bounded `apply_patch`/`revert_patch` tools for reviewed text replacements and single-file unified-diff hunks with `runtime.patch_applied`/`runtime.patch_reverted` proof events, and MoonClaw's first native tool/file-edit eval harness report from the selected book-scoped eval endpoint. MoonClaw can now use an explicitly selected model for bounded OpenSeek-style tool-call planning with tool-result feedback, deterministic fallback, and native reasoning/assistant/tool-call/tool-result events; the remaining gap is live steering/diff-review polish, multi-file patchsets, per-hunk runtime dispatch, and model-backed coding eval coverage. |
| Background daemon lifecycle | Working | UI/API support status, start, stop, restart, desired-state supervision policy, reconcile-on-status restart, LaunchAgent install/remove/status, persisted state, and log paths under `.moontown/moondesk-daemon/`. Log rotation and multi-root daemon governance are still hardening work. |
| MoonClaw run/artifact projection | Working first slice | Lists visible run workspaces and common artifacts, aggregate progress counts/latest run status, event records, result summaries, and failure/review signals. |
| Daily operating surface | Working first slice | Shows counts, cadence list, due-tick calendar, watcher outcome mix, browser notifications, saved views, tags, event/review analytics, review queue, and an ICS export. Trend charts and external calendar subscription polish are optional refinements. |
| Scoped desktop helpers | Working first slice | Finder reveal is scoped under the selected workspace. Browser launch is still implemented for `desktop` and `bundle --shell browser`. Local file picker/drop/paste import is staged through host APIs. Open-with-external-app remains future polish. |
| Native packaging | Working local distribution | `bundle` builds the native MoonBit host helper plus an AppKit/WebKit launcher, copies bundled UI resources, writes absolute runtime config, signs with `codesign` by default, creates a zip, and bundled launch opens a native window. `release` writes release/update manifests, verifies signing, creates a DMG, and can submit the archive through `xcrun notarytool --keychain-profile`. |

EB evidence-watch books now also write `raw/analysis-runs/eb-expected-output-contract.json`, a book-local receipt for the exact final XLSX filename, sheet/header, sidecar, lifecycle, official-source, multi-bond, and Bookkeeper acceptance requirements. Contract verification and deterministic output validation use that receipt so the expected workbook shape is auditable without reconstructing it from the prompt, schema, dispatch packet, and starter workbook.
Run health now surfaces the same receipt as `expected_output_contract_ready` plus an `expected_output_contract` production-checklist item, so missing or stale workbook-contract proof blocks final EB output readiness and appears in the operator-facing health report.
The Moontown publish receipt, template request, install config, and standing-goal registration receipt now also carry a structured `output_contract` handoff. For EB books that handoff points at `raw/analysis-runs/eb-expected-output-contract.json` and `raw/analysis-runs/eb-output-validation.json`, making the expected XLSX output contract auditable from the scheduler-side records as well as from the book-local verifier.
Moondesk's EB production-audit panel now renders that expected-output contract path, readiness flag, and contract id beside the workbook-validation evidence, so operators can see why an EB book is or is not ready to publish the final accepted XLSX. The same panel also shows the base `research-book` selection receipt, Moontown handoff target, Moontown publish receipt, book-local standing-goal registration, and global standing-goal readiness, making the full `base type -> Moondesk pattern -> Moontown standing watch -> expected XLSX output` chain auditable without opening raw JSON. The same audit action refreshes stale EB runtime scaffolding before reading health, so older EB books can repair the expected-output receipt and stale Moontown publish/standing-goal output-contract handoff receipts instead of remaining blocked until a manual JSON refresh.

## How Far To Fully Functioning

| Target | Readiness | Meaning |
| --- | --- | --- |
| Local native-window daily use | 95% | The planned M0-M7 workflow is implemented for a single operator: browse, preview, search, inbox/import, submit, talk to MoonClaw in book-scoped sessions, supervise daemon actions, inspect runs, use saved views/tags/review queues, and export cadence. |
| Self-contained local `.app` bundle | 95% | The bundle contains the AppKit/WebKit launcher, internal native MoonBit host, and UI assets, launches without `moon run`, declares native-window mode, and has release/update manifests plus DMG output. |
| Production native-window desktop app | 85% | Core data plumbing, local workflow surfaces, release packaging, native windowing, and daemon install UX exist. Remaining work is mostly real credentialed notarization, artifact hosting/update policy, clean-machine validation, and long-running reliability testing. |
| Multi-user or organization-grade deployment | 50% | There is not yet a hardened permissions model, fleet distribution, remote policy, multi-root daemon governance, audit log, or support/update story. |

The practical answer: Moondesk is already useful as a local single-user alpha
and close to functionally complete for the native-window desktop target. It now
matches the core Codex-style packaging shape: a normal macOS app window backed
by a bundled local host.

Current assessment after the M7 agent-console pass:

- Feature-complete for local single-user native-window use except daily-use
  polish and long-running reliability hardening.
- Standalone as a self-contained local `.app`; production distribution still
  depends on real signing/notarization credentials, hosted update artifacts,
  and clean-machine validation.
- Not organization-grade yet because multi-root governance, hardened
  permission policy, audit trails, remote policy, and support/update operations
  are not implemented.

## Remaining Work

High-priority work before calling it production-ready:

- Run the `release` notarization path with real Developer ID credentials and
  validate the DMG/zip on a clean macOS account.
- Host `updates.json` and artifacts somewhere durable, then decide whether
  Moondesk only publishes update metadata or also owns an in-app updater.
- Add log rotation and multi-root policy for long-running LaunchAgent use.
- Reconcile Moondesk-managed daemon state with any independently running
  Moontown daemon.
- Finish the MoonClaw autonomous MoonCode service beyond the current queue
  supervisor and bounded model/tool feedback planner: persistent live
  resume/steer semantics, diff-aware review, and model-backed coding eval proof.
- Deepen output-library navigation, direct MoonClaw SSE event-stream rendering
  beyond the current saved/logged event projection, trend analytics, and
  calendar subscription polish after more real workspace usage.

## Full Functioning Criteria

Moondesk can be called fully functioning for the intended single-user desktop
scope when these are true:

- A user can install and launch it without a terminal. Implemented for bundle
  creation; still needs clean-machine validation.
- Native AppKit/WebKit windowing is the default packaged desktop shell.
  Implemented. Browser-shell launch remains available as fallback.
- The shipped artifact is signed, notarized, and reproducible from documented
  release commands. Implemented except for real credentialed notarization.
- The daemon can be installed, supervised, inspected, and removed from the UI.
  Implemented for the Moontown LaunchAgent and Moondesk-managed daemon loop.
- A user can talk to MoonClaw from Moondesk in the selected book/workspace
  context. Implemented through the Agents activity and `/api/agents/*` bridge.
- Inbox import covers URL, text/data URL, file picker, drag/drop, and pasted
  files/images. Implemented as staged inbox imports.
- Moontown/MoonClaw progress includes event records and actionable failure/review
  states. Implemented as polling summaries, queues, and agent transcript
  projection from saved/logged MoonClaw events.
- Search, saved views, tags, run artifacts, output libraries, and review/diff
  workflows are usable for repeated daily work. Implemented first slices; polish
  continues with real use.
- The validation checklist below passes on a fresh machine or clean workspace.

## Current Validation Checklist

The current tree should be considered healthy when these pass:

```sh
moon check
moon test
moon info
moon -C ui/rabbita-desk check --target js
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out /tmp/moondesk-release-check --port 4299 --skip-sign --no-dmg
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out /tmp/moondesk-native-bundle-check --port 4299
codesign --verify --deep --strict /tmp/moondesk-native-bundle-check/Moondesk.app
```

Manual smoke checks:

- `POST /api/books/from-pattern` can create a generic
  `pdf-evidence-watch` book whose verifier passes and whose Moontown template
  config/request plus standing goal are visible under `.moontown/`. The
  request is marked `installed` by Moondesk, not `pending`, because Moondesk has
  already written the richer `research-book` workspace and the current Moontown
  generic installer would rewrite that schema if re-run.
- Running `moon -C ../moontown run cmd/main -- books template requests process`
  after Moondesk publish should report zero pending Moondesk-created PDF watch
  requests. If global standing goals drift after Moontown maintenance,
  `GET /api/town/progress`, `GET /api/town/standing-goals`,
  `GET /api/town/analytics`, `GET /api/town/calendar.ics`, and
  `POST /api/town/dispatch` now rehydrate all registered PDF-watch standing
  goals from book-local receipts before returning. The sweep only considers
  books with explicit `pattern`, `specialization`, or legacy PDF-watch
  `book_type` metadata, so ordinary `research-book` workspaces are left alone.
  `POST /api/books/sync-standing-goal` remains the explicit one-book repair
  route and should report `global_standing_goal_ready: true`.
- The Moondesk builder presents the PDF Evidence Watch path as a reusable
  7-step wizard: choose `research-book`, add websites, author
  `wiki/methods/my-analysis-method.md`, select `pdf-watch`/`pdf-analysis`,
  enable the standing watch, set accepted-knowledge notifications, and publish
  the book/template receipt to Moontown. Moondesk now also writes the exact
  user-editable nested config shape to
  `raw/inbox/pdf-evidence-watch-config.json`; the Moontown install config
  remains the flat latest `PdfEvidenceWatchInstallSpec` so the current
  Moontown parser is not exposed to unknown fields. Contract verification also
  checks the requested `raw/inbox`, `raw/pdfs`, `raw/extracted`,
  `raw/analysis-runs`, wiki, skills, schemas, and generated-site layout, the
  standing-watch pipeline prompt, and the accepted-new-knowledge-only
  notification rule in the Moontown publish receipt.
- `POST /api/books/from-pattern` can create an EB watch with a `target_bonds`
  array; verification passes and the multi-bond list is durable in `book.json`,
  `raw/inbox/eb-tracking-request.json`,
  `raw/inbox/eb-standing-watch-dispatch.json`, and
  `moonclaw-packets/eb-standing-watch-proposal.json`.
- Custom EB method text is preserved in `wiki/methods/my-analysis-method.md`.
  If the supplied method omits required EB lifecycle/source/workbook terms,
  Moondesk appends the output-contract guardrails instead of letting the
  generated book fail verification.
- Accepted EB workbooks now require both a sibling `.xlsx.manifest.json` and a
  sibling `.xlsx.validation.json`. The validation artifact is hash-bound to
  the workbook bytes with `xlsx_sha256` and must prove the exact two-sheet EB
  header contract before the output gate treats the workbook as valid. Live
  reconciliation can copy this artifact from a MoonClaw result
  `workbook_validation_path`, but `production_ready` rejects sample validation
  artifacts.
- `GET /api/town/daemon/status` returns daemon state.
- `POST /api/town/daemon/supervision` persists desired-state policy.
- `GET /api/town/progress` and `GET /api/moonclaw/progress` return live
  summaries.
- `GET /api/town/events`, `GET /api/moonclaw/events`, and
  `GET /api/review/items` return event/review projections.
- `GET /api/workspaces/:id/review-diff?path=...` returns a line-level review
  comparison for review files.
- `GET|POST /api/town/daemon/agent` reports and manages the Moontown
  LaunchAgent install state.
- `GET /api/books/template-registry` returns the selected Moontown template
  registry, available templates, install examples, editable files, required
  assets, missing asset count, and derived base types. The current expected
  registry source is `templates/books/templates.json`, with
  `pdf-evidence-watch` as a `research-book` template and the latest local
  Moontown `app-tool-book` as a separate `toolbook` template.
- `GET /api/books/base-types` returns the available base MoonBook catalog
  derived from the registry-backed pattern catalog. The current creation flow
  intentionally builds PDF and EB patterns on `research-book`, while the base
  catalog also shows registry-discovered non-PDF bases such as `toolbook`
  without routing them through the PDF/EB creator. Base-type records now include
  provenance fields for the creation palette and MoonBook layout references, so
  the UI can show where the selected base came from.
- `GET /api/books/patterns` returns the reusable book pattern catalog, using
  Moontown's registry descriptor for `pdf-evidence-watch` when available and
  Moondesk's built-in pattern records as fallbacks.
- `GET /api/books/verify?book_id=<id>` verifies generated book-pattern
  contracts. EB verification checks the execution request, durable
  MoonClaw proposal packet, workspace-local MoonClaw profile, standing-watch
  dispatch packet, required watch-marker contract, explicit executor/full
  `web_search`/`web_fetch` runtime metadata plus non-interactive missing-input
  policy for MoonClaw,
  official-source domains, six lifecycle stages, exact workbook headers, XLSX
  payload, generated schema coverage for manifest/validation/source-screen
  proof artifacts, required validation sidecar proofs across
  request/dispatch/proposal handoff, MoonBook catalog, Moontown standing-watch
  handoff identity, book-local standing-goal registration receipt, and Moontown
  template request/config receipt. The response reports both
  `moontown_standing_goal_registration_ready` and
  `moontown_global_standing_goal_ready`, so a durable Moondesk handoff can pass
  while stale global Moontown scheduling is still visible.
- `GET /api/books/app-tool-portable?book_id=<id>` reports whether a MoonBook
  declares `app-tool-book` metadata through `book.json` or
  `tool-manifest.json`, which entrypoints exist, whether
  `portable/app-tool/index.html` is ready, which copied assets reference
  Moondesk APIs, which HTML files received the offline snapshot shim, and
  whether any unsupported API route or unresolved API dependency remains.
- `POST /api/books/app-tool-portable` exports any app-tool MoonBook, including
  direct `toolbook` templates and `research-book` patterns such as EB evidence
  watches with a ToolBook manifest, into a static `portable/app-tool/` bundle
  that preserves book-relative app/output paths for another standalone host. It
  requires an existing `.html`/`.htm` entrypoint because the generated portable
  shell opens the tool in an iframe; books with only non-HTML entrypoints report
  `unsupported_entrypoint` instead of a false portable-ready state.
  It writes `moondesk-api-snapshot.json` plus `moondesk-api-shim.js` and injects
  the shim into copied HTML files so supported read-only `/api/*` calls run
  without a live Moondesk process. The Town book tools expose the same operation
  as `Export Portable App` and open the generated bundle preview when the export
  succeeds.
- `GET /api/books/app-tool-portable/all` reports aggregate portability for all
  discovered app-tool MoonBooks in the workspace. `POST` to the same endpoint
  exports every discovered app-tool MoonBook and returns `exported_count`,
  `failure_count`, `api_warning_count`, and per-book receipts. The Town UI
  exposes the operation as `Export All Portable Apps`.
- `POST /api/books/sync-standing-goal` repairs stale global scheduling for an
  existing PDF Evidence Watch book by reading the book-local
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipt,
  reconstructing the standard `watch-<book-id>-pdfs` standing goal from
  `book.json`, upserting `.moontown/standing-goals.json`, and returning
  refreshed verification plus EB run-health evidence when applicable.
- `POST /api/books/refresh-eb-runtime` repairs existing EB Evidence Watch books
  that were created before the current MoonClaw runtime contract. It rewrites
  generated runtime artifacts (`moonclaw.jobs.json`, EB request/dispatch, EB
  watch contract, `raw/bootstrap/eb_extract_pdf_text.py`,
  `raw/bootstrap/eb_package_workbook.py`,
  `schemas/eb-tracking-output.schema.md`, and the importable MoonClaw proposal
  packet), writes/repairs the standalone `raw/bootstrap/EB_OPERATOR_PROMPT.md`
  plus `raw/analysis-runs/eb-prompt-contract.json` receipt, refreshes
  `wiki/methods/my-analysis-method.md` plus `wiki/methods/analysis-method.md`
  only when required EB lifecycle/source/workbook contract sections are
  missing, writes the bounded EB MoonClaw step limits (`timeout_ms: 300000` and
  `max_total_tokens: 48000`, `retry_max_attempts: 1`), backfills
  `wiki/evidence-matrix.md`, records
  `raw/analysis-runs/eb-runtime-refresh.json`, and rewrites stale
  `raw/analysis-runs/moontown-template-publish.json` plus
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipts so
  existing books preserve the EB output-contract handoff expected by the book
  verifier. It is run automatically before MoonClaw import/production proof.
  The refresh and production-proof paths also resync the global Moontown
  standing goal from the book-local registration receipt. If generated runtime
  or method-contract artifacts changed after an
  earlier import, production proof discards stale confirmed run ids, reports
  `not_proven_refreshed_runtime_requires_new_moonclaw_import`, and requires a
  new MoonClaw import from the refreshed packet.
- EB production proof execution is workflow-budget aware. The HTTP endpoint
  raises execution requests shorter than 900 seconds to the generated four-step
  EB profile budget, so the Moondesk wrapper no longer creates artificial
  orphaned runs by timing out before MoonClaw's per-step bounds can complete.
  The discovery step is now scoped to write
  `outputs/official-pdf-candidates.json` or an explicit failed candidate record
  instead of retrying the same broad official-site search.
  EB runtime generation also writes
  `raw/bootstrap/eb_discover_pdf_candidates.py`, a book-local official-source
  discovery helper that scans configured official websites for PDFs and HTML
  notice pages, classifies source kind, infers dates/codes when possible, and
  writes current-run `outputs/official-pdf-candidates.json` evidence.
  Active-universe production books no longer embed a dated current EB universe
  in `book.json`, the execution request, or the MoonClaw packet. If
  deterministic crawling cannot prove complete active-universe coverage, the
  helper writes `ai_discovery_required: true` and MoonClaw must use
  official-domain `web_search`/`web_fetch` to produce a complete candidate
  artifact before analysis. The old 2025-12-03 to 2026-06-03 EB source list is
  retained only as a regression fixture for tests that validate packaging and
  discovery behavior. Active-universe discovery must prove observed facts:
  `instrument_count`, `observed_instrument_codes`, `source_kind_counts`,
  `fact_based_universe_evidence: true`, `universe_evidence_basis`,
  `universe_evidence_sources`, `ai_discovery_required: false`, and
  `discovery_completeness_ok` before analysis. Counts may guide review, but
  they are not minimum/maximum readiness gates. It also writes
  `raw/bootstrap/eb_extract_pdf_text.py`, a
  book-local helper used by the extract/source-screen step to turn downloaded
  `raw/pdfs/*.pdf` files and `raw/html/*` source pages into
  `raw/extracted/*.txt` plus a terminal `outputs/official-source-screen.json`.
  It also writes
  `raw/bootstrap/eb_package_workbook.py`, which packages accepted official
  source records into the required workbook, sidecars, run result, durable
  candidate artifact, and durable source-screen artifact from either the
  book root or `moonclaw-jobs/<run>` workspace. MoonClaw now has a structured
  AI extractor contract at `outputs/eb-indicator-extraction.json`; the packager
  consumes those AI facts only as source-backed fallbacks for missing Sheet 2
  metrics, requiring a value, official source URL/path, and snippet matched to
  extracted official text. The MoonClaw EB profile and packet now
  set `best_effort_on_missing_input: false`, so missing extraction input must
  produce a failed evidence artifact rather than a prose-only continuation.
- Production official-source screens now require durable source evidence
  records, not just counters. At least one official-domain source record must
  prove download and extraction with a PDF path/hash or HTML/source path/hash
  plus extracted-text hash/path, and the referenced book-local `raw/pdfs/`,
  `raw/html/`, and `raw/extracted/` files must exist before the production
  source-screen gate can pass.
- Moondesk also performs a best-effort all-book standing-goal repair before town
  progress, analytics, calendar, standing-goal reads, and dispatch. Missing
  receipts on stale explicit PDF-watch draft books are reported as skipped
  books, not endpoint failures, so valid registered books still rehydrate. Plain
  `research-book` workspaces without a PDF-watch specialization are ignored.
- `GET /api/books/run-health?book_id=<id>` verifies the durable execution
  surface for an EB watch book after a run. It does not pass until Moondesk can
  see the standing-watch identity, watcher ledger update, MoonClaw-style result,
  `.moontown/book-results` acceptance, non-placeholder EB workbook, accepted
  `.xlsx.manifest.json` output contract, matching workbook `xlsx_sha256`,
  required OOXML workbook package parts, extracted workbook XML containing the
  required EB sheet names, headers, frozen header panes, filters, custom column
  widths, and bold header styling, official source screen, and final output
  gate together. It also reports
  `moonclaw_import_receipt_ready`, the latest
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipt path,
  `standing_goal_registration_ready`, `global_standing_goal_ready`, the latest
  `raw/analysis-runs/eb-production-proof.json` receipt status when an explicit
  proof attempt has run, and `production_ready`; the latter remains
  false for deterministic sample runs because it requires a live imported
  MoonClaw result plus a confirmed MoonClaw `run_id`, a succeeded persisted
  MoonClaw run meta record, clean import/launch stderr, and a production
  official-source screen proving live fetch/extract with official-domain URLs,
  `live_fetch_performed: true`, positive `downloaded_pdf_count`, and positive
  `extracted_pdf_count`. Moondesk also accepts equivalent structured source
  records with official URL fields plus successful download/extract status, and
  requires their `raw/pdfs/` and `raw/extracted/` paths to exist in the
  MoonBook. It rejects third-party repost URLs even when the numeric counters
  are present.
  The workbook validation sidecar must prove the prompt-required appendix notes
  are present: search keywords, retrieval date, and an official source list.
  Non-sample workbook validation must also include `workbook_data_proof` with
  positive announcement-table, indicator-table, and official-source-backed row
  counts, and the workbook OOXML must contain non-header rows in both required
  sheets, so a header-only starter workbook cannot pass production proof.
  It must also prove workbook QA: official-link-only rows, clickable source
  URLs, actual workbook OOXML hyperlink relationships for Sheet 1 original-link
  cells, summaries within 200 characters, emphasized key data,
  issuer/underlying cross-verification, disclosure-timing checks, Sheet 1 /
  Sheet 2 data reconciliation, missing-disclosure marking, and readable Excel
  formatting. The same `appendix_notes`, `quality_proof`, and
  `lifecycle_stage_proof` requirements are now carried in the MoonClaw handoff
  packet, not only enforced after output reconciliation.
  It also rejects accepted workbooks whose filename/manifest bond code and name
  do not match a configured production EB target, preventing a real target
  configuration from passing with the sample `132001 / 示例EB` workbook.
  The response now includes a `production_checklist` array with stable
  requirement/evidence rows for the book contract, EB target config, standing
  goal, MoonClaw import/run/web-tool contract/stderr, live result, watcher update, accepted
  book result, workbook/manifest/validation, appendix notes, quality proof,
  lifecycle proof, non-sample proof, source-backed workbook data rows plus
  actual workbook rows,
  workbook-to-target matching,
  official source screen, and final output
  validation.
  When a valid accepted workbook exists before Moontown has appended the
  watcher ledger or book-result record, run-health now falls back through
  `eb-output-validation.json` and the accepted workbook manifest to surface the
  output path, run id, source-screen path, workbook validation, hyperlink, data
  row, appendix, quality, lifecycle, and target-match proofs. This fallback does
  not mark the run durable or production-ready; it prevents a partially
  reconciled live run from being reported as if no workbook existed.
- `POST /api/books/moonclaw-import` imports the generated EB proposal packet
  through MoonClaw and writes
  `raw/analysis-runs/moonclaw-proposal-import.json` as the durable receipt. When
  called with `confirm: true`, it launches the MoonClaw run, mirrors
  `moonclaw-packets/eb-standing-watch-proposal.json.import.json` for Moontown,
  and writes `raw/analysis-runs/moontown-task-execution.json` with the
  `RunConfirmed` state when MoonClaw returns a run id. The receipt now preserves
  MoonClaw home/run metadata and stderr so Moondesk can report `Pending`,
  `WaitingForInput`, `Succeeded`, `Failed`, or a launch-stderr problem instead
  of treating any returned run id as healthy. Inline imports are also bounded by
  an API timeout and persist a `timed_out` receipt so the desktop cannot be held
  open by a long-running MoonClaw execution.
- `POST /api/books/moonclaw-run` executes the last confirmed EB MoonClaw run id
  through MoonClaw's `proposal run` path and writes
  `raw/analysis-runs/<run-id>-moonclaw-run.json` with command, timeout,
  stdout/stderr, run metadata, and current run health. The EB builder exposes
  this as `Run Confirmed MoonClaw`, which gives the desk a bounded recovery
  action when a detached launch leaves a confirmed run at `Pending` or
  `Running`. Run health now treats a clean, successful confirmed-run receipt as
  recovery from a noisy detached launch stderr; timed-out or failed confirmed
  receipts stay visible as blocking health states.
- `POST /api/books/eb-production-proof` gives the EB builder a single
  `Prove Production Run` action. It launches or reuses the confirmed MoonClaw
  run, executes it when needed, reconciles completed live output, refreshes
  production health, and persists
  `raw/analysis-runs/eb-production-proof.json` with the final proof level,
  run id, detailed receipts, and blockers. `GET /api/books/run-health` surfaces
  the same proof receipt path, status, proof level, run id, and failed checks so
  the latest proof attempt is visible without opening raw JSON. The verdict is `production_ready`
  only when the existing strict live gates pass; otherwise it records
  `not-proven_*` with the blocking checks. Production proof now preflights the
  persisted EB target scope. `active_universe` is valid with no configured
  bonds and drives dynamic official-source discovery plus the `ACTIVEEB`
  aggregate workbook; `single_bond` and `portfolio` still reject
  placeholder/sample targets, and each configured target needs a non-sample
  `132XXX` code, bond name, issuer, underlying listed company, and recognized
  exchange. The builder now exposes an explicit active-universe/single/portfolio
  scope switch, starts in active-universe mode for the EB pattern, sends
  `target_scope` in the create payload, shows target-readiness blockers only for
  configured-target modes, and keeps MoonClaw action buttons available for
  active-universe books. The sample `132001 / 示例EB` path stays available for
  deterministic packaging validation only.
- EB production health now also checks `moonclaw_web_tool_contract_ready`. The
  generated MoonClaw profile and proposal packet request executor/full runtime,
  `allow_execution_tools: true`, and required `web_search`/`web_fetch` tools.
  The generated EB profile uses the executor role `eb_pdf_evidence_worker`
  rather than MoonClaw's planner-only `controller` role, and carries the formal
  `metadata.role_runtime` / step `metadata.role_runtime` envelope that current
  MoonClaw resolves into execution-layer full-tool access. The generated
  proposal packet also uses absolute book-root paths so MoonClaw can import the
  durable MoonBook context instead of an empty run workspace.
  If a stale or detached MoonClaw run artifact reports planner-only/limited
  runtime or says web search/fetch was unavailable, the `moonclaw_web_tools`
  checklist item fails and `production_ready` remains false even when MoonClaw
  marked an intermediate step accepted.
- Latest live EB proof status on 2026-06-02: Moondesk refreshed the EB runtime,
  imported a new MoonClaw proposal for `G三峡EB1 / 132018`, confirmed run
  `run-20260602-135834-usersk`, and verified the MoonClaw web-tool contract as
  ready. The proof is still `not_proven_moonclaw_run_timed_out` because the
  confirmed MoonClaw run stayed `Running` past the bounded execution window, so
  no live result, Bookkeeper-accepted workbook, official-source screen, watcher
  ledger update, or Moontown book result exists yet. A later deliberately short
  retry smoke test timed out during proposal import before MoonClaw returned a
  replacement run id; run-health now recovers the previous confirmed run context
  from the production-proof health snapshot, reports
  `moonclaw_import_receipt_recovered: true`, and keeps the operator status at
  `moonclaw_run_orphaned_after_timeout` rather than collapsing to missing-run
  state. A later full forced retry confirmed replacement run
  `run-20260602-143345-usersk`, but its first `discover_official_pdfs` step
  stayed `Running` for the full 300000ms bounded execution window. Its
  MoonClaw tool journal records only session start with `web_search` and
  `web_fetch` enabled, and no live result, official-source screen, Bookkeeper
  acceptance, watcher ledger update, Moontown book result, or accepted workbook
  exists yet. A later 900000ms proof run
  `run-20260602-152356-usersk` also remained `not_proven`: its first
  `discover_official_pdfs` step eventually recorded a MoonClaw
  `best_effort_missing_input` continuation instead of durable PDF discovery,
  and did not let Moontown accept the result. Moondesk then refreshed the
  generated EB helpers, recovered official CNInfo PDF URLs from the MoonClaw
  step output, merged those URL-only discovery records with the downloaded
  `raw/pdfs/` and extracted `raw/extracted/` files, and produced
  `book/outputs/EB追踪_132018_G三峡EB1_20260602.xlsx` plus manifest,
  validation sidecar, official-source screen, official-PDF candidates, and
  `moonclaw-jobs/run-20260602-152356-usersk/result.json`. Run-health now shows
  the accepted workbook, source-screen, workbook data rows, official hyperlinks,
  appendix notes, quality proof, lifecycle proof, target match, and final
  output-validation gates as passing. After refreshing stale Moontown
  output-contract handoff receipts, run-health reports `durable_ready: true`
  with no durable failed checks and exposes `base_type_selection_ready`,
  `moontown_template_publish_receipt_ready`, and
  `standing_goal_registration_ready` as first-class health fields. The book is still not production-ready because
  MoonClaw metadata for the run is still `Running` after timeout, the discovery
  step used missing-input fallback, and the result is not from a clean live
  imported MoonClaw run. Production
  health now scans MoonClaw step records and rejects any best-effort
  missing-input fallback as evidence for discovery, extraction, analysis, or
  Bookkeeper acceptance. Run-health also expects
  `outputs/official-pdf-candidates.json` from the first discovery step, either
  with official-domain candidates or an explicit failed record with checked
  domains and a failure reason; this gives operators terminal discovery
  evidence before the stricter source-screen, Bookkeeper, and workbook gates can
  pass. Reconciliation now preserves that first-step artifact under
  `raw/analysis-runs/<run>-official-pdf-candidates.json`, so a partial MoonClaw
  run is inspectable from the durable MoonBook even when accepted output is not
  ready. The final `eb-output-validation.json` gate now requires this candidate
  evidence alongside the accepted workbook and source-screen artifact before
  reporting `accepted_output_ready`. It remains not production-proven.
- A bounded MoonClaw run timeout whose persisted MoonClaw metadata still says
  `Running` is now classified as `moonclaw_run_orphaned_after_timeout`.
  Run-health exposes `moonclaw_run_orphaned_after_timeout` and
  `moonclaw_run_retry_recommended`, and any production proof allowed to launch
  and execute now re-imports the packet to obtain a fresh run id instead of
  repeatedly executing the same abandoned confirmed run. The explicit
  `force_execute + launch_if_missing` retry uses the same abandoned-run path.
  If that retry import itself fails or times out before returning a new run id,
  Moondesk stores it separately as
  `raw/analysis-runs/moonclaw-proposal-retry-import.json` and preserves the
  previous confirmed import as canonical health evidence while skipping
  execution of the known-orphaned run id. For historical books already affected
  by a failed retry overwrite, run-health can recover from
  `eb-production-proof.standing_goal_sync.run_health` or the latest confirmed
  `raw/analysis-runs/*-moonclaw-run.json` receipt and exposes
  `moonclaw_import_receipt_recovered` plus `moonclaw_import_recovery_source`.
- EB run-health now preserves raw MoonClaw import stderr while tolerating the
  known successful-import Moon wrapper diagnostic
  `tcc: error: invalid option -- '--home'` as
  `moonclaw_import_stderr_tolerated`. The diagnostic is tolerated only when the
  import exits 0 and returns a valid proposal/run id; timeouts, failed confirmed
  runs, planner-only runtime artifacts, missing live results, and missing
  accepted XLSX output remain hard production blockers.
- `POST /api/books/moonclaw-reconcile` imports a completed live MoonClaw run
  into the book/town health surface only when the proposal import receipt,
  matching run id, succeeded MoonClaw meta, non-sample `result.json`, accepted
  workbook, accepted `.xlsx.manifest.json`, Bookkeeper acceptance, and a
  production official-source screen all pass. That screen must include
  official-domain URLs and prove live PDF download/extraction, so deterministic
  policy-only source screens cannot be promoted as production runs. The gate can
  read either top-level URL/counter fields or structured source records from
  MoonClaw output, and structured records must point to existing book-local PDF
  and extracted-text artifacts. The gate also accepts MoonClaw's final
  `package_result` wrapper when the step is accepted and the accepted workbook
  manifest belongs to the confirmed run id, which avoids falling back to stale
  watcher output when MoonClaw overwrites the helper-shaped `result.json`.
  Accepted runs append
  `.moontown/watchers/<goal>.jsonl`, write
  `.moontown/book-results/<run>.json`, copy the source-screen artifact into
  `raw/analysis-runs/`, refresh `eb-output-validation.json`, and can make
  `GET /api/books/run-health` report `production_ready: true`. Failed or
  partial runs write a reconciliation receipt and stay out of accepted
  knowledge. The EB Book Pattern Builder exposes this as `Reconcile MoonClaw
  Result`, so the operator does not need to call the JSON endpoint manually.
- `POST /api/books/accept-recovered-eb-output` is the explicit fallback for an
  EB book that already has a valid non-sample workbook, accepted manifest,
  hash-bound validation sidecar, production source-screen artifact, target
  match, and production-ready EB target config, but does not yet have a
  confirmed successful live MoonClaw lifecycle. It writes
  `moonclaw-jobs/<run>/result.json` with
  `kind: moonclaw-eb-recovered-accepted-output`, a Bookkeeper recovered-output
  review, refreshed `raw/analysis-runs/eb-output-validation.json`,
  `.moontown/watchers/<goal>.jsonl`,
  `.moontown/book-results/<run>.json`, and
  `raw/analysis-runs/<run>-accepted-output-recovery.json`. Run health can then
  report `durable_ready: true`, but `production_ready` remains false because
  recovered outputs are deliberately excluded from the live MoonClaw result
  gate. The EB Book Pattern Builder exposes this as `Accept Recovered Output`.
- The EB Book Pattern Builder also exposes `Audit Production Health`, which
  calls `GET /api/books/run-health` directly and summarizes the exact durable
  and production blockers after a detached MoonClaw run. This is a visibility
  control only; production readiness still requires a live official-source
  MoonClaw result, non-sample workbook validation, Bookkeeper acceptance, and
  the source-screen gates above.
- The same builder now preserves the backend `production_checklist` and
  `production_proof_*` fields after import, run, reconcile, sample validation,
  proof, and audit actions. It renders a compact Production Audit panel with
  the proof receipt path, proof level, run id, latest proof blockers, and every
  durable evidence row, so an operator can see which file or
  Moontown/MoonClaw artifact proves each production gate. The panel also shows
  the accepted workbook, workbook validation sidecar, official source screen,
  book result, MoonClaw result, and final output-validation status directly
  from run health. When run health reports a recovered import or orphaned
  timeout, the panel exposes the effective MoonClaw import run id/status,
  recovery source, retry-import receipt, and retry recommendation, then offers
  `Fresh Retry Orphaned Run` to call the forced production-proof path without
  making the operator edit JSON or reuse an abandoned run manually.
- `GET /api/books/run-health` now performs the same book-local
  standing-goal-receipt repair before returning EB health. This keeps the
  Moontown global `.moontown/standing-goals.json` handoff visible when a
  Moontown maintenance pass rewrites the scheduler file and drops non-core
  goals; the EB health response and the file itself now return
  `global_standing_goal_ready: true` after the audit read.
- The Town request ledger now normalizes both regular Moondesk request records
  and book-pattern handoff records into the UI's stable
  `{id,status,path,request}` shape, so publishing a specialized EB watch book
  does not make the request list show `Invalid request ledger`.
- `POST /api/books/from-pattern` can publish a PDF Evidence Watch or
  Exchangeable Bond Evidence Watch research book, register it in
  `.moontown/moonbooks.json`, create the Moontown standing goal using the
  latest `watch-<book-id>-pdfs` identity, write a
  strict latest-Moontown `PdfEvidenceWatchInstallSpec` at
  `.moontown/book-template-configs/<book>.json` plus an
  `installed` `.moontown/book-template-requests.json` request/event,
  `raw/analysis-runs/moontown-template-publish.json` receipt, and
  `raw/analysis-runs/moontown-standing-goal-registration.json` receipt. It accepts explicit
  `book_id`, `base_type`, `purpose`, `skill_pack`, websites, cadence, source
  policy, and notification rules, and rejects incompatible base/pattern pairs;
  currently both supported patterns require `research-book`. The generated `book.json`
  keeps the latest reusable Moontown template shape and now records
  `base_type_provenance`, binding the `research-book` base to MoonBook layout
  refs and Moontown template-registry refs. The publish receipt preserves the
  same provenance. Moondesk also writes
  `raw/analysis-runs/base-type-selection.json`, proving the base was selected
  from `/api/books/base-types` before the PDF/EB watch pattern was layered on,
  and contract verification fails if either the provenance or this receipt is
  dropped.
  The generated shape includes `book_type: research-book`,
  `specialization: pdf-evidence-watch`, `watch.cadence_minutes`,
  `watch.file_types`, `watch.dedupe_by`, `watch.notify_on`, schema pointers,
  and the operator method at `wiki/methods/my-analysis-method.md` with a
  compatibility copy at `wiki/methods/analysis-method.md`. The latest local
  `../moontown/templates/books/templates.json` still advertises
  `pdf-evidence-watch` as a specialized `research-book`, and also adds an
  unrelated `app-tool-book` / `toolbook` template; Moondesk surfaces that base
  in the catalog but continues to treat PDF Evidence Watch as a reusable
  research-book pattern rather than a civic/toolbook. If an EB operator
  method is shorter than the required contract, Moondesk preserves it and
  appends the mandatory official-source, six-stage lifecycle, missing-marker,
  and two-sheet workbook requirements. Generic PDF-watch books keep
  `targets.target_count` at `0`; EB books now carry explicit `target_scope`.
  Active-universe EB books keep `target_bonds` empty and discover the official
  source universe dynamically; configured single/portfolio books accept
  `target_bonds` and carry the same target list through `book.json`,
  `raw/inbox/eb-tracking-request.json`,
  `raw/inbox/eb-standing-watch-dispatch.json`, and
  `moonclaw-packets/eb-standing-watch-proposal.json`. For EB, it also creates
  `moonclaw.jobs.json`,
  `raw/analysis-runs/moonclaw-proposal-import.json` after the operator imports
  the packet,
  `raw/bootstrap/EB_WATCH_CONTRACT.md`,
  `raw/bootstrap/EB_OPERATOR_PROMPT.md`,
  `raw/analysis-runs/eb-prompt-contract.json`,
  `raw/analysis-runs/eb-contract-verification.json`, and
  `raw/analysis-runs/eb-output-validation.json`, plus the starter workbook
  `book/outputs/EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`. The validation
  reports `template_ready_waiting_for_accepted_output` until a non-placeholder
  workbook with a valid `moondesk.exchangeable_bond_tracking.xlsx.v1` manifest
  whose `xlsx_sha256` matches the workbook bytes, real OOXML workbook parts
  exist, and extracted workbook XML contains the required `公告追踪主表` /
  `关键指标监控表` sheet names, header strings, frozen header panes, filters,
  custom column widths, bold header styling, and official-domain hyperlink
  relationships for Sheet 1 `原文链接` cells, plus validation-sidecar
  source-backed data-row proof, appendix notes, quality proof, and six-stage
  lifecycle proof,
  `accepted_output_waiting_for_source_screen` when that workbook exists
  without durable official-source screening, and `accepted_output_ready` only
  when both the workbook manifest and
  `raw/analysis-runs/*-official-source-screen.json` are present and valid.
  Production reconciliation is stricter than this output-readiness gate: it
  rejects source screens without live fetch/extract proof.
- `POST /api/books/eb-sample-run` runs a deterministic EB packaging validation
  for an existing EB watch book. It writes a MoonClaw-style run workspace under
  `moonclaw-jobs/`, a deterministic official-source screen artifact, an extracted
  source-screen note, a Bookkeeper review note, a watcher ledger row, a town
  result message, and a non-placeholder
  `EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx` workbook plus accepted output
  manifest, then returns `run_health.status=durable_output_ready` when all
  durable artifacts agree.
  This verifies packaging and handoff durability without claiming live official
  source evidence collection.
- `GET /api/agents/daemon`, `GET /api/agents/models`, and
  `GET /api/agents/sessions?workspace=...` return MoonClaw agent state.
- `POST /api/agents/sessions` starts a book-scoped MoonClaw task and sends the
  initial message.
- `POST /api/agents/sessions/:id/message` sends a follow-up contextual message.
- `POST /api/agents/sessions/:id/cancel` cancels active MoonClaw task work.
- `GET /api/town/calendar.ics` returns a valid calendar payload.
- `POST /api/town/daemon/start` starts the Moontown daemon.
- `POST /api/town/daemon/stop` stops it and final status reports `running:
  false`.
- Running `open Moondesk.app` from outside the repo opens the native window,
  starts `Contents/MacOS/moondesk-host`, serves bundled UI resources, and can
  still reach the configured workspace root.
