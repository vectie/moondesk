# MoonCode Canonical Conversation Architecture

## Decision

MoonCode is a chat product first. The user-facing conversation is an
append-only list of turns:

1. user message
2. optional folded progress
3. assistant reply or error

Raw MoonClaw events, command queues, receipts, runtime service lifecycle
records, proof manifests, and stream checkpoints are diagnostic evidence. They
must not be rendered as the chat transcript.

This is a fresh-default design. We do not preserve old transcript behavior as a
compatibility target.

The phase-by-phase clean rebuild plan is tracked in
[`MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md`](MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md).

## Target Shape

MoonCode's stable behavior comes from one append path:

- the UI appends the user input immediately
- the agent/run appends progress and final output through one callback
- stale async events are fenced by run identity
- the renderer appends semantic transcript items instead of rebuilding order
  from multiple logs

The backend owns durable canonical turns and Moondesk renders those turns.

```json
{
  "contract_id": "moonsuite-conversation.v1",
  "kind": "mooncode-conversation",
  "protocol": "mooncode.v1",
  "session_id": "mooncode-...",
  "turns": [
    {
      "kind": "mooncode-conversation-turn",
      "turn_id": "turn-...",
      "client_turn_id": "client-turn-...",
      "command_id": "command-...",
      "status": "queued|running|done|failed",
      "user": {
        "role": "user",
        "content": "user prompt",
        "status": "queued|done"
      },
      "progress": [
        {
          "role": "progress",
          "title": "Reading the workspace",
          "content": "Short human-facing progress",
          "status": "running|done|failed"
        }
      ],
      "assistant": {
        "role": "assistant",
        "content": "assistant answer",
        "status": "running|done|failed"
      },
      "items": []
    }
  ]
}
```

## Ownership Rules

- Backend owns durable conversation turns.
- UI owns only local optimistic turns that have not been acknowledged yet.
- MoonClaw emits runtime events, but every user-facing event must be normalized
  behind a `turn_id` or `command_id` before it reaches the chat list.
- Runtime service lifecycle events update service state only.
- Stream and runtime-event endpoints remain available for diagnostics only.
- The chat renderer consumes `ConversationTurn[]` plus unacknowledged local
  optimistic turns. It never merges raw events, pending prompt state machines,
  local rows, and session transcript rows at the same time.

## Anti-Patterns To Delete

- content-based ownership checks for user/assistant pairing
- pending prompt state machines or splitting around arbitrary event counts
- grouped-prefix repair for misplaced user messages
- recovered failed-assistant cleanup in the main chat path
- rendering unscoped runtime/service events as normal chat rows
- UI-triggered fake "working" state before a backend turn/runtime signal exists
- multiple independent transcript owners in the frontend model

## Phase 1 - Canonical Backend Projection

Status: complete.

Work:

- Build `mooncode_conversation` from session events.
- Group events by `command_id` or `command_packet.command_id`.
- Drop runtime service lifecycle events from the user transcript.
- Normalize user prompts, progress, assistant deltas, final assistant messages,
  and terminal failures into ordered turns.
- Attach the projection to session responses.

Exit tests:

- first user turn projects as user -> progress -> assistant
- two user turns preserve append order
- service lifecycle events do not create transcript rows
- assistant deltas collapse into the assistant message

## Phase 2 - UI Canonical Read Path

Status: complete.

Work:

- Decode `mooncode_conversation` in `MoonCodeSession`.
- Render backend canonical turns first.
- Merge local optimistic user rows only when the backend has not yet
  acknowledged them.
- Stop using raw stream and runtime diagnostic events as primary chat input.
- Remove the old raw-event renderer instead of keeping a compatibility fallback.

Exit tests:

- backend canonical turns win over local repair logic
- local first prompt appears immediately when backend has not returned a turn
- stream refresh cannot move a second prompt above the first turn
- diagnostic refresh cannot duplicate a backend conversation turn

## Phase 3 - Send API Turn Creation

Status: complete for the frontend contract.

Work:

- Every send creates a `client_turn_id` before network work starts.
- Create-session send and existing-session send both post `client_turn_id`.
- Backend returns `client_turn_id`, `turn_id`, `mooncode_turn`, and
  `mooncode_conversation` in the immediate command response.
- UI stores the same id on the single optimistic row for that submit.
- UI drops acknowledged optimistic rows only when the backend canonical
  conversation contains the same `client_turn_id`.
- `client_turn_id` generation uses a single monotonic submit counter, not
  parallel array lengths.
- Raw runtime or stream events never acknowledge, clear, or reorder local
  optimistic turns.

Exit tests:

- pressing Enter appends exactly one local turn immediately
- create-session send and existing-session send share the same turn contract
- retries do not duplicate the user row
- acknowledged backend turn replaces, not reorders, local optimistic turn
- same-content prompts get distinct `client_turn_id` values

## Phase 4 - Runtime Ownership

Status: superseded by Phase 21's explicit runtime-service boundary.

Work:

- Earlier work made backend command enqueue start or resume MoonClaw runtime
  server-side.
- UI no longer decides runtime startup from pending prompts or sink snapshots.
- "Working" appears only from canonical turn status or attached progress.
- Duplicate runtime-service starts are rejected/fenced server-side.
- Runtime startup has an explicit command producer for
  `/api/mooncode/sessions/:id/runtime-service`.
- Runtime sink snapshots update factual event/service status only.

Implemented:

- Phase 21 removes the old post-enqueue runtime-start helper from command
  submit responses.
- Submit routes append commands and return canonical acknowledgement.
- The UI explicitly calls `/runtime-service` after acknowledgement; failures
  from that call are runtime-service failures, not submit failures.

Exit tests:

- a queued turn is acknowledged once
- no fake progress appears when runtime is unreachable
- runtime-service failure is surfaced from the runtime-service request
- second turn does not reuse stale runtime state from the first turn

## Phase 5 - Event Identity Contract

Status: complete for backend conversation projection.

Work:

- MoonClaw must echo `turn_id` or `command_id` on every user-facing event.
- Backend buffers scoped events until the matching user turn exists.
- Unscoped events before any turn are diagnostics only.
- UI ignores stale session/run updates by identity, not by content equality.

Implemented:

- Scoped events are buffered until the matching user turn exists.
- Unscoped progress and assistant events do not attach to the latest turn.
- Unscoped terminal runtime failures can still fail the active queued/running
  turn.

Exit tests:

- scoped progress emitted before user acknowledgment still lands under that user
- unscoped progress before any user is hidden from chat
- unscoped progress/assistant after a user is hidden from chat
- stale events from a previous selected session cannot mutate visible chat
- same-content prompts are represented as distinct turns

## Phase 6 - Delete Stale Frontend Implementation

Status: complete for the main Moondesk MoonCode frontend path; expanded by the
clean rebuild phase to remove the old pending-prompt model entirely.

Work:

- Delete grouped user prefix repair.
- Delete recovered failed assistant cleanup from the main chat path.
- Delete pending prompt event splitting from the main chat path.
- Delete content-based assistant/user dedupe from the main chat path.
- Delete transcript rendering from `session.transcript` in the main chat path.
- Move raw log visualization to a diagnostics/details surface.
- Deleted the browser-side raw-event transcript renderer, raw event activity
  converter, grouped user repair, recovered assistant cleanup, pending prompt
  event splitting, and content-based duplicate suppression.
- Deleted `mooncode_pending_prompts`; local optimistic turns are now the only
  frontend-owned in-flight chat state.
- Deleted decoded legacy `session.transcript` and `session.mooncode_events`
  fields from the frontend session model.
- Added explicit new-chat draft route state, so display status text no longer
  decides session selection.
- Renamed UI-owned in-flight rows to `MoonCodeOptimisticRow` /
  `mooncode_optimistic_rows`, leaving `mooncode_conversation` as the only
  durable backend conversation name in the frontend model.
- Compact session polling preserves `mooncode_conversation`, so old replies do
  not disappear when a lightweight session listing arrives.
- Runtime stream diagnostics remain in the model as status payloads only.

Exit tests:

- `mooncode_transcript_items` is a small projection from canonical turns
- no main chat code reads raw runtime diagnostic events
- no main chat code reads stream events
- no main chat code compares message content to determine ownership
- same-content prompts with different `client_turn_id` values remain distinct
  turns
- compact listings without canonical conversation cannot steal a new-chat draft
- raw runtime prompt events cannot acknowledge an optimistic turn

Validation in this slice:

- `moon check --target js`
- `moon test --target js`

## Phase 7 - End-To-End Chat Tests

Status: complete for the MoonCode API/browser gate.

Backend:

- new chat first reply
- two sequential replies
- third sequential reply
- assistant delta then final answer
- progress before answer
- runtime unavailable error attached only from runtime/event ingestion
- refresh/replay reproduces the same turn order

Current backend coverage:

- three sequential turns preserve append order and replay deterministically
- scoped progress emitted before the prompt is buffered under the matching turn
- unscoped progress before any prompt is hidden from chat
- assistant delta collapses into the final assistant reply
- failed runtime/command events attach a failed assistant message to the active
  turn

UI:

- new chat shows the prompt immediately
- first progress appears between user and assistant
- second and third prompts append at the bottom
- old turns never disappear during poll, stream, or diagnostic refresh
- collapsed progress remains attached to its turn

Current UI coverage:

- canonical progress remains folded between the user message and assistant reply
- three backend turns render in order before a fourth local optimistic prompt
- same-content prompts with different `client_turn_id` values stay distinct
- folded progress summaries hide internal MoonClaw/runtime/tool-call wording
- browser smoke sends first, second, and third prompts, verifies API canonical
  order after each send, hard refreshes, and verifies the same order again
- immediate command responses and session polling both return frontend-decodable
  canonical conversation DTOs

Browser smoke:

- fresh app, new chat, send first prompt
- send second message
- send third message
- API check: exactly one MoonCode session owns the same three canonical turns
- hard refresh
- verify the same three turns remain in UI and API order

## Phase 8 - Legacy Durable Transcript Deletion

Status: complete.

Work:

- Delete the MoonCode-specific `append_transcript_message` wrapper.
- Stop new prompt creation from writing a parallel `session.transcript` row.
- Stop runtime supervisor responses from writing status transcript rows.
- Remove the backend fallback that projected `session.transcript` into
  `mooncode_events`.
- Remove compact-listing `transcript` / `mooncode_events` compatibility arrays.
- Remove transcript arrays and transcript counts from MoonCode session
  snapshots.

Current coverage:

- prompt creation returns a canonical conversation turn without a legacy
  transcript row
- legacy transcript-only session records produce no projected chat events
- response defaults do not inject `transcript: []`
- session listings choose titles from first prompt, last message, title, or id

## Phase 9 - Shared Product Contract

Status: complete for the shared contract rollout.

Work:

- Move stable conversation DTOs into MoonLib.
- Keep MoonCode-specific event normalization in MoonCode.
- Keep MoonStat focused on analytics and health metrics, not chat ownership.
- Publish the contract for MoonClaw, MoonCode, Moondesk, MoonRobo, MoonMoon,
  MoonFish, MoonTown, and future MoonSuite products.

Current coverage:

- MoonLib `0.1.8` exposes `vectie/moonlib/conversation`.
- The shared contract owns role order, required turn fields, identity fields,
  diagnostics rules, and the contract JSON envelope.
- Moondesk imports MoonLib `0.1.8`.
- `mooncode/core` delegates shared conversation contract data to MoonLib while
  keeping MoonCode-specific protocol/owner names local.
- `scripts/validate_conversation_contract_rollout.sh` now guards the source
  boundary across MoonLib, Moondesk, MoonRobo, MoonTown, MoonClaw, MoonStat,
  MoonBook, MoonFish, MoonMoon, MoonChat, MoonVis, and Lepusa.
- `scripts/phase9_cutover_gates.sh full` now runs the shared-contract guard
  after the full migration wall, API smoke, browser smoke, and cross-product
  fresh-suite product smoke.

Exit tests:

- all products consume the same turn/message/progress schema
- product-specific diagnostics stay outside the chat contract
- schema tests reject missing turn identity for user-facing events

## Phase 10 - Ordinary Chat Composer Cutover

Status: complete for the ordinary chat composer path.

Work:

- Ordinary chat input always creates a new `prompt` turn.
- Runtime-service status does not decide whether the next visible chat message
  is a `steer`.
- Explicit steering remains available through runtime/API controls where the
  caller intentionally asks for steering.

Current coverage:

- The composer command path posts `prompt` for ordinary text.
- The composer button remains `Prompt` for existing sessions and `Start` for a
  new session.
- Stale runtime status no longer changes the user's chat message into a
  steering command.
- Validation passed with Rabbita main tests (`147/147`), MoonCode core tests
  (`4/4`), internal MoonCode tests (`265/265`), internal MoonWiki tests
  (`144/144`), `npm run build`, and the full Desk browser smoke.

Exit tests:

- first, second, and third visible composer sends all append as prompt turns
- stale runtime status cannot rewrite a chat turn into steering
- explicit steering API/runtime tests still cover steer behavior outside the
  ordinary chat composer

## Phase 11 - Backend-Owned Runtime Start

Status: complete for the command enqueue path.

Work:

- New-session and existing-session prompt sends enqueue the command, persist the
  canonical command event, and then ask the backend to start/resume MoonClaw.
- Runtime-service status is diagnostic state, not a composer action switch.
- Runtime startup is explicit through `/runtime-service`, not hidden inside
  submit acknowledgement.
- Runtime-unavailable failures are persisted only when runtime/event ingestion
  produces real command-owned failure evidence.

Current coverage:

- first, second, and third ordinary sends share the same backend enqueue path
- submit acknowledgement stays queued until runtime/event evidence advances it
- duplicate runtime-service starts are fenced by the backend lease

## Phase 12 - Canonical Native Event Ingestion

Status: complete for the Moondesk backend projection path.

Work:

- Import MoonClaw native sidecar/runtime evidence into Moondesk's append log
  before projection.
- Read session listing, event, stream, stream-state, preflight, and command
  responses from Moondesk's canonical log.
- Strip response-only projection DTOs from persisted session records.
- Remove direct sidecar-as-transcript projection.

Current coverage:

- sidecar events do not affect chat before import
- repeated sync does not duplicate imported events
- projection reads from the durable Moondesk event log
- persisted records do not cache `mooncode_events`, `mooncode_summary`, or
  `mooncode_conversation`

## Phase 13 - Native Reply Ownership Gate

Status: complete for deterministic backend/API coverage.

Work:

- Preserve native `command_id` as a normalized `command_packet` for transcript,
  reasoning, runtime-update, and terminal error events.
- Let a command-scoped final assistant answer complete its turn even when an
  earlier infrastructure failure was recorded before native evidence arrived.
- Prove first, second, and third raw native sidecar assistant replies import
  through the canonical append log and replay in order.

Current coverage:

- native transcript events keep command ownership during normalization
- final native answers recover stale runtime-unavailable failures on the same
  command turn
- the three-turn HTTP E2E test imports raw sidecar replies and verifies ordered
  canonical assistant messages through session listing, events, and stream
  reads

## Phase 14 - Browser Native Reply Smoke

Status: complete for the automated browser smoke path.

Work:

- Drive the real MoonCode composer in a headless browser for first, second, and
  third prompts.
- Use the backend session projection to discover canonical command ids.
- Append raw MoonClaw sidecar `assistant_message` events for each command id.
- Wait for backend canonical session refresh to import those replies.
- Wait for the visible chat surface to render the replies under the matching
  user turns, without stale runtime-unavailable failure copy or internal
  runtime bookkeeping.
- Hard refresh and verify the same native reply order replays from durable
  state.

Current coverage:

- `scripts/desk_mode_browser_smoke.mjs` now turns the native sidecar reply
  import into a user-visible browser gate.
- The smoke proves visible prompt order, backend native reply import, UI native
  reply rendering, and hard-refresh replay.

## Phase 15 - Frontend Runtime Sink Removal

Status: complete for the MoonCode browser model.

Work:

- Delete browser-side runtime-event sink polling and state.
- Keep the backend runtime-events endpoint as an explicit diagnostic/ingest
  surface, not a hidden frontend conversation source.
- Keep stream polling for cursors/checkpoints and canonical session refresh for
  chat ownership.
- Preserve tests proving raw stream events cannot acknowledge optimistic rows.

Current coverage:

- The frontend no longer has `LoadedMoonCodeRuntimeEventSink`,
  `MoonCodeRuntimeEventSink`, legacy runtime-sink model fields, or a
  runtime-sink fetch command.
- `PollMoonCodeSessions`, session selection, and session mutation success do
  not fetch runtime-event sink snapshots.
- Stream diagnostics remain separate from chat ownership.

## Phase 16 - Native Runtime Contract Report

Status: complete for the backend normalization boundary.

Work:

- Classify accepted MoonClaw native runtime events after Moondesk normalization.
- Require chat/progress eligible native events to be command-scoped before they
  can be considered projection-safe.
- Keep service lifecycle, watcher, usage, and runtime-loop records diagnostic.
- Expose the contract on the existing runtime-events diagnostic response,
  without adding another browser transcript owner.

Current coverage:

- `mooncode-native-runtime-contract-report` marks command-scoped reasoning and
  assistant events projection-safe.
- Unscoped watcher updates are diagnostic-only.
- Unscoped assistant answers are flagged unsafe before they can masquerade as
  canonical chat evidence.
- Runtime-events responses expose contract status and unsafe unscoped counts.

## Current Direction

Phase 17 cuts normal Moondesk synchronization over to the native MoonClaw
runtime-events API. Direct product-home JSONL reads are no longer part of the
regular app path; they are replaced by a daemon-owned `/v1/code/*` contract.

Current coverage:

- normal session/list/event/stream/command handlers sync through
  `sync_mooncode_native_runtime_events`
- only command-scoped or diagnostic-only native events are persisted into the
  canonical append log
- unsafe unscoped transcript/progress records stay in the diagnostic
  runtime-events report and cannot become durable chat
- deterministic browser testing posts runtime evidence through Moondesk's public
  runtime-events route
- the live smoke starts MoonClaw, posts native runtime evidence through
  MoonClaw's endpoint, and verifies the Moondesk projection contract

Phase 18 turns explicit tool-call execution into a deterministic native runtime
gate. `runtime_tool_calls` now belongs to the durable command packet and the
native MoonClaw command body, so Moondesk can ask MoonClaw to execute concrete
work without relying on fallback prompt interpretation before the first
assistant reply appears. The canonical conversation projection also treats a
command-scoped native `finish` tool call with an `answer` as the assistant
reply, then uses the generic finish result only to close the turn.

Phase 19 adds the live multiturn service gate. It runs first, second, and third
prompt turns through one Moondesk session and one real MoonClaw service path,
then proves the canonical conversation remains append-only with distinct
command ids and stable replies after each turn.

Phase 20 removes the frontend copy-forward fallback for compact session rows.
Normal `/api/mooncode/sessions` now owns full canonical session state, while
compact rows remain an explicit `format=listing` API shape. The browser no
longer patches a newer backend response with stale local
`mooncode_conversation` data.

Phase 21 removes the post-enqueue runtime-start helper from submit responses.
Create/send routes now append and acknowledge canonical command state only; the
MoonCode UI starts MoonClaw through the explicit `/runtime-service` endpoint
after acknowledgement. A live runtime-control smoke proves prompt, steer, and
cancel stay in append-only command order and project to `start-turn`,
`queue-steer`, and `withdraw-pending` before runtime starts.

Phase 22 removes the remaining stale runtime-start failure shape. If the
explicit `/runtime-service` boundary cannot reach MoonClaw, the backend now
records one command-scoped `runtime_unavailable` event in `events.jsonl` and
marks the session failed for ordering/status. The HTTP request still fails, but
the chat transcript no longer depends on composer-only error text; the failed
assistant reply is projected from the same append-only event log as native
MoonClaw replies. A live failure smoke proves the first prompt remains queued on
submit, the runtime-service call returns an error, and the next session fetch
shows the same command id as a failed turn.

Phase 23 makes runtime-service recovery event-backed. Moondesk still uses a
local `runtime-service.lease.json` file to single-flight duplicate starts, but
that lease is now released by terminal runtime evidence instead of only by a
timeout. Startup failures release it when `runtime_unavailable` is recorded, and
native sync or runtime-event ingest releases it when MoonClaw writes
`runtime.service_finished` or `runtime.service_failed`. The live runtime-loop
smoke now proves a same-command-count service restart can happen immediately
after the native finish event is imported.

Phase 24 removes control commands from the user/assistant transcript. Ordinary
chat turns are now prompt-owned only; explicit `steer` and `cancel` remain
durable control evidence surfaced by runtime-control and steering lifecycle
projections. The runtime-control contract now names the native scheduler
boundary: controls settle when MoonClaw reaches a runtime boundary or emits real
abort evidence, not when Moondesk fabricates a chat row. The live
control-boundary smoke proves prompt -> deferred steer -> prompt -> dropped
cancel leaves only the two prompt turns in `mooncode_conversation`.

Phase 25 removes the remaining catch-all progress projection. Durable runtime
events are still stored and available through diagnostics, but
`mooncode_conversation` now accepts only an explicit user-visible progress
allowlist: turn start, reasoning, tool call/result, test, diff, and artifact
evidence that is command-scoped. Generic runtime updates, runtime bookkeeping,
debug detail, raw tool JSON, and model planner internals no longer enter chat
just because they have a title/detail. The backend projection normalizes
allowed progress into human wording before the UI folds it between the owning
user prompt and assistant reply.

Phase 26 adds the model-planner evidence contract. Model-planned prompt, steer,
and package commands are now recognized as commands with a selected model and
no explicit `runtime_tool_calls`. The backend reports whether each command is
pending, service-started, running with planner evidence, planner-failed,
satisfied, or contract-failed. The key clean-architecture rule is now explicit:
queued commands are not working, and a started native turn without planner
evidence is a MoonClaw/runtime contract failure rather than a browser thinking
state.

Phase 27 adds explicit turn ownership and abort settlement. Visible
conversation rows now carry the owning command/turn/client/runtime/run ids, and
the conversation projection publishes an ownership report. Unscoped
progress/assistant/failure/abort-shaped runtime events stay diagnostic and can
no longer attach themselves to the latest active turn. A command-scoped
`runtime_aborted` can close its owning prompt turn as cancelled, while
cancel-scoped abort evidence remains folded in cancel lifecycle state instead
of becoming chat.

The next scheduled phases are now explicit:

- Phase 28: package and review model flow gate. Package/review decisions now
  have a command-scoped deterministic fixture gate for accepted, rejected,
  failed, and stale runs; live model coverage remains a scheduled gate layered
  above that contract.
- Phase 29: browser conversation stability gate. First/second/third turns must
  append immediately, preserve old turns, keep owner-tagged progress under the
  owning turn, fold completed progress, and survive reload without flashes or
  reordering. The deterministic browser gate uses `mooncodeRuntime=manual` to
  disable only UI runtime auto-start and then injects event-backed native
  replies through public APIs; ordinary MoonCode sessions keep automatic
  MoonClaw runtime startup.
- Phase 30: no frontend conversation repair. Normal
  `/api/mooncode/sessions` responses are authoritative for any session they
  include. The browser may keep local optimistic rows and may preserve an
  absent selected in-flight session during a real list race, but it must not
  copy an older cached `mooncode_conversation` over a present backend response
  with fewer turns or source events. Backend regressions should be caught by
  gates, not hidden by browser state.
- Phase 31: frontend route ownership. The Rabbita MoonCode command path first
  moved desktop `/api/mooncode` URL construction out of individual command
  handlers. Phase 39 supersedes the Rabbita-local helper with public
  `vectie/moondesk/core` route formatting while keeping the migration wall
  rejection for raw active frontend MoonCode API route strings.
- Phase 32: frontend session effect ownership. The Rabbita MoonCode reducer
  path now routes prompt-submit followups, mutation acknowledgement followups,
  runtime-service settlement, session polling, and selected-session stream
  reloads through one typed effect owner. Reducer branches no longer
  hand-assemble the timing-sensitive mix of runtime-service start,
  session/stream refresh, poll scheduling, and shell sync.
- Phase 33: backend route contract ownership. The MoonCode desktop projection
  contract now advertises every backend-routed MoonCode desktop endpoint,
  including status, session events, change-set, and patch-set. A MoonWiki
  route parity test compares the router surface against
  `@mooncode.desktop_projection_required_endpoints`, and the Phase 8 wall runs
  that gate.
- Phase 34: backend route method contract ownership. The MoonCode desktop
  projection contract now owns route methods through
  `@mooncode.desktop_projection_route_contracts`, derives the legacy path list
  from that structured surface, and compares backend router path plus method
  fingerprints in the MoonWiki gate. Read routes explicitly include `HEAD`
  because the desktop router accepts `HEAD` wherever it accepts `GET`.
- Phase 35: contract-backed method dispatch. MoonCode router branches now ask
  the published route contract whether a method is accepted, instead of keeping
  raw method policy in every branch. Contract-backed 405 responses expose the
  same allowed-method list through `Allow` and JSON `allowed_methods`.
- Phase 36: host-visible method contract. A fresh Moondesk HTTP smoke now
  creates a real MoonCode session and verifies accepted `HEAD` behavior plus
  rejected read-only, POST-only, and mixed-route methods through the actual
  `405` response boundary.
- Phase 37: capability-published route contract coverage. MoonCode
  capabilities now publish `desktop_route_contracts`, and the HTTP smoke uses
  that live contract to verify rejected-method behavior for every advertised
  desktop route.
- Phase 38: no static backend route mirrors. The MoonWiki backend route
  contract test no longer carries a copied list of MoonCode paths; a source
  validator compares router endpoint helper calls to
  `desktop_projection_route_contracts` and rejects reintroduced static route
  mirrors.
- Phase 39: shared frontend route formatting. Rabbita no longer owns a
  MoonCode-specific route helper file; active frontend command code calls the
  public `vectie/moondesk/core` route formatter through `@desk`, while the
  migration wall rejects raw active frontend `/api/mooncode` strings and the old
  helper file.
- Phase 40: shared desktop API route formatting. Active Rabbita command and
  settings code now call public `vectie/moondesk/core` helpers for workspace,
  MoonClaw, review, search, town, preferences, and book routes; the Phase 8
  wall rejects raw active frontend `/api/` desktop literals and stale
  frontend-local route encoder externs.
- Phase 41: desktop API method contract ownership. Generic non-MoonCode
  desktop API method policy now lives in `vectie/moondesk/core` route
  contracts, and workspace, town, MoonClaw, review/preferences, and book routers
  use a shared backend helper for method checks and `405 Allow` responses. The
  stale `/api/town/control` branch is removed; the active route is
  `/api/town/dispatch`.
- Phase 42: host-visible desktop API contract publication. Moondesk now serves
  `GET/HEAD /api/desktop/capabilities` from the public core desktop API route
  contract, publishes generic `desktop_route_contracts` and
  `required_endpoints`, and the migration wall runs a live HTTP smoke that
  derives one unsupported-method check from every advertised route.
- Phase 43: portable API route contract ownership. App-tool portable now reads
  its offline snapshot route subset and dynamic workspace content support from
  `vectie/moondesk/core`, publishes `api_supported_route_patterns` in portable
  manifests/status payloads, and the migration wall rejects a MoonWiki-local
  portable API route list returning.
- Phase 44: host-visible portable API contract publication. The desktop
  capabilities endpoint now publishes portable snapshot routes, workspace
  content route patterns, and the combined portable supported route set from
  `vectie/moondesk/core`; the live HTTP smoke and Phase 8 wall assert those
  fields before method-contract coverage runs.
