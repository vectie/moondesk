# MoonDesk UI Design

## Visual Goal

MoonDesk is a quiet, dense desktop workbench. It combines Finder-like project
navigation with focused MoonWiki and MoonCode workspaces. The interface should
make the selected MoonSuite root, MoonBook, mode, session, and current content
obvious without turning diagnostics into the primary experience.

Use restrained neutral surfaces, clear selected states, familiar icons,
compact controls, readable code and paths, and stable split-pane dimensions.
Avoid marketing composition, decorative cards, gradients, nested panels, and
status copy that claims work without evidence.

## Shell

The persistent shell contains:

- a mode switcher for Desk, MoonWiki, MoonCode, and Flow
- the active MoonBook or General scope
- a stable navigation rail
- one primary work surface
- optional contextual actions that do not displace the primary content

The shell must not flash a different mode, empty front page, or previous
session during asynchronous hydration. Route state and selected product state
must converge before an empty state is committed.

## Desk

Desk is the read-only virtual filesystem view. It supports book-first browsing,
directory navigation, file selection, preview, search, inbox, generated output,
and artifact inspection. MoonWiki and MoonCode inherit the selected MoonBook
and real file context; synthetic paths are never sent as code context.

## MoonWiki

MoonWiki owns durable knowledge editing, preview, publish, review, and source
workflows. It shares the shell and MoonBook selection but does not share a chat
projection with MoonCode.

## MoonCode

MoonCode answers one user question: what coding conversation am I having in
this MoonBook?

The surface has three stable regions:

1. Session rail: MoonBook groups and session titles.
2. Transcript: one canonical append-ordered conversation.
3. Composer: model-aware prompt input and a clear submit action.

### Session Rail

- Group sessions by MoonBook; use General for unbound sessions.
- Preserve the durable listing order inside each group.
- Show the active group and session without moving them during hydration.
- Keep session rows compact: title plus one factual status or relative time.
- A listing transport/decode failure preserves the last good rail and exposes a
  retry state; it must not look like a real zero-session catalog.
- New Chat creates a draft surface. Typing into that draft cannot switch back
  to an existing session.
- Future rename, archive, delete, and search actions belong in row menus or a
  compact rail toolbar, not in the transcript.

### Transcript

- Render only the selected MoonClaw canonical turn list plus local optimistic
  user rows that have not yet been acknowledged.
- A turn is visually ordered as user message, factual work, assistant answer.
- The user row appears immediately after mouse submit or Enter.
- Do not show a spinner, work row, or "working" text until MoonClaw emits a
  turn-owned signal.
- Update live work in place. Never prepend work to the session or reorder prior
  turns.
- Completed work remains between its user message and answer and folds with
  native disclosure behavior.
- The folded summary describes user-relevant progress. Raw event names,
  protocol messages, process logs, and debugging detail stay out of ordinary
  chat.
- Render assistant Markdown safely. Code blocks and answers have familiar copy
  actions; diffs and test evidence identify their file or command source.
- Empty, loading, reconnecting, failed, cancelled, and completed states are
  distinct and factual.

### Composer

- Enter submits; Shift+Enter inserts a newline.
- Submit clears the input only after the optimistic user row has been appended.
- The control remains associated with the visible selected session or draft.
- Stop is available only when MoonClaw reports cancellable work.
- Model and web-search choices are compact and must eventually persist per
  session.
- Background daemon/model metadata cannot overwrite an active draft's composer
  state.

### Accessibility

- Native buttons, textboxes, and `details`/`summary` controls are required.
- Keyboard order matches visual order.
- Focus remains in the composer after submit unless the user navigates away.
- Factual asynchronous status changes use a polite live region without moving
  focus.
- Selected state is conveyed semantically and not by color alone.
- Touch targets remain usable at narrow widths; text wraps without overlap.
- Reduced motion removes nonessential transitions while preserving state
  changes.

## Information Hierarchy

Ordinary users see conversation and code outcomes first. Diagnostics are
progressively disclosed and must answer an actionable question. Do not surface
internal command queues, replay receipts, runtime claims, raw journals, or
adapter contracts in the main transcript. Those belong in developer tooling or
an explicit diagnostics view.

## Command Palette

The palette should expose clear product commands such as:

- Open MoonBook
- Open MoonCode
- New MoonCode Chat
- Search All MoonBooks
- Import Files or URL
- Build MoonBook Site
- Reveal in Finder
- Start, Stop, or Restart managed services
- Show generated outputs or run artifacts

Palette results must use icons from the existing icon system, preserve keyboard
focus, and avoid duplicating controls already visible next to the active object.

## Desktop Interactions

Browser development uses the local MoonDesk server. The Lepusa production host
provides native file selection, reveal, drag/drop, clipboard, notifications,
service supervision, and packaged asset behavior. Both hosts must render the
same route and conversation contracts.

## Responsive Behavior

- Desktop: persistent session rail and full transcript.
- Narrow desktop/tablet: collapsible rail that preserves selection.
- Phone-sized validation: transcript and composer remain usable even if the
  full desktop shell is not a shipping target.
- Fixed controls must use stable dimensions so loading, labels, and status
  changes do not shift surrounding content.
- Long session titles truncate in the rail and remain available through an
  accessible name or tooltip.

## Validation Matrix

Every UI release must inspect these states in a real browser:

- cold load with persisted sessions
- no sessions, listing failure, and MoonClaw unavailable
- new General chat and MoonBook-bound chat
- first through fifth turn
- immediate optimistic row before any runtime signal
- factual live work, completion, failure, retry, and cancellation
- session switch during an active watch
- hard reload and MoonClaw restart
- long Markdown, code blocks, diffs, tests, and long session titles
- keyboard-only, reduced-motion, narrow, and desktop layouts

Acceptance requires stable order, no blank-page flash, no duplicate rows, no
revision rollback, no unexplained working state, and no overlapping content.
