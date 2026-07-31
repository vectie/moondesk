# MoonDesk Product Plan

The canonical model is in
[Executable Book Architecture](EXECUTABLE_BOOK_ARCHITECTURE.md). MoonDesk is a
native human workspace for one selected executable MoonBook at a time.

```text
MoonBook = durable executable book
MoonWiki = MoonBook functionality for editing what the book says
Bookkeeper = MoonBook role for outcome closure and reviewed Three-Gap learning
MoonCode = MoonClaw role/profile for editing what the book can do
MoonFind = discover evidence and author desired-capability graph intent
MoonFlow = validate, schedule, execute, reconcile and recover durable work
MoonTown = coordinate books and produce reviewable cross-book synthesis
MoonClaw = sole agent runtime for bounded runs and role sessions
MoonLib = define shared MoonSuite filesystem contracts
MoonGate = resolve exact capability/authority and report contract drift
```

## Thesis

MoonDesk should feel like a local research/coding studio: book files on the
left, active work in the center, run/context state on the right, and durable
outputs at the bottom. It is a shell and projection layer, not another runtime.

## Core User Flow

1. Select or create a MoonBook.
2. Work in MoonWiki for prose, evidence, methods, reviews, and generated pages.
3. Switch to MoonCode for interactive coding/chat on the same book.
4. Inspect MoonFind-authored graph intent and select only declared,
   catalog-compatible work.
5. Let MoonFlow validate, schedule, execute, reconcile, and recover the durable
   Work graph through exact MoonGate authority.
6. Let MoonClaw execute bounded agent work and emit evidence; use MoonTown for
   civic coordination and reviewable cross-book synthesis.
7. Review proposals through MoonBook's Bookkeeper before they become durable
   book truth.
8. Separately authorize any publication, trading, physical command, or policy
   activation.

## Non-Goals

- Do not hardcode domain-specific research workflows into MoonDesk.
- Do not make MoonDesk own the MoonClaw runtime or model loop.
- Do not make MoonDesk the graph author or orchestration state owner.
- Do not hide MoonFind, MoonFlow, MoonGate, MoonBook, MoonTown, MoonClaw, and
  Bookkeeper ownership.
- Do not treat MoonWiki, MoonCode, MoonMini, or MoonStat as callable active
  products.
- Do not make MoonGate the source of truth for filesystem contracts; shared
  MoonSuite layout contracts belong in MoonLib.
- Do not keep obsolete routes after the current contract replaces them.
- Do not expose platform concepts as the primary navigation when Book, Wiki,
  Code, Run, Review, and Publish are clearer.

## Product Surfaces

### Desk

- discover configured roots and `books/*`
- project MoonBook-owned virtual filesystem sections before raw host folders
- show `wiki/`, `raw/`, `skills/`, `schemas/`, `tools/`, `apps/`,
  `site/generated/`, `book/site/generated/`, and review/output paths
- keep file operations scoped to the selected workspace
- test Desk as the primary file explorer surface with the end-to-end strategy in
  [Desk Mode Test Plan](DESK_MODE_TEST_PLAN.md)

### Preview

- preview markdown, HTML, JSON, images, text, directories, and generated sites
- serve raw files and generated assets through scoped local routes
- keep markdown/source views recoverable after opening sites or tool apps

### Inbox

- create notes
- import dropped, pasted, selected, URL, or data-url files
- stage user-provided inputs into book-local paths before promotion

### MoonWiki

- edit human-language book material
- manage methods, sources, findings, reviews, and generated pages
- create reusable book patterns such as PDF Evidence Watch without embedding a
  domain-specific pack
- test Wiki as the forward/backward MoonBook knowledge workflow with the
  end-to-end strategy in [Wiki Mode Test Plan](WIKI_MODE_TEST_PLAN.md)

### MoonCode

- start and resume book-scoped coding sessions
- send typed prompt, steer, cancel, test, build, eval, package, accept, and
  reject commands
- show transcript, runtime stream, tool calls, diffs, test results, packages,
  readiness, and review controls
- package accepted outputs as MoonBook-owned tools, miniapps, generated sites,
  or portable app-tools

### Town

- show standing goals, request ledger, town messages, progress, review queue,
  and notifications
- submit recurring or one-shot book work to MoonTown
- keep book-to-book communication, participant synthesis, challenges, and idea
  routing visible
- leave executable scheduling and restart recovery to MoonFlow

### Flow

- render MoonFind-authored `moonsuite.work-model.v1` items without copying a
  product list into MoonDesk
- show exact operation/schema refs, requested authority, required claim,
  acceptance criteria, artifacts, timeout, adapter claim ceiling, review
  requirement, health evidence, catalog identity, and validation status
- retain a source-bound, dependency-closed composition overlay
- delegate catalog-backed validation and conformant import to MoonFlow
- pin and retain the exact catalog snapshot, validation report, and import
  receipt used for a run
- present run state, evidence, review, controls, and recovery without becoming
  the durable scheduler or runtime
- derive continuation from graph dependencies and MoonFlow runnable state,
  never from a hardcoded product list
- fit and navigate large graphs without assuming a fixed canvas extent

### Daemon And Native Shell

- run as a native window app
- supervise the local MoonDesk host and configured MoonClaw/MoonTown daemons
- expose LaunchAgent/install/status controls where appropriate
- keep browser development in `serve`/`desktop`; app packaging is Lepusa-only

## Data Contracts

Keep MoonDesk-facing records small and stable:

```text
DeskWorkspace
  id, name, root_path, kind, status

DeskFileEntry
  workspace_id, path, display_name, kind, source_layer, readable, writable

DeskPreview
  renderer, title, body, metadata, warnings

DeskRunProjection
  run_id, book_id, goal_id, status, phase, summary, artifacts

MoonCodeSessionProjection
  id, workspace_id, title, status, events, summary, readiness, artifact paths
```

Detailed protocol contracts belong in [MoonCode Workspace](MOONCODE.md) and
package-generated `.mbti` files. The code-mode end-to-end testing strategy is
tracked in [Code Mode Test Plan](CODE_MODE_TEST_PLAN.md).

MoonSuite filesystem contracts belong in MoonLib. MoonDesk should use MoonLib
for suite root discovery, product registry records, product-home paths, suite
temp paths, and book path construction. During migration, local helpers may
exist only as thin adapters over MoonLib. MoonGate should consume the same
MoonLib contracts to audit workspace health and legacy-path drift; it should
not define the contract.

Contract ownership rule: any MoonSuite path, registry, manifest, artifact
class, or book-root constructor that more than one product needs must be added
to MoonLib first. MoonGate may validate that the constructor is being followed,
report drift, and project health/status, but it must not become a required
dependency for products that only need filesystem contracts.

## Permission Model

- reads stay under configured roots
- writes stay under selected book/workspace roots
- imports land in inbox/staging first
- workflow execution and recovery are delegated to MoonFlow
- bounded agent execution is delegated to the sole MoonClaw runtime
- cross-book synthesis and civic coordination are delegated to MoonTown
- accepted durable truth requires MoonBook Bookkeeper review
- destructive actions require explicit operator intent
- publication, trading, physical effects, and policy activation require
  separate authority

## Engineering Bar

MoonDesk is good when it is boring to operate:

- boundaries are visible and hard to confuse
- graph nodes and continuation actions come only from the Work graph and
  compatible catalog, never a hardcoded product inventory
- MoonSuite paths come from the shared MoonLib contract layer
- MoonGate resolves exact capability/authority and observes MoonLib contract
  compliance instead of owning path schemas
- stale domain packs live outside the desktop core
- generated app-tools can leave MoonDesk as standalone artifacts
- native app startup, preview, routing, and daemon controls are reliable
- MoonCode can be extracted without dragging MoonWiki or desktop code with it
- tests cover protocol contracts, routing, packaging, preview, and runtime
  handoff behavior

## Current integration reference

The locally validated MoonFind humanoid-robotics graph contains 63 stages, 43
unique exact operations, 63 typed primary requests, and 11 domain-product
owners: MoonBook, MoonCast, MoonChat, MoonClaw, MoonFind, MoonMold, MoonMoon,
MoonProj, MoonRobo, MoonTown, and MoonVis. MoonFlow, MoonGate, and MoonLib are
support-plane dependencies. MoonFish remains a separate finance domain.
MoonMini and MoonStat are absent.

This reference proves local typed compatibility, not deployment readiness.
Production still needs live unexpired adapter health, real credentials,
licensed providers and data, named reviewers, media rights, customer
acceptance, calibrated robotics simulation, safety evidence, and explicit
external/physical authority.

Use [STATUS.md](STATUS.md) for current implementation state and
[ROADMAP.md](ROADMAP.md) for milestone tracking.
