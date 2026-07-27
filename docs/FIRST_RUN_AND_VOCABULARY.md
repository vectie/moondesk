# First Run And Navigation Vocabulary

| Field | Value |
| --- | --- |
| Status | Phase 1 quickstart executable; broader Phase 1 acceptance open |
| Evidence | Current MoonBit views, state, and tests in `ui/rabbita-desk/main/`; `ui/rabbita-desk/DEVELOPMENT.md` |

This document deliberately separates **current evidence** from **target behavior**. “Target” rows are requirements, not claims that the product already implements them.

## Three-sentence product promise (target)

MoonDesk helps you open or create a MoonBook and keeps its pages, files, conversations, runs, reviews, and published outputs in one place. You can move from writing to code-assisted work without learning MoonSuite service topology, while MoonDesk shows whether optional capabilities are ready before offering dependent actions. Your book remains the durable source of truth, and runtime progress is shown only when evidence supports it.

## Current evidence

The shell now presents Home, Pages, Code, Requests, Runs, Review, and Publish
as distinct primary destinations. The Pages activity rail contains Pages,
Search, Inbox, and Settings; it no longer duplicates Requests or Review. Flow
and Packs remain secondary Commands destinations. Exact primary routes and
legacy aliases are both covered. Home renders a `MoonBooks` workspace list,
library location, refresh control, capability setup, new-book panel, file
browser, details, quick access, and folder outline. Code has session,
transcript, activity, service, package/test/review, loading, retry, and error
projections; Requests and Review have operator projections. Existing tests
cover bootstrap/navigation, Home keyboard behavior, Pages UX, Code sessions
and source-pane synchronization, command palette, app-tool navigation, and
flow views, but they do not prove the complete target matrix or all required
viewports.

Current evidence is uneven: individual surfaces contain empty/loading/error copy
and runtime status, but there is not yet one exhaustive state contract covering
every surface. Command 011 adds the first bounded UI slice: a private six-case
`CapabilityState`, a deterministic pure classifier with explicit precedence,
exact plain-language title/detail and primary-action mappings, and focused
tests for every state, precedence edge, action, label, and current daemon
mapping. Code setup and workspace service summaries now consume that mapping
and use the ordinary labels **Code assistance** and **Requests**; the exact
service name is confined to Code's optional technical disclosure.

Current Code runtime integration prioritizes explicit host-owned platform,
installation, and configuration evidence and never parses message strings.
Managed ownership is separate from installation: a configured external service
can be installed and stopped, while observed installation evidence without
required configuration is misconfigured. The host reports normalized platform
and architecture evidence in every daemon-status response.
`UnsupportedPlatform` is selected only when that record explicitly reports
false; older responses without the optional evidence records retain their
structured-field compatibility behavior. Platform, architecture, evidence
sources, and stable reasons stay inside the Code technical disclosure.

Requests uses the same six-state vocabulary over its separate Town lifecycle
DTO. The host reports platform support plus installation evidence from a
configured service or a matching-root LaunchAgent. Explicit false evidence can
therefore select NotInstalled or UnsupportedPlatform; a configured stopped
service selects InstalledStopped; an installed but invalid setup selects
Misconfigured. Missing optional evidence preserves older-response behavior.
Platform, architecture, installation source, and configuration paths remain
inside Technical details, and request staging remains enabled in every state.

Flow preparation now has a separate read-only readiness probe. Its host
evidence distinguishes platform support, MoonBit command availability,
configured runtime root, and root validity without executing Flow. Durable run
history remains visible when preparation is explicitly unavailable; only
**Prepare** and **Ingest latest revision** are removed, and the update layer
also refuses a dispatched preparation action. Missing readiness evidence from
an older host preserves the earlier structured behavior.

Responsive and keyboard behavior exists in parts of the UI, but
the four acceptance sizes below are not comprehensively proven by source tests.
This is evidence for a bounded Phase 1 slice, not a Phase 1 completion claim.

## Implemented bounded cold-start evidence

Command 012 implements a private five-state classifier over actual `Model`
evidence with strict precedence: loading; no known workspace metadata paths and
zero books; zero books with a known library; exactly one book; many books. Desk
uses exact plain-language title/detail and primary-action mappings with stable
state/action hooks. Loading offers **Refresh** without claiming failure; missing
metadata offers **Choose library folder**; a known empty library opens the existing
**Add MoonBook** disclosure by default so Create and Import are directly
reachable without automatic creation. Once books exist that disclosure remains
closed, and existing selection preservation plus deterministic first-book
fallback remain the navigation behavior.

Commands 015–016 and the independent repair implement the bounded
**Choose library folder** contract. The packaged and generated live desktop
manifests grant only the file-dialog permission required by the native
directory picker. The UI reports selection, cancellation, unavailable bridge,
and picker errors explicitly beside the library control rather than keeping the
result only in hidden model state. The host validates the selected absolute folder,
rejects filesystem roots, missing folders, source checkouts, and individual
MoonBooks, normalizes a selected `books` folder to its owning suite, prepares
the standard layout, stores the preference under the stable bootstrap root,
and switches subsequent API requests to the active root. Cancellation or
validation failure preserves the existing active root.

Focused evidence covers the static and generated desktop grants, picker
response parsing, UI transitions, persistence/restore, layout preparation,
unsafe-folder rejection, and a live HTTP root switch. A fresh packaged macOS
build now also proves an app-owned native panel, cancellation, exact
single-MoonBook rejection, valid library selection, one ready fixture book,
subsequent API use of the new root, and a preference saved under the stable
bootstrap location. The browser-host quickstart separately proves the
empty-library create/save/Code/restart path described below.

The packaged build used for acceptance exposed and closed several
prerequisites:

- the picker’s asynchronous command declaration was unreachable through the
  synchronous native drain, so the bridge request hung before opening a panel
- the first recovered panel was owned by a separate script process and was not
  accessible through MoonDesk
- the packaged WebView could race localhost readiness once and remain on
  “Connecting” until a manual Refresh

File-dialog commands are now synchronous main-thread modal commands, macOS uses
an app-owned Cocoa panel, and a cold-start metadata failure retries only the
data-fetch batch before any root has been established. One-time observers and
import polling remain single-owner. The host’s corrective rejection message is
preserved instead of being replaced by a generic UI error.

The same work retained the earlier package-pipeline fix: async runtime,
sidecar, UI, and launcher steps could race, and the outer command ignored their
result. Those steps are now ordered and failure is propagated. A fresh positive
build completed cleanly; a missing-UI negative build emitted no success claim
and exited 1.

The macOS interaction, saved preference, and no-Refresh relaunch restoration
are proven. Other supported desktop platforms remain open. Detailed evidence
is in
`NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md`.

## Exact cold-start paths

| Starting condition | Required path | Completion signal |
| --- | --- | --- |
| No library configured | Launch → Desk explains that a MoonBook library is needed → **Choose library folder** → validate readable/writable location → show empty-library setup | Library location is visible; creation is enabled, with no false runtime warning |
| Library configured, zero books | Launch → Desk shows “No MoonBooks yet” → **Create MoonBook** → enter name/location → create and select it → open Wiki | Selected book is visible and the first page action is available |
| Exactly one book | Launch → restore/auto-select that book → Desk summary → **Open Wiki** (last valid surface may be restored only when evidence exists) | Book identity remains visible and the chosen surface has a useful primary action |
| Many books | Launch → Desk book chooser with recent/selected context → **Open selected book**; search/filter is secondary → restore that book’s last valid surface | Exactly one selected book scopes Wiki, Code, Runs, Review, and Publish |

Failure at any step must retain the entered choice, explain the problem in user vocabulary, and offer one retry or corrective primary action. The checked-in browser quickstart proves the configured-empty-library path through host restart. The packaged macOS no-library path now has cancellation, rejection, valid-selection, persistence, and no-Refresh relaunch evidence. The one/many-book selection matrix now passes in the browser at all four specified viewports; other supported desktop platforms and the broader responsive, screen-reader, and packaged-native keyboard matrices remain open.

The first row has focused host/UI proof and real packaged macOS launch,
app-owned visual picker interaction, cancellation, unsafe-folder rejection,
valid activation, saved-preference evidence, and relaunch restoration. It does
not yet have cross-platform native evidence.

## Visible-copy inventory

| Current visible vocabulary/evidence | User meaning | Classification / target treatment |
| --- | --- | --- |
| MoonBooks, book, page, file, folder, conversation, run, review | Primary user objects | Keep; use singular/plural consistently |
| Desk | Book and file home | Rename target label to **Home**; retain “Desk” only in developer identifiers during migration |
| Wiki | Pages and knowledge work | Target **Pages**; “Wiki” may be optional explanatory copy |
| Code | Assisted coding conversation/work | Keep **Code** |
| Town | Requests/scheduled work | Target **Requests**; hide MoonTown topology |
| Runs | Runtime evidence/history | Keep **Runs** |
| Review | Evidence and approval | Keep **Review**, scoped to selected work |
| Publish | Produce/export a usable output | Keep **Publish** |
| Settings | Product, library, and capability configuration | Keep **Settings** |
| MoonGate, MoonClaw, MoonTown, daemon, managed install, AI boundary, VFS, workspace ID, session ID, transport, projection | Internal architecture/diagnostics | Do not lead with these terms; place exact names/IDs under **Technical details** |
| Refresh, Retry, Install, Start, Create MoonBook | Actions | Keep when they are the single corrective/primary action; avoid competing primaries |

Command 042 adds the first browser-backed rendered-copy slice for Home’s Code
assistance card. The broader audit must still enumerate every rendered literal
and localization key across every route and state; this inventory is not a
claim of exhaustive extraction.

### Implemented bounded first-use copy evidence

The Home sidebar previously contradicted this document. Its ordinary optional
capability card led with internal authority and service names, selected state
through a second boolean branch, and rendered raw daemon and installation
messages outside disclosure.

Home and Code now share the same six-state classifier, plain-language
title/detail mapping, and action allowlist. Home exposes the stable capability
state key and offers only Start, Install, Review configuration, Check again, or
no action. Its ordinary summary and generic installation progress are separate
render functions that never receive or render raw diagnostic text. One closed
**Technical details** renderer owns the exact service name, raw service and
installation messages, platform/architecture/support evidence, managed
installation/process facts, and authority boundary.

Fifteen focused capability tests cover all six Home state keys, their rendered
action allowlists, independently rendered ordinary and technical markup, closed
disclosure, generic install progress, and the shared Code summary. They also
render the actual Code setup for all six typed states. Running alone hides
setup; every non-ready state owns the setup layout row and stable state key.
In particular, a missing daemon-status response now renders
`temporarily-unavailable`, **Check again**, and a closed diagnostic disclosure
instead of making setup disappear. The first
real browser proof initially exposed a second copy defect: the ready Code card
said “Requests can be handled now.” The shared six-state explanations now
describe Code conversations and explicitly preserve Pages/files when the
capability is unsupported or temporarily unavailable.

A fresh production build and full populated browser smoke pass. The retained
proof record `desk-first-use-copy-proof.json` reports
`moondesk-first-use-copy-partial-proof.v1`, state `detected-running`, no
`MoonClaw`, `MoonGate`, `daemon`, or `AI boundary` term in the ordinary visible
card, the exact diagnostics inside a closed disclosure, and the corrected
conversation copy. The 1440×900 screenshot was inspected at original
resolution. This closes only the Home Code-assistance copy slice; every other
route/state and the localization-key audit remain open.

Command 057 expands rendered browser evidence without expanding that claim to
the full responsive matrix. One deterministic CDP scenario supplies explicit
platform, installation, configuration, running, and HTTP-availability evidence
to the actual host/UI response paths. At 1440×900 it proves all six Code states,
all six Requests states, and Flow ready versus capability-limited. Every case
checks the stable state key, visible title and explanation, applicable visible
action, closed technical disclosure, and absence of private fixture values from
ordinary copy. The versioned proof is
`moondesk-rendered-capability-state-proof.v1`.

Original-resolution screenshot review found one additional defect: Flow’s
capability-limited title and explanation were present only in the visually
hidden polite announcement, leaving sighted users with only `Technical
details`. Flow now renders the typed title and explanation visibly as well as
announcing them, and the browser proof geometry-checks those visible nodes.
This slice does not prove keyboard order, focus restoration, smaller
viewports, large text, localized copy, manual screen-reader output, packaged
native behavior, or other optional capabilities.

Command 058 closes the next bounded keyboard seam without broadening it into a
full accessibility claim. At 1440×900, every capability-state navigation starts
from natural document focus and uses only real CDP Tab, Space, Escape, and
Shift+Tab events. The executable matrix reaches, opens, closes, and
reverse/forward round-trips the exact owned **Technical details** summary for
all six Code states, the five Requests states with structured lifecycle
evidence, and all five capability-limited Flow cases. Every traversed target
must be connected, visible, enabled, inside the viewport, and visibly focused.
Escape must close the native disclosure and return focus to the exact triggering
summary.

The versioned record
`moondesk-capability-keyboard-focus-proof.v1` contains 16 cases: six Code, five
Requests, and five Flow. It explicitly records natural document focus and no
programmatic focus. The proof exposed a focusable Flow composition canvas whose
active selector suppressed its visible outline; the canvas now receives a
three-pixel `:focus-visible` accent outline, and the unrelaxed traversal passes.
Original-resolution Code, Requests, and Flow screenshots show the exact closed
summary with a strong focus ring. This remains a disclosure-restoration subset,
not whole-page focus order, responsive geometry, manual screen-reader behavior,
localization, or packaged-native keyboard acceptance.

Command 059 closes the ordinary-scale responsive geometry seam for these same
capability surfaces. The versioned
`moondesk-capability-responsive-geometry-proof.v1` record contains 72 unique
rendered cases: six evidence cases on Code, Requests, and Flow at exactly
1440×900, 1024×768, 390×844, and 320×700. Every case begins at document scroll
position zero and proves no horizontal overflow, an unclipped state panel,
visible title/detail, the correct closed-or-absent disclosure, a fully visible
applicable action, correct desktop/compact navigation, no pane overlap, and
usable primary work.

The proof changed product structure rather than accepting below-fold actions.
Flow state and `Start governed run` now precede its large composition canvas;
secondary handoffs no longer inflate the primary state panel. Compact Code
setup wraps within the viewport, including its action and Technical details.
Screenshot review additionally found overlapping compact Flow canvas controls;
the title and tool row now stack without clipping, and the proof measures every
control plus title/tool overlap. Sixteen original-resolution screenshots cover
Code not installed, Requests misconfigured, and both Flow boundaries at every
viewport. This remains ordinary-scale responsive evidence, not capability-state
200% text, manual screen-reader, localization, or packaged-native acceptance.

Command 060 closes the corresponding capability-state large-text seam. The
versioned `moondesk-capability-scale-proof.v1` record contains 54 unique cases:
all six evidence cases on Code, Requests, and Flow at 200% browser-zoom
equivalence (720×450), text-only 200% at 1440×900, and text-only 200% at
320×700. Every case proves exact state and viewport, no horizontal overflow,
reachable and unclipped state content, readable applicable actions, the correct
Technical-details contract, usable destination controls, and non-overlapping
primary work.

The text-only runner snapshots every connected element before scaling and
proves full scale coverage before geometry and after screenshots, followed by
complete marker removal. This exposed product defects that ordinary responsive
tests could not find: ready-card header overflow, Flow empty-state minimum
width, single-line Code actions, a non-wrapping desktop setup row,
short-height Code disclosure clipping, an unusable compact session rail, and a
clipped Flow Refresh control. The repaired layouts wrap or provide a real
reachable scroll path without hiding the corrective capability action.
Twelve original-resolution screenshots cover Code not installed, Requests
misconfigured, and both Flow boundaries in every scale mode. This remains a
capability-state scale matrix, not whole-page keyboard order, manual
screen-reader, reduced-motion, localization, packaged-native input, or
cross-platform acceptance.

Command 061 closes the next bounded page-level keyboard and transient-focus
seam. The versioned `moondesk-page-keyboard-transient-proof.v1` record contains
exactly 18 fresh-navigation cases:

- Home Storage & services at 1440×900, 1024×768, 390×844, and 320×700
- not-installed Code-assistance Technical details at the same four viewports
- the command palette at the same four viewports
- a deterministic Code-session action menu at the same four viewports
- compact primary navigation at 390×844 and 320×700

Every journey begins at natural document focus and uses real Tab/Shift+Tab,
alternating Space/Enter, and Escape. The palette cases also alternate the
documented Meta+K and Control+K shortcut. Every traversed target is connected,
visible, enabled, inside the scroll viewport, and visibly focused. Escape
closes the exact owned surface, restores the exact trigger, and is followed by
a reverse/forward round trip to that same trigger.

The palette now owns source-rendered modal-dialog semantics, a named search
input, stable panel/input/close hooks, input autofocus, a forward/reverse Tab
trap, topmost Escape behavior, and exact trigger restoration. Application
shortcuts no longer fire from editable controls. On compact layouts the
shortcut returns to the visible pre-open summary rather than the hidden
Commands button. Session-menu traversal reaches Rename first, and compact
navigation reaches Requests before Escape restores its summary.

Machine audit reports 18 unique cases, 18 exact restorations, 18 round trips,
and 18 screenshots. Review of every original-resolution screenshot confirms
visible focus and usable opened surfaces at all four viewports. This remains a
bounded browser-host matrix, not manual screen-reader speech, live-region
announcement order or deduplication, reduced-motion completion, packaged
native keyboard behavior, localization completion, or cross-platform
acceptance.

## Current-to-target navigation vocabulary

| Current | Target label | Target destination contract |
| --- | --- | --- |
| Desk | Home | Book choice, files, recent work, first-run setup |
| Wiki | Pages | Read, create, find, and edit book pages |
| Code | Code | Conversations and code-oriented work for the selected book |
| Town | Requests | Queued/scheduled requests without service topology |
| Runs | Runs | Evidence-backed current and historical execution |
| Review | Review | Changes, evidence, decisions, and approval |
| Publish | Publish | Validate, package/export, and locate output |
| Settings | Settings | Library, appearance, keyboard, and capabilities |

Implemented primary order: **Home, Pages, Code, Requests, Runs, Review,
Publish**; Settings is a Pages utility destination.

### Implemented bounded navigation evidence

Command 013 introduced the shared vocabulary source. Command 026 completes the
bounded primary-navigation structure: the desktop order is **Home**, **Pages**,
**Code**, **Requests**, **Runs**, **Review**, **Publish**; Meta/Control+1 through
+7 select those destinations; and every command palette exposes the same seven
entries. Flow and Packs remain secondary Commands destinations.

At 760 pixels and below, one native disclosure replaces the desktop strip. Its
summary names the current destination, its seven actions have unique hooks, and
real browser key events prove opening and selection at 320×700 without
horizontal document overflow. Pages now owns only **Pages**, **Search**,
**Inbox**, and **Settings** in its internal rail.

Exact routes `home`, `pages`, `code`, `requests`, `runs`, `review`, and
`publish` select distinct workspace identities. Legacy aliases such as `desk`,
`library`, `files`, `wiki`, `mooncode`, `activity`, `town`, `flow`,
`moonflow`, `packs`, `more`, and `settings` remain accepted. Runs distinguishes
no selected book from no run history and exposes result files without leading
with IDs. Publish checks review readiness and offers the generated output
location without claiming that output exists. A broader rendered-literal and
localization audit is still required.

## Implemented bounded shared-state evidence

Command 014 introduces the private eight-case `SurfaceState` contract and
stable keys. Pages search is its first typed consumer. Its surface-owned
titles/details, primary-action mappings, and separately disclosed technical
details remain search-specific. Its
model state is optional so a successful nonempty result is represented as
ready content rather than left falsely “loading.” Explicit transitions now
cover first use, query editing, active search, legitimate zero results,
successful results, and recoverable failure; the view does not infer state by
parsing `search_status`.

The Search/Retry control remains the single primary action, is disabled while
loading, and the state panel has stable `data-state` and test hooks. The legacy
search route still returns its original array. The current UI opts into the
private `pages-search.v1` envelope, whose exact contract, success flag, stable
status, query, optional workspace scope, message, and hits provide host-owned
evidence. A successful empty response is now the only route to
`LegitimateZero`; an unknown explicit workspace cannot become “No results,” and
a missing or unreadable selected root becomes `CapabilityLimited`.

The query that produced current hits is stored separately from the editable
query. Refreshing the same query keeps prior rows through `Loading` and selects
`Stale` on failure. Editing the query clears those rows, so different-query
results are never relabeled as current. `workspace-not-found` has an explicit
terminal mapping and host-route proof, although the current all-books UI does
not send a workspace filter. `Disconnected` remains contract-only because the
browser adapter does not retain transport error identity. Raw host/decode
details remain inside a closed Technical details disclosure. Five Pages-focused
tests, one scope test, the owning HTTP integration, and an isolated live host
probe cover the bounded contract; unreadable recursive descendants and
individual files remain outside it.
Review is now the second typed consumer. Opening or refreshing Review records
Loading without discarding prior items; an explicit empty success becomes
LegitimateZero; nonempty success renders ready content; a failed refresh with
prior items becomes Stale; and failure without prior items becomes
RecoverableError. Review owns its own copy, exposes `review-state-panel` and a
stable state key, retains stale items, offers retry, and hides the raw error
under Technical details. Two focused tests cover those transitions and the
rendered contract. Requests is the third typed consumer. Its ledger starts at
first use, enters Loading on selection or refresh, distinguishes an explicit
empty success from ready records, retains prior records as Stale after refresh
failure, and uses RecoverableError when no prior records exist. Composer
feedback remains separate, raw ledger errors stay under Technical details, and
request staging remains available when automation is degraded. Three focused
tests and the empty-library browser smoke cover its transitions and rendered
contract.

Runs is the fourth typed consumer. Its state starts at first use; explicit and
automatic book selection enter Loading; explicit empty success becomes
LegitimateZero; nonempty success becomes ready content; refresh failure keeps
prior records as Stale or becomes RecoverableError without prior records.
Changing the automatically selected book clears the previous book’s cached
runs. One stable `runs-state-panel` owns the visible state, while raw errors and
run IDs remain under Technical details. Loading and stale states retain result
records and their file actions. Four focused tests and the empty-library
browser smoke cover actual transitions, all eight rendered mappings, and honest
zero. Disconnected, capability-limited, and terminal Runs states remain
contract-level cases until host evidence can select them. Additional
surface-state ownership and evidence slices remain open.

Publish is the fifth typed consumer and owns readiness state separately from
Review. It enters Loading when selected with a book; explicit empty review
evidence becomes LegitimateZero; nonempty evidence becomes ready content; a
failed refresh retains prior items as Stale or becomes RecoverableError without
items. Explicit/automatic book changes and library replacement clear prior
book evidence, and a recorded review decision invalidates Publish until its
existing queue refresh completes. `publish-state-panel` owns the exact state
key. Loading and stale states retain only labeled earlier evidence; failure
without evidence cannot render the output-check action. Legitimate zero proves
only zero review blockers, so the UI still asks the user to inspect the known
output location and never claims output exists. Four focused tests plus empty
and quickstart browser journeys cover this contract. Disconnected,
capability-limited, and terminal states remain contract-level cases. This is
bounded Phase 1 evidence rather than completion.

Code session listing is the sixth typed consumer, bounded to catalog transport
rather than conversation execution. Entering Code with explicit running-daemon
evidence starts Loading without discarding prior rows. A successful empty
listing becomes LegitimateZero; a nonempty listing renders ready rows; a failed
refresh retains prior rows as Stale; and failure without rows becomes
RecoverableError. The stable `mooncode-sessions-state-panel` owns the state key
and raw listing errors stay under Technical details. Group-level “No chats”
copy and search-level “No matching chats” copy require a successful listing, so
loading and failure cannot masquerade as empty success. Capability setup,
archived-history failure tolerance, transcript projection, watch state, and
canonical conversation reconciliation remain separately owned. Five focused
tests plus the clean-workspace quickstart cover this bounded contract.
Disconnected, capability-limited, and terminal listing states remain
contract-level cases.

Home file listing is the seventh typed consumer. Each listing result carries
the workspace, directory, and monotonically increasing generation that issued
it; a response for an abandoned location or superseded same-folder request is
ignored instead of replacing current evidence. Moving to another workspace or
directory clears the old rows, while refreshing the same folder retains its
rows and labels them Loading. Explicit empty success becomes LegitimateZero,
nonempty success becomes ready content, failure with retained rows becomes
Stale, and failure without rows becomes RecoverableError. Raw host errors
remain under Technical details. A filtered zero appears only after a successful
listing, so loading or failure cannot masquerade as “No matching files.” Seven
focused tests and the populated multi-viewport browser smoke cover the mapping,
cross-location and same-location response ordering, row retention, rendering,
and successful-only filter zero.

Selected file/page preview is the eighth typed consumer. Each response carries
the workspace, path, and monotonically increasing request generation that
issued it. Late responses for another location and superseded same-location
responses are ignored. Same-location refresh retains its preview through
Loading and Stale; a different selection clears the old preview. Host
diagnostics remain separate from ordinary copy, and presentation does not parse
`preview_status` to infer transport truth.

Flow run listing is the ninth typed consumer. Its global host response remains
intact while the selected-book presentation filters rows. Explicit successful
empty evidence becomes LegitimateZero; nonempty evidence becomes ready;
failure with retained rows becomes Stale; and failure without rows becomes
RecoverableError. Retry enters Loading, raw listing failure stays inside
Technical details, and preparation progress uses a separate boolean instead of
parsing visible status copy.

The saved-view catalog is the tenth typed consumer. It begins at first use and
enters Loading on Settings entry, explicit refresh, global refresh, and the
post-save catalog reload. Only a successful empty response becomes
LegitimateZero. A failed refresh keeps earlier rows as Stale, while failure
without rows becomes RecoverableError. Save-operation progress and failure are
owned separately from listing transport. Raw catalog errors stay in a closed
Technical details disclosure, and the failure presentation cannot render
`No saved views yet`. Disconnected, capability-limited, and terminal mappings
remain contract-only because the current endpoint supplies no such evidence.

The workspace catalog is the eleventh typed consumer and now owns the evidence
that drives Desk cold start. Initial bootstrap, library selection, global
refresh, book creation/import, and portable-tool export reloads enter Loading.
A successful empty response alone selects LegitimateZero and enables the
create/import presentation. Failure without rows becomes RecoverableError and
offers Refresh instead of claiming there are no MoonBooks. Failed refresh with
retained rows becomes Stale and keeps those rows visible. Missing library
metadata remains a separate choose-library state, and switching libraries
clears rows that belonged to the previous library. Raw catalog errors stay in
a closed Technical details disclosure. Disconnected, capability-limited, and
terminal mappings remain contract-only because current transport evidence does
not distinguish them.

## Per-surface state matrix (target contract)

Every cell gives **primary action; optional technical disclosure**. None of this complete matrix is claimed as implemented.

| Surface | First-use empty | Legitimate zero | Loading | Stale | Disconnected | Permission/capability limitation | Recoverable error | Terminal error |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Home/Desk | Choose library; path rules | Create MoonBook; library path | Wait/cancel; request ID | Refresh; last updated | Reconnect; endpoint | Choose accessible folder; OS detail | Retry; error detail | Open Settings; diagnostic export |
| Pages/Wiki | Create first page; template | Create page; filter detail | Wait/cancel; request ID | Refresh; snapshot age | Reconnect; endpoint | Fix access; denied path | Retry; parse/request detail | Return Home; corruption detail |
| Code | Start conversation; capability note | New conversation; filters | Stop/wait; runtime ID | Refresh status; evidence age | Reconnect; endpoint | Set up capability; detected state | Retry; command/error | Save details and return; terminal runtime code |
| Requests/Town | Create request; capability note | Create request; active filters | Wait/cancel; request ID | Refresh; scheduler age | Reconnect; endpoint | Set up Requests; capability state | Retry; scheduler detail | Export details; terminal code |
| Runs | Start eligible work; capability note | Go to Code/Requests; filters | Wait/cancel; run ID | Refresh; last event | Reconnect; stream endpoint | Set up capability; state | Retry; event/error | Export run evidence; terminal code |
| Review | Select completed work; required evidence | Go to Runs; filters | Wait/cancel; review ID | Refresh evidence; age | Reconnect; source endpoint | Request access/setup; missing grant | Retry; evidence error | Export review record; terminal reason |
| Publish | Choose output; prerequisites | Go to Review; filters | Cancel/wait; job ID | Revalidate; validation age | Reconnect; destination | Fix permission/setup; denied target | Retry publish; log | Save report; terminal packaging code |
| Settings | Choose library; defaults | Add capability; detected inventory | Wait/cancel; probe ID | Recheck; probe age | Recheck connection; endpoint | Open system settings; required grant | Retry check; probe detail | Copy diagnostics; unsupported reason |

“Legitimate zero” must never be rendered as first-use, loading, or failure. Stale and disconnected states must preserve last known data, label its age/source, and avoid claiming active execution.

## Capability-guided setup

### Explicit target enum

```text
CapabilityState =
  DetectedRunning
  InstalledStopped
  NotInstalled
  Misconfigured
  UnsupportedPlatform
  TemporarilyUnavailable
```

The UI now implements this as a private shared MoonBit enum. Code and Requests
automation map all six states from explicit host evidence. Requests
installation evidence distinguishes a configured service, a matching-root
supervisor, and absence; its platform evidence is normalized independently of
runtime reachability; and its configuration evidence distinguishes absence
from an installed but unusable setup. Both configured service hosts also
validate executable availability and working-directory integrity before
lifecycle writes or process spawn. Older responses retain structured-field
compatibility behavior. Requests remain saveable while automation is stopped,
absent, misconfigured, unsupported, or temporarily unavailable.

| Capability state | Meaning | Allowed primary action | Other allowed actions | Prohibited claim/action |
| --- | --- | --- | --- | --- |
| DetectedRunning | Capability is detected and responding | Continue | Recheck, stop only when safely managed, technical details | Do not show setup as required |
| InstalledStopped | Installation detected, process not running | Start | Recheck, open Settings, details | Do not claim connected/running |
| NotInstalled | No supported installation detected | Install | Choose existing installation, details | Do not offer Start |
| Misconfigured | Installation exists but config/credentials/path is invalid | Fix configuration | Recheck, open file/system settings, details | Do not silently reinstall or execute |
| UnsupportedPlatform | Capability cannot run on this platform | Continue without capability | Learn more, export diagnostics | Do not offer install/start/retry loops |
| TemporarilyUnavailable | Previously/configurably available but probe/service failed transiently | Retry | Continue offline where safe, details | Do not convert to “not installed” or erase last evidence |

Dependent controls must be disabled or replaced with the one allowed setup action. Detection is read-only; install, start, configuration, and permission changes require explicit user action.

## Command 019 executable clean-workspace quickstart smoke

Run from the repository root:

```sh
scripts/moondesk_quickstart_e2e.sh
```

The wrapper builds on the checked-in CDP browser smoke. It creates an isolated
temporary suite, starts the real local Code runtime fixture, serves the
production UI, and drives visible controls to create and select one MoonBook.
It saves an Inbox note, navigates Home → Pages, reopens the note, and hard
reloads before continuing.

The Code step submits one harmless read request through the visible composer.
The proof requires one terminal canonical assistant row with command ownership,
checks the backend Markdown projection separately from rendered transcript
text, and records the exact reply for the restart assertion. Review must render
its legitimate-zero structure, while Publish must expose its honest output
check without claiming a generated result exists. The shell then stops and
restarts only the MoonDesk web host while
preserving the browser profile and runtime. After restart it proves the selected
book, exactly one user/assistant conversation pair, selected Inbox note,
rendered note content, and durable file bytes.

The smoke leaves its `mktemp` fixture for failure diagnosis and operating-system
temporary-file cleanup. It is browser-host evidence; it does not claim native
picker, packaged-app launch, signing, or clean-machine acceptance.

## User quickstart target

1. Launch MoonDesk. If no library is configured, choose **Choose library folder** and select a writable folder you control.
2. If the library is empty, choose **Create MoonBook**, enter a name, create it, and confirm that it is selected on Home.
3. Open **Pages**, choose **Create page**, enter text, save, navigate away and back, and confirm the page persists.
4. Open **Code**. If capability setup appears, follow exactly one offered action: Start, Install, Fix configuration, Retry, or Continue without it. Do not proceed until the UI says detected and running; unsupported platforms should continue without Code runtime work.
5. Start one conversation, submit a harmless request, open **Runs**, and verify that progress is labeled with runtime evidence rather than optimistic text.
6. Open **Review**, inspect the resulting evidence, then open **Publish** only if the work is eligible. Confirm the output location or actionable limitation.
7. Quit and relaunch. Confirm the library, selected book, saved page, and only evidence-backed runtime history are restored.

Steps 2–3 and the available-runtime branch of steps 4–7 are now executable in
the checked-in browser quickstart. Packaged macOS picker interaction through
restart restoration is also proven. Native installation, unsupported-platform
continuation, the remaining responsive page-level keyboard matrix, packaged
native keyboard behavior, and other supported desktop platforms remain
acceptance targets. The configured-empty-library browser path for steps 2–3
passes at 1440×900 using natural document focus, real Tab/Shift+Tab traversal,
Input insertion, Space, and Enter; it retains the existing hard-reload and host
restart persistence checks.

## Keyboard and responsive acceptance cases (target)

Common keyboard contract: Tab/Shift+Tab reaches every visible control in visual order; focus is always visible; Enter/Space activates buttons; arrow keys operate declared composite widgets only; Escape closes the topmost transient UI and restores triggering focus; no global shortcut fires while typing; all state messages are announced once. Existing Desk/navigation/palette tests are partial evidence, not full acceptance.

| Viewport | Acceptance cases |
| --- | --- |
| 1440×900 | Full navigation labels and three-pane Home may show; primary action and selected book remain above fold; keyboard traversal does not enter hidden panes |
| 1024×768 | No clipped navigation/action; secondary/technical panels collapse before primary content; focus order follows rendered order |
| 390×844 | Single-column content; navigation uses one accessible compact control; no horizontal page scroll; dialogs fit and remain dismissible by keyboard |
| 320×700 | Same as 390 with long names wrapping/truncating accessibly; primary action remains visible; 200% text zoom causes no control overlap or unreachable disclosure |

For each viewport, test no library, empty library, one book, many books, every capability state, all eight matrix states on the owning surface, keyboard-only completion, and focus restoration after retry/setup disclosures.

Current bounded automation covers the populated Home path at 1440×900,
1024×768, 390×844, and exactly 320×700. At 320×700 it asserts no document
horizontal overflow, no pane overlap, no overflowing file table, correct
single-column pane order, and primary browser content above the fold. The same
run focuses the Storage & services summary, opens it with a real CDP Space
event, closes it with Escape, verifies focus returns to the summary, then
activates Pages with a real Space event. The configured-empty-library
quickstart separately traverses from natural document focus to accessible
book-name/folder fields, Create MoonBook, Pages, New note, accessible Inbox
title/body fields, and Save note without programmatic focus or click. Its
bounded proof records 73 visible, enabled focus/input/activation entries and
durable Markdown through hard reload and host restart. This is not completion
of the full matrix above.

The one/many-book selection subset now has one merged, machine-readable
eight-case proof. It covers exactly one selected MoonBook in the clean-workspace
fixture and four choices in the populated fixture at 1440×900, 1024×768,
390×844, and 320×700. Every case:

- begins from natural document focus after a fresh navigation
- uses real Tab/Shift+Tab and alternating Space/Enter events without click or
  programmatic focus
- proves connected, visible, enabled targets and row DOM/visual order
- proves a visible three-pixel focus outline, activation focus retention, and
  reverse/forward round-trip
- exposes exactly one semantic `aria-pressed="true"` row from the same predicate
  as the visual active class
- agrees across selected row, URL workspace, title-bar identity, and Home
  content
- uses full navigation at desktop/tablet and compact navigation at both narrow
  widths
- has no document horizontal overflow or pane overlap

All eight retained PNGs were inspected at original resolution. The same
release output passed the populated smoke and the clean-workspace journey
through hard reload and host restart. This closes the bounded cardinality and
viewport selection subset, not whole-page focus order or screen-reader output.

The shared shell now has a separate bounded accessibility proof. Every primary
destination renders one `main` landmark named for that destination, and a
native “Skip to main content” link becomes visible on focus and transfers focus
to that landmark on Enter. Desktop and compact primary navigation are both
named; the same selected predicate drives the active class, `aria-pressed`, and
`aria-current`. Destination changes publish one factual polite/atomic status.
Each of the eight typed state surfaces also has an isolated polite/atomic
announcement containing only its user-facing title and detail; actions and raw
diagnostics remain outside that node.

The machine-readable proof covers:

- skip-link Tab/Enter, a visible three-pixel focus indicator, main-landmark
  focus transfer, and non-trapping Shift+Tab/Tab at 1440×900, 1024×768,
  390×844, and 320×700
- all seven primary destinations in one desktop and one narrow route group,
  using real keyboard activation and checking DOM state against the CDP
  accessibility tree
- exactly one main landmark and one current destination per route, without
  horizontal overflow or pane overlap
- deterministic Pages Loading, RecoverableError, and LegitimateZero
  announcements, including proof that technical detail is not copied into the
  live region
- six retained screenshots: four focused skip-link captures and two
  destination-route captures

Original-resolution review caught two defects that semantic assertions did not:
the isolated announcement was also visible and duplicated state copy, and
Runs/Publish inherited Home’s three-column grid and squeezed their cards into
one narrow column. Both are fixed. CDP accessibility-tree output is still not a
substitute for a focused manual VoiceOver/NVDA run, so announcement timing,
speech quality, page-level focus order beyond the Command 061 bounded matrix,
and packaged native keyboard behavior remain open.

A separate populated-Home run now covers text-only 200% at exactly 1440×900
and 320×700. It snapshots every computed font size before applying the scale,
doubles 401 rendered HTML elements without changing viewport size or device
scale, and restores all 401 elements after each case. Machine-readable geometry
proof requires document width to equal viewport width, no horizontal overflow
or pane overlap, the correct desktop or compact destination control, and
unclipped headings, selected book, current path, Back/Forward controls, Refresh,
Up, and Home. The passing run also retains PNGs for both cases. Visual review
found and repaired a 446px implicit shell grid track, non-wrapping navigation
and disclosure controls, inspector action truncation, and a fixed language
selector that collided with enlarged title-bar controls; the selector now
mounts into a real two-row header host.

Responsive-state page-level focus order beyond the Command 061 Home setup,
palette, session-action, and compact-navigation matrix, focused manual
screen-reader behavior, packaged native keyboard behavior, and remaining
data/capability states are still open.

## Exact implementation slices and owners

1. **Shared vocabulary and navigation:** `ui/rabbita-desk/main/app_shell_model.mbt`, `app_update_navigation_actions.mbt`, `main.mbt`, and owning shell view files; extend `app_desk_navigation_wbtest.mbt`, `app_tool_navigation_wbtest.mbt`, and command-palette tests.
2. **Cold-start classifier and restoration:** `app_bootstrap.mbt`, `app_initial_model.mbt`, `app_workspace_model.mbt`, `app_update_workspace_results.mbt`, `app_update_library_selection.mbt`, `commands.mbt`, `commands_mutation.mbt`, `desk_mode_views.mbt`, `internal/moonwiki/library_selection.mbt`, and `internal/moonwiki/server.mbt`; extend focused library-selection tests into all four exact E2E paths.
3. **Shared surface-state model/rendering:** `app_state.mbt`, `http_result.mbt`, per-surface model/view files (`desk_mode_views.mbt`, `moonwiki_*_views.mbt`, `mooncode_*_views.mbt`, `moontown_*_views.mbt`, run/review/publish owning views); add focused state-table tests per surface.
4. **Capability enum and transition policy:** `app_daemon_model.mbt`, `mooncode_daemon_model.mbt`, `app_update_daemon_actions.mbt`, `app_update_daemon_results.mbt`, capability/setup portions of `desk_mode_views.mbt` and Code/Town/Settings views; add transition tests for all six enum cases and action allowlists.
5. **Copy migration and disclosure:** owning view files and localization resources/tests; assert user-facing labels and that internal terms appear only inside technical disclosure.
6. **Quickstart E2E:** browser/app E2E suite owning bootstrap, persistence, Code, Runs, Review, and Publish; fixtures must deterministically simulate every capability state without requiring a real daemon.
7. **Keyboard/responsive proof:** keyboard handlers including `app_desk_keyboard.mbt`, shell/surface views, and UI styles; add automated viewport cases at exactly 1440×900, 1024×768, 390×844, and 320×700 plus keyboard-only paths and focused manual screen-reader evidence.

Phase dependencies remain those in the productization plan. These slices implement Phase 1; they do not close later typed-contract, package, security, release, or operational-proof gates.

## Command 045 — Code-assistance localization migration

This bounded migration followed five explicit phases:

1. **Inventory the rendered contract.** Treat the capability eyebrow and
   heading, six state titles, six state details, six status labels, four
   actions, installing label, and generic progress sentence as the complete
   ordinary-copy slice. Keep diagnostic strings outside this slice.
2. **Reconcile authoritative catalogs.** Add the exact English strings and
   natural Simplified Chinese equivalents. Remove only the three dead
   setup-topology keys; retain every current diagnostic entry.
3. **Regenerate from the canonical source.** Run the shared catalog generator,
   never hand-maintain the generated browser catalog. Regeneration exposed
   source drift: the generator had lost exact-only accessibility-attribute
   translation and the locale-specific system-language label. Repair those
   behaviors in the generator, then regenerate again.
4. **Prove the bounded contract.** A table-driven test checks all 26 ordinary
   strings, requires every Simplified Chinese value to differ from English,
   and proves the three dead English strings are absent. Separate tests retain
   dynamic template translation, exact accessibility-attribute behavior, and
   the single-language system option. Generated JavaScript syntax and
   byte-for-byte regeneration must also pass.
5. **Keep the larger gate open.** This slice does not prove every literal in
   every rendered state, manual assistive output, or packaged-native locale
   behavior. Complete source/catalog/generated-output inventory and rendered
   browser coverage remain required before Phase 1 can close.

## Command 046 — explicit localization-key ownership

This follow-on phase moved the same bounded slice from catalog-only coverage to
stable ownership in the MoonBit UI source:

1. **Define the source contract.** Keep the Command 045 set of 26 ordinary
   strings fixed. Technical details and raw diagnostics remain outside the
   contract; this phase does not widen the translated surface by inference.
2. **Bind typed state to exact keys.** Exhaustive private mappings now associate
   all six capability states with title, detail, and status keys and every
   primary action with its action key. The mappings use the existing catalog
   vocabulary and preserve the English-returning behavior used before browser
   localization.
3. **Attach keys at every owning render node.** Home owns keyed eyebrow,
   heading, and status nodes. Home and Code share keyed titles and details.
   Both own keyed actions, installing labels, and the generic progress
   sentence. The technical disclosure carries no `code.assistance_*` key.
4. **Prove state and render coverage.** Focused MoonBit tests exercise all six
   states, all actions, both installing branches, shared progress, unchanged
   English before browser translation, and diagnostic isolation. The focused
   capability suite passes 16/16.
5. **Prove source/catalog/runtime parity.** The localization suite extracts the
   literal key set from the three owning MoonBit sources, requires exact
   equality with the English and Simplified Chinese catalog slice, and invokes
   the generated runtime for every key. Every generated Simplified Chinese
   result must equal its catalog value and differ from English. The suite
   passes 5/5.
6. **Keep the phase boundary honest.** This closes one complete source-owned
   vertical slice, not the product-wide localization gate. Every remaining
   surface still needs a source/catalog/generated-output/rendered-state
   inventory, browser-state coverage, manual assistive review, and packaged
   native locale evidence.
