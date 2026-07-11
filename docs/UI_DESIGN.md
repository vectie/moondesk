# MoonDesk UI Design

## Visual Goal

MoonDesk should feel like a focused desktop workbench:

- Codex-like professional shell
- Finder-like file navigation
- research-studio previews
- MoonCode activity visible but not dominant

It should not look like the Wenyu Valley game viewport. The town viewport is a
linked visualization, while MoonDesk is the practical human workspace.

See [Desk Mode Design](DESK_MODE_DESIGN.md) for the current product decision:
MoonDesk's primary mode is a read-only virtual filesystem desk, with MoonWiki
and MoonCode as activities on the selected book/path context.

## Shell Layout

```text
┌────────────────────────────────────────────────────────────────────┐
│ title bar / command palette / active workspace / sync status        │
├────┬──────────────────────┬──────────────────────────────┬─────────┤
│rail│ files                │ editor / preview tabs         │inspector│
│    │ books/files/inbox    │ markdown/html/json/images     │MoonCode │
│    │                      │ generated outputs             │metadata │
├────┴──────────────────────┴──────────────────────────────┴─────────┤
│ bottom drawer: logs, artifacts, requests, search results            │
└────────────────────────────────────────────────────────────────────┘
```

## Main Surfaces

### Workspace Mode Switcher

The title bar exposes three first-class modes for the selected book:

- `Desk` is the Finder/File Explorer style virtual filesystem browser for
  MoonBook projects, directories, files, and metadata. It is read-only in the
  first implementation.
- `MoonWiki` keeps the existing book/wiki workspace for files, previews,
  inbox, publishing, town status, and review.
- `MoonCode` switches the same book into a coding/chat workspace with the
  session list, transcript, composer, runtime status, and code-oriented review
  panels.

The switch is a product boundary, not a visual shortcut. Desk owns navigation
context. MoonWiki and MoonCode operate on that selected context. MoonCode can
later be extracted as a standalone component while MoonDesk remains the native
host.

### Activity Rail

- Files
- Search
- Inbox
- Town
- Runs
- Settings

### Desk Files

Book-first navigation:

- All Books
- Favorites
- Recent
- Inbox
- Generated Outputs
- Run Artifacts

Each book expands into:

- Wiki
- Raw Evidence
- Reviews
- Generated Site
- Journal
- MoonClaw Runs

### Preview Tabs

The central area should support:

- Markdown source/preview split
- HTML preview
- JSON tree inspector
- image preview
- report reader
- generated site iframe
- artifact summary
- diff/review view

### MoonCode

The MoonCode surface is the first coding/chat workspace slice. It should support:

- per-book MoonClaw session list
- selected-path prompt composer
- visible daemon/model/run state
- model and web-search controls
- send/cancel/refresh actions
- MoonCode review controls for run tests, run build, run eval, package,
  accept, reject, and cancel commands
- MoonCode contract inspector for protocol, command specs, display tool specs,
  executable tool contract, approval policy, expected event lanes, tool hints,
  output roots, native/MoonCode tool-call contract shapes, unknown-tool rejection
  policy, and the MoonCode runtime contract for agent runtime, session
  store, tool registry, loop, command protocol, eval harness ownership,
  the `/api/mooncode/eval-harness` contract endpoint, and MoonCode eval
  reference paths
- MoonCode engine-readiness panel that shows the configured MoonClaw service,
  daemon state, safe `/v1/models` probe, native `/v1/code/capabilities`
  contract state, sidecar append-only log, missing MoonClaw runtime contract endpoint,
  and missing MoonCode eval evidence
- visible runtime mode for the selected session, distinguishing native
  `/v1/code/sessions/<id>/commands` intake from recorded or failed commands
- visible stream source for the selected session/live tail, distinguishing
  native `/v1/code/sessions/<id>/stream` events from MoonDesk's
  append-log projection
- MoonCode readiness/eval checklist for book scope, MoonCode session attachment,
  transcript, tool, diff, test, artifact, review, append-log, typed command
  packets, typed session snapshot, verified test results, MoonBook review
  receipts, source-bound package manifests, and live-stream coverage, including
  the current incremental stream cursor endpoint
- MoonCode Eval Report panel in the center pane that exposes passed/missing
  checks, required native harnesses, persisted
  `wiki/reviews/mooncode/<session-id>/eval-report.json` path, native eval
  source/endpoint, native proof ingest endpoint, and the MoonClaw-owned eval
  proof gap before raw event lanes
- MoonCode Runtime Handoff panel in the center pane that exposes the resumable
  `wiki/reviews/mooncode/<session-id>/runtime-handoff.json` artifact, ordered
  session snapshot, command/event log paths, runtime command feed path,
  MoonDesk session-store, stream, command, and runtime-feed endpoints, native
  MoonClaw endpoints, output roots, runtime mode, and next runtime step for an
  standalone `mooncode` backend
- MoonCode Runtime Supervisor panel in the same handoff board that shows
  whether the next turn is launchable, the replay/native mode, scheduler
  effect, command/action, claim/ack/event/session endpoints, MoonClaw root, and
  ordered supervisor loop without making MoonDesk execute tools. It also shows
  the embedded readiness status and missing launch requirements, so blocked
  turns are diagnosable without opening JSON.
- MoonCode session header at the top of the coding workspace that shows the
  selected book/session, next required action, stream source, runtime state,
  event/diff/test/tool/package counts, eval evidence, and durable resume/log paths
  before the transcript and review panels
- MoonCode preflight gates panel that reads the server-side package, accept,
  commit, and selected-path apply/revert patch gates before command intake,
  showing exact selected file/hunk blockers for tests, diffs, source-bound
  packages, runtime patch proof, and tool approvals
- MoonCode Action Plan rows show command-scoped runtime evidence status,
  required/proven event counts, and exact missing/failed MoonClaw/MoonCode event
  names so operators can tell whether a command is merely delivered, running, or
  actually proven by typed runtime events
- MoonCode code-review queue that promotes diff-lane events into open,
  file-targeted accept/reject, and package controls before the broader
  tool/event lane grid
- MoonBook receipt visibility for accepted/rejected/packaged coding results,
  sourced from `wiki/reviews/mooncode/<session-id>/...json`
- MoonBook change-set visibility for the current session, sourced from
  `wiki/reviews/mooncode/<session-id>/change-set.json`, so the operator can see
  whether diff/test/artifact/review evidence has a durable book-owned review
  object
- MoonBook patch-set visibility for the current session, sourced from
  `wiki/reviews/mooncode/<session-id>/patch-set.json`, so file diffs have a
  durable pending/accepted/rejected/applied/reverted staging object with
  stable hunk targets, compact hunk counts, gate status, next action,
  per-file Open/Accept/Reject/Apply/Revert/Package controls, and per-hunk
  Accept/Reject/Apply/Revert commands before MoonClaw owns true patch execution
- MoonCode command-queue visibility in the center pane and readiness/contract
  surfaces, sourced from
  `.moonsuite/products/mooncode/sessions/<session-id>/commands.jsonl`, so operator
  intent is auditable as ordered `mooncode.v1` packets separately from rendered
  transcript and event progress, with latest packet rows and target-aware Test
  and Package controls
- MoonCode composer semantics match the ordered MoonCode command protocol: no selected session
  starts a session, an idle selected session sends the text as a typed `prompt`
  command, and a running or queued selected session sends the text as a typed
  `steer` command through the MoonCode command route
- MoonCode pending-steer feedback in the session header and command queue,
  computed from durable `steer` commands minus `steer_applied`/`steer_dropped`
  runtime events, with `steer_deferred` shown separately as saved next-turn
  context, so a sent steer is visible while MoonClaw
  has not yet confirmed whether it was applied or dropped
- MoonCode Eval Report and primary command surfaces have Run Eval controls that
  enqueue a typed `run_eval` command through the ordered runtime queue, asking
  MoonClaw for `tool_harness` and `file_edit` native
  proof instead of executing harnesses inside MoonDesk
- MoonCode runtime-feed visibility in the center pane, sourced from
  `.moonsuite/products/mooncode/sessions/<session-id>/runtime-commands.jsonl`, so the
  MoonClaw-facing feed is visible even before runtime receipts or runtime
  leases exist, with compact execution summaries for planned tools, expected
  events, required outputs, and replay/event sinks
- MoonCode runtime-replay visibility in the center pane, sourced from
  `/api/mooncode/sessions/<session-id>/runtime-replay`, so operators can inspect
  pending MoonCode JSONL protocol commands, replay readiness, delivered/claimed/
  invalid counts, and per-command decode status before MoonClaw executes the queue
- MoonCode runtime-claim controls in the Runtime Claims panel, sourced from
  `POST /api/mooncode/sessions/<session-id>/runtime-claim`, with Claim Next and
  Force Claim buttons that lease one runtime command for the
  `moondesk-ui-inspector` consumer without executing tools in MoonDesk
- MoonCode runtime-replay acknowledgement controls on claimed Runtime Claims
  rows, sourced from `POST /api/mooncode/sessions/<session-id>/runtime-replay`,
  with Ack, Complete, and Fail buttons that record operator/debug receipts and
  refresh replay, receipt, event, handoff, and action-plan state
- MoonCode runtime-event sink visibility in the center pane, sourced from
  `/api/mooncode/sessions/<session-id>/runtime-events`, so operators can inspect
  the event log path, event count, POST endpoint, accepted MoonClaw/MoonCode
  payload shapes, normalization rule, and latest normalized runtime events
  before they are projected into lanes, plans, evals, and review artifacts
- MoonCode live-tail visibility keeps a bounded, id-deduped recent stream
  buffer across successive polls, so the operator sees stable coding progress
  even when the latest poll returns no new event rows
- MoonCode action-plan visibility for the current execution/review state,
  sourced from `wiki/reviews/mooncode/<session-id>/action-plan.json`, with
  compact acceptance gates, `next_required_action`, command state rows, and
  target-aware Test/Package/Accept/Reject controls
- MoonCode runtime-evidence visibility, sourced from
  `GET /api/mooncode/sessions/<session-id>/runtime-evidence`, with aggregate
  command proof counts, runtime/event log paths, and per-command missing or
  failed required runtime events so operators can distinguish queued intent
  from MoonClaw-proven execution
- MoonCode tool-authorization probes for the selected session/path, sourced
  from `POST /api/mooncode/sessions/<session-id>/tool-authorization`, with
  explicit Read/Write/Shell probe buttons, current decision, approval state,
  target, reason, and matching approval row before MoonClaw executes a gated
  tool
- MoonCode runtime execution summaries that render the ordered claim/tool/event/
  output/ack checklist from each command's `result_contract`, so operators can
  compare MoonClaw progress against machine-readable execution requirements
- MoonCode tool-approval visibility for policy/review-gated shell, write/edit,
  diff, and artifact work, sourced from
  `wiki/reviews/mooncode/<session-id>/tool-approvals.json`, with per-row Open,
  Approve, and Reject controls
- MoonCode test-run visibility for test/build evidence, sourced from
  `wiki/reviews/mooncode/<session-id>/test-runs.json`, with passed/failed,
  running/queued counts and per-row Open, Rerun, and Package controls
- MoonBook package-manifest visibility for package candidates, sourced from
  `portable/app-tool/mooncode/<session-id>/package-...json`, including
  source-bound/missing status, manifest/receipt paths, source inventory, file
  hash evidence, and Open/Test/Accept/Package controls
- persisted transcript/status records plus saved MoonClaw assistant/tool/failure
  event projection and bounded workspace-log progress projection
- MoonCode lanes for tools, diffs, tests, artifacts, and review decisions
- MoonCode live-tail panel driven by the bounded
  `/stream?format=jsonl&live=true` cursor for the selected session
- bottom-drawer summary for the selected session

### Right Inspector

Context for the selected file or workspace:

- file metadata
- citations/source info
- owning book
- current standing goal
- related runs
- keeper decisions
- available actions

### Bottom Drawer

Operational visibility:

- request ledger
- town messages
- MoonClaw run events
- build output
- validation warnings
- latest daemon and standing-watch summary

## Command Palette

Required commands:

- Open Book
- Create Book Inbox Note
- Import Files
- Import URL
- Open MoonCode
- Submit to Town
- Run Daemon Tick
- Start Daemon
- Stop Daemon
- Restart Daemon
- Enable Daemon Supervision
- Disable Daemon Supervision
- View Cadence Calendar
- Open Calendar Export
- Review Outcome Analytics
- Save Current View
- Tag Selection
- Build Book Site
- Open Generated Site
- Show Run Artifacts
- Reveal in Finder
- Search All Books
- Toggle Inspector

## Request Composer

The composer should support:

- selected files/pages as context
- free-form prompt
- target book
- one-shot or standing-watch cadence
- review policy
- source policy
- submit to MoonTown
- create or update standing-watch records in `.moonsuite/products/moontown/standing-goals.json`
- run a single daemon tick through the scoped host action
- start, stop, restart, supervise, and inspect the background daemon loop

## Desktop Interactions

Phase 1 browser mode:

- drag files into inbox using browser APIs where available
- click previews
- local API writes staged inbox files
- URL import writes staged inbox/import notes

Phase 2 MoonBit host mode:

- host-backed open/import flows
- scoped reveal in Finder
- open with external app
- drag/drop from Finder
- clipboard images
- desktop notifications
- signed self-contained `.app` bundle created through `cmd/main bundle`
- release manifest/notarization path through `cmd/main release`
- LaunchAgent template generation for login startup policy

## Codex Outlook Matching

Use these visual principles:

- dense split-pane shell
- subdued neutral background
- blue/teal accent for active states
- small caps/status pills for state
- high-contrast active tab
- monospace for paths/logs
- clear empty states
- keyboard-first navigation

Avoid:

- game-style map as primary UI
- random gradients
- generic dashboard cards only
- hiding files behind marketing copy
