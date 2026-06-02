# Moondesk

Moondesk is a pure MoonBit desktop host and Rabbita UI for browsing MoonBook
workspaces, staging inbox notes, submitting selected context to Moontown, and
inspecting MoonClaw run artifacts.

Current milestone slice:

- workspace explorer, previews, raw links, search, favorites, and inbox
  writes/imports
- Moontown request ledger, standing-watch creation, town messages, and one-shot
  daemon tick dispatch
- book pattern publishing: exposes a 7-step PDF Evidence Watch wizard, selects
  the Moontown-discovered base type catalog, and creates
  reusable specializations such as PDF Evidence Watch and Exchangeable Bond
  Evidence Watch with explicit book id, purpose, source websites, cadence,
  notification rule, and selected skill pack,
  reads the Moontown template registry for available base types, patterns, install examples,
  editable files, and required template assets,
  materializes the EB analyst prompt into durable
  `raw/bootstrap/EB_OPERATOR_PROMPT.md` and
  `raw/analysis-runs/eb-prompt-contract.json` artifacts, then mirrors it into
  the generated method/skill files with the official-source priority list, six
  lifecycle stages, quality rules, required workbook headers, and execution
  directive,
  the operator-owned `wiki/methods/my-analysis-method.md` page, local
  `raw/inbox/pdf-evidence-watch-config.json` nested watch/analysis config,
  durable `raw/analysis-runs/base-type-selection.json` proof that Moondesk
  selected the `research-book` MoonBook base from `/api/books/base-types`,
  exact PDF Evidence Watch layout metadata for `raw/inbox/`, `raw/pdfs/`,
  `raw/extracted/`, `raw/analysis-runs/`, `wiki/`, `skills/`, `schemas/`, and
  `site/generated/`,
  durable MoonBook `wiki/evidence-matrix.md`, `pdf-watch`/`pdf-analysis` skills, schemas, generated site, MoonBook catalog
  entry, EB single-bond or multi-bond target fields in the MoonClaw execution
  request, a workspace-local
  `moonclaw.jobs.json` profile plus importable MoonClaw proposal packet, an EB
  standing-watch dispatch packet, the required watch-marker contract, Moondesk
  handoff, a normal Moontown standing goal using the latest
  `watch-<book-id>-pdfs` identity, an installed Moontown template request plus
  strict `PdfEvidenceWatchInstallSpec` config/publish receipt, a durable
  Moontown standing-goal registration receipt,
  publish receipts that prove the owner split, reusable
  `research-book + source adapter + extractor + analysis skill + standing watch`
  contract, and accepted-new-knowledge-only notification rule,
  contract verification record, output-readiness gate with an official-source screen
  requirement, accepted EB `.xlsx.manifest.json` output-contract,
  hash-bound `.xlsx.validation.json` sidecar contract carried through the
  execution request, Moontown dispatch, and MoonClaw proposal packet,
  sheet/header validation, generated schema coverage for
  manifest/validation/source-screen proof artifacts,
  appendix-note proof for search keywords/retrieval date/source list,
  workbook data-row proof for source-backed rows in both required sheets,
  actual workbook hyperlink checks for official original-link cells,
  workbook quality proof for official-link-only rows, clickable source URLs,
  summaries within 200 characters, emphasized key data, cross-verification,
  timing checks, data reconciliation, missing-disclosure marking, and readable
  Excel formatting, lifecycle-stage proof that all six EB stages were reviewed
  or explicitly marked missing, and
  workbook-hash validation plus extracted workbook XML checks for the required
  EB sheet names, headers, frozen header panes, filters, custom column widths,
  bold header styling, and official-domain hyperlink relationships,
  a durable run-health audit over watcher/result/run/output artifacts with a
  stable production checklist of requirement/evidence rows, visible base-type
  selection and Moontown handoff receipt readiness, and
  workbook-to-target matching plus MoonClaw proposal import receipts, confirmed MoonClaw run
  launch, bounded confirmed-run execution/recovery receipts,
  a one-click EB production-proof receipt that launches/reuses a confirmed run,
  reconciles, audits, and records `production_ready` versus `not-proven`
  blockers, surfaces the latest proof attempt in run-health, and includes
  production target-readiness preflights in the builder,
  executor/full MoonClaw runtime metadata with required `web_search` and
  `web_fetch` tools plus a `moonclaw_web_tools` production checklist gate that
  rejects stale planner-only or web-tool-blocked runs,
  an EB runtime refresh route for existing books that rewrites only generated
  MoonClaw request/dispatch/profile/packet artifacts, repairs the standalone EB
  operator prompt and prompt-contract receipt, repairs the durable
  `raw/analysis-runs/eb-expected-output-contract.json` workbook contract,
  repairs stale Moontown publish/standing-goal output-contract handoff receipts,
  repairs missing canonical EB method-contract sections without deleting operator text, and resyncs the
  Moontown standing goal before import or production proof,
  MoonClaw import/run routes, and proof route that reject the default
  `132001 / 示例EB` sample target before live MoonClaw execution,
  Moontown-compatible packet-side import receipts and task execution
  receipts, MoonClaw run-meta/stderr health checks, timeout-bounded inline
  import receipts, strict reconciliation of completed live MoonClaw run outputs,
  including MoonClaw's final `package_result` wrapper shape, into
  watcher/book-result health only after the workbook, run-id-matching manifest,
  official-source screen with live fetch/extract proof from the generated
  `raw/bootstrap/eb_discover_pdf_candidates.py` official-seed materializer and
  `raw/bootstrap/eb_extract_pdf_text.py` pypdf helper plus existing book-local
  `raw/pdfs/` and `raw/extracted/` artifacts, final workbook packaging through
  `raw/bootstrap/eb_package_workbook.py`, and run metadata pass through a
  desk action, an `Accept Recovered Output` action that records an already
  validated non-sample EB workbook/source-screen package into durable
  watcher/book-result ledgers while keeping `production_ready` blocked until
  live MoonClaw lifecycle proof exists, a
  deterministic EB output validation run against the expected-output contract,
  and an EB starter workbook with the
  required two-sheet XLSX structure
- managed background daemon lifecycle: start, stop, restart, status, and
  desired-state supervision
- scoped Finder reveal through the host API
- saved views, selected-path tags, live Moontown/MoonClaw progress, daily
  cadence calendar, ICS export, and outcome analytics for standing goals and
  watcher decisions
- MoonBit-only `desktop`, `bundle`, `release`, and `launch-agent` commands; the
  default app bundle uses a native AppKit/WebKit window plus an internal MoonBit
  host, with no Tauri/Rust app shell

See [`docs/STATUS.md`](docs/STATUS.md) for the current completeness assessment.
Short version: it is a usable local single-user alpha with native window
ownership in the generated macOS app bundle; production distribution still
needs a credentialed release channel.

Run locally:

```bash
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

Create the signed self-contained native-window macOS app bundle:

```bash
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199
```

Create a release manifest/notarization submission when credentials exist:

```bash
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out dist --port 4199 --notary-profile <profile>
```
