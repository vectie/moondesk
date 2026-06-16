# Moondesk Product Plan

## Thesis

Moondesk is a human-facing desktop workspace for the Moon ecosystem.

Moontown is built for AI agents. Moondesk is built for real human users. It
should feel like a combination of Finder, Codex, and a local research studio:
files on the left, active work in the center, agent/progress context on the
right, and durable output/artifact history at the bottom.

## Core Problem

The Moon system can already create useful artifacts across multiple projects:

- Moontown schedules goals and keeps the 24/7 loop alive.
- MoonBook stores durable wiki, raw evidence, generated sites, journals, and
  standing-watch history.
- MoonClaw executes jobs and emits run workspaces, artifacts, logs, and memory
  candidates.

The missing product layer is a convenient human workspace:

- browse all books without terminal commands
- inspect files, pages, artifacts, and generated websites
- drag files into a book inbox
- edit or annotate documents before promotion
- submit requests to Moontown from selected files/context
- watch agent progress without reading raw JSON or logs

## Product Positioning

Moondesk should not replace MoonBook, Moontown, or MoonClaw.

It should sit beside Moontown as a desktop surface:

```text
human user
  -> Moondesk
      -> MoonBook workspaces for files/wiki/site/memory
      -> Moontown for standing goals and dispatch
      -> MoonClaw for runs, artifacts, and execution traces
```

## First Use Case

A user wants a 24/7 research workspace for "one person company".

Moondesk should let the user:

1. Open the `research-opc` MoonBook.
2. See `wiki/`, `raw/`, `site/generated/`, and `history/`.
3. Read the latest standing-watch messages.
4. Drop PDFs, links, or notes into an inbox.
5. Switch from MoonWiki to MoonCode and talk to MoonClaw from the selected book
   context when they want an interactive coding/research assistant.
6. Submit "analyze these files and update the OPC book" to Moontown.
7. Watch the assigned worker activity and MoonClaw artifacts.
8. Open the generated report/site/course output.

## Non-Goals

- Do not make Moondesk another autonomous agent brain.
- Do not let Moondesk own durable wiki semantics.
- Do not let Moondesk execute arbitrary tools directly.
- Do not hard-code domain-specific research procedures into Moondesk.
- Do not hide MoonBook/Moontown/MoonClaw boundaries behind ambiguous generic
  calls.

## Product Modules

### Workspace Explorer

Shows all known MoonBooks and their important folders:

- `wiki/`
- `raw/`
- `site/`
- `book/`
- `wiki/history/`
- `reviews/`
- `.moonclaw/jobs/runs/`
- `moonclaw-jobs/`

### Preview Center

Tabbed preview/edit area:

- markdown preview and source
- HTML preview
- JSON inspector
- image preview
- artifact viewer
- generated site preview
- diff/review panel

### Human Inbox

Book-local staging area for user-provided files:

- drag and drop
- create note
- paste URL
- attach screenshot/image
- mark privacy scope
- submit to MoonBook/Moontown

### Operator Console

Human request composer:

- choose target book
- select files/pages as context
- write request
- choose cadence or one-shot
- submit to Moontown
- watch accepted request id and progress

### Agent Activity

Interactive projection of Moontown and MoonClaw state:

- Mayor messages
- standing goals
- book keeper decisions
- worker runs
- run artifacts
- recent failures/retries
- book-scoped MoonClaw agent sessions
- selected-path chat context
- model and web-search controls
- transcript, progress, tool, and failure rows
- task cancellation and daemon refresh controls

Moondesk does not become an agent runtime here. It provides the human-facing
session surface and delegates execution to MoonClaw through the local daemon.

### MoonCode Workspace

MoonCode is the coding/chat workspace beside the current MoonWiki book
workspace. It is selected through an explicit shell switcher rather than hidden
as an ordinary activity.

MoonCode should support:

- OpenSeek-like durable coding sessions
- prompt, steer, cancel, run-test, package, commit, accept, and reject command flow
  through MoonClaw or the extractable MoonCode protocol
- live assistant/reasoning/tool/result transcript
- file change and diff review
- test/build result panels
- packaging generated code as MoonBook tools, miniapps, generated sites, or
  app-tool books
- runtime-visible capability contract for commands, tool specs, approval
  policy, event lanes, and output roots
- clear extraction path into a standalone `mooncode` component

Moondesk owns the UI and review controls. MoonClaw owns the typed runtime,
tools, streaming protocol, and test/build execution. MoonBook owns accepted
code artifacts and generated outputs.

Current implementation slice: Moondesk exposes `mooncode.v1` capability,
session, event, stream, eval-harness, and command routes. The eval-harness
route (`GET /api/mooncode/eval-harness`) is the standalone, extractable
OpenSeek-style proof contract MoonClaw must eventually own: deterministic
`tool_harness` coverage for `read`, `write`, `edit`, `shell`, `moon_check`,
and `finish`, plus model-facing `file_edit` cases for
exact replacement, ambiguous replacement, multiline edits, file creation, and
compile fixes. The first runtime-neutral code has moved into
`internal/mooncode`: a pure package for OpenSeek-compatible serve-wire helpers
and command/action metadata that `internal/moonwiki` consumes when validating
queued runtime commands, building command packets, calculating dispatch and
approval policy, projecting tool hints/lanes, or exporting `/serve-jsonl`.
Command queue API response shaping is now a separate MoonCode slice from the
action metadata catalog, keeping HTTP-facing queue envelopes apart from core
command semantics.
Default MoonCode command prompt text is also isolated from routing metadata, so
MoonClaw-facing task instructions can evolve without changing dispatch,
approval, lane, or command support tables.
Payload action/context extraction is separated too, keeping request decoding
reusable across Moondesk HTTP handlers and future MoonClaw-facing command
ingestion without mixing it into the command metadata catalog.
OpenSeek serve-wire wrapping and runtime-command record assembly are now
separate MoonCode slices as well, leaving the core command file focused on
durable command packets and command events.
Native command body assembly is similarly separated from tool-authorization
snapshotting and execution-summary projection, keeping runtime body construction
distinct from policy and readiness evidence.
The same package now owns the data-only tool contract for the OpenSeek-style
`read`, `edit`, `write`, `shell`, `moon_check`, and `finish` tools, including
input schemas, output event requirements, review policy, and safety constraints.
That contract catalog is now separated from reusable MoonCode JSON helpers and
tool-entry builders, so the future standalone `mooncode` package can lift the
schema without dragging generic support code behind a catalog file.
MoonClaw's native runtime-turn now supports explicit tool calls, deterministic
prompt planning, and opt-in bounded model-planned tool-call batches when the
queued command carries a selected model; successful tool results are fed back to
the model until `finish`, failure, cancel, or `planner_max_steps`. It records
planner events, `planner_steps`, step limits, native `reasoning_delta` progress,
optional assistant deltas, and pre-execution `tool_call` events before matching
`tool_result` events. It falls back to deterministic planning when the model is
unavailable or emits no supported calls. Native steer commands now settle with
`steer_applied` / `steer_dropped` events, so Moondesk's pending steering counts
are backed by MoonClaw-owned evidence instead of only projected intent.
Native accept/reject commands now also write MoonBook-owned review receipts and
emit `receipt.accept` / `receipt.reject` review-lane events, so review state can
be proven by MoonClaw-owned runtime evidence instead of only desktop intent.
Native `run_eval` commands now run MoonClaw's OpenSeek-style tool/file-edit
harnesses from runtime-turn, write a MoonBook-owned
`wiki/reviews/mooncode/<session-id>/eval-report.json`, and emit
`eval_report.manifest` evidence with `tool_harness` and `file_edit` results.
MoonClaw's native runtime-loop now
supervises repeated runtime-turns over the durable queue until idle, failure,
cancel, or max-turns. The remaining engine work is the persistent OpenSeek-style
service with long-running live steering/cancel UX, diff-aware review, and
broader model-backed coding eval cases.
It also owns runtime-neutral durable event helpers: safe session-id validation,
event record construction, JSONL rendering, JSONL parsing for events, command
queues, runtime command feeds, runtime dispatch receipts, and event
merge/dedupe. It now also owns the runtime-neutral JSONL/SSE stream contract:
meta/event/done records, 1-based event sequence wrapping, `since` cursor
semantics, stream mode, stream source, checkpoint cursor selection, checkpoint
records, and stream-state records. It also owns the runtime queue contract:
runtime protocol metadata, command decode reports, delivered/claimed/pending/
expired-lease classification, pending OpenSeek JSONL export, runtime replay
state, runtime claim state, claim/replay consumer contracts, replay
acknowledgement request expansion, replay/claim timestamp defaulting,
acknowledgement status/detail rules, claim request limits, runtime-claim
response shape, runtime dispatch-state response shape, command-queue response
shape, aggregate command-queue response assembly, runtime-replay
acknowledgement response shape, aggregate runtime-replay acknowledgement
response assembly, MoonClaw native command/runtime-loop/runtime-turn/stream/eval
endpoint shapes, native runtime-loop/turn request bodies, and dispatch-mode
classification, runtime command-feed response shape, aggregate runtime
command-feed response assembly, runtime event-sink response shape, runtime
event-sink response assembly, runtime event-ingest result response shape,
runtime execution-plan response shape, runtime-supervisor response shape, and
dispatch receipt record shape, dispatch receipt-list response normalization,
aggregate runtime-dispatch response shape,
aggregate runtime-claim response assembly, runtime response receipt
normalization, session snapshot and runtime-handoff receipt normalization, plus
serve-scheduler response shape. It
also owns OpenSeek-style
runtime event normalization, canonical MoonCode event shaping, event lane
validation, runtime event titles, tool lane classification, command preflight
rules, acceptance-gate projection, required action-gate metadata, patch-target
checks, `preflight.blocked` event shaping, and action-plan item/state
projection over command logs, runtime receipts, preflight events, and current
session summaries. It also owns session summary and eval-report projection:
event lane counts, review state, pending diff/tool approval counts, verified
test counts, MoonBook manifest counters, bridge readiness checks, and native
eval report status are now data-only `internal/mooncode` protocol objects. It
also owns the aggregate action-plan response surface and runtime-replay block
composition; Moondesk gathers durable logs and timestamps but no longer builds
that JSON contract locally. It
also owns change-set, patch-set, tool-approval, test-run, package-manifest,
package-index, and package-candidate projection: reviewable lane entries,
patch hunk grouping, approval/test row grouping, package status/index/
entry-point derivation, review-state derivation, and manifest status/count
fields are now host-neutral protocol objects. Patch review/execution state
matching is also a separate MoonCode slice from patch-set manifest assembly, so
file-level and hunk-level gates share one target-matching contract. Aggregate
package-candidate projection is likewise separate from per-command package
manifest construction and package-index construction, so MoonWiki can persist
MoonBook artifacts while MoonCode owns the API/UI readiness summary. Review receipt manifests/events,
manifest events, package manifest/index events, and runtime-handoff manifest
events are also now MoonCode protocol records; Moondesk supplies stable ids and
handles filesystem persistence. MoonWiki computes book-local paths and writes
review receipts, but the `mooncode-review-receipt` JSON contract and owner split
are constructed by MoonCode. The artifact path contract for
`wiki/reviews/mooncode/<session-id>/...` and
`portable/app-tool/mooncode/<session-id>/...` is also now in
`internal/mooncode`, including safe session/command id normalization. Package
source-inventory record shapes, source-promotion status records, and the
`portable/app-tool/mooncode/<session-id>/sources/<command-id>/...` promoted
source path convention are also MoonCode-owned; MoonWiki resolves workspace
paths and writes files but no longer constructs those JSON contracts locally.
Durable session snapshot
projection and runtime-handoff projection are also data-only
`internal/mooncode` protocol objects, including the runtime-consumer
status/action block, runtime event-ingest contract, and current-handoff
freshness checks. The command policy for which actions write MoonBook review
receipts is also protocol-owned, so MoonWiki no longer carries that decision
table in its host/session file. Command packet
construction, initial typed session record construction, command
action/context/message defaults, command event shaping, command-event
session append/update, transcript-message event shaping, OpenSeek serve-wire
wrapping, native MoonCode command bodies, execution plans, result contracts,
compact execution summaries, runtime dispatch status/detail classification,
native runtime dispatch result status/detail/mode projection, runtime-dispatch
receipt body construction, response-normalized dispatch receipt projection, and
native eval-report projection cleanup are also data-only `internal/mooncode`
protocol behavior now. Tool-authorization
contract rendering and
preview/allowed/requires-approval/blocked decision projection are also
extracted into `internal/mooncode`; Moondesk only supplies fallback ids and
timestamps, persists review artifacts, and serves the HTTP handshake. The
static capability, runtime-contract, eval-harness, and native-eval report
schemas are also `internal/mooncode` APIs now. Moondesk decorates them with
live daemon/endpoint status for `/api/mooncode/capabilities`, while
`/api/mooncode/eval-harness` is a direct projection of the extractable
MoonCode protocol contract. The
filesystem-backed
sidecar store, checkpoint file paths/writes, dispatch/claim/replay receipt
appends, request query parsing, bounded live-tail polling, host fallback
ids/timestamps, stable id generation, log reads, source inventory reads,
native/daemon readiness probes, action-plan manifest persistence, and tool-authorization HTTP
handshakes still live in `internal/moonwiki`; legacy MoonClaw transcript,
runtime status/progress, and tool call/result lane `desc.msg` shaping now live in
`internal/mooncode`, including assistant deltas, request-completed message
content, diff/test/artifact path extraction, and command extraction. Future
session storage, eval, and packaging contracts should move through
`internal/mooncode` before being split into a standalone `mooncode` component.
The `.moontown/mooncode-sessions/<session-id>/` sidecar layout is now also
part of `internal/mooncode`: event logs, command logs, runtime-command logs,
runtime-dispatch logs, session snapshots, and stream-checkpoint relative paths
are protocol-owned. Moondesk joins those relative paths to the selected
workspace root and remains responsible for the actual filesystem IO.
The stream route now prefers MoonClaw's native MoonCode stream
when `/v1/mooncode/capabilities` responds,
proxying `/v1/mooncode/sessions/<id>/stream`; otherwise it emits JSONL or SSE
append-log incremental records over the current event projection plus
`.moontown/mooncode-sessions/<session-id>/events.jsonl` and labels that replay
with `stream_source: "moondesk-append-log-projection"`.
The host-side stream HTTP handlers, bounded live-tail fallback, checkpoint
projection, native stream proxy path, and stream-specific tests now live in
`internal/moonwiki/mooncode_streams.mbt` instead of the monolithic MoonCode
session file. This keeps Moondesk-owned IO/proxy behavior separate from the
pure stream protocol in `internal/mooncode`, making the future `mooncode`
extraction boundary easier to audit.
The host-side runtime/command protocol adapter is now similarly split into
`internal/moonwiki/mooncode_runtime_protocol.mbt`: command packet construction,
preflight event shaping, replay/claim/lifecycle projections, runtime
supervisor packets, runtime event ingest normalization, and Moondesk stable-id
wrappers live outside the session router while delegating pure rules to
`internal/mooncode`.
MoonBook artifact write orchestration is also split into
`internal/moonwiki/mooncode_artifact_writes.mbt`: review receipt creation,
change/patch/tool/test/action-plan/runtime-evidence manifest writes, and
session updates now sit outside the HTTP session router while the durable
artifact shapes still come from `internal/mooncode` and the files remain
MoonBook-owned. The command route
records every normalized `command_packet` into an ordered
`.moontown/mooncode-sessions/<session-id>/commands.jsonl` queue and records
the engine-facing command adapter to
`.moontown/mooncode-sessions/<session-id>/runtime-commands.jsonl`. Packets carry
action, dispatch, approval, ids, target path, expected lanes, tool hints, output
contract, and ownership boundary. `GET /api/mooncode/sessions/<id>/commands`
exposes the UI/operator audit queue; `GET
/api/mooncode/sessions/<id>/runtime-commands` exposes the execution feed. Each
runtime feed row includes an OpenSeek-compatible serve command (`prompt`,
`steer`, or `cancel`) plus the full native MoonCode command body, so MoonClaw or
a future standalone `mooncode` runtime can consume ordered command intent
separately from rendered events. The native command body includes
`execution_plan`, `tool_contract`, and `result_contract` objects so actions such
as `run_tests`, `run_eval`, `package`, `commit`, patch review, accept, and reject expose
their tool sequence, approval policy, expected events, required outputs, event
sink, eval-report sink, ordered execution checklist, and replay acknowledgement
sink without forcing MoonClaw to parse prompt prose.
Runtime commands also persist a compact `execution_summary`, and the runtime
feed returns an `execution_summaries` projection so Moondesk can render the
planned tools, evidence requirements, executable checklist, and replay/event
sinks in Runtime Feed, Dispatch Receipts, and Runtime Claims without coupling
the UI to the full native body.
The runtime feed, runtime execution plan, and saved runtime handoff now also
include a `runtime_turn_packet`: a self-contained MoonClaw/standalone-MoonCode
turn handoff that combines replay/claim state, the serve-scheduler decision,
OpenSeek wire command, native MoonCode body, required proof events, endpoint
map, and claim/ack/failure templates. This moves the execution boundary closer
to OpenSeek serve mode while keeping Moondesk as recorder and renderer, not the
tool executor.
Moondesk also now exposes
`GET /api/mooncode/sessions/<id>/runtime-supervisor`, and embeds the same
`runtime_supervisor` launch packet into execution-plan responses, runtime-feed
responses, and saved runtime handoff manifests. The packet gives MoonClaw or a
future standalone `mooncode` runtime a single declarative launch view: current
status, bridge/native mode, workspace root, MoonClaw root, claim/ack/event
endpoints, launch-blocked reason, launch request, and ordered supervisor loop.
`POST /api/mooncode/sessions/<id>/runtime-supervisor` is now the operator launch
action for that boundary: Moondesk asks MoonClaw to run a bounded native
runtime-loop, falls back to a single native runtime-turn when needed, ingests
returned MoonCode events, refreshes review/test/package/evidence manifests, and
saves the enriched session. The MoonCode workspace exposes this as `Run Native
Loop`; Moondesk still does not execute tools directly. Native runtime-loop and
runtime-turn responses now also ingest MoonClaw `package_events`, so package
build/verification proof appears in the MoonCode artifact/package panels as
soon as the bounded native run returns. Runtime-loop responses are also recorded
as durable `runtime_loop` events, so no-work idle loops, failures,
cancellations, and max-turn stops show up in the transcript/runtime panels
instead of only as an HTTP response. Native response event extraction now lives
in `internal/mooncode`, including top-level events, execution events, package
events, turn receipts, nested turns, and loop-status projection, keeping those
rules extractable from the Moondesk host. Native response session append now
lives there as well: the pure MoonCode helper folds returned runtime events
into `mooncode_command_events` with durable id dedupe while Moondesk only
supplies the local fallback id/timestamp and saves the enriched session.
The launch packet now embeds a `mooncode-runtime-supervisor-readiness` report
that checks the command id, scheduler permission, claim/ack/event/session
endpoints, claim/ack request templates, and required supervisor loop steps. The
MoonCode UI renders missing launch requirements directly in the Runtime
Supervisor panel.
After live dispatch attempts, Moondesk records
`runtime-dispatches.jsonl` receipts that prove native dispatch, legacy bridge
dispatch, failure, or pending state; `GET
/api/mooncode/sessions/<id>/runtime-dispatch` exposes that audit state without
causing duplicate execution. `GET
/api/mooncode/sessions/<id>/runtime-replay` now exposes the native-consumer
view: decode reports, delivered/skipped command ids, pending command items,
first pending index, and `pending_openseek_jsonl` for an OpenSeek-style
single-consumer serve loop. `GET
/api/mooncode/sessions/<id>/serve-jsonl` also exposes that pending feed directly
as `application/x-ndjson` so MoonClaw or a standalone `mooncode` process can
pipe Moondesk session intent into an OpenSeek-compatible serve loop without
parsing the whole Moondesk replay projection; `?scope=all` exports every valid
wire command in append order for bootstrap/debug replay. `GET
/api/mooncode/sessions/<id>/serve-scheduler` now exposes the OpenSeek-style
ordered serve-loop projection from `commands.jsonl` plus runtime lifecycle
state: one active turn, pending turn ids, per-command effects such as
`start-turn`, `queue-turn`, `deliver-steer`, `queue-steer`, `cancel-active`,
`withdraw-pending`, and idle dropped controls. This projection lives in
`internal/mooncode`, so MoonClaw or a standalone `mooncode` runtime can enforce
prompt/steer/cancel ordering without depending on Moondesk UI state.
Command-scoped runtime lifecycle event counting now lives in a focused
MoonCode implementation file, separate from queue lifecycle assembly, so
MoonClaw and future standalone `mooncode` consumers can reuse the same
command-id/action matching contract.
`GET
/api/mooncode/sessions/<id>/runtime-claim` now exposes claimable, claimed,
delivered, failed, and invalid commands for the UI and runtime consumers. `POST
/api/mooncode/sessions/<id>/runtime-claim` lets MoonClaw or standalone
`mooncode` claim pending valid commands in runtime-log order, recording
`runtime-claimed` receipts before execution so multiple consumers do not race
the same prompt/steer/cancel packet. Runtime consumers can pass `now` on the
claim-state query or claim POST to evaluate `lease_expires_at`
deterministically; expired claims and failed dispatches are projected as
claimable retry work, active earlier claims and invalid earlier commands block
later non-delivered rows as `blocked-by-prior-command`, and expired-claim
recovery receipts preserve the previous claim id and expiry. `POST
/api/mooncode/sessions/<id>/runtime-replay` lets MoonClaw or standalone
`mooncode` acknowledge consumed commands with `runtime-acknowledged` or
`runtime-completed` receipts, append those receipts to
`runtime-dispatches.jsonl`, preserve prior claim/consumer context plus
`ack_order_status` and `order_blocker` audit fields, and optionally include
OpenSeek/MoonCode events that Moondesk normalizes into `events.jsonl`. The feed response now includes
decode reports and the reusable runtime protocol contract, and Moondesk can
normalize OpenSeek-style JSONL runtime events directly into MoonCode lanes. The MoonCode
runtime-event ingest path now also accepts current MoonClaw task event JSON
from `/v1/task/<id>/events`: `AssistantMessageDelta`, `AssistantMessage`,
`PreToolCall`, `PostToolCall`, `Cancelled`, and `Failed` under `desc.msg` are
bridged into MoonCode transcript/tool/test/review/runtime lanes. The adapter
maps MoonClaw tools such as `execute_command`, `read_file`, `write_to_file`,
`replace_in_file`, `patch_edit`, and `apply_patch` onto the MoonCode tool
vocabulary and is advertised from `/api/mooncode/capabilities` as a
compatibility bridge. Native MoonClaw MoonCode endpoint builders and query
encoding are now a separate MoonCode slice from the adapter contract, runtime
request, event mapping, tool mapping, and readiness projection. MoonClaw now
implements native `/v1/mooncode/*` slices
for capabilities, command ingestion, cold sidecar list/show, runtime claim,
runtime dispatch, runtime event ingest, native tool execution, package-result
acknowledgement, session stream, eval-report projection, and the first
book-local `runtime-turn` path. That turn path claims the next durable command,
executes explicit `runtime_tool_calls` or deterministic built-in fallbacks such
as `run_tests -> moon_check + finish`, appends runtime/tool events, and closes
the command with `runtime-completed` or `runtime-failed`. Native `run_tests`
now emits command-scoped `test_result` proof from MoonClaw `moon_check`
evidence, and Moondesk accepts both `exit_code` and native `exit_status` when
normalizing that proof. Native command
ingestion still supports the compatibility path that binds the Moondesk
MoonCode session to the MoonClaw task for the selected book root and forwards
accepted commands into MoonClaw's existing task/agent runtime.
The live engine status now includes adapter readiness as `native-ready`,
`compatibility-bridge`, or `missing-runtime`, so the UI can distinguish current
MoonClaw task-event compatibility from a real MoonClaw-owned MoonCode runtime.
The MoonCode
center pane now renders the UI queue as a Command Queue panel with latest
command packets, prompt/steer/cancel/review counts, and quick target-aware
test/package controls. Pending steer acknowledgement counts are now projected
by `internal/mooncode` from `command.steer` events minus
`steer_applied`/`steer_dropped` runtime events, so Moondesk and future
standalone `mooncode` read the same steering state. It also renders a Dispatch Receipts panel from
`GET /api/mooncode/sessions/<id>/runtime-dispatch`, including receipt counts,
pending command ids, native-vs-bridge status, latest receipt details, and
runtime-replay acknowledgement audit fields (`ack_order_status`,
previous claim/consumer context, and `order_blocker`) so daemon delivery and
consumer acknowledgement safety can be audited inside the coding workspace.
The session snapshot and runtime handoff now persist normalized dispatch
receipts, not raw legacy rows, so old `runtime-dispatches.jsonl` entries gain
stable native/legacy endpoint, owner, runtime-command, status, and timestamp
fields before a MoonClaw supervisor consumes `session.json` or
`wiki/reviews/mooncode/<session-id>/runtime-handoff.json`. The handoff also
includes a `runtime_consumer` block with queue status (`claim-ready`,
`lease-held`, `delivered`, `blocked-invalid-command`, or idle), `ready_to_claim`
/ `ready_to_replay` flags, endpoints, and the required external runtime loop:
claim, execute with MoonClaw/MoonCode tools, append streamed events, acknowledge
through runtime replay, and publish native eval evidence when available.
The runtime feed now also exposes a shared `command_lifecycle` projection from
the pure MoonCode package. It classifies each command as pending, running,
dispatched, completed, failed, blocked-invalid, or blocked-tool-authorization
using command logs, dispatch receipts, command-scoped runtime events, decode
validity, authorization snapshots, and lease expiry; the MoonCode Runtime Feed
renders this as a Lifecycle block with the next command, blocking reason, and
next step.
`GET/POST /api/mooncode/sessions/<id>/stream-state` now exposes and persists
named consumer checkpoints under
`.moontown/mooncode-sessions/<session-id>/stream-checkpoints/`, so the UI,
MoonClaw, or standalone `mooncode` can resume from a known append-log cursor
without replaying the entire session. This is the durable cursor boundary for
the future blocking live tail; Moondesk still does not own the long-running
agent event producer.
Moondesk also writes and exposes a compact MoonBook-owned action plan at
`wiki/reviews/mooncode/<session-id>/action-plan.json` and
`GET /api/mooncode/sessions/<id>/action-plan`. The plan merges command packets,
runtime dispatch receipts, MoonCode lanes, tests, packages, tool approvals, and
review state into command-level action items with states such as
`queued-for-runtime`, `awaiting-proof`, `blocked`, `ready-for-review`,
`runtime-retry`, and `completed`. The MoonCode center renders this as an Action
Plan panel with acceptance gates and `next_required_action`; a delivered
`run_tests` command remains `awaiting-proof` until MoonClaw's native
`test_result` evidence arrives, and accept/package actions are blocked while
required gates are missing. Action rows now also include command-scoped runtime evidence:
`runtime_evidence_status`, required/proven event counts, and exact
missing/failed required event names derived from the native result contract.
Runtime command lookup and lease/receipt state classification are now a
separate MoonCode action-plan slice from per-action gate decisions, keeping
queue-state evidence distinct from acceptance policy.
Only matching `command_packet.command_id` events satisfy this proof, so
concurrent test/package/commit commands cannot complete each other by accident.
The same evidence is now available through
`GET /api/mooncode/sessions/<id>/runtime-evidence` as a session-level
`mooncode-session-runtime-evidence` projection, giving MoonClaw and future
standalone `mooncode` consumers a UI-independent proof contract.
Command-level proof construction and session-level evidence aggregation are now
separate MoonCode implementation files, keeping per-command event matching
extractable while leaving session rollups as a distinct consumer-facing
projection.
Runtime feed response projection is also separated from endpoint-specific
response assembly, so shared dispatch, replay, claim, lifecycle, scheduler,
turn-packet, and supervisor rollups stay reusable across feed, plan, and
supervisor views.
Runtime proof events now normalize `command_id`/`command_packet` into
a `mooncode.v1` command reference. When scoped proofs exist for an action, the
plan only completes the matching command id; unscoped proof events remain a
legacy fallback for older sessions.
Moondesk now also exposes `GET/POST
/api/mooncode/sessions/<id>/runtime-events` as the runtime event sink. MoonClaw
or an extractable `mooncode` engine can POST OpenSeek-style JSONL events,
legacy MoonClaw events, canonical MoonCode events, or event batches. Moondesk
normalizes those into durable MoonCode lanes, appends `events.jsonl`, and
refreshes change-set, patch-set, tool-approval, test-run, action-plan,
eval-report, session-snapshot, and runtime-handoff artifacts. Native
`tool_call`/`tool_started` events preserve tool call ids, arguments, commands,
paths, and command references when `command_id` is supplied, so the review UI
can show pending shell/file-write approval state before the tool result
arrives. Native `tool_result` events preserve the same identity fields when
present and parse nested OpenSeek tool-call arguments, so approval rows, result
rows, and command proof can stay correlated.
Runtime-event sink and ingest result response builders are now a separate
MoonCode file from normalization and ingest-report construction, keeping the
engine-facing event parser independent from Moondesk endpoint payload shape.
This closes the first engine-to-desktop half of the runtime boundary while
leaving actual execution with MoonClaw.
The capability and runtime-handoff payloads now also carry a machine-readable
`mooncode-tool-contract` for `read`, `edit`, `write`, `shell`, `moon_check`,
and `finish`. Each entry defines the execution owner, lane, approval policy,
input schema, required output events, file-mutation/review flags, and safety
policy. The MoonCode inspector renders this contract separately from the older
display-oriented tool specs, giving MoonClaw or a future standalone `mooncode`
runtime a concrete schema to enforce.
Moondesk also writes a typed durable session snapshot to
`.moontown/mooncode-sessions/<session-id>/session.json` and exposes it through
`GET /api/mooncode/sessions/<id>/session-store`. That snapshot captures the
MoonCode protocol, selected book/workspace identity, MoonClaw task id, command
packets, runtime feed rows, event projection, summary, and resume endpoints so
MoonClaw or a future standalone `mooncode` runtime can resume without depending
on generic Moondesk agent-session storage. The same packet is embedded in delegated MoonClaw
prompts until the standalone MoonCode runtime
takes over; cancel commands still go to the attached daemon task.
The dispatch path now prefers a MoonClaw-owned native MoonCode runtime when
`/v1/mooncode/capabilities` is available, posting typed packets to
`/v1/mooncode/sessions/<id>/commands`; otherwise it falls back to the legacy
`/v1/task` prompt/message/cancel bridge and exposes `dispatch_mode` in the
session summary.
MoonCode mode now starts sessions through `POST /api/mooncode/sessions` instead
of the generic agent endpoint. Creation still binds the selected MoonBook to a
MoonClaw daemon task, but the saved session is tagged as `component=mooncode`,
`protocol=mooncode.v1`, and `mooncode_session_kind=coding`, and the first prompt
is appended to `commands.jsonl` as an ordered MoonCode command packet before
dispatch. That makes the first turn resumable/auditable in the same protocol as
later prompt, steer, cancel, test, review, package, and commit commands.
Accept, reject, package, and commit commands now also write MoonBook-owned
`mooncode-review-receipt` files under
`wiki/reviews/mooncode/<session-id>/<action>-<command-id>.json`, with matching
`receipt.<action>` stream events, so accepted coding outputs have durable book
review state instead of only Moondesk session state. Moondesk writes these
receipts for desktop-side review commands, and MoonClaw's native runtime-turn
now writes compatible accept/reject receipts when it consumes review commands
directly. Every command now also refreshes a MoonBook-owned
`mooncode-change-set` manifest under
`wiki/reviews/mooncode/<session-id>/change-set.json`, grouping current diff,
test, artifact, and review evidence into a durable Bookkeeper review object.
Moondesk exposes it through `GET /api/mooncode/sessions/<id>/change-set` and
renders it as a Change Set panel in the MoonCode center pane so the durable
review object is visible without opening JSON manually.
Every command also refreshes a file-focused MoonBook-owned
`mooncode-patch-set` manifest under
`wiki/reviews/mooncode/<session-id>/patch-set.json`, grouping diff candidates by
path, parsed hunks, stable hunk targets, and
pending/accepted/rejected/applied/reverted review state. Patch file and hunk
rows now also project `gate_status`, `next_action`, and `blocked_reason` so the
operator surface and future `mooncode` runtime share the same review/apply/test
handoff semantics. It also separates operator review state from runtime
execution state: MoonClaw or standalone `mooncode` must emit `patch_applied` or
`patch_reverted` runtime events after actual file mutation, and Moondesk normalizes those into
`runtime.patch_applied` / `runtime.patch_reverted` proof counts on the patch
set and session summary. MoonClaw now provides native bounded
`apply_patch`/`revert_patch` tool execution for reviewed text replacements plus
single-file or multi-file unified-diff patchsets inside the selected MoonBook
root, inferring target paths from diff headers when needed and emitting those
proof events directly. Patch tool packets can also request post-change
verification through `verification_command`, `test_command`, `verify_after`, or
`moon_check_target`; MoonClaw stores the verification command, status, capped
output, and pass/fail result under the patch proof metadata. MoonClaw also
supports selected-hunk dispatch through `hunk_index`/`hunk_id` or
`path#hunk-N` targets, emitting `hunk_dispatch_scope`, `selected_hunk_index`,
`available_hunk_count`, and `file_path` metadata on the patch proof event.
Moondesk exposes it
through `GET /api/mooncode/sessions/<id>/patch-set` and renders it as a Patch
Set panel with per-file Open, Accept, Reject, Apply, Revert, and Package
controls plus hunk-level Accept, Reject, Apply, and Revert controls, including
visible gate and next-action chips for each target. Moondesk
still does not edit files directly; the remaining MoonClaw work is richer
diff-review polish and broader model-backed coding eval coverage.
The pure MoonCode package now keeps patch review/execution state projection in a
focused slice shared by patch sets, parsed hunks, and preflight gates. Patch-set
manifest assembly can change independently from target matching, runtime proof
counting, and accepted/applied/reverted state derivation.
Moondesk also writes a MoonBook-owned `mooncode-tool-approvals` manifest under
`wiki/reviews/mooncode/<session-id>/tool-approvals.json`, exposes it through
`GET /api/mooncode/sessions/<id>/tool-approvals`, and renders it as a Tool
Approvals panel with per-tool Open, Approve, and Reject controls. It also
exposes `GET/POST /api/mooncode/sessions/<id>/tool-authorization` as the
MoonClaw-facing authorization handshake. MoonClaw can POST a tool-call preview;
Moondesk records missing gated previews, refreshes the review artifacts, and
returns `allowed`, `requires_approval`, or `blocked` for MoonClaw to enforce.
This captures policy/review-gated shell, write/edit, diff, and artifact work as
durable operator intent while keeping execution in MoonClaw or standalone
`mooncode`.
The pure MoonCode package now separates approval queue projection from the live
authorization decision contract, keeping MoonBook review rows reusable while
MoonClaw-facing allow/block decisions stay in the authorization slice.
The MoonWiki adapter also keeps the tool-approval and tool-authorization HTTP
handlers outside the generic MoonCode session router, so the desktop bridge can
change approval persistence without coupling that work to session creation or
list/event projection.
The test-run manifest projection is also split into a focused MoonCode slice,
separate from change-set, patch-set, and tool-approval artifacts. That keeps
MoonBook-owned test/build evidence reusable by action-plan gates, eval-readiness
checks, and a future standalone `mooncode` runtime without making the review
artifact file the owner of every operator panel.
The command endpoint now also performs server-side preflight before appending
or dispatching review/package/commit/apply commands. `accept`, `package`, and `commit` return
`409 Conflict` while projected events show failing tests, pending tool
approvals, or untested pending diffs; `commit` also requires accepted reviewed
file changes before it enters the runtime queue. `apply_patch` and
`revert_patch` require a selected path that matches a known patch candidate,
plus an accepted target before `apply_patch` and an applied target before
`revert_patch`. Package and commit preflight now also project a stable
`selected_patch` object and block selected file/hunk targets until their
review state and MoonClaw runtime proof are sufficient. This moves the MoonCode
UI buttons from advisory controls toward enforceable review gates.
Commit remains runtime-owned: Moondesk records operator intent and review
receipts, while MoonClaw native runtime-turn now handles `commit` by running
git inside the selected MoonBook, excluding MoonClaw/Moontown sidecars from
staging, and emitting `runtime.commit_created` proof with the commit SHA after
`git commit` and `rev-parse HEAD` succeed. A future standalone `mooncode`
runtime should preserve the same proof contract.
Blocked attempts stay out of `commands.jsonl`, but Moondesk records them as
`preflight.blocked` events in `events.jsonl`, returns the preflight object in
the 409 response, refreshes the UI panels after failures, and projects the
attempt into the Action Plan as a blocked item.
`GET /api/mooncode/sessions/<id>/preflight?action=<action>&context_path=<path>`
now exposes the same gate projection without mutating command logs. The
MoonCode center renders a Preflight Gates panel for `package`, `commit`,
`accept`, and selected-path or selected-hunk `apply_patch`/`revert_patch`,
making test/build, diff, patch-state, runtime-proof, package, and tool approval
blockers visible before the operator dispatches a command.
Selected file and hunk patch target resolution now lives in a focused
MoonCode implementation file, keeping the command preflight entrypoint separate
from the reusable patch-review target contract consumed by MoonWiki routes,
tests, and future standalone `mooncode` runtimes.
Moondesk also writes a MoonBook-owned `mooncode-test-runs` manifest under
`wiki/reviews/mooncode/<session-id>/test-runs.json`, exposes it through
`GET /api/mooncode/sessions/<id>/test-runs`, and renders it as a Test Runs
panel with passed/failed/running/queued counts plus Open, Rerun, and Package
controls. This turns test/build events into durable book review evidence while
MoonClaw or standalone `mooncode` still needs to own real execution and
stdout/stderr logs.
Package commands also
write MoonBook-owned `mooncode-package-manifest` candidate JSON under
`portable/app-tool/mooncode/<session-id>/package-<command-id>.json`, with a
matching `package.manifest` artifact event, source inventory for candidate
paths, file `size_bytes`/`sha256` evidence when source is present, promoted
source copies under
`portable/app-tool/mooncode/<session-id>/sources/<command-id>/...`, promotion
status/count metadata, and a summary/readiness gate for package manifest
evidence. Package commands also
refresh a MoonBook-owned session package registry at
`portable/app-tool/mooncode/<session-id>/index.json`, emit a `package.index`
artifact event, and expose executable-ready entry points for the future
MoonClaw/standalone-MoonCode bundler. MoonClaw native runtime-turn now emits the
first deterministic `package_built`/`package_verified` proof for generated
tools and miniapps after book-local write/shell verification, while standalone
`mooncode` still needs the same contract for model-backed bundle
assembly/checking. Moondesk ingests those proof events from native runtime-turn
and runtime-loop responses, normalizes them into package proof counts and
per-candidate execution state, and persists them with the rest of the MoonCode
event log. Moondesk now exposes saved package
manifests and the package index through
`GET /api/mooncode/sessions/<id>/package-candidates` and renders a Package
Candidates panel with source-bound/missing-source counts, executable-ready
count, runtime built/verified proof counts, manifest/receipt paths, source
inventory, promoted-source paths, index status/path, ready entry points, and Open/Test/Accept/Package
controls.
The pure MoonCode package now keeps per-command package-manifest construction,
aggregate package-candidate response projection, package-index construction,
and per-candidate runtime proof matching in separate implementation files,
leaving MoonWiki to resolve file paths and persist the MoonBook-owned
artifacts.
Moondesk also exposes
`GET /api/mooncode/sessions/<id>/eval-report` plus
`POST /api/mooncode/sessions/<id>/eval-report` for MoonClaw-owned native eval
proof ingestion, and renders an Eval Report panel with bridge score, bridge
level, passed/missing readiness checks, required native harnesses, native source
endpoint, native ingest endpoint, the current MoonClaw eval-proof gap, and the
persisted MoonBook artifact path
`wiki/reviews/mooncode/<session-id>/eval-report.json`. Native eval ingestion
also refreshes the extractable session snapshot at
`.moontown/mooncode-sessions/<session-id>/session.json` and the runtime handoff
manifest before writing the eval report, then appends the generated eval-report
manifest event to `.moontown/mooncode-sessions/<session-id>/events.jsonl`, so
Bookkeeper and a future standalone `mooncode` runtime can resume from the same
proof boundary. When a native
MoonClaw MoonCode runtime is present, the same endpoint probes
`/v1/mooncode/sessions/<id>/eval-report?book_root=<path>`, delegates native report
normalization to `internal/mooncode`, and persists the MoonClaw-owned report as
`native_eval_report`. Moondesk also refreshes a MoonBook-owned runtime handoff at
`wiki/reviews/mooncode/<session-id>/runtime-handoff.json`, exposes it through
`GET /api/mooncode/sessions/<id>/runtime-handoff`, and renders a Runtime
Handoff panel with the ordered command log, event log, stream/command
endpoints, native MoonClaw endpoints, output roots, dispatch mode, and next
runtime step for MoonClaw or a future standalone `mooncode` runtime. The
MoonWiki eval-report GET/POST handlers and native proof persistence now live
outside the generic MoonCode session router, keeping session lookup/projection
separate from eval evidence ingestion. The
capability route now carries
typed `command_specs`, display `tool_specs`, and the executable
`mooncode-tool-contract`, and the MoonCode inspector renders those tool owners,
lanes, approval policies, input fields, mutation/review flags, purposes,
outputs, and safety policies. The capability route also carries an OpenSeek-shaped
`runtime_contract` for `agent_runtime`, `agent_session`, `agent_tool`,
`agent_loop`, the prompt/steer/cancel JSONL wire, append-only session store, and
tool/file-edit eval harnesses plus a native eval-report schema for
`/v1/mooncode/sessions/<id>/eval-report?book_root=<path>` and a concrete
`/api/mooncode/eval-harness` contract endpoint. The inspector renders that
contract as the MoonClaw/MoonCode extraction boundary. Runtime-contract
construction is now separated from top-level capability response assembly, so
the OpenSeek/MoonClaw engine contract can move with a future standalone
`mooncode` package without dragging the whole Moondesk capability payload. The
same capability response now carries
a live `engine_status` compatibility block that checks the configured MoonClaw
checkout, daemon, `/v1/models`, `/v1/tasks`, prompt/message/cancel bridge,
append-only command queue, append-only session log, MoonClaw adapter readiness,
native runtime-turn availability, native runtime-loop queue supervision,
optional bounded model/tool feedback planning, and the remaining autonomous
MoonClaw-owned long-running steering UX, diff-review, and model-backed eval
proof. The
live probes still happen in `internal/moonwiki`, but the readiness projection
itself now lives in `internal/mooncode`: endpoint rows, bridge-vs-production
status, and check metadata are extractable protocol data rather than
desktop-only logic. It also
exports `adapter_status`, `native_runtime_ready`, and
`legacy_task_bridge_ready` fields for the native UI. The
inspector renders that before the static contract so operators can distinguish
daemon-bridge readiness from true production readiness. The session summary now
also carries a readiness/eval
checklist and score, including append-log, ordered-command-queue,
typed-command-packet, review-state, pending-diff, MoonBook review-receipt,
MoonBook package-manifest, verified test-result, source-bound-package, and
live-append-stream gates while Moondesk serves incremental JSONL/SSE with
stable `since` sequence cursors plus bounded `?live=true` tailing. Queued
test/package commands are separated from completed MoonClaw
test/build results and source-inventoried package manifests. The MoonCode
center pane now renders a session header before the transcript with selected
book/session identity, next required action, stream source, dispatch state,
event/diff/test/tool/package counts, eval score, and durable resume/log paths.
It also consumes the bounded `?live=true` JSONL stream for the selected
session, shows the latest batch as a Live Tail, and renders a Code Review queue
from diff-lane events, with file-open and file-targeted accept/reject/package
controls that preserve the selected diff path in the command event. Per-hunk
staging and selected-hunk patch dispatch are present. Native loop status now
lands as a runtime event, improving idle/failure/cancel visibility; richer patch
promotion, signed bundle assembly, persistent long-running steering, and broader
model-backed eval evidence are still future runtime work.

### Output Library

Convenient access to generated outputs:

- final reports
- generated marketing sites
- course pages
- journal timelines
- approved wiki pages
- exported bundles

## Data Contracts

### DeskWorkspace

```text
id
name
root_path
kind: moonbook | loose-folder | town-root
status
last_seen_at
```

### DeskFileEntry

```text
id
workspace_id
path
display_name
kind: markdown | html | json | image | directory | artifact | unknown
source_layer: wiki | raw | generated-site | run-artifact | inbox | config
readable
writable
size_bytes
modified_at
```

### DeskPreview

```text
entry_id
renderer: markdown | html | json | image | text | artifact-summary
title
body
metadata
warnings
```

### DeskTaskSubmission

```text
id
target_book_id
title
prompt
context_entries
cadence
quality_threshold
source_policy
created_at
```

### DeskRunProjection

```text
run_id
book_id
goal_id
status
phase
summary
artifacts
started_at
updated_at
```

## Permission Model

Moondesk should treat local files as user-owned and agent execution as
permissioned.

- Read operations are allowed only under configured roots.
- Writes go to a book-local inbox/staging area first.
- Durable wiki promotion belongs to MoonBook.
- Execution belongs to Moontown/MoonClaw.
- Filesystem operations go through explicit MoonBit host APIs with scoped roots.
- Destructive operations require explicit confirmation.

## Visual Direction

Match Codex's outlook more than a game UI:

- left activity rail
- left explorer tree
- tabbed central workspace
- right agent/context inspector
- bottom logs/artifacts drawer
- command palette
- calm dark/light neutral palette
- dense but readable typography
- strong keyboard navigation

Moondesk can link out to the Wenyu Valley town viewport, but it should not embed
the game map as the main desktop surface.
