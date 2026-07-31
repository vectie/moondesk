# MoonDesk Architecture

The graph-first cross-product control surface is specified in
[`SUITE_COMPOSITION_CANVAS.md`](SUITE_COMPOSITION_CANVAS.md). MoonDesk persists
only a generic, source-bound composition overlay. MoonFind owns the discovery
and desired graph, MoonFlow executes the conformant Work graph, MoonGate
resolves capability and authority, and product packs retain all domain
semantics.

See [Executable Book Architecture](EXECUTABLE_BOOK_ARCHITECTURE.md) for the
canonical product boundary: MoonBook is the executable book, MoonDesk is the
desktop shell, MoonClaw is the sole agent runtime, MoonFlow owns workflow
execution, and MoonTown coordinates books. See
[Desk Mode Design](DESK_MODE_DESIGN.md) for the current UI decision: Desk is
the read-only virtual filesystem mode, while MoonWiki and MoonCode are
activities on the selected book/path context.

MoonSuite filesystem contracts are a shared foundation owned by MoonLib.
MoonGate consumes those contracts to resolve exact capability and authority and
to report workspace health and legacy-path drift; it does not define
product-home or book-layout paths.

## Phase 5 security boundary

Canonical path, route-authority, generated-content, archive-import, and durable
action-receipt guarantees are specified with owning code and gate commands in
[`PHASE5_SECURITY_EVIDENCE.md`](PHASE5_SECURITY_EVIDENCE.md).

## Boundary

MoonDesk is a desktop shell over existing Moon workspaces. It should not absorb
the responsibilities of the other projects.

```text
MoonDesk
  human control and hosting surface, file browsing, preview, editing, inbox,
  review, pack-app hosting, graph selection and run inspection

MoonBook
  durable executable book, MoonWiki functionality, Bookkeeper, source files,
  history, review queue, accepted knowledge

MoonFind
  discovery, evidence intake, desired-capability graph and canvas intent

MoonFlow
  graph validation, scheduling, execution, reconciliation and restart recovery

MoonTown
  civic coordination, cross-book communication, reviewable synthesis,
  standing goals, notifications and town state

MoonClaw
  sole agent runtime, role profiles including MoonCode, workers, tools,
  bounded execution, artifacts and logs

MoonLib
  shared suite root, product registry, product-home, temp, and book path
  contracts

MoonGate
  exact capability/authority resolution, claim ceilings, health projection,
  metrics and contract-drift audits
```

MoonDesk treats the selected book as a desk-centered workspace:

```text
Desk
  browse MoonBooks, directories, files, source layers, and metadata

MoonWiki
  read/edit/preview/review MoonBook-owned durable knowledge

MoonCode
  MoonClaw role/profile for creating, modifying, testing, and packaging
  executable book code
```

## Source Ownership

| Concern | One owner | Boundary / primary source |
| --- | --- | --- |
| Desk/file APIs | MoonDesk | `internal/moonwiki/` host routes, adapters, and scoped file IO |
| Wiki projection | MoonDesk | `internal/moonwiki/` and the MoonWiki UI project durable book state without owning it |
| Code presentation | MoonDesk | `internal/mooncode/` adapters and the MoonCode UI present MoonClaw activity |
| Host/CLI/release | MoonDesk | `cmd/main/` owns serving, desktop launch, bundle, release, and LaunchAgent actions |
| Shared DTOs | MoonDesk | `core/` owns product-neutral desktop records and host-facing DTOs |
| Shared helper primitives | MoonDesk | `internal/mooncore/` owns reusable JSON, record-file, session, and transcript helpers |
| Durable book truth | **MoonBook (external)** | Book files, history, review queue, accepted knowledge, and generated artifacts |
| MoonWiki and Bookkeeper | **MoonBook (external)** | Human-language knowledge functionality, acceptance policy, outcome closure, durable receipts, and reviewed Three-Gap proposals |
| Discovery and canvas intent | **MoonFind (external)** | Research discovery, desired-capability graph, typed requests, and reviewable topology |
| Workflow execution | **MoonFlow (external)** | Graph validation, scheduling, durable execution, reconciliation, and restart recovery |
| Agent execution | **MoonClaw (external)** | Sole agent loop/runtime, role profiles, workers, tools, bounded execution, artifacts, and logs |
| Civic/cross-book coordination | **MoonTown (external)** | Standing goals, messages, notifications, participant-book synthesis, and coordination state |
| Shared paths | **MoonLib (external)** | Suite root, product registry/home, temporary, and book path contracts |
| Capability and authority | **MoonGate (external)** | Exact operation resolution, authority policy, claim ceilings, health projection, metrics, and contract-drift audits |

Cross-product owners in bold are external to MoonDesk. This table assigns a
single accountable owner without moving product boundaries or implying that
MoonDesk owns the external products it projects.

The UI implementation lives in `ui/rabbita-desk/main/` and covers Desk, Files,
Search, Inbox, MoonWiki, MoonCode, Town, Runs, and Settings surfaces.

MoonDesk path construction should call the MoonLib MoonSuite contract package
instead of carrying product-local string helpers for `.moonsuite`, `.tmp`,
`books`, or product registry paths. During migration, local helpers may remain
only as thin compatibility adapters over MoonLib.

MoonCode is intentionally a MoonClaw role/profile, not a standalone runtime or
product. MoonDesk renders the native shell and review surfaces, MoonClaw owns
the agent loop and tool execution, and MoonBook owns generated code/artifacts.
See [MoonCode Workspace](MOONCODE.md) for the contract.

## Cross-product graph boundary

MoonDesk accepts only the selected book's `flow/work-graph.json` when it
declares `moonsuite.work-model.v1`. The reviewable MoonFind
`flow/desired-graph.json` remains a distinct intent artifact.

The executable graph is inspected against a
`moonflow.capability-catalog.v1`, resolved from the explicit
`MOONFLOW_CAPABILITY_CATALOG` override or the selected book's
`flow/capability-catalog.json`. The desktop presents canonical operation and
schema references, requested authority, required claim, acceptance criteria,
primary artifacts, timeout, adapter claim ceiling, review requirement, health
evidence, catalog identity, and validation status. It never creates an
operation from a repository or product name.

The host persists a source-bound, dependency-closed composition overlay and
delegates `validate-work-graph-capabilities` followed by
`import-conformant-graph` to MoonFlow using the same catalog and evaluation
timestamp. It first pins the catalog by digest; selected and safely rebased
artifact references receive a deterministic compiled graph identity, revision,
and digest. The catalog snapshot, validation report, and import receipt are
durable under
`.moonsuite/products/moondesk/moonflow-imports/<digest>/`.

MoonFlow remains the durable state owner. Run controls delegate to MoonFlow's
`control` command, and absent persisted autonomy, intervention, or control
evidence stays unavailable in the UI. MoonGate remains the exact
capability/authority policy plane. External publication, trading, physical
commands, and learning-policy activation remain separately authorized.

## HTTP Surface

The host exposes scoped local routes. Important families:

- `/api/workspaces`, `/api/workspaces/:id/*`: workspace discovery, file lists,
  previews, raw files, edits, search, tags, saved views, and imports.
- `/api/town/*`: MoonTown requests, standing goals, progress, events, review
  queue, analytics, and daemon coordination.
- `/api/books/*`: base-type/pattern registry, PDF Evidence Watch creation,
  standing-goal sync, template registry reads, and portable app-tool export.
- `/api/mooncode/*`: seven-route-family desktop projection for status,
  capabilities, active/archived session listing and creation, selected-session
  reads/watches, command submit, and lifecycle mutation. MoonClaw remains the
  session, journal, conversation, title, and archive owner.
- `/api/moonclaw/*`: MoonClaw daemon/model status needed by the MoonCode UI.
- `/api/daemon/*`: local MoonDesk daemon and LaunchAgent lifecycle controls.

Domain-specific workflows should not add permanent first-class route families
inside MoonDesk. They should be exposed through book-local tools, MoonClaw
skills, app-tool manifests, or generic MoonCode/MoonWiki operations.

## Reusable Book Pattern

MoonDesk currently ships a generic PDF Evidence Watch creator:

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

MoonDesk writes the operator-facing config, method document, skills, schemas,
layout metadata, publish receipts, and standing-goal registration. MoonTown
coordinates the standing-goal request and notifications; MoonFlow owns any
durable executable schedule and recovery. MoonClaw performs bounded
fetch/extract/analyze work. MoonBook owns accepted durable knowledge and
generated outputs.

## Domain Packs

MoonDesk exposes installed domain packs through Pack Home. A pack appears as a
product card whether its app runtime is ready, missing, invalid, or intentionally
absent. "Open pack" enters the pack-owned Rabbita application; "Inspect current
composition" is an advanced route to the selected MoonBook's generic MoonFlow
graph. See [Pack app runtime discovery](PACK_APP_RUNTIME.md).

Domain-specific discovery workflows are experiments for testing information
discovery and app-tool generation. They are no longer built into MoonDesk.

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

MoonDesk can manage such a pack through generic book creation, file editing,
MoonCode sessions, MoonClaw execution, review surfaces, and portable export.
MoonDesk should not hardcode the pack's source list, target universe, workbook
schema, or validation rules.

Portable export has one generic detection rule: explicit `toolbook` /
`app-tool-book` manifests are preferred, and any book with a real
`app/index.html` can also be packaged as a standalone app-tool. This lets
generated tools leave MoonDesk cleanly without adding domain-specific product
code. Exported app-tools include `serve.py` and `run-local.command` so the
generated JavaScript runs from a served local origin instead of a fragile raw
`file://` open. The exporter discovers local assets referenced by generated
HTML, CSS, and JavaScript, including root-absolute `/assets/...` links,
side-effect imports, and `new URL(..., import.meta.url)` asset references, so
book-local tools do not need MoonDesk code changes just to ship their UI. The
portable runtime also handles generic read-only workspace file APIs such as
`/api/workspaces/<id>/raw?path=...`, `/file/...`, `/site/...`, and preview
requests by serving copied book files from the static bundle. Runtime file
resolution is relative to the injected portable runtime script, so the same
bundle works in MoonDesk's nested workspace-file iframe preview and under the
standalone static host. That keeps generated JavaScript tools usable after
export without adding domain-specific MoonDesk endpoints.
Generated app-tools that still call unsupported MoonDesk APIs are exported for
inspection, but they are not treated as launchable standalone apps. Their
portable manifest sets `auto_open_allowed: false`; the fix belongs either in
the generated pack or in the portable runtime, not in domain-specific
MoonDesk code.

## Native App

`cmd/main bundle` now defaults to the Lepusa-native host path. It creates
`MoonDesk.app` with:

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
