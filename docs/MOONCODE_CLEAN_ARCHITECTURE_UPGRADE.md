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

## Reference Behavior

OpenSeek stays stable because it has one append path:

- queued input is drained through one update choke point
- the UI appends the user item before starting agent work
- task-originated events are fenced by run identity
- progress and final output append as semantic transcript items
- raw logs remain evidence, not the conversation owner

MoonCode should follow the same shape, with Moondesk rendering a canonical
conversation projection owned by the backend and a very small optimistic buffer
owned by the UI.

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
- runtime sink transcript order
- content-based prompt acknowledgement
- fake "working" rows before a backend turn or runtime event exists

### Diagnostics

Raw MoonClaw events, runtime sink snapshots, command queue receipts, stream
checkpoints, and service lifecycle records remain available for diagnostics.
They update status/details surfaces, not the main chat transcript.

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
- Runtime stream and sink events remain diagnostics only.

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
- Runtime stream and sink state must not decide session selection.

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
- Runtime stream and sink state remain diagnostics/status inputs and do not feed
  the transcript read path.

Exit tests:

- old replies do not disappear on compact poll responses
- raw stream refresh cannot create chat rows
- runtime sink refresh cannot duplicate chat rows
- same-content turns remain distinct by id

## Phase 4 - Event Identity Contract

Work:

- MoonClaw echoes `turn_id` or `command_id` on every user-facing event.
- Backend buffers scoped events until the matching user turn exists.
- Unscoped events before any turn are diagnostics only.
- Terminal failures attach to the active canonical turn.

Exit tests:

- progress emitted before user acknowledgement lands under the correct user
- unscoped progress before the first user is hidden from chat
- stale events from a previous selected session cannot mutate visible chat
- runtime unavailable becomes a failed assistant response for that turn

## Phase 5 - Progress Rendering

Work:

- Render progress between the user message and assistant reply.
- Keep completed progress folded, with a user-facing summary.
- Show running progress only when it comes from canonical progress/runtime
  evidence.
- Do not show backend/debug wording in the collapsed summary.

Exit tests:

- thinking stays between user and assistant
- completed thinking remains folded after the reply
- collapse actually hides details until expanded
- summaries are human-facing, not implementation logs

## Phase 6 - End-To-End Gate

Work:

- Add a deterministic browser/API smoke path for a fresh app.
- Send first, second, and third messages.
- Verify immediate optimistic append after each send.
- Verify backend canonical acknowledgement preserves order.
- Hard refresh and verify the same three turns remain.
- Assert no fake working rows and no raw diagnostics leak into chat.

Exit tests:

- browser smoke passes on a fresh app root
- API replay returns the same canonical turn order
- hard refresh does not drop or reorder the third turn
- no duplicate MoonCode sessions are spawned by one chat

## Phase 7 - Shared Contract Layer

Work:

- Move stable conversation DTOs into MoonLib.
- Keep MoonCode-specific MoonClaw normalization in MoonCode.
- Keep MoonStat focused on analytics/health, not chat ownership.
- Publish the contract for MoonClaw, MoonCode, Moondesk, MoonRobo, MoonMoon,
  MoonFish, MoonTown, and future MoonSuite products.

Exit tests:

- all products consume the same turn/message/progress schema
- product-specific diagnostics stay outside the chat contract
- schema tests reject missing turn identity for user-facing events

## Non-Goals

- Preserving legacy raw transcript UI behavior.
- Matching old content-based prompt acknowledgement.
- Using runtime service state as a fake "working" signal.
- Letting compact session listings replace an active new-chat draft.
