# MoonCode Workspace

MoonCode is the coding/chat half of Moondesk. It sits beside MoonWiki, not
inside it.

```text
Moondesk
  -> MoonWiki: book/wiki/knowledge workspace
  -> MoonCode: coding/chat workspace
```

MoonWiki remains the default workspace for reading, editing, previewing,
publishing, reviewing, and managing MoonBook knowledge. MoonCode is the
Codex/OpenSeek-like workspace for asking MoonClaw to create, modify, test, and
package executable code inside the selected MoonBook.

## Product Boundary

Moondesk owns the native desktop shell:

- MoonWiki/MoonCode switcher
- book and session selection
- chat transcript, diff, test, artifact, and review UI
- preview surfaces and approval controls
- packaging controls for generated tools, miniapps, generated sites, and
  app-tool books

MoonClaw owns the coding engine:

- typed agent loop
- model provider integration
- durable coding sessions
- JSONL/SSE event stream
- tool execution
- test/build execution
- result packaging

MoonBook owns durable outputs:

- generated source files
- `tools/`, `apps/`, `book/site/generated/`, and `portable/app-tool/`
- review notes and MoonCode review receipts
- accepted artifacts
- executable book structure

This keeps the implementation extractable. A future standalone `mooncode`
component should be able to take the coding runtime/protocol without taking the
MoonWiki UI or the rest of Moondesk.

The extraction boundary is now split into two MoonCode packages. The portable
kernel is `mooncode/core`; it owns `mooncode.v1`, the native capability surface,
and a machine-readable `mooncode-extraction-boundary` record that names the
core, Moondesk projection, MoonWiki host, and MoonClaw runtime responsibilities.
The larger Moondesk projection is `internal/mooncode`; it is intentionally
pure and UI-free. It currently owns the OpenSeek-compatible serve-wire helper
surface for `prompt`, `steer`, and `cancel`, plus native function tool-call
wire decoding for OpenSeek/DeepSeek shapes like
`{id,type,function:{name,arguments}}`, wrapped runtime events with
`tool_call`, and flattened `{tool_call_id,tool_name,arguments}` events. That
decoder validates the bounded registry and returns parsed argument objects for
MoonClaw while preserving the raw `function.arguments` string for audit. The
local wire atoms are centralized in `internal/mooncode/protocol.mbt`:
`mooncode.v1`, command/runtime-dispatch kinds, runtime-turn/tool-call contract
kinds, and canonical tool/test/package/control event names. MoonWiki route
code should consume those helpers instead of re-declaring protocol strings;
when `mooncode` becomes a standalone component, `mooncode/core` is the first
shared package to lift and `internal/mooncode` is the projection layer to split
next.
The
package also owns command/action metadata:
supported actions, dispatch policy, approval policy, tool hints, expected
lanes, command lane, and display title. It also owns the data-only tool
contract for `read`, `edit`, `write`, `shell`, `moon_ide`, `moon_cmd`,
`moon_check`, and `finish`, including input/output event schemas,
approval/review policy, ownership, and safety constraints. `moon_ide` is the
read-only semantic navigation tool for MoonBit packages; `moon_cmd` is the
structured check/test/build/run/info/fmt executor that keeps MoonBit validation
out of generic shell calls. MoonClaw now executes both tools natively inside
the selected MoonBook root and records `moon_ide.finished` /
`moon_cmd.finished` proof events with bounded output metadata. The same package now owns runtime-neutral durable event
helpers: session id validation, projected coding-session id construction,
MoonCode event record construction,
events/commands/runtime-commands/runtime-dispatches JSONL parsing, compact
session-list row projection, native/local session-list merge and dedupe, JSONL
rendering, event merge/dedupe, and the JSONL/SSE stream contract:
meta/event/done records, 1-based sequence wrapping, `since` semantics, stream
mode, stream source, bounded live-tail option defaults/clamping/attempt counts,
stream content type selection, Moondesk stream endpoint construction,
checkpoint cursor selection, checkpoint records, and stream-state records,
including the Moondesk checkpoint/state wrapper records that fill resumable
stream, live-tail, and runtime-event ingest endpoints. It also owns the runtime queue contract used by MoonClaw
or standalone `mooncode`: runtime protocol metadata, command decode reports,
pending/delivered/claimed/expired lease classification, pending OpenSeek JSONL
export, runtime replay state, runtime claim state, and claim/replay consumer
contracts, including replay acknowledgement request expansion, acknowledgement
status/detail rules, proof-aware completion gates, claim request limits, and
dispatch receipt record shape. It also owns the OpenSeek-style serve scheduler
projection: given `commands.jsonl` plus runtime lifecycle state, it computes the
single active turn, pending turn queue, steer delivery target, cancel target,
and idle deferred/dropped-control decisions without depending on Moondesk UI
state.
MoonClaw's native `runtime-turn` now consumes that same projection before
executing a claimed command, returns `serve_scheduler_state` and
`serve_scheduler_decision` in the native response, persists idle `steer`
controls as `steer_deferred` next-turn context, and closes idle `cancel`
controls with `cancel_dropped` evidence instead of planning fallback tool
calls. That keeps Moondesk as the renderer/recorder
while aligning native execution with OpenSeek's ordered prompt/steer/cancel
serve semantics.
It also owns OpenSeek-style runtime event normalization, canonical MoonCode
event shaping, deterministic sparse runtime-event fallback ids, created-at
defaulting, event lane validation, runtime event titles, and tool lane
classification, so MoonClaw or a standalone `mooncode` runtime can produce the
same transcript/tool/diff/test/artifact/review lanes without depending on
Moondesk server helpers. It also owns the MoonClaw compatibility adapter for
current `../moonclaw` task streams: `AssistantMessageDelta`,
`AssistantMessage`, `PreToolCall`, `PostToolCall`, `Cancelled`, and `Failed`
events under `desc.msg` are converted into MoonCode runtime events, and
MoonClaw tool names such as `execute_command`, `read_file`, `write_to_file`,
`replace_in_file`, `patch_edit`, and `apply_patch` are mapped onto the
MoonCode tool vocabulary. MoonClaw now implements the first native endpoint
slice: `/v1/mooncode/capabilities`,
`/v1/mooncode/sessions/<id>/commands`,
`/v1/mooncode/sessions/<id>/stream`, and
`/v1/mooncode/sessions/<id>/eval-report?book_root=<path>`, and
`/v1/mooncode/sessions/<id>/package-result?book_root=<path>`. The native
command endpoint binds a Moondesk MoonCode session to the MoonClaw task for the
target book root and forwards accepted commands into the existing MoonClaw
task/agent runtime.
Package acknowledgement is now explicit on both sides: MoonClaw records native
package proof in its book-local sidecar, while Moondesk exposes
`POST /api/mooncode/sessions/<id>/package-result` to ingest the same proof into
local runtime evidence and forward it to MoonClaw when the daemon is available.
The same package now exposes live adapter readiness
with `native-ready`, `compatibility-bridge`, and `missing-runtime` states, so
Moondesk can show whether current execution is using the legacy MoonClaw
task/event bridge or a native MoonCode runtime. Native readiness is not just a
successful daemon ping: `internal/mooncode` validates the
`/v1/mooncode/capabilities` component, protocol, required native endpoints, and
MoonClaw tool set, including `moon_ide` and `moon_cmd`, before MoonWiki can use
the runtime path. It also owns unavailable, incompatible, and ready readiness
payloads; MoonWiki only passes observed daemon errors or capability JSON into
the MoonCode projection. The required native endpoint and tool surfaces are
named helpers in `internal/mooncode`, so the compatibility check, tests, and
future shared `mooncode` package can consume the same list instead of copying
the capabilities payload by hand. It now owns command preflight rules, acceptance-gate
projection, required action-gate metadata, patch-target checks, and
`preflight.blocked` event shaping for `accept`, `package`, `commit`,
`apply_patch`, and `revert_patch`, so review gates are protocol behavior instead of desktop-only
logic. The action-plan item projection also lives there now: command runtime
state, item state, blocking reasons, next steps, state/command/review counts,
command-scoped runtime evidence, missing/failed required event lists, and
`next_required_action` are computed by `internal/mooncode` from command logs,
runtime receipt logs, preflight events, append-log proof events, and the
current summary. The saved action-plan manifest response wrapper also lives
there now: MoonCode stamps the durable `manifest_path` and
`absolute_manifest_path` fields while MoonWiki only chooses host paths and
writes the file. MoonCode also owns the generic manifest-event session patch:
append the already-shaped manifest event to `mooncode_command_events` and stamp
the corresponding `mooncode_last_*_manifest` field, while MoonWiki only writes
the artifact and supplies the event. Review receipt and package/index latest
fields use the same MoonCode-owned session patch boundary. Canonical event IDs for review manifests,
review receipts, package manifests/indexes, runtime-handoff manifests, and
tool-authorization preview events are MoonCode-owned too. Command preflight
blocked/override event IDs are also MoonCode-owned, so MoonWiki no longer
re-encodes those protocol identity rules with desktop stable-id helpers.
Runtime-dispatch receipt IDs are MoonCode-owned as well; MoonWiki supplies the
observed dispatch timestamp and persisted session state. Native runtime-loop
fallback event IDs are MoonCode-owned as well; MoonWiki supplies the observed
runtime timestamp and native response payload. The
session projection response wrapper lives there as well:
MoonWiki reads host logs and passes paths/counts, while MoonCode attaches
`mooncode_events` and the computed `mooncode_summary` without leaking those
host log fields into the outer session record. Runtime-evidence response
wrappers live there too: MoonWiki chooses manifest/log paths and writes files,
while MoonCode stamps `manifest_path`, `absolute_manifest_path`, and durable
log-path fields onto the session proof projection. Native runtime-events state
helpers also live there now: MoonCode owns unavailable-daemon/runtime,
fetch-failed, and available-payload shapes while MoonWiki only checks daemon
readiness and performs the GET. The
session readiness summary, eval-report projection, and saved eval-report
manifest session patch also live there now:
event lane counts, review state, pending diff/tool approval counts, verified
test counts, MoonBook manifest counters, bridge readiness checks, and native
eval report status are computed by `internal/mooncode` as data-only protocol
objects, and accepted native eval evidence is carried forward from saved
eval-report manifests without MoonWiki owning that session-state rule. Native
eval-report session patching is also MoonCode-owned now: MoonWiki decides when
to fetch or persist native proof, while MoonCode normalizes and stores
`mooncode_native_eval_report`.
Change-set, patch-set, tool-approval, test-run, and package
manifest/index/candidate projection also moved into the pure package:
diff/test/artifact/review entry normalization, patch hunk grouping,
approval/test row grouping, package status/index/entry-point derivation,
review-state derivation, and manifest status/count fields are produced without
HTTP, filesystem, or desktop dependencies. The corresponding append-log event
records for review receipts, review manifests, package manifests/indexes,
runtime-evidence manifests, and runtime-handoff manifests are also shaped by
`internal/mooncode`, including their projected event ids; Moondesk only
persists the records and writes host-selected files. The artifact path contract
for `wiki/reviews/mooncode/<session-id>/...` and
`portable/app-tool/mooncode/<session-id>/...` also lives there now, including
safe session/command id normalization. Durable session snapshot projection and
runtime-handoff projection also live in `internal/mooncode`, including the
runtime-consumer status/action block and runtime event-ingest contract, so
append-log session state, claim/replay consumer state, and runtime resume
manifests are data-only MoonCode protocol objects. Initial typed session
record construction, command action/context/message defaults, command event
shaping, command-event session append/update, command-event fallback id
projection, transcript-message event shaping,
command packet construction, preflight blocked/override event id projection,
and stable command-id projection, OpenSeek serve-wire wrapping, native MoonCode
command bodies, execution plans, result contracts, and compact execution
summaries are also `internal/mooncode` protocol behavior. Runtime
dispatch status/detail classification, runtime-dispatch receipt id projection,
and runtime-dispatch receipt body
construction live there too, including the response-normalized dispatch receipt
view used by operator/runtime feed endpoints. The MoonClaw task-bridge and
native runtime session patch shapes and host-neutral patch application also
live there now: MoonCode classifies the status/detail,
`mooncode_dispatch_mode`, `last_message`, `mooncode_last_command_packet`, and
status transcript row while MoonWiki appends UI status messages, supplies host
timestamps, calls the patch applier, and persists the result. The native
runtime-supervisor launch result patch is
MoonCode-owned as well: MoonWiki posts to MoonClaw, but MoonCode decides the
session status row, dispatch mode, and updated timestamp fields to apply after
the loop/turn response. Moondesk supplies stable ids, timestamps,
persistence, and observed host state but no longer owns those runtime-feed,
dispatch-receipt, native-dispatch/supervisor-run session-patch, or
durable-session schemas.
The durable sidecar layout for `.moontown/mooncode-sessions/<session-id>/`
also moved into `internal/mooncode`: event logs, command logs,
runtime-command logs, runtime-dispatch logs, session snapshots, and stream
checkpoint relative paths are now protocol-owned. `internal/moonwiki` only
joins those relative paths to a workspace root and performs filesystem reads
or writes.
`internal/moonwiki` delegates to that package when
validating runtime queue rows, exporting `/serve-jsonl`, building command
packets, parsing sidecar logs, projecting events, rendering `/stream` JSONL/SSE
batches, rendering `/stream-state` payloads, rendering `/runtime-replay` and
`/runtime-claim` projections, building claim/replay receipts, saving stream
checkpoints, rendering the tool contract, normalizing OpenSeek-style runtime
events, canonicalizing incoming MoonCode events, and enforcing/read-projecting
MoonCode command preflight gates, action-plan rows, session summaries, and
eval-report responses. Its host-side event/summary projection adapter now lives
outside the generic session router, and the host-side command-event default
adapter delegates id projection to MoonCode while staying isolated with the
command handlers instead of the session route wrapper. The create-session HTTP flow also lives in a dedicated
MoonWiki adapter file, and review-artifact manifest reads plus refresh live in
their own artifact adapter, leaving the generic session router focused on list
and event reads. The action-plan and runtime-evidence HTTP/projection adapters
are separate from that router as well, so route wrappers gather host logs while
MoonCode owns the response contracts and saved action-plan manifest response
shape, including the session projection response wrapper. It now also delegates typed session-record
creation, command action/context/message defaults, command-event creation/append,
command-event fallback id projection, transcript-message event shaping, MoonBook
change-set, patch-set, tool-approval, test-run, package-manifest,
package-index, package-candidate, typed session snapshot, runtime-handoff
manifest, runtime-consumer handoff, and runtime event-ingest contract body
construction, plus command packet/runtime command/native command body
construction, runtime-dispatch receipt body construction,
tool-authorization preview construction, and tool-authorization
decision/contract projection. Static MoonCode capability, runtime-contract,
eval-harness, and native-eval report schemas now live in `internal/mooncode`
too. The engine-status readiness model also moved there: supported endpoint
rows, bridge/production status calculation, and the checkout/daemon/model/task/
runtime/adapter/eval check list are now protocol-owned. It includes
`adapter_status`, `native_runtime_ready`, and `legacy_task_bridge_ready` plus
the nested MoonClaw adapter contract, making compatibility mode explicit.
`internal/moonwiki` only probes
the configured MoonClaw daemon and passes the observed facts into that pure
projection before returning the desktop API response. This keeps
`/api/mooncode/capabilities`, `/api/mooncode/eval-harness`,
`/api/mooncode/extraction-boundary`, and
`/api/mooncode/production-rubric` backed by a package that can later be
extracted as standalone `mooncode` protocol surface.
The older HTTP-local session-summary and eval-report implementations have
also been removed; `internal/moonwiki` keeps only compatibility wrappers that
call `@mooncode.session_summary` and `@mooncode.eval_report_projection`.
`internal/moonwiki` retains stable id/timestamp generation, path selection,
source inventory reads, file writes, daemon/native-runtime probes, and the
MoonClaw-facing tool-authorization HTTP handshake. `internal/mooncode` now owns
legacy MoonClaw `desc.msg` event-record shaping for `UserMessage`,
`AssistantMessageDelta`, `AssistantMessage`, `RequestCompleted`, runtime
status/progress events, `PreToolCall`, and `PostToolCall`, including
diff/test/artifact path and command extraction. It also owns the runtime ingest
report's descriptor-only fallback acceptance for older MoonClaw logs. The
filesystem-backed sidecar store, HTTP query parsing, live-tail polling,
checkpoint file writes, host fallback ids/timestamps, action-plan manifest persistence, and
dispatch/claim/replay receipt appends remain in `internal/moonwiki`; new
runtime-neutral MoonCode contracts should move into `internal/mooncode` before
becoming part of a standalone `mooncode` component.

## Reference Shape

Use `../openseek` as the interaction and runtime reference:

- typed runtime/session/tool packages
- append-only session event log
- persistent prompt/steer/cancel command stream
- `read`, `edit`, `write`, `shell`, `moon_ide`, `moon_cmd`,
  `moon_check`, and `finish` tools
- streamed assistant/reasoning/tool/result events
- file-edit and tool reliability evals

Moondesk should not copy OpenSeek as a whole app. It should expose the same
coding ergonomics through a MoonBook-aware native desktop surface while
MoonClaw provides the real engine.

## Current Host Contract

Moondesk exposes the first extractable MoonCode contract at:

```text
GET /api/mooncode/capabilities
GET /api/mooncode/eval-harness
GET /api/mooncode/extraction-boundary
GET /api/mooncode/production-rubric
GET /api/mooncode/sessions
GET /api/mooncode/sessions?format=listing
POST /api/mooncode/sessions
GET /api/mooncode/sessions/<session-id>/events
GET /api/mooncode/sessions/<session-id>/stream?format=jsonl&since=<sequence>
GET /api/mooncode/sessions/<session-id>/stream?format=sse&since=<sequence>
GET /api/mooncode/sessions/<session-id>/stream-state?consumer=<consumer>&since=<sequence>
POST /api/mooncode/sessions/<session-id>/stream-state
GET /api/mooncode/sessions/<session-id>/change-set
GET /api/mooncode/sessions/<session-id>/patch-set
GET /api/mooncode/sessions/<session-id>/tool-approvals
GET /api/mooncode/sessions/<session-id>/tool-authorization
POST /api/mooncode/sessions/<session-id>/tool-authorization
GET /api/mooncode/sessions/<session-id>/test-runs
GET /api/mooncode/sessions/<session-id>/package-candidates
GET /api/mooncode/sessions/<session-id>/eval-report
POST /api/mooncode/sessions/<session-id>/eval-report
GET /api/mooncode/sessions/<session-id>/runtime-handoff
GET /api/mooncode/sessions/<session-id>/session-store
GET /api/mooncode/sessions/<session-id>/runtime-commands
GET /api/mooncode/sessions/<session-id>/runtime-dispatch
GET /api/mooncode/sessions/<session-id>/runtime-events
POST /api/mooncode/sessions/<session-id>/runtime-events
GET /api/mooncode/sessions/<session-id>/runtime-claim
GET /api/mooncode/sessions/<session-id>/runtime-execution-plan
GET /api/mooncode/sessions/<session-id>/runtime-supervisor
POST /api/mooncode/sessions/<session-id>/runtime-supervisor
GET /api/mooncode/sessions/<session-id>/serve-scheduler
GET /api/mooncode/sessions/<session-id>/runtime-replay
POST /api/mooncode/sessions/<session-id>/runtime-claim
POST /api/mooncode/sessions/<session-id>/runtime-replay
GET /api/mooncode/sessions/<session-id>/preflight?action=<action>&context_path=<path>
GET /api/mooncode/sessions/<session-id>/action-plan
GET /api/mooncode/sessions/<session-id>/production-readiness
GET /api/mooncode/sessions/<session-id>/runtime-evidence
GET /api/mooncode/sessions/<session-id>/commands
POST /api/mooncode/sessions/<session-id>/commands
```

`GET /api/mooncode/sessions?format=listing` returns the OpenSeek-style compact
machine picker shape owned by `internal/mooncode`: each row includes `id`,
`title`, `updated_at`, `updated_at_ms`, workspace identity, status/model, and
session/stream URLs. The full session projection remains the default response
for existing Moondesk UI surfaces. When a MoonClaw daemon is reachable,
Moondesk asks `GET /v1/mooncode/sessions?book_root=<path>&format=json` and
merges those native rows ahead of local desktop records by session id. The
native `format=json` route follows OpenSeek's machine-readable session-list
contract: a raw array of `{id, title, updated_at_ms}` rows. Moondesk still
accepts MoonClaw's richer `{ "sessions": [...] }` envelope from `format=listing`
for compatibility; parsing that compatibility layer is owned by
`internal/mooncode`, not the MoonWiki HTTP route. Sparse OpenSeek-compatible
rows stay valid; Moondesk only fills missing UI metadata such as `source`,
`protocol`, and `component` at the boundary. Moondesk supplies persistence and
optional host timestamps; the title and row contract are MoonCode protocol
behavior so MoonClaw, OpenSeek, or a standalone `mooncode` runtime can expose
the same shape from native sidecars.
MoonClaw sorts native listing rows newest first by factual `updated_at_ms`,
with undated rows last; Moondesk preserves that daemon order when merging
native rows ahead of local fallback rows. Native rows now prefer the stored first
user prompt for `title`, matching OpenSeek's machine picker semantics, while
local Moondesk fallback rows use the same first-prompt rule before transcript,
latest-message, or title fallbacks. Older sidecars can still fall back to the
latest message or command id.

The response names the ownership split, workspace modes, preferred command and
event protocol, typed `command_specs`, expected tools, typed `tool_specs`, book
output locations, a machine-readable `tool_contract`, and a live
`engine_status` block. `engine_status` reports the
configured MoonClaw checkout, daemon status, safe read probes for `/v1/models`
and `/v1/tasks`, the current prompt/message/cancel bridge, the sidecar
append-only session log, and the missing MoonClaw-owned runtime/eval evidence
that still prevents a production-ready coding-agent claim. It also exposes a
structured `runtime_protocol` and `runtime_contract` derived from the
`../openseek` reference shape: serve-mode `prompt`/`steer`/`cancel` commands,
OpenSeek JSONL event names, runtime state, durable sessions, typed tool
registry, agent loop, JSONL/SSE wire protocol, session store, and eval harness
requirements. The runtime contract now includes `namespace_roles` to prevent
the overloaded name from hiding ownership: Moondesk MoonCode is the workspace
mode, `mooncode.v1` is the extractable protocol/library target, MoonClaw is the
runtime owner, and MoonBook is the artifact owner. The `serve-scheduler`
endpoint exposes the ordered OpenSeek serve
loop semantics over the durable MoonCode logs, so MoonClaw or a future
standalone `mooncode` process can enforce one active turn, queued prompts,
steer-to-active-or-pending, and cancel-active-or-withdraw-pending behavior
without reading Moondesk component state. The eval contract
includes a `native_eval_report` target for MoonClaw:
`/v1/mooncode/sessions/<id>/eval-report?book_root=<path>`, required fields, accepted status
values, and Moondesk's normalization rule for persisting native proof into
`wiki/reviews/mooncode/<session-id>/eval-report.json`. Moondesk reads this
route into the MoonCode inspector so the coding-agent boundary is visible at
runtime instead of only documented.
MoonClaw now also exposes read-only cold session-store routes:
`GET /v1/mooncode/sessions?book_root=<path>` and
`GET /v1/mooncode/sessions/<id>?book_root=<path>`. These project the
book-local `.moonclaw/mooncode/sessions/<session-id>/` sidecars without
spawning a task, so Moondesk or a future standalone `mooncode` process can
discover and show durable sessions after daemon restart. The records include
live-binding status, snapshot payload, storage paths, and command/event/package
log counts. The compact picker contract is also native-owned:
`GET /v1/mooncode/sessions?book_root=<path>&format=json` returns the
OpenSeek-compatible session rows used by Moondesk's switcher, and the runtime
handoff now carries that endpoint as `native_session_listing`. MoonClaw owns
`updated_at_ms` for those native rows: live sessions use their `last_updated`
clock timestamp, and durable sidecar sessions use the newest filesystem mtime
across the session event, command, package-result, runtime-dispatch, and
snapshot files. Moondesk should display and sort these native rows as factual
runtime data rather than recomputing timestamps from local projections. The
native list is already newest-first with undated rows last, matching
OpenSeek's JSON session-list picker semantics. MoonClaw keeps
`format=listing` as a richer diagnostic envelope. Moondesk also accepts a native
raw array of `{id,title,updated_at_ms}` rows so an OpenSeek-style engine can be
plugged into the same picker without a MoonClaw envelope shim.
MoonClaw also exposes the first native durable lease point:
`GET /v1/mooncode/sessions/<id>/serve-scheduler?book_root=<path>` projects the
OpenSeek-style ordered scheduler directly from MoonClaw's native
`commands.jsonl` and `runtime-dispatches.jsonl` sidecars. It reports the active
turn, pending turns, lifecycle rows, and effects such as `start-turn`,
`deliver-steer`, `queue-steer`, `cancel-active`, and `withdraw-pending` without
spawning or claiming work. Moondesk can render this state, but MoonClaw now owns
the native runtime interpretation of the durable command queue.
`GET /v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>` and
`POST /v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>`. The GET
route projects the next claimable command from the native `commands.jsonl`
sidecar and existing `runtime-dispatches.jsonl` receipts. The POST route appends
a `runtime-claimed` receipt for the next unresolved command without spawning a
task. MoonClaw now also exposes
`POST /v1/mooncode/sessions/<id>/runtime-dispatch?book_root=<path>`, which
claims the next durable command if needed, forwards the claimed command to the
MoonClaw task runtime, and appends a `runtime-delivered` or `runtime-failed`
receipt. Durable `cancel` commands go through MoonClaw's task cancellation path
and record terminal `runtime-cancelled` receipts instead of being forwarded as
chat. This gives native cold sidecar sessions a daemon-owned path from claim to
delivery; the remaining gap is the full OpenSeek-style typed loop around
model/tool execution, steering, cancellation, and eval proof.

`GET /api/mooncode/extraction-boundary` returns the standalone
`mooncode-extraction-boundary` object without the broader capabilities payload.
It names the portable core package, Moondesk projection package, MoonWiki host
package, future standalone package, runtime-engine owner, and extraction rules.
This gives tests, operators, and future standalone clients a small stable
contract for the `moonwiki`/`mooncode`/`moondesk`/`moonclaw` split.

`GET /api/mooncode/production-rubric` returns the static
`mooncode-production-grade-rubric` contract. It lists the 18 production checks,
score thresholds, evidence requirements, next actions, and responsible owners
that `production_readiness` uses for each session. This keeps "production
grade" measurable and stable instead of being a UI-only label.

`GET /api/mooncode/sessions/<session-id>/production-readiness` returns the
session-scoped `mooncode-session-production-readiness` audit response. It
contains the compact readiness summary, score, level, first blocker, next
action, next owner, all check evidence, the static rubric, and durable evidence
paths. Moondesk dashboards can poll this endpoint for regular production-grade
scoring without loading the full session transcript.
The MoonCode Readiness panel now loads this endpoint for the selected session
and falls back to the full session summary only while the compact audit payload
is still loading.

`GET /api/mooncode/eval-harness` is the standalone eval-harness contract for
the extractable `mooncode` boundary. It names the OpenSeek references
`../openseek/eval/tool_harness`, `../openseek/eval/file_edit`,
`../openseek/eval/patch_review`, `../openseek/eval/command_execution`, and
`../openseek/eval/package_output`; required tool coverage (`read`, `write`,
`edit`, `shell`, `moon_ide`, `moon_cmd`, `moon_check`, `finish`); file-edit
cases (`exact_replace`, `ambiguous_replace`, `multiline_replace`,
`create_file`, `compile_fix`); patch/review, command, and package evidence
rules; report schema; and the production rule that all required harnesses must
be fresh and passing for the current MoonClaw build. Moondesk only exposes and
renders this contract; MoonClaw or a future standalone `mooncode/eval` package
must run the harnesses and publish
`/v1/mooncode/sessions/<id>/eval-report?book_root=<path>`.
Each command spec names action, dispatch mode, approval policy, expected event
lanes, and tool hints. Each tool spec names the tool id, owner, event lane,
approval policy, purpose, and expected outputs.
Per-command runtime evidence now includes `tool_harness`, a protocol-owned
projection that mirrors OpenSeek's tool harness at the session proof layer: it
checks each expected tool in the command's `tool_sequence` for command-scoped
`tool_call` and `tool_result` proof, treats malformed or rejected tool traffic
as failed evidence, and marks the command `proven`, `missing-evidence`, or
`failed` without making Moondesk execute the tool.

`tool_contract` is the executable MoonClaw/MoonCode registry contract. It
defines `read`, `edit`, `write`, `shell`, `moon_ide`, `moon_cmd`,
`moon_check`, and `finish` with:

- owner and execution boundary
- lane and approval policy
- input field schema
- required output events
- whether the tool mutates files
- whether operator review is required
- path, diff, test, approval, and extraction constraints

This is intentionally data-only so it can move into a standalone `mooncode`
package later. Moondesk renders the contract and records approval intent;
MoonClaw or standalone MoonCode must enforce it before executing file or shell
tools.

`tool_call_wire` is the matching runtime input contract for actual tool calls.
It accepts OpenSeek native function-call objects, wrapped runtime events, and
flattened MoonCode event shapes; rejects unknown tools; exposes
`mutates_files`/`requires_review`; and keeps raw plus parsed arguments together
so the UI, evidence projector, and MoonClaw runtime agree on the same tool-call
identity before execution.

Native MoonCode command bodies now also carry a `tool_policies` array inside
their `execution_plan` and `tool_contract`. This is the first OpenSeek-style
tool guardrail layer for MoonClaw: every planned `read`, `edit`, `write`,
`shell`, `moon_ide`, `moon_cmd`, `moon_check`, `package_app_tool`, and
`finish` step names required
inputs, proof events, approval policy, mutation behavior, and runtime
guardrails. The policies include bounded reads/output, recent-read-before-edit,
MoonBit manifest protections such as rejecting new `moon.mod.json` files and
JSON-shaped `moon.mod`/`moon.pkg` content, argv-only shell execution, test
evidence publication, and package manifests bound to MoonBook-owned source
paths. Moondesk only serializes and renders these policies; MoonClaw or
standalone MoonCode must enforce them at the tool boundary.

The runtime contract deliberately names MoonClaw as the target owner for the
engine pieces:

```text
agent_runtime  -> workspace root, task scope, steering queue, runtime events
agent_session  -> typed durable conversation and append-only session store
agent_tool     -> read/edit/write/shell/moon_ide/moon_cmd/moon_check/finish registry
agent_loop     -> run_turn/run_turn_with_append/run_turn_in_scope semantics
eval_harness   -> tool harness and file-edit eval proof
```

The wire protocol mirrors OpenSeek serve mode:

```json
{"command":"prompt","text":"create a tool","session_id":"...","book_root":"..."}
{"command":"steer","text":"keep it inside tools/","session_id":"..."}
{"command":"cancel","session_id":"..."}
{"command":"apply_patch","session_id":"...","context_path":"tools/demo/main.mbt"}
{"command":"revert_patch","session_id":"...","context_path":"tools/demo/main.mbt"}
```

Moondesk now exposes the same ordered wire feed as direct NDJSON for native
consumers:

```text
GET /api/mooncode/sessions/<session-id>/serve-jsonl
GET /api/mooncode/sessions/<session-id>/serve-jsonl?scope=all
```

The default response is only pending, valid OpenSeek-compatible commands, with
delivered commands and active runtime leases skipped according to the durable
`runtime-dispatches.jsonl` receipts. `scope=all` exports every valid wire
command in append order for bootstrap/debug replay. This is the narrowest
extraction seam for MoonClaw or a future standalone `mooncode`: it can consume
prompt/steer/cancel JSONL without parsing the full Moondesk session projection,
then acknowledge completion through `/runtime-replay` and append streamed events
through `/runtime-events`.

MoonClaw's native `runtime-loop` can now use the same feed in a bounded live
mode: callers may pass `live_wait_ms` and `poll_ms` when posting to
`/v1/mooncode/sessions/<id>/runtime-loop?book_root=<path>`. With
`live_wait_ms=0` it preserves immediate idle behavior; with a positive value it
polls `commands.jsonl` for newly appended prompt, steer, or cancel commands
before returning idle and reports `waits`, `live_wait_attempt_count`, and
`live_wait_elapsed_ms` in the response.
Moondesk now uses this mode in both native launch paths: automatic command
drains request a short wait for rapid follow-on steering, while the explicit
`Run Native Loop` action posts `live_wait_ms=5000` and `poll_ms=250` unless an
API caller overrides those values.

MoonClaw also exposes a daemon-owned background supervisor slice at
`/v1/mooncode/sessions/<id>/runtime-service?book_root=<path>`. It starts a
task-group service outside the request lifecycle, appends
`runtime.service_started` and `runtime.service_finished` events to the selected
book's `events.jsonl`, and executes the same bounded native `runtime-loop`.
Moondesk exposes this through
`POST /api/mooncode/sessions/<id>/runtime-service` and a `Start Service` action
beside `Run Native Loop`, then refreshes the stream, claim state, event sink,
evidence, tests, packages, action plan, and compact production-readiness gate.
The runtime panel now also projects the latest service lifecycle state from
durable `runtime.service_*` events and exposes `Stop Service` as an explicit
MoonCode `cancel` command, matching the OpenSeek serve-mode shape where
cancellation is ordered through the runtime command stream instead of killing
the desktop shell. This gives Moondesk and a future standalone `mooncode` a real
service endpoint to discover through `/v1/mooncode/capabilities`; richer
multi-session service lifecycle controls and resume UX are still product
hardening work.

Output events include assistant/reasoning deltas, tool calls/results, runtime
updates, file changes, diffs, test results, artifacts, finish/abort, command
errors, and dropped steering. This is now rendered in the MoonCode inspector as
a product/runtime contract together with engine readiness. The implementation
still delegates through the current MoonClaw daemon bridge until MoonClaw owns
the native engine and reports `/v1/mooncode/capabilities` plus OpenSeek-style
tool, file-edit, patch-review, command-execution, and package-output eval
results.

The session/event routes project existing MoonClaw task events into MoonCode
lanes:

- `transcript`: user and assistant messages.
- `runtime`: model, queue, context, cancel, and failure status.
- `tool`: generic tool calls and results.
- `diff`: file writes, edits, patches, and extracted diffs.
- `test`: `moon test`, `moon check`, `moon build`, and related result output.
- `artifact`: packaged tools, miniapps, generated sites, and app-tool bundles.
- `review`: operator accept/reject decisions and review handoff commands.

The stream route emits the same ordered event projection as a protocol stream
with stable absolute sequence numbers:

- default or `format=jsonl`: newline-delimited JSON records.
- `format=sse`: `text/event-stream` records named `mooncode.meta`,
  `mooncode.event`, and `mooncode.done`.
- optional `since=<sequence>`: emits only events with a sequence greater than
  `since`; `mooncode.meta` and `mooncode.done` include `next_since` so clients
  can poll incrementally without replaying the whole session.
- optional `live=true`: waits briefly for events after `since` before returning
  the JSONL/SSE batch. `timeout_ms` is clamped to 15 seconds and `poll_ms` is
  clamped between 50 and 1000 ms. This is Moondesk's resumable UI-facing live
  projection; MoonClaw or standalone `mooncode` still owns event production and
  native blocking runtime streams.

The current stream is an incremental append-log replay plus bounded live-tail
over persisted session state, MoonClaw events, and MoonCode's sidecar JSONL
event log:

```text
.moontown/mooncode-sessions/<session-id>/events.jsonl
.moontown/mooncode-sessions/<session-id>/commands.jsonl
.moontown/mooncode-sessions/<session-id>/runtime-commands.jsonl
.moontown/mooncode-sessions/<session-id>/runtime-dispatches.jsonl
.moontown/mooncode-sessions/<session-id>/stream-checkpoints/<consumer>.json
.moontown/mooncode-sessions/<session-id>/session.json
```

MoonClaw owns a parallel native book-local store for the runtime side:

```text
.moonclaw/mooncode/sessions/<session-id>/session.json
.moonclaw/mooncode/sessions/<session-id>/commands.jsonl
.moonclaw/mooncode/sessions/<session-id>/runtime-dispatches.jsonl
.moonclaw/mooncode/sessions/<session-id>/events.jsonl
.moonclaw/mooncode/sessions/<session-id>/package-results.jsonl
.moonclaw/mooncode/watchers/moon-check.json
```

The native list/show, runtime-claim, and runtime-dispatch endpoints read this
store directly. This removes the previous pure in-memory discovery, claim, and
first delivery gap, but the full OpenSeek-style loop is not complete until
MoonClaw can execute, resume, and steer complete turns from claimed durable
commands without relying on a current in-memory task binding.
MoonClaw also owns the native `moon_check` watcher contract in this store:
tool results expose `watcher=started|reused|replaced|restarted`, textual watcher
`status`, numeric `exit_status`, `seq`, `restart_count`, command line, and
state path. Moondesk should render this proof and test status; it should not
start duplicate checkers or infer watcher lifecycle in the desktop layer.
MoonClaw's native `/v1/mooncode/sessions/<id>/runtime-events` response now
also projects that watcher state into a synthetic test-lane `runtime_update`
with `[moon_check update]` content. Its `event_count` includes this projected
state, while `durable_event_count` remains the raw `events.jsonl` count.
Moondesk's `/api/mooncode/sessions/<id>/runtime-events` GET uses that native
endpoint when MoonClaw is running, merges native events ahead of local append-log
events by durable event id, and reports `local_event_count`,
`native_event_count`, `native_runtime_ready`, and
`native_runtime_events_endpoint` so the UI can show whether runtime evidence is
coming from MoonClaw or only from the desktop fallback.
Native payloads are treated as foreign engine input before that merge:
Moondesk runs the same OpenSeek/MoonClaw normalizer used by POST ingest, assigns
canonical MoonCode ids when native events omit them, and exposes
`native_runtime_events_submitted_count`,
`native_runtime_events_accepted_count`,
`native_runtime_events_rejected_count`, plus the full
`native_runtime_events_report`. This prevents valid OpenSeek-style native
events such as id-less `tool_result` rows from being dropped by the merge layer.

MoonCode session creation uses `POST /api/mooncode/sessions`. It creates a
normal Moondesk agent session bound to the selected MoonBook and MoonClaw task,
but tags the record with `component=mooncode`, `protocol=mooncode.v1`, and
`mooncode_session_kind=coding`. The first prompt is recorded as a typed
`mooncode.v1` command packet before dispatch, so a new session is resumable and
auditable as MoonCode from its first turn.

Moondesk appends command/review/test/package control events to `events.jsonl`,
appends every normalized UI command packet to `commands.jsonl`, and appends an
engine-facing runtime command to `runtime-commands.jsonl`. After Moondesk
attempts live dispatch, it appends a dispatch receipt to
`runtime-dispatches.jsonl` recording whether the command went to the native
MoonCode runtime, the legacy MoonClaw task bridge, failed, or remains only
recorded. The UI command queue is deliberately separate from rendered
transcript events; the runtime command feed is deliberately separate from the UI
queue; dispatch receipts are audit proof, not a second execution queue.
MoonClaw or a future standalone `mooncode` runtime should consume ordered
execution intent from `runtime-commands.jsonl`, while Moondesk renders observed
progress from `events.jsonl`.

The runtime replay endpoint is the current single-consumer handoff surface:

- `GET /api/mooncode/sessions/<session-id>/runtime-replay` returns decode
  reports, delivered receipts, pending command items, and
  `pending_openseek_jsonl`.
- `GET /api/mooncode/sessions/<session-id>/runtime-claim` returns the lease
  projection: claimable, claimed, delivered, failed, and invalid runtime
  commands, plus the latest receipt and acknowledgement endpoint per command.
  Runtime consumers may pass `?now=<iso-time>` when they need deterministic
  `lease_expires_at` evaluation.
- `POST /api/mooncode/sessions/<session-id>/runtime-claim` accepts
  `{consumer_id, max_count, force, lease_expires_at, now}` and appends
  `runtime-claimed` dispatch receipts for pending valid commands in file order.
  Expired `runtime-claimed` receipts and failed dispatches become claimable
  retry work without `force`; active earlier claims and invalid earlier commands
  block later non-delivered rows so OpenSeek serve ordering is preserved.
  Expired-claim recovery receipts record the previous claim id and expiry. This
  is the durable lease step for MoonClaw or standalone `mooncode`; it does not
  execute tools inside Moondesk.
- `POST /api/mooncode/sessions/<session-id>/runtime-replay` accepts
  `{consumer_id, command_id, status, detail, events}` or
  `{receipts:[...], events:[...]}`. It appends `mooncode.runtime-dispatch`
  receipts with `dispatch_mode: "mooncode-runtime-replay"`, copies prior
  dispatch/claim context into `previous_dispatch_status`,
  `previous_claim_id`, `previous_consumer_id`, and `claimed_by_same_consumer`,
  classifies `ack_order_status`, and normalizes any included OpenSeek/MoonCode
  runtime events into `events.jsonl`. Events submitted inside a replay
  acknowledgement inherit a `mooncode.command-ref` packet from the acknowledged
  runtime command when they do not already carry `command_packet.command_id`.
  That makes the events usable as command-scoped proof without forcing every
  runtime event to repeat the queue metadata.
  Replay receipts also summarize submitted proof events with
  `submitted_event_count`, `normalized_event_count`, `proof_event_count`, and a
  `runtime_event_summary` object listing normalized lanes such as `tool`,
  `diff`, `test`, `artifact`, and `review`. This lets Moondesk show whether a
  completed runtime command produced reviewable evidence instead of only a
  terminal acknowledgement.
  Package acknowledgements may include `package_manifest` and `package_index`
  events; Moondesk normalizes them into `package.manifest` and `package.index`
  artifact-lane proof so the same replay payload can satisfy package completion
  without relying on UI-generated manifests alone.
  For proof-sensitive actions (`run_tests`, `run_eval`, `package`, `commit`,
  `accept`, `reject`, `apply_patch`, `revert_patch`, `approve_tool`, and
  `reject_tool`), a requested `runtime-completed` acknowledgement is not treated
  as delivered until required command-scoped proof events and typed
  tool-harness proof are present. The proof gate checks both events already
  appended through `/runtime-events` and events submitted inside the
  acknowledgement. If required proof is missing or failed, or if the declared
  tool sequence is not proven by matching `tool_call`/`tool_result` evidence,
  the receipt records `requested_status: "runtime-completed"` but uses effective
  `status: "proof-missing"` with a `proof_gate` object listing required, proven,
  missing, and failed events plus `tool_harness_status`,
  `tool_harness_expected_tool_count`, `tool_harness_proven_tool_count`,
  `tool_harness_missing_tool_count`, and `tool_harness_failed_tool_count`.
  `proof-missing` commands remain retryable pending work for MoonClaw or
  standalone `mooncode`; they are not counted as delivered completion.

`runtime-claimed` receipts are treated as leased until `lease_expires_at`
passes; expired claims, failed dispatches, and proof-missing completions are
projected as claimable retry work. Active `runtime-claimed` receipts hide later
non-delivered rows behind a `blocked-by-prior-command` status until the active
lease is acknowledged, failed, expired, or force-recovered.
`runtime-acknowledged` and proof-satisfied `runtime-completed` receipts are
treated as delivered for replay dedupe, alongside native-dispatched and
legacy-bridged receipts. This lets MoonClaw or a standalone `mooncode` loop claim from
`runtime-commands.jsonl`, skip already leased or consumed command ids, execute
outside Moondesk, and report progress without depending on the Moondesk UI
process.

The runtime-command feed response also returns `decode_reports`, proving each
stored row can be decoded back to the OpenSeek-compatible serve command shape.
It also returns `dispatch_receipts`, `runtime_dispatch_pending_count`, and
`runtime_dispatch_log_path`. The dedicated
`GET /api/mooncode/sessions/<session-id>/runtime-dispatch` route returns the
same dispatch audit state plus pending command ids for operators and future
MoonClaw supervisors.
The dedicated `GET /api/mooncode/sessions/<session-id>/runtime-replay` route
returns a deterministic OpenSeek serve-mode replay plan: decoded command
reports, delivered/skipped command ids, pending command items, and
`pending_openseek_jsonl`. A MoonClaw supervisor can feed those JSONL lines to a
serve-mode runtime in append order while skipping command ids already marked
`native-dispatched` or `legacy-bridged`, which prevents accidental duplicate
execution.

The MoonCode UI now renders that same replay plan as a Runtime Replay panel
beside Runtime Feed, Runtime Claims, and Dispatch Receipts. Operators can see
pending/delivered/claimed/invalid counts, the exact pending OpenSeek JSONL wire
commands, first pending/invalid markers, and per-command decode status without
opening raw files. The panel is read-only by design: Moondesk shows replay
readiness, while MoonClaw or standalone `mooncode` still owns claiming,
executing, streaming, and acknowledging the commands.

The Runtime Claims panel can also call `POST /runtime-claim` through explicit
`Claim Next` and `Force Claim` controls. This marks one pending runtime command
as leased by the `moondesk-ui-inspector` consumer and refreshes replay,
dispatch, handoff, and action-plan state. It is a handoff/debug control for the
ordered MoonClaw consumer loop, not a Moondesk executor: claimed commands still
must be executed by MoonClaw or standalone `mooncode` and acknowledged through
`POST /runtime-replay`.

Claimed Runtime Claims rows expose `Ack`, `Complete`, and `Fail` controls. These
POST `runtime-acknowledged`, `runtime-completed`, or `failed` receipts to
`/runtime-replay` for the selected command id, then refresh the claim/replay/
dispatch/event/handoff panels. The controls close the handoff audit loop for
operator testing, but they do not execute shell, file, or edit tools inside
Moondesk.

`session-store` and `runtime-handoff` persist the same normalized dispatch
receipt shape used by the HTTP API. Legacy or partially written dispatch rows
are projected with stable `legacy_bridge_endpoint`, `native_mooncode_endpoint`,
`runtime_command`, `owner`, status, and timestamp fields before they are written
into `session.json` or `wiki/reviews/mooncode/<session-id>/runtime-handoff.json`.
This keeps the extraction boundary durable: a MoonClaw supervisor or future
standalone `mooncode` runtime can consume the stored handoff without carrying
Moondesk UI fallback logic for old receipt rows.

The runtime handoff also includes a `runtime_consumer` block. It summarizes
whether the queue is `claim-ready`, `lease-held`, `delivered`,
`blocked-invalid-command`, or idle; exposes `ready_to_claim` and
`ready_to_replay`; repeats the claim/replay/events/native session listing and
native serve-scheduler/eval endpoints; and spells out the required consumer
loop:

```text
GET runtime-handoff or session-store
-> GET runtime-claim
-> POST runtime-claim with consumer_id
-> GET native serve-scheduler when using MoonClaw's native MoonCode endpoint
-> execute the claimed OpenSeek-compatible command with MoonClaw/MoonCode tools
-> POST runtime-events for streamed reasoning/tool/diff/test/artifact evidence
-> POST runtime-replay with acknowledgement/completion
-> POST eval-report when native harness evidence is available
```

The same handoff now carries a `runtime_execution_plan` block, also available
directly from
`GET /api/mooncode/sessions/<session-id>/runtime-execution-plan`. This is the
runtime-facing next-step packet for MoonClaw or standalone `mooncode`: it selects
the first claimable or leased command, repeats the `command_id`, `action`,
target path, OpenSeek wire command, native MoonCode command body, execution
summary, required proof events/outputs, claim template, ack/failure templates,
runtime event ingest endpoint, and safety boundary. It is deliberately data-only.
Moondesk publishes and renders this plan; MoonClaw owns claiming it, running
tools, streaming evidence, and acknowledging completion or failure.
The resume contract also carries
`GET /api/mooncode/sessions/<session-id>/production-readiness`, so a native
consumer can fetch the same production gate that the Moondesk Readiness panel
uses before claiming that a session is product-ready.
The plan now embeds a stricter `runtime_turn_packet`, and the saved
`runtime-handoff.json` carries the same packet. The packet combines the next
claimable or leased command, OpenSeek serve command, native MoonCode body,
serve-scheduler decision, required proof events, claim/ack/failure templates,
tool contracts, and endpoint map into one self-contained object. The endpoint
map now includes `native_serve_scheduler` beside native session listing,
commands, and eval-report endpoints, so a native runtime can verify the
OpenSeek-style scheduler projection before execution. This is the object a
MoonClaw supervisor or future standalone `mooncode` loop should consume before
executing a turn; Moondesk still only records and renders it.

Moondesk also exposes a supervisor-ready launch packet at
`GET /api/mooncode/sessions/<session-id>/runtime-supervisor`, and embeds the
same object in `runtime-handoff.json` as `runtime_supervisor`. It wraps the turn
packet with launch status, bridge/native mode, workspace and MoonClaw roots,
claim/ack/event/session endpoints, a `launch_request`, and the required
supervisor loop:

```text
GET session-store
-> POST runtime-claim
-> execute OpenSeek-compatible MoonCode command locally in MoonClaw
-> POST runtime-events
-> POST runtime-replay
-> POST package-result when executable package proof is available
-> POST native eval-report when available
```

This is the current extraction boundary for MoonClaw. The packet is declarative:
Moondesk publishes it, while MoonClaw or standalone `mooncode` owns model calls,
tool execution, path policy, approvals, tests, diffs, packaging, cancellation,
and final acknowledgement.

Moondesk also exposes `POST
/api/mooncode/sessions/<id>/runtime-supervisor` as the operator launch action
for this boundary. The action asks MoonClaw to run a bounded native
`/v1/mooncode/sessions/<id>/runtime-loop`, falls back to one native
runtime-turn if the loop endpoint is unavailable, ingests returned MoonCode
events, refreshes review/test/package/evidence manifests, saves the session,
and returns the enriched session projection. The MoonCode workspace surfaces
this as `Run Native Loop`; Moondesk still does not execute the tools itself.
Loop responses are also projected into a durable `runtime_loop` event, so idle,
failed, cancelled, and max-turn outcomes appear in the MoonCode transcript and
runtime panels even when the loop did not produce per-turn tool output.
`internal/mooncode` now owns native response event extraction for top-level
events, `execution.events`, `package_events`, `turn_receipt.events`, nested
`turns`, and loop-status projection. It also owns the append/merge rule that
folds those returned native events into `mooncode_command_events` with durable
event-id dedupe; Moondesk only supplies the local fallback event id/timestamp
and persists the enriched session.

The supervisor packet also embeds `readiness`, a
`mooncode-runtime-supervisor-readiness` report. It verifies that the packet has a
command id, scheduler permission, claim/ack/runtime-event/session/native
serve-scheduler/production-readiness endpoints, claim and ack request templates, and the required
`load-session`,
`claim-command`, `execute-turn`, `stream-events`, `acknowledge`, `report-eval`,
and `check-production-readiness` loop steps.
When a launch is blocked, the UI renders the missing requirements rather than
leaving operators to inspect raw JSON.

`GET /api/mooncode/sessions/<session-id>/runtime-events` exposes the durable
event sink state, and `POST /api/mooncode/sessions/<session-id>/runtime-events`
lets MoonClaw or a standalone `mooncode` runtime append OpenSeek-style JSONL
events, legacy MoonClaw `desc.msg` events, canonical MoonCode events, or
`{"events":[...]}` batches. The reusable `internal/mooncode` package owns the
`mooncode-runtime-event-ingest-report`: submitted/accepted/rejected counts,
accepted normalized events, rejected event records, command progress, and
runtime/UI ownership metadata. The MoonCode report also owns the temporary
legacy `desc.msg` fallback for older MoonClaw logs, so Moondesk's HTTP handler
uses it as a transport adapter and appends accepted events to
`.moontown/mooncode-sessions/<session-id>/events.jsonl`, and refreshes the
change set, patch set, tool approvals, test runs, action plan, eval report,
session snapshot, and runtime handoff. Native `tool_call`/`tool_started`
events are first validated against `tool_call_wire`; accepted events preserve
`tool_call_id`, command, path, arguments, and a lightweight `mooncode.v1`
command reference when `command_id` is supplied. Runtime `tool_result` events
use the same validation and preserve the same fields when present, including
nested OpenSeek `tool_call.function.arguments`. Unknown or malformed tool calls
normalize to failed `tool_call_decode_error` events instead of tool evidence.
This lets approval manifests, result rows, and command proof stay correlated
when the runtime posts evidence through Moondesk. MoonClaw now also exposes the
engine-owned counterpart at
`GET`/`POST /v1/mooncode/sessions/<session-id>/runtime-events?book_root=<path>`,
normalizing single events or `{"events":[...]}` batches into its book-local
`.moonclaw/mooncode/sessions/<session-id>/events.jsonl` sidecar. That closes
the durable stream-ingress slice on the MoonClaw side. The same GET response
projects MoonClaw's `.moonclaw/mooncode/watchers/moon-check.json` state into a
synthetic `[moon_check update]` runtime event so Moondesk can render live-style
test progress from MoonClaw-owned sidecar proof. The remaining native gap is
the full typed agent loop that emits those events while executing claimed
commands without the in-memory task bridge. MoonClaw remains responsible for
execution, while Moondesk owns durable display and review state.

The MoonCode UI renders the same sink as a Runtime Events panel near Runtime
Replay. It shows the durable event log path, merged event count, local/native
event counts, native MoonClaw readiness, native runtime-events endpoint, POST
endpoint, native submitted/accepted/rejected normalization counts, producer,
accepted payload shapes, ordering rule, normalization rule, and the latest
normalized events. This gives operators and MoonClaw developers a
direct view of whether runtime execution is producing the expected event stream
before those events are projected into lanes, action plans, eval reports, and
review artifacts.
The same response now separates command-scoped proof from unscoped live events.
`command_progress` groups events with `command_packet.command_id`; the
`unscoped_progress` projection counts and lists recent transcript, reasoning,
tool, and runtime events that have not yet been bound to a MoonCode command.
Those unscoped events are visible operator evidence, but they do not satisfy
command proof gates until MoonClaw or standalone `mooncode` emits them with a
command packet.
`GET /api/mooncode/sessions/<session-id>/stream-state` returns the current
append-log cursor state, tail records after `?since=<sequence>`, and the saved
checkpoint for a named consumer. `POST /stream-state` persists
`{consumer_id,last_seen_sequence}` under `stream-checkpoints/`, giving the UI,
MoonClaw, or standalone `mooncode` a durable resume point without making
Moondesk the long-running event producer. The cursor clamp rules and response
record shape live in `internal/mooncode`; Moondesk still owns the HTTP route,
checkpoint path, and file write.
`GET /api/mooncode/sessions/<session-id>/action-plan` returns the compact
execution/review plan over the same durable data. It classifies each command as
queued for runtime, awaiting proof, blocked, ready for review, retryable, or
completed; exposes acceptance gates for tests, tool approvals, diffs, and
source-bound package output; and writes the durable MoonBook artifact
`wiki/reviews/mooncode/<session-id>/action-plan.json` when commands refresh the
session. This is the handoff object MoonClaw or standalone `mooncode` can use
to decide the next runtime step without inferring intent from chat prose.
Raw native runtime events using OpenSeek names such as `assistant_delta`,
`reasoning_delta`, `tool_result`, `agent_finished`, `steer_applied`, and
`turn_failed` are normalized directly into MoonCode lanes before Moondesk falls
back to the older MoonClaw `desc.msg` event projection.
The runtime protocol contract also advertises MoonCode proof events:
`patch_applied`, `patch_reverted`, `package_built`, `package_verified`, and
`commit_created`. These are normalized into review/artifact lanes and should
carry `command_id` or `command_packet` when produced by MoonClaw.
The stream route dedupes event records against legacy inline session events
during replay. It is intentionally shaped so MoonClaw or a future standalone
`mooncode` runtime can replace the pollable incremental producer with a
blocking live append-only event tail without changing the desktop shell
contract.

The MoonCode UI now consumes that same incremental JSONL stream while the
selected session is open. The existing full session poll remains the durable
state refresh, and the stream poll keeps a per-session `next_since` cursor.
The center transcript folds durable chat messages together with normalized
MoonCode runtime events, so reasoning, tool calls, diffs, tests, artifacts, and
review/proof events read as a Codex/OpenSeek-style conversation instead of
living only in diagnostic panels. A separate "Live Tail" batch remains available
for inspecting the raw event feed without replaying the whole transcript.
The center pane starts with a compact session header before the transcript. It
shows the selected book/session, next required action, stream source, dispatch
state, pending steer acknowledgements, event/diff/test/tool/package counts,
eval score, and durable session/command/runtime/event log paths. This gives the
operator the resume and runtime state needed for a Codex/OpenSeek-like coding
session without opening the handoff JSON manually. Pending steer accounting is
now a protocol-owned `mooncode_summary` projection: `steer_command_count`
minus `steer_settlement_count` becomes `pending_steer_count`, with settlements
coming from runtime `steer_applied`/`steer_dropped` events and
`deferred_steer_count` coming from `steer_deferred` runtime evidence. Moondesk
renders those fields from the same package-level summary used by future
standalone `mooncode`. The same summary now includes `steering_lifecycle`, a
row-level projection of durable steer command packets plus command-scoped
`steer_applied`, `steer_deferred`, and `steer_dropped` runtime events. The
MoonCode session header renders that lifecycle with applied/deferred/dropped/
pending counts and recent rows, so deferred or dropped steering is visible
without opening raw event JSON. Cancel is now projected the same way:
`cancel_lifecycle` folds durable `cancel` command packets with command-scoped
`agent_aborted` and `cancel_dropped` runtime evidence, and the header shows
cancelled/dropped/failed/pending rows so operators can tell whether a stop
request reached active work, arrived while idle, failed before MoonClaw accepted
it, or is still waiting for proof. File diff review is also summarized at the
same level through `patch_lifecycle`, a MoonCode-owned projection over current
patch-set entries. The header shows needs-review/runtime-needed/runtime-proven/
blocked counts plus recent patch rows, so an operator can see whether generated
file changes need review, runtime apply/revert proof, or tests before scrolling
to the full patch panel.
Durable resume state is summarized through `resume_lifecycle`, which projects
the latest typed session snapshot plus runtime command/dispatch logs into
snapshot-ready, pending, running, blocked, completed, next-command, and
next-step fields. The MoonCode header renders this before the command-specific
lifecycle panels, making restart/resume readiness visible without opening the
runtime handoff manifest.

Each session also carries a `mooncode_summary` readiness/eval block. It records
the stream mode, `live_stream_ready`, `live_stream_url`, `stream_state_url`,
event log path,
append-log count, command log path, command-log count, typed session snapshot
path, `session_snapshot_ready`, `incremental_stream_ready`,
`incremental_stream_url`, event-lane counts, pending
diff count, accepted/rejected review counts, MoonBook review receipt count,
MoonBook package manifest count, verified/failing test-build result counts,
source-bound package count, `review_state`, an `eval_score`, an `eval_level`,
`steer_command_count`, `steer_settlement_count`, `deferred_steer_count`,
`pending_steer_count`, `steering_lifecycle`, `cancel_command_count`,
`cancel_dropped_count`, `cancel_settlement_count`, `pending_cancel_count`,
`cancel_lifecycle`, `patch_lifecycle`, `package_lifecycle`,
`resume_lifecycle`, and
`eval_checks` for book scope, MoonClaw task attachment, transcript, tool
events, file diffs, tests/builds, verified test results, artifacts, review
decisions, append-only log coverage, typed command packets, ordered command
queue coverage, typed session snapshot coverage, MoonBook-owned review receipts, MoonBook-owned package
manifests, MoonBook-owned test-run manifests, source-bound package evidence,
MoonCode runtime handoff manifests, incremental replay, and live append-only
streaming.
The current implementation marks incremental replay and
`live_append_only_stream` as ready when the local `?live=true` JSONL/SSE tail is
available. Native MoonClaw streaming remains the production runtime target for
a true blocking agent engine stream.

Each command now also refreshes a runtime handoff manifest at:

```text
wiki/reviews/mooncode/<session-id>/runtime-handoff.json
```

`GET /api/mooncode/sessions/<session-id>/runtime-handoff` returns that
`mooncode-runtime-handoff` object. It is the compact resumable bridge between
Moondesk and MoonClaw or a future standalone `mooncode` runtime: typed session
snapshot path, command log, event log, session-store endpoint, stream endpoint,
command queue endpoint, runtime command feed endpoint, action-plan endpoint,
production-readiness endpoint, native MoonClaw endpoints, book output roots,
artifact manifest pointers, engine dispatch mode, the `tool_call_wire` decoder
contract, and the next runtime step. Its runtime event sink repeats the same
`tool_call_wire` contract so MoonClaw can validate OpenSeek-native function
calls, wrapped tool events, and flattened MoonCode tool events before executing
or reporting tool results. Moondesk renders it as the Runtime Handoff panel so
the extractable boundary is visible in the product, not just in source comments.

Moondesk also writes the OpenSeek-style durable session snapshot at:

```text
.moontown/mooncode-sessions/<session-id>/session.json
```

`GET /api/mooncode/sessions/<session-id>/session-store` returns that
`mooncode-session-snapshot` object. The snapshot is intentionally separate from
the generic Moondesk agent-session record: it captures the MoonCode protocol,
book/workspace identity, task id, command packets, event projection, summary,
runtime command packets, the `tool_call_wire` decoder contract, and resume
endpoints in one typed object that MoonClaw or a standalone `mooncode` runtime
can resume without depending on MoonWiki internals or the Moondesk capability
endpoint. The `resume_endpoints` map includes session-store, runtime handoff,
runtime claim/replay/events, runtime commands, JSONL stream, stream state,
action-plan, and production-readiness URLs for the selected session.
Event projection is normalized by `internal/mooncode`, not the Moondesk HTTP
handler: missing event ids, lane/kind/title/status defaults, trimmed detail and
diff text, numeric exit codes, and optional command packets are shaped before
the snapshot, event endpoint, and stream endpoint expose them. This prevents a
future MoonClaw or standalone `mooncode` consumer from inheriting desktop-only
fallback logic just to render or replay partially written runtime events.
OpenSeek/MoonClaw runtime events use the same boundary: the public
`normalize_runtime_event_with_defaults` API hashes the original runtime payload
for a deterministic `mooncode-runtime-event-*` fallback id and injects a
fallback `created_at` only when the runtime did not provide `created_at` or
`created`.

Queued `run_tests` commands and package intents do not count as verified runtime
evidence. `verified_test_count` only increments for completed MoonClaw
test/build result events without failure status, and
`source_bound_package_count` only increments when a MoonBook package manifest
includes source inventory evidence for the candidate being packaged. Package
manifests now also include `promoted_sources`, `promoted_source_count`, and
`source_promotion_status`; Moondesk and MoonClaw copy text source files into
`portable/app-tool/mooncode/<session-id>/sources/<command-id>/...` so a package
candidate can be reviewed from a MoonBook-owned artifact root instead of only
from live workspace paths.
`runtime_package_proof_count` and `runtime_verified_package_count` are separate
runtime evidence: they only increment when MoonClaw or standalone `mooncode`
emits `package_built` or `package_verified` events after assembling/checking a
bundle.

Runtime proof events may carry a `command_id` or `command_packet`. Moondesk
normalizes that into a lightweight `mooncode.v1` command reference on
`test_result`, `package_built`, `package_verified`, `commit_created`,
`patch_applied`, `patch_reverted`, `steer_applied`, `steer_deferred`, and
`steer_dropped` events.
When any proof for an action is command-scoped, the Action Plan only marks the
matching command complete. Older unscoped proof events remain accepted as a
legacy fallback, but MoonClaw and standalone `mooncode` should emit scoped
proofs so concurrent package/commit/test commands cannot satisfy each other by
accident.
Each action-plan row also carries a `runtime_evidence` object. It evaluates the
command's required runtime events from its native result contract and reports
`required_event_count`, `proven_required_event_count`,
`missing_required_events`, and `failed_required_events`. This is stricter than
the legacy aggregate counters: only events with the matching
`command_packet.command_id` satisfy the command-level evidence checklist.
Rows for coding/runtime actions also expose `tool_harness_status`,
`tool_harness_expected_tool_count`, `tool_harness_proven_tool_count`,
`tool_harness_missing_tool_count`, and `tool_harness_failed_tool_count`.
Moondesk now gates delivered `prompt`, `steer`, `run_tests`, `run_eval`,
`package`, `commit`, `accept`, `apply_patch`, and `revert_patch` rows on this
typed tool-harness verdict. If the runtime says a command was delivered but the
expected OpenSeek/MoonClaw tools were not emitted as matching
`tool_call`/`tool_result` proof, the row remains `awaiting-proof`; malformed or
failed tool traffic moves it to `runtime-retry`.
Runtime replay acknowledgement events are normalized with that packet attached,
so `tool_call`, `tool_result`, `test_result`, `package_verified`, and
`agent_finished` events submitted by a claimed command can prove the same
command immediately after `/runtime-replay`.
Command-scoped `tool_call_decode_error` events are failed runtime evidence:
an invalid `tool_call` fails the required `tool_call` proof, and an invalid
`tool_result` fails the required `tool_result` proof. This prevents unknown or
malformed MoonClaw/OpenSeek tool traffic from appearing as a merely missing
backend result.

`GET /api/mooncode/sessions/<session-id>/runtime-evidence` exposes the same
proof as a session-level contract for MoonClaw, Moondesk, or a future
standalone `mooncode` runtime. It returns `mooncode-session-runtime-evidence`
with command, runtime-command, and proof-event counts; per-command evidence
items; tool-harness aggregate counts; and aggregate `proven`,
`missing-evidence`, or `failed` status. This keeps proof consumption out of the
UI implementation and makes it clear what the runtime engine must emit before
Moondesk can treat a coding action as actually executed.
When `/runtime-events` accepts command-scoped streamed proof events, or
`/runtime-replay` accepts acknowledgement events, Moondesk also refreshes a
MoonBook-owned review artifact at
`wiki/reviews/mooncode/<session-id>/runtime-evidence.json`. That file contains
the same session proof projection plus `manifest_path` and
`absolute_manifest_path`, so package/accept/review flows can audit runtime
proof without depending on transient UI state. The persisted manifest and
HTTP response field wrappers are MoonCode-owned protocol helpers; Moondesk only
passes host-selected paths into them.
The MoonCode workspace renders this projection as a Runtime Evidence panel next
to the Action Plan and Runtime Claims boards, showing aggregate proof counts,
durable log paths, native/local event counts, native normalization counts, and
per-command missing/failed runtime events. The projection uses the same
native-first event merge as the Runtime Events panel: when MoonClaw is running,
Moondesk fetches native
`/v1/mooncode/sessions/<id>/runtime-events?book_root=<path>` proof, normalizes
the native response into canonical MoonCode events, merges accepted native
events with local append-log events by durable event id, and computes command
proof from that merged evidence set. This keeps MoonClaw-owned watcher/test/tool
proof visible in acceptance gates without making MoonWiki infer runtime state.

Each session also has a MoonBook-owned test/build manifest at:

```text
wiki/reviews/mooncode/<session-id>/test-runs.json
```

`GET /api/mooncode/sessions/<session-id>/test-runs` returns the latest
`mooncode-test-runs` object. It groups test-lane events into passed, failed,
running, and queued rows with command, path, exit code, detail, and verification
state. The MoonCode center pane renders this as the Test Runs board with Open,
Rerun, and Package controls. This remains a Moondesk-produced bridge object
until MoonClaw or standalone `mooncode` executes tests directly, streams
stdout/stderr, and writes native test-run evidence.

The desktop renders those fields as a Code Review queue before the lane grid.
Diff events become review candidates with file open, accept, reject, and package
controls. Row-level review commands preserve the diff file path in the
`context_path` command body and durable event record, so accepting or rejecting a
candidate is auditable against the targeted file. This is still file-level
review. The Patch Set panel adds hunk-addressable review commands, while true
patch promotion still belongs to the future MoonCode/MoonClaw runtime.

The command route accepts a small `mooncode.v1` action body:

```json
{
  "action": "run_tests | run_eval | package | commit | accept | reject | approve_tool | reject_tool | apply_patch | revert_patch | cancel | steer | prompt | note",
  "message": "optional operator text",
  "context_path": "wiki/index.md",
  "web_search": false
}
```

`run_tests`, `run_eval`, `package`, `commit`, `accept`, `reject`, `approve_tool`, `reject_tool`,
`apply_patch`, `revert_patch`, and `cancel` are first-class MoonCode review
controls. Today they are persisted as command events, including
the targeted `context_path` when a review row sends the command. MoonCode also
owns stable command packet ids and the stable fallback id for command events
that do not have a packet `command_id`; blocked or overridden preflight
attempts use MoonCode-owned projected event ids too. Every command event now
carries a normalized `command_packet`:

```json
{
  "protocol": "mooncode.v1",
  "kind": "mooncode.command",
  "command_id": "mooncode-command-...",
  "action": "run_tests",
  "dispatch": "command",
  "approval": "auto",
  "session_id": "agent-...",
  "workspace_id": "book-id",
  "task_id": "moonclaw-task-id",
  "context_path": "tools/demo/main.mbt",
  "message": "Run the relevant tests...",
  "expected_lanes": ["test", "tool", "runtime"],
  "tool_hints": ["moon_check", "shell"],
  "output_contract": {
    "owner": "moonbook",
    "roots": ["tools/", "apps/", "book/site/generated/", "portable/app-tool/"],
    "review_required": false
  }
}
```

Moondesk appends this packet to the durable ordered command queue:

```text
.moontown/mooncode-sessions/<session-id>/commands.jsonl
.moontown/mooncode-sessions/<session-id>/runtime-commands.jsonl
.moontown/mooncode-sessions/<session-id>/runtime-dispatches.jsonl
```

That queue is inspectable with:

```text
GET /api/mooncode/sessions/<session-id>/commands
GET /api/mooncode/sessions/<session-id>/session-store
GET /api/mooncode/sessions/<session-id>/runtime-commands
GET /api/mooncode/sessions/<session-id>/runtime-dispatch
GET /api/mooncode/sessions/<session-id>/runtime-events
POST /api/mooncode/sessions/<session-id>/runtime-events
GET /api/mooncode/sessions/<session-id>/runtime-claim
GET /api/mooncode/sessions/<session-id>/runtime-execution-plan
GET /api/mooncode/sessions/<session-id>/runtime-replay
POST /api/mooncode/sessions/<session-id>/runtime-claim
POST /api/mooncode/sessions/<session-id>/runtime-replay
GET /api/mooncode/sessions/<session-id>/preflight?action=<action>&context_path=<path>
GET /api/mooncode/sessions/<session-id>/action-plan
GET /api/mooncode/sessions/<session-id>/production-readiness
GET /api/mooncode/sessions/<session-id>/tool-authorization
POST /api/mooncode/sessions/<session-id>/tool-authorization
```

The response is a `mooncode-command-queue` object with `command_count`,
`command_log_path`, and replayed command packets in file order. This is the
current operator/audit queue. The runtime feed response is a
`mooncode-runtime-command-feed` object; each row includes an OpenSeek-compatible
`openseek_wire_command` (`prompt`, `steer`, or `cancel`) plus the full native
MoonCode command body and original command packet. Each native body and runtime
command row also includes a `mooncode-tool-authorization-snapshot` containing
the current tool-approval manifest path, approval counts, approval rows,
`enforcement_state`, and `runtime_may_execute`. MoonClaw or a standalone
`mooncode` runtime must enforce that snapshot and recheck
`/tool-authorization` before running gated tools. This is the current bridge
toward OpenSeek-style serve mode: Moondesk records user intent, MoonClaw or the
future extractable `mooncode` runtime owns execution.
Runtime evidence for those rows also computes a tool-harness verdict from the
same `tool_sequence`, so the UI can distinguish “command acknowledged” from
“expected tools actually ran and produced proof.”
The MoonCode center pane renders the same queue as an ordered Command Queue
panel with prompt/steer/cancel/review counts, latest command packets, target
paths, expected lanes, tool hints, authorization state, and quick
Test/Package/Commit controls. This makes operator intent visible without
opening `commands.jsonl` by hand.
The main MoonCode composer writes to this same typed command queue. With no
selected session it starts a durable coding session. With an idle selected
session it POSTs a `prompt` command carrying the user's text. With a running or
queued selected session it POSTs a `steer` command carrying the user's text,
matching OpenSeek serve mode's "Enter prompts when idle, steers while a turn is
open" interaction. The legacy `/api/agents/sessions/<id>/message` route remains
for non-MoonCode agent sessions only.
The action-plan response now includes a primary `recommended_command` plus a
`recommended_commands` array for multi-choice operator recovery, and a
`production_readiness` snapshot that reuses the full session production
readiness when available or falls back to action-plan state only for thin
callers. It
distinguishes UI runtime-loop actions from queued MoonCode commands, so the
Action Plan can offer `Run Native Loop`, `Retry Runtime`, `Refresh Proof`,
`Fix Tests`, `Run Tests`, `Package`, `Resume`, and `Start Next Turn`, and it
can expose paired choices such as `Accept`/`Reject` or
`Approve Tool`/`Reject Tool` without making Moondesk execute tools itself.
For runtime-backed next steps, the same recommendation array now also offers
`Start Service` beside the one-shot native loop action, routing the operator to
MoonClaw's daemon-owned MoonCode supervisor when they want Codex/OpenSeek-style
standing execution instead of a single bounded replay.
When steering has been deferred, `Start Next Turn` queues a typed `prompt`
command with a bounded continuation message, so MoonClaw or standalone MoonCode
can apply the saved steering in the next eligible turn.
It also renders a Dispatch Receipts panel from
`GET /api/mooncode/sessions/<session-id>/runtime-dispatch`, showing native
dispatch, legacy bridge dispatch, failed dispatch, pending command ids, and
runtime-replay acknowledgement safety (`ack_order_status`, prior claim/
consumer context, and any `order_blocker`) next to the command queue. This
makes daemon delivery and consumer acknowledgement order auditable in the
MoonCode workspace without opening `runtime-dispatches.jsonl` by hand.
The runtime command feed response also includes `command_lifecycle`, a
`mooncode-runtime-command-lifecycle` projection computed by the extractable
MoonCode protocol package from `runtime-commands.jsonl`,
`runtime-dispatches.jsonl`, command-scoped runtime events, decode validity,
tool-authorization snapshots, and lease expiry. The MoonCode center pane
renders it as a Lifecycle block inside Runtime Feed, with pending, running,
dispatched, completed, failed, blocked, next command, scoped event counts,
blocking reason, and next step. This gives Moondesk and MoonClaw a shared
operator/runtime view of queue progress without coupling status logic to the
desktop UI.
The `runtime-events` route is the engine-to-desktop event sink. Runtime workers
POST progress, native `tool_call`/`tool_started`, tool-result, diff, test,
artifact, finish, usage, and failure events there; Moondesk records them
append-only and uses the same normalized events to drive live stream output,
Tool Approvals, change/patch manifests, test-run proof, Action Plan gates, and
the MoonBook-owned runtime-evidence artifact. Events intended to prove a
specific command must include a `command_packet` or compact `command_id` plus
the matching `action`; unscoped transcript events still render, but do not
satisfy command-level runtime proof.
GET and POST responses also include `command_progress`, a
`mooncode-runtime-event-command-progress` projection grouped only from
command-scoped runtime events. Each row reports command id, action, status,
event counts, running/done/failed counts, tool-call/tool-result counts, lanes,
kinds, and latest event metadata. This gives Moondesk, MoonClaw, and future
standalone `mooncode` consumers a compact live progress object without
treating unscoped transcript noise as command proof.
The `runtime-replay` route is the native-consumer view of the same data. It
classifies every runtime command as delivered, claimed, pending,
expired-claim-pending-retry, failed-pending-retry, blocked-tool-authorization,
blocked-by-prior-command, or blocked-invalid, exposes the first pending index,
and provides `pending_openseek_jsonl` for an OpenSeek-style single-consumer
serve loop. It is read-only and never dispatches commands by itself. Runtime
consumers can call `GET /runtime-claim` to inspect claimable, claimed,
delivered, failed, invalid, tool-authorization-blocked, and order-blocked
command leases. A claimed command whose `lease_expires_at` is older than the
supplied `now` clock is claimable again; commands with failed dispatch receipts
are also claimable retry work and carry `previous_dispatch_failed: true` in the
claim projection. Commands whose `tool_authorization` snapshot has
`runtime_may_execute: false`, pending approvals, or rejected approvals are not
included in pending replay JSONL and are not claimable; they also block later
non-delivered commands until a later approving snapshot is recorded. Later
non-delivered commands behind an active claim, invalid earlier command, or
tool-authorization-blocked earlier command are reported as
`blocked-by-prior-command`, not claimable. Consumers should call
`POST /runtime-claim` before execution, then call
`POST /runtime-replay` with `runtime-acknowledged`, `runtime-completed`,
`failed`, or event payloads after handling the claimed command. Replay receipts
include `ack_order_status`; `matching-claim` proves the same consumer is
acknowledging the active lease, while `blocked-by-prior-command` includes an
`order_blocker` object for out-of-order acknowledgements. When acknowledgements
carry runtime `events`, replay items expose the latest receipt, event counts,
and `runtime_event_summary` so the Runtime Replay panel can distinguish
delivered-with-proof from delivered-without-proof commands.
The `preflight` route is the read-only command-gate projection. It returns the
same `mooncode-command-preflight` object used by command POST enforcement for a
requested action and selected `context_path`; `path` is accepted as an alias for
clients that already model selected files that way. The MoonCode center pane
fetches `run_tests`, `run_build`, `run_eval`, `package`, `commit`, `accept`,
and selected-path `apply_patch`/`revert_patch` gates and renders a Preflight
Gates panel before the transcript, so the operator sees proof-building commands
and current test, diff, patch-state, tool-approval, and package blockers before
clicking a review command.
The preflight object also carries command metadata from the shared MoonCode
command registry: `dispatch`, `approval`, `lane`, `title`, `tool_hints`,
`expected_lanes`, and `required_gates`. Moondesk renders those fields in the
Preflight Gates panel, and MoonClaw or a standalone `mooncode` client can use
the same data to explain why a command is ready, blocked, or routed to a
particular runtime lane.
Patch review state and patch execution state are deliberately separate:
operator `apply_patch` / `revert_patch` commands record intent and review
receipts, while MoonClaw or standalone `mooncode` must emit `patch_applied` or
`patch_reverted` runtime events after actually changing files. MoonClaw now
executes bounded reviewed text replacements plus single-file or multi-file
unified-diff patchsets, including target-path inference from diff headers.
Patch execution packets can request post-change verification through
`verification_command`, `test_command`, `verify_after`, or `moon_check_target`;
MoonClaw stores the verification command, status, capped output, and pass/fail
result under the patch proof metadata.
Moondesk
normalizes those events into `runtime.patch_applied` /
`runtime.patch_reverted` proof records and exposes the aggregate
`runtime_patch_execution_proof_count` in session readiness.
The `action-plan` route is the operator/runtime view. It combines the command
queue, dispatch receipts, event lanes, test-run evidence, package candidates,
and review state into one MoonBook-owned plan with a `next_required_action`.
For example, a delivered `run_tests` command remains `awaiting-proof` until
MoonClaw's native `test_result` event and the expected typed tool proof for
`read`, `moon_cmd`, `moon_check`, `shell`, and `finish` arrive; Moondesk
normalizes both `exit_code` and native MoonClaw `exit_status` for this proof.
An `accept` command is blocked while tests are failing, tool approvals are
pending, file diffs have not been tested, or the runtime has not proven its
expected package/finish tools.
Each row exposes `runtime_evidence_status` and proof counts so the UI can show
exactly which OpenSeek/MoonClaw events are still missing for that command.
`POST /api/mooncode/sessions/<session-id>/commands` enforces the same command
preflight before appending a command packet or dispatching to MoonClaw. Blocked
`accept`, `package`, and `commit` commands return `409 Conflict` while tests are failing,
tool approvals are pending, or pending diffs lack verified test/build evidence.
`commit` is also blocked for sessions with file diffs until the operator has
accepted reviewed changes. The operator command writes a MoonBook review
receipt; MoonClaw or standalone `mooncode` must perform the git operation and
emit a `commit_created` runtime proof event with the commit SHA before Moondesk
shows commit execution as complete.
Blocked `apply_patch` and `revert_patch` commands return `409 Conflict` when
no selected patch path exists, the target path is not a known MoonCode patch
candidate, `apply_patch` targets have not first been accepted, or
`revert_patch` targets have not first been applied. A blocked command is not
appended to `commands.jsonl`, but Moondesk does append a `preflight.blocked`
event to `events.jsonl`, returns the full preflight object in the 409 response,
and projects that blocked attempt into the Action Plan. This keeps operator
mistakes auditable without letting refused commands enter the runtime queue.
The UI's blocked-row **Try Anyway** control sends `force_preflight: true`.
Moondesk then appends a `preflight.override` audit event and continues with the
normal command/runtime-command append flow. The override does not prove the
result; the Action Plan marks it as `operator-override`, and the operator still
needs command-scoped runtime evidence before accepting or packaging output.

Moondesk also appends this packet to the durable event log and prefers sending
it to MoonClaw as a typed MoonCode command when the daemon's
`/v1/mooncode/capabilities` payload passes the MoonCode-owned compatibility
check. That check now requires the `mooncode-native-capability-surface.v1`
capability contract id, the current protocol, endpoint set, tool set, and a
matching nested `capability_surface` object, all owned beside the `mooncode.v1`
wire atoms through the package-level `mooncode/core` contract package and
compatibility wrappers in `internal/mooncode/protocol.mbt`. The readiness report
carries that expected surface as `expected_capability_surface`, records
MoonClaw's advertised surface as `daemon_capability_surface`, and reports
surface-specific mismatch fields before native dispatch is enabled. The nested
surface includes
`capability_surface_fingerprint`, a SHA-256 drift guard over the required
protocol, contract id, endpoint list, and tool list; a missing or mismatched
fingerprint blocks native dispatch even if top-level compatibility fields look
current. MoonClaw exposes the same required surface through its matching
`mooncode/core` package, while daemon-only optional endpoints remain local to
the daemon protocol wrapper. During the mirrored-package phase,
`scripts/verify-mooncode-core-sync.sh` must pass before treating the two repos as
compatible; it compares the core source files and normalizes only the generated
interface package name. `scripts/validate-core-boundaries.sh` is the broader
boundary smoke test: it runs the sync gate, Moondesk MoonCode/MoonWiki tests,
MoonClaw daemon tests, and lightweight MoonBook/Moontown contract checks. If
that native runtime endpoint or required contract surface is absent,
Moondesk falls back to the current
MoonClaw `/v1/task` bridge and includes the same packet in a bounded
book-scoped prompt. `cancel` follows the same
native-first path and falls back to the attached task cancel endpoint when
needed. The session summary exposes `dispatch_mode` so operators can
distinguish native runtime dispatch from bridge compatibility mode.

MoonClaw's native endpoint now treats `prompt`, `steer`, and `cancel` as
control commands instead of plain prose-only task messages. `prompt` and
general command packets bind or reuse the book-scoped task; native runtime-turn
checks the native serve-scheduler decision for the claimed command, settles
`steer` commands with `steer_applied`, `steer_deferred`, or `steer_dropped`
runtime evidence, and settles idle `cancel` commands with `cancel_dropped`
evidence while active task cancellation lands as command-scoped
`agent_aborted`. Both paths clear or classify pending cancel acknowledgements
in the session summary; live `cancel` still
targets an existing bound task and deliberately does not spawn a new task.
Native `accept` and `reject` commands now settle with compatible
MoonBook-owned review receipts under `wiki/reviews/mooncode/<session-id>/` and
review-lane `receipt.accept` / `receipt.reject` evidence, so accepted/rejected
review state can come from the runtime path as well as Moondesk's local review
controls. MoonClaw also
accepts native package-result proof at
`POST /v1/mooncode/sessions/<session-id>/package-result?book_root=<path>`, recording
`package_built` and `package_verified` evidence for a command-scoped executable
MoonBook artifact. Moondesk mirrors that contract at
`POST /api/mooncode/sessions/<session-id>/package-result`: it accepts direct
package proof or native sidecar-shaped `package_result` records, normalizes them
into local artifact-lane runtime events, refreshes review/evidence artifacts,
and forwards the original native request to MoonClaw when available. MoonWiki
does not build or verify packages; it records, projects, and forwards runtime
proof. The HTTP response wrapper is MoonCode-owned too:
`package_result_ingest_result_response` attaches native forwarding readiness,
endpoint, error, submitted count, accepted count, and the raw native forwarding
report while MoonWiki only supplies host paths, session state, and native state.
MoonClaw's native runtime-turn now also writes the first
MoonBook-owned package manifests and package index for generated tools and
miniapps under `portable/app-tool/mooncode/<session-id>/`, then appends
`package_built`/`package_verified` proof when the book-local verification shell
step succeeds. Its native stream now also normalizes bound MoonClaw task
events into MoonCode transcript, tool, review, and runtime lanes, so assistant
deltas, tool calls/results, cancel, and failure events can be consumed as
MoonCode proof without the legacy task-event adapter. MoonClaw now persists
book-local native MoonCode sidecars under
`.moonclaw/mooncode/sessions/<session-id>/`: `session.json`, `commands.jsonl`,
`events.jsonl`, and `package-results.jsonl`. MoonClaw also exposes
`POST /v1/mooncode/sessions/<session-id>/tool-exec?book_root=<path>` for the
native OpenSeek-style `read`, `edit`, `write`, `shell`, `moon_check`, and
`finish` tool contract. Those tool calls run inside the selected MoonBook root,
reject paths that escape it, and append command-scoped proof events to the
native event sidecar. Runtime-turn can also use an explicitly selected model for
bounded OpenSeek-style tool-call planning with tool-result feedback, recording
planner start/selection/failure events, `planner_steps`, step limits, native
`reasoning_delta` progress, optional assistant deltas, and pre-execution
`tool_call` events before matching `tool_result` evidence while falling back to
deterministic planning when the model is unavailable or produces no supported
calls. Runtime-loop now supervises repeated runtime-turns over the durable
command queue until idle, failure, cancel, or max-turns, and Moondesk prefers
that endpoint while falling back to runtime-turn for older daemons. This is the
first durable MoonClaw-owned session, tool, model-planning, and
queue-supervision store; the remaining MoonClaw-side gap is turning that store
into a production OpenSeek-style service with live steering/cancel UX,
diff-aware review, long-running resume UX, and broader model-backed coding
evals without relying on the daemon's in-memory binding.

The native MoonCode command body now carries an explicit runtime contract beside
the human text. `execution_plan` names the action, dispatch policy, target path,
tool sequence, expected events, required outputs, recommended test/package/commit
commands, package kind, review requirement, and path policy. `tool_contract`
states the bounded tool registry and approval boundary MoonClaw or standalone
MoonCode must enforce. The registry covers OpenSeek-compatible `read`, `edit`,
`write`, `shell`, `moon_ide`, `moon_cmd`, `moon_check`, and `finish`, plus
MoonCode's executable-output extensions `apply_patch`, `revert_patch`, and
`package_app_tool`.
`result_contract` names the
required evidence and the durable sinks for streamed runtime events and replay
acknowledgements. It also includes an ordered `execution_checklist` with claim,
tool, event, output, native-eval-report, and acknowledgement steps. This lets
`run_tests`, `package`, `commit`, patch, and review commands be consumed as
structured coding-agent work instead of prose-only prompts.

The extractable `internal/mooncode` package also provides runtime-consumer
helpers for the MoonClaw/standalone `mooncode` side of the boundary:
`runtime_consumer_tool_outcome`, `runtime_consumer_test_result_event`, and
`runtime_consumer_completion_ack` turn a claimed runtime command plus typed tool
outcomes into the `/runtime-replay` acknowledgement shape. The helper does not
execute tools inside Moondesk; it creates the same command-scoped event payload
MoonClaw must emit after it executes `read`, `moon_ide`, `moon_cmd`,
`moon_check`, `shell`, `package_app_tool`, `apply_patch`, `revert_patch`, and
`finish`. Missing expected tool outcomes become failed tool proof, so the
replay proof gate keeps the command retryable instead of marking it complete.
For package commands, `runtime_consumer_package_output_ack` builds the complete
package proof shape for executable MoonBook output: `read`, `moon_ide`,
`moon_cmd`, `moon_check`, `shell`, `package_app_tool`, and `finish` tool
outcomes plus `diff`, `test_result`, `artifact`, `package_manifest`,
`package_index`, and `package_verified` proof events. This is the reusable MoonClaw/standalone
`mooncode` contract for turning generated code into a tool, miniapp, generated
site, or app-tool package while Moondesk remains only the recorder/reviewer.
That proof can be posted to
`POST /api/mooncode/sessions/<id>/package-result`; Moondesk normalizes
`package_built`/`package_verified` proof into the runtime append log, refreshes
change/test/action/evidence/session artifacts, and best-effort forwards the
native request to
`POST /v1/mooncode/sessions/<id>/package-result?book_root=<path>`. The response
shape is produced by MoonCode, including `native_package_result_ready`,
`native_package_result_endpoint`, `native_package_result_error`,
`native_package_result_submitted_count`, and
`native_package_result_accepted_count`. MoonCode also owns the native
package-result forwarding report helpers for unavailable-daemon/runtime and
partial-rejection states; MoonWiki only adds `book_root` and performs the HTTP
post loop.

Each runtime command also persists a compact `execution_summary` derived from
that native body. The summary repeats only the operator/runtime essentials:
planned tool sequence, allowed tools, expected events, required outputs,
runtime checklist, recommended commands, package kind, review requirement, event
sink, replay acknowledgement sink, and path rule. The runtime feed exposes the
same summaries as `execution_summaries`. The MoonCode Runtime Feed, Dispatch
Receipts, and Runtime Claims panels render them so operators can see what
MoonClaw is expected to execute without opening raw JSON.

The MoonCode stream endpoint follows the same boundary rule. When MoonClaw
reports the native MoonCode runtime, Moondesk proxies
`/v1/mooncode/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<sequence>&wait_ms=<ms>&poll_ms=<ms>` and
returns MoonClaw's typed stream. The native stream is resumable by sequence and
supports bounded long-poll live tailing for newly persisted events; the current
Rabbita UI asks the Moondesk route for `timeout_ms=1000` and `poll_ms=100`,
which Moondesk forwards as MoonClaw `wait_ms`/`poll_ms` when the native runtime
is available. If that endpoint is not available, Moondesk falls back to its
local append-log projection from
`.moontown/mooncode-sessions/<session-id>/events.jsonl`; with `live=true`, it
performs a bounded wait before replaying the tail. Local projection records
include `stream_source: "moondesk-append-log-projection"` so the UI can show
whether the operator is looking at native runtime events or bridge replay. The
Rabbita live tail keeps a bounded, id-deduped recent buffer from successive
polls, so a quiet poll does not erase the operator's visible progress timeline.
The main MoonCode transcript now merges three ordered sources with the same
stable-id dedupe: projected session events, the live stream buffer, and the
runtime event sink. That keeps daemon service lifecycle events, tool proof,
diff/test/package evidence, and native streamed assistant/reasoning updates in
the primary Codex/OpenSeek-style conversation instead of hiding them only in
lower diagnostic panels.

Operator review ownership is also written into the selected MoonBook. For
`accept`, `reject`, `package`, and `commit`, Moondesk records a durable JSON receipt;
MoonClaw's native runtime-turn now writes the same shape for runtime-consumed
`accept` and `reject` commands:

```text
wiki/reviews/mooncode/<session-id>/<action>-<command-id>.json
```

The receipt is a `mooncode-review-receipt` with protocol `mooncode.v1`, the
book/session/task ids, target `context_path`, the typed command packet, and the
owner split:

```json
{
  "kind": "mooncode-review-receipt",
  "protocol": "mooncode.v1",
  "action": "accept",
  "receipt_path": "wiki/reviews/mooncode/agent-demo/accept-mooncode-command-demo.json",
  "owner": {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "artifact": "moonbook",
    "review": "moonbook",
    "extractable_component": "mooncode"
  }
}
```

After each MoonCode command, Moondesk also refreshes a session-level change-set
manifest:

```text
wiki/reviews/mooncode/<session-id>/change-set.json
```

That `mooncode-change-set` groups current diff, test, artifact, and review
events with the latest review receipt and package manifest. It is still
Moondesk's book-owned projection, not the final MoonClaw patch engine, but it
gives Bookkeeper and future `mooncode` extraction a durable object to review
instead of loose UI events.

The desktop reads that object through:

```text
GET /api/mooncode/sessions/<session-id>/change-set
```

The MoonCode center pane renders it as a Change Set panel between the review
queue and raw event lanes so the operator can inspect the exact durable
Bookkeeper object without opening JSON manually.

Moondesk also refreshes a file-focused patch-set manifest:

```text
wiki/reviews/mooncode/<session-id>/patch-set.json
```

That `mooncode-patch-set` is the current durable staging object for file and
hunk review. It groups diff-lane events by path, parses unified-diff hunk
headers when available, records stable hunk targets such as
`tools/demo/main.mbt#hunk-1`, stores per-hunk added/removed/context counts,
keeps operator `review_state` separate from runtime `execution_state`, and
tracks pending, accepted, rejected, applied, reverted, and runtime proof counts.
Each file and hunk row also carries a protocol-owned `gate_status`,
`next_action`, and `blocked_reason`, so Moondesk, MoonClaw, and a future
standalone `mooncode` component can agree whether the target needs operator
review, is ready for `apply_patch`, is waiting for runtime proof, should run
tests, or is blocked by rejection.
File-level review decisions project onto that file's hunks, while hunk-level
commands use the hunk target as `context_path`. It deliberately remains
MoonBook-owned and protocol-shaped rather than Moondesk-private UI state, so
MoonClaw or a future standalone `mooncode` runtime can own the real
apply/revert operation while Moondesk only renders proof and review state.
MoonClaw's native patch tool currently handles reviewed text replacements plus
single-file or multi-file unified-diff patchsets. It now accepts
`hunk_index`/`hunk_id` or `context_path`/`target` values such as
`tools/demo/main.mbt#hunk-1`, applies only that selected hunk, and emits
`runtime.patch_applied` / `runtime.patch_reverted` proof metadata with
`hunk_dispatch_scope`, `selected_hunk_index`, `available_hunk_count`, and the
underlying `file_path`.
The command preflight contract now returns a stable `selected_patch` object for
the requested `context_path`, including `matched`, `review_state`,
`execution_state`, `gate_status`, `next_action`, `blocked_reason`, and
`runtime_proven`. This lets package and commit gates block on the exact selected
file or hunk instead of relying only on broad session-level counts.

The desktop reads that object through:

```text
GET /api/mooncode/sessions/<session-id>/patch-set
```

The MoonCode center pane renders it as a Patch Set panel with Open, Accept,
Reject, Apply, Revert, and Package controls per file path plus per-hunk Accept,
Reject, Apply, and Revert controls. The panel also renders each target's gate
status and next action. Those controls enqueue MoonCode review commands;
Moondesk does not directly edit files. Runtime proof chips show whether
MoonClaw has posted `patch_applied` or `patch_reverted` evidence for the
selected file or hunk. This is closer to the Codex/OpenSeek review workflow than
the broader all-lane Change Set panel, but MoonClaw still owns the actual patch
engine.

The MoonCode stream also gets a `receipt.<action>` review event for that file.
These receipt events intentionally do not count as extra accept/reject decisions,
so the UI can distinguish "operator chose accept" from "MoonBook recorded the
receipt".

Moondesk also refreshes a MoonBook-owned tool approval manifest:

```text
wiki/reviews/mooncode/<session-id>/tool-approvals.json
```

That `mooncode-tool-approvals` object lists policy/review-gated tool work
detected from the current MoonCode event stream. File edits, writes, generated
artifacts, and shell-style commands become approval rows with tool id,
originating event id, `tool_call_id`, `command_id`, command action, approval
class (`review` or `policy`), approval state (`pending`, `approved`, or `rejected`), target path or command, and
approve/reject review counts.
When `tool_call_id` is present it is the primary target identity
(`tool_call:<id>`). Path and command remain display labels and legacy context,
but they no longer authorize every repeated tool call against the same file or
command. This mirrors Codex/OpenSeek tool approval semantics: approval belongs
to one concrete runtime tool call, not to a broad path string.

Moondesk exposes it through:

```text
GET /api/mooncode/sessions/<session-id>/tool-approvals
GET /api/mooncode/sessions/<session-id>/tool-authorization
POST /api/mooncode/sessions/<session-id>/tool-authorization
```

The MoonCode center pane renders it as a Tool Approvals panel with per-row
Open, Approve, and Reject controls. The controls send typed `approve_tool` or
`reject_tool` commands through the same `mooncode.v1` command queue. This is
still a Moondesk bridge manifest. MoonClaw or a standalone `mooncode` runtime
should call `POST /tool-authorization` before executing a tool. Moondesk records
new gated shell/write/edit/package previews as pending approval rows, refreshes
the same MoonBook review artifacts, and returns `allowed`, `requires_approval`,
or `blocked` with the matching approval row. MoonClaw remains responsible for
enforcing the decision before it executes the tool.
The Moondesk route handlers for this handshake are isolated from the generic
session router; they are an adapter over MoonCode's approval contract and
MoonBook-owned review artifacts, not a session-management responsibility.

The MoonCode UI also exposes this boundary as a Tool Authorization panel beside
Tool Approvals. It can explicitly probe representative `read`, `write`, and
`shell` tool calls for the selected session/path and render the current
decision, target, approval state, reason, and matching approval row. These
probes use the same `POST /tool-authorization` contract a MoonClaw runtime
consumer should call before execution; they are a desktop inspection/control
surface, not an execution engine.

For `package`, Moondesk also records a MoonBook-owned package candidate
manifest:

```text
portable/app-tool/mooncode/<session-id>/package-<command-id>.json
```

The manifest is a `mooncode-package-manifest` with protocol `mooncode.v1`,
package kind (`tool`, `miniapp`, `generated-site`, `app-tool`, or
`app-tool-candidate`), candidate paths, the review receipt path, the typed
command packet, source inventory, and the same owner split. The inventory
records each candidate path as ready, missing, or invalid; file candidates also
carry `size_bytes` and `sha256` so later bundle assembly can prove which source
was packaged. The manifest exposes `source_present_count` and
`source_inventory_status` (`source-bound` or `no-source-yet`) to distinguish a
real package candidate from an operator intent without source evidence.

Each package command also refreshes a session-level package registry:

```text
portable/app-tool/mooncode/<session-id>/index.json
```

The registry is a `mooncode-package-index` with the package count,
source-bound/missing-source counts, executable-ready count, package kinds,
ready entry points, the latest package manifest, and the full package manifest
list. Per-command manifests remain audit records; `index.json` is the stable
MoonBook handoff for MoonClaw or a future standalone `mooncode` component to
resume bundle assembly and final packaging.

The MoonCode stream gets `package.manifest`, `package.index`,
`runtime.package_built`, and `runtime.package_verified` artifact events, and
`mooncode_summary` exposes package manifest/index gates, runtime package proof
counts, and a header-level `package_lifecycle` object. Source-bound package
candidates show that package inputs exist; runtime package proof shows that
MoonClaw or standalone `mooncode` actually assembled and checked a bundle.
Moondesk ingests MoonClaw `package_events` returned by native
runtime-turn/runtime-loop calls, so package verification proof is visible
immediately after `Run Native Loop` without waiting for a separate stream poll.
The package lifecycle projection reports package/source-bound/missing-source,
executable-ready, runtime-built, and runtime-verified counts plus recent
candidate rows and the next packaging action.

Those candidates are inspectable through:

```text
GET /api/mooncode/sessions/<session-id>/package-candidates
```

The response is a `mooncode-package-candidates` projection over saved MoonBook
package manifests under `portable/app-tool/mooncode/<session-id>/`, with
package count, source-bound count, missing-source count, candidate paths,
manifest paths, receipt paths, source inventory records, promoted-source paths,
package-index status, package-index path, executable-ready count, ready entry points, runtime
built/verified counts, and per-candidate `execution_state`. The MoonCode center
pane renders this as a Package Candidates panel between Test Runs and Patch Set,
with Open, Test, Accept, and Package controls. This keeps executable artifact
readiness visible while preserving the boundary: Moondesk renders and routes
operator intent; MoonBook owns the manifests and index; MoonClaw or standalone
`mooncode` must create verified bundles and emit package proof.

This projection is a contract marker and UI bridge, not the final execution
engine. Current execution still flows through MoonClaw daemon-backed
`/api/agents/*` routes; the lane shape is meant to move behind a standalone
`mooncode` runtime later.

Each session also exposes current eval evidence as:

```text
GET /api/mooncode/sessions/<session-id>/eval-report
POST /api/mooncode/sessions/<session-id>/eval-report
```

The response is a `mooncode-eval-report` object derived from session summary
and event evidence. After each command Moondesk also persists the same report as
a MoonBook-owned review artifact:

```text
wiki/reviews/mooncode/<session-id>/eval-report.json
```

When MoonClaw exposes a native MoonCode runtime, Moondesk first probes:

```text
/v1/mooncode/sessions/<session-id>/eval-report?book_root=<path>
```

and attaches that response as `native_eval_report`. Native reports are
normalized by the `internal/mooncode` contract with `ok`,
`source: "moonclaw-native-runtime"`, `endpoint`, and native harness summary
fields. Moondesk only
performs daemon probing, persistence, and response serving. If the daemon or
endpoint is unavailable, the report remains a Moondesk bridge-evidence
fallback.

MoonClaw's current native eval endpoint already runs a first deterministic
tool/file-edit harness for `read`, `write`, `edit`, `shell`, `moon_ide`,
`moon_cmd`, `moon_check`, and `finish`, and the shared eval contract now also
requires `patch_review`, `command_execution`, and `package_output` harness
proof before native eval can be treated as production-ready. Runtime-turn now has an opt-in bounded model/tool feedback planner
that emits reasoning/assistant/tool-call/tool-result event evidence, and
runtime-loop can drain the durable queue until idle/failure/cancel/limits; the
remaining runtime work is production-grade live steering and broader
model-backed coding eval cases.
MoonClaw or a future standalone `mooncode/eval` runner can also submit the same
native proof directly with `POST /api/mooncode/sessions/<session-id>/eval-report`.
The main MoonCode toolbar, selected-session header, side command card, and Eval
Report panel all expose a typed `run_eval` command that enters the same ordered
`mooncode.v1` command/runtime queue. Its execution plan asks MoonClaw or
standalone `mooncode` to run the OpenSeek-style `tool_harness`, `file_edit`,
`patch_review`, `command_execution`, and `package_output` harnesses and then
publish native eval proof through the native eval endpoint or Moondesk ingest
endpoint.
The shared MoonCode contract normalizes the payload; Moondesk stores it on the
durable session, refreshes
the resumable session snapshot under
`.moontown/mooncode-sessions/<session-id>/session.json`, refreshes the runtime
handoff at `wiki/reviews/mooncode/<session-id>/runtime-handoff.json`, refreshes
`wiki/reviews/mooncode/<session-id>/eval-report.json`, appends the generated
eval-report manifest event to
`.moontown/mooncode-sessions/<session-id>/events.jsonl`, and returns the
updated projection. This is only an evidence-ingress and persistence boundary;
Moondesk still does not run the eval harness or execute MoonCode tools.

The report records bridge score, bridge level, passed and missing readiness
checks, required native harnesses (`tool_harness`, `file_edit`,
`patch_review`, `command_execution`, and `package_output`), missing required
native harnesses, minimum native evidence, native eval source/endpoint, the current gap, `manifest_path`,
`absolute_manifest_path`, and `recorded_at`. This deliberately distinguishes
Moondesk bridge evidence from MoonClaw-native eval proof while still giving
Bookkeeper and future standalone `mooncode` a durable review object. The
MoonCode center pane renders it as an Eval Report panel after the Command
Queue, so operators can see which Codex/OpenSeek-style behaviors are currently
proven and which still require MoonClaw or standalone `mooncode` runtime
evidence.

The session summary also carries a separate product-grade score:
`production_score`, `production_level`, `production_passed_check_count`,
`production_check_count`, `production_readiness`, and `production_checks`. This
score maps directly to the end-to-end MoonCode workspace criteria: selected
MoonBook, MoonClaw attachment, durable session, explicit `resume_lifecycle`
health, launch-ready runtime supervisor handoff, complete native eval proof,
chat transcript, typed command queue, live runtime stream, tool execution,
diff review, test/build proof, review receipts, package result, verified
`package_lifecycle`, the current action-plan manifest, clear live blockers, and
extractable MoonCode boundary.
`production_readiness` is the compact contract
for UI/runtime consumers: it reports readiness, score, first blocker, next
action, next owner, and blocking check ids so Moondesk, MoonClaw, or a future
standalone `mooncode` component do not have to reconstruct the next step from
the raw checklist. A session with historical proof but an action plan that still
reports blocked actions, unresolved diffs, pending tool approvals, pending
steering, or failing tests cannot score as `production-grade`; neither can a
session whose resume lifecycle is missing or blocked, or whose package lifecycle
lacks executable-ready verified package proof, or whose runtime handoff does not
embed a launch-ready supervisor with the `check-production-readiness` loop step,
or whose saved eval report lacks the complete native harness set
(`tool_harness`, `file_edit`, `patch_review`, `command_execution`, and
`package_output`).
It is intentionally separate from
`eval_score`: eval score measures bridge/native harness evidence, while
production score measures whether the selected session proves the user-facing
MoonCode product workflow. The static rubric is also available at
`GET /api/mooncode/production-rubric`, so production-grade claims can be audited
without a selected session. For a selected session, use
`GET /api/mooncode/sessions/<session-id>/production-readiness` to retrieve the
same score and checklist as a compact audit payload.

## Completion Criteria

MoonCode is production-complete when a user can:

1. Select a MoonBook.
2. Switch from MoonWiki to MoonCode.
3. Start or resume a durable coding session.
4. Chat with MoonClaw through a Codex/OpenSeek-style interface.
5. Generate or modify executable book code.
6. See streamed reasoning, progress, tool calls, and results.
7. Review file diffs and generated artifacts.
8. Run tests/builds from the UI.
9. Accept, reject, or package the result as a MoonBook tool, miniapp,
   generated site, or app-tool book.
10. Resume from a typed `session.json` store plus command/event logs.
11. Extract the MoonCode runtime/protocol into a standalone component without
    breaking MoonWiki or Moondesk.
