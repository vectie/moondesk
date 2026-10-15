# MoonDesk: navigation from a user's job to a finished output

Date: 2026-10-14. Status: five active journeys completed and verified; the MoonFish handoff is paused at the user's request. Original observations are retained below.

## Assessment

The compact layout has improved scanning, but producing something still asks
users to understand MoonDesk's feature structure. Desk, Book/Wiki, Code, Flow,
and Packs are different kinds of destination presented as peers. The user
must infer where a task starts, where its output lives, and how to return.

The product should make a MoonBook and a named piece of work the persistent
context. Files, conversation, output, changes, and execution are views of
that work. Switching a view should not feel like starting a different job.

The initial review below motivated the implementation recorded at the end.
The initial review staged drafts and navigated existing work. Final verification
also created isolated test schedules and completed a real one-off MoonClaw
report run. No production recurring schedule was enabled.

## Evidence and scope

Inspected the populated local library and installed frontend, plus the current
navigation, file-opening, task, results, and URL synchronization code.

- MoonBook Chat opens Book/Wiki directly with the selected book.
- The task picker and Review both open the same **Document tools** modal,
  containing 13 tabs: Review, Book room, Calendar, Results, Tasks, Artifacts,
  Conversations, Sources, History, Check packs, Learning, Preferences, Inbox.
- Task setup offers four document/research recipes even when `coding` is
  selected: board brief, document review, topic tracking, and presentation.
  The board-brief form ends with **Start in chat**; the action routes to Wiki.
- Book/Wiki has chat next to a document viewer, with Find and Add context.
  Those controls already avoid returning to Desk merely to attach a source.
- Code has local Files, Changes, Preview, Terminal, and Compare tabs. Its
  unsent draft survived a Code → Desk → Code check. The draft runtime restores
  the text even though the MoonBit mode transition clears its model field.
- In the installed frontend, Flow's empty state offered **Open executable
  document**. For the selected coding book, clicking it opened Book/Wiki's
  empty **Open a document** screen without choosing or creating a document.
- The current host reported Flow execution controls unavailable and no graph
  for that book. This review does not infer how a completed Flow run behaves.
- Packs launches MoonFish in the same window (`target="_self"`). Its loaded
  screen showed MoonFish navigation with no visible MoonDesk return control.
  Browser Back returned to the shell through its loading screen.
- A return through the development server exposed a cached older shell.
  The installed frontend was used to confirm the Flow transition; conclusions
  about current ownership and MoonBook controls use the installed version.
- Source confirms file double-click selects a file; it does not open a working
  editor. The document-opening action is in Selection details. Desk Back and
  Forward track directories; shell destinations update URLs with replaceState.

These are interface observations and source inspection, not measured user
completion times or evidence that outputs were generated successfully.

Evidence: [task setup inside the broad Document tools dialog](design/moondesk-icons/journey-task-dialog-20261014.png).

## Six user jobs

| Job and output | Current path / friction | Intended path |
| --- | --- | --- |
| Analyst: turn source documents into a brief | Desk book → Chat → Find/Add context or Synthesize → chat and viewer; Review opens a broad toolbox, Results and export require knowing separate entry points | Choose book → describe brief and attach sources → draft opens beside conversation → revise → Export |
| Developer: fix a bug and inspect the result | Code already keeps files, changes, terminal, and preview local. The generic MoonBook + task picker does not offer a coding job and starts its recipes in Wiki | Book card + → Fix a bug or freeform task → Code conversation → local changes/preview → finish with a linked patch or PR |
| Reader/editor: improve an existing file | Desk selection → discover Selection details → find Open in Wiki for supported documents; double-click mainly changes selection. Markdown/text uses Desk preview | Double-click/Enter opens the appropriate working viewer; Ask/Revise opens conversation beside that file |
| Returning user: continue yesterday's output | Code has a visible conversation list; Desk has Resume work lower in its rail; document conversations and Results live in the Review toolbox | Book → recent named work → same conversation, output, selection, and panel position |
| Researcher: repeat a weekly report | Document background work, Code schedules, and Flow expose different portions of recurring work; Flow's empty-state action can lead to an empty document view | Finish a report → Schedule this → future results link to the same work; Flow is available for editing dependencies |
| Domain specialist: use MoonFish to produce research | Packs → separate app replaces shell; no visible return-to-book or send-result-to-current-work route on the inspected screen | Launch app with visible book/work context → create result → Open in MoonDesk or Add to current work → revise/export |

The table describes likely paths from the available controls. It does not
claim each job currently requires every named stop. Book's source picker and
Code's local panels are useful shortcuts that should remain.

## The specific navigation problems

### 1. The current book disappears as a useful visible control

Desk has the MoonBook library and Code has a book/session rail. Book/Wiki's
visible headings are Chat and Document, while selected-book context is in the
shell accessibility status. A user comparing material across books must find
their way back to a selector or use another indirect route.

**Change:** a compact book switcher in the existing work header, available in
Book, Code, and Flow. Show the active task title beside it. Remember the last
work position per book instead of treating book selection as a fresh start.
The switcher should make the context change explicit without opening a wizard.

### 2. Primary work is hidden behind a Review icon

Conversations, starting a task, viewing results, and reviewing an edit are
different frequent intentions. They currently share an oversized modal with
13 peer tabs. An icon's tooltip cannot explain that navigation structure.

**Change:** put recent conversations in the work rail, start tasks through a
focused picker, and expose output beside the conversation. Keep Review as a
contextual panel for the current result. Calendar, preferences, and learning
belong in their own book-level menus, not every task-starting flow.

### 3. “Start task” is biased toward documents

The new + action finds the correct book, but its destination remains generic
Document tools, then a document-oriented recipe list. A coding user still has
to know to leave for Code.

**Change:** one focused task picker with a freeform request and a short set of
relevant templates. Initial examples: Fix a bug, Build a feature, Review code,
Write a brief, Create slides, Analyze data. A selected template names its
output and opens the appropriate view while retaining the same book/task.
Reuse the existing recipe machinery; do not introduce another task catalog.

### 4. Compactness has hidden the main file action

Moving Selection details behind a panel icon made Desk cleaner, but the
working action for a selected document moved with it. A file browser where
double-click only selects a file is difficult to discover.

**Change:** single-click selects, double-click/Enter opens the appropriate
viewer or editor. The inspector contains metadata and occasional operations.
Add a contextual Ask/Revise action to the opened object, carrying its path and
selection. A meaningful view switch is fine when the destination is explicit.

### 5. Results exist, but the end of the job is not prominent

The existing Results implementation already groups outputs and conversations
and offers export. It is reached through the Document tools modal. Some
result actions open another broad destination rather than a visibly scoped
piece of work; the current View work callback routes to Runs without using
the bundle argument.

**Change:** promote those existing result bundles into the active work view
and a visible recent-work entry. Show the output name and useful status, with
Open, Revise, and Export actions. View work must open the specific task/run.
Do not add a second results store or another always-visible dashboard.

### 6. Return behavior depends on where the user came from

Desk arrows mean directory history. Shell URLs use replaceState, so browser
Back is not a dependable history of visited destinations. Pack apps replace
the shell. A Flow action currently changes destination without resolving the
object named by that action.

**Change:** separate file history from work history. A contextual **Back to
{task title}** returns to the originating work and restores view state. An
action that says Open {object} must resolve that object. Pack apps receive a
return target and retain a small host navigation strip or equivalent visible
return control. Use explicit object links instead of routing to generic lists.

## Destination responsibilities

| Destination | User purpose | Role during production |
| --- | --- | --- |
| Desk | Find, manage, and resume books and files | Entry and library; not a mandatory waypoint between work steps |
| Book | Read, discuss, create, and revise documents | Main work surface for document/research jobs; settle the visible Book/Wiki naming consistently |
| Code | Build and change software | Main work surface for coding jobs, keeping changes/terminal/preview local |
| Flow | Inspect or edit repeatable execution and dependencies | Optional advanced view of a task; ordinary progress/results remain reachable from the task |
| Packs | Discover and launch apps and templates | Launcher and catalog; launched work retains an obvious book and return destination |

Keep the existing five destinations during the first implementation phase.
Clarify that Desk/Packs are app-level entry points and Book/Code/Flow operate
on the current book/work. Renaming or removing tabs alone will not fix the
missing connections.

## A coherent production workspace

```text
Current MoonBook ▾  /  Named task                       work actions
──────────────────────────────────────────────────────────────────
Recent work       Conversation                  Output / editor
                  Attach or find sources        Preview / changes
                  Ask and refine                Review / export
```

Use the current 48px work header and compact rail. Avoid adding a permanent
stepper, explanatory paragraphs, duplicate counts, or another dashboard row.
Files, results, review, and execution details open as local panels. Names of
books, tasks, and outputs stay as text; repeated utility actions use icons.
Completion actions such as Export retain a clear label in the output menu.

The user's progression is:

**Choose work → supply context → produce → inspect/refine → take the output.**

These are states of the same job, not five tabs the user must visit. Opening
Code for a software task or Flow to edit a graph is a meaningful change of
working view. Returning to Desk just to locate the active book or to a broad
Runs page just to find the output already being discussed is avoidable travel.

## Implementation order and acceptance criteria

1. **Continuity.** Add book/task identity to existing headers; expose direct
   book switching and contextual return targets. Preserve drafts, active
   conversation, selected object, file filters, scroll, and open panels per
   book/work. Keep Code's existing draft restoration. Check A → B → A restores
   each context independently.
2. **Direct entry.** Replace the broad toolbox as the + entry point with the
   focused task picker; add relevant coding templates and freeform entry.
   Make file double-click/Enter open the right view. A bug-fix task starts in
   Code and a document job starts in Book without an extra manual tab choice.
3. **Visible completion.** Reuse result bundles beside the originating chat;
   make Open, Revise, Export, and exact-run links reachable there. A user can
   take the finished output without searching Desk, Flow, or a toolbox tab.
4. **Connected specialist views.** Give Pack apps a visible return and result
   handoff. Make Flow empty states choose/create a supported graph or document
   and open it directly. Scheduling begins on the completed task/result and
   links its later outcomes back to that work.

Validate each phase using the six jobs above. Track unnecessary top-level
switches, repeated context selection, ability to identify the current book
and task, successful return to the same work, and discoverability of the final
output. Targets: zero unrelated destination switches for normal draft/review/
export; one deliberate transition into a specialist editor; one-action return.
These are proposed acceptance targets, not current measured performance.

## Implementation anchors

- `ui/rabbita-desk/main/moonbook_actions.mbt`: direct book chat and task entry.
- `ui/rabbita-desk/main/desk_mode_views.mbt`: file activation and inspector.
- `ui/rabbita-desk/main/moonwiki_focus_views.mbt`: document chat and viewer.
- `ui/rabbita-desk/workspace-features-runtime.js`: recipes and toolbox tabs.
- `ui/rabbita-desk/workspace-results-runtime.js`: existing result bundles.
- `ui/rabbita-desk/code-workbench-runtime.js`: scoped prompt/context recovery.
- `ui/rabbita-desk/main/app_update_navigation_actions.mbt`: mode/book context.
- `ui/rabbita-desk/main/main.mbt`: URL synchronization.
- `ui/rabbita-desk/main/moonflow_views.mbt`: Flow entry and empty-state actions.
- `ui/rabbita-desk/main/pack_home_views.mbt`: app launch and templates.

See also the [layout change record](UI_UX_LAYOUT_2026-10-13.md).

## Implemented journey cleanup

The existing five destinations remain. The everyday path is now:

**Book switcher → + → describe the result → Book or Code → inspect results → revise/export.**

| Journey | Implemented behavior |
| --- | --- |
| Choose and resume a book | A searchable book switcher stays in the 52px shell header. Switching A → B → A retains each book's work. Recent tasks includes Book drafts/conversations and Code sessions. Book task recovery retains the open output, unsent draft, attached sources/context, folder/filter, review panel and transcript reading position after reload. Code panels and transcript positions are scoped to the book and session. |
| Start work | Plus opens a focused goal form. Continue stages an editable draft in Book or Code. Fix a bug, Build a feature and Review code presets supplement the existing document recipes. Starting a document recipe preserves its named outcome. |
| Open a file | Single-click and typeahead select. Double-click or Enter opens document/media/Markdown output in Book, and source files in Code. Markdown can enter the existing editor. The explicit return arrow restores the originating view and file position. |
| Inspect completion | Output file chips, Revise, Download and Schedule sit beside the conversation. A new output opens beside the active task. Results includes ordinary chat artifacts and restores the owning conversation when opening a file. Download exports the actual file; Export result includes that task's transcript and sources. |
| Revise or repeat | Book's Markdown editor has Save, Cancel and ⌘S. Schedule opens a focused form bound to the original book, task, sources and output paths. Schedules can be edited, paused, resumed, run now and removed from a local drawer. Scheduled outcomes return to the original conversation and Results, with a link to the execution conversation. |
| Use a Pack | Paused. Existing Pack host work remains, but this journey is excluded from this completion claim. |
| Enter Flow | An empty Flow offers Start a task or Choose workflow file. The latter opens a file picker instead of an empty document viewer. Existing workflow files open in their appropriate working view. |

### Scope and persistence

Conversation content remains in the existing server archive. Local app storage
retains unsent task drafts, source/context selections, the open document,
review-panel selection, transcript reading positions and schedule-to-task
bindings. Code panel choices and transcript positions are scoped per session.
This is desktop-local presentation recovery; it is not cross-device sync.

MoonTown owns schedule definitions and cadence. MoonClaw owns execution.
Opening or editing a schedule does not submit a report request; Create/Save
schedule is the explicit execution setup action. A connected MoonTown owner
service is required on the host. The original 2026-10-14 checks used an isolated
MoonTown workspace and the existing MoonClaw private control. On 2026-10-15,
MoonTown was connected to the primary installed MoonDesk workspace, its
background schedule clock was installed, and two automatic recurring runs
completed, including one with MoonDesk closed. Both verification schedules
were then paused. See [typography and main workspace scheduling](UI_TYPOGRAPHY_AND_SCHEDULING_2026-10-15.md).

A live verification exposed an unrelated-path migration error in MoonTown:
`/Users/.../workspace/books/...` was rewritten as if it were a legacy
`/workspace/books/...` path. The normalization now matches the legacy prefix
only. Its regression test and the live scheduled report pass.

### Verification

- Book preview now shares Code's Markdown renderer. A final screenshot exposed
  literal table and emphasis syntax in the older preview; the correction was
  verified with a rendered table, bold text, inline code and an indented fenced
  code block. All 20 Markdown editor tests pass, including the regression.
- The packaged app was refreshed again after that correction, its signature
  verified, and its embedded frontend compared with the final build.
- 99 focused MoonBit navigation, Quick Access and journey tests pass.
- 59 JavaScript tests pass, including the real MoonDesk → MoonTown schedule
  create/read/pause/resume/run-now round trip and schedule retry/context recovery.
- MoonTown's 12 schedule tests pass. The path regression and an explicitly
  enabled live execution check both pass: a real MoonClaw turn read a local CSV,
  wrote `inbox/scheduled-report.md`, cited the source and calculated 20% growth.
- MoonBit interface generation and formatting pass. The added interface
  entries are the private work-location and per-book position types.
- Browser checks cover task preset → editable Code draft, report → revise →
  save → download, result package export, schedule create/edit/pause/resume,
  and reload recovery. The report download matched its source bytes. The result
  package contained the correct transcript, output and source references.
- Reload restored the report conversation to the same 342px transcript position,
  retained the unsent revision request and open report, and reopened Review.
- MoonDesk's existing native sidecar is retained. MoonTown's owner service was
  rebuilt with the workspace-path correction.
- `/Applications/MoonDesk.app` contains the verified frontend build, with
  signature and embedded-file checks passing. Native cross-book task entry
  also passes; the app is left ready on coding's task picker.
- Verification used dedicated fixture books and one-time tasks; no production
  recurring job was enabled. Temporary library content is preserved with the
  verification artifacts rather than left among the user's books.

Evidence: [report and draft](design/moondesk-icons/journey-report-desktop-final.png),
[schedule controls](design/moondesk-icons/journey-schedules-desktop-final.png),
[phone layout](design/moondesk-icons/journey-schedules-mobile-final.png),
[packaged editor](design/moondesk-icons/journey-packaged-editor-final.png), and
[corrected Markdown preview](design/moondesk-icons/journey-report-markdown-final.png).

The previous installed bundle is preserved at
`_build/desktop-task-journeys-20261014/MoonDesk.previous.app`.
