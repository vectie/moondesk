# Wiki Mode User-Centered End-to-End Test Plan

## Purpose

This plan proves that a normal user can complete real knowledge work in Wiki
mode without understanding MoonSuite internals. It complements
`WIKI_MODE_TEST_PLAN.md`, which covers routes, filesystem contracts, and forward
and backward runtime flows.

The central acceptance question is:

> Can a user understand where they are, choose a sensible next action, complete
> it, and confirm the durable result without being distracted by implementation
> details?

The test is not complete when a control merely responds. A journey passes only
when the user-visible outcome, API result, persisted state, refresh behavior,
and information-hiding boundary all agree.

## User Model

Primary persona: a researcher, writer, or project owner who understands pages,
notes, sources, search, and review decisions. They may know Markdown, but they
must not need to understand daemon lifecycle, process IDs, queue records,
MoonClaw runs, MoonTown requests, source layers, or filesystem layout.

Primary jobs:

- find and read trusted knowledge;
- capture a thought or source before it is lost;
- edit a page and know whether it was saved;
- ask the book to research, organize, or update something;
- understand whether work is waiting, active, ready for review, or failed;
- accept or reject proposed knowledge with context;
- inspect sources and history when confidence matters;
- recover from errors without losing work.

## Methodology

### 1. Test The User Contract At Five Levels

Every journey is checked at all applicable levels:

1. **Perception:** what is visible before the user acts, including hierarchy,
   labels, default disclosure state, focus, and absence of internal noise.
2. **Interaction:** what the user can operate with pointer and keyboard, and
   whether the control gives immediate feedback.
3. **Product state:** whether the intended page, task, review, or status appears
   in the UI without an unrelated mode switch.
4. **Durability:** whether API responses and files/receipts contain the expected
   scoped result after refresh.
5. **Recovery:** whether failures preserve user input, explain the next step,
   and leave the shell usable.

### 2. Use A Controlled, Disposable Fixture

- Build the production Rabbita UI.
- Copy a seeded MoonBook into a unique directory under
  `/private/tmp/moondesk-wiki-e2e/`.
- Add known pages, search phrases, inbox content, pending reviews, generated
  output, and a sibling traversal sentinel.
- Start the real MoonDesk server on a unique loopback port.
- Disable reliance on external network and live MoonTown/MoonClaw services.
- Record a pre-run file inventory and compare it with the post-run inventory.
- Stop the server and retain only the written execution report or screenshots
  needed as evidence.

### 3. Observe Before Acting

For each destination, capture the accessibility/DOM snapshot before clicking
anything. This catches hidden-by-CSS internals, incorrect default disclosures,
ambiguous controls, missing headings, and actions that are only understandable
after experimentation.

### 4. Use Role-Based Browser Interaction

Prefer accessible roles and names (`button "Inbox"`, `textbox "Note title"`)
over CSS selectors. A control that cannot be found by role/name is an
accessibility and testability defect unless it is intentionally non-interactive.

### 5. Verify Both Meaning And Mechanics

Text assertions verify user meaning; API/filesystem assertions verify mechanics.
For example, `Saved to Inbox.` is not sufficient by itself: the note must exist
under the selected book, contain the submitted text, and remain visible after a
hard refresh.

### 6. Test Progressive Disclosure Explicitly

Default snapshots must not contain PID, CWD, daemon commands, raw event names,
run IDs, absolute paths, source-layer labels, service files, or transport
terminology. Those values may appear only after the user explicitly opens
`Technical details` or `More > Diagnostics`.

### 7. Cover Responsive And Keyboard Behavior

Required viewports:

- desktop: `1280 x 720`;
- compact desktop/tablet: `900 x 800`;
- phone: `390 x 844`;
- narrow phone stress: `320 x 700`.

At each viewport, assert no horizontal document overflow, no clipped action,
no overlapping text, and a reachable active destination. Run the primary
navigation, note capture, search, edit, and review flows with keyboard focus as
well as pointer input where practical.

### 8. Record Evidence And Severity

Each scenario records `PASS`, `FAIL`, `BLOCKED`, or `NOT APPLICABLE`, plus:

- browser-visible evidence;
- API/filesystem evidence;
- screenshot when layout is material;
- console errors/warnings;
- defect severity and reproduction steps.

Severity:

- **P0:** data loss, write outside the selected book, or security escape;
- **P1:** primary journey cannot be completed or internal state dominates the
  default experience;
- **P2:** confusing feedback, inaccessible action, broken refresh, or serious
  responsive defect;
- **P3:** cosmetic or low-frequency clarity defect with a usable workaround.

## User Journey Matrix

### U1. Enter Wiki And Resume Reading

**User should see:** `Desk`, `Wiki`, and `Code`; Wiki selected; the current book;
`Library`, `Search`, `Inbox`, `Activity`, `Review`, and `More`; a readable page
as the visual center.

**Why:** the user needs orientation and continuity before taking action. Runtime
health is not part of this decision.

**User can do:** choose a destination, open a page, switch modes, or continue
reading.

**Likely user behavior:** scan the page title and navigation, then continue from
the selected page.

**Expected outcome:** the page is readable, Wiki remains active, and switching
away and back preserves book/page context without starting a Code session.

**Evidence:** DOM snapshot, active-state styles, URL state, preview API, mode
round trip, and zero console errors.

### U2. Browse The Library

**User should see:** book identity, simple sections (`Overview`, `Pages`,
`Inbox`, `Published`), human-readable page names, and the selected document.

**Why:** browsing should answer “what knowledge is here?” rather than expose
storage structure.

**User can do:** change section, expand folders, open pages, and switch books.

**Likely user behavior:** choose `Pages`, scan titles, and open a relevant page.

**Expected outcome:** the chosen page opens in Wiki; raw paths, source-layer
codes, and workspace roots are absent from the default tree.

**Evidence:** role/text snapshot, selected page content, and absence scan for
internal terms.

### U3. Search And Open Knowledge

**User should see:** one search field labeled by purpose, one Search action,
results with title, useful type (`Page`, `Note`, `Review`, `Original source`),
book, and bounded snippet.

**Why:** users search by meaning, not by runtime layer or path taxonomy.

**User can do:** enter a phrase, submit, scan results, and open a result.

**Likely user behavior:** search a remembered phrase and select the most relevant
title/snippet.

**Expected outcome:** matching content appears; selecting it returns to Library
with the page open while staying in Wiki; no raw source-layer label is shown.

**Evidence:** search API response, DOM result, active mode/destination, selected
page, empty-query behavior, and no-results behavior.

### U4. Capture And Recover An Inbox Note

**User should see:** `New note`, title, body, one primary `Save note` action,
plain feedback, and secondary link/file import disclosures.

**Why:** capture must be fast and must protect attention and unfinished work.

**User can do:** write and save a note, add a link, add files, or preview details.

**Likely user behavior:** type a short title/body and save immediately.

**Expected outcome:** feedback says `Saved to Inbox.`; a scoped Markdown note is
created; content survives refresh; a failed save retains the draft and says
`Could not save. Your draft is still here.`

**Evidence:** DOM feedback, inbox API, file contents, hard refresh, and induced
invalid-write reducer/route test.

### U5. Edit A Wiki Page

**User should see:** page content and one primary `Edit` action. In edit mode,
they see the draft, `Save`, `Cancel`, and only meaningful states: `Unsaved
changes`, `Saving...`, `Saved`, or a recoverable failure.

**Why:** editing must make persistence status unambiguous without exposing the
write route or file transport.

**User can do:** edit, save, cancel, and continue reading.

**Likely user behavior:** make a small change, save, and verify it in the rendered
page.

**Expected outcome:** the saved Markdown and rendered preview agree after hard
refresh. Cancel does not write. A failed save preserves the draft.

**Evidence:** editor state, markdown API response, exact file diff, refreshed
preview, cancel inventory, and failure projection tests.

### U6. Build Or Update The Book

**User should see:** Activity with `Build or update this book`, a
purpose-oriented description, visible material context, direct `Add link` and
`Add files` actions, one `Start building` action, and recent tasks described as
`Waiting`, `Working`, `Ready for review`, `Completed`, or `Needs attention`.

**Why:** users care about requested outcomes and next actions, not request queues
or execution subsystems.

**User can do:** describe the outcome, attach links or files without leaving
Activity, remove imported materials, start the task, inspect recent
work/results, retry or review when available, and intentionally open
Automations. Inbox remains available for reusable material capture.

**Likely user behavior:** describe a research/update goal and expect an immediate
acknowledgment.

**Expected outcome:** imports persist inside the selected book and appear in the
composer. The durable request is scoped to that book and contains the visible
material paths in `context_entries`. Successful submission clears the composer;
failure preserves its description and materials.

**Evidence:** imported file, request API/file, exact `context_entries`, status
projection, responsive DOM, default noise scan, and offline-service behavior.

### U7. Review A Proposed Change

**User should see:** `Review`, the number needing attention, a decision note,
proposal title, plain explanation, and adjacent `Open proposal`, `Accept`, and
`Reject` actions. Technical details are closed.

**Why:** the user must understand the decision and its consequence before acting.

**User can do:** inspect a proposal, add context, accept, or reject.

**Likely user behavior:** open the proposal, compare it with current knowledge,
optionally add a note, then decide.

**Expected outcome:** a durable decision receipt is written; feedback states
`Change accepted and recorded.` or `Change rejected and recorded.`; refresh
preserves the decision; raw paths appear only after opening technical details.

**Evidence:** review DOM, decision API, receipt file, refreshed review count,
page-content invariant for rejection, and disclosure-state snapshot.

### U8. Trace Sources And History

**User should see:** a closed `Sources and history` disclosure near the document,
not a permanent provenance/debug panel.

**Why:** traceability matters when confidence is questioned, but should not
compete with ordinary reading.

**User can do:** open the disclosure, jump to Activity or Review, and optionally
reveal technical location from a deeper disclosure.

**Likely user behavior:** open this only when validating or explaining a claim.

**Expected outcome:** traceability entry points are understandable; the current
page remains visible; internal paths stay one deliberate step deeper.

**Evidence:** before/after snapshots, focus continuity, and path absence/presence
checks at each disclosure level.

### U9. Use More Without Seeing Operations Noise

**User should see:** small attention counts, saved views, calendar/notification
settings, and a closed `Diagnostics` disclosure.

**Why:** occasional tools belong together, while operational details must remain
available to support users without defining the product experience.

**User can do:** open Review or Activity, save a view, configure optional
settings, or explicitly open Diagnostics.

**Likely user behavior:** use an attention shortcut or ignore the page entirely.

**Expected outcome:** no PID, CWD, daemon command, tick, raw event, LaunchAgent,
or absolute path appears until Diagnostics is opened. Closing it removes that
content from the accessibility tree.

**Evidence:** closed/open/closed DOM snapshots and exact internal-term scan.

### U10. Responsive And Accessible Operation

**User should see:** the same six Wiki destinations, readable content, reachable
primary actions, and no incoherent overlap at every required viewport.

**Why:** the information hierarchy must survive constrained space; hiding the
last navigation item or clipping review counts makes the product unreliable.

**User can do:** navigate, search, save a note, edit, and review using pointer and
keyboard.

**Likely user behavior:** scroll vertically and use the top navigation row on a
phone.

**Expected outcome:** document width never exceeds viewport width; all six
destinations are reachable; focus is visible; labels and badges do not overlap;
primary controls meet a practical touch target.

**Evidence:** screenshots, bounding-box/overflow measurements, tab sequence,
role/name lookup, and focus-visible styles.

### U11. Security And Scope Recovery

**User should see:** a calm scoped error for invalid or escaped paths and an
otherwise usable Wiki shell.

**Why:** security failures must not expose sibling data or strand the user.

**User can do:** return to Library, open a valid page, and continue local work.

**Likely user behavior:** follow a malformed link or stale result, then navigate
back to known content.

**Expected outcome:** traversal and invalid writes return `4xx`, no outside file
is read or created, no absolute host path leaks into normal UI, and a valid page
still opens afterward.

**Evidence:** crafted API calls, sentinel hash/inventory, post-error browser
journey, and console log.

### U12. Empty, Loading, Offline, And Large States

**User should see:** purposeful empty/loading/error text rather than blank panes,
fake success, or permanent spinners.

**Why:** exceptional states are where users decide whether they can trust the
product.

**User can do:** retry, change destination, create a first note/page/book, or
continue local work while services are offline.

**Likely user behavior:** retry once, then choose another local action.

**Expected outcome:** empty Library, no search results, empty Activity, empty
Review, offline service, and a 300-page library remain understandable and
responsive. No healthy background status demands attention.

**Evidence:** edge fixtures, bounded render/search timing, empty-state snapshots,
retry action, and shell responsiveness.

## Execution Order

1. Build and static-check the UI.
2. Start canonical fixture and capture baseline desktop/mobile screenshots.
3. Execute U1, U2, U3, U8, and U9 without mutations.
4. Execute U4 and U5; verify files and refresh persistence.
5. Execute U6 and U7; verify request/decision records and offline behavior.
6. Execute U10 at all viewports and keyboard checkpoints.
7. Execute U11 against crafted route inputs and verify the sentinel.
8. Execute U12 with empty and stress fixtures or equivalent route-level data.
9. Run unit, package, root, build, formatting, interface, and diff checks.
10. Record defects, fixes, retest evidence, and residual risk below.

## Acceptance Gates

Release acceptance requires:

- U1-U11 pass; U12 may document a bounded large-fixture follow-up only if no
  correctness, data-loss, security, or unusable-state issue exists.
- Inbox save, Wiki edit, review decision, and request submission each have both
  browser evidence and durable API/filesystem evidence.
- All default Wiki destinations pass the internal-term absence scan.
- No write/read escapes the selected workspace.
- Desktop and phone have zero horizontal document overflow and no hidden primary
  action.
- Refresh preserves every completed durable action.
- Wiki remains useful with MoonTown and MoonClaw unavailable.
- Browser console has no uncaught errors.
- Focused Wiki tests, full frontend tests, root tests, and production build pass.

## Execution Record

Executed 2026-07-10 against the production build and the disposable fixture at
`/private/tmp/moondesk-wiki-e2e-20260710`. The initial verification server used
`http://127.0.0.1:4544/`; the empty-book and large-library follow-up used
`http://127.0.0.1:4545/`; the unified Activity follow-up used
`http://127.0.0.1:4546/`. All were stopped after their runs.

### Journey Results

| Journey | Result | Evidence |
| --- | --- | --- |
| U1 Enter/resume | PASS | Wiki orientation, URL context, hard refresh, Desk round trip, and Code round trip preserved `book-wiki-e2e` plus `wiki/e2e-target.md`; Code stayed at zero sessions. |
| U2 Library | PASS after fix | Default Overview contains only Wiki, Raw Evidence, Inbox, and Generated Site. Pages opens maintained Wiki content. |
| U3 Search | PASS | Controlled phrase returned one Page result and stayed in Wiki; a nonsense phrase returned a clear `0 results`. |
| U4 Inbox | PASS after fix | New note began empty, saved with `Saved to Inbox.`, persisted exact Markdown, and reset safely after refresh. |
| U5 Edit | PASS after fix | Editor has accessible name `Edit page Markdown`; save displayed `Saved`; file and refreshed rendered page agreed. |
| U6 Activity | PASS after fix | Description, current page, URL import, material count, and `Start building` were available together. Import stayed in Activity; the durable request contained both visible material paths; success cleared the composer. |
| U7 Review | PASS after fix | Approved and decided files were excluded; one proposal was accepted and one rejected; receipts persisted; count reached zero and the empty state was correct. |
| U8 Sources/history | PASS | Closed by default; opening showed plain-language Review/Activity links; technical location stayed behind a second disclosure. |
| U9 More/Diagnostics | PASS | Closed state contained no internal terms; explicit Diagnostics exposed PID/CWD/service details; closing removed them from the accessibility tree. |
| U10 Responsive/accessibility | PASS | No horizontal document overflow at 320x700, 390x844, 900x800, or 1280x720. All six destinations fit, including More. Role/name interaction and visible focus states were available. |
| U11 Security/scope | PASS | Encoded traversal preview and invalid Markdown writes returned 400; no escaped file appeared; outside sentinel SHA-256 remained `44923b0bdf2fed2262ccdfa351812aa2c3977c1ec5e810cc1614157135c9756a`. |
| U12 Exceptional/large | PASS after fix | Empty Activity, empty Review, no-results Search, offline services, delayed loading, and recovery passed. An empty book now offers note and question actions. A 301-entry library rendered, searched, opened page 150, and remained usable at desktop and 390px phone widths. |

### Defects Found And Corrected

| Severity | Defect | Correction |
| --- | --- | --- |
| P1 | Library Overview exposed `.moonbook`, MoonClaw, keeper, skills, config, and runtime roots. | Filtered the default tree to four user-facing knowledge roots. |
| P1 | Inbox body inherited a root-directory preview when both edit and selected paths were empty. | Require a non-empty, matching Inbox edit path before preview content can populate the draft. |
| P1 | Review treated approved files and decision receipts as pending; accepting one increased the badge. | Exclude completed names, receipt directories, and source paths with durable decision receipts. |
| P1 | Choosing another page, section, activity, book, or mode while editing silently destroyed the unsaved Markdown draft. | Defer the navigation behind an accessible confirmation; `Keep editing` preserves the draft and `Discard changes` performs the requested navigation. |
| P2 | Hard refresh lost the selected book/page. | Persist workspace and path in URL state and restore them at initialization. |
| P2 | Activity started with an executable generic prompt. | Start the composer empty and keep the guidance as placeholder text. |
| P2 | Adding materials required a separate Inbox visit, and imports navigated away from the task description. | Unified description, link/file capture, material context, and task start in Activity while retaining Inbox as an optional library. |
| P2 | Save completion disappeared immediately and the editor had no accessible name. | Show `Saved` after completion and label the Markdown editor. |
| P2 | More was clipped at 320px. | Use six equal responsive navigation columns instead of fixed-width buttons. |
| P2 | The final review decision confirmation disappeared with the last queue item. | Preserve accepted/rejected confirmation in the Review empty state. |
| P2 | An empty book exposed indexing and preview failure language with no productive first action. | Present `Start this book` with direct `Create a note` and `Ask this book` actions; remove host and preview internals from the empty state. |

### Exceptional-State Follow-up

- Empty book: `This book is empty` and `Start this book` replaced `workspace
  indexed` and `Preview is not available`. `Create a note` opened an empty Inbox
  composer in the same book.
- Large library: the fixture contained 301 visible entries (`index.md` plus 300
  numbered pages). The entries API completed in `0.028151s`; the controlled
  phrase search completed in `0.026786s` and returned only `page-150.md`.
- Responsive stress: all 301 rows remained available at 390x844, all six Wiki
  destinations fit, and document `scrollWidth` equaled the 390px viewport.
- Unsaved navigation: page 150 retained the sentinel draft and URL after `Keep
  editing`; explicit discard moved to page 151. The sentinel never appeared in
  the page-150 file. The dialog fit between x=16 and x=374 at 390px with no
  horizontal document overflow.

### Unified Activity Follow-up

- Entered a unique task description and URL material on the same Activity
  surface while `wiki/e2e-target.md` remained the current page.
- `Add link` persisted an Inbox import and increased the visible context from
  one to two materials without changing the `activity=activity` URL.
- `Start building` created a staged request whose `context_entries` exactly
  contained the current page and imported material path; Recent work displayed
  the task title and `2 materials`.
- Successful submission cleared the description and imported-material
  selection. Reducer coverage confirms failed submission preserves both.
- At 390x844, the composer, material rows, attachment actions, and primary
  action remained within the viewport; document `scrollWidth` was 390px.

### Automated Evidence

- Wiki UX tests: `19/19`.
- Request material projection tests: `2/2`.
- Full Rabbita frontend tests: `165/165`.
- Root JavaScript tests: `327/327`.
- Root native tests: `533/533`.
- Review queue regression: `1/1` focused native test.
- Production `npm run build`: passed.
- Browser console warnings/errors: none.
- Security route checks: all expected `400` responses with no out-of-scope write.

The isolated committed tree finished all three suites without failures. The two
MoonCode HTTP failures seen during the initial run no longer reproduce.

### Residual Risk

- Page-specific provenance is still represented by book-wide Review and
  Activity entry points.
