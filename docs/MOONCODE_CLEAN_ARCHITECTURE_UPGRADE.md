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
- runtime unavailable becomes a failed assistant response for that turn

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

Status: complete for the command enqueue path.

Work:

- Treat command enqueue as the only normal place that starts or resumes
  MoonClaw runtime work.
- Use the existing backend runtime-service lease to fence duplicate starts.
- Return a real canonical failed turn when MoonClaw is unavailable instead of a
  queued prompt that can sit forever.
- Keep `/api/mooncode/sessions/:id/runtime-service` as a backend/internal
  runtime route, not as the visible chat producer.
- Keep runtime-event snapshots diagnostic; they never decide chat ownership or
  composer action.

Implemented:

- New-session creation and existing-session command send now both call the same
  backend post-enqueue helper.
- The helper attempts runtime-service start/resume after the prompt command and
  command event are durably appended.
- Runtime start failures append a command-scoped `runtime_unavailable` event and
  return a failed assistant message for that exact turn.
- The HTTP E2E test now expects runtime-unavailable to appear as a canonical
  failed turn when a test workspace has no MoonClaw daemon.

Exit tests:

- first, second, and third ordinary sends all enter the same backend enqueue
  lifecycle
- no browser-side fake working row is needed to show progress or failure
- runtime unavailable is visible as a failed assistant message for the active
  turn
- command ordering stays append-only after runtime start/failure handling

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

## Non-Goals

- Preserving legacy raw transcript UI behavior.
- Matching old content-based prompt acknowledgement.
- Using runtime service state as a fake "working" signal.
- Letting compact session listings replace an active new-chat draft.
- Automatically steering from ordinary chat input because a runtime service is
  running.
