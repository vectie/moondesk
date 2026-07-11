# MoonCode OpenSeek Alignment Update Plan

Status: canonical conversation upgrade implemented and the three-turn real UI
closure gate passed on 2026-07-10. This is a finite architecture correction,
not Phase 59.

## Implementation Record

Completed on 2026-07-10:

- MoonLib now defines `moonsuite-conversation.v2`, stable turn ordinals,
  user/work/assistant slots, typed work steps, and monotonic revision rules.
- MoonClaw is the only canonical conversation reducer. It emits stable slot
  ids, upserts work steps, keeps raw reasoning deltas transient, and writes
  JSONL records with append mode instead of rewriting the full file. Every
  append now takes an exclusive file lock and repairs a crash-torn final
  fragment before writing the next complete record.
- MoonDesk rejects stale, cross-session, or pre-v2 conversation payloads and
  never rebuilds chat from its command/event logs.
- the former MoonDesk conversation projector and its replay tests were deleted.
- session-list polling uses listing rows; selected-session polling hydrates one
  canonical conversation.
- the UI renders one producer-owned work disclosure per turn and suppresses
  unchanged revisions without scan-ahead, folding, compaction, or content
  repair.
- browser polling now has one generation-checked controller. A new submit
  invalidates stale timers instead of starting another permanent polling loop.
- active polling reads only the selected canonical session (or the listing
  while a new-session id is still unknown); idle polling refreshes rail and
  daemon state every five seconds.
- the chat route performs one MoonClaw canonical-session read and does not
  fetch or replay native runtime events as an alternate transcript source.
- both local and native listing rows preserve the selected hydrated
  conversation and fill metadata without clearing its workspace identity.

Passing automated gates:

- MoonLib conversation tests: 3/3
- MoonClaw core tests: 15/15
- MoonClaw daemon tests: 93/93
- MoonClaw full repository tests: 1,028/1,028
- MoonDesk MoonCode core tests: 281/281
- MoonDesk HTTP/backend tests: 160/160
- MoonDesk UI model tests: 177/177
- production Rabbita/Vite build

The isolated HTTP workflows now run with an in-process MoonClaw v2 contract
fixture. They test native readiness, command delivery, runtime-loop completion,
metadata-only listing, selected-session canonical hydration, diagnostic event
ingest, stream checkpoints, and three-turn order without reviving a local
conversation projector.

### Real UI Closure Record

The final test used one fresh MoonDesk server, one MoonClaw daemon, and the
in-app browser. Prompts were entered through the visible textarea and sent with
Enter; no internal message injection was used.

- the second and third user messages were present in the first post-Enter DOM
  sample, before MoonClaw work or an assistant answer existed
- real MoonClaw evidence added exactly one work row beneath each owning user
  message
- every sampled top-level order remained `user -> work -> assistant`
- the three completed turns produced nine stable rows with three distinct
  `command_id` and `client_turn_id` pairs
- the nine-row order survived idle polling, hard reload, and a MoonClaw daemon
  restart
- expanding a completed historical work disclosure with a mouse click stayed
  open through the next poll; a second click collapsed it
- the selected conversation no longer disappears when a native listing row
  arrives
- blank native listing metadata no longer changes the selected workspace or
  context path
- the previous multiplied polling loops were reduced to one idle tick every
  five seconds, with one native listing read and one selected canonical read
  per idle tick

The final durability rerun observed 16 ms and 20 ms from Enter to the first
ordered DOM sample for the second and third turns. The optimistic row was
already present in both samples. Live MoonClaw work and the exact requested
assistant reply completed within the following 1.2-second observation window
for all three turns.

### Storage Durability Closure

The long-horizon storage targets were closed on 2026-07-10:

- 1,000 sequential appends preserved exactly 1,000 parseable records
- 64 concurrent writers produced exactly 64 unique records with no loss or
  duplication
- a partial final JSONL fragment was truncated while every prior committed
  record and the next append were preserved
- 100 repeated canonical replay cycles produced byte-identical conversation
  JSON
- the normal append path reads one final byte and writes one record; backward
  scanning is used only when the final record is torn

## Outcome

MoonCode should have the same simple behavioral shape that makes OpenSeek
stable:

1. the user message appears immediately
2. one turn owns all work and answer state
3. live activity updates one stable slot inside that turn
4. completed work remains as one folded disclosure
5. the assistant answer commits once below the work disclosure
6. later refreshes update content in place and never reorder prior turns

The architectural decision is:

- MoonClaw is the sole durable owner of the canonical MoonCode conversation.
- MoonLib owns the shared typed conversation contract.
- MoonDesk proxies and renders MoonClaw's canonical conversation. It does not
  rebuild a competing conversation from command, event, receipt, or stream
  logs.
- The browser owns only an unacknowledged optimistic user turn and local
  presentation state such as whether a disclosure is open.

## Historical Failure Analysis

The following findings describe the pre-upgrade implementation that motivated
this plan. They are retained as architectural rationale and regression context;
they are not descriptions of the current production path.

### 1. There are two canonical conversation projectors

MoonClaw builds `mooncode_conversation` in
`cmd/daemon/mooncode_conversation_projection.mbt`. MoonDesk separately builds
the same shape in `internal/mooncode/conversation_projection.mbt`.

`internal/mooncode/session_summary.mbt` accepts MoonClaw's supplied
conversation only when MoonDesk's local projection has no turns. If local
events produce a turn, MoonDesk overwrites the MoonClaw conversation. This
makes ownership conditional on timing and available data rather than explicit.

The existing test named "lets durable events override incomplete supplied
conversation" encodes this dual-owner behavior. That test should be removed;
the new contract should reject or diagnose an invalid MoonClaw conversation,
not silently replace it with a second implementation.

### 2. MoonDesk merges sources, not one ordered log

`internal/mooncode/event_log.mbt` merges arrays in source-group order:

1. projected/session events
2. inline command events
3. durable events

It deduplicates by event id but does not assign or validate one contiguous
session sequence across those sources. The conversation projector then replays
that merged array on every read.

OpenSeek instead gives every durable session event a contiguous one-based
sequence and rejects gaps, duplicates, stale snapshots, and reordered logs.
The important property is not "event sourced" by itself; it is one owner and
one total order.

### 3. Reasoning deltas are incorrectly treated as transcript rows

`internal/mooncode/conversation_projection.mbt` classifies both
`reasoning_delta` and `reasoning_message` as visible progress. Every event is
appended to `turn.progress`.

The UI then:

- converts every progress object into a generic `Progress` activity
- scans the flattened transcript to find an assistant after each activity
- changes running activity to done in the browser
- compacts adjacent completed thinking rows into `Prepared the response`

This is semantic repair in the renderer. It explains repeated thinking rows,
late collapse, generic copy, and visible replacement when a reply arrives.

### 4. The event names do not describe their actual semantics

MoonClaw's native planner currently emits one structured planner summary per
step using the name `reasoning_delta`. The payload is not a token delta; it is a
complete statement such as a selected-tool summary. Treating it as an
appendable text delta creates the wrong reducer behavior.

Likewise, `assistant_delta` can represent model-step content rather than a
strict token delta. The contract does not state whether a payload means
append, replace, or commit.

### 5. Polling hydrates far more data than the UI needs

During active work, the browser polls every 750 ms and requests both:

- the global session collection using the default `format=full`
- the selected session using `format=chat`

The full collection route hydrates local sessions and fetches every native
MoonClaw session conversation before sorting the rail. This repeats work for
the selected session and makes rail refresh cost grow with all sessions and all
logs, even though the rail needs only id, title, scope, status, and timestamp.

### 6. MoonClaw's JSONL append was a full-file rewrite

`cmd/daemon/mooncode_session_store.mbt::mooncode_append_jsonl` previously read
the whole file, concatenated one line, and rewrote the whole file for each
command, event, or receipt. There was no file lock at that write boundary.

That was O(n) I/O per append and O(n^2) over a growing session, with a
concurrent lost-update window. The replacement uses a locked O_APPEND write
and trims only an incomplete tail before appending the next record.

## What To Copy From Latest OpenSeek

The useful OpenSeek behavior is a state-transition model, not its terminal
styling.

- `SessionEvent.sequence` defines one durable order.
- `SessionStore::append` locks the session, rejects stale snapshots, assigns the
  next sequence, and appends one JSONL line.
- `assistant_delta` updates a transient live preview and does not append a
  transcript item.
- the first assistant content clears the live thinking preview.
- `reasoning_message` commits one thought item before `assistant_message`.
- the committed assistant message clears all transient previews.
- transcript items are appended once; live activity is separate state.

One latest OpenSeek detail matters for MoonCode: commit `a85d568` intentionally
stopped logging streaming `reasoning_delta` payloads from the agent. The TUI
still understands them, but the normal producer emits the final
`reasoning_message` and assistant deltas. MoonCode should therefore not build
its product UX around exposing raw model reasoning tokens. Live user feedback
should primarily come from structured work evidence: planning started, context
checked, tool running, files edited, tests completed, and answer streaming.

## Target Contract

The fresh contract should replace generic `progress[]` and duplicated `items[]`
with three stable turn slots: user, work, and assistant.

```json
{
  "contract_id": "moonsuite-conversation.v2",
  "session_id": "session-...",
  "revision": 17,
  "last_sequence": 42,
  "turns": [
    {
      "turn_id": "turn-...",
      "client_turn_id": "client-turn-...",
      "command_id": "command-...",
      "ordinal": 1,
      "status": "queued|running|done|failed|cancelled",
      "user": {
        "item_id": "turn-...:user",
        "content": "Fix the conversation order",
        "status": "accepted"
      },
      "work": {
        "item_id": "turn-...:work",
        "status": "idle|running|done|failed",
        "summary": "Checked the code and updated the renderer",
        "steps": [
          {
            "step_id": "tool-call-...",
            "kind": "thought|context|tool|edit|test|artifact|status",
            "summary": "Checked the transcript projection",
            "detail": "Optional user-facing detail",
            "status": "running|done|failed"
          }
        ],
        "live": {
          "kind": "none|thinking|working|answering",
          "step_id": "tool-call-...",
          "summary": "Checking the transcript projection",
          "preview": "Bounded, user-safe live preview"
        }
      },
      "assistant": {
        "item_id": "turn-...:assistant",
        "content": "The final answer",
        "status": "streaming|done|failed"
      }
    }
  ]
}
```

Contract rules:

- `revision` and `last_sequence` never decrease.
- `ordinal` is assigned once when the prompt is accepted.
- `turn_id`, `item_id`, and `step_id` never change after assignment.
- the top-level visual order is always user, work, assistant.
- a turn has at most one top-level work disclosure and one assistant message.
- repeated evidence updates an existing step by `step_id`; it does not append a
  duplicate top-level row.
- raw provider reasoning is not required by the public contract.
- `live.preview` is bounded and user-safe. It is not model history and need not
  be durable after the turn closes.
- diagnostics, receipts, raw tool JSON, stdout/stderr, command ids, and runtime
  lifecycle records stay outside user-facing copy.

MoonLib should own concrete MoonBit DTO types for this contract, not only arrays
of role and field-name strings. MoonClaw and MoonDesk both inspect and construct
these values, so the public concrete types belong in the shared public package.

## Canonical Reducer Rules

MoonClaw applies these rules in session-sequence order:

| Input | Canonical effect |
|---|---|
| prompt command | append one turn and assign ordinal |
| runtime/planner started | set work to running; do not append a transcript row |
| structured planner step | upsert one work step by planner step id |
| raw reasoning delta | update a bounded transient preview only, or suppress |
| reasoning message | commit/upsert one folded thought step for that model step |
| tool call | append one tool step keyed by tool call id |
| tool result | update the matching tool step in place |
| file/test/artifact evidence | append or update one typed step by evidence id |
| assistant delta | update assistant streaming preview and clear thinking preview |
| assistant message/finish | commit assistant once, clear live state, close work |
| failure/cancel | close live state and commit one owned terminal result |
| duplicate event id | no-op |
| unowned visible event | diagnostic contract failure; never attach to latest turn |

`runtime.turn_started` is evidence that work began, not a durable user-facing
step. `reasoning_delta` from the current MoonClaw planner should be renamed or
normalized as a structured planner-step summary because it is not a text delta.

## Update Stages

### Stage 0 - Freeze The Invariants And Capture The Failure

Work:

- Add a short architecture test that fails if both MoonClaw and MoonDesk remain
  production owners of `mooncode_conversation`.
- Add a browser trace sampler that records ordered `turn_id`, `item_id`, status,
  and visible text after every DOM change during first, second, and third sends.
- Record baseline timings for optimistic append, command acknowledgement, first
  real work evidence, first assistant text, and final commit.
- Preserve the current failing trace as a test fixture, not as compatibility
  behavior.

Exit gate:

- the failing behavior is reproducible through real keyboard typing and Enter
- the trace identifies whether a change is append, update-in-place, removal, or
  reorder
- no internal-message injection is used for the browser gate

### Stage 1 - Publish MoonLib Conversation V2

Work:

- Add concrete public `Conversation`, `Turn`, `Message`, `Work`, `WorkStep`, and
  `LiveActivity` types to `vectie/moonlib/conversation`.
- Add status and kind validation without product-specific MoonClaw vocabulary.
- Add JSON encode/decode and invariant checks for ids, ordinals, revision, and
  fixed slot order.
- Keep product-specific event normalization in MoonCode/MoonClaw.
- Update MoonCode core to delegate the shared contract to MoonLib v2.

Exit gate:

- round-trip tests preserve every stable id and ordinal
- malformed decreasing revisions, duplicate ordinals, and duplicate item ids
  are rejected
- MoonLib contains no MoonClaw endpoint, tool, or runtime-event names

### Stage 2 - Replace MoonClaw Storage With One Ordered Session Timeline

Work:

- Introduce a single typed session timeline with a contiguous sequence for
  prompt, work, assistant, terminal, control, and diagnostic records.
- Use a per-session lock and stale-sequence check for every append.
- Use O_APPEND for the normal path; use atomic full rewrite only to repair a
  torn final record.
- Reject sequence gaps, duplicates, and stale writers on load/append.
- Keep commands, receipts, and diagnostics as typed record kinds or derived
  indexes instead of independent chat-order authorities.
- If separate operational files remain temporarily, they must not participate
  in canonical conversation ordering.

Primary MoonClaw files:

- `cmd/daemon/mooncode_session_store.mbt`
- `cmd/daemon/mooncode_persistence.mbt`
- `cmd/daemon/mooncode_runtime_turn.mbt`
- `cmd/daemon/mooncode_runtime_service.mbt`
- `cmd/daemon/mooncode_runtime_claims.mbt`

Exit gate:

- concurrent append tests cannot lose or duplicate records
- a 1,000-record session appends one new record without reading/re-writing the
  whole log
- torn-tail recovery keeps committed records and appends the next sequence
- session replay is byte-for-byte deterministic

### Stage 3 - Make MoonClaw The Only Conversation Reducer

Work:

- Rewrite `cmd/daemon/mooncode_conversation_projection.mbt` around the v2 turn
  reducer and one ordered timeline.
- Add stable `revision`, `last_sequence`, ordinal, item ids, and step ids.
- Normalize current planner `reasoning_delta` records into structured planner
  steps rather than generic transcript progress.
- Treat true raw reasoning deltas as transient preview only or suppress them,
  matching the latest OpenSeek producer behavior.
- Upsert tool call/result pairs by tool call id.
- Close work state in MoonClaw when assistant/failure/cancel commits; do not ask
  the browser to infer completion by scanning later rows.
- Return the canonical v2 conversation from native list/show/command responses.

Primary MoonClaw files:

- `cmd/daemon/mooncode_conversation_projection.mbt`
- `cmd/daemon/mooncode_runtime_planner_events.mbt`
- `cmd/daemon/mooncode_session_store.mbt`
- `cmd/daemon/mooncode_stream.mbt`

Exit gate:

- multiple reasoning updates produce one work disclosure
- reasoning commit precedes assistant commit within the owning turn
- assistant delta updates one preview and final assistant replaces it in place
- replay after restart returns identical ids, ordinals, revision, and content
- same-content prompts remain separate turns by identity

### Stage 4 - Cut MoonDesk Back To A Proxy And Listing Consumer

Work:

- Make the session rail request `format=listing` and decode a dedicated listing
  type that has no conversation payload.
- Fetch only the selected session's canonical conversation.
- Preserve MoonClaw's supplied conversation unconditionally after session-id and
  contract validation.
- Remove the rule that lets local durable events override a supplied native
  conversation.
- Remove native chat projection from MoonDesk command/event/receipt merges.
- Keep raw event endpoints and projections only for explicit diagnostics,
  readiness, and operator evidence.
- Split rail refresh cadence from selected-conversation refresh cadence.

Primary MoonDesk files:

- `internal/moonwiki/mooncode_sessions.mbt`
- `internal/moonwiki/mooncode_session_projection.mbt`
- `internal/mooncode/session_summary.mbt`
- `internal/mooncode/conversation_projection.mbt`
- `ui/rabbita-desk/main/mooncode_session_fetch_commands.mbt`
- `ui/rabbita-desk/main/mooncode_session_effects.mbt`

Deletion target:

- delete the MoonDesk production conversation projector after local-only
  fixtures are moved to MoonClaw/shared contract tests
- delete tests that authorize MoonDesk to repair or override MoonClaw chat
- retain event-log utilities only where diagnostics still consume them

Exit gate:

- the rail request never hydrates conversation turns
- the selected chat request performs one MoonClaw canonical read
- MoonDesk cannot produce a different assistant/work order from MoonClaw
- MoonClaw unavailable is shown as a factual error, not a locally fabricated
  working state

### Stage 5 - Render Stable Turn Slots Directly

Work:

- Decode MoonLib v2 types instead of local JSON progress objects.
- Render each turn as one keyed container with keyed user, work, and assistant
  children.
- Keep the optimistic user row keyed by `client_turn_id`; replace it only when
  the canonical turn with that id arrives.
- Remove browser functions that fold, resolve, compact, or sanitize canonical
  thinking rows after the fact.
- Render one work disclosure per turn. While running it is open and shows the
  current safe live summary; when resolved it folds but remains reviewable.
- Preserve native `<details>` open state across unrelated polling updates by
  keeping the same `item_id` key.
- Use distinct visual treatment for context, tool, edit, test, artifact, and
  failure steps inside the disclosure without creating multiple top-level chat
  rows.
- Announce live-status changes through a polite ARIA live region without
  repeatedly reading the entire transcript.

Primary MoonDesk files:

- `ui/rabbita-desk/main/mooncode_model.mbt`
- `ui/rabbita-desk/main/mooncode_canonical_transcript.mbt`
- `ui/rabbita-desk/main/mooncode_transcript_views.mbt`
- `ui/rabbita-desk/main/mooncode_activity_views.mbt`
- `ui/rabbita-desk/main/mooncode_views.mbt`
- `ui/rabbita-desk/styles/mooncode.css`

Deletion target:

- `mooncode_fold_resolved_thinking_items`
- `mooncode_compact_folded_thinking_items`
- frontend internal-wording heuristics used to repair backend progress
- generic `Progress / Prepared the response` synthesis

Exit gate:

- a running turn has exactly one top-level work row
- completed work is folded between its user and assistant rows
- opening one historical work disclosure stays open when another turn updates
- no DOM update removes or re-inserts a previously committed turn

### Stage 6 - Canonical Revision Transport And Performance

Work:

- Add an ETag or `since_revision` contract to selected-session chat reads.
- Return unchanged/304 when the canonical revision has not advanced.
- Poll only the selected conversation at a fast cadence while its turn is
  running; use a slower rail/idle cadence.
- Target 250-500 ms evidence-to-screen latency without fetching raw events.
- Optionally use long polling for revision changes. A push transport may signal
  "revision changed," but it must never carry an alternate raw-event transcript
  into the renderer.
- Bound live previews and response sizes.

Exit gate:

- idle polls do not parse full session histories
- active polling does not fetch all session conversations
- an unchanged poll causes no transcript DOM mutation
- a newer revision updates only keyed content/status inside the owning turn

### Stage 7 - End-To-End, Visual, Recovery, And Cleanup Gate

Run the final gate from a fresh MoonSuite test area under
`~/moonsuite/.tmp/mooncode-e2e/<run-id>` and remove it after success.

Real UI workflow:

1. start a fresh MoonClaw and MoonDesk
2. open Code mode in the in-app browser
3. click New chat
4. type and send the first prompt with the keyboard
5. type and send second and third prompts the same way
6. expand and collapse completed work with mouse clicks
7. hard reload
8. switch to another session and back
9. restart MoonClaw and reload the same session

Assertions:

- each prompt is visible within 50 ms of the Enter event
- prior row-id order is a prefix of every later sampled row-id order
- a turn may update text/status in place but may not move
- one canonical turn acknowledges each `client_turn_id`
- one work disclosure exists between each user and assistant
- live work appears only after real MoonClaw evidence
- assistant streaming replaces thinking preview in place
- final assistant content commits once
- no internal runtime/debug text appears
- no front page flashes after a prompt is accepted
- no old turn disappears after poll, reload, session switch, or daemon restart
- rail groups and ordering remain stable while selected chat updates

Coverage layers:

- MoonLib contract round trips and invalid-contract rejection
- MoonClaw store locking, sequence, idempotency, and torn-tail recovery
- MoonClaw reducer state transitions and replay
- MoonDesk route pass-through and listing/detail separation
- frontend optimistic acknowledgement and stale-revision rejection
- real browser keyboard/mouse timeline sampler
- desktop screenshots at wide desktop, narrow desktop, and mobile width
- reduced-motion and keyboard-focus checks for the work disclosure

After each implementation stage, rebuild and reopen the latest MoonDesk app in
the in-app browser so the user can inspect the actual surface.

## Quantitative Completion Metrics

Correctness:

- 0 duplicate `turn_id`, `item_id`, or `step_id` values
- 0 decreasing revisions or sequences
- 0 sampled reorder/removal events across three-turn browser tests
- 0 raw diagnostic events rendered as chat
- 100% optimistic rows acknowledged only by matching `client_turn_id`

Latency:

- Enter to optimistic user row: p95 <= 50 ms
- local submit acknowledgement: p95 <= 300 ms
- MoonClaw evidence append to visible work update: p95 <= 500 ms
- assistant delta append to visible preview: p95 <= 500 ms

Efficiency:

- normal session append performs O(1) log growth
- rail polling reads listing metadata only
- selected-session polling parses or returns one canonical projection only
- unchanged revisions produce no transcript DOM mutation

Durability:

- 100 repeated restart/replay cycles preserve the same canonical projection
- concurrent append stress has no lost, duplicated, or non-contiguous records
- torn final JSONL line recovery preserves every committed prior sequence

## Explicit Non-Goals

- Do not expose raw model chain-of-thought as a requirement for live UX.
- Do not restore browser-side raw stream/event transcript rendering.
- Do not keep two projectors for compatibility.
- Do not use content equality to acknowledge prompts or pair replies.
- Do not let session-list data replace selected-session detail.
- Do not add another generic "working" row before MoonClaw evidence exists.
- Do not continue the old numbered phase sequence; this plan closes one named
  architectural workstream.

## Recommended Execution Order

Implement Stage 0 and Stage 1 first so every later change is checked against a
shared invariant. Then land MoonClaw storage and reducer work together before
deleting the MoonDesk projector. Cut the host and UI over in one bounded
vertical slice, and finish with the real browser/restart gate before removing
the old tests and files.

The critical dependency chain is:

`MoonLib v2 contract -> MoonClaw ordered store -> MoonClaw reducer -> MoonDesk
proxy -> keyed UI -> real browser gate -> stale-code deletion`.
