# Wiki Mode User Experience Plan

## Purpose

Wiki mode should feel like a calm knowledge workspace for a person who wants to
read, capture, organize, improve, and publish a MoonBook. It must not require the
user to understand Moontown, MoonClaw, daemon lifecycle, ticks, run identifiers,
filesystem layout, queue internals, or transport status.

The screen's primary question is:

> What am I reading or changing, and what needs my attention next?

This plan improves presentation and interaction without moving durable truth out
of MoonBook or changing runtime ownership. Internal evidence remains available,
but ordinary work no longer competes with it.

## Implementation Status

Major upgrade slice implemented on 2026-07-10:

- Wiki navigation now uses `Library`, `Search`, `Inbox`, `Activity`, `Review`,
  and `More` while preserving compatible internal activity enums and old URL
  slugs.
- The document surface has one primary edit/save action. Favorite, original
  file, reveal, provenance, and technical location controls use explicit
  disclosures.
- Town requests and run projections are presented as user tasks with `Waiting`,
  `Working`, `Ready for review`, `Completed`, and `Needs attention` states.
- Activity now combines the task description, current page context, link/file
  capture, material list, and `Start building` action. Persisted imports remain
  in the selected book and are submitted as explicit request context.
- Inbox remains an optional reusable material library rather than a required
  stop before starting book work.
- Review is a dedicated decision surface with proposal context, an optional
  note, and adjacent accept/reject actions.
- Inbox and Search use capture and knowledge language. Paths and source-layer
  labels are no longer part of default result rows.
- Daemon, event, PID, CWD, supervision, LaunchAgent, policy, registry, and log
  information is available only under `More > Diagnostics`.
- The Wiki grid now gives its remaining width to the document, keeps labeled
  navigation visible, and uses a horizontal navigation row on phone layouts.
- Pure projection and navigation tests cover user labels, compatible slugs,
  task states, save feedback, search types, review copy, and staying in Wiki
  when a search or review result opens.

Still planned:

- model page-specific provenance relationships instead of linking to book-wide
  Activity and Review;
- complete the guided book-creation flow so its Advanced setup is never needed
  for a supported default pattern;
- automate the full browser UX lane against the canonical seeded fixture and
  native bundle across all required viewports.

## Problem Statement

The current Wiki shell exposes product implementation as if it were user work.
Examples in the current views include:

- `Daemon Lifecycle`, PID, command, CWD, state files, policy files, logs,
  LaunchAgent installation, supervision, and restart counts.
- daemon ticks, request and dispatch counts, run IDs, artifact counts, event
  sources, event kinds, and raw timestamps.
- source-layer labels, renderer labels, workspace roots, raw paths, configuration
  JSON, creation backends, and product registry ownership.
- `Town`, `Runs`, and `Settings` as equal top-level destinations even when the
  user only wants to read or edit a page.
- several controls with implementation-oriented names, single-letter icons, or
  actions whose effect is unclear without knowing the architecture.

This creates three problems:

1. Attention is spread across system health, navigation, editing, automation,
   review, and publishing at the same time.
2. Technical status looks urgent even when it does not block the user's task.
3. Forward and backward Wiki workflows are split across surfaces named after
   subsystems rather than user intentions.

Existing `.quiet-*` CSS rules reduce some immediate noise, but hiding isolated
elements is not a complete information architecture. Hidden data should be
excluded from the ordinary view composition and exposed deliberately through a
details or diagnostics surface.

## Target Users And Jobs

The primary user is a knowledge worker, researcher, writer, or project owner.
They may understand files and Markdown, but should not need MoonSuite runtime
knowledge.

Their core jobs are:

- open a book and continue where they stopped;
- read a page without surrounding operational noise;
- capture a note, URL, image, or file;
- turn captured material into a durable Wiki page;
- ask the system to research, organize, or update knowledge;
- see whether work is waiting, in progress, completed, or needs attention;
- review a proposed change and understand its sources;
- trace a published result backward to evidence and history;
- recover safely from a failed save or unavailable background service.

Operators and developers are secondary users. Their diagnostics must remain
reachable without defining the default experience.

## Product Principles

### 1. Content First

The selected page is the visual center. Navigation supports the document and
status supports the current action. Neither should dominate it.

### 2. One Primary Action Per Context

Each surface has one obvious next action:

- Library: open a page.
- Search: search.
- Inbox: save a note or import material.
- Document: read, or enter edit mode.
- Review: accept, request changes, or reject a proposed change.
- Automation: create or manage a watch.

Secondary commands move into an overflow menu or contextual details.

### 3. Progressive Disclosure

Information is divided into three levels:

| Level | Audience | Examples |
| --- | --- | --- |
| Primary | Every user | page title, content, save state, current task, review decision |
| Details | Interested user | source, last updated time, provenance, output files, task history |
| Diagnostics | Operator/developer | PID, CWD, daemon command, ticks, raw IDs, logs, policy files, transport errors |

Primary information is visible by default. Details require an explicit action.
Diagnostics live under `Settings > Diagnostics` and never open automatically
unless a blocking error provides a direct `View diagnostics` action.

### 4. Human Language Over Runtime Language

Visible labels describe user outcomes. Internal terms may appear in diagnostics
or developer tooltips, not in the main workflow.

| Internal term | User-facing term |
| --- | --- |
| Moontown request | Task |
| MoonClaw run | Activity |
| artifact | Result or file |
| standing goal | Automation or watch |
| queued dispatch | Waiting to start |
| daemon unavailable | Background work is unavailable |
| tick / next tick | Next scheduled check |
| review receipt | Decision history |
| raw evidence | Original source |
| source layer | Type, only where useful |

Product names can remain in About, diagnostics, and technical documentation.

### 5. Status By Exception

Healthy background state is silent. Show status when work is actively running,
when the user requested feedback, or when action is required. A compact task
indicator can show `Working`, `Ready for review`, or `Needs attention`; it should
not continuously report connectivity, process health, or queue counters.

### 6. Evidence Without Anxiety

Backward traceability is a product capability, not a debug dump. Present it as a
plain-language chain:

```text
Published page -> accepted change -> task result -> original sources
```

Each item gets a title, short explanation, and open action. IDs and paths belong
in expandable details.

## Target Information Architecture

### Global Shell

Keep `Desk`, `Wiki`, and `Code` as the stable product-mode switcher. In Wiki:

- show the current book name and a book switcher;
- remove routine connection and sync text from the title bar;
- show a compact attention indicator only for active or blocked work;
- place global search and the command palette in predictable locations;
- preserve the selected book and page when switching modes.

### Wiki Navigation

The default navigation should contain:

1. `Library`: Home, Wiki, Notes, and Published.
2. `Search`.
3. `Inbox`.
4. `Review`: visible when proposals need attention, otherwise available under
   `More`.
5. `Activity`: user tasks and results, not runtime telemetry.
6. `More`: Automations, Settings, and Diagnostics.

The final labels may be adjusted during usability testing, but top-level items
must describe user jobs. `Town` and `Runs` should not remain separate concepts in
the normal Wiki navigation.

### Main Document Surface

The document surface should contain:

- a restrained tab or breadcrumb for location;
- the page title and content;
- a primary `Edit` action when the page is editable;
- a clear save state only while editing: `Unsaved`, `Saving`, `Saved`, or
  `Could not save`;
- an overflow menu for Favorite, Open original, Reveal in Desk, and other
  secondary actions;
- a collapsible `Sources and history` panel for provenance and backward runs.

Do not show raw paths, renderer names, source-layer labels, or a `Command` button
in the always-visible toolbar.

### Activity Surface

Merge the user-relevant parts of Town requests, Runs, progress, and events into
one task-oriented surface:

- one composer for the requested outcome and attached links/files;
- a visible, removable list of book-owned materials and current page context;
- one `Start building` action that submits those material paths with the task;
- task title or first meaningful prompt line;
- book and optional page context;
- state: `Waiting`, `Working`, `Ready for review`, `Completed`, or
  `Needs attention`;
- a plain-language progress summary;
- result links after completion;
- `Cancel`, `Retry`, or `Review` only when applicable.

Runtime events, run IDs, counts, and logs are available from `Details`, with a
second step to `Diagnostics` for process-level information.

### Review Surface

Review should be a dedicated decision workflow rather than a small panel inside
Settings. It should show:

- what is proposed;
- why it changed;
- the affected page;
- sources used;
- a readable diff;
- `Accept`, `Request changes`, and `Reject` actions;
- an optional note close to the decision controls;
- decision history after completion.

The review view is the main backward-run entry point.

### Inbox Surface

Keep Inbox as an optional reusable material library with simple capture
language:

- `New note` with title and body;
- `Add link` and `Add files` as secondary modes or a compact segmented control;
- one preview, shown only on request or beside the editor when space allows;
- no `safe writes`, staging terminology, local intake labels, or duplicate load
  controls in the primary view.

### Automations And Book Creation

Separate frequent Wiki work from setup. Book creation and watches should be
guided flows opened intentionally from `New book` or `Automations`.

The book wizard should ask for user concepts in this order:

1. Book name and purpose.
2. Sources.
3. What to look for or produce.
4. Schedule, if automation is enabled.
5. Review preference and notifications.
6. Confirmation summary.

Hide book IDs, method paths, source policies, skill packs, creation backends,
configuration JSON, and portable-app exports under `Advanced setup`.

### Settings And Diagnostics

Settings contains user preferences and book behavior. Diagnostics is a separate
subpage with an explicit technical warning and copy/export actions. It owns:

- daemon lifecycle and supervision;
- LaunchAgent installation;
- PID, command, CWD, logs, state and policy files;
- raw task/run/event identifiers;
- service health and transport details;
- registry and path ownership information.

Diagnostics must not be required to complete a normal forward or backward run.

## Forward And Backward Wiki Runs

### Forward Run

```text
Capture or select source
  -> create a task or edit a draft
  -> quiet progress indicator
  -> proposed Wiki change
  -> review when required
  -> accepted page and published result
```

The user sees intent, progress, proposal, and outcome. Runtime routing remains
behind the task projection.

### Backward Run

```text
Open published page or result
  -> open Sources and history
  -> inspect accepted change
  -> inspect task result and original sources
  -> revise, request follow-up, or record a review decision
```

The backward path must be available from the content itself; users should not
need to know that evidence is stored under `raw/analysis-runs` or a product home.

## Surface-Level Change Map

| Current module | Planned responsibility |
| --- | --- |
| `moonwiki_shell_views.mbt` | stable Wiki shell and responsive composition |
| `moonwiki_views.mbt` | user-job navigation and accessible icon labels |
| `moonwiki_workspace_views.mbt` | book/page navigation without roots or source-layer noise |
| `moonwiki_preview_center_views.mbt` | content-first reading, editing, save states, overflow actions, provenance entry |
| `moonwiki_inbox_views.mbt` | focused note/link/file capture modes |
| `moonwiki_search_views.mbt` | human-readable results with paths in optional details |
| `moonwiki_town_views.mbt` | split into task creation, activity projection, automation, and advanced setup |
| `moonwiki_run_views.mbt` | fold results into Activity; retain raw projection for details |
| `moonwiki_settings_views.mbt` | preferences and summary only; move Review out |
| `moonwiki_daemon_lifecycle_views.mbt` | Diagnostics-only surface |
| `moonwiki_town_status_views.mbt` | derive concise user states; technical events remain diagnostics |
| `app_shell_model.mbt` / `app_state.mbt` | navigation state for Review, Activity, More, and progressive disclosure |
| `styles.css` | restrained hierarchy, responsive behavior, focus states; remove reliance on blanket `.quiet-*` hiding |

The backend route contracts and durable record formats should remain stable in
the first implementation. Presentation helpers should project internal records
into user-facing task, review, provenance, and status models.

## Implementation Phases

### Phase 0: Baseline And Guardrails

- Capture desktop, narrow desktop, and phone screenshots for Files, Inbox,
  Search, Town, Runs, Settings, edit mode, review, empty, loading, and failure
  states.
- Inventory every visible label and classify it as Primary, Details, or
  Diagnostics.
- Add stable semantic selectors for major Wiki surfaces and primary actions.
- Record task completion time and visible-control count for the canonical
  forward and backward journeys.

Exit gate: the team can identify which information is moving, where it remains
accessible, and which existing behaviors must not regress.

### Phase 1: Quiet Shell And Content-First Document

- Replace single-letter activity glyphs with the existing icon library or
  accessible icon-and-tooltip controls.
- simplify the title bar and Wiki navigation;
- make Library, Search, and Inbox the default visible destinations;
- consolidate secondary document commands into an overflow menu;
- implement explicit editor save states and unsaved-change protection;
- add `Sources and history` as a stable document action.

Exit gate: a user can open, read, edit, and save a Wiki page without seeing
runtime terminology or unrelated controls.

### Phase 2: User-Facing Activity And Review

- Create a pure projection from requests, runs, progress, events, and review
  records to user-facing task states.
- Replace separate Town and Runs navigation with Activity and Automations.
- Move Review Queue from Settings into a full review workflow.
- Add provenance links from completed activity and review records back to pages
  and sources.
- Keep raw run/event data in expandable details.

Exit gate: forward and backward runs can be completed without opening
Diagnostics or reading an internal identifier.

### Phase 3: Capture, Search, And Creation Cleanup

- Simplify Inbox into note, link, and file capture modes.
- Remove source-layer badges and raw paths from default search results; retain
  book, title, useful snippet, and a user-facing type when needed.
- Rebuild book creation as a short guided flow with optional Advanced setup.
- Move portable exports and implementation configuration out of ordinary Wiki
  creation.

Exit gate: first-time users can create a book and capture material without
understanding MoonSuite storage or execution architecture.

### Phase 4: Diagnostics Boundary And Failure Recovery

- Move daemon and LaunchAgent controls to Settings > Diagnostics.
- Translate service failures into user-impact language with retry actions.
- Show technical details only after `View diagnostics`.
- Ensure local reading, editing, inbox, search, and provenance continue when
  background services are unavailable.
- Provide bounded copy/export of diagnostics for support.

Exit gate: healthy system state is silent, recoverable failures are actionable,
and technical detail remains available to operators.

### Phase 5: Responsive, Accessible, And Polished

- Verify keyboard order, visible focus, semantic headings, screen-reader names,
  and no icon-only ambiguity.
- Keep touch targets at least 44 CSS pixels on touch layouts.
- Define responsive navigation and document actions for phone, tablet, and
  desktop without hiding the primary action.
- Verify text wrapping, long titles, Unicode names, zoom, reduced motion, empty
  states, and high-contrast behavior.
- Keep the light, neutral workspace palette and ensure no theme falls back to a
  black page background.

Exit gate: the canonical workflows remain complete and legible at every
supported viewport and input method.

## End-To-End Validation Plan

Extend `WIKI_MODE_TEST_PLAN.md` with a user-experience lane. Browser tests must
use the built UI, real host, seeded MoonBook, route assertions, and filesystem
assertions.

### UX E2E 1: First Open And Reading Focus

Open Wiki on a seeded book and read `wiki/index.md`.

Assert:

- the book, page title, and page body dominate the first viewport;
- Library, Search, and Inbox are immediately understandable;
- no PID, CWD, tick, daemon, dispatch, run ID, raw path, renderer, source layer,
  or registry text appears in the ordinary view;
- one clear `Edit` action is available for editable Markdown;
- no black background or low-contrast fallback appears before or after loading.

### UX E2E 2: Focused Markdown Edit

Open a Wiki page, edit it, save, simulate a failed save, and navigate with an
unsaved draft.

Assert:

- edit mode exposes only editing-related primary actions;
- save state progresses through user-facing states without raw host messages;
- failed save preserves the draft and offers retry;
- navigation does not silently discard unsaved content;
- the saved file and preview contain the exact final text.

### UX E2E 3: Capture To Accepted Knowledge

Create an Inbox note, promote it to a Wiki proposal, review it, and accept it.

Assert:

- capture uses note/link/file language rather than staging or safe-write terms;
- the task has a human title and plain-language state;
- the review explains page, change, and sources before asking for a decision;
- acceptance writes the expected Wiki content and durable decision record;
- internal paths remain absent until Details is opened.

### UX E2E 4: Task To Result

Create a Wiki-oriented task against the selected page and use seeded progress to
complete it.

Assert:

- the UI says Waiting, Working, Ready for review, or Completed as appropriate;
- only the current task creates a visible progress indicator;
- result links open in the selected book without switching to Code;
- raw events and IDs are hidden by default but available in Details;
- reload preserves the task and result state.

### UX E2E 5: Backward Provenance

Open a generated page, then follow Sources and history to an accepted change,
task result, and original source.

Assert:

- each step has a human title and relationship label;
- the user never has to navigate a filesystem path manually;
- the selected book remains stable;
- source evidence is read-only;
- a follow-up or revision can be started from the provenance view.

### UX E2E 6: Review Decisions

Accept one proposal, request changes on another, and reject a third.

Assert:

- decision actions are adjacent to the diff and note field;
- destructive or rejecting actions require clear intent;
- completed decisions leave readable history;
- rejected content does not alter the accepted Wiki page;
- pending-review count clears only after durable success.

### UX E2E 7: Background Service Unavailable

Run Wiki with Moontown and MoonClaw unavailable.

Assert:

- reading, local editing, Inbox, Search, and generated preview still work;
- no daemon error dominates the shell;
- task creation explains that background work is unavailable and offers retry;
- `View diagnostics` reveals the bounded technical reason;
- restoring the service recovers without a full application restart.

### UX E2E 8: Diagnostics Disclosure

Start from the default Wiki surface and open Diagnostics deliberately.

Assert:

- no diagnostics content exists in the ordinary accessibility tree;
- Settings requires an explicit navigation action to reach Diagnostics;
- PID, command, CWD, logs, policy files, supervision, and LaunchAgent controls
  appear only there;
- closing Diagnostics returns focus and context to the originating surface.

### UX E2E 9: Search Clarity

Search across Wiki pages, Inbox notes, original sources, reviews, and results.

Assert:

- results lead with title, book, useful type, and bounded snippet;
- paths and internal source layers are hidden in default rows;
- opening Details reveals provenance when relevant;
- keyboard selection, empty query, no results, large results, and failure states
  remain understandable.

### UX E2E 10: Responsive And Accessible Workflows

Repeat reading, editing, capture, task review, and backward provenance at phone,
tablet, and desktop widths using keyboard-only and touch-sized controls.

Assert:

- no overlapping, clipping, horizontal page scroll, or hidden final action;
- navigation collapses predictably and restores context;
- focus order follows visual order and focus is always visible;
- icon controls have accessible names and tooltips;
- long page titles, book names, filenames, and translated text wrap safely.

## Unit And Integration Coverage

Add focused MoonBit tests for:

- internal-to-user task state projection;
- status-by-exception rules;
- vocabulary mapping and fallback copy;
- Primary, Details, and Diagnostics visibility decisions;
- navigation state and return-focus behavior;
- editor save-state transitions and unsaved-draft protection;
- provenance chain ordering and missing-link states;
- review actions and durable-success gating;
- diagnostics redaction and bounded output;
- responsive class/state selection where represented in the model.

Existing route and filesystem security tests remain mandatory. The UX change
must not weaken scoped paths, write restrictions, durable review receipts, or
mode-boundary behavior.

## Success Metrics

Use these as release gates rather than aesthetic aspirations:

- Zero runtime implementation terms in the default reading and editing views,
  measured against the blocked vocabulary in UX E2E 1.
- At most one visually dominant action in each primary surface.
- Forward run completion without opening Settings, Diagnostics, Desk, or Code.
- Backward provenance completion in four relationship steps or fewer.
- No normal workflow requires copying or interpreting a path or ID.
- All blocking failures explain user impact and provide a next action.
- No layout overlap or horizontal page scroll at supported viewport sizes.
- All primary workflows pass keyboard-only validation.
- Existing Wiki route, filesystem, security, and mode-boundary suites continue
  to pass.

## Non-Goals

- Replacing MoonBook, Moontown, or MoonClaw ownership contracts.
- Removing operator diagnostics or audit evidence.
- Redesigning Desk or Code mode beyond shared title-bar consistency.
- Adding domain-specific research workflows to Moondesk core.
- Changing durable record formats solely to make labels easier to render.
- Treating visual polish as a substitute for forward/backward workflow proof.

## Definition Of Done

The Wiki UX improvement is complete when a first-time user can open a MoonBook,
read and edit a page, capture a source, run a task, review a proposal, and trace
a result back to evidence without encountering unexplained architecture terms.
Operators must still be able to inspect the complete technical state through an
intentional Diagnostics surface, and all canonical forward/backward E2E,
security, persistence, and responsive tests must pass against the native bundle.
