# MoonCode Clean Architecture Upgrade

## Goal

MoonCode should behave like a simple chat product:

1. user submits text
2. the text appears immediately at the bottom
3. progress for that turn appears under that user message
4. the assistant reply appears under that progress
5. refresh and polling replay the same canonical order

This is a fresh-default architecture. We do not preserve stale transcript
behavior, raw-event rendering, content-matching repair, or compatibility
fallbacks as product behavior.

## Conversation Rule

MoonCode stays stable when it has one append path:

- queued input is drained through one update choke point
- the UI appends the user item before starting agent work
- task-originated events are fenced by run identity
- progress and final output append as semantic transcript items
- raw logs remain evidence, not the conversation owner

Moondesk renders a canonical conversation projection owned by the backend and a
very small optimistic buffer owned by the UI.

## Target Model

### Durable Backend State

The backend owns `mooncode_conversation`.

Each turn has:

- `turn_id`
- `client_turn_id`
- `command_id`
- `status`
- `user`
- `progress[]`
- `assistant`

Every user-facing runtime event must be normalized behind `turn_id` or
`command_id` before it can affect the conversation.

### Local UI State

The UI owns only local optimistic turns that have not been acknowledged by the
backend canonical conversation.

The UI does not own:

- pending prompt state machines
- raw stream transcript order
- browser-owned diagnostic snapshot transcript order
- content-based prompt acknowledgement
- fake "working" rows before a backend turn or runtime event exists

### Diagnostics

Raw MoonClaw events, backend runtime-event snapshots, command queue receipts,
stream checkpoints, and service lifecycle records remain available for
diagnostics. They update status/details surfaces, not the main chat transcript.

## Phase 1 - Single Optimistic Turn Buffer

Status: complete.

Work:

- Delete `mooncode_pending_prompts`.
- Generate `client_turn_id` from one monotonic submit counter.
- Append exactly one optimistic user turn for each send.
- Reassign draft optimistic turns when the backend creates the real session.
- Drop optimistic turns only when canonical backend turns acknowledge the same
  `client_turn_id`.
- Stop clearing UI state from raw runtime or stream events.

Implemented:

- `mooncode_pending_prompts` is deleted.
- `client_turn_id` comes from one monotonic submit counter.
- `MoonCodeSession` no longer decodes legacy `transcript` or
  `mooncode_events` as frontend chat state.
- Raw runtime and stream events remain diagnostics only.

Exit tests:

- first prompt appears immediately in a new chat
- second and third prompts append at the bottom
- same-content prompts get different `client_turn_id` values
- compact session listings without canonical conversation do not steal a draft
- raw runtime prompt events do not acknowledge or reorder optimistic turns

## Phase 2 - Selection and Draft Ownership

Status: complete.

Work:

- Treat "new chat" as an explicit draft route until a canonical session
  acknowledgement arrives.
- Polling must not auto-select an old session while a draft prompt or typed
  draft exists.
- Session list refresh may preserve a selected in-flight session only because
  canonical or optimistic turn state says it is in flight.
- Runtime and stream diagnostic state must not decide session selection.

Implemented:

- Added explicit `mooncode_new_chat_active` model state for the new-chat route.
- Removed draft routing decisions from `mooncode_composer_status` text.
- Session polling now computes draft ownership from the post-refresh model.
- Workspace and mode switches clear stale draft-route flags instead of relying
  on status copy.
- Regression tests now prove stale status strings alone cannot keep the UI on a
  draft route.

Exit tests:

- new chat does not flash to an existing session
- stale listing does not remove a selected in-flight session
- acknowledged draft moves once to the created session
- unacknowledged compact listing keeps the draft visible
- status copy alone cannot decide draft routing

## Phase 3 - Backend Conversation as the Only Read Path

Status: complete.

Work:

- `mooncode_transcript_items` consumes backend canonical turns plus local
  optimistic turns.
- Legacy `session.transcript` and `session.mooncode_events` are not decoded as
  frontend chat state.
- Session polling may preserve hydrated `mooncode_conversation`, but not legacy
  transcript or raw event payloads for the chat.
- Delete content-based dedupe and repair helpers from the main path.

Implemented:

- The main transcript renderer still enters through
  `mooncode_canonical_transcript_items`.
- UI-owned in-flight rows are now named `MoonCodeOptimisticRow` and stored as
  `mooncode_optimistic_rows`, separating them from backend-owned
  `mooncode_conversation`.
- The optimistic-row state moved into `mooncode_optimistic_state.mbt`.
- Runtime and stream diagnostics remain status inputs and do not feed
  the transcript read path.

Exit tests:

- old replies do not disappear on compact poll responses
- raw stream refresh cannot create chat rows
- diagnostic refresh cannot duplicate chat rows
- same-content turns remain distinct by id

## Phase 4 - Event Identity Contract

Status: complete.

Work:

- MoonClaw echoes `turn_id` or `command_id` on every user-facing event.
- Backend buffers scoped events until the matching user turn exists.
- Unscoped events before any turn are diagnostics only.
- Terminal failures attach to the active canonical turn.

Implemented:

- Scoped progress emitted before the user event is buffered until the matching
  command-owned turn exists.
- Unscoped progress and assistant events no longer attach to the latest visible
  turn as a fallback.
- Unscoped terminal runtime failures may attach to the active queued/running
  turn, so runtime-unavailable states are visible without letting normal work
  events guess their owner.

Exit tests:

- progress emitted before user acknowledgement lands under the correct user
- unscoped progress before the first user is hidden from chat
- unscoped progress/assistant after a user is hidden from chat
- stale events from a previous selected session cannot mutate visible chat
- runtime/event evidence for runtime unavailable becomes a failed assistant
  response for that turn

## Phase 5 - Progress Rendering

Status: complete.

Work:

- Render progress between the user message and assistant reply.
- Keep completed progress folded, with a user-facing summary.
- Show running progress only when it comes from canonical progress/runtime
  evidence.
- Do not show backend/debug wording in the collapsed summary.

Implemented:

- Folded progress always renders through the same disclosure component instead
  of falling back to the expanded activity body.
- Compacted progress summaries now sanitize internal MoonClaw/runtime/tool-call
  wording before it reaches the chat transcript.
- Generic thinking rows produce stable product-facing summaries unless the
  detail text is already clean user-facing progress.

Exit tests:

- thinking stays between user and assistant
- completed thinking remains folded after the reply
- collapse actually hides details until expanded
- summaries are human-facing, not implementation logs

## Phase 6 - End-To-End Gate

Status: complete.

Work:

- Add a deterministic browser/API smoke path for a fresh app.
- Send first, second, and third messages.
- Verify immediate optimistic append after each send.
- Verify backend canonical acknowledgement preserves order.
- Hard refresh and verify the same three turns remain.
- Assert no fake working rows and no raw diagnostics leak into chat.

Implemented:

- Extended the browser smoke to send three prompts, verify immediate append
  after each send, query the API for matching canonical turns, and hard refresh
  before checking the same order again.
- Added an HTTP E2E gate that creates a fresh session, sends second and third
  prompts, replays the session list, and verifies the same ordered
  `client_turn_id` / user-message sequence.
- Immediate command responses now include the projected `mooncode_summary` and
  `mooncode_conversation` DTOs required by the frontend session decoder.
- Moondesk MoonCode polling now fetches full canonical sessions, not compact
  listing rows, so hard refresh keeps the selected conversation hydrated.
- Removed the stale legacy transcript fallback from structured MoonCode session
  projection so `session.transcript` cannot duplicate canonical command events.

Exit tests:

- browser smoke passes on a fresh app root
- API replay returns the same canonical turn order
- hard refresh does not drop or reorder the third turn
- no duplicate MoonCode sessions are spawned by one chat

## Phase 7 - Shared Contract Layer

Status: complete as the interim Moondesk adapter; Phase 9 owns the shared
MoonLib extraction.

Work:

- Move stable conversation DTOs into MoonLib.
- Keep MoonCode-specific MoonClaw normalization in MoonCode.
- Keep MoonStat focused on analytics/health, not chat ownership.
- Publish the contract for MoonClaw, MoonCode, Moondesk, MoonRobo, MoonMoon,
  MoonFish, MoonTown, and future MoonSuite products.

Implemented in Moondesk:

- Added a public `mooncode/core` conversation contract JSON surface for the
  stable turn/message/progress DTO while MoonLib extraction was not available.
- `internal/mooncode` now consumes public contract names for conversation and
  turn kinds instead of owning those string literals privately.
- Phase 9 replaces the local stable schema mirror with
  `vectie/moonlib/conversation`; MoonCode keeps only product identity and
  runtime normalization.

Exit tests:

- all products consume the same turn/message/progress schema
- product-specific diagnostics stay outside the chat contract
- schema tests reject missing turn identity for user-facing events

## Phase 8 - Legacy Durable Transcript Deletion

Status: complete.

Work:

- Stop writing prompt/status messages into `session.transcript`.
- Remove MoonCode's public `append_transcript_message` wrapper.
- Remove the backend fallback that projected `session.transcript` into
  `mooncode_events`.
- Keep `transcript` only as an event lane name for runtime/user/assistant event
  records.
- Keep generic MoonCore transcript helpers available for other products, but do
  not expose or default them through MoonCode.

Implemented:

- New MoonCode session records no longer include a `transcript` field.
- Immediate queued prompt responses are projected from command events only.
- Runtime supervisor responses append projected runtime events only.
- Session listings no longer emit empty `transcript` / `mooncode_events`
  compatibility arrays or derive titles from transcript messages.
- Session snapshots describe command/runtime/event logs as the durable store,
  without a transcript array or transcript count.

Exit tests:

- new prompt creation returns a canonical `mooncode_conversation` turn without
  writing a transcript row
- legacy transcript-only sessions produce no chat events
- session listing title comes from first prompt, last message, title, or id
- response defaults do not add `transcript: []`

## Phase 9 - MoonLib Upstream Extraction

Status: complete for the shared contract rollout.

Work:

- Move the stable conversation contract from `mooncode/core` into MoonLib.
- Update Moondesk to import the MoonLib conversation contract directly.
- Keep MoonCode-specific command/runtime normalization in MoonCode.
- Publish or pin the MoonLib version that contains the contract.

Implemented:

- Added `vectie/moonlib/conversation` in MoonLib `0.1.8`.
- Published MoonLib `0.1.8` after package verification.
- Updated Moondesk to depend on `vectie/moonlib@0.1.8`.
- `mooncode/core` now delegates stable conversation schema constants, turn
  fields, ordering, identity fields, and contract JSON to MoonLib.
- MoonCode still owns product-specific protocol and owner names:
  `mooncode.v1`, `mooncode`, `moonclaw`, and `moondesk`.
- `scripts/validate_conversation_contract_rollout.sh` now rejects retired local
  conversation contract ids and unapproved product-local wrappers across all
  active MoonSuite source repos.
- `scripts/phase9_cutover_gates.sh full` now includes the conversation contract
  rollout validator after the Phase 8 full wall, API smoke, browser smoke, and
  cross-product fresh-suite product smoke.

Exit tests:

- Moondesk, MoonCode, MoonClaw, MoonRobo, MoonMoon, MoonFish, MoonTown, and
  future MoonSuite products compile against the same MoonLib contract
- contract tests reject missing turn identity for user-facing events
- product-specific diagnostics stay outside the shared chat contract

## Phase 10 - Ordinary Chat Composer Cutover

Status: complete for the ordinary chat composer path.

Work:

- Treat the visible chat composer as a new-turn prompt producer only.
- Remove browser-side `prompt` versus `steer` inference from runtime-service
  status.
- Keep explicit steering as a runtime/API capability, not as the default action
  for a normal chat message.
- Keep the optimistic append path identical for first, second, and later turns.

Implemented:

- `send_mooncode_composer_cmd` now posts ordinary composer text as `prompt`.
- The composer button no longer changes to `Steer` because a runtime service
  reports `running`.
- The main UI no longer depends on runtime diagnostic state to decide the
  semantic meaning of the user's chat input.
- Validation passed with Rabbita main tests (`147/147`), MoonCode core tests
  (`4/4`), internal MoonCode tests (`265/265`), internal MoonWiki tests
  (`144/144`), `npm run build`, and the full Desk browser smoke.

Exit tests:

- first, second, and third messages all enqueue `prompt` commands from the chat
  composer
- stale `running` runtime status cannot turn the next chat message into a
  steer command
- backend/API steering tests remain available for explicit steering behavior
- browser smoke still proves immediate append, canonical acknowledgement, and
  refresh-stable order

## Phase 11 - Backend-Owned Runtime Start

Status: superseded by Phase 21.

Work:

- Originally treated command enqueue as the normal place that starts or resumes
  MoonClaw runtime work.
- Use the existing backend runtime-service lease to fence duplicate starts.
- Return a real canonical failed turn when MoonClaw is unavailable.
- Keep `/api/mooncode/sessions/:id/runtime-service` as a backend/internal
  runtime route.
- Keep runtime-event snapshots diagnostic; they never decide chat ownership or
  composer action.

Implemented:

- This phase exposed the hidden coupling: command acknowledgement, runtime
  startup, and runtime failure projection were one response path.
- Phase 21 removes that stale coupling. Command submit now only appends and
  acknowledges durable command state; explicit `/runtime-service` calls own
  MoonClaw startup and runtime failures.

Exit tests:

- first, second, and third ordinary sends all enter the same backend enqueue
  lifecycle
- no browser-side fake working row is needed to show progress
- command ordering stays append-only after runtime start handling

## Phase 12 - Canonical Native Event Ingestion

Status: complete for the Moondesk backend projection path.

Work:

- Treat MoonClaw native sidecar/runtime events as input evidence, not as a
  second conversation owner.
- Import observed native runtime events into Moondesk's append log before
  projection.
- Make session listing, session events, stream, stream-state, preflight, and
  command send paths sync native evidence before reading canonical state.
- Stop projecting directly from MoonClaw sidecar `events.jsonl`.
- Strip response-only projection DTOs from persisted session records so storage
  records do not cache `mooncode_events`, `mooncode_summary`,
  `mooncode_conversation`, or inline `mooncode_command_events`.
- Make immediate command responses project from the durable append log order,
  using inline events only when no append log exists.

Implemented:

- Added a deduped native-event sync helper that imports sidecar events and
  daemon-observed runtime events into Moondesk's event log once.
- `GET /api/mooncode/sessions`, session event reads, stream reads, stream-state,
  command preflight, and command send all use the sync-first canonical path.
- Known Moondesk sessions no longer bypass the backend by returning native
  MoonClaw stream text directly.
- `attach_mooncode_session_projection` now projects from Moondesk's durable
  event log only.
- `write_mooncode_session_record` removes response/projection fields before
  writing the session record.
- Regression coverage proves sidecar events do not affect projection until they
  are imported, and repeated sync does not duplicate events.

Exit tests:

- native assistant/progress events are imported once into Moondesk's append log
- session refresh and stream polling project from one canonical log
- sidecar timing cannot reorder the chat independently of Moondesk storage
- persisted session records contain durable state, not cached response DTOs
- first, second, and third immediate command responses preserve append-log order

## Phase 13 - Native Reply Ownership Gate

Status: complete for deterministic backend/API coverage.

Work:

- Preserve `command_id` ownership when raw native MoonClaw transcript and
  progress events are normalized into MoonCode events.
- Treat a later command-scoped final assistant answer as the canonical
  completion for that turn, even if an earlier transport/runtime-unavailable
  failure was recorded before MoonClaw evidence arrived.
- Keep true failed final answers failed; only a `done` assistant final can
  recover a stale infrastructure failure on the same command turn.
- Extend the three-prompt HTTP E2E gate so raw native sidecar answers are
  imported through the sync-first canonical path.
- Verify session listing, event reads, and stream reads all show the same
  ordered replies without direct sidecar projection.

Implemented:

- Raw native `assistant_delta`, `assistant_message`, `reasoning_*`,
  `runtime_update`, and terminal error events now carry a normalized
  `command_packet` when MoonClaw provides `command_id`.
- Conversation projection now lets a command-scoped final assistant message
  replace a stale runtime-unavailable failure for that same turn.
- Unit coverage proves native transcript events keep command ownership and a
  real final answer recovers a stale infrastructure failure.
- The existing three-turn HTTP E2E test now appends three raw native sidecar
  assistant answers, triggers session refresh import, and verifies ordered
  canonical replies through session list, event, and stream endpoints.

Exit tests:

- native transcript events without `command_packet` but with `command_id` attach
  to the intended prompt turn
- a stale runtime-unavailable event cannot keep a turn failed after the real
  command-scoped assistant final arrives
- first, second, and third native replies append under the matching user turns
- replay/listing and stream output agree after native sidecar import
- no UI timer, fake working row, or direct MoonClaw sidecar transcript owns chat
  output

## Phase 14 - Browser Native Reply Smoke

Status: complete for the automated browser smoke path.

Work:

- Extend the real browser smoke so it does not stop at queued user turns.
- Send first, second, and third prompts through the visible MoonCode composer.
- Discover the canonical command ids from the backend session projection.
- Append raw MoonClaw sidecar `assistant_message` events for each command.
- Require the backend to import those replies through the canonical session
  refresh path.
- Require the visible chat surface to replace stale runtime-unavailable copy
  with the command-owned native replies, in turn order.
- Hard refresh and prove the same user/reply order replays from durable state.

Implemented:

- `scripts/desk_mode_browser_smoke.mjs` now writes native sidecar assistant
  replies after the three-prompt UI flow.
- The smoke waits for backend canonical replies and then for the visible
  `mooncode-chat-surface` to render exactly those assistant rows under their
  matching user turns.
- The smoke rejects leaked local-agent text, native bookkeeping text, stale
  `MoonClaw daemon` failure copy, and internal runtime status copy from the
  chat surface after native replies arrive.
- The hard-refresh portion now checks native reply replay, not just user prompt
  persistence.

Exit tests:

- first, second, and third prompts are still appended immediately through the UI
- native sidecar assistant replies import into backend canonical state
- browser-visible assistant rows match native replies in the same turn order
- stale runtime-unavailable failure copy does not remain as final chat output
- hard refresh preserves native reply order

## Phase 15 - Frontend Runtime Sink Removal

Status: complete for the MoonCode browser model.

Work:

- Remove browser-side polling of `/api/mooncode/sessions/:id/runtime-events`.
- Remove the runtime-event sink DTO, message, model fields, and reducer branch
  from `ui/rabbita-desk/main`.
- Keep session stream polling for cursors/checkpoints and canonical session
  refresh for chat ownership.
- Keep backend runtime-event endpoints available as explicit diagnostics and
  ingestion surfaces, not as a hidden frontend transcript owner.
- Delete stale UI tests that asserted sink retention, service-status copy, or
  sink-driven behavior.

Implemented:

- `PollMoonCodeSessions`, session selection, and mutation success no longer
  fetch runtime-event sink snapshots.
- The browser model no longer stores `mooncode_runtime_event_sink`,
  `mooncode_runtime_event_sink_session_id`, or
  `mooncode_runtime_event_sink_status`.
- `LoadedMoonCodeRuntimeEventSink`, `MoonCodeRuntimeEventSink`, and the
  frontend fetch command were deleted.
- Stream-event tests remain where they prove raw diagnostic events cannot
  acknowledge optimistic user turns.

Exit tests:

- the visible chat has only canonical backend turns plus unacknowledged
  optimistic rows as owners
- session reload still preserves matching stream cursor/event state
- raw stream prompt events cannot acknowledge optimistic rows
- ordinary composer text cannot become steering because of runtime status
- generated UI interfaces no longer expose the runtime sink DTO

## Phase 16 - Native Runtime Contract Report

Status: complete for the backend normalization boundary.

Work:

- Treat the existing native runtime-events response as the diagnostic surface
  for live MoonClaw event shape.
- Classify accepted native events after Moondesk normalization.
- Require every chat/progress eligible native event to carry a direct
  `command_id` or normalized `command_packet.command_id`.
- Keep unscoped service lifecycle, watcher, usage, and runtime-loop records as
  diagnostics only.
- Surface contract status and unsafe unscoped projection counts in the runtime
  events response without adding a browser-side chat owner.

Implemented:

- Added `mooncode-native-runtime-contract-report` in `internal/mooncode`.
- `runtime_event_sink_result_response_with_native` now includes the full
  contract plus scalar status/projection-safe fields.
- Tests prove command-scoped native chat evidence is projection-safe, watcher
  updates remain diagnostic-only, and unscoped assistant answers are flagged
  unsafe.

Exit tests:

- command-scoped reasoning and assistant native events are projection-safe
- unscoped watcher updates do not become chat evidence
- unscoped assistant/native chat events produce an unsafe contract report
- runtime-events diagnostics expose contract status without reintroducing a
  frontend runtime sink

## Phase 17 - Native Runtime Sync Cutover

Status: implemented as the clean producer boundary.

Work:

- Remove regular Moondesk API synchronization from direct MoonClaw
  product-home `events.jsonl` reads.
- Treat MoonClaw's `/v1/code/sessions/<id>/runtime-events?book_root=<path>`
  response as the native runtime producer contract.
- Persist only command-scoped or diagnostic-only native events into Moondesk's
  canonical append log.
- Keep unsafe unscoped transcript/progress records visible only through the
  diagnostic runtime-events contract report.
- Convert deterministic browser and HTTP gates to inject runtime evidence
  through public API routes instead of writing MoonClaw sidecar files.
- Add a live smoke that starts a real MoonClaw daemon for a temporary
  MoonSuite root, posts a command-scoped event through MoonClaw's native
  runtime-events endpoint, and verifies Moondesk imports it as canonical
  conversation output.

Implemented:

- `sync_mooncode_native_runtime_events` is the only normal backend sync path.
- `native_runtime_events_for_canonical_projection` filters accepted native
  events before persistence.
- The direct `read_moonclaw_mooncode_event_log` and
  `moonclaw_mooncode_event_log_path` helpers were removed from Moondesk.
- `scripts/desk_mode_browser_smoke.mjs` now posts deterministic runtime replies
  to `/api/mooncode/sessions/:id/runtime-events`.
- `scripts/mooncode_live_runtime_contract_smoke.sh` is the manual/scheduled
  live gate for the daemon-owned path.

Exit tests:

- command-scoped native events import into the canonical append log
- unscoped native transcript events do not persist into canonical chat
- browser smoke still proves first/second/third prompt append order and reply
  rendering without filesystem sidecar injection
- live MoonClaw smoke proves owner=`moonclaw`, projection-safe contract status,
  zero unsafe unscoped projection events, and final assistant reply projection

## Phase 18 - Native Runtime Loop Contract Gate

Status: implemented as the clean command-producer boundary.

Problem:

- MoonClaw already accepts `runtime_tool_calls` in native command bodies and
  packets, but Moondesk was not forwarding explicit tool-call plans from the
  session/command payload into either durable producer surface.
- That made simple deterministic work depend on fallback prompt planning or
  model/service behavior, which is too slow and ambiguous for first-message and
  multi-turn UI correctness.

Work:

- Treat `runtime_tool_calls` as a first-class MoonCode command field.
- Persist explicit runtime tool calls in the canonical command packet.
- Replay the same tool-call plan in the native MoonClaw command body.
- Keep Moondesk as the command producer only; MoonClaw remains the runtime
  owner that executes tools and emits command-scoped evidence.
- Treat a command-scoped native `finish` tool call containing an `answer` as the
  assistant final reply, and let the following generic `finish` result close
  the turn without replacing the answer with `finished`.
- Add a live native runtime-loop gate that creates a Moondesk session, asks
  MoonClaw to execute explicit `write` and `finish` tool calls, verifies the
  file-system side effect under the selected MoonSuite root, and verifies the
  final assistant answer imports through the native runtime-events API into the
  canonical conversation.

Exit tests:

- command packet contains explicit `runtime_tool_calls`
- native command body contains the same explicit `runtime_tool_calls`
- live MoonClaw runtime loop executes the tool calls instead of falling back to
  generic thinking
- Moondesk imports the daemon-owned `finish` tool-call answer as the assistant
  reply for the originating command and closes the turn on the generic finish
  result
- no legacy `.moonclaw` sidecar root is created

## Phase 19 - Native Runtime Multiturn Service Gate

Status: implemented as the live append-only conversation gate.

Problem:

- Single-turn native loop validation does not prove that the same session can
  accept immediate second and third prompts through the backend command route.
- The user-visible failure mode is specifically multi-turn: first reply works,
  then later prompts can appear to stall, reorder, duplicate, or disappear if
  the runtime-service lease, command replay, or projection identity contracts
  are wrong.

Work:

- Add a live MoonClaw/Moondesk smoke that creates one MoonCode session and
  executes first, second, and third prompt turns through the real backend
  command route.
- Use explicit native `finish` tool calls for each turn so the gate tests the
  native service and conversation identity contract without depending on model
  quality.
- Assert append-only ordering after every turn: distinct command ids, matching
  user messages, matching assistant replies, done statuses, and exact turn
  count.
- Keep all evidence in the MoonSuite product layout and fail if a legacy
  `.moonclaw` root appears.

Exit tests:

- first, second, and third native runtime turns all settle in the same session
- command ids remain distinct and stable
- assistant replies append under their originating user turns
- no old turns disappear, duplicate, or reorder after later replies
- no legacy `.moonclaw` sidecar root is created

## Phase 20 - Full Session List Contract

Status: implemented as the normal session-list ownership cleanup.

Problem:

- The MoonCode frontend still preserved old hydrated conversations when a later
  session-list response omitted `mooncode_conversation`.
- That compatibility layer made the browser capable of hiding backend contract
  regressions and reintroduced a second conversation owner: a previous frontend
  snapshot could silently override the newest backend response.

Work:

- Treat normal `/api/mooncode/sessions` responses as full canonical session
  state.
- Keep compact/listing rows behind the explicit `format=listing` API shape,
  not as an accepted normal browser state.
- Remove frontend copy-forward of stale `mooncode_conversation` and
  `mooncode_summary` from older local state.
- Preserve only the separate in-flight selected-session guard used for real
  asynchronous list races where the selected running session is absent from a
  stale response.

Exit tests:

- the existing HTTP code-mode E2E proves normal session lists include canonical
  first/second/third turns and native replies
- the UI reducer test proves a backend response missing
  `mooncode_conversation` is not patched with old frontend conversation data
- immediate optimistic user rows still render while the backend has not
  acknowledged the turn

## Phase 21 - Explicit Runtime-Service Boundary

Status: implemented as the submit/runtime split and runtime-control gate.

Problem:

- Command submit still tried to start MoonClaw before returning the browser's
  submit response.
- That made one HTTP path responsible for three different jobs: durable command
  append, runtime startup, and runtime failure projection.
- The browser could see slow or jumpy behavior because an ordinary chat submit
  was waiting on runtime-service work instead of returning the acknowledged
  conversation turn.

Work:

- Make `POST /api/mooncode/sessions` and
  `POST /api/mooncode/sessions/:id/commands` enqueue-only submit routes.
- Keep `/api/mooncode/sessions/:id/runtime-service` as the explicit runtime
  starter for MoonClaw work.
- Update the MoonCode UI so successful create/send acknowledgement triggers a
  separate runtime-service request.
- Keep "working" and failure copy event-backed: command submit alone may show
  the user turn, but it must not fabricate runtime progress.
- Add a live HTTP control smoke proving prompt, steer, and cancel remain one
  append-only command/runtime-control stream before MoonClaw starts.
- Update deterministic live runtime smokes to start runtime through the explicit
  service endpoint.

Exit tests:

- first prompt submit returns a queued canonical turn without starting runtime
  in the command response
- UI starts runtime through `/runtime-service` only after create/send
  acknowledgement
- prompt, steer, and cancel appear in `commands.jsonl` and
  `runtime-commands.jsonl` in append order
- runtime-control returns `start-turn`, `queue-steer`, and `withdraw-pending`
  for a pending prompt/control/cancel sequence
- deterministic native runtime loop and multiturn smokes still finish through
  explicit runtime-service calls
- no legacy `.moonclaw` sidecar root is created

## Phase 22 - Durable Runtime-Service Failure Evidence

Status: implemented as the runtime-service failure evidence gate.

Problem:

- Phase 21 made submit append-only, but a runtime-service startup failure could
  still remain mostly an HTTP/composer error.
- That left the canonical conversation turn queued or apparently thinking when
  MoonClaw never accepted the work.
- The stale implementation shape was still too split: submit owned durable user
  intent, runtime-service owned process startup, but only successful runtime
  responses reliably entered the append-only event log.

Work:

- Keep command submit clean: it still only appends the user command and returns
  a queued canonical turn.
- On `/api/mooncode/sessions/:id/runtime-service` failure, target the pending or
  active command through the MoonCode runtime-control decision engine.
- Append one command-scoped `runtime_unavailable` event to `events.jsonl` from
  the runtime-service boundary.
- Mark the stored session failed for list ordering/status, while the visible
  reply comes from the durable event projection.
- Make the failure append idempotent so retries do not duplicate assistant
  failure messages.
- Add a live smoke that starts Moondesk without MoonClaw, submits the first
  prompt, calls `/runtime-service`, then verifies the same turn renders a failed
  assistant reply from the append-only event log.

Exit tests:

- first prompt submit still returns immediately with only the queued user turn
- runtime-service failure still returns an HTTP error
- the next canonical session fetch contains the prompt plus one
  `runtime_unavailable` event
- the failed assistant reply is attached to the same command id
- repeating the failure recorder does not duplicate the event
- no legacy `.moonclaw` sidecar root is created

## Phase 23 - Event-Backed Runtime-Service Lease Recovery

Status: implemented as the runtime-service lease reconciliation gate.

Problem:

- Moondesk used a local 15-second `runtime-service.lease.json` file to fence
  duplicate runtime-service starts.
- MoonClaw's native runtime-service is event-backed and backgrounded: it writes
  `runtime.service_started`, then later `runtime.service_finished` or
  `runtime.service_failed`.
- Keeping the Moondesk lease timeout-only after terminal native evidence makes
  service ownership stale and can delay legitimate recovery/restart attempts.

Work:

- Move runtime-service lease ownership into a focused MoonWiki module instead of
  leaving it embedded in the supervisor handler.
- Add explicit release/reconcile helpers for runtime-service leases.
- Release the lease when the runtime-service boundary records a
  `runtime_unavailable` startup failure.
- Reconcile/release the lease when native or ingested runtime events include
  `runtime.service_finished` or `runtime.service_failed`.
- Strengthen the live runtime-loop smoke so a terminal native service event must
  allow an immediate same-command-count runtime-service restart.

Exit tests:

- same-command-count service starts still single-flight while no terminal event
  exists
- terminal runtime-service events release the local lease immediately
- persisted runtime events release the lease through the normal projection path
- the live runtime-loop smoke can start a second idle service immediately after
  importing the first service's native finish event

## Phase 24 - Runtime Control Boundary Cleanup

Status: implemented as the control-not-chat projection gate.

Problem:

- The canonical conversation projection still treated `steer` command events as
  user chat turns.
- That kept a stale implementation path where explicit runtime controls could
  leak into the same transcript surface as ordinary user prompts and assistant
  replies.
- MoonClaw settles steer/cancel at native scheduler boundaries; Moondesk should
  not pretend control commands are chat messages or mid-tool interruption.

Work:

- Restrict user-facing conversation turn creation to prompt/user events.
- Keep `steer`, `cancel`, `steer_deferred`, `steer_applied`, and
  `cancel_dropped` as control/runtime evidence owned by the runtime-control and
  steering lifecycle projections.
- Publish the runtime-control settlement boundary in the contract:
  controls settle at native runtime scheduler boundaries or through real abort
  evidence, not fabricated chat rows.
- Add a deterministic projection regression for prompt -> steer -> prompt ->
  cancel ordering.
- Add a live MoonClaw/Moondesk control-boundary smoke that drives prompt,
  deferred steer, prompt, and dropped cancel through real runtime-service calls
  while requiring the visible conversation to contain only the two prompt turns.

Exit tests:

- explicit steer/cancel commands do not create canonical conversation turns
- deferred/applied steering remains visible through steering lifecycle summary
  evidence
- prompt turns still render append-only with their assistant replies
- the live control-boundary smoke rejects leaked steer/cancel text in
  `mooncode_conversation`
- no legacy `.moonclaw` sidecar root is created

## Phase 25 - Explicit Visible Progress Contract

Status: implemented as the progress-projection allowlist gate.

Problem:

- The append-only conversation projection had one remaining stale shape:
  after user, assistant, failure, and lifecycle records were handled, any other
  command-scoped runtime event with a title/detail could become visible chat
  progress.
- That made the UI depend on defensive string cleanup. Internal records such as
  generic `runtime_update`, runtime bookkeeping, debug text, or model/tool JSON
  could still appear between a user prompt and the assistant answer.
- A first-time clean implementation should have a contract boundary: durable
  runtime evidence is kept for diagnostics, but only explicit user-visible
  progress events can enter `mooncode_conversation`.

Work:

- Remove the catch-all runtime-to-progress projection branch.
- Add an explicit visible-progress allowlist for command-scoped
  `runtime.turn_started`, reasoning, tool call/result, test, diff, and artifact
  evidence.
- Normalize visible progress copy at the backend projection boundary before it
  reaches the UI:
  - runtime start becomes "Starting request"
  - planner/model reasoning becomes "Thinking" with user-facing detail
  - context lookup, file edits, commands, checks, package/artifact work, and
    answer preparation each get stable human copy
- Keep arbitrary runtime records durable in event logs and diagnostic reports,
  but out of the chat transcript.
- Add projection regressions proving arbitrary scoped `runtime_update` records
  do not become progress and allowed event-backed progress is shown with clean
  wording.

Exit tests:

- a command-scoped generic runtime update cannot create a progress row
- MoonClaw turn-start, reasoning, and tool-call evidence still create progress
  rows between the user prompt and assistant reply
- visible progress rows do not contain MoonClaw/runtime bookkeeping,
  `model-tool-calls`, command ids, or raw tool JSON
- final assistant replies still complete the same command turn in append order

## Phase 26 - Model Planner Evidence Contract

Status: implemented as the model-planner evidence contract gate.

Problem:

- Deterministic `runtime_tool_calls` paths are covered, but model-planned turns
  still need a hard contract proving that MoonClaw emitted real planner evidence
  or a durable command-scoped planner failure.
- The UI must not show "working" from local state when no MoonClaw start,
  reasoning, tool-call, assistant, or failure event exists.
- Queued commands and started runtime turns were previously too easy to merge
  into one vague "thinking" state. A clean implementation needs a typed
  distinction: queued, service-started, running with planner evidence,
  planner-failed, satisfied, or contract-failed.

Work:

- Define the required event sequence for model-planned prompt turns:
  command prompt -> runtime service start -> runtime turn start -> planner
  evidence or planner failure -> tool/result evidence -> assistant/failure.
- Add `mooncode-model-planner-evidence-contract` as a backend contract exposed
  through the runtime protocol, runtime-event ingest contract, runtime-event
  sink response, and ingest-result response.
- Classify a model-planned command as a prompt, steer, or package command with
  a selected model and no explicit `runtime_tool_calls`.
- Keep a queued command with no MoonClaw evidence as `pending`; this state is
  not active work and must not create a fake working row.
- Treat `runtime.turn_started` without planner evidence as `contract-failed`.
- Treat command-scoped `runtime.planner_failed` as durable runtime failure
  evidence, not as a missing-evidence UI loop.
- Accept a complete planner sequence only when the same command id owns planner
  start/selection/reasoning or model tool-call evidence and then assistant or
  terminal evidence.
- Add deterministic fixture gates for pending, missing-evidence failure,
  planner failure, and successful planner-to-assistant completion without
  requiring live model credentials.

Exit tests:

- model-planned command with only the prompt record reports `pending`, zero
  working evidence, and no problems
- model-planned command with `runtime.turn_started` but no planner evidence
  reports `contract-failed` with
  `missing-model-planner-evidence-after-turn-start`
- command-scoped `runtime.planner_failed` reports `planner-failed` without
  creating a missing-evidence problem
- planner start/selection/reasoning/tool/result plus assistant evidence reports
  `satisfied`
- runtime-event sink and ingest-result responses expose
  `model_planner_evidence`
- no UI or projection path needs to infer active work from local state alone

## Phase 27 - Turn Ownership and Abort Contract

Status: implemented as the conversation ownership and abort/control gate.

Problem:

- Steer/cancel are now kept out of chat, but true interrupt behavior depends on
  MoonClaw emitting explicit abort or scheduler-boundary evidence.
- UI rows should never move because a late control event lacks turn ownership.
- The previous projection still had a stale fallback that could attach an
  unscoped runtime failure to the latest active turn. That is convenient in
  demos but wrong for a first-time clean architecture: it lets late runtime
  diagnostics rewrite the visible transcript without command ownership.

Work:

- Add command/run ownership ids to every visible progress, assistant, failure,
  abort, and recovery record.
- Add `mooncode-conversation-ownership-contract` and expose it from the
  conversation projection, runtime-control contract, and runtime protocol
  event-stream contract.
- Add an ownership report to the conversation projection. Unscoped
  progress/assistant/failure/abort-shaped events are counted as ignored
  diagnostics instead of being attached to the latest turn.
- Preserve `run_id`, `runtime_session_id`, `client_turn_id`,
  `target_command_id`, and `applied_to_command_id` when raw native runtime
  events are normalized into command refs.
- Add source/target owner tuples and required settlement events to
  runtime-control decisions so steer/cancel decisions name the MoonClaw evidence
  required to settle them.
- Project command-scoped `runtime_aborted` as a cancelled assistant row only
  when it belongs to a non-control prompt/command turn.
- Keep control history folded outside the user/assistant transcript unless
  MoonClaw emits command-scoped user-visible failure/abort evidence.

Exit tests:

- every visible user/progress/assistant row carries `turn_id`,
  `client_turn_id`, `command_id`, `run_id`, `runtime_session_id`, `action`, and
  `owner`
- unscoped runtime failure evidence is ignored by the visible transcript and
  counted in the ownership report
- command-scoped runtime failure still closes the owning turn
- command-scoped `runtime_aborted` on a prompt turn closes that turn as
  `cancelled`
- cancel-scoped `runtime_aborted` remains folded control lifecycle evidence and
  does not create a chat row
- runtime-control decisions expose source owner, target owner, and required
  settlement events for steer/cancel

## Phase 28 - Package and Review Model Flow Gate

Status: implemented for the deterministic package/review model-flow gate; the
separate scheduled live model package/review run remains follow-up work.

Problem:

- Package/review flows are currently covered by deterministic tool and artifact
  gates, but model-backed review decisions can still become broad and
  nondeterministic.

Work:

- Define a command-scoped package/review event sequence with package manifest,
  diff review, test evidence, final readiness, and assistant summary.
- Add fixture tests for accepted, rejected, failed, and stale package/review
  runs.
- Add a scheduled/live gate for one real model package/review turn, separate
  from deterministic merge tests.

Implemented gate:

- `package_review_model_flow_contract_json` defines the clean event contract for
  model-backed package/review turns.
- `package_review_model_flow_report` groups evidence by package command owner
  and refuses to merge stale evidence from another command into the active
  package/review run.
- Accepted runs require one command owner to provide `command.package`,
  `package.manifest`, `receipt.accept`, passing `test_result`,
  `runtime.package_verified`, and final assistant summary.
- Rejected runs require owned `receipt.reject` plus final assistant summary.
- Failed runs are terminal when command-scoped tests, package proof, planner, or
  command execution evidence fails.
- Stale runs are reported when package/review evidence has no matching package
  command owner, instead of completing the nearest visible turn.

Exit tests:

- accepted package/review fixture satisfies the full owned sequence
- rejected package/review fixture closes through an owned reject receipt and
  assistant summary
- failed package/review fixture closes through command-scoped failed test
  evidence
- stale package/review fixture proves old-command evidence cannot settle a new
  package command
- runtime protocol contract advertises the package/review model-flow contract
- scheduled live gate still needs one real model-backed package/review run
  against MoonClaw/Moondesk, not a deterministic tool-call simulation

## Phase 29 - Browser Conversation Stability Gate

Status: implemented as the browser transcript stability smoke gate.

Problem:

- Backend projection fixes must be protected in the actual browser surface:
  first, second, and third user turns must append immediately, progress must
  stay between the owning user and assistant, and reload/polling must not erase
  old turns.

Work:

- Extend the browser smoke to assert first/second/third prompt behavior against
  canonical backend events without racing the live model runtime.
- Fail on front-page flashes after new chat submit, duplicate messages,
  reordering, disappearing old turns, or non-collapsed completed progress.
- Keep the visible transcript contract simple: user row, folded progress for
  that command, assistant row, repeated append-only.

Implemented gate:

- MoonCode transcript message and activity DOM rows now carry
  `data-command-id` and `data-client-turn-id` from the backend canonical
  conversation.
- Normal MoonCode sessions still auto-start MoonClaw runtime service. The
  browser stability smoke opens MoonCode with `mooncodeRuntime=manual`, which
  disables only runtime auto-start so the test can inject event-backed native
  replies through public APIs and measure UI ordering deterministically.
- The browser smoke samples the transcript after each of the first, second, and
  third prompt submits so transient front-page flashes, duplicate user rows,
  reorder windows, disappearing turns, and activity-before-user placement fail
  the test instead of being hidden by eventual convergence.
- After event-backed native replies and after a hard reload, the smoke asserts
  user/reply order, owner placement, absence of internal runtime copy, and
  folded completed progress rows.

Exit tests:

- `scripts/desk_mode_browser_smoke.sh full` passes with the Phase 29 MoonCode
  transcript stability sampler enabled
- JS package check passes for `ui/rabbita-desk/main`
  (`moon check ui/rabbita-desk/main --target js`)

## Phase 30 - No Frontend Conversation Repair

Status: implemented as the browser session-list ownership cleanup.

Problem:

- The frontend still had one stale repair branch: when a normal
  `/api/mooncode/sessions` response contained the selected session but with
  fewer canonical turns or source events than the browser's previous snapshot,
  the reducer replaced the backend response with the old local session.
- That made the browser a second conversation owner. It could hide backend
  regressions, mask compact/listing route mistakes, and make disappearance or
  reordering bugs harder to trace because the displayed transcript was not
  always the newest backend projection.
- A first-time clean implementation should make the backend append log and
  canonical projection the only durable conversation source. The UI may keep
  local optimistic user rows and may preserve an absent selected in-flight
  session during a real list race, but it must not repair a present backend
  session by copying old conversation state over it.

Work:

- Remove the selected-session "fresher conversation" replacement branch from
  `mooncode_preserve_selected_inflight_session`.
- Delete the frontend helpers that compare conversation turn counts or source
  event counts and replace an incoming session with a cached local one.
- Keep the valid in-flight guard only for the case where the selected session is
  absent from a stale list response and the UI has a real optimistic row,
  queued status, or running status for that selected session.
- Update reducer coverage so a regressed normal backend response is accepted by
  the UI. That test exists to expose backend contract failures rather than hide
  them.

Exit tests:

- normal `/api/mooncode/sessions` responses remain the source of truth for any
  session they contain
- a response with fewer canonical turns is not patched with an older local
  `mooncode_conversation`
- selected in-flight sessions are preserved only when missing from the incoming
  list and backed by real in-flight state
- immediate optimistic user rows still render until acknowledged by
  `client_turn_id`

## Phase 31 - Frontend Route Ownership

Status: implemented as the MoonCode desktop route helper and gate.

Problem:

- The frontend still built normal MoonCode desktop API routes inline in command
  files. That kept route construction spread across the browser update path,
  backend route contracts, tests, and smoke scripts.
- Inline route strings are a stale implementation shape: they make it easy for
  one path to miss encoding, keep an old endpoint spelling, or bypass the clean
  `/api/mooncode` desktop boundary when new controls are added.
- A first-time clean implementation should have one frontend route layer for
  browser-owned HTTP calls. Product behavior can then change at that boundary
  instead of inside individual command handlers.

Work:

- Add `mooncode_route_helpers.mbt` in the Rabbita main package.
- Move session listing, command submit, stream polling, stream checkpoint, and
  runtime-service URLs behind those helpers.
- Encode session ids and workspace ids at the helper boundary.
- Add route-helper white-box coverage for workspace query encoding and
  session-id path encoding.
- Add `scripts/validate_mooncode_frontend_routes.sh`, wired into the Phase 8
  migration wall, so active frontend MoonCode code cannot reintroduce raw
  `/api/mooncode` strings outside the helper.

Exit tests:

- frontend command files contain no raw `/api/mooncode` strings
- route helpers generate the same current endpoints with correct encoding
- the Rabbita JS package check and tests pass
- the Phase 8 migration wall runs the route ownership validator

## Phase 32 - Frontend Session Effect Ownership

Status: implemented as the MoonCode session effect owner and gate.

Problem:

- The frontend still assembled MoonCode session follow-up commands inside
  separate action/result reducer branches. Prompt submit, create-session
  acknowledgement, runtime-service success/failure, session selection, and
  polling each repeated parts of the same batch: fetch sessions, fetch stream,
  start runtime-service, schedule fast/normal polling, and sync the shell route.
- That shape is a stale implementation risk because the reducer branch that
  changes model state can silently drift from the branch that schedules the
  side effects. It makes first/second/third turn behavior harder to reason
  about, and it spreads timing-sensitive chat behavior across unrelated files.
- A first-time clean implementation should have one frontend owner for
  session-side effects. Reducers should choose model state and invoke a named
  effect plan; they should not hand-assemble HTTP/timer batches.

Work:

- Add `mooncode_session_effects.mbt` in the Rabbita main package.
- Define typed MoonCode session effects for daemon refresh, session refresh,
  selected stream refresh, explicit stream refresh, runtime-service start,
  fast/normal poll scheduling, and shell sync.
- Move prompt-submit followups, session-mutation acknowledgement followups,
  runtime-service settlement followups, polling followups, and selected-session
  stream reloads behind that owner.
- Keep runtime-service auto-start gated only by `mooncode_runtime_mode` at the
  effect-plan boundary; manual browser smokes still suppress runtime start
  without changing reducer logic.
- Add white-box coverage for the effect plans, including manual-mode runtime
  suppression and runtime success/failure settlement plans.
- Wire the effect-plan gate into the Phase 8 migration wall.

Exit tests:

- submit acknowledgement effect plans include runtime-service start only in
  automatic mode, then session refresh, stream refresh, fast poll, normal poll,
  and shell sync
- manual mode suppresses runtime-service start without suppressing canonical
  session/stream refresh
- runtime-service success schedules session refresh, stream refresh, fast poll,
  and normal poll
- runtime-service failure schedules session refresh, stream refresh, and normal
  poll without pretending active work
- polling has one canonical effect plan

## Phase 33 - Backend Route Contract Ownership

Status: implemented as the MoonCode backend route contract parity gate.

Problem:

- The backend MoonCode router served routes that the public desktop projection
  contract did not advertise. In particular, `/api/mooncode/status`,
  session `events`, `change-set`, and `patch-set` were routed separately from
  `desktop_projection_required_endpoints`.
- That split lets docs, capabilities, runtime readiness reports, browser code,
  and server routing disagree about what the clean desktop MoonCode API is.
  A first-time standalone project should not require reading the router source
  to discover supported endpoints.
- Missing route contracts also weaken test planning: a route can exist without
  being counted by contract coverage, migration gates, or downstream product
  boundary checks.

Work:

- Add public MoonCode route-contract helpers for status, session events,
  session change-set, and session patch-set endpoints.
- Include those endpoints in `desktop_projection_required_endpoints` and,
  through that, `engine_supported_endpoints`.
- Add a MoonWiki backend route contract white-box test that normalizes query
  strings and compares the router surface against
  `@mooncode.desktop_projection_required_endpoints`.
- Document `/api/mooncode/status` in the MoonCode API route list.
- Wire the backend route contract gate into the Phase 8 migration wall.

Exit tests:

- `desktop_projection_required_endpoints` contains every routed desktop
  MoonCode API path
- the backend router surface has no unadvertised MoonCode desktop endpoint
- status, events, change-set, and patch-set endpoints are counted by the
  contract and engine-supported endpoint report
- the Phase 8 migration wall runs the backend route parity test

## Phase 34 - Backend Route Method Contract Ownership

Status: implemented as the MoonCode route method contract parity gate.

Problem:

- Phase 33 made backend-routed desktop paths visible through the MoonCode
  contract, but allowed HTTP methods were still implicit in
  `api_mooncode_router.mbt`.
- That left a stale split: the public contract could say a route exists without
  telling downstream tests, docs, or products whether it is read-only,
  read/write, or POST-only.
- A first-time clean implementation should make route method behavior part of
  the same contract surface as route paths. Reading router source should not be
  required to know which endpoints accept `GET`, `HEAD`, or `POST`.

Work:

- Add `desktop_projection_route_contracts` as the structured MoonCode desktop
  route contract owner.
- Derive `desktop_projection_required_endpoints` from that structured contract
  so the path list is not a second manually maintained source.
- Include `HEAD` in read-route contracts because the desktop router accepts
  `HEAD` anywhere it accepts `GET`.
- Extend the MoonWiki backend route contract gate to compare router path plus
  method fingerprints against the published MoonCode contract.
- Update the MoonCode API docs and code-mode test plan to treat method parity
  as part of the backend contract.

Exit tests:

- every desktop route contract has one path and a non-empty method list
- read-only routes advertise `GET` and `HEAD`
- mixed command routes advertise `GET`, `HEAD`, and `POST`
- package-result and runtime-service remain POST-only
- the backend router method surface matches
  `desktop_projection_route_contracts`

## Phase 35 - Contract-Backed Method Dispatch

Status: implemented as MoonCode router method dispatch through the published
route contract.

Problem:

- Phase 34 made route methods visible in the public MoonCode contract, but the
  backend router branches still contained their own method policy with raw
  `is_read_method` and `Post` checks.
- That made the route contract an audited mirror instead of the actual method
  authority. A router branch could still drift from the contract and only be
  caught after the fact.
- `405 Method Not Allowed` responses also did not report the allowed method
  list, so API consumers and host tests could not observe the contract boundary
  from the HTTP behavior itself.

Work:

- Add a MoonWiki MoonCode route-method helper that reads
  `@mooncode.desktop_projection_route_contracts`.
- Replace MoonCode router branch method checks with
  `mooncode_route_accepts_read` and `mooncode_route_accepts_post`.
- Add a MoonCode-specific 405 sender that reports the contract's allowed
  methods through the `Allow` header and JSON `allowed_methods`.
- Keep non-MoonCode routers on the existing generic method-not-allowed path.
- Extend the MoonWiki backend route contract test to prove GET/HEAD/POST
  acceptance is contract-backed for read-only, mixed, and POST-only routes.
- Add a migration-wall source validator that rejects raw method checks or
  generic 405 calls inside the MoonCode router.

Exit tests:

- raw method policy for MoonCode routes is isolated in the route-method helper
- status accepts GET/HEAD and rejects POST/DELETE through the contract
- commands accepts GET/HEAD/POST and rejects unrelated methods through the
  contract
- runtime-service remains POST-only through the contract
- MoonCode 405 responses are prepared from the route contract's allowed method
  list
- the Phase 8 migration wall rejects raw MoonCode router method checks

## Phase 36 - Host-Visible Method Contract

Status: implemented as a real HTTP boundary smoke for MoonCode method policy.

Problem:

- Phase 35 made router method dispatch contract-backed in code, but the
  migration wall still did not prove the observable host API response.
- The UI and desktop host never call `mooncode_route_accepts_*` directly. They
  see HTTP status codes, `Allow` headers, and JSON API contracts.
- Without an HTTP-level gate, a future response helper, router wrapper, or
  server boundary change could preserve the internal test while breaking the
  actual MoonCode client contract.

Work:

- Add a focused MoonCode HTTP smoke that launches Moondesk against a fresh
  suite root and creates one real MoonCode session.
- Probe a read-only route, a POST-only route, and a mixed GET/HEAD/POST route
  with methods the contract rejects.
- Assert each rejected request returns `405 Method Not Allowed`, the expected
  `Allow` header, and JSON `allowed_methods`.
- Assert the 405 body still carries the shared API contract fields:
  `ok=false`, `status=error`, `api_contract=moonsuite.phase6.v1`, and
  `next_action=inspect_request`.
- Keep the smoke in the Phase 8 fast wall so contract drift fails before larger
  runtime smokes.

Exit tests:

- `HEAD /api/mooncode/status` is accepted wherever `GET` is accepted
- `POST /api/mooncode/status` exposes `GET, HEAD` as the allowed contract
- `GET /api/mooncode/sessions/:id/runtime-service` exposes `POST` as the
  allowed contract
- `PUT /api/mooncode/sessions/:id/commands` exposes `GET, HEAD, POST` as the
  allowed contract
- method policy is proven through the same HTTP boundary used by the frontend
  and desktop host

## Phase 37 - Capability-Published Route Contract Coverage

Status: implemented as capability-published desktop route contracts plus
contract-driven HTTP route coverage.

Problem:

- Phase 36 proved the HTTP method contract only for representative route
  classes: read-only, POST-only, and mixed routes.
- The broader done criterion is stronger: every `/api/mooncode` desktop route
  needs at least one host-visible success, method, or validation check.
- `/api/mooncode/capabilities` still exposed route information partly through
  prose and individual fields, while the structured
  `desktop_projection_route_contracts` surface stayed available only to
  MoonBit callers.

Work:

- Publish `desktop_route_contracts` directly in `@mooncode.capabilities_json`.
- Add capability tests proving the published route contracts mirror
  `desktop_projection_route_contracts` path and method data.
- Extend the real HTTP smoke to read `/api/mooncode/capabilities`, create one
  session, substitute the live session id into each `<session-id>` route, and
  probe every advertised desktop route with a method rejected by that route.
- Keep the smoke asserting `405`, `Allow`, JSON `allowed_methods`, and shared
  API contract fields for every advertised route.

Exit tests:

- desktop route contracts are a client-visible capability, not only an internal
  MoonBit helper
- every advertised MoonCode desktop route has host-visible method-contract
  coverage
- adding a new desktop route without observable HTTP method behavior now fails
  the Phase 8 migration wall

## Phase 38 - No Static Backend Route Mirrors

Status: implemented as source-owned backend route validation without a copied
route list.

Problem:

- Phase 33 and Phase 34 used a MoonWiki white-box test with a hand-written
  mirror of every MoonCode backend route and method.
- After Phase 37, the real HTTP gate is driven by the live capability route
  contract, so the old 33-route MoonWiki mirror became stale implementation
  debt: adding or renaming a route required editing the contract, router, and
  a duplicated test list.
- A clean standalone project should let the MoonCode contract own route shape,
  while backend validation proves the router references the same endpoint
  helper set.

Work:

- Delete the static `mooncode_backend_router_route_contracts` mirror from the
  MoonWiki route contract test.
- Keep the MoonWiki white-box test focused on route method helper behavior.
- Add a source validator that compares endpoint helper calls in
  `api_mooncode_router.mbt` against helper calls in
  `desktop_projection_route_contracts`.
- Make the validator reject reintroduced static `/api/mooncode` route mirrors
  in the backend route contract test.
- Wire the validator into the Phase 8 fast wall before the HTTP route coverage
  smoke.

Exit tests:

- MoonWiki tests no longer contain a copied list of MoonCode route paths
- every route helper in `desktop_projection_route_contracts` is referenced by
  the backend router exactly once, and vice versa
- the Phase 8 wall rejects route additions that update only the router or only
  the contract

## Non-Goals

- Preserving legacy raw transcript UI behavior.
- Matching old content-based prompt acknowledgement.
- Using runtime service state as a fake "working" signal.
- Letting compact session listings replace an active new-chat draft.
- Repairing backend conversation regressions in the browser with cached local
  `mooncode_conversation` state.
- Letting individual frontend command handlers construct MoonCode desktop API
  routes directly.
- Letting reducer branches hand-assemble MoonCode session HTTP/timer follow-up
  batches.
- Letting the backend serve MoonCode desktop API routes that are absent from
  the published route contract.
- Letting backend route methods live only inside router branches instead of the
  published MoonCode route contract.
- Letting MoonCode 405 responses hide the allowed-method contract from API
  consumers.
- Letting internal route-contract tests stand in for host-visible HTTP contract
  behavior.
- Letting MoonWiki route tests maintain a second static copy of the MoonCode
  desktop API route list.
- Automatically steering from ordinary chat input because a runtime service is
  running.
