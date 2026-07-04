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

## Target Shape

OpenSeek's stable behavior comes from one append path:

- the UI appends the user input immediately
- the agent/run appends progress and final output through one callback
- stale async events are fenced by run identity
- the renderer appends semantic transcript items instead of rebuilding order
  from multiple logs

MoonCode will use the same shape, with the backend owning durable canonical
turns and Moondesk rendering those turns.

```json
{
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
- The chat renderer consumes `ConversationTurn[]`; it never merges raw events,
  pending prompts, local rows, and session transcript rows at the same time.

## Anti-Patterns To Delete

- content-based ownership checks for user/assistant pairing
- pending prompt splitting around arbitrary event counts
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

Status: complete for the primary read path.

Work:

- Decode `mooncode_conversation` in `MoonCodeSession`.
- Render backend canonical turns first.
- Merge local optimistic user rows only when the backend has not yet
  acknowledged them.
- Stop using raw stream events and runtime sink events as primary chat input.
- Keep old raw-event renderer behind a clearly named temporary fallback.

Exit tests:

- backend canonical turns win over local repair logic
- local first prompt appears immediately when backend has not returned a turn
- stream refresh cannot move a second prompt above the first turn
- runtime sink refresh cannot duplicate a backend conversation turn

## Phase 3 - Send API Turn Creation

Status: active, core contract implemented.

Work:

- Every send creates a `client_turn_id` before network work starts.
- Create-session send and existing-session send both post `client_turn_id`.
- Backend returns `client_turn_id`, `turn_id`, `mooncode_turn`, and
  `mooncode_conversation` in the immediate command response.
- UI stores the same id on the optimistic row and pending prompt.
- UI drops acknowledged optimistic rows by `client_turn_id` before using any
  content fallback.
- Pending prompt acknowledgement prefers `command_packet.client_turn_id`, so
  identical second/third prompts are not cleared by an older event with the
  same text.
- Remaining cleanup: delete the old event-count pending insertion path after
  all primary render tests use backend canonical turns.

Exit tests:

- pressing Enter appends exactly one local turn immediately
- create-session send and existing-session send share the same turn contract
- retries do not duplicate the user row
- acknowledged backend turn replaces, not reorders, local optimistic turn

## Phase 4 - Runtime Ownership

Status: active, browser-side runtime startup removed from the primary path.

Work:

- Backend command enqueue starts or resumes MoonClaw runtime server-side.
- UI no longer decides runtime startup from pending prompts or sink snapshots.
- "Working" appears only from canonical turn status or attached progress.
- Duplicate runtime-service starts are rejected/fenced server-side.
- The frontend no longer has a command producer for
  `/api/mooncode/sessions/:id/runtime-service`.
- Runtime sink snapshots update factual event/service status only.

Exit tests:

- a queued turn starts runtime once
- no fake progress appears when runtime is unreachable
- runtime unavailable attaches an error to the active turn
- second turn does not reuse stale runtime state from the first turn

## Phase 5 - Event Identity Contract

Work:

- MoonClaw must echo `turn_id` or `command_id` on every user-facing event.
- Backend buffers scoped events until the matching user turn exists.
- Unscoped events before any turn are diagnostics only.
- UI ignores stale session/run updates by identity, not by content equality.

Exit tests:

- scoped progress emitted before user acknowledgment still lands under that user
- unscoped progress before any user is hidden from chat
- stale events from a previous selected session cannot mutate visible chat
- same-content prompts are represented as distinct turns

## Phase 6 - Delete Stale Frontend Implementation

Status: partially complete.

Work:

- Delete grouped user prefix repair.
- Delete recovered failed assistant cleanup from the main chat path.
- Delete pending prompt event splitting from the main chat path.
- Delete content-based assistant/user dedupe from the main chat path.
- Delete transcript rendering from `session.transcript` except as import
  fallback for historical data.
- Move raw log visualization to a diagnostics/details surface.
- Completed in this pass: deleted UI runtime-start sink heuristic, deleted
  browser runtime-service command producer, deleted stale runtime-service
  message handling, and replaced pending prompt acknowledgement with
  `client_turn_id`.

Exit tests:

- `mooncode_transcript_items` is a small projection from canonical turns
- no main chat code reads raw runtime sink events
- no main chat code reads stream events
- no main chat code compares message content to determine ownership

## Phase 7 - End-To-End Chat Tests

Backend:

- new chat first reply
- two sequential replies
- third sequential reply
- assistant delta then final answer
- progress before answer
- runtime unavailable error attached to active turn
- refresh/replay reproduces the same turn order

UI:

- new chat shows the prompt immediately
- first progress appears between user and assistant
- second and third prompts append at the bottom
- old turns never disappear during poll/stream/sink refresh
- collapsed progress remains attached to its turn

Browser smoke:

- fresh app, new chat, send `hello`
- send second message
- send third message
- hard refresh
- verify the same three turns remain in order

## Phase 8 - Shared Product Contract

Work:

- Move stable conversation DTOs into MoonLib.
- Keep MoonCode-specific event normalization in MoonCode.
- Keep MoonStat focused on analytics and health metrics, not chat ownership.
- Publish the contract for MoonClaw, MoonCode, Moondesk, MoonRobo, MoonMoon,
  MoonFish, MoonTown, and future MoonSuite products.

Exit tests:

- all products consume the same turn/message/progress schema
- product-specific diagnostics stay outside the chat contract
- schema tests reject missing turn identity for user-facing events

## Current Cleanup Direction

The next implementation step is to finish deleting the remaining compatibility
renderer paths:

- remove pending prompt event-count insertion from the main chat path
- remove content-based user/assistant ownership checks from the canonical path
- keep raw stream/runtime sink rendering only in diagnostics
- require `client_turn_id` or `command_id` on all user-facing runtime events
- add browser smoke coverage for first, second, and third turns after hard
  refresh
