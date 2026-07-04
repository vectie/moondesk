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

## Non-Goals

- Preserving legacy raw transcript UI behavior.
- Matching old content-based prompt acknowledgement.
- Using runtime service state as a fake "working" signal.
- Letting compact session listings replace an active new-chat draft.
- Automatically steering from ordinary chat input because a runtime service is
  running.
