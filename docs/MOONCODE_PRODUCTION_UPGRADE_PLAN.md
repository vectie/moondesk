# MoonCode Production Upgrade Plan

Status: active. This is a finite seven-milestone program. It replaces open-ended
phase numbering and treats MoonClaw's canonical conversation as the only chat
state that Moondesk may render.

## Product Outcome

MoonCode should behave like a dependable coding conversation, not an event
console:

1. A submitted user message appears immediately and never disappears.
2. MoonClaw owns one append-ordered canonical conversation per session.
3. Work appears only after MoonClaw reports real work, in the owning turn.
4. Live work updates one stable slot; it never inserts above an older turn.
5. Completed work remains available as one collapsed disclosure with a useful
   summary.
6. The assistant answer appears once below that work and survives refresh,
   reconnect, daemon restart, and later turns.
7. The session rail is MoonBook-grouped, stable, and independent from chat
   hydration.

The primary user question on the Code screen is: "What did I ask, what is the
agent doing, and what did it answer?" Diagnostics, storage records, raw events,
and runtime topology do not belong in the ordinary transcript.

## Non-Negotiable Architecture

```text
user input
    |
    v
optimistic user row in Moondesk
    |
    v
MoonClaw command append -> canonical reducer -> canonical conversation revision
                                                |
                                                v
                                   Moondesk snapshot/subscription
                                                |
                                                v
                                      keyed turn renderer
```

- MoonClaw is the sole durable conversation owner and reducer.
- MoonLib owns the shared versioned contract and validation rules.
- Moondesk owns only optimistic, not-yet-acknowledged user rows and local UI
  state such as disclosure openness.
- Session listings contain metadata only. They cannot replace selected chat
  content.
- Raw command, event, and receipt logs are diagnostic inputs to MoonClaw. They
  are never merged in the browser and never rendered as chat rows.
- A canonical revision is monotonic. A response with revision less than or
  equal to the displayed revision cannot replace the displayed conversation.
- A queued command is not evidence that work started. Work UI begins only from
  a MoonClaw runtime event.

## Baseline Risks

The OpenSeek comparison shows a mature state-transition core: one ordered
journal, sequence validation, transient deltas, and committed transcript
items. Orca adds mature reconnect behavior, product workflows, and broad
integration coverage. MoonCode already has the correct v2 ownership boundary,
but its visible product remains vulnerable at the transport and merge edges:

- selected-session responses can complete out of order;
- a lower revision has been allowed to overwrite a higher revision;
- mutation responses and polling responses use different merge paths;
- listing refresh and chat hydration are still too closely coupled;
- polling transfers an unchanged conversation repeatedly;
- queued work currently looks like active agent work;
- custom document listeners duplicate native disclosure behavior;
- the coding surface lacks mature answer, diff, approval, recovery, and session
  management workflows;
- release confidence depends on manual local runs because hosted CI is
  intentionally disabled.

## Milestone A: Monotonic Conversation Boundary

Goal: make disappearing and reordered turns structurally impossible at the UI
boundary.

Deliverables:

- Reject equal, lower, missing, or explicitly unchanged canonical snapshots
  when a selected session already has a positive revision.
- Apply the same rule to polling, create responses, and command responses.
- Preserve the selected canonical conversation when metadata listings refresh.
- Add `since_revision` to selected-session reads and return a compact unchanged
  response when the revision matches.
- Keep rail ordering stable during chat hydration.
- Add tests for lower-revision polling, delayed mutation responses, unchanged
  responses, listing refresh, and cross-session responses.

Exit criteria:

- Three or more rapid turns never lose rows under deliberately reversed HTTP
  completion order.
- The rendered revision never decreases.
- An unchanged poll transfers no turns and causes no transcript mutation.

## Milestone B: Truthful Live Work

Goal: show fast feedback without pretending that MoonClaw is active.

Deliverables:

- Render the optimistic user row immediately after Enter or Send.
- Show no work row while the command is merely queued.
- Create the work slot only from a planner, reasoning, tool, edit, test, or
  other real runtime event owned by the command id.
- Update live work in place and commit bounded, user-facing steps.
- Keep raw reasoning tokens and low-level protocol diagnostics out of chat.
- Use native `details`/`summary` semantics for completed work and retain open
  state across canonical refreshes.
- Announce factual asynchronous status changes through an appropriate polite
  live region without moving keyboard focus.

Exit criteria:

- Queued, running, answering, failed, cancelled, and completed states are
  visually and semantically distinct.
- No spinner or "working" copy appears without a MoonClaw runtime signal.
- Tab, Enter, and Space operate the disclosure in visual order.

## Milestone C: Resumable Canonical Transport

Goal: replace repeated fast snapshots with one bounded selected-session
watcher.

Deliverables:

- Define a canonical subscription response in MoonLib: current snapshot,
  revision, heartbeat, terminal state, and retry guidance.
- Keep exactly one watcher for the selected session and cancel it on selection
  change or component teardown.
- Resume from the last accepted revision after network interruption.
- Coalesce intermediate live updates while never coalescing committed turns.
- Use slow metadata refresh only for the rail; do not hydrate all chats.
- Expose reconnecting and failed states without clearing the last good
  conversation.

Exit criteria:

- One selected session creates at most one active canonical request.
- Reconnect resumes without duplicates, gaps, reorder, or blank-page flashes.
- Idle network cost is independent of transcript length.

## Milestone D: One Transactional MoonClaw Journal

Goal: give every command, runtime transition, work item, and answer one total
order at the source.

Deliverables:

- Replace fragmented ordering assumptions with one session sequence allocator.
- Append under a session lock, repair torn tails, and reject stale snapshots.
- Give every durable record a sequence, command id, client turn id, kind, and
  timestamp.
- Make canonical replay deterministic and side-effect free.
- Persist a compact snapshot checkpoint without weakening journal authority.
- Add corruption, crash, duplicate delivery, concurrent writer, and replay
  equivalence tests.

Exit criteria:

- Sequences are contiguous and unique under concurrent writes.
- Replaying the same journal produces byte-identical canonical JSON.
- A torn final record loses no prior committed record.

## Milestone E: Complete Coding Workflow

Goal: move from reliable chat to a useful coding product.

Deliverables:

- Render assistant Markdown, code blocks, copy actions, links, and long-output
  overflow accessibly.
- Show file edits as reviewable diffs with file identity and applied/pending
  state.
- Support tool approval, cancellation, retry, and actionable failure recovery.
- Keep model and web-search controls compact and persistent per session.
- Make working directory and MoonBook scope visible without consuming the
  transcript.
- Add empty, offline, daemon-starting, permission, and context-loss states.

Exit criteria:

- A user can ask for a change, inspect work, approve when required, review the
  diff, see test evidence, and continue the same conversation.

## Milestone F: Session And MoonBook Information Architecture

Goal: make projects and conversation history predictable.

Deliverables:

- Group sessions under their MoonBook; place unbound sessions in General.
- Keep stable ordering by durable activity timestamp with a session-id tie
  breaker.
- Preserve selection independently from refresh and new-session draft state.
- Add rename, archive, delete, search, and clear recent-history behavior.
- Separate metadata listing state from selected conversation state in the UI
  model.
- Virtualize large histories and avoid hydrating conversations for rail rows.

Exit criteria:

- The user always knows the active MoonBook and selected session.
- Rail refresh never changes selection, flashes groups, or moves unchanged
  sessions.

## Milestone G: Release Evidence And Operations

Goal: turn correctness claims into repeatable evidence.

Deliverables:

- Add a local release-gate command that runs format, check, focused tests, full
  tests, production build, and browser journeys.
- Keep deterministic MoonClaw fixtures for failure injection and run a smaller
  real-daemon journey for final confidence.
- Record latency from submit to optimistic row, first real work, first answer,
  completion, and reconnect recovery.
- Track duplicate-row count, revision rollback count, watcher count, dropped
  optimistic rows, daemon failures, and session-load failures.
- Test keyboard, screen-reader semantics, reduced motion, narrow layout, long
  content, empty/error/loading states, refresh, and daemon restart.
- Re-enable hosted CI only through an explicit repository decision; until then,
  the local release gate is mandatory before push.

Exit criteria:

- Zero revision rollback, duplicate row, missing committed turn, or unexplained
  working-state events in the long-horizon suite.
- Submit-to-optimistic-row p95 is below 100 ms on the local desktop build.
- First factual status is shown within one transport interval after MoonClaw
  emits it.

## End-To-End Test Method

Every journey records five things: what the user sees, why it is shown, what
the user can do, what the user actually does, and the expected durable result.
The browser journey must use visible keyboard and mouse input; internal message
injection is not acceptance evidence.

Required journeys:

1. General new chat, first prompt, real reply.
2. Second through fifth turns while prior work remains folded and ordered.
3. MoonBook-bound chat and General grouping.
4. Rapid submits with reversed response completion.
5. Refresh during queued, running, answering, and completed states.
6. MoonClaw unavailable, starts late, crashes mid-turn, and restarts.
7. Network timeout and reconnect from the last accepted revision.
8. Failed tool, rejected approval, retry, cancel, and successful continuation.
9. Long Markdown answer, code blocks, diffs, and large work history.
10. Keyboard-only and reduced-motion operation at desktop and narrow widths.

For each journey, assert canonical row identity and order after every visible
transition, after idle refresh, after hard reload, and after daemon restart.

## Implementation Record

- 2026-07-14: Milestone A started. The first slice adds monotonic response
  acceptance, revision-aware compact reads, selected-listing preservation, and
  stale-response regression tests.
- 2026-07-14: Milestone B started. Queued commands no longer manufacture a
  work disclosure, and completed disclosures use native browser semantics.
- 2026-07-14: The first A/B production slice passed 532 Moondesk tests, 1,051
  MoonClaw tests, the production UI build, and a visible keyboard-and-mouse
  browser journey covering two new turns plus a three-turn persisted session.
  The browser evidence confirmed immediate optimistic rows, factual work,
  stable user/work/assistant order, native disclosure behavior, and canonical
  completion status in the session rail.
- 2026-07-15: The C/D ownership cutover added MoonClaw's atomic
  `/v1/code/sessions/<id>/turns` transaction and a per-session single-flight
  runtime service. Moondesk now creates, mutates, reads, lists, and watches
  sessions only through MoonClaw canonical records. Its active MoonCode backend
  surface is six routes, and the stale local command, event, session, replay,
  runtime-supervisor, and artifact persistence handlers were deleted.
- 2026-07-15: Cold session listings now retain exact MoonBook identity from a
  durable MoonClaw snapshot and are normalized against Moondesk's actual
  MoonBook catalog. Canonical conversation metadata wins over incomplete
  listing metadata, unbound rows remain in General, and one accepted command is
  counted once across queue and runtime completion.
- 2026-07-15: The ownership cutover gate passed 1,124 MoonClaw tests and 463
  Moondesk tests, both native builds, and a visible browser journey with mouse
  submission, Enter submission, live factual work, two ordered answers, daemon
  restart, hard reload, stable MoonBook grouping, and exact command accounting.
- 2026-07-15: The first Milestone E vertical slice added safe assistant
  Markdown, code-block and answer copy actions, canonical file/command/output/
  test evidence, reviewable diffs, one turn-owned Retry action, and real Stop
  commands. MoonClaw now publishes owner-curated evidence and completes every
  model-selected tool call in a batch before asking the model to continue,
  including when one call fails. Moondesk sends file context only for a real
  selected file, never for a synthetic wiki path.
- 2026-07-15: This slice passed 1,125 MoonClaw tests, 463 Moondesk core tests,
  539 Moondesk UI tests, both native builds, the production browser build, and
  a visible real-daemon journey. Browser evidence covered immediate mouse and
  Enter submission, factual work updates, honest failed-tool evidence, Retry,
  a successful second turn, native disclosure toggling, exact clipboard copy,
  append-only order, and hard-reload persistence.
- 2026-07-15: The selected-session watcher now has one generation-owned
  lifecycle. Ordinary command completion no longer aborts and recreates a
  healthy watch; selection changes create one replacement, and stale responses
  or delayed retry timers cannot revive an older generation. Consecutive
  failures use bounded 500/1,000/2,000/4,000/8,000 ms retry delays, while a
  successful heartbeat resets the failure count and resumes from the last
  accepted revision.
- 2026-07-15: Session-listing transport failure is no longer represented as a
  successful empty catalog. Moondesk returns `503 Service Unavailable` when
  MoonClaw cannot supply the canonical listing, so the UI preserves its last
  good selected transcript and session metadata during an outage. The obsolete
  Moondesk `/stream` and `/stream-state` route constructors were removed; the
  selected conversation uses only the canonical watch contract.
- 2026-07-15: The watcher slice passed 463 Moondesk core tests and 542 UI tests,
  including single-owner, stale-generation, selection replacement, heartbeat,
  bounded-backoff, and outage-preservation coverage. A visible real-daemon
  browser journey submitted with the keyboard, switched sessions with the
  mouse, killed and restarted MoonClaw, and submitted another turn after
  recovery. Every sampled frame retained the optimistic and committed turns;
  no transcript blanking, duplicate answer, or reorder occurred.
- 2026-07-15: Milestone D replaced MoonClaw's split command, receipt, event,
  package, and MoonBook result logs with one locked `journal.jsonl` per
  session. MoonLib `0.1.15` now owns the
  `moonsuite-conversation-journal.v1` envelope and sequence rules; MoonClaw
  owns append, repair, replay, and checkpointing; Moondesk consumes the
  canonical session record without rebuilding logs. Regression coverage now
  includes 1,000-record replay, 64 concurrent cross-lane writers, duplicate
  delivery, torn-tail repair, complete-record corruption and sequence-gap
  rejection, corrupt-checkpoint recovery, and deterministic replay. Final
  gates passed with 1,129 MoonClaw tests, 463 Moondesk native tests, 542
  Moondesk UI tests, both native builds, the production UI bundle, and a
  synchronized MoonCode core interface. A real five-turn keyboard journey
  then proved immediate optimistic insertion, ordered work and answers,
  disclosure behavior, hard-reload persistence, two daemon restarts, and a
  stable first-prompt session title. Its on-disk session contained only
  `session.json` and a 60-record journal with contiguous unique sequences.

## Current Completion And Remaining Order

- Milestone A is complete for the production path: one monotonic canonical
  conversation is accepted by one UI boundary, and stale local merge/replay
  paths are gone.
- Milestone B is complete for the core transcript: optimistic user rows are
  immediate, work is event-backed and turn-owned, completed work folds in
  place, and answers append once below it.
- Milestone C is complete for the production selected-session path. Canonical
  reads, revision resumes, compact unchanged responses, one generation-owned
  watcher, cancellation by replacement, heartbeat recovery, bounded backoff,
  stale-response rejection, and transcript-preserving daemon restart are
  covered. Remaining transport hardening belongs to Milestone G: measure idle
  request cost, add a long-soak fault matrix, and automate the real-daemon
  restart journey in the local release gate.
- Milestone D is complete. One MoonLib-defined sequence contract, one
  MoonClaw-owned transactional journal, deterministic canonical replay,
  replaceable checkpoints, concurrent-writer serialization, idempotent
  delivery, torn-tail repair, corruption rejection, and recovery tests are in
  place. Moondesk's production adapter exposes only the journal path and
  sequence and does not reconstruct conversation from storage artifacts.
- Milestone E is partially complete. Safe Markdown and code rendering,
  answer/code/evidence copy, canonical file diffs, command/output/test evidence,
  Retry, and Stop command wiring are implemented. The remaining work is the
  approval decision workflow, confirmation that cancellation interrupts a real
  long-running tool, richer permission/context-loss recovery, durable
  model/web-search preferences, and stronger agent planning so explicit file
  inspection and project scaffolding are executed correctly instead of merely
  producing an honest failure.
- Milestone F has its grouping and selection foundation. Rename, archive,
  delete, search, history virtualization, and large-catalog performance remain.
- Milestone G is partially complete through local native, production-build, and
  visible browser gates. A single release command, latency/correctness metrics,
  accessibility/responsive journeys, deterministic fault fixtures, and the
  explicit hosted-CI decision remain.

No remaining milestone may add a Moondesk conversation store or merge raw
MoonClaw events into chat. New work extends the canonical owner, transport, or
renderer boundary already established here.
