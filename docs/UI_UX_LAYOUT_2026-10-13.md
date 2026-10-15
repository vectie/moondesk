# MoonDesk: columns before controls

This pass responds to the review of the second icon pass: the surface still
looked crowded because its layout did not establish a primary place to work.

## Reference and diagnosis

The local `../codex` checkout contains the CLI, TUI, SDK and app server rather
than the desktop view implementation. Native Codex capture was unavailable.
The reference inspected was the official desktop illustration in
[Work with files](https://learn.chatgpt.com/docs/artifacts-viewer?surface=app),
alongside the navigation illustration in
[Features](https://learn.chatgpt.com/docs/features). The relevant arrangement is
a conversation with an adjacent file preview, local pane controls and compact
navigation. Dimensions below are MoonDesk design decisions, not measurements
of native Codex.

The previous MoonDesk viewport stacked the application header, conversation
header, installation notice and workbench toolbar before the actual content.
Its fixed 280px navigation left two narrow working columns at 977px. Chat was
on the right, and the composer split its settings over several rows. The
MoonVis reference used a large editorial introduction and long page of examples.

## Implemented arrangement

| Region | Rule |
| --- | --- |
| Application bar | One 52px row; compact labeled destination navigation. |
| Chat navigation | 224px on wide screens; collapsible. Below 1100px, an optional 260px overlay with an explicit close control. |
| Workspace header | One 48px row; title and chat settings align with the tool pane controls. |
| Main conversation | First in DOM and visual order. New workspaces start here. Existing explicit pane choice is retained. |
| Tools | Optional right column from 1280px. Both content columns have at least 420px. Below that, a tool uses the main surface and closing it returns to chat. |
| Composer | Bounded to 640px; model on the left, message actions on the right. Reasoning and task purpose use a settings disclosure. |
| Empty state | A centered heading, composer and relevant setup notice. No empty source editor opens alongside a new workspace by default. |
| Status | Setup sits with the chat it affects. Selection errors remain visible as transient feedback without adding a permanent header row. |
| Source | File path and open/save actions share one row. Editor height is no longer capped by the old stacked Git layout. Location navigation and declaration outline live under Edit tools. |
| Documents | Office editing is a disclosure beneath the source workspace; opening an Office file expands it. |

On phone widths, the application destination stays in the first row, conversation
context in the second, and workspace tools in a compact third row. Each working
surface scrolls within its own area. The chat list is not stacked above the work.

## Interaction details

- Tool launchers become tabs when a pane is open; hidden panes do not appear selected.
- Sidebar open state is remembered; narrow layouts support close, outside click and Escape.
- Adding source context returns to a visible composer, including on narrow screens.
- Hiding a tool preserves its source buffer. Closing composer settings preserves chosen values.
- The settings summary translates both its sentence and selected values into English or Simplified Chinese.
- Existing draft, setup, drawer and tooltip behavior remains in use.

## MoonVis

`../moonvis/docs/icon-workbench.html` now uses a 200px navigation column,
52px header, central active view and optional 240px icon inspector. Icons,
Layout and Interactions are separate views. The coding specimen uses aligned
48px chat/tool headers and a bounded composer. Phone widths show one region at
a time. The 72 production SVGs, search, family filter, keyboard tabs and review
drawer remain available. See `../moonvis/docs/ICON_LANGUAGE.md` for the rules.

## Verification

- MoonBit JS check, interface generation, formatting and release build passed.
- Four focused MoonBit composer tests passed; no frontend public interface changed.
- 26 focused JavaScript tests passed, including retained controls, initial layout,
  tab keys, context handling, tooltip dismissal and translation coverage.
- Two source DOM integration tests passed for location navigation and declaration outlines.
- Production preview built with Vite/esbuild; existing compiler warnings remain.
- Visual checks cover the 1440px desktop split, 977px single surface, and 375px
  mobile layout. Screenshot evidence lives in `docs/design/moondesk-icons/`.

Evidence: [desktop](design/moondesk-icons/layout-moondesk-desktop.jpg),
[mobile](design/moondesk-icons/layout-moondesk-mobile.jpg),
[MoonVis](design/moondesk-icons/layout-moonvis-desktop.jpg).

This verifies the layout against the isolated local demo and source preview.
The demo has no connected coding model, so no live model run was used as part
of visual verification.

## Packaged application follow-up

On 2026-10-13 the current native release backend and verified frontend were
packaged into `_build/desktop-layout-20261013/MoonDesk.app`, installed at
`/Applications/MoonDesk.app`, and opened in the existing `coding` workspace.

- Used the local `../lepusa` checkout via the supported `--lepusa` option. The
  published dependency's older transitive source fails with the installed
  compiler; the local host and packaging CLI built successfully.
- Used port 4201 because the existing LaunchAgent owns 4199. The app runs its
  bundled sidecar and serves its bundled assets independently of the previews.
- Retained the existing application workspace under
  `~/Library/Application Support/app.vectie.moondesk.lepusa.live/workspace`.
- Configured this local bundle's launcher to supply the existing
  `MOONDESK_EXECUTION_SANDBOX_CONFIG` path, defaulting to
  `$LEPUSA_APP_DATA_DIR/control/execution-sandbox/moonclaw.json`. This matches
  the existing background service configuration; credentials stay in that
  private file. This is a local package adjustment and must be retained when
  replacing this bundle with another local build.
- Bundle validation and `codesign --verify --deep --strict` passed. Packaged
  frontend files exactly match `ui/rabbita-desk/dist`.
- Native UI verification showed the compact navigation, aligned toolbar and
  composer, existing session history, and a populated model selector. The
  packaged `/api/mooncode/status` returned `MoonCode runtime is ready`.
  No model request or file edit was submitted during this check.

Native screenshot: [installed MoonDesk](design/moondesk-icons/layout-moondesk-packaged.jpg).

## Density follow-up

The native review exposed excess space in the sidebar and empty composer.
The duplicate "Ask MoonCode" heading is removed; the prompt remains the input
placeholder and accessible name. Session totals no longer appear beneath the
composer; actionable status and error messages remain visible.

Desktop chat rows now use one 32px line instead of a minimum 54px two-line row,
with regular-weight titles, a 12px indent and a compact trailing menu. The
repeated "Ready" subtitle is omitted. Other states and timestamps sit inline.
Group headings use 28px rows, search uses 30px, and gaps between rows are 2px.
Touch and phone controls retain 44px targets. The composer input starts at
40px rather than 68px, with 10px vertical padding and 6px internal gaps.

The updated frontend passed interface generation, formatting, release build
and all four focused composer tests. The installed app at
`/Applications/MoonDesk.app` now uses the density build from
`_build/desktop-density-20261013/MoonDesk.app`, retaining the previously
verified native binaries and local MoonClaw configuration. Its signature and
embedded frontend comparison passed. The prior installed app is retained as
`_build/desktop-density-20261013/MoonDesk.previous.app`.

Native evidence: [compact installed layout](design/moondesk-icons/layout-moondesk-density-packaged.jpg).

Command and the destination tabs now share one typography rule: the same UI
font stack, weight and line height, with a shared size of 12px in Code and
13px elsewhere. Browser computed styles confirmed the match. This frontend
is installed in `/Applications/MoonDesk.app`; the package is retained at
`_build/desktop-command-font-20261013/MoonDesk.app`.

## Shared destination standard

The accepted Code layout is now the baseline for Desk, Book (Wiki), Flow and
Packs. `workbench-layout.css` owns the shared 52px application bar, including
12px destination and Command typography. `destination-layout.css` applies
the 48px pane heading, 32px desktop row, 224px navigation rail, restrained
borders and flat surfaces to the other destinations. Phone and touch actions
retain 44px targets. Document and message content keep readable line spacing.

- **Desk:** single-line MoonBook rows, compact folder and file rows, inline
  location, and a selection inspector opened from the top-right panel icon.
  Storage, services and saved work are disclosures. The file list no longer
  loses half its height to an always-visible details pane on smaller laptops.
  Repeated setup status is a named information icon, keeping long book names
  readable; hover and accessibility names retain the full status.
- **Book:** 48px chat and viewer headings; Find, Synthesize, Review, Attach,
  Send, Choose document and Open original use named icon controls with
  tooltips. A flex layout gives remaining height to messages rather than
  stretching the composer. Attachment drop target and warnings remain visible.
- **Flow:** 48px context bar, a full-width canvas with compact tools, and
  status details available through disclosure. The empty canvas message is
  centered in the actual viewport rather than positioned at fixed coordinates.
- **Packs:** compact header, applications and templates first, agents in
  concise rows. Passport capability counts, Pack Studio and collaboration
  are available on demand. The generic landing-page headline and repeated
  implementation explanations no longer occupy the primary workspace.
  Installed applications use the same row treatment, with launch beside the
  identity and bridge/capability statistics inside Advanced controls.

No execution, authority, provider or data contracts change in this pass.

### Verification and packaged update

- Browser computed styles confirm all five destinations and Command use the
  same font stack, 12px size, 760 weight and 15px line height, in a 52px bar.
- Desktop and 390px phone views were inspected for Desk, Book, Flow and Packs.
  No horizontal page overflow was found. Desk's inspector opens and dismisses
  with Escape; the passport disclosure reveals its capabilities and counts.
- Existing Wiki/workspace and quick-access tests passed (62 focused cases
  across the final runs). Interface generation and the JS release/Vite build
  succeeded; generated public interfaces did not change. Existing compiler
  warnings remain unrelated to this presentation change.
- `/Applications/MoonDesk.app` contains this frontend, with the working native
  runtime and local MoonClaw configuration retained. The staged app is
  `_build/desktop-destinations-20261013/MoonDesk.app`; the preceding installed
  version is preserved beside it as `MoonDesk.previous.app`. Code signature
  verification and comparison of every embedded frontend file both passed.

Preview evidence: [Desk](design/moondesk-icons/layout-destinations-desk.png),
[Book](design/moondesk-icons/layout-destinations-book.png),
[Flow](design/moondesk-icons/layout-destinations-flow.png),
[Packs](design/moondesk-icons/layout-destinations-packs.png),
[phone](design/moondesk-icons/layout-destinations-mobile.png).

The installed native app was also inspected with the existing library and
MoonFish pack. Native evidence: [Desk](design/moondesk-icons/layout-destinations-packaged.jpg),
[Book](design/moondesk-icons/layout-destinations-book-packaged.jpg),
[Flow](design/moondesk-icons/layout-destinations-flow-packaged.jpg),
[Packs](design/moondesk-icons/layout-destinations-packs-packaged.jpg).

## Packs revision: cards, a searchable collection, and one inspector

The populated library exposed a problem with the previous destination pass:
44 agents produced 100px rows, and one application occupied a 1180px-wide
strip. Removing a few margins did not address the repeated controls and
metadata. This revision replaces that treatment:

- Applications use small wrapping launcher cards with identity, category,
  an information icon and a launch arrow. Configuration messages remain
  visible when action is needed. Disabled applications remain disabled.
- Agents use 40px desktop rows in two columns, with a single-line name,
  a selected indicator, plus for starting a task and status/details control.
  Selecting the name retains the previous selection behavior; the selected
  agent's name opens its chat. Full names remain available on hover.
- A local search filters names, book identities, summaries and capabilities.
  It preserves the library and current MoonBook, announces result counts,
  offers clear, and shows an explicit no-results state.
- A single 380px inspector holds passports, versions, examples and capability
  counts. Pack Studio, collaboration and runtime explanation open there from
  the header, so users do not scroll past the entire agent library to reach them.
- Repeated action words and source/version subtitles leave the collection;
  icon actions retain accessible names and hover/focus tooltips. The attention
  glyph has a different shape from info and describes the actual status.
  Phone layout is one column, with 44px touch controls.

The pattern is documented in MoonVis: cards for distinct launchable products
and outcome previews, rows for large homogeneous collections, and an inspector
for the selected object's detail. This supersedes the earlier recommendation
to use the same row treatment for installed applications and agents.

### Checks and packaged update

- The real library (44 agents and the installed MoonFish app) was checked at
  1280px and 390px. Desktop rows measure 40px instead of 100px; the app card
  measures 287.5 × 86px instead of 1180 × 112.5px. The 720px-high desktop
  preview shows 22 agents. Phone action targets measure 44 × 44px, with no
  horizontal page overflow.
- Search, no-results, clear, app/agent inspection, Escape with focus return,
  outside dismissal and the task picker were exercised. No task was submitted.
- All 11 focused Packs tests pass. Interface generation, formatting and the
  Vite production build pass. The generated interface gains the expected
  `PackInspection` state type; existing compiler warnings are unchanged.
- `/Applications/MoonDesk.app` was updated from the final frontend build.
  Signature verification and a complete embedded-file comparison pass.
  The native runtime is reused. Staging and rollback copies are in
  `_build/desktop-packs-compact-20261013/` (`MoonDesk.app` and
  `MoonDesk.previous.app`, respectively).

The installed app was reopened and visually verified on Packs with the existing
44-agent library; the local MoonCode runtime reports ready. Evidence:
[native app](design/moondesk-icons/layout-packs-compact-packaged.jpg),
[desktop](design/moondesk-icons/layout-packs-compact-desktop.png),
[phone](design/moondesk-icons/layout-packs-compact-mobile.png),
[inspector](design/moondesk-icons/layout-packs-compact-inspector.png).

## Packs follow-up: smaller cards that flow

The previous two-column agent layout still allocated too much width per item.
Applications and agents now share an auto-fill grid with a 224px minimum
column width, 6px gaps and no centered 1180px cap. Columns grow with the window;
there is no two-column limit. Empty tracks retain the small card size when
search leaves only one result.

Agent tiles are 32px tall on desktop, with 12px names using up to two short
lines and 28px actions. App cards have 24px marks, tighter padding and actions
beside each other. Touch actions remain 44px. This is a stylesheet-only update;
selection, search, task launch and inspection behavior are unchanged.

The real 44-agent library uses five columns at 1280px and six at 1600px,
with all agents visible in the 720px-high desktop viewport. At 390px it
flows to one column; actions measure 44 × 44px. No horizontal overflow was
found. The production build passes, and `/Applications/MoonDesk.app` now
contains this frontend; its signature and embedded-file comparison pass.
The preceding package is preserved at
`_build/desktop-packs-flow-20261013/MoonDesk.previous.app`.

Desktop app cards measure approximately 245 × 63px (previously 288 × 86px),
and agent tiles measure 245 × 32px (previously 578 × 40px). A one-result
search retains the same tile width. App and agent grids share the same left
edge and full workspace width. Evidence:
[desktop](design/moondesk-icons/layout-packs-flow-desktop.png),
[phone](design/moondesk-icons/layout-packs-flow-mobile.png).

The installed app was reopened and left on Packs after visual verification:
[packaged app](design/moondesk-icons/layout-packs-flow-packaged.jpg).

## 2026-10-14: one MoonBook collection

Agents were a second projection of the MoonBook library. That duplication is
removed from Packs, which now contains applications and output templates.
Application details, Pack Studio and runtime help remain in its inspector.
The frontend no longer requests or stores the duplicate agent catalog;
backend agent execution APIs are unchanged.

Each compact MoonBook card in Desk now has two always-visible icon actions:

- The name selects the book and its files.
- The chat bubble selects the named book and opens its chat in one action.
- Plus selects the named book and opens the task picker, without submitting.

The selected book's existing chat and file context survive actions on that
same book. Existing pending-edit navigation behavior also applies when
switching books. Buttons are separate accessible controls with names and
tooltips, rather than nested inside the selection button.

Search moves to the MoonBook library and matches name, identity and location.
It preserves the library and selection, and supports clear and no-results
states. Cards keep the 32px desktop rhythm and 28px icon controls; touch
actions and search retain 44px targets. This supersedes the agent-grid
recommendations earlier in this change record.

### Verification

The 15 focused Packs and workspace-action tests pass. JS checking, interface
generation and formatting pass. Generated interfaces remove the obsolete
frontend agent catalog types and add the MoonBook action type.

The real library was inspected at desktop width and 390px. MoonBook cards
measure 207 × 32px in the desktop rail; phone action targets measure 44 × 44px
with no horizontal page overflow. Direct chat, cross-book task selection,
search, no-results and clear were exercised without submitting a task.
Packs shows the installed MoonFish application with no Agents section.

The production frontend build passes. `/Applications/MoonDesk.app` was
updated with that build; signature verification and comparison of all embedded
frontend files pass. The native runtime is reused. The preceding installed
app is preserved at
`_build/desktop-moonbook-actions-20261014/MoonDesk.previous.app`.

Browser evidence: [desktop](design/moondesk-icons/layout-moonbook-actions-desktop.png),
[phone](design/moondesk-icons/layout-moonbook-actions-mobile.png).

The installed app was reopened and both destinations were visually verified
with the real library. It is left on Desk with coding selected; MoonCode
reports ready. Native evidence:
[MoonBook actions](design/moondesk-icons/layout-moonbook-actions-packaged.jpg),
[Packs](design/moondesk-icons/layout-packs-apps-only-packaged.jpg).

## 2026-10-14: follow the work from entry to output

The app header now names and switches the current MoonBook, with compact
shortcuts for task entry, conversations, results and book tools. A contextual
return arrow carries the previous work location. Switching books remembers
document drafts, attachments, conversation, file selection and Code context
within the running app.

Plus opens a focused goal form, a Book/Code working-view choice and compact
presets. The broad thirteen-tab toolbox is replaced by separate task entry
and grouped detail drawers. Book chat names its current task/file and exposes
results/export. Files open on double-click or Enter; Markdown opens beside
chat and can enter the existing editor.

Result bundles expose their exact outputs, revision and recurring-request
entry points. Pack apps use a persistent frame with Back to Packs, Results,
Attach file and a separate-window link. Flow's empty state opens task entry
or a real workflow-file picker.

The implementation boundaries and complete job mapping are in
[User journeys](USER_JOURNEYS_2026-10-14.md#implemented-journey-cleanup).
No native runtime or backend execution changes were introduced.

### Verification and package

- 97 focused MoonBit tests and 53 JavaScript tests pass; the four new journey
  tests were rerun after the final task-entry timing fix.
- Interface generation, formatting and the production frontend build pass.
- Real-library checks cover cross-book draft restoration, Markdown opening,
  Code preset staging, result drawers, Flow's picker, and MoonFish return.
- At 390px, task preset controls are 44px tall with no page overflow.
- Updated `/Applications/MoonDesk.app`; verified its signature and equality
  of embedded frontend files with the production build. The previous app is
  preserved at `_build/desktop-work-journey-20261014/MoonDesk.previous.app`.

Evidence: [work and results](design/moondesk-icons/layout-work-journey-desktop.png),
[phone task entry](design/moondesk-icons/layout-work-journey-mobile.png).

The final installed app was relaunched and cross-book task entry was checked
in the native window. It is left with coding selected and the task picker
open. [Packaged app evidence](design/moondesk-icons/layout-work-journey-packaged.jpg).

## Journey completion follow-up — 2026-10-14

Report outputs now remain connected to their conversation and sources. File
download exports the actual output, while result export includes its own
transcript and references. Book's Markdown editor exposes Save, Cancel and ⌘S.
Recent tasks restores the unsent prompt, attached context, open file, review
panel and transcript reading position. Code layout and scroll are scoped per
book/session.

Schedule creation and management remain beside the originating task. The
compact Schedules drawer provides edit, pause/resume, run now and remove icons.
At 390px the drawer stays within the viewport and controls remain 44px.
Actual schedule execution produced a local, source-cited report with a correct
20% calculation. The MoonFish journey is paused.

99 MoonBit tests, 59 JavaScript tests, 12 owner schedule tests, and the owner
path regression/live execution checks pass. The packaged MoonDesk frontend
matches the production build and its signature verifies. See the updated
[journey acceptance record](USER_JOURNEYS_2026-10-14.md#verification) for evidence
and the MoonTown service prerequisite.
