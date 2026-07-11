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

MoonDesk renders a canonical conversation projection owned by the backend and a
very small optimistic buffer owned by the UI.

Hard gate:

- visible chat rendering is allowed to read only `mooncode_conversation.turns`
  and unacknowledged `mooncode_optimistic_rows`
- `mooncode_events`, stream events, runtime-event snapshots, command logs,
  receipts, and `merge_events` output are diagnostic/backend-normalization
  inputs only
- live progress is allowed only when it arrives by refreshing the selected
  canonical session and updating the progress array inside the owning turn
- late MoonClaw events may update the owning canonical turn by `command_id`,
  but they must never rebuild or resequence visible chat rows
- any implementation that replaces the visible transcript from a rebuilt event
  projection is wrong, even if it appears to fix one timing case

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
stream checkpoints, and service lifecycle records remain available for explicit
diagnostics. Rabbita/MoonDesk does not fetch, parse, merge, or checkpoint stream
data for chat rendering; the main chat transcript refreshes only from the
backend canonical session conversation plus unacknowledged local optimistic
turns.

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
- MoonDesk MoonCode polling now fetches full canonical sessions, not compact
  listing rows, so hard refresh keeps the selected conversation hydrated.
- Removed the stale legacy transcript fallback from structured MoonCode session
  projection so `session.transcript` cannot duplicate canonical command events.

Exit tests:

- browser smoke passes on a fresh app root
- API replay returns the same canonical turn order
- hard refresh does not drop or reorder the third turn
- no duplicate MoonCode sessions are spawned by one chat

## Phase 7 - Shared Contract Layer

Status: complete as the interim MoonDesk adapter; Phase 9 owns the shared
MoonLib extraction.

Work:

- Move stable conversation DTOs into MoonLib.
- Keep MoonCode-specific MoonClaw normalization in MoonCode.
- Keep MoonGate focused on analytics/health, not chat ownership.
- Publish the contract for MoonClaw, MoonCode, MoonDesk, MoonRobo, MoonMoon,
  MoonFish, MoonTown, and future MoonSuite products.

Implemented in MoonDesk:

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
- Update MoonDesk to import the MoonLib conversation contract directly.
- Keep MoonCode-specific command/runtime normalization in MoonCode.
- Publish or pin the MoonLib version that contains the contract.

Implemented:

- Added `vectie/moonlib/conversation` in MoonLib `0.1.8`.
- Published MoonLib `0.1.8` after package verification.
- Updated MoonDesk to depend on `vectie/moonlib@0.1.8`.
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

- MoonDesk, MoonCode, MoonClaw, MoonRobo, MoonMoon, MoonFish, MoonTown, and
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

Status: complete for the MoonDesk backend projection path.

Work:

- Treat MoonClaw native sidecar/runtime events as input evidence, not as a
  second conversation owner.
- Import observed native runtime events into MoonDesk's append log before
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
  daemon-observed runtime events into MoonDesk's event log once.
- `GET /api/mooncode/sessions`, session event reads, stream reads, stream-state,
  command preflight, and command send all use the sync-first canonical path.
- Known MoonDesk sessions no longer bypass the backend by returning native
  MoonClaw stream text directly.
- `attach_mooncode_session_projection` now projects from MoonDesk's durable
  event log only.
- `write_mooncode_session_record` removes response/projection fields before
  writing the session record.
- Regression coverage proves sidecar events do not affect projection until they
  are imported, and repeated sync does not duplicate events.

Exit tests:

- native assistant/progress events are imported once into MoonDesk's append log
- session refresh projects from one canonical log
- sidecar timing cannot reorder the chat independently of MoonDesk storage
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
- Remove session stream polling, stream cursors, stream checkpoints, parser
  state, and stream reducer branches from the browser chat path.
- Keep canonical selected-session refresh as the only browser chat ownership
  input after local optimistic turns.
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
- Stream-event tests were deleted with the browser stream model. Optimistic
  acknowledgement is now tested only against backend canonical conversation
  turns.

Exit tests:

- the visible chat has only canonical backend turns plus unacknowledged
  optimistic rows as owners
- session reload still preserves the selected canonical session
- raw diagnostic events cannot acknowledge optimistic rows because the browser
  no longer consumes them as transcript input
- ordinary composer text cannot become steering because of runtime status
- generated UI interfaces no longer expose the runtime sink DTO

## Phase 16 - Native Runtime Contract Report

Status: complete for the backend normalization boundary.

Work:

- Treat the existing native runtime-events response as the diagnostic surface
  for live MoonClaw event shape.
- Classify accepted native events after MoonDesk normalization.
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

- Remove regular MoonDesk API synchronization from direct MoonClaw
  product-home `events.jsonl` reads.
- Treat MoonClaw's `/v1/code/sessions/<id>/runtime-events?book_root=<path>`
  response as the native runtime producer contract.
- Persist only command-scoped or diagnostic-only native events into MoonDesk's
  canonical append log.
- Keep unsafe unscoped transcript/progress records visible only through the
  diagnostic runtime-events contract report.
- Convert deterministic browser and HTTP gates to inject runtime evidence
  through public API routes instead of writing MoonClaw sidecar files.
- Add a live smoke that starts a real MoonClaw daemon for a temporary
  MoonSuite root, posts a command-scoped event through MoonClaw's native
  runtime-events endpoint, and verifies MoonDesk imports it as canonical
  conversation output.

Implemented:

- `sync_mooncode_native_runtime_events` is the only normal backend sync path.
- `native_runtime_events_for_canonical_projection` filters accepted native
  events before persistence.
- The direct `read_moonclaw_mooncode_event_log` and
  `moonclaw_mooncode_event_log_path` helpers were removed from MoonDesk.
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
  packets, but MoonDesk was not forwarding explicit tool-call plans from the
  session/command payload into either durable producer surface.
- That made simple deterministic work depend on fallback prompt planning or
  model/service behavior, which is too slow and ambiguous for first-message and
  multi-turn UI correctness.

Work:

- Treat `runtime_tool_calls` as a first-class MoonCode command field.
- Persist explicit runtime tool calls in the canonical command packet.
- Replay the same tool-call plan in the native MoonClaw command body.
- Keep MoonDesk as the command producer only; MoonClaw remains the runtime
  owner that executes tools and emits command-scoped evidence.
- Treat a command-scoped native `finish` tool call containing an `answer` as the
  assistant final reply, and let the following generic `finish` result close
  the turn without replacing the answer with `finished`.
- Add a live native runtime-loop gate that creates a MoonDesk session, asks
  MoonClaw to execute explicit `write` and `finish` tool calls, verifies the
  file-system side effect under the selected MoonSuite root, and verifies the
  final assistant answer imports through the native runtime-events API into the
  canonical conversation.

Exit tests:

- command packet contains explicit `runtime_tool_calls`
- native command body contains the same explicit `runtime_tool_calls`
- live MoonClaw runtime loop executes the tool calls instead of falling back to
  generic thinking
- MoonDesk imports the daemon-owned `finish` tool-call answer as the assistant
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

- Add a live MoonClaw/MoonDesk smoke that creates one MoonCode session and
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
- Add a live smoke that starts MoonDesk without MoonClaw, submits the first
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

- MoonDesk used a local 15-second `runtime-service.lease.json` file to fence
  duplicate runtime-service starts.
- MoonClaw's native runtime-service is event-backed and backgrounded: it writes
  `runtime.service_started`, then later `runtime.service_finished` or
  `runtime.service_failed`.
- Keeping the MoonDesk lease timeout-only after terminal native evidence makes
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
- MoonClaw settles steer/cancel at native scheduler boundaries; MoonDesk should
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
- Add a live MoonClaw/MoonDesk control-boundary smoke that drives prompt,
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
  against MoonClaw/MoonDesk, not a deterministic tool-call simulation

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
- Normal MoonCode submits now run through the backend command API, which
  replays the local command into MoonClaw, runs the native canonical runtime
  loop, syncs `mooncode_conversation`, and returns that session response. The
  browser stability smoke must not depend on a browser-side runtime disable
  switch; deterministic fixtures belong behind backend/public APIs.
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

Status: implemented as the initial MoonCode desktop route helper and gate;
frontend-local helper ownership was superseded by Phase 39's public core route
formatter.

Problem:

- The frontend still built normal MoonCode desktop API routes inline in command
  files. That kept route construction spread across the browser update path,
  backend route contracts, tests, and smoke scripts.
- Inline route strings are a stale implementation shape: they make it easy for
  one path to miss encoding, keep an old endpoint spelling, or bypass the clean
  `/api/mooncode` desktop boundary when new controls are added.
- A first-time clean implementation should have one browser-facing route layer
  for HTTP calls. Product behavior can then change at that boundary instead of
  inside individual command handlers.

Work:

- Add the initial `mooncode_route_helpers.mbt` in the Rabbita main package
  before Phase 39 moved that responsibility to `vectie/moondesk/core`.
- Move session listing, command submit, selected-session refresh, and
  runtime-service URLs behind those helpers.
- Encode session ids and workspace ids at the helper boundary.
- Add route-helper coverage for workspace query encoding and session-id path
  encoding.
- Add `scripts/validate_mooncode_frontend_routes.sh`, wired into the Phase 8
  migration wall, so active frontend MoonCode code cannot reintroduce raw
  `/api/mooncode` strings outside the shared route boundary.

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
  selected stream refresh, explicit stream refresh, fast/normal poll
  scheduling, and shell sync.
- Move prompt-submit followups, session-mutation acknowledgement followups,
  polling followups, and selected-session stream reloads behind that owner.
- Keep runtime execution owned by the backend command API; the browser must not
  auto-start a separate runtime service after submit or poll.
- Add white-box coverage for the effect plans, including the absence of
  browser-owned runtime-service startup.
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

- Add a focused MoonCode HTTP smoke that launches MoonDesk against a fresh
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

## Phase 39 - Shared Frontend Route Formatting

Status: implemented as public core-owned MoonCode desktop URL formatting.

Problem:

- Phase 31 moved Rabbita MoonCode URLs into one frontend helper file, but that
  file was still a second implementation of desktop MoonCode route shape.
- Backend route shape is owned by the MoonCode contract and published through
  capabilities; the UI should not keep its own `/api/mooncode` path formatter
  when a shared MoonDesk public package can own browser-safe URL construction.
- A clean standalone project should have the browser command path import a
  stable public route formatter instead of hand-building MoonCode API paths in
  the UI module.

Work:

- Add public MoonCode desktop URL helpers to `vectie/moondesk/core`, including a
  target-neutral URL component encoder.
- Switch Rabbita MoonCode session list, command submit, selected-session
  refresh, and runtime-service calls to the shared `@desk` helpers.
- Delete the old Rabbita-local `mooncode_route_helpers.mbt` implementation and
  its duplicate route tests.
- Extend the frontend route validator so reintroducing the old helper file or
  raw active frontend `/api/mooncode` strings fails the Phase 8 wall.

Exit tests:

- Rabbita active command code contains no raw `/api/mooncode` path strings
- MoonCode desktop URL formatting is covered in the public `core` package
- adding a frontend-only MoonCode route formatter now fails the migration wall

## Phase 40 - Shared Desktop API Route Formatting

Status: implemented as public core-owned desktop API URL formatting for active
Rabbita routes.

Problem:

- Phase 39 removed the MoonCode-specific frontend formatter, but the active
  Rabbita command surface still built normal desktop API routes inline for
  workspaces, MoonClaw, review, search, town, preferences, and books.
- The UI also kept JS-only route encoders, which made URL construction
  browser-package behavior instead of a shared MoonDesk contract.
- A first-time clean project should let the shared public package own
  browser-safe desktop API formatting, while product UI code asks for named
  routes.

Work:

- Add generic `desktop_api_url`, `desktop_api_path`, `desktop_api_query`, and
  `url_path` helpers to `vectie/moondesk/core`.
- Add public workspace, MoonClaw, review, search, town, preferences, and books
  route wrappers around the generic helper.
- Switch active Rabbita fetch, mutation, daemon, bootstrap, settings, file, and
  book-builder code to call the shared `@desk` route helpers.
- Remove stale JS-only URL encoder externs from the Rabbita main package.
- Add a Rabbita desktop route ownership validator and wire it into the Phase 8
  migration wall.

Exit tests:

- active Rabbita production `.mbt` code contains no raw `/api/` desktop route
  strings
- active Rabbita production `.mbt` code contains no frontend-local route
  encoder externs
- `core` tests cover desktop path, query, path-preserving file, and named
  product route encoding
- the Phase 8 wall rejects reintroduced active frontend desktop API literals

## Phase 41 - Desktop API Method Contract Ownership

Status: implemented as a public core-owned method contract for generic desktop
API routes and backend router dispatch through that contract.

Problem:

- Phase 40 gave active Rabbita command code one shared route formatter, but
  non-MoonCode backend routers still owned method policy branch-by-branch with
  inline `GET`, `HEAD`, and `POST` checks.
- That left the same stale shape MoonCode had before Phases 34 and 35: route
  clients and backend routes could agree on paths while silently disagreeing on
  method behavior and `405 Allow` responses.
- Inspection also found the active UI route `/api/town/dispatch` did not have a
  matching backend route because the router still exposed the stale
  `/api/town/control` branch.

Work:

- Add `DesktopApiRouteContract` and `desktop_api_route_contracts` to
  `vectie/moondesk/core` for workspace, town, MoonClaw, review, preferences,
  search, and book desktop API families.
- Add public route-pattern helpers for route contracts, including placeholders
  for workspace ids, file/site paths, and MoonClaw run ids.
- Add a MoonWiki backend helper that converts `@http.RequestMethod` into the
  public core method contract and emits contract-backed `405 Allow` responses.
- Switch generic desktop API routers to call the contract helper instead of
  carrying inline method policy.
- Retire the stale `/api/town/control` router branch and serve the active
  `/api/town/dispatch` route directly.
- Add a source validator, wired into the Phase 8 wall, that rejects inline
  method policy returning to generic desktop API routers.

Exit tests:

- `core` tests prove generic desktop route contracts publish expected method
  sets and exclude retired `/api/town/control`
- MoonWiki tests prove backend method checks read the shared core desktop route
  contract
- generic desktop API routers contain no inline method checks or generic
  method-not-allowed calls
- the Phase 8 wall rejects reintroduced router-local method policy

## Phase 42 - Host-Visible Desktop API Contract Publication

Status: implemented as a live MoonDesk capability endpoint and HTTP method
contract smoke derived from the published route contract.

Problem:

- Phase 41 moved generic desktop API path and method policy into
  `vectie/moondesk/core`, but that contract was still only visible to source
  code and package tests.
- A clean first-time architecture needs the running host to advertise its
  generic desktop API surface the same way MoonCode advertises
  `/api/mooncode/capabilities.desktop_route_contracts`.
- Without a host-visible contract, browser code, portable app tooling, and
  downstream product shells can drift back toward probing routes or keeping
  stale route mirrors.

Work:

- Add public core helpers for `/api/desktop/capabilities` and include that
  endpoint in `desktop_api_route_contracts`.
- Add a MoonWiki desktop capability payload that publishes
  `desktop_route_contracts`, `required_endpoints`, and the shared
  `moonsuite.phase6.v1` API envelope.
- Add a small desktop API router branch for `GET/HEAD
  /api/desktop/capabilities`; it uses the same core-backed method helper and
  `405 Allow` response path as the rest of the generic desktop API.
- Add a live HTTP smoke that starts MoonDesk, reads
  `/api/desktop/capabilities`, probes one unsupported method for every
  advertised route, verifies the `405 Allow`/API-envelope body, and confirms
  retired `/api/town/control` stays absent.
- Wire the live smoke into the Phase 8 migration wall so published contract
  drift is caught by default.

Exit tests:

- `core` tests prove the desktop capability route is part of the public route
  contract.
- MoonWiki tests prove the capability payload mirrors
  `@desk.desktop_api_route_contracts`, includes `/api/town/dispatch`, and
  excludes retired `/api/town/control`.
- the live HTTP smoke derives coverage from
  `/api/desktop/capabilities.desktop_route_contracts` and checks every
  advertised generic desktop API route for contract-backed `405` behavior.
- the Phase 8 wall rejects a route added to source without host-visible method
  evidence.

## Phase 43 - Portable API Route Contract Ownership

Status: implemented by moving the app-tool portable offline API route subset
into the public desktop route contract layer and making MoonWiki app-tool
export consume that subset.

Problem:

- Phase 42 made the generic desktop API surface host-visible, but app-tool
  portable still had a MoonWiki-local `app_tool_portable_api_snapshot_routes`
  list for the offline snapshot runtime.
- That local list described a different concept than the full desktop API: only
  routes the portable bundle can answer without a running MoonDesk host. Keeping
  it local made future drift likely because route names, capability publication,
  unsupported-route detection, and portable export warnings could evolve
  independently.
- Treating MoonDesk as a clean first-time project means the portable supported
  API subset is a contract owned beside the desktop routes, not another helper
  buried in app-tool export code.

Work:

- Add core-owned portable desktop API helpers:
  `desktop_portable_api_snapshot_routes`,
  `desktop_portable_api_workspace_content_routes`,
  `desktop_portable_api_supported_route_patterns`, and
  `desktop_portable_api_route_supported`.
- Keep the portable snapshot subset explicit: static JSON snapshot routes are
  `/api/workspaces` and the read-only book registry routes; dynamic workspace
  content routes cover entries, preview, raw, file, and site reads that the
  portable runtime can answer from copied bundle assets.
- Remove the MoonWiki-local snapshot route list and make app-tool portable
  snapshot creation, export manifests, status payloads, and unsupported-route
  detection consume the core portable route contract.
- Add `api_supported_route_patterns` to portable manifests/status payloads so
  generated bundles expose both the static snapshot routes and the dynamic
  workspace content patterns they support.
- Add a migration gate that rejects reintroducing a MoonWiki-local portable API
  route list or unsupported-route detector.

Exit tests:

- `core` tests prove the portable snapshot subset and dynamic workspace content
  patterns are derived from public desktop route helpers.
- app-tool portable tests prove export and status payloads publish
  `api_supported_route_patterns` and unsupported-route detection delegates to
  the core contract.
- the Phase 8 wall runs the portable API route contract gate after live desktop
  API contract coverage, so the portable offline subset cannot silently drift
  back into a product-local mirror.

## Phase 44 - Host-Visible Portable API Contract Publication

Status: implemented by making the portable offline API subset visible through
the same desktop capability endpoint that publishes the generic host route
contract.

Problem:

- Phase 43 moved the portable API subset into `vectie/moondesk/core`, but live
  hosts still published only `desktop_route_contracts` at
  `/api/desktop/capabilities`.
- A clean first-time architecture should not require app-tool export code,
  portable manifests, or external consumers to infer the offline supported
  subset from generated bundle files.
- The portable subset is not the full desktop API. It must be explicit and
  host-visible as snapshot routes plus dynamic workspace content route
  patterns, while town/MoonClaw/control routes remain outside the offline
  contract.

Work:

- Extend `/api/desktop/capabilities` with
  `portable_api_snapshot_routes`,
  `portable_api_workspace_content_routes`, and
  `portable_api_supported_route_patterns`, all derived directly from the
  public core portable route helpers.
- Keep `desktop_route_contracts` as the full host route/method contract and
  treat the new portable fields as the offline app-tool support contract.
- Extend the live HTTP route-method smoke so the running host proves the
  portable contract is published before it checks route method behavior.
- Extend the portable route ownership gate so deleting the capability
  publication or live smoke assertion fails the Phase 8 wall.

Exit tests:

- MoonWiki capability tests prove the portable fields mirror
  `@desk.desktop_portable_api_*` exactly and exclude online-only town routes.
- the live HTTP smoke proves a real host publishes snapshot routes, workspace
  content route patterns, and the combined supported portable route set.
- the Phase 8 wall keeps the portable route contract source-owned,
  host-visible, and covered by live integration evidence.

## Phase 45 - Core-Owned Desktop Capability Schema

Status: implemented by moving the desktop capability payload shape into
`vectie/moondesk/core` and reducing MoonWiki to an HTTP envelope around that
contract.

Problem:

- Phase 42 and Phase 44 made route contracts host-visible, but
  `internal/moonwiki/desktop_api_capabilities.mbt` still owned the capability
  schema by hand: component, kind, version, route endpoint, required endpoints,
  full route contracts, and portable route fields were local JSON literals.
- That meant the route table was shared but the published capability document
  was not. Any future product could drift by adding fields to core routes,
  app-tool portable exports, or live smokes while forgetting the actual host
  capability payload.
- Treating MoonDesk as a clean standalone project means the host capability
  object is a first-class core contract, not a backend formatting detail.

Work:

- Add `DesktopApiCapabilities` and
  `desktop_api_capability_contract()` to `vectie/moondesk/core`.
- Derive the capability object from the existing desktop route contracts,
  required endpoints, and portable API route helpers.
- Replace MoonWiki's hand-built capability JSON with
  `@desk.desktop_api_capability_contract().to_json()` wrapped by the shared
  API response envelope.
- Add a migration gate that rejects returning schema fields to the MoonWiki
  capability handler.

Exit tests:

- `core` tests prove the capability object owns component/kind/version,
  required endpoints, full desktop route contracts, and portable route fields.
- MoonWiki tests prove `/api/desktop/capabilities` mirrors the core capability
  object and only adds the response envelope fields.
- the Phase 8 wall runs the capability-contract ownership gate before the live
  HTTP route-method smoke.

## Phase 46 - MoonCode Native Endpoint Contract Ownership

Status: implemented by moving the named native `/v1/code/*` endpoint set into
`mooncode/core` and making the MoonCode projection derive its native endpoint
surface from that core contract.

Problem:

- `mooncode/core` already owned the native capability surface and
  `native_capability_required_endpoints`, but `internal/mooncode/route_contracts.mbt`
  still carried private helper functions with copied `/v1/code/*` endpoint
  strings.
- That left the native runtime surface split across two packages: core owned
  the published capability list while the projection owned named endpoint
  helpers used by `/api/mooncode/capabilities`.
- A clean standalone MoonCode architecture needs native runtime endpoint names
  to be part of the public core contract, with host/projection packages only
  consuming them.

Work:

- Add `NativeCapabilityEndpoints` and `native_capability_endpoints()` to
  `mooncode/core`.
- Derive `native_capability_required_endpoints()` from the typed endpoint
  object so the existing public array API remains stable.
- Replace internal MoonCode native endpoint helper string literals with reads
  from `@mooncode_core.native_capability_endpoints()`.
- Derive `native_projection_required_endpoints()` directly from
  `native_capability_required_endpoints()`.
- Add a Phase 8 gate rejecting raw `/v1/code/*` endpoint literals returning to
  `internal/mooncode/route_contracts.mbt`.

Exit tests:

- `mooncode/core` tests prove the typed endpoint object matches the published
  required endpoint list and contains the native capability/runtime-service
  endpoints.
- internal MoonCode route-contract tests prove the projection still mirrors the
  core native surface without duplicates.
- the Phase 8 wall runs the native endpoint ownership validator before backend
  method dispatch and live MoonCode HTTP route coverage.

## Phase 47 - Core-Owned Native Runtime Endpoint Builders

Status: implemented by moving concrete MoonClaw `/v1/code` URL formatting into
`mooncode/core` and making the internal MoonCode projection wrappers delegate
to that core formatter.

Problem:

- Phase 46 made the named native endpoint templates core-owned, but
  `internal/mooncode/moonclaw_endpoints.mbt` still built concrete runtime
  URLs from raw `/v1/code/sessions/...` strings and owned its own query encoder.
- `internal/mooncode/moonclaw_capabilities.mbt` also described the native
  daemon target with a hand-copied endpoint sentence, so a route addition could
  update the typed endpoint object while leaving runtime contract copy stale.
- A standalone MoonCode package needs both endpoint templates and concrete
  endpoint formatting in the reusable core boundary; desktop projection code
  should only preserve host-facing wrapper names for current callers.

Work:

- Add `mooncode/core/native_endpoints.mbt` with the typed endpoint object,
  strict native URL component encoding, concrete builders for native
  session/list/show/command/runtime/stream/tool/eval/package endpoints, and a
  derived native target description.
- Keep `native_capability_required_endpoints()` derived from the typed endpoint
  object.
- Replace internal MoonCode's concrete MoonClaw endpoint string builders with
  delegations to `@mooncode_core.native_*_endpoint`.
- Replace the MoonClaw runtime contract's copied native target sentence with
  `@mooncode_core.native_capability_target_description()`.
- Extend the Phase 8 native endpoint ownership gate to reject raw concrete
  `/v1/code` builder strings or target descriptions returning to internal
  MoonCode.

Exit tests:

- `mooncode/core` tests prove concrete native endpoint builders encode session,
  book root, stream, and strict query characters correctly.
- internal MoonCode runtime tests prove existing host-facing wrapper functions
  still produce the same concrete native URLs.
- the Phase 8 wall rejects raw concrete `/v1/code` endpoint builders or target
  descriptions returning to internal MoonCode.

## Phase 48 - Canonical Conversation Readiness Proof

Status: implemented by making readiness and executable-book lifecycle depend on
the backend canonical conversation projection instead of raw transcript-lane
event counts.

Problem:

- Readiness still had a stale `chat_transcript` check that passed when any
  durable event used the `transcript` lane, even if no canonical user turn
  existed.
- The executable-book lifecycle inherited that stale proof for
  `propose_change`, so lifecycle readiness could be satisfied by raw assistant
  evidence rather than the append-only conversation the UI actually renders.
- A clean first-time MoonCode architecture should use one chat proof
  everywhere: `conversation_projection(session, events).turn_count`.

Work:

- Replace `chat_transcript` with `canonical_conversation` in the readiness
  contract, policy, and executable-book lifecycle requirement map.
- Derive the check from `conversation_projection(session, events)` instead of
  `count_lane(events, "transcript")`.
- Expose canonical conversation readiness telemetry in `session_summary`.
- Add a Phase 8 source gate that rejects the old `chat_transcript` readiness
  contract or raw transcript-lane counts returning to readiness.

Exit tests:

- readiness does not pass from an assistant transcript event without a
  canonical prompt turn
- executable-book `propose_change` requires canonical conversation plus typed
  command queue evidence
- session summary reports canonical conversation turn count/readiness
- the Phase 8 wall rejects raw transcript-lane chat proof returning to
  readiness/lifecycle code

## Phase 49 - Canonical Conversation Eval and Resume Telemetry

Status: implemented by removing raw transcript-count chat proof from MoonCode
eval checks, session summary telemetry, and resume lifecycle telemetry.

Problem:

- Phase 48 moved readiness and executable lifecycle off raw transcript-lane
  counts, but `session_eval_checks` still treated any transcript-lane event as
  the conversation proof.
- `session_summary` still published `transcript_count`, and
  `session_resume_lifecycle` still returned a dead `transcript_count` read from
  fresh snapshots that no longer write it.
- This kept two concepts visible in high-level telemetry: the canonical
  conversation that the UI renders, and raw transcript-lane diagnostics.

Work:

- Replace the eval check id `transcript` with `canonical_conversation`.
- Derive eval, summary, and resume conversation telemetry from
  `conversation_projection(...).turn_count`.
- Remove user-facing `transcript_count` from session summary and resume
  lifecycle payloads.
- Extend the Phase 8 conversation-proof gate to reject raw transcript counts or
  transcript eval checks returning to eval/summary/resume telemetry.

Exit tests:

- eval readiness is not satisfied by assistant-only transcript evidence
- eval checks expose `canonical_conversation`, not `transcript`
- session summary and resume lifecycle expose canonical conversation turn count
  and readiness, not `transcript_count`
- the Phase 8 wall rejects raw transcript-count chat proof returning to
  eval/summary/resume telemetry

## Phase 50 - Core-Owned Event Lane Contract

Status: implemented by moving the supported MoonCode event-lane vocabulary into
`mooncode/core` and making internal MoonCode consume that public contract.

Problem:

- The stale implementation still had private copies of the lane vocabulary in
  command metadata, runtime-event normalization, native event safety checks,
  readiness/eval counters, conversation progress projection, and capability
  prose.
- That meant "transcript", "runtime", "tool", "diff", "test", "artifact", and
  "review" could drift independently depending on which subsystem was rendering
  the current frame.
- For the user-visible chat bugs, this is exactly the wrong shape: the UI needs
  one canonical conversation path, while raw runtime evidence needs one shared
  lane contract before it can be counted or projected.

Work:

- Add `mooncode/core/event_lanes.mbt` with lane-name functions, ordered
  supported lanes, progress lanes, default-lane normalization, and a JSON
  contract.
- Embed the event-lane contract in the native capability surface fingerprint
  and capability JSON so MoonClaw-facing contracts see the same vocabulary.
- Replace private lane-list ownership in command metadata, runtime event
  projection, native runtime contract checks, readiness/eval/summary counts,
  conversation progress projection, runtime progress telemetry, tool approvals,
  and package-review flow.
- Keep concrete event records and tests free to use lane values, but stop
  implementation files from owning the supported lane list or raw lane-count
  policy.
- Add `scripts/validate_mooncode_event_lane_contract.sh` and run it from the
  Phase 8 migration wall.

Exit tests:

- `mooncode/core` proves the event-lane contract id, default lane, ordered
  lanes, progress lanes, supported-lane predicate, and normalization behavior.
- native capability JSON includes the event-lane contract.
- internal MoonCode prompt/steer expected lanes come from `event_lanes()`.
- runtime protocol and capabilities expose `event_lane_contract_json()`.
- the migration wall rejects duplicated lane lists, raw lane-count ownership,
  and prose-only lane normalization returning to implementation files.

## Phase 51 - Core-Owned Runtime Event Name Contract

Status: implemented by moving the accepted MoonClaw-to-MoonCode runtime event
vocabulary into `mooncode/core` and making internal MoonCode publish and
validate against that contract.

Problem:

- Phase 50 made lanes core-owned, but runtime event names were still copied in
  accepted-event lists, command output-event lists, native command expected
  events, native runtime safety checks, and conversation projection branches.
- That left the product with a clean lane contract but a stale event-name
  architecture: the same event stream could be accepted by one contract,
  ignored by another, or rendered differently by chat projection.
- For a standalone MoonCode product, MoonClaw and MoonDesk need one shared
  vocabulary for event names before a runtime event can become progress,
  assistant output, failure evidence, test proof, package proof, or review
  state.

Work:

- Add `mooncode/core/event_names.mbt` with accepted runtime event names,
  command output event names, failure event names, diagnostic event names,
  helper predicates, and a JSON contract.
- Embed the runtime event-name contract in the native capability surface
  fingerprint and capability JSON.
- Replace internal accepted-event and output-event arrays with
  `runtime_event_names()` and `runtime_command_output_event_names()`.
- Replace native command expected-event literals for prompt/test/package/patch/
  commit/cancel paths with core-owned helper functions.
- Move native runtime projection safety and visible conversation progress/failure
  checks onto the core-owned event helper functions.
- Add `scripts/validate_mooncode_event_name_contract.sh` and run it from the
  Phase 8 migration wall.

Exit tests:

- `mooncode/core` proves the event-name contract id, accepted events, command
  output events, diagnostic events, failure events, and helper predicates.
- native capability JSON includes the runtime event-name contract.
- runtime protocol publishes accepted events from `runtime_event_names()`.
- capabilities and runtime contracts publish output events from
  `runtime_command_output_event_names()`.
- the migration wall rejects duplicated production accepted-event/output-event
  lists returning outside `mooncode/core`.

## Phase 52 - Core-Owned Command Action Contract

Status: implemented by moving MoonCode command/action vocabulary and command
metadata into `mooncode/core`, then making internal MoonCode consume that
contract instead of carrying local lists.

Problem:

- Phase 50/51 made event lanes and runtime event names core-owned, but command
  actions were still split across command metadata, protocol decoding, native
  command metadata, preflight, action-plan proof gates, runtime completion
  proof gates, review-receipt routing, and capability payloads.
- That shape lets chat/runtime ordering drift: one subsystem can think
  `prompt`, `steer`, and `cancel` are the turn commands while another treats
  package, patch, or review commands as a separate ad hoc vocabulary.
- For a clean standalone MoonCode product, the command vocabulary must be a
  contract beside the lane and event-name contracts, not implementation glue in
  `internal/mooncode`.

Work:

- Add `mooncode/core/command_actions.mbt` with action-name functions,
  turn-control actions, advertised and supported actions, command categories,
  approval policy, lane policy, tool hints, proof predicates, review-receipt
  predicates, titles, and a JSON command-action contract.
- Embed the command-action contract in the native capability surface fingerprint
  and capability JSON.
- Convert internal command metadata to a thin facade over `mooncode/core`.
- Make `code_command_names()`, command decoding, runtime protocol JSON,
  runtime capability JSON, native action metadata, preflight, action-plan proof
  policy, runtime completion proof policy, and review-receipt policy consume the
  core-owned action contract.
- Add `scripts/validate_mooncode_command_action_contract.sh` and run it from
  the Phase 8 migration wall.

Exit tests:

- `mooncode/core` proves the command-action contract id, prompt/steer/cancel
  turn actions, advertised/supported action lists, category predicates, approval
  policy, lane policy, proof predicates, tool hints, and contract JSON.
- native capability JSON includes the command-action contract.
- runtime protocol and MoonCode capability JSON expose
  `command_action_contract_json()`.
- internal command metadata delegates advertised/supported actions and metadata
  to `mooncode/core`.
- preflight, action-plan proof gates, runtime completion proof gates, review
  receipt policy, and native command metadata consume core command predicates.
- the migration wall rejects duplicated production command-action lists or
  grouped command action ownership returning outside `mooncode/core`.

## Phase 53 - Core-Owned Runtime Tool Registry Contract

Status: implemented by moving MoonCode runtime tool vocabulary, aliases,
capability tool specs, native-required tools, tool-call contract, detailed tool
contract, and MoonClaw-to-MoonCode tool mappings into `mooncode/core`.

Problem:

- Phase 52 moved command actions into core, but command actions still pointed at
  tool names while `internal/mooncode` owned the runtime tool list, package-style
  aliases, native-required tool subset, tool-call decode policy, mutation/review
  predicates, detailed tool contract, capability tool specs, and MoonClaw tool
  mapping rows.
- That left command execution with a clean command vocabulary but a stale tool
  architecture: one subsystem could advertise a tool, another could reject it,
  and another could require review or authorization from a separate local list.
- A standalone MoonCode product needs one tool registry contract before
  MoonClaw, MoonDesk, MoonBook packaging, and future standalone clients can
  agree on allowed tools, aliases, proof events, and review policy.

Work:

- Add `mooncode/core/runtime_tools.mbt` with tool-name functions, runtime tool
  lists, capability tool lists, native-required tools, accepted aliases,
  MoonClaw mapping rows, canonicalization, supported-tool checks,
  mutation/review predicates, authorization-snapshot predicate, tool-call
  contract JSON, detailed tool contract JSON, and capability tool specs.
- Make `native_capability_required_tools()` and the native capability surface
  consume and publish the core runtime tool contract.
- Make command action tool hints use core runtime tool constants.
- Replace internal `runtime_tool_names()`, `runtime_tool_alias_rows()`,
  `tool_call_contract_json()`, tool-call decoding policy, `tool_contract_json()`,
  capability tool names/specs, native command tool sequences, web-search tool
  hints, authorization snapshot policy, and MoonClaw tool mappings with core
  consumers.
- Remove stale local tool contract record builders.
- Add `scripts/validate_mooncode_runtime_tool_contract.sh` and run it from the
  Phase 8 migration wall.

Exit tests:

- `mooncode/core` proves the runtime tool contract id, tool names, capability
  tool names, native-required tools, aliases, MoonClaw mapping rows,
  canonicalization, mutation/review predicates, authorization-snapshot
  predicate, tool-call contract JSON, detailed tool contract JSON, and
  capability tool specs.
- native capability JSON includes `runtime_tool_contract_json()` and
  `runtime_tool_call_contract_json()`.
- internal protocol commands delegate runtime tool names, aliases,
  canonicalization, support checks, mutation/review policy, and tool-call
  contract publication to `mooncode/core`.
- internal capability JSON consumes core capability tool names/specs.
- native command tool sequences and web-search tool hints use core tool
  constants.
- MoonClaw tool mapping rows and normalization delegate to `mooncode/core`.
- the migration wall rejects duplicated production tool lists, alias rows,
  local tool contract builders, and MoonClaw tool mapping ownership returning
  outside `mooncode/core`.

## Phase 54 - Core-Owned Native Event Projection Contract

Status: implemented by moving MoonClaw event mapping and native event projection
policy into `mooncode/core`.

Problem:

- Phase 51 made runtime event names core-owned, but `internal/mooncode` still
  owned the MoonClaw event mapping and the policy for whether native events are
  command-scoped, diagnostic-only, unsafe for projection, transcript evidence,
  or progress evidence.
- That left the product with a clean event vocabulary but a stale projection
  architecture: one subsystem could accept an event name while another decided
  locally whether the same event could affect chat or progress.
- A standalone MoonCode product needs one projection-safety contract before
  MoonDesk, MoonClaw, and future clients can reliably distinguish real
  command-owned work from service lifecycle noise or unsafe unscoped replies.

Work:

- Add `mooncode/core/native_event_projection.mbt` with the native event
  projection contract id/kind, MoonClaw event mapping JSON, command-scope keys,
  diagnostic source/title allowlists, projection predicates, unsafe-event
  problem records, native projection report generation, projection filtering,
  and contract JSON.
- Embed the native event projection contract in the native capability surface
  and capability fingerprint.
- Replace internal native runtime contract policy with thin delegates to
  `mooncode/core`.
- Make the MoonClaw runtime contract publish its event mapping from
  `mooncode/core`.
- Add `scripts/validate_mooncode_native_event_projection_contract.sh` and run
  it from the Phase 8 migration wall.

Exit tests:

- `mooncode/core` proves the native event projection contract id/kind, report
  kind, MoonClaw event mapping, command-scope keys, diagnostic allowlists,
  command-scope predicate, diagnostic predicate, scope-required predicate,
  transcript/progress predicates, unsafe-event reporting, projection filtering,
  and contract JSON.
- native capability JSON includes `native_event_projection_contract_json()`.
- internal native runtime contract report and canonical-projection event filter
  delegate to `mooncode/core`.
- MoonClaw runtime contract event mapping delegates to `mooncode/core`.
- the migration wall rejects duplicated production MoonClaw event mappings or
  native projection policy returning outside `mooncode/core`.

## Phase 55 - Core-Owned Model Planner Evidence Contract

Status: implemented by moving the model-planner evidence vocabulary and policy
contract into `mooncode/core`.

Problem:

- Phase 26 made model-planned turns event-backed, but the contract still lived
  in `internal/mooncode`.
- That left the working-state boundary too host-local: MoonDesk projection knew
  when queued commands must stay pending, when `runtime.turn_started` without
  planner proof becomes a contract failure, and which planner statuses/reasons
  are valid.
- A standalone MoonCode product needs MoonClaw, MoonDesk, and future clients to
  share one planner-evidence contract before any UI can show active work.

Work:

- Add `mooncode/core/model_planner_evidence.mbt` with the planner evidence
  contract id/kind, report kind, model-planned actions, command event kinds,
  planner event kinds, terminal event kinds, model-tool-call mode, statuses,
  problem reasons, status predicates, and user-facing rule copy.
- Embed the model-planner evidence contract in the native capability surface and
  capability fingerprint.
- Make `internal/mooncode/model_planner_evidence.mbt` delegate its public
  contract JSON and reusable policy decisions to `mooncode/core`, while keeping
  event aggregation/report generation in the projection package.
- Add a migration gate that rejects duplicated production planner status/event
  policy returning outside `mooncode/core`.

Exit tests:

- `mooncode/core` proves the planner contract id/kind, report kind,
  model-planned action set, command-event predicate, planner-event predicate,
  status predicates, missing-evidence reason, contract JSON, and native
  capability embedding.
- internal model-planner reports still prove pending, contract-failed,
  planner-failed, and satisfied states from deterministic event fixtures.
- runtime protocol and runtime handoff continue to expose the same
  model-planner evidence contract through the internal projection facade.
- the migration wall rejects duplicated production model-planner evidence
  vocabulary returning outside `mooncode/core`.

## Phase 56 - Core-Owned Runtime-Control Contract

Status: implemented by moving conversation-ownership and runtime-control
vocabulary, effect policy, and settlement rules into `mooncode/core`.

Problem:

- Phase 27 made turn ownership and abort handling deterministic, but the
  runtime-control contract still lived in `internal/mooncode`.
- The published internal contract listed some protocol effects but omitted
  effects the decision engine actually emits, including `active-turn`,
  `already-completed`, and `failed`.
- The runtime supervisor also carried its own local list of effects that allow
  native execution, so MoonClaw-facing runtime packets could drift from the
  contract surface that clients inspect.
- A standalone MoonCode product needs MoonClaw, MoonDesk, and future hosts to
  share one runtime-control contract before steer/cancel, scheduler-boundary
  aborts, and queued turns can be trusted.

Work:

- Add `mooncode/core/conversation_ownership.mbt` with the conversation
  ownership contract id/kind and the visible-row ownership, unowned-event,
  control, and abort rules.
- Add `mooncode/core/runtime_control.mbt` with runtime-control contract id/kind,
  state kind, active/terminal/blocked statuses, decision effects, target states,
  turn-start predicates, execution-allow predicate, settlement predicate, and
  settlement-event mapping.
- Embed the runtime-control and conversation-ownership contracts in the native
  capability surface and capability fingerprint.
- Make internal conversation projection and runtime-control contract responses
  delegate their public contract JSON to `mooncode/core`.
- Make runtime-control decision assembly and runtime-supervisor execution
  gating consume the core effect/status/settlement predicates instead of local
  string lists.
- Add a migration gate that rejects duplicated production runtime-control
  vocabulary or private conversation-ownership policy returning under
  `internal/mooncode`.

Exit tests:

- `mooncode/core` proves the conversation-ownership contract, runtime-control
  contract id/kind/state kind, status sets, effect set, target states,
  turn-start predicate, execution-allow predicate, settlement predicate,
  settlement events, contract JSON, and native capability embedding.
- internal runtime-control tests still prove active steer/cancel routing,
  lifecycle-owned response assembly, pending-turn start, queued steer,
  withdraw-pending cancel, web-search preservation, package-turn steering, and
  idle steer deferral.
- runtime supervisor packets derive `runtime_control_allows_turn` from the core
  predicate.
- the migration wall rejects duplicated production runtime-control state/effect
  strings or conversation-ownership rule strings outside `mooncode/core`.

## Phase 57 - Core-Owned Package/Review Flow Contract

Status: implemented by moving package/review model-flow vocabulary, status
policy, stale evidence reasons, event predicates, missing-step names, and the
advertised package/review contract into `mooncode/core`.

Problem:

- Phase 28 made package/review decisions deterministic, but the clean
  package/review event policy still lived in `internal/mooncode`.
- The internal projection owned the public contract JSON, terminal statuses,
  stale evidence reasons, missing-step strings, event-kind predicates, and
  readiness proof names.
- That left MoonClaw, MoonDesk, and future standalone MoonCode hosts with no
  shared source of truth for package/review flow evidence.
- A first-time clean MoonCode product needs package/review policy in the shared
  contract layer, with internal MoonCode limited to aggregating concrete event
  records.

Work:

- Add `mooncode/core/package_review_flow.mbt` with package/review contract
  id/kind, report kind, statuses, terminal status predicate, stale reasons,
  missing-step names, accepted/rejected/failed sequences, package command
  predicate, evidence predicates, failure predicate, and contract JSON.
- Embed the package/review flow contract in the native capability surface and
  capability fingerprint.
- Make `internal/mooncode/package_review_model_flow.mbt` delegate public
  contract JSON, status policy, stale evidence reasons, missing-step names, and
  event classification to `mooncode/core`.
- Keep internal MoonCode responsible only for command-owner extraction, event
  grouping, counter aggregation, latest-event tracking, and report projection.
- Add a migration gate that rejects duplicated production package/review flow
  vocabulary returning under `internal/mooncode`.

Exit tests:

- `mooncode/core` proves the package/review contract id/kind/report kind,
  statuses, terminal predicate, stale reasons, missing-step names, event
  predicates, accepted/rejected/failed sequences, contract JSON, and native
  capability embedding.
- internal package/review model-flow tests still prove accepted, rejected,
  failed, and stale command-owned package runs.
- runtime protocol contract continues to expose the package/review model-flow
  contract through the internal projection facade.
- the migration wall rejects duplicated production package/review contract,
  status, reason, missing-step, and event-kind strings outside `mooncode/core`.

## Phase 58 - Core-Owned Runtime Consumer Contract

Status: implemented by moving runtime claim/replay consumer vocabulary,
receipt status policy, claim status policy, replay status policy, replay ack
status policy, endpoint formatting, and published claim/replay rules into
`mooncode/core`.

Problem:

- Runtime claim/replay is the boundary where MoonClaw proves that work is real,
  ordered, replayable, and command-scoped, but the consumer contract still lived
  in `internal/mooncode`.
- The projection owned the public claim/replay contract JSON, receipt statuses,
  claim statuses, replay statuses, ack-order statuses, endpoint strings,
  ordering rules, duplicate guards, and lease policy.
- That left standalone MoonCode and MoonClaw consumers depending on MoonDesk
  internals for the rules that decide whether a command is claimable, delivered,
  retryable, blocked, or acknowledged.

Work:

- Add `mooncode/core/runtime_consumer.mbt` with runtime-consumer contract
  id/kind, claim/replay kinds, receipt statuses, claim statuses, replay
  statuses, ack statuses, ack-order statuses, endpoint builders, ordering
  rules, duplicate guards, lease policy, and contract JSON.
- Embed the runtime-consumer contract in the native capability surface and
  capability fingerprint.
- Make `internal/mooncode/runtime_consumer_contracts.mbt` delegate public
  claim/replay contract JSON to `mooncode/core`.
- Make runtime queue, claim, replay, and ack projection files consume core
  status predicates, status transition helpers, endpoint builders, and rule
  strings while keeping command/receipt aggregation internal.
- Add a migration gate that rejects duplicated production runtime-consumer
  vocabulary returning under runtime claim/replay projection files.

Exit tests:

- `mooncode/core` proves the runtime-consumer contract id/kind, claim/replay
  kinds, receipt statuses, claim statuses, replay statuses, ack statuses,
  endpoint builders, rules, contract JSON, and native capability embedding.
- internal runtime claim/replay tests still prove claim leasing, expired-lease
  retry, delivery skipping, ack proof gates, and command-scoped runtime
  evidence.
- runtime claim/replay projection responses continue to expose the same public
  consumer contracts through the internal facade.
- the migration wall rejects duplicated production runtime-consumer status,
  endpoint, rule, and contract strings outside `mooncode/core`.

## Final Architecture Closure Gate

Status: active. This is not Phase 59. It is the finite closure audit that
prevents the architecture plan from becoming an open-ended string-replacement
loop.

Audit result:

- Already core-owned: conversation ownership, command actions, event lanes,
  runtime event names, native endpoints, native event projection,
  model-planner evidence, runtime control, runtime consumer, runtime tools, and
  package/review flow.
- Shared-contract work still left: exactly the candidates listed below.
- Everything else that only aggregates MoonDesk/MoonBook state, host routes,
  UI copy, or diagnostic reports stays internal unless a real external consumer
  needs a data-only protocol contract.

Finite closure checklist:

1. Native command execution/result contract

   Status: implemented. `mooncode/core/native_command_execution.mbt` now owns
   the shared native command execution/result policy, the native capability
   surface embeds `native_command_execution_contract_json()`, and
   `scripts/validate_mooncode_native_command_execution_contract.sh` rejects
   duplicated internal policy tables.

   Move MoonClaw-facing native command execution policy from
   `internal/mooncode` into `mooncode/core`: action-to-tool sequence,
   expected-event policy, required-output policy, recommended command hints,
   result contract, execution checklist, and per-tool guardrails. Internal
   files should become thin adapters that pass session/path payload details into
   the core contract.

   Candidate files:

   - `internal/mooncode/native_command_action_metadata.mbt`
   - `internal/mooncode/native_command_contracts.mbt`
   - `internal/mooncode/native_command_result_contracts.mbt`
   - `internal/mooncode/native_command_tool_policies.mbt`

   Exit tests:

   - `mooncode/core` proves native command contract ids, tool sequences,
     expected events, required outputs, result checklist, and guardrail rows.
   - Internal native command body/execution-plan tests still produce the same
     MoonClaw handoff JSON by delegating to core.
   - A source validator rejects duplicated native command policy returning to
     `internal/mooncode`.

2. Runtime proof/evidence contract

   Status: implemented. `mooncode/core/runtime_evidence.mbt` now owns the
   shared runtime proof/evidence vocabulary, required-event policy,
   tool-harness statuses, action-plan proof states, and runtime replay
   completion proof gate. `scripts/validate_mooncode_runtime_evidence_contract.sh`
   rejects duplicated internal proof policy tables.

   Move reusable runtime proof vocabulary and policy from `internal/mooncode`
   into `mooncode/core`: command runtime evidence report kind, evidence
   statuses, missing/failed/proven rules, tool-harness proof statuses, required
   event proof policy, and runtime-replay proof-gate policy. Internal files
   should keep only concrete log/event aggregation.

   Candidate files:

   - `internal/mooncode/runtime_evidence.mbt`
   - `internal/mooncode/tool_harness_evidence.mbt`
   - `internal/mooncode/runtime_replay_ack_proof_gate.mbt`
   - `internal/mooncode/action_plan_state.mbt`
   - `internal/mooncode/action_plan_response.mbt`

   Exit tests:

   - `mooncode/core` proves the evidence status vocabulary, proof predicates,
     tool-harness status policy, and contract JSON.
   - Internal runtime evidence, action-plan, and replay-ack tests still prove
     command-scoped proof, failed evidence, missing evidence, and tool-harness
     blocking by delegating to core.
   - A source validator rejects duplicated runtime proof status/policy strings
     returning to production `internal/mooncode`.

3. Closure wall

   Add a final closure validator to the migration wall. It must reject new
   numbered architecture phases after Phase 58 and require this finite checklist
   to stay explicit. Any future shared-boundary item must be added by editing
   this checklist with a named owner, candidate files, and exit tests before
   implementation starts.

Do-not-migrate classification:

- `internal/mooncode/stream_*`: MoonDesk host stream/checkpoint projection, not
  the shared runtime contract.
- `internal/mooncode/session_readiness*`, `action_plan*`,
  `session_resume_lifecycle.mbt`, `session_summary*`,
  `session_executable_lifecycle.mbt`: MoonBook/MoonDesk aggregation and status
  reporting over core evidence.
- `internal/mooncode/session_tool_authorization*` and
  `session_tool_approvals.mbt`: host/operator approval projection; reusable
  tool policy already belongs to the core runtime-tool contract.
- `internal/mooncode/capabilities*.mbt`, `engine_status.mbt`,
  `runtime_handoff.mbt`, and `runtime_supervisor*.mbt`: host capability and
  launch packets that publish or embed core contracts, not independent owners
  of core vocabulary.
- `internal/mooncode/conversation_projection.mbt`: backend projection logic and
  user-facing copy. It consumes core event/action/tool/ownership contracts but
  should not move wholesale into `mooncode/core`.

Closure rule:

- No Phase 59 by default.
- No regex-only cleanup as architecture work.
- No migration just because an internal report contains display strings.
- Migrate only data-only policy that MoonClaw, standalone MoonCode, or another
  MoonSuite product must consume without importing MoonDesk internals.

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
- Letting the Rabbita frontend keep a second MoonCode desktop route formatter.
- Letting active Rabbita command handlers own generic desktop API route
  formatting.
- Letting non-MoonCode desktop API routers own method policy separately from
  the public core route contract.
- Automatically steering from ordinary chat input because a runtime service is
  running.
