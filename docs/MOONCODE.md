# MoonCode Workspace

MoonCode is the coding conversation mode for a MoonBook. The product has one
ordered conversation, one durable owner, and one desktop projection:

```text
MoonDesk UI -> MoonDesk adapter -> MoonClaw canonical session -> MoonBook files
```

MoonDesk does not reconstruct chat from runtime events, local command queues,
receipts, or artifact logs.

## Product Boundary

MoonDesk owns the desktop experience:

- select a MoonBook or General session
- append an optimistic user row immediately after submit
- render the canonical turn list returned by MoonClaw
- keep local presentation state such as the selected session and disclosure
  openness
- proxy session mutations and selected-session watches

MoonClaw owns execution and durable conversation state:

- session identity and metadata
- command intake, model loops, and tool execution
- ordered user, work, and assistant records
- durable tool-approval decisions, live task cancellation, failure, and
  recovery state
- the authoritative per-session journal and replaceable checkpoint

MoonBook owns the files and accepted outputs changed by a coding session.
MoonLib owns the shared, versioned MoonSuite and conversation-journal
contracts. MoonGate may measure those contracts but does not own them.

## Non-Negotiable Rules

1. MoonClaw is the only durable session and conversation owner.
2. The UI renders `mooncode_conversation.turns` in canonical order.
3. A listing refresh updates metadata; it never replaces a newer selected
   conversation with a compact row.
4. A lower or unchanged revision cannot replace the displayed revision.
5. The optimistic user row is local only until a canonical turn acknowledges
   its `client_turn_id` or content identity.
6. A queued command is not evidence of active work. Work UI begins only after
   MoonClaw publishes a command-owned work signal.
7. Runtime events are inputs to MoonClaw's reducer. MoonDesk never merges raw
   events into chat.
8. Reconnect preserves the last accepted conversation and resumes from the
   last accepted revision and sequence.
9. Session rail ordering comes from the MoonClaw listing and remains stable
   while a selected session is hydrated.
10. New features must extend the canonical contract or renderer; they must not
    add a second store, replay engine, or projection reducer in MoonDesk.
11. Approval and cancellation commands are control-plane records, not chat
    turns. Approval renders as a stable work step inside its owning turn.
12. Stop is offered only for canonical unfinished work and must interrupt the
    MoonClaw task; desktop timers or optimistic state cannot claim cancellation.
13. Stop names the canonical target command. A stale listing cannot retarget
    cancellation or navigate away from the selected canonical conversation.

## Runtime Controls

MoonLib publishes `moonsuite-conversation-control.v1`. MoonClaw consumes that
contract and owns the complete control lifecycle:

```text
tool proposed
-> durable approval request in the owning turn
-> hidden MoonClaw continuation checkpoint stores plan and completed results
-> operator approves or rejects
-> the live task or a fresh MoonClaw daemon resumes the original plan and tool
   call

Stop
-> hidden cancel command naming the canonical target command
-> active task and child process are cancelled
-> durable turn-cancelled event and terminal receipt
```

MoonDesk renders pending approval between the user message and final assistant
reply. It submits the decision using the stable approval, command, and tool-call
identifiers already present in canonical evidence. It does not execute tools,
infer decisions, create a separate approval conversation, or reorder turns.
Daemon restart recovery requires no desktop replay state: MoonDesk retains the
last canonical list and submits the same visible decision after MoonClaw returns.

## Source Layout

```text
mooncode/core
  Shared protocol, action, tool, capability, watch, and journal contracts.

internal/mooncode
  Thin, filesystem-neutral adapter:
  - adapter_protocol.mbt
  - adapter_capabilities.mbt
  - adapter_commands.mbt
  - adapter_sessions.mbt
  - adapter_json.mbt

internal/moonwiki
  HTTP routing, MoonClaw process/probe integration, workspace lookup, and
  canonical response shaping.

ui/rabbita-desk/main
  Session rail, canonical transcript, optimistic rows, selected-session watch,
  composer, and presentation state.
```

`internal/mooncode` deliberately does not contain a session store, command or
event JSONL writer, runtime supervisor, replay queue, receipt reducer, action
plan engine, or chat merger. Those responsibilities were retired after the
MoonClaw journal cutover.

## Desktop API

The active desktop surface contains six route contracts:

```text
GET|HEAD  /api/mooncode/status
GET|HEAD  /api/mooncode/capabilities
GET|HEAD  /api/mooncode/sessions
POST      /api/mooncode/sessions
GET|HEAD  /api/mooncode/sessions/<session-id>
GET|HEAD  /api/mooncode/sessions/<session-id>/watch
POST      /api/mooncode/sessions/<session-id>/commands
```

The watch query carries `since_revision` and `since_sequence`. The endpoint
returns a snapshot only when canonical state changed; heartbeats and retry
guidance do not mutate the transcript.

The listing form is metadata-only:

```text
GET /api/mooncode/sessions?format=listing
```

Every listing row is a complete compact `MoonCodeSession` record. Required
fields include identity, MoonBook identity, cwd, title, model, status,
`queued_count`, runtime session identity, and a compact `mooncode_summary`.
Malformed rows are filtered at the adapter boundary. A transport or decode
failure is not converted to a successful empty catalog.

## Native MoonClaw API

MoonDesk consumes MoonClaw's capability-advertised native routes. The current
session flow is:

```text
list sessions   -> native session listing
read session    -> native session show
submit turn     -> /v1/code/sessions/<id>/turns
watch progress  -> native canonical stream/session record
```

A desktop command body contains only canonical fields consumed by MoonClaw:
protocol, action, text, model, session id, book root, context path, payload,
packet, web-search choice, and runtime tool calls. MoonDesk does not send a
second result contract, replay policy, or local tool-authorization document.

## Canonical Conversation

Each session exposes one `moonsuite-conversation.v2` conversation. A turn has
stable command, client-turn, and turn identities plus three ordered slots:

```text
user -> work -> assistant
```

Slots may be absent until MoonClaw commits them. The UI never moves a slot to a
different turn and never sorts transient records independently from the
canonical turn array.

The selected-session state machine is:

```text
submit
  -> append optimistic user row
  -> send one durable turn mutation
  -> watch selected canonical revision
  -> reconcile acknowledged optimistic row
  -> render canonical work and assistant slots in place
```

Completed work remains between the user message and assistant answer and uses
native disclosure semantics. The collapsed summary is concise user-facing
progress; low-level protocol diagnostics stay outside ordinary chat.

## Session Rail

Sessions are grouped by durable MoonBook identity. Sessions without a known
MoonBook belong to General. The listing order supplied by MoonClaw is preserved
within each group, with stable identity used as the tie breaker at the source.

Selecting a rail row hydrates that session without changing rail order. A
metadata refresh cannot clear an active draft, replace a selected transcript
with a compact row, or manufacture a new selection. A fresh browser load must
decode the listing before showing a zero-session empty state.

## Durability

Each MoonClaw session has one authoritative journal:

```text
<moonclaw-product-home>/sessions/<session-id>/
  journal.jsonl
  session.json
```

`journal.jsonl` uses the MoonLib
`moonsuite-conversation-journal.v1` envelope and owns total order.
`session.json` is a replaceable checkpoint. MoonDesk may display the journal
path and sequence for diagnostics, but it cannot read storage artifacts to
rebuild a conversation.

## Failure Behavior

- MoonClaw unavailable: keep the last good transcript and show an actionable
  connection state.
- Listing unavailable: preserve the last good rail; do not display zero as a
  successful result.
- Watch interruption: retain the accepted revision and reconnect with bounded
  backoff.
- Mutation failure: mark the matching optimistic row failed without removing
  prior turns.
- Stale response: ignore it.
- Unknown or malformed session: reject it at the boundary and expose a
  diagnosable error rather than silently changing selection.

## Validation

Code changes must pass:

```sh
moon fmt
moon info
moon check --target all --warn-list +73
moon test --target native
(cd ui/rabbita-desk && moon test --target js)
npm --prefix ui/rabbita-desk run build
git diff --check
```

Acceptance also requires a visible browser journey using real keyboard and
mouse input:

1. Open a fresh Code view and confirm persisted sessions hydrate.
2. Start or select a MoonBook-bound session.
3. Submit with the mouse and with Enter.
4. Confirm the user row appears immediately without a fabricated work state.
5. Confirm factual work appears only after MoonClaw signals it.
6. Confirm every turn remains `user, work, assistant` in append order.
7. Continue for at least four turns.
8. Hard reload and verify the same rail selection and conversation.
9. Repeat across MoonClaw restart and network interruption for release gates.

## Remaining Product Work

The storage, conversation ownership, approval, and live-cancellation upgrades
are complete. Remaining work is product capability, not another architecture
rewrite:

- richer permission, context-loss, and offline recovery
- durable per-session model and web-search preferences
- session rename, archive, delete, and search
- large-history virtualization and performance metrics
- automated latency, duplicate-row, rollback, reconnect, accessibility, and
  responsive release gates

The finite delivery order and evidence are tracked in
`MOONCODE_PRODUCTION_UPGRADE_PLAN.md`.
