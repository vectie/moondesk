# MoonCode Workspace

This document describes the current desktop/runtime ownership boundary. The
discussion baseline is [Current MoonCode plan](mooncode-discussion-2026-11-04/CURRENT_PLAN.md).
The single-agent consolidation removes the separate Goal panel and desktop
package-review/proof-gate inference. The runtime completion boundary is described
in MoonClaw's `docs/executable_book_runtime_boundary.md`.
The legacy nine-step lifecycle report is also removed from capabilities and
session listings. MoonDesk uses the canonical conversation and runtime receipts;
ordinary work does not become blocked because it has no review or package.
The [discussion archive](mooncode-discussion-2026-11-04/README.md) retains the
original comparisons, revisions, and decisions.

MoonCode is the coding conversation mode for a MoonBook. The product has one
ordered conversation, one durable owner, and one desktop projection:

```text
MoonDesk UI -> MoonDesk adapter -> MoonClaw canonical session -> MoonBook files
```

MoonClaw must remain a standalone agent runtime; MoonDesk consumes its typed
surface and does not make it desktop-private. MoonDesk does not reconstruct
chat from runtime events, local command queues, receipts, or artifact logs.

## Shared Runtime, Separate Lanes

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

The desktop session surface is:

```text
GET|HEAD  /api/mooncode/status
GET|HEAD  /api/mooncode/capabilities
GET|HEAD  /api/mooncode/sessions
POST      /api/mooncode/sessions
GET|HEAD  /api/mooncode/sessions/<session-id>
GET|HEAD  /api/mooncode/sessions/<session-id>/watch
POST      /api/mooncode/sessions/<session-id>/commands
POST      /api/mooncode/sessions/<session-id>/lifecycle
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

Active and archived catalogs are separate metadata-only reads:

```text
GET /api/mooncode/sessions?format=listing&scope=active
GET /api/mooncode/sessions?format=listing&scope=archived
```

Lifecycle mutations use one typed command boundary. Supported actions are
`rename`, `archive`, `restore`, and `delete`. MoonClaw owns every storage
transition, persists custom titles in the session snapshot, rejects destructive
changes while work is running, and never deletes MoonBook content when a
session is deleted.

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

Search filters the already-loaded metadata catalog without fetching or
reordering conversations. Rename is inline. Archive removes an active row and
clears selection when necessary; restore returns it to its durable source
order. Permanent delete requires explicit confirmation. Archived sessions live
in a separate disclosure and are never mixed into the active groups.

## Durability

Each MoonClaw session has one authoritative journal:

```text
<moonclaw-product-home>/mooncode/sessions/<session-id>/
  journal.jsonl
  session.json
```

`journal.jsonl` uses the MoonLib
`moonsuite-conversation-journal.v2` envelope with exact decimal sequences and
owns total order. Existing v1 journal reads remain a shared storage concern.
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

Use focused checks for the packages affected by a change. MoonBit changes also
require `moon info`, `moon fmt`, and review of generated interface differences.
The repository release gate is `scripts/validate.sh full`; it is not an
authoring check for documentation-only edits.

For changes to conversation behavior, exercise real keyboard and mouse input,
multiple turns, reload, reconnect, and cancellation. Verify stable
`user -> work -> assistant` ordering, truthful progress, and preservation of
the last accepted state. The focused scenarios and validation entry points
are in [Code mode test plan](CODE_MODE_TEST_PLAN.md).

## Current Implementation

The [discussion plan](mooncode-discussion-2026-11-04/CURRENT_PLAN.md) is the
historical design baseline. Its main consolidation is implemented through the
existing MoonClaw runtime:

1. Goal state machines and dual authority are removed.
2. `finish` owns completion; repairable gaps return to the same primary agent.
3. Native verification receipts and tracked input versions support completion;
   journal checkpoints retain execution intent and completed-result references.
4. Forced-mutation rules, permissive tool-call repair and duplicate acceptance
   projections are removed.
5. Native tools use one catalog. Read-only subsets and explicit tool selection
   remain; keyword bundles and native search-to-load trial state are removed.

Progress checkpoints remain advisory throughout execution. Empty model
follow-ups retain the existing claim and completed results for automatic
continuation, without requiring milestones to be present or marked done.
MoonDesk displays those runtime facts rather than deciding whether a plan
permits recovery or completion.

Default to one primary agent and autonomous completion. Do not introduce a
permanent Router/Worker agent pair, a new runtime framework, a universal
checker registry, or mandatory human review. Existing authorization and
sandbox boundaries remain enforced. No old-protocol compatibility or
dual-write implementation is required.

This describes source behavior. It does not claim installed-app deployment or
live-model delivery quality. Dated test reports remain historical evidence;
current readiness requires current checks.
