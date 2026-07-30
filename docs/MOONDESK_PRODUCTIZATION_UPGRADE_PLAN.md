# MoonDesk Productization Upgrade Plan

| Field | Value |
| --- | --- |
| Status | Program closed with a **Not ready** release decision; repository-owned work is implemented, but external distribution evidence, warning cleanup, and current hosted CI remain blockers |
| Owner | MoonDesk |
| Last updated | 2026-07-30 |

## Purpose

This plan turns MoonDesk from a capable local alpha into a coherent,
maintainable, and distributable desktop product without changing its product
boundary.

MoonDesk remains:

- the human desktop shell for MoonSuite
- the Finder-like workspace for MoonBooks
- the MoonWiki and MoonCode presentation layer
- the operator surface for MoonTown and MoonClaw
- the native host and portable app-tool packaging surface

MoonDesk does not become:

- a second agent runtime
- a second durable book store
- a second scheduler
- a domain-specific workflow host
- a generic shell with unrestricted authority

The program focuses on product clarity, typed contracts, package boundaries,
security, observability, release discipline, and operational proof.

## Assessment Translated Into Action

The review identified real strengths that should be preserved:

- explicit ownership boundaries between durable content, execution, scheduling,
  health, and presentation
- a local-first model with inspectable files and durable evidence
- broad integration across editing, coding, requests, runs, review, publishing,
  and native packaging
- a substantial test base and documented architecture
- a native desktop direction rather than a browser-only product boundary

It also identified the gaps that most affect trust and usability:

- first run exposes too much system topology before the user's book and task
- loading, empty, stale, unavailable, and failed states are not yet consistent
  across every primary surface
- some runtime boundaries still rely on strings or loosely structured JSON
- large ownership and compilation boundaries increase change risk
- filesystem confinement and generated-content authority need adversarial proof
- evidence is spread across surfaces instead of answering one operator question
- localization, keyboard operation, zoom, focus, and screen-reader behavior are
  not yet release-qualified
- local packaging is ahead of credentialed, clean-machine, update, rollback,
  and soak evidence

The phase order below is deliberate. It first establishes truthful evidence,
then fixes the user journey and delivery gate, then reduces contract and
ownership risk, and only afterward completes security, observability,
accessibility, and distribution qualification.

## Target Outcome

At the end of this plan, a new user should be able to install MoonDesk, open or
create a MoonBook, understand the available work surfaces, and complete a
useful Wiki or Code task without learning the internal MoonSuite topology.

A contributor should be able to identify the owning package for a change,
understand the public contract from generated interfaces, run one documented
quality command, and receive the same result in CI.

An operator should be able to distinguish:

- durable book state from projected runtime state
- current work from stale or disconnected state
- evidence-backed progress from optimistic UI state
- safe file operations from execution requiring explicit authority
- a locally valid build from a release-ready build

## Program Principles

### Product principles

1. Lead with the user's object and task: Book, Page, File, Conversation, Run,
   Review, or Published Output.
2. Hide suite topology, service descriptors, contracts, and diagnostics until
   they answer an immediate user question.
3. Keep one primary action and one primary work surface per screen.
4. Preserve context across Desk, Wiki, Code, and Flow.
5. Never claim that work is running without runtime evidence.
6. Never turn an optional capability failure into a false empty state.

### Architecture principles

1. Keep durable truth with MoonBook, execution with MoonClaw, scheduling with
   MoonTown, shared paths with MoonLib, and health reporting with MoonGate.
2. Keep public concrete types in the package users name.
3. Prefer typed records and enums over strings and unstructured JSON.
4. Keep facade APIs narrow; do not export implementation vocabulary.
5. Split compilation units by ownership, not merely by file name.
6. Preserve one canonical conversation and runtime evidence stream.

### Delivery principles

1. A phase is complete only when its exit gate passes.
2. Every behavior change includes tests and user-facing documentation.
3. Every public API change is reviewed through generated `.mbti` diffs.
4. Every cross-package change includes a focused test and a product smoke.
5. Release claims require reproducible evidence from a clean environment.
6. Historical plans record history; one current document records current truth.

## Current Program Action

Phase 1 is complete locally. Its design inventory is recorded in
`docs/FIRST_RUN_AND_VOCABULARY.md`, and its exit-gate evidence is recorded in
`docs/PHASE_1_CLOSURE_2026-07-27.md`. The
first bounded capability slices now supply the private six-state model,
capability-owned labels and actions, and deterministic mappings backed only by
host evidence. Code covers all six states. Requests automation covers running,
configured/stopped, misconfigured, and temporarily unavailable states while
keeping request staging usable. The lifecycle contract now supplies optional
host-backed installation and platform evidence, making all six Requests
capability states reachable while preserving older responses. Focused
capability tests pass 16/16. Home and Code share the same six-state summary and
action allowlist. Code setup is now reachable for every non-ready state:
missing status evidence renders temporarily unavailable, its retry action,
stable state key, closed technical details, and the matching layout row instead
of silently removing setup. Independent subtree tests and a retained populated-browser
fixture prove that the rendered Home card keeps ordinary copy free of service,
daemon, platform, installer, and authority vocabulary while preserving exact
diagnostics in one closed `Technical details` disclosure. The matching
1440×900 screenshot was inspected at original resolution. This closes only
that bounded first-use copy slice; the complete rendered-literal and
localization audit remains open. A second bounded copy slice now aligns the
authoritative English and Simplified Chinese catalogs with the ordinary
six-state Code-assistance UI: eyebrow, heading, six titles, six details, six
statuses, four actions, the installing label, and generic progress text. It
removes three dead setup-topology keys while leaving technical diagnostics
outside the ordinary-copy contract. The canonical generator has also been
repaired so regenerated output preserves exact-only accessibility-attribute
translation and a locale-specific system-language label. The owning MoonBit
sources now attach explicit stable keys to every node in this 26-string slice,
using exhaustive typed state/action mappings while keeping technical
diagnostics outside the ordinary-copy key space. Rendered-source extraction
requires exact equality with the catalog slice, and the generated runtime must
resolve every source-owned key to the Simplified Chinese catalog. Generated
syntax, 5/5 localization tests, and byte-for-byte regeneration prove this
vertical slice. The remaining gate is still a complete source, catalog,
generated-output, and rendered-literal audit across every other surface. The
six-state cold-start classifier and Desk first-use
presentation are also implemented with focused tests, including deterministic
one/many-book selection and a catalog-unavailable state that cannot masquerade
as an empty library. The primary-navigation slice is now implemented:
Desk, Wiki, Code, Flow, and Packs are the five primary destinations. Wiki owns
second-level Pages, Requests, Runs, Review, and Publish tabs with exact routes;
its Pages activity retains Pages, Search, Inbox, and Settings. A compact
disclosure replaces the primary strip at narrow widths. Legacy aliases remain
accepted. Focused
navigation/destination tests and desktop, compact, populated, empty-library,
and quickstart browser journeys pass. The shared eight-state surface contract
now has eleven typed consumers. Workspace catalog loading is owned separately
from broad shell loading and host status. Only successful empty catalog
evidence enables the empty-library creation path; failure without rows offers
refresh, while failed refresh retains prior rows as stale. Switching libraries
clears rows proven by the previous library before the new catalog request.
Saved-view catalog loading is independent from
save-operation feedback. Only an explicit successful empty catalog becomes
legitimate zero; failed refresh retains earlier rows as stale, failure without
rows becomes recoverable, and raw request detail stays inside Technical
details. Home file listing binds responses to the
requesting workspace, directory, and monotonically increasing request
generation. It rejects stale navigation and superseded same-folder responses,
clears rows when location changes, and preserves same-folder evidence through
loading and stale refresh failure. It distinguishes first use, loading,
explicit empty success, ready rows, stale retained rows, and recoverable
failure without showing raw host errors outside Technical details. Pages search
now opts into a backward-compatible versioned response while the legacy array
route remains unchanged. Only a successful empty envelope selects legitimate
zero; an unreadable selected root selects capability-limited, and an explicit
unknown workspace has terminal evidence instead of becoming empty. Same-query
refresh preserves prior hits through loading and stale failure, while query
editing clears cross-query evidence. Raw host/decode details remain inside
Technical details. Disconnected remains contract-only because the browser
adapter erases transport error identity, and the current all-books UI does not
itself issue an invalid workspace filter. Review additionally preserves
prior items through loading, distinguishes stale refresh failure from
recoverable failure without prior content, and keeps its own copy separate from
search language. Requests now distinguishes first use, loading, explicit zero,
ready records, stale retained records, and recoverable failure while keeping
composer feedback and automation capability separate. Runs now enters Loading
on explicit and automatic book selection, derives legitimate zero only from an
explicit successful empty response, preserves failed-refresh records as Stale,
and distinguishes failure without records as RecoverableError. Publish now owns
readiness separately from Review, preserves labeled same-book evidence through
loading/stale states, blocks its output check after a failed empty fetch, and
still does not claim output exists. Code session listing separately owns
first-use, loading, successful-zero, ready, stale-retained, and recoverable
transport states. It does not replace capability classification, archived
history’s optional behavior, transcript projection, watch state, or canonical
conversation ownership. Selected file/page preview now binds each response to
its requesting workspace, path, and monotonically increasing generation. It
rejects late different-path and superseded same-path responses, retains
same-path evidence while refreshing and after failure, separates private host
diagnostics from ordinary copy, and renders transport state without parsing
`preview_status`. None of these surfaces parses display strings for transport
state. Flow run listing now separately owns first use, loading, selected-book
zero, ready, stale retained runs, and recoverable failure. The global response
remains intact while presentation filters the selected book; listing errors
stay inside Technical details; retry re-enters Loading; and ingest busy state is
an explicit boolean instead of parsed progress copy. The
native coding runtime now rejects `finish` as completion evidence for
verification-sensitive prompts unless an accepted mutation is followed by
successful typed verification; requested tests require typed test proof.
Comment-only implementation changes are rejected before disk. Native mutation
results carry content fingerprints, so a fully reverted edit sequence and an
accepted no-op patch cannot satisfy completion. The same ordered verdict
governs model-planned and explicit batches and is retained in terminal
responses, events, and receipts. This prevents a failed or omitted check,
cosmetic edit, or net-zero turn from being reported as a completed
productization command, but it does not prove semantic completeness across
every requested owning layer. The
real choose-library host/UI
contract is now implemented as a bounded Phase 1 slice: desktop manifests grant
the native directory picker; the UI distinguishes selection, cancellation, and
error; the local host validates, prepares, activates, and persists the chosen
library; and subsequent API requests use the active root. Focused server,
persistence, picker-parser, and UI-transition tests pass. The current action is
to extend the shared state contract beyond Home file listing, selected
file/page preview, Pages search, Review, Requests, Runs, Publish, Code session
listing, Flow run listing, the saved-view catalog, and the workspace catalog.
Requests
installation/platform evidence is now
host-backed. Requests configuration validity is also explicit: an operation
failure no longer fabricates `Misconfigured`, an installed supervisor without
service configuration does, and stable reasons remain technical detail.
Remaining capability work is equivalent evidence for other optional
capabilities and unsupported-host proof. Configured Town and Code services now
also validate executable availability and working-directory integrity before
any lifecycle write or process spawn. The
browser-host clean-workspace quickstart is now executable and passing: it
creates/selects a book, saves and reloads Pages content, completes a canonical
Code turn, verifies honest Review/Publish zero states, restarts the host, and
proves book, transcript, and file-byte persistence. Code
assistance now has explicit host platform/architecture support evidence and
selects the unsupported-platform state only from an explicit false value; older
responses retain the prior behavior. Its installation/configuration evidence is
also explicit: managed ownership is no longer mistaken for installation, an
external configured service can be installed/stopped, and observed service
evidence without required configuration becomes misconfigured. A bounded
rendered capability proof now drives the six Code and six Requests states from
explicit running, installation, configuration, platform, and HTTP-availability
evidence at 1440×900. It separately proves Flow ready versus
capability-limited, exact visible title/detail/action mappings, closed
technical disclosures, and separation of private substituted diagnostics from
ordinary copy. Screenshot review found that Flow state title/detail existed
only in the visually hidden announcement; the renderer now presents the same
typed copy visibly and the executable proof geometry-checks it. This does not
close responsive, screen-reader, localization, or unsupported-host acceptance
for those states. A separate bounded 1440×900 keyboard matrix now starts each
hard navigation from natural document focus and uses real Tab, Space, Escape,
and Shift+Tab events to exercise 16 state-owned Technical details disclosures:
six Code, five Requests with structured lifecycle evidence, and five
capability-limited Flow cases. Every traversed target must be connected,
visible, enabled, inside the viewport, and visibly focused; Escape must close
the disclosure and restore the exact triggering summary before a reverse and
forward traversal round-trip. The proof found that the focusable Flow canvas
suppressed its visible outline because its active class did not match an older
focus selector. The active canvas now owns a three-pixel focus-visible outline,
the unrelaxed matrix passes, and three representative screenshots confirm the
restored focus ring. This closes disclosure focus restoration only, not
whole-page order, responsive states, manual screen-reader behavior,
localization, or packaged-native keyboard input. A bounded keyboard/responsive slice now
proves all four specified viewports, including exact 320x700 document-overflow,
pane-overlap, and primary-content visibility checks. It also proves real CDP
Space activation of one disclosure and primary navigation control, plus Escape
closure with focus restoration. The populated smoke additionally proves the
browser-zoom reflow equivalent of a 1440×900 physical window at 200% through
an exact 720×450 CSS viewport. Shared geometry checks prove no document
overflow or pane overlap, correct stacked pane order, confined table content,
above-fold primary work, a valid PNG, no browser errors, and a visible,
keyboard-focusable compact primary destination control. That browser-zoom
slice alone does not prove text-only large-text behavior. A distinct text-only
acceptance path now closes that bounded populated-Home case at 1440×900 and
320×700. It snapshots all
computed font sizes before mutation, doubles 401 rendered HTML elements,
preserves exact viewport dimensions and device scale, and restores every
element afterward. Both cases prove document width equals viewport width, no
horizontal overflow or pane overlap, the correct primary-navigation form, and
unclipped headings, selected book, current path, history controls, and primary
folder actions. Rendered PNG review additionally drove repairs for implicit
shell grid expansion, non-wrapping toolbars and inspector actions, and the
fixed language selector; the selector now occupies a real second-row header
host. This remains one populated state, not the complete responsive state
matrix. The clean-workspace quickstart now proves the
configured-empty-library first useful task using only natural document focus
and real CDP Tab/Shift+Tab, Input insertion, Space, and Enter events. It creates
and selects a MoonBook, opens Pages and the Inbox note composer, saves durable
Markdown, records a bounded 73-entry focus trace, and retains hard-reload and
host-restart persistence evidence. All traversed controls must be connected,
visible, and enabled. A separate eight-case matrix now begins from natural
document focus and uses real Tab/Shift+Tab plus alternating Space/Enter to
exercise one selected book and a four-book chooser at exactly 1440×900,
1024×768, 390×844, and 320×700. The rows share one predicate for active class
and `aria-pressed`, expose a visible focus ring, retain focus after activation,
round-trip reverse traversal, and prove selection agreement across semantics,
URL, identity, and Home content. Each case also proves row DOM/visual order,
the expected desktop/compact navigation, no document overflow, and no pane
overlap; all eight PNGs were visually inspected. This closes the bounded
one/many-book selection matrix, but not every responsive-state page-level
focus order, screen-reader announcement, or packaged native keyboard case. A
fresh packaged macOS build now proves an
app-owned native picker, cancellation, exact invalid-folder rejection, valid
selection, active-root switching, one ready fixture book, and saved
preference. Relaunching the package without pressing **Refresh** restores the
saved root and ready book on the first rendered state. The bridge dispatch,
separate-process accessibility, generic-error, stale-distribution acceptance,
and cold-start initialization/retry defects found during that journey are
repaired and regression-tested. Other supported desktop platforms remain open.
Open acceptance actions include repeating the real picker journey on those
platforms, the four user-skipped real-VoiceOver rows retained by Command 062,
packaged-native keyboard behavior, and page-level focus/state coverage beyond
the bounded browser-host matrices below. Command 059 owns
the completed responsive geometry and action-visibility matrix: 72 unique
Code/Requests/Flow cases now pass at 1440×900, 1024×768, 390×844, and 320×700
with document-start position, no horizontal overflow, unclipped state
presentation, fully visible applicable actions, correct navigation, no pane
overlap, and usable primary work. That evidence moved Flow state/actions before
its canvas, separated downstream handoffs from the primary state panel, wrapped
compact Code setup, and repaired overlapping compact Flow canvas controls.
Command 060 now closes the capability-state scale matrix: 54 unique
Code/Requests/Flow cases pass at 200% browser-zoom equivalence and text-only
200% at both desktop and narrow viewports, with complete scale coverage,
reachable state/action/disclosure content, usable destination controls, and 12
visually reviewed screenshots. The evidence repaired shared card and
empty-state minimum widths, Code setup wrapping and compact scroll ownership,
and Flow header wrapping. Command 061 now closes the bounded whole-page
keyboard-order and focus-restoration slice across responsive setup and
transient surfaces. It contains exactly 18 fresh-navigation cases across
Home storage, Code-assistance setup, the command palette, Code session actions,
and compact navigation at the applicable 1440×900, 1024×768, 390×844, and
320×700 viewports. All cases use real Tab/Shift+Tab, activation, and Escape,
restore the exact trigger, round-trip focus, and retain 18 visually reviewed
screenshots. Command 062 now closes the bounded automated screen-reader
semantics and announcement matrix: 18 route/viewport accessibility-tree cases,
two Commands-dialog cases, and two exact live-region sequences pass with eight
reviewed screenshots. The work repaired landmark names, route headings,
preview-tab fallback naming, decorative glyph exposure, compact navigation
closure/focus, and Flow/Packs header rows. Its four real-VoiceOver transcript
rows remain explicitly pending because the user asked to skip the blocked
system-caption capture; automated DOM/accessibility-tree evidence is not
reclassified as spoken output. These bounded slices contribute to the completed
Phase 1 user-facing gate; they do not claim or advance the broader Phase 8 and
Phase 9 gates.

## Current Baseline

This baseline records the starting point for the program. It should be updated
only by Phase 0 and then treated as historical evidence.

### Product baseline

- MoonDesk is a usable local, single-user, Lepusa-hosted macOS alpha.
- Desk, MoonWiki, MoonCode, MoonTown projections, Flow, app-tool export, and
  native bundle commands exist.
- Native distribution still needs credentialed signing, notarization, hosted
  updates, clean-machine validation, and long-running reliability proof.
- Rich Code and Town operation depends on explicitly configured MoonClaw and
  MoonTown services.
- The product vocabulary and navigation still expose more suite topology than
  a first-time user needs.

### Engineering baseline

- The root native suite passes 217 tests.
- The Rabbita JS suite passes 303 tests.
- The JavaScript localization suite passes 3 tests.
- The production UI builds successfully.
- The Rabbita package currently emits 20 unused-code warnings.
- Coverage analysis reports 2,547 uncovered executable lines across 138 files.
- `internal/moonwiki` contains more than 100 implementation files in one
  MoonBit package.
- `ui/rabbita-desk/main` contains close to 90 implementation files in one
  MoonBit package.
- `mooncode/core/pkg.generated.mbti` exposes hundreds of small public
  functions, most returning strings, booleans, arrays, or unstructured JSON.
- Release construction exists locally, but repository CI and release
  publication are not yet the authoritative path.

## Program Structure

The phases are numbered by program concern. Phase 0 establishes the baseline.
Phases 1 and 2 may then run in parallel: product simplification should begin
early, while CI must become mandatory before the contract and package
refactorings begin.

```text
Phase 0  Establish truth and ownership
   ├──→ Phase 1  Simplify product story and first-run experience
   └──→ Phase 2  Establish mandatory CI and release evidence
                 ↓
Phase 3  Replace string-heavy runtime contracts with typed contracts
   ↓
Phase 4  Split oversized ownership and compilation boundaries
   ↓
Phase 5  Harden workspace and generated-content security
   ↓
Phase 6  Unify runtime observability and operator evidence
   ↓
Phase 7  Complete first-class document and code editing
   ↓
Phase 8  Finish UX consistency, localization, and accessibility
   ↓
Phase 9  Prove native distribution and long-running operation
   ↓
Phase 10 Close the program with release-readiness evidence
```

Phase 3 requires Phase 2's CI gate. Phases 3 and 4 may overlap only after the
target contract ownership map is approved. Phase 7 begins only after the file
authority and runtime-evidence boundaries from Phases 5 and 6 are stable.
Phases 7 and 8 may overlap only after the edit/save contracts are executable.
Phase 9 must not begin as a release claim until Phases 2 through 8 have passed
their exit gates.

### Phase overview

| Phase | Current state | Depends on | Primary result | Next gate evidence |
| --- | --- | --- | --- | --- |
| [0. Current truth](#phase-0-establish-one-source-of-current-truth) | Complete locally | — | One current source of truth and reproducible local baseline | Retain proof; correct drift when later phases change facts |
| [1. Product clarity](#phase-1-simplify-the-product-story-and-first-run-experience) | Complete locally | Phase 0 | Understandable first run and honest capability setup | Retain the closure journey; later matrices remain in Phases 8 and 9 |
| [2. CI and release evidence](#phase-2-make-ci-and-release-evidence-mandatory) | Complete | Phase 0 | Mandatory quality gates and reproducible preview releases | Retain the immutable runs, artifact verification, and bounded rebuild proof |
| [3. Typed MoonCode contract](#phase-3-establish-a-small-typed-mooncode-contract) | Complete | Phase 2 | Small typed public protocol and one serialization boundary | Retain the closed contract and validation evidence |
| [4. Package boundaries](#phase-4-split-oversized-ownership-and-compilation-boundaries) | Complete locally | Phase 3 | Narrower packages, state ownership, and decomposed tests | Retain ownership, interface, focused-test, timing, and product-smoke evidence |
| [5. Security](#phase-5-harden-workspace-and-generated-content-security) | Complete locally | Phases 2–4 | Symlink-aware IO, explicit authority, and isolated content | Retain the confinement, denial-path, authority, receipt, and CI evidence |
| [6. Observability](#phase-6-unify-runtime-observability-and-operator-evidence) | Complete locally | Phases 3–5 | Evidence-backed turns, approvals, traces, and recovery | Retain the canonical ordering, evidence, receipt, stale-event, and disclosure proof |
| [7. Editing workspaces](#phase-7-complete-first-class-document-and-code-editing) | Complete locally | Phases 3–6 | Working DOCX, XLSX, PPTX, and direct Code editing | Retain reopen/save fidelity, conflict, and prompt-to-edit integration evidence |
| [8. UX quality](#phase-8-finish-ux-consistency-localization-and-accessibility) | Complete locally | Stable Phase 7 editing contracts | Shared shell, explicit localization, and accessibility proof | Retain automated evidence; spoken VoiceOver and packaged-native interaction remain manual/external boundaries |
| [9. Native distribution](#phase-9-prove-native-distribution-and-long-running-operation) | Repository path complete; external gate blocked | Phases 2–8 | Credentialed release path, evidence contracts, and local smoke | Credentialed clean-machine install/update/rollback and soak transcripts |
| [10. Closure](#phase-10-program-closure-and-release-readiness) | Complete — **Not ready** | Phases 0–9 | Finite release-readiness decision | Clear every dated blocker in the final readiness report before recording Ready |

## Phase 0: Establish One Source Of Current Truth

### Outcome

The repository has one accurate product status, one prioritized program plan,
one validation entry point, and an explicit ownership map.

### Current gate state — 2026-07-27

The local validation entry point, reproducible baseline, ownership table,
historical labels, active-document contradiction audit, and retained
clean-checkout `scripts/validate.sh full` transcript are complete. Phase 0 is
complete locally. The local CI workflow configuration and isolated proof are not
remote CI-run evidence.

### Why this comes first

MoonDesk has strong plans and reports, but current truth is distributed across
status documents, architecture plans, migration records, UX reports, and
release notes. Engineering work cannot converge if completion is defined
differently in different documents.

### Workstreams

#### 0.1 Current status consolidation

- Update `docs/STATUS.md` to the current date and current implementation.
- Separate current facts from planned work.
- Mark historical reports as historical at their top.
- Move obsolete or completed planning claims out of active reading order.
- Add a compact table of:
  - working
  - working with limitations
  - externally owned
  - blocked on credentials or infrastructure
  - not implemented

#### 0.2 Ownership map

Document the owner of every important concept:

| Concept | Owner | MoonDesk responsibility |
| --- | --- | --- |
| MoonBook contents | MoonBook | browse, edit, preview, review, publish |
| Conversation and runtime journal | MoonClaw | project, watch, render, control |
| Scheduling and standing goals | MoonTown | configure, submit, inspect |
| Shared filesystem contracts | MoonLib | consume typed helpers |
| Health and drift | MoonGate | display and hand off |
| Native shell | MoonDesk/Lepusa | package, launch, supervise |
| UI projection state | MoonDesk | render without becoming durable truth |

For each concept, name:

- the canonical package
- the canonical file or endpoint
- the facade consumed by the UI
- the tests proving ownership

#### 0.3 Validation entry point

Create one top-level validation command or script that runs:

1. formatting check
2. native check
3. native tests
4. JS UI check
5. JS UI tests
6. localization tests
7. production UI build
8. generated-interface verification
9. boundary validators
10. `git diff --check`

The script must:

- stop on the first failure
- print the failing stage
- support a fast mode for local iteration
- support a full mode for CI and release
- avoid changing snapshots or generated interfaces silently

#### 0.4 Baseline evidence

Record:

- test counts by package
- warning counts
- uncovered lines by package
- public symbol counts by package
- largest implementation and test files
- product smoke coverage
- current bundle size and startup time

The point is not to optimize every metric. The point is to detect regressions
and verify that later structural work produces a real improvement.

### Deliverables

- current `docs/STATUS.md`
- ownership table in `docs/ARCHITECTURE.md`
- top-level validation script
- checked-in baseline report under `docs/releases/` or `docs/`
- explicit labels on historical documents

### Exit gate

Phase 0 is complete when:

- a contributor can find current truth from `docs/README.md`
- every product concept has one named owner
- the full validation command runs from a clean checkout
- no document in the active reading order contradicts `STATUS.md`
- baseline metrics are recorded and reproducible

### Non-goals

- no feature redesign
- no package moves
- no contract rewrite
- no release claim

## Phase 1: Simplify The Product Story And First-Run Experience

### Outcome

A first-time user can reach useful work without understanding MoonSuite
internals or manually editing service descriptors.

### Current gate state — complete locally, 2026-07-27

Implementation is complete for five bounded foundations:

1. deterministic six-state cold-start classification
2. deterministic six-state optional-capability classification
3. shared navigation vocabulary for the current shell
4. an eight-state surface contract with Home file listing, selected file/page
   preview, Pages search, Review, Requests, Runs, Publish, Code session listing,
   Flow run listing, the saved-view catalog, and the workspace catalog as typed
   consumers
5. restored primary navigation for Desk, Wiki, Code, Flow, and Packs, with
   Requests, Runs, Review, and Publish retained as second-level Wiki tabs

The native library-selection path is also implemented, focused-tested, and
exercised in a fresh packaged macOS build. A stable bootstrap location owns the
saved preference; a validated selected folder becomes the active root;
cancellation and rejection preserve the current library; unsafe source
checkouts, filesystem roots, missing folders, and individual MoonBooks are
rejected; selecting a `books` folder resolves to its owning suite. Picker
progress and failures are visible beside the library control. The macOS panel
is owned by MoonDesk and accessible as a native open panel. Its bridge route is
a synchronous main-thread modal command, host rejection details remain visible,
and cold-start metadata failure retries only the data-fetch batch before an
established root exists, without duplicating one-time setup. The native package
pipeline now sequences bundle copies before launcher
configuration, propagates integration failure to the outer command, and has
both a clean positive build and an exit-1 negative build as local evidence.

The Phase 1 exit gate is closed by the clean-workspace first-use journey, the
structured capability journey, the restored five-destination navigation, and
the focused state/navigation tests. The exact criterion-to-evidence map is
recorded in `docs/PHASE_1_CLOSURE_2026-07-27.md`.

Work previously listed here as “remaining Phase 1 acceptance” is reassigned to
its owning gate:

- exhaustive localization, reduced-motion, responsive-state, page-level
  keyboard, and focused manual assistive-technology coverage belong to Phase 8
- other-platform picker journeys, packaged-native keyboard behavior, signing,
  installation, update, rollback, and soak evidence belong to Phase 9
- further typed surface adoption may continue when it supports a concrete
  later-phase requirement, but it is not an open-ended Phase 1 quota

The browser-host clean-workspace quickstart is complete. It is not evidence for
packaged-app launch, native picker interaction, signing, or clean-machine
distribution.

### User promise

The initial product explanation should fit in three sentences:

1. MoonDesk is a desktop workspace for MoonBooks.
2. Use Wiki to work on what a book says and Code to work on what it can do.
3. Runs, reviews, and publishing stay attached to the same book.

### Workstreams

#### 1.1 First-run state

Design a first-run flow with these steps:

1. choose or accept the default library location
2. discover existing MoonBooks
3. create or import a MoonBook when none exist
4. show optional service readiness without blocking file and Wiki work
5. open the selected book on its most useful starting surface

The first-run flow must not require users to know:

- `.moonsuite`
- product-home paths
- daemon-info files
- service descriptor schemas
- adapter contracts
- internal runtime route names

Advanced setup details remain available behind an explicit disclosure.

#### 1.2 Navigation vocabulary

Audit global navigation and visible copy.

Primary navigation is expressed in user language:

- Desk
- Wiki
- Code
- Flow
- Packs

Requests, Runs, Review, and Publish remain attached to the selected book as
second-level Wiki tabs. Services and diagnostics appear only where their role
is clear, with technical detail behind explicit disclosure.

#### 1.3 Empty, loading, offline, and error states

For every major surface, define:

- first-use empty state
- legitimate zero-result state
- loading state
- stale state
- disconnected state
- permission or capability limitation
- recoverable error
- terminal error

Each state must provide:

- a plain-language explanation
- one primary next action
- optional technical detail behind disclosure
- no false claim of runtime activity

#### 1.4 Capability-guided setup

Replace raw service configuration instructions in the ordinary UI with:

- detected
- installed but stopped
- running
- not installed
- configured incorrectly
- unavailable on this platform

Each state should offer only actions that are actually supported:

- inspect
- install
- start
- retry
- open setup guide
- continue without the optional capability

#### 1.5 Quickstart documentation

Add a concise quickstart covering:

1. install or build
2. open a library
3. create/import a MoonBook
4. edit one Wiki page
5. start one Code conversation when MoonClaw is available
6. review the resulting files or output

The quickstart must be executable and tested against a clean workspace.

### Deliverables

- first-run flow
- simplified navigation and vocabulary map
- state matrix for each primary surface
- capability-guided setup UI
- tested quickstart
- updated screenshots for desktop and narrow layouts

### Validation

- cold start with no library
- cold start with an empty library
- cold start with one and many MoonBooks
- MoonClaw absent, stopped, running, and misconfigured
- MoonTown absent, stopped, running, and misconfigured
- keyboard-only completion of the first useful task
- 1440x900, 1024x768, 390x844, and 320x700 layout checks
- no internal path or protocol copy in the first-use path

### Exit gate

Phase 1 is complete when a new user can:

- identify where they are
- identify the selected book
- identify the primary action
- create or import a book
- edit and save durable content
- understand why Code or Town features are unavailable
- recover from setup failure without opening repository documentation

**Gate result:** passed locally. See
`docs/PHASE_1_CLOSURE_2026-07-27.md`.

### Non-goals

- no new runtime ownership
- no new domain packs
- no broad visual rebrand
- no diagnostics removal; diagnostics move behind progressive disclosure

## Phase 2: Make CI And Release Evidence Mandatory

### Outcome

Every change is checked by the same quality gates used for release, and every
release artifact is produced from a reproducible pipeline.

### Current bounded evidence — 2026-07-28

Local CI runs the canonical full validator. A separate unsigned-preview
workflow now uses a pinned macOS runner, read-only repository permission,
per-ref concurrency, explicit MoonBit/Node dependency setup, `npm ci`, full
validation, the canonical preview wrapper, an independent artifact
verification, and a uniquely named non-overwriting uploaded artifact.

The underlying command now returns failure instead of printing completion when
bundle integration, signing, archive, requested DMG, runtime manifest, hashes,
or public metadata are missing. Release mode refuses a nonempty output root.
Public release/update JSON contains only release-root-relative paths and never
workspace, UI, dependency-cache, temporary, runner, or user-home paths.

The verifier:

- confines every declared path lexically and after symlink resolution
- recomputes artifact SHA-256 values
- requires matching release/update version, channel, artifact, notarization,
  and installer state
- requires release notes and exact bytewise-sorted `SHA256SUMS` coverage
- assigns stable exits 64–69 to usage, malformed metadata, unsafe contract,
  missing evidence, digest drift, and overwrite attempts
- passes eight fixtures covering a valid twice-read release, immutable checksum
  generation, hash mismatch, absolute path, parent traversal, missing artifact,
  inconsistent notarization, and extra checksum data

One fresh macOS arm64 `0.1.0-preview.4` candidate built locally with app, zip,
DMG, runtime manifest, portable metadata, release notes, and six checksum
entries. It verified twice without mutation; both the wrapper and direct
release path refuse the populated output without changing its file snapshot.
Exact commands, counts, sizes, hashes, and the evidence boundary are retained
in
[`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md).
This closes a local unsigned-preview implementation slice only.

GitHub now retains two clean CI runs for the same reviewed change:

- pull request run [`30314186808`](https://github.com/vectie/moondesk/actions/runs/30314186808),
  commit `faebef38bf9d0e732089d7d9e0f8ccf1023a71f3`, completed successfully as
  job `Required repository validation`; the run was created at 2026-07-27
  23:27:13 UTC, and the job ran from 23:27:15 through 23:28:13 UTC
- default-branch push run [`30316790583`](https://github.com/vectie/moondesk/actions/runs/30316790583),
  merge commit `083e1729e5602146071c06fc5992c74acf608547`, completed successfully as
  job `Required repository validation`; the run was created at 2026-07-28
  00:15:54 UTC, and the job ran from 00:16:03 through 00:17:12 UTC

The immutable `v0.1.0-preview.11` source
`01e5b4d0ed468d12cea8271011dd3147c079f2fb` now has successful hosted run
[`30335949331`](https://github.com/vectie/moondesk/actions/runs/30335949331)
and job
[`90200737627`](https://github.com/vectie/moondesk/actions/runs/30335949331/job/90200737627).
The API retained runner `GitHub Actions 1000001278`, group `GitHub Actions`,
label `macos-14`, and artifact `8679181026`, named
`moondesk-0.1.0-preview.11-01e5b4d0ed468d12cea8271011dd3147c079f2fb-macos-arm64-unsigned`
at 18,011,747 bytes. The unchanged download passed the repository read-only
verifier and checksum check. An independent descendant-only clean checkout
passed `scripts/validate.sh full`, rebuilt and verified the same portable
contract, and recorded exact matching fields plus host/toolchain/timestamp-
sensitive digest and size differences. See
[`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md).

**Gate result:** passed. Phase 2 is complete; byte identity, signing,
notarization, clean-machine installation, update/rollback, and soak proof are
not claimed here and remain later Phase 9 qualification.

### Workstreams

#### 2.1 Continuous integration

Enable an active repository workflow for:

- `moon fmt --check` or equivalent formatting verification
- `moon check --target all --warn-list +unnecessary_annotation`
- native tests
- JS UI checks and tests
- JavaScript localization tests
- production UI build
- generated `.mbti` verification
- contract-boundary scripts
- smoke tests that do not require credentials
- `git diff --check`

Use concurrency cancellation for superseded branch and pull-request runs.

#### 2.2 Warning policy

Adopt a staged warning policy:

1. Phase 2 begins by recording the current warning allowlist.
2. Existing warnings receive owners and removal issues.
3. New warnings fail CI immediately.
4. The existing warning count must only decrease.
5. The phase cannot close until the allowlist is empty.

Do not globally suppress unused fields or constructors to obtain a green build.

#### 2.3 Generated interface policy

CI must run `moon info` for the supported targets and fail if generated
interfaces differ from the committed files.

Pull requests changing `.mbti` files must explain:

- intended new or removed public symbols
- compatibility impact
- owning package
- migration or deprecation path

#### 2.4 Reproducible release workflow

Automate:

- version stamping
- UI production build
- native sidecar build
- Lepusa bundle construction
- asset and runtime manifest verification
- archive and DMG construction
- checksums
- release notes
- signing/notarization when credentials are present
- explicit unsigned preview behavior when credentials are absent

Release assets must be immutable. Re-running an existing release should verify
or skip it rather than replacing artifacts silently.

#### 2.5 Changelog discipline

Create one changelog policy:

- every user-visible change has one concise entry
- each release has a curated summary
- released entries are immutable
- release notes link to validation evidence and known limitations

### Deliverables

- active CI workflow
- empty warning allowlist
- `.mbti` drift check
- automated preview release workflow
- documented production release workflow
- consolidated changelog

### Exit gate

Phase 2 is complete when:

- a clean pull request runs all mandatory checks
- warnings fail CI
- generated interface drift fails CI
- a preview artifact can be reproduced from a tag
- checksums and release notes are generated automatically
- no release step depends on an undocumented local machine path

### Non-goals

- production notarization is not claimed until Phase 9
- credentialed live-model tests may remain separately gated
- CI does not require sibling source checkouts unless roots are explicit

## Phase 3: Establish A Small Typed MoonCode Contract

### Outcome

MoonDesk consumes and exposes a compact typed contract for conversations,
commands, evidence, approvals, lifecycle state, and capabilities.

### Why this phase matters

The current MoonCode contract surface exposes hundreds of public helper
functions. Many functions return strings or JSON fragments representing
states, actions, event kinds, lanes, tools, endpoints, and policy decisions.
This makes invalid combinations easy to express and makes public API review
difficult.

### Target domain model

Define a small set of public types owned by the correct public package:

```text
MoonCodeCapability
MoonCodeSessionId
MoonCodeSessionSummary
MoonCodeSessionStatus
MoonCodeConversation
MoonCodeTurn
MoonCodeMessage
MoonCodeWork
MoonCodeEvidence
MoonCodeCommand
MoonCodeCommandKind
MoonCodeCommandStatus
MoonCodeApproval
MoonCodeLifecycleAction
MoonCodeWatchCursor
MoonCodeWatchResult
MoonCodeFailure
```

Use enums for closed vocabularies:

- session status
- command kind
- command status
- evidence kind
- approval decision
- lifecycle action
- stop reason

Use opaque or validated IDs for identities. Use JSON only at serialization
boundaries.

### Workstreams

#### 3.1 Public API inventory

Classify every current public MoonCode symbol:

- public domain type
- public operation
- serialization helper
- endpoint construction
- compatibility alias
- test-only contract assertion
- private implementation detail
- obsolete symbol

The default decision for constants and helper predicates is private unless an
external consumer is proven.

#### 3.2 Canonical ownership

Agree with the owning runtime package on:

- canonical conversation representation
- stable session identity
- command packet representation
- evidence and approval representation
- watch cursor semantics
- lifecycle error semantics

MoonDesk must not invent a second durable representation. It may define a
small presentation DTO only when the runtime type contains details the desktop
must not expose.

#### 3.3 Typed serialization boundary

Create exactly one decoding path from runtime JSON into typed values and one
encoding path for supported commands.

Rules:

- reject unknown required fields
- preserve forward-compatible optional fields deliberately
- distinguish absent, malformed, unsupported, and stale data
- never render raw decode failures as ordinary empty state
- include contract version and capability negotiation

#### 3.4 Migration

Migrate in vertical slices:

1. capabilities
2. session listing
3. selected session
4. canonical conversation
5. command submission
6. watch/stream
7. approvals
8. lifecycle mutation
9. package/review evidence

For each slice:

- add the typed type
- add decode/encode tests
- adapt the existing route
- migrate the UI
- remove or deprecate old helpers
- review `.mbti` shrinkage

#### 3.5 Compatibility

Use compatibility aliases or wrappers only for proven consumers. Put
deprecated blocks in `deprecated.mbt` within the owning package. Give every
deprecated API a removal phase.

### Quantitative targets

- reduce public MoonCode function count substantially
- replace repeated string-status helpers with enums
- expose domain types instead of JSON construction helpers
- keep serialization helpers private
- make the generated `.mbti` readable in one review session
- eliminate duplicated endpoint and action vocabularies

The precise symbol-count target is set after the Phase 3 inventory; it must be
ambitious enough that the resulting interface expresses the domain rather than
the implementation.

### Validation

- black-box tests for every public typed operation
- malformed and forward-compatible payload tests
- session resume and watch-cursor tests
- stale response and revision rollback tests
- command idempotency tests
- approval ownership tests
- generated `.mbti` review at every slice
- unchanged visible conversation ordering

### Exit gate

Phase 3 is complete. All nine slices are closed. Accepted evidence:

- **17** public types, **30** public functions/methods, **0** public impl/raw
  helpers, and **47** public declarations;
- generated interface: **245 lines / 7,053 bytes**;
- **11** ownership validators green;
- `mooncode/core`: **61/61** on wasm, wasm-gc, js, and native;
- `internal/mooncode`: **15/15** on all four targets;
- MoonWiki: **155/155**; UI: **379/379**.

Downstream consumer migration commit `716870857725abd5fb0853675cf5ee494a87bd2f`
was validated but deliberately is not part of this integration. The immediate
next phase is Phase 4 package boundaries.

The closure gate required:

- the UI no longer parses MoonCode runtime JSON throughout view/update files
- closed state vocabularies are enums
- one adapter owns serialization
- public helpers describe user/domain operations rather than protocol strings
- old APIs are removed or have dated deprecation paths
- the visible MoonCode behavior remains regression-clean

### Non-goals

- no runtime loop moves into MoonDesk
- no second conversation store
- no speculative abstraction for runtimes MoonDesk does not support
- no UI redesign beyond changes required by the typed contract

## Phase 4: Split Oversized Ownership And Compilation Boundaries

### Outcome

MoonDesk has packages whose responsibilities are narrow enough to understand,
test, and change independently.

### Package design rule

A package should have one reason to change and should own the public concrete
types that users of that package construct, inspect, match, or call methods on.
An `internal/*` package may own implementation helpers, but it must not become
the accidental owner of public desktop types.

### Workstreams

#### 4.1 Dependency map

Generate the current package dependency graph and classify dependencies as:

- domain DTO
- filesystem
- HTTP transport
- runtime adapter
- UI state
- UI rendering
- test helper

Identify cycles currently avoided only because many files share one package.

#### 4.2 Host-side target boundaries

Evaluate extraction of cohesive packages such as:

```text
internal/workspace
  discovery, scoped path resolution, entry operations

internal/preview
  preview classification, safe response headers, raw/site serving

internal/bookpatterns
  registry, creation, verification, standing-goal handoff

internal/portable
  app-tool discovery, copy, rewrite, manifest, launcher

internal/services
  MoonClaw/MoonTown descriptor and lifecycle adapters

internal/review
  queue, diff, decisions, preferences
```

Names are provisional. Extraction occurs only when the ownership and dependency
direction are clear.

Keep route assembly in a thin host facade. Route handlers should call typed
services rather than share one package-wide namespace of unrelated helpers.

#### 4.3 UI state decomposition

Before splitting UI packages, separate the current global model into explicit
state records:

- shell state
- workspace state
- Wiki state
- Code state
- Town state
- Flow state
- setup/capability state

Then define:

- which messages can change each state
- which effects each state can request
- which cross-surface transitions are legitimate
- which state survives route changes or reload

Prefer small update functions returning explicit effects. Avoid background
results mutating unrelated surface state.

#### 4.4 UI package options

Evaluate package extraction only after the state contract is explicit. Likely
candidates include:

- pure view-model projection helpers
- URL and route state
- localization keys and formatting
- canonical MoonCode transcript projection
- Desk sorting, selection, and clipboard state

Do not create packages that require exposing all internal UI structs publicly
just to cross a package boundary. In that case, keep the code in one package
but reduce the global model and file size first.

#### 4.5 Test decomposition

Split very large test files by user contract:

- session selection and lifecycle
- optimistic submission and acknowledgement
- watch/reconnect/stale response
- approvals and cancellation
- Desk navigation and sorting
- Desk mutations and trash
- imports and creation
- accessibility and responsive projection

Use black-box tests for public package behavior and white-box tests only for
private state transitions that cannot be expressed through public APIs.

### Structural targets

- no package combines filesystem, transport, domain creation, service
  lifecycle, and portable packaging without an explicit facade boundary
- no new production file grows beyond the agreed review threshold
- large existing files have owners and decomposition plans
- public type ownership follows the package users name
- test files are organized by behavior rather than historical accumulation
- package-level tests can run without unrelated UI or service fixtures

### Validation

For each extraction:

1. record the intended dependency direction
2. run `moon check`
3. run targeted package tests
4. run `moon info`
5. confirm intended `.mbti` changes
6. run the owning product smoke
7. measure build/test time before and after

### Exit gate

Phase 4 is complete when:

- the package map matches documented ownership
- `internal/moonwiki` is a thin facade or has a substantially narrower scope
- UI state changes are surface-owned and background-safe
- the largest tests are split by behavior
- generated interfaces expose no internal helper types accidentally
- clean builds and targeted tests are faster or no slower without a documented
  reason

### Non-goals

- no package explosion for its own sake
- no file moves without ownership improvement
- no public types moved into `internal/*`
- no broad rewrite of working behavior

## Phase 5: Harden Workspace And Generated-Content Security

### Outcome

All local file and preview operations remain inside their intended authority
scope, including traversal, symlink, archive, origin, and generated-script
cases.

### Threat model

MoonDesk handles:

- user-selected workspaces
- potentially untrusted imported archives and files
- generated HTML, SVG, JavaScript, and app-tools
- local HTTP requests from a WebView or browser
- paths emitted by runtimes
- service descriptors and downloaded release assets

The security model must assume that filenames, manifests, archives, generated
content, runtime events, and request paths can be malformed or hostile.

### Workstreams

#### 5.1 Canonical path confinement

Replace lexical-only checks at security-sensitive IO boundaries with canonical,
symlink-aware resolution.

Reads must:

- canonicalize the workspace root
- canonicalize the target
- verify the canonical target is inside the canonical root
- perform IO on the canonical path

Writes must:

- reject absolute and parent traversal
- canonicalize the nearest existing parent
- verify the parent remains inside the canonical root
- create missing directories only below a verified ancestor
- refuse final-component symlinks where supported
- avoid check-then-use gaps

Add the required primitives to MoonLib or a narrow native filesystem package
when they are shared across products.

#### 5.2 Workspace authority

Define explicit scopes for:

- library root
- selected MoonBook root
- suite product-home projections
- inbox/import staging
- trash and restore
- generated output
- portable export output

Every route must name the authority scope it accepts. A book-scoped route must
not become suite-scoped merely because a convenient path exists.

#### 5.3 Archive and import safety

Verify:

- zip-slip prevention
- symlink entries
- absolute archive paths
- duplicate names
- Unicode normalization collisions
- oversized compressed and expanded payloads
- unsupported file types
- overwrite policy
- staging-before-promotion

Imports must return a receipt describing accepted, renamed, rejected, and
quarantined entries.

#### 5.4 Generated-content isolation

Preserve and extend:

- opaque sandboxed preview origins
- restrictive CSP
- no ambient cookies or storage
- no unapproved network access
- no form submission or top navigation
- limited permissions policy
- explicit capability manifest
- `auto_open_allowed=false` for unsupported or unsafe app-tools

HTML and SVG should never execute on the authenticated application origin.

#### 5.5 Local server security

Test:

- DNS rebinding and invalid Host headers
- invalid or opaque Origin headers
- unsupported HTTP methods
- request-body limits
- content-type validation
- cache and referrer headers
- localhost-only binding by default
- behavior behind the native host

#### 5.6 Execution authority

MoonDesk must continue delegating execution. Any command or lifecycle action
exposed by the desktop must have:

- a typed action
- explicit authority
- a visible target scope
- an approval or policy decision where required
- a durable receipt
- a clear stop/cancel path

### Deliverables

- canonical path API
- symlink-safe read/write implementation
- route-to-authority matrix
- archive/import security suite
- generated-preview security suite
- desktop action receipt contract
- security section in architecture and release documentation

### Exit gate

Phase 5 is complete when:

- traversal and symlink escapes are rejected for reads and writes
- archive extraction cannot escape staging
- generated scriptable content cannot reach authenticated application state
- every mutating route has an explicit authority scope
- every execution control produces a receipt
- the security suite runs in CI

**Status: complete (2026-07-30).** Repository evidence is recorded in
[`PHASE5_SECURITY_EVIDENCE.md`](PHASE5_SECURITY_EVIDENCE.md). Archive extraction
is deliberately unsupported: the real import boundary rejects archive entries
before any write and returns the typed staging receipt. The focused security
suite, all-target check, 326 native tests, 487 UI tests, interface generation,
formatting, and the full product validator passed; the validator's final
clean-tree assertion is completed after the Phase 5 commit.

### Non-goals

- no general-purpose local shell
- no remote multi-user server exposure
- no expansion of authority for convenience

## Phase 6: Unify Runtime Observability And Operator Evidence

### Outcome

MoonDesk shows one coherent, evidence-backed view of conversations, work,
approvals, changes, tests, packages, costs, and failures without duplicating
runtime truth.

### Operator questions

Every runtime view should answer:

1. What did I ask?
2. Is anything actually running?
3. What is it doing now?
4. What authority has been requested or granted?
5. What files or artifacts changed?
6. What tests or checks ran?
7. What failed, and can I retry safely?
8. What is ready for review, acceptance, or publishing?

### Workstreams

#### 6.1 Canonical turn presentation

Keep one turn ordered as:

```text
user message
  → factual work disclosure
  → assistant answer
```

Rules:

- user input appears optimistically
- work appears only after runtime evidence
- live work updates in place
- completed work remains attached to its turn
- reload preserves order and identity
- stale watchers cannot roll back revisions
- diagnostics never become chat messages accidentally

#### 6.2 Evidence model

Project typed evidence for:

- tool execution
- file edits
- diffs
- test/build/eval results
- package/export results
- approvals
- review receipts
- runtime failure and retry

Evidence must include:

- stable identity
- owning command and turn
- status
- timestamp
- source
- artifact or file references
- user-facing summary
- optional diagnostic detail

#### 6.3 Unified run and trace view

Create one operator view with:

- turn/request timeline
- current and terminal statuses
- tool and approval events
- file/diff/test evidence
- token and cost data when the runtime provides it
- reconnect, cancellation, and compaction markers
- links to durable artifacts and reviews

Capability-gate fields that the runtime does not provide. Do not fabricate
zeros or empty charts.

#### 6.4 Approval experience

An approval request must show:

- requested action
- target file, directory, service, or external effect
- read-only or mutating classification
- requesting turn and command
- expected outcome
- allow and deny actions
- resulting receipt

The decision must survive reload and remain auditable.

#### 6.5 Failure and recovery

Define distinct user-visible handling for:

- runtime unavailable
- model unavailable
- command rejected
- approval denied
- tool failure
- network timeout
- malformed event
- stale watcher
- interrupted run
- failed package/review handoff

Each recoverable state identifies whether retry is:

- safe and idempotent
- safe only after inspection
- unsafe without a new command
- unavailable

#### 6.6 Usage and evaluation projections

When supported by the runtime, add:

- per-session and per-turn token usage
- model identity
- duration
- cost
- success/failure summaries
- evaluation result links

These are projections, not a second accounting store.

### Deliverables

- typed evidence model
- unified turn work disclosure
- run/trace operator view
- durable approval receipts
- failure/retry policy
- capability-gated usage and evaluation projections

### Validation

- first through fifth turns
- parallel or sequential tool evidence
- approval allow and deny
- disconnect and reconnect
- cancellation at each lifecycle stage
- malformed and stale events
- hard reload during work
- runtime restart
- long output and truncation
- diff/test/package evidence
- no duplicate or reordered turns

### Exit gate

Phase 6 is complete when:

- ordinary users can explain current work without reading diagnostics
- every displayed progress claim has runtime evidence
- approvals and mutations have durable receipts
- reload and reconnect preserve canonical ordering
- stale events cannot overwrite newer state
- diagnostic detail remains available but progressively disclosed

### Closure evidence

Phase 6 is complete locally at commit `568ec7c3`. The bounded audit found one
remaining user-visible gap: completed approval decisions did not identify their
owning command/tool call or durable receipt. That copy and its focused regression
test close the gap. Existing owning tests prove the other exit criteria; the
exact mapping and validation record are in `docs/PHASE6_OPERATOR_EVIDENCE.md`.

### Non-goals

- no duplicate trace database
- no runtime-specific raw journal in the ordinary transcript
- no unsupported cost or evaluation claims

## Phase 7: Complete First-Class Document And Code Editing

### Outcome

A user can work with DOCX, XLSX, and PPTX artifacts and directly edit source
files from Code without leaving MoonDesk or relying on an unverified agent-only
path.

### Why this phase belongs here

This is product capability, not visual polish. It follows the typed contract,
package-boundary, filesystem-authority, and runtime-evidence phases because
binary document writes and concurrent user/agent source edits need those
boundaries. It precedes UX quality so Phase 8 validates real editors rather than
mockups or read-only placeholders.

### Current gate state — complete locally, 2026-07-30

Product implementation commit `94f957a4` closes the repository-local Phase 7
gate. DOCX, XLSX, and PPTX valid ZIP packages can be opened, edited, saved,
closed, reopened, and exported. Independent ZIP/member verification confirms
valid saved packages and retention of unknown members. The supported model
also retains XLSX formulas and sheet identity, plus PPTX slide order and
geometry.

Code now supports direct file open, edit, save, diff, reload, and deliberate
replace. A baseline conflict preserves the dirty draft instead of silently
overwriting it. The retained browser journey uses real MoonCode to edit a file
and then directly edits that same file, while backend messages and errors stay
honest.

Automatic same-session runtime-turn resume is deliberately narrow: it applies
only to paused planner transport and uses canonical session listing, the bound
`book_root`, and repository-local daemon metadata. It does not replay a prompt
and has no retry count or time/step ceiling.

Closure evidence is retained in `docs/PHASE7_EDITING_EVIDENCE.md`: focused UI
Office tests passed 7/7; `internal/moonwiki` passed 165/165; the Phase 7 browser
smoke passed and emitted `moondesk-phase7-editing-proof.v1` for DOCX, XLSX, and
PPTX with `conflictDraftPreserved: true` and MoonCode-edit-then-direct-edit
proof; full fast validation passed 338/338 native and 500/500 UI. The compiler
still reports pre-existing warnings, so Phase 7 does not claim warning-clean
release readiness.

### Workstreams

#### 7.1 Editing contract

Define one internal contract for:

- open
- editable content or structured model
- dirty state
- save
- save failure
- external change detection
- reopen verification
- export or download

The contract must distinguish first-class editing from raw download or
read-only preview. Unsupported features must remain explicit.

#### 7.2 DOCX integration

Implement:

- document open and readable rendering
- paragraph and basic inline-style editing
- save to a valid DOCX package
- reopen verification
- preservation of content outside the supported edit subset

#### 7.3 XLSX integration

Implement:

- workbook and worksheet navigation
- cell value and basic formula editing
- save to a valid XLSX package
- reopen verification with formulas and sheet identity intact
- honest handling of unsupported workbook features

#### 7.4 PPTX integration

Implement:

- slide navigation and readable rendering
- text and basic object-property editing
- save to a valid PPTX package
- reopen verification with slide order and supported content intact
- honest handling of unsupported presentation features

#### 7.5 Direct Code editor

Replace the read-only source-pane foundation with a visible editor that
supports:

- workspace-scoped source tree and file opening
- text editing with line and selection state
- dirty-state indication and navigation protection
- explicit save and save-failure recovery
- reload after external change
- diff and diagnostics alongside the active file

#### 7.6 User and agent edit coordination

Define one conflict rule for direct edits and MoonCode mutations:

- an agent cannot silently overwrite an unsaved user draft
- an external or agent change is detected before save
- the user can reload, compare, or deliberately replace
- accepted agent changes appear as reviewable file evidence
- saved direct edits become the next MoonCode source truth

#### 7.7 Executable acceptance

Add product-level journeys that prove:

1. open, change, save, close, and reopen one DOCX
2. open, change, save, close, and reopen one XLSX
3. open, change, save, close, and reopen one PPTX
4. open, edit, save, and verify one source file in Code
5. submit one MoonCode change, observe the resulting file and diff, then edit
   and save that file directly
6. preserve an unsaved direct edit when an agent or external process changes
   the same file

Fixture-only render tests do not satisfy this gate. Each journey must verify the
saved bytes by reopening through an independent reader or parser.

### Deliverables

- shared editor state and save contract
- first-class DOCX, XLSX, and PPTX integrations
- visible direct Code editor
- user/agent edit-conflict behavior
- reopen/fidelity fixtures and browser journeys
- honest unsupported-feature messages

### Exit gate

Phase 7 is complete when:

- each Office format passes open/edit/save/reopen acceptance
- saved files remain valid and retain supported content
- raw binary transport is no longer reported as Office integration
- Code supports direct file editing and durable save
- MoonCode mutations and unsaved direct edits cannot silently overwrite each
  other
- one current browser journey proves prompt-to-edit evidence and subsequent
  direct editing of the same file

### Non-goals

- no claim of complete feature parity with dedicated Office applications
- no macro execution
- no real-time multi-user collaboration
- no silent conversion that loses unsupported content

## Phase 8: Finish UX Consistency, Localization, And Accessibility

### Outcome

Desk, Wiki, Code, Flow, Runs, Review, and setup feel like one product and remain
usable across supported window sizes and assistive input.

### Current bounded evidence — 2026-07-27

Home now has retained normal and 200% text-only screenshots plus geometry proof
at 1440×900 and 320×700. The proof covers exact viewport/document widths,
navigation form, pane separation, selected-book/path visibility, and unclipped
folder/history actions. The localization selector participates in the desktop
header layout instead of floating over content, and the compact header remains
single-control at narrow width. This is evidence for one populated Home state;
it does not satisfy the complete accessibility, localization, surface, state,
or assistive-technology matrices below.

MoonBook selection now has a distinct eight-case keyboard proof spanning one
and many books at 1440×900, 1024×768, 390×844, and 320×700. Native buttons
expose exactly one `aria-pressed="true"` state from the same predicate as the
visual active state, a three-pixel focus ring remains visible in every retained
PNG, and real CDP traversal/activation agrees with URL and rendered Home state.
This is not evidence for complete page-level focus order, announcements in a
screen reader, every data/capability state, or packaged native keyboard input.

The persistent shell now has one native skip link and exactly one named `main`
landmark for each of Desk, Wiki, Code, Requests, Runs, Review, Publish, Flow,
and Packs. Both rendered primary-navigation forms and the Wiki tab navigation
are named. One predicate drives visual selection, `aria-pressed`, and
`aria-current`. Destination changes
publish a factual polite/atomic status. Home/Desk file listing, selected
preview, Pages search, Review, Requests, Runs, Publish, and Code session
listing use the same isolated polite/atomic announcement helper; technical
diagnostics and actions remain outside the live node.

The retained `moondesk-shared-shell-accessibility-proof.v1` evidence covers:

- skip-link focus, visible focus indication, Enter activation, main focus
  transfer, and a non-trapping reverse/forward traversal at 1440×900, 1024×768,
  390×844, and 320×700
- five primary destinations plus four nested Wiki destinations in a 1440×900
  desktop group and a 390×844 compact group
- matching DOM and CDP accessibility-tree navigation, current-state, main, and
  status semantics
- a deterministic Pages Loading → RecoverableError → LegitimateZero sequence,
  with technical detail excluded from the announcement
- six original-resolution screenshot inspections and bounded no-overflow /
  no-pane-overlap geometry

Screenshot review found and repaired two product defects after the first
machine pass: live-region text was visibly duplicated, and Runs/Publish
inherited Home’s three-column grid and rendered their cards in a narrow track.
This closes only the shared-shell semantic/interaction slice. CDP accessibility
tree evidence does not establish spoken output, announcement timing, or
usability in a manual assistive-technology session.

### Current gate state — complete locally, 2026-07-30

Phase 8 is complete for the repository-local product gate. The retained
implementation and evidence now cover the primary Desk, Wiki, Code, Flow, and
Packs shell plus the routed operational surfaces:

- source-authored localization keys replace rendered-English matching for the
  corrected Code/session states; English and Simplified Chinese catalogs have
  parity tests and no known mixed-language collision remains
- semantic primary-navigation labels, keyboard transient handling, skip/main
  behavior, named landmarks, focus restoration, selected-state semantics, and
  factual live regions pass the automated accessibility journeys
- reduced-motion behavior, 44-pixel narrow controls, and the 844×390
  short-landscape geometry matrix pass without pane overlap, clipped primary
  actions, or hidden recovery controls
- Code’s short-landscape session/search layout and the shared routed surfaces
  retain one visible primary question/action without changing the five
  top-level destinations
- native MoonDesk tests pass 338/338, Rabbita JS tests pass 501/501, the
  production bundle builds, and the focused MoonCode adapter suite passes
  16/16 after the removed local-projection architecture was reflected in its
  validators

The retained browser evidence is repository-local under `_build`. DOM,
geometry, keyboard, and accessibility-tree assertions are authoritative for
the automated gate. Chromium’s headless raster capture intermittently omits
already-painted top-navigation text even when the same nodes are present,
visible, correctly sized, and exposed in the accessibility tree; this renderer
artifact is not treated as a product overlap failure. Spoken VoiceOver timing
and clean-machine packaged-native interaction remain manual/external evidence
boundaries and are not reclassified as automated proof. The former belongs to
the manual accessibility checklist; packaging, signing, installation, update,
rollback, and soak evidence belong to Phase 9.

### Workstreams

#### 8.1 Shared shell

Standardize:

- global navigation
- selected book/scope
- page title and primary action
- contextual toolbar
- loading and error placement
- disclosure of diagnostics
- status and notification placement
- pane resizing and collapse behavior

Avoid duplicate navigation to the same action in rail, toolbar, hero, and
empty state.

#### 8.2 Surface-specific primary questions

Each surface must have one primary question:

| Surface | Primary question |
| --- | --- |
| Desk | What files and outputs are in this book? |
| Wiki | What does this book say, and what should I edit or review? |
| Code | What coding conversation am I having in this book? |
| Runs | What work is running or completed? |
| Review | What proposed change needs my decision? |
| Publish | What durable output is ready to share or package? |
| Flow | How is this executable work composed? |

Remove or move content that does not help answer the primary question.

#### 8.3 Localization architecture

Replace fragile runtime text matching over rendered English strings with
explicit localization keys at the source of UI construction.

Requirements:

- every user-visible string has a stable key
- parameters are typed or validated
- no substring/template collision can translate unrelated status text
- aria labels, titles, placeholders, and visible copy share intentional keys
- English and Simplified Chinese catalogs have parity
- missing keys fail tests
- internal errors are translated into user-facing categories before rendering

#### 8.4 Accessibility

Verify:

- native semantic controls
- logical heading order
- keyboard order matching visual order
- visible focus
- no keyboard traps
- polite live regions for factual async state
- alerts only for actionable failures
- selected state conveyed semantically
- icon-only controls have accessible names
- decorative icons are hidden from assistive technology
- 44px minimum primary touch targets at narrow widths
- reduced-motion behavior
- readable contrast in every supported theme

Add a skip-to-content mechanism if the persistent desktop navigation creates a
long keyboard path.

#### 8.5 Responsive behavior

Validate:

- wide desktop
- normal desktop
- compact desktop/tablet
- phone-sized stress layout
- short landscape window

Phone-sized support is a resilience target, not necessarily a distribution
target. The primary action, current object, and recovery path must remain
reachable.

#### 8.6 Visual consistency

Consolidate:

- spacing scale
- type scale
- surface and border tokens
- selected, hover, focus, disabled, warning, and error states
- icon system
- pane widths
- toolbar heights
- code/diff/test presentation

Do not solve hierarchy problems by adding cards. Operational surfaces should
remain quiet, dense, and scannable.

### Deliverables

- shared shell contract
- surface hierarchy audit
- explicit localization-key system
- catalog parity tests
- accessibility checklist and automated checks
- responsive screenshot and geometry suite
- consolidated design tokens

### Exit gate

Phase 8 is complete when:

- all primary surfaces use the shared shell rules
- no known mixed-language or template-collision bug remains
- keyboard-only primary journeys pass
- reduced-motion and narrow-layout tests pass
- internal error strings do not leak into ordinary UI
- desktop and narrow screenshots show no overlap or hidden primary action
- each screen has one obvious primary question and action

### Non-goals

- no ornamental redesign
- no conversion-focused landing patterns inside the app
- no mobile application commitment

## Phase 9: Prove Native Distribution And Long-Running Operation

### Outcome

MoonDesk can be installed, launched, updated, recovered, and removed on a clean
supported Mac through a documented and reproducible release path.

### Current gate state — repository path complete, external gate blocked, 2026-07-30

The repository-owned release path, protected credential inputs, immutable
identity/channel metadata, signing/notarization command order, evidence
schemas/checklists, fixed soak thresholds, and non-credentialed smoke are
implemented and locally validated. Exact operations and blockers are retained
in [`PHASE9_NATIVE_DISTRIBUTION_REPORT.md`](PHASE9_NATIVE_DISTRIBUTION_REPORT.md)
and [`PHASE9_RELEASE_OPERATIONS.md`](PHASE9_RELEASE_OPERATIONS.md).

Phase 9 is not complete. No credentialed Apple, Gatekeeper, hosted-channel,
clean-machine, lifecycle, or 24-hour soak evidence was available locally, and
none is inferred from the repository-owned implementation.

### Workstreams

#### 9.1 Credentialed release

Establish:

- Developer ID Application signing
- hardened runtime settings
- notarization submission and stapling
- DMG signing
- update manifest signing
- credential isolation in CI
- auditable release identity and version

#### 9.2 Clean-machine matrix

Test on clean systems covering:

- minimum supported macOS
- current macOS
- fresh user account
- no MoonBit toolchain
- no source checkout
- no existing MoonSuite root
- existing MoonBook library
- offline first launch
- optional services absent and present

#### 9.3 Installation and update

Verify:

- DMG installation
- first launch and Gatekeeper behavior
- sidecar startup and shutdown
- application restart
- in-place update
- rollback or safe failure after interrupted update
- preservation of user libraries and settings
- removal without deleting user data

#### 9.4 Long-running lifecycle

Run reliability tests for:

- repeated open/close
- sleep/wake
- network loss and recovery
- runtime restart
- MoonDesk sidecar crash and supervision
- service port collision
- large libraries
- long Code sessions
- concurrent file changes
- repeated preview and generated-app use
- memory and file-descriptor growth

Define soak-test durations and acceptable resource thresholds before testing.

#### 9.5 Update hosting and channels

Provide:

- stable and preview channels
- immutable release assets
- signed metadata
- hosted checksums
- explicit compatibility requirements
- rollback guidance
- release notes and known limitations

### Deliverables

- signed and notarized release
- clean-machine report
- update and rollback report
- soak-test report
- hosted update channel
- installation/removal documentation

### Exit gate

Phase 9 is complete when:

- a clean Mac installs and launches MoonDesk without development tools
- Gatekeeper accepts the application normally
- the sidecar is supervised correctly
- an update succeeds without losing user data
- interrupted update behavior is safe
- soak tests meet the defined resource and reliability thresholds
- release artifacts and metadata are reproducible and immutable

### Non-goals

- no Windows commitment
- no remote hosted MoonDesk service
- no claim beyond tested macOS architectures

## Phase 10: Program Closure And Release Readiness

### Outcome

The productization program ends with a finite readiness decision, not an
open-ended list of improvements.

### Current gate state — complete with Not ready decision, 2026-07-30

The closure audit is complete. The project records **Not ready**, with every
remaining release blocker assigned an owner, target date, and required evidence
in
[`FINAL_RELEASE_READINESS_2026-07-30.md`](FINAL_RELEASE_READINESS_2026-07-30.md).
This completes Phase 10's decision gate without reclassifying Phase 9's missing
external proof as success.

### Closure audit

Audit every prior phase:

| Phase | Required closure evidence |
| --- | --- |
| 0 | current status, ownership map, validation entry point |
| 1 | first-run journey and setup evidence |
| 2 | green mandatory CI and reproducible preview release |
| 3 | reviewed typed MoonCode `.mbti` surface |
| 4 | package graph and boundary tests |
| 5 | security suite and authority matrix |
| 6 | runtime evidence, approval, and recovery journeys |
| 7 | DOCX/XLSX/PPTX and direct Code edit/save/reopen journeys |
| 8 | localization, accessibility, and responsive evidence |
| 9 | notarized clean-machine release and soak report |

Every incomplete item must be:

- completed
- explicitly descoped with rationale
- moved to a versioned post-release roadmap
- or declared a release blocker

### Final release criteria

MoonDesk is release-ready when:

- the first useful task is clear and tested
- optional services degrade honestly
- all mandatory CI checks pass
- warnings are clean
- public contracts are typed and reviewable
- package ownership is documented and enforced
- workspace and preview security tests pass
- runtime progress and approvals are evidence-backed
- DOCX, XLSX, PPTX, and direct Code edit/save/reopen gates pass
- localization and accessibility gates pass
- a signed, notarized artifact passes clean-machine installation and update
- current status and release notes describe limitations honestly

### Deliverables

- final readiness report
- release candidate artifacts
- current architecture and status documents
- post-release roadmap containing only non-blocking work
- archived or clearly historical superseded plans

### Exit gate

Phase 10 is complete when the project records one of two decisions:

1. **Ready**: every release criterion has evidence.
2. **Not ready**: remaining blockers, owners, and target dates are explicit.

There is no partial or implied completion state.

## Cross-Cutting Measurement

Track these measures throughout the program:

### Product

- time from first launch to first saved Wiki edit
- time from first launch to first Code prompt when runtime is available
- setup failure recovery rate
- number of internal concepts visible before the first useful action
- percentage of empty/error states with a working next action

### Architecture

- public symbols by package
- typed domain types versus string/JSON helpers
- package dependency count and cycles
- largest production files
- largest test files
- `.mbti` changes per phase

### Quality

- test count and pass rate
- warnings
- uncovered executable lines
- smoke journeys automated
- median CI duration
- flaky-test count

### UX and accessibility

- untranslated or missing keys
- keyboard-only journey pass rate
- responsive overflow failures
- inaccessible-name failures
- reduced-motion failures
- internal-error leakage

### Release

- clean-machine install success
- startup time
- bundle size
- update success and rollback success
- crash-free soak duration
- memory and file-descriptor growth

Metrics are signals, not substitutes for user and architecture judgment. A
metric may be waived only with a documented reason and owner.

## Risk Register

### Risk: package splitting expands the public API

Mitigation:

- define type ownership before moving code
- keep implementation packages internal
- use explicit facades
- inspect `.mbti` after every extraction

### Risk: contract migration creates two sources of truth

Mitigation:

- migrate one vertical slice at a time
- keep one canonical runtime record
- make compatibility adapters read-only and temporary
- set removal gates for old paths

### Risk: product simplification hides necessary power

Mitigation:

- use progressive disclosure
- retain explicit diagnostics views
- test both first-time and expert workflows
- preserve command palette access to advanced actions

### Risk: security hardening breaks valid symlink workflows

Mitigation:

- document the supported symlink policy
- distinguish safe internal links from out-of-scope links
- add migration/error guidance
- test real user library layouts before enforcement

### Risk: release automation depends on unavailable credentials

Mitigation:

- separate reproducible unsigned preview from credentialed production release
- validate all non-credentialed stages continuously
- store credentials only in protected release environments

### Risk: UI restructuring destabilizes canonical conversation behavior

Mitigation:

- stabilize the typed contract first
- retain append-order regression tests
- migrate complete vertical slices
- run reload, reconnect, stale-watch, and multi-turn smokes after each slice

## Recommended Milestones

### Milestone A: Trustworthy development baseline

Includes Phases 0 and 2.

Result:

- current truth
- mandatory CI
- warning cleanup
- reproducible preview artifacts

### Milestone B: Understandable product

Includes Phase 1.

Result:

- plain-language first run
- coherent navigation
- honest optional-service setup

### Milestone C: Maintainable core

Includes Phases 3 and 4.

Result:

- typed MoonCode contract
- narrower packages
- readable generated interfaces
- decomposed tests

### Milestone D: Safe and observable operation

Includes Phases 5 and 6.

Result:

- canonical path and preview security
- evidence-backed runtime operation
- coherent approvals, traces, and recovery

### Milestone E: First-class editing and product-quality interface

Includes Phases 7 and 8.

Result:

- working Office artifact editors
- direct Code editing with user/agent conflict handling
- consistent shell
- explicit localization
- accessibility and responsive proof

### Milestone F: Native release readiness

Includes Phases 9 and 10.

Result:

- signed/notarized clean-machine release
- update and soak evidence
- finite readiness decision

## Immediate Next Actions

Actions 1–5 are complete locally: current status and historical labels,
canonical validation and local CI configuration, zero-warning cleanup, and the
`mooncode/core` inventory/typed target. Their remote or clean-checkout gates
remain governed by the phase exit criteria above.

Continue with:

1. Retain the completed Phase 2 pull-request, push, immutable preview-run,
   downloaded-artifact, and clean-checkout rebuild evidence.
2. Continue Phase 3 with the command-submission vertical slice; capabilities,
   session listing, selected-session fetch, and canonical conversation now use
   the typed boundary.
3. Continue Phase 4 only through ownership directions already recorded in the
   package map; review calculation and preview response policy are the first
   accepted production extractions, and workspace preview is the first large
   test contract split into a behavior-named file.

The first-class Office and Code editors are owned by Phase 7. The broader UX
matrix remains owned by Phase 8. Cross-platform packaged-app and picker
evidence remains owned by Phase 9. Security design remains owned by
Phase 5; do not pull those workstreams into the next phase by inference.

Do not begin broad UI restructuring or package movement before the required
Phase 0–3 gates establish the truth, CI evidence, and target contract.
