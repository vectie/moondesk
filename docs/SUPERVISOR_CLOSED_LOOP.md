# Supervisor Closed Loop

## Product decision

The user's first controllable agent is created and edited in the MoonTown
experience rendered by Bunnia. MoonDesk does not own a second character editor,
persona store, agent loop, mailbox, review system, or learning engine.

The closed loop has one owner per kind of truth:

| Concern | Owner |
|---|---|
| phone UI, onboarding steps, touch interaction | Bunnia |
| character/profile versions, mission, permissions, town projection | MoonTown |
| user-visible desktop control/proxy | MoonDesk |
| capability and authority verification | MoonGate |
| supervisor and bounded worker execution | MoonClaw |
| exact final-deliverable acceptance and outcome closure | MoonBook Bookkeeper |
| durable book memory and Three-Gap learning | MoonBook |

## Call chain

```text
Bunnia five-tab phone
  -> MoonTown profile draft / activation command
  -> durable MoonTown outbox handoff
  -> MoonDesk typed supervisor proxy
  -> MoonClaw HTTP command boundary
  -> MoonGate-backed authority decision
  -> retained MoonClaw SupervisorRuntime
  -> existing bounded child-run delegation
  -> MoonTown status, worker, and building projections
  -> immutable outcome-evidence submission
  -> MoonBook Bookkeeper named-human exact review
  -> ProductOutcomeClosure
  -> Three-Gap learning proposal
  -> reviewed profile/book/policy update
```

No earlier component may claim that the final deliverable is accepted. A
MoonClaw result and a MoonTown review projection are evidence awaiting the
Bookkeeper decision.

## MoonDesk HTTP surface

MoonDesk deliberately exposes only a typed, same-origin control bridge:

| Method | Path | Meaning |
|---|---|---|
| `POST` | `/api/moonclaw/supervisors/activate` | forward a versioned, digest-bound activation command |
| `GET` | `/api/moonclaw/supervisors/<id>/status` | read the runtime projection |
| `GET` | `/api/moonclaw/supervisors/<id>/events` | read events after a durable cursor |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/message` | deliver a user command |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/wake` | wake an idle supervisor |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/steer` | steer current work |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/stop` | request bounded cancellation |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/retry-resume` | reconcile and resume a failed or interrupted command |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/delegate` | submit one bounded high-level worker intent |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/worker-steer` | steer a receipt-projected worker run |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/worker-stop` | stop a receipt-projected worker run |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/worker-retry-resume` | retry a receipt-projected worker run |
| `POST` | `/api/moonclaw/supervisors/<id>/commands/outcome-evidence` | append non-final deliverable evidence |
| `GET` | `/api/moonclaw/supervisor-bridge` | inspect exact pending Town handoffs, required digests, and durable transport receipts |
| `POST` | `/api/moonclaw/supervisor-bridge/grant-and-sync` | derive a short-lived exact grant from the durable Town user action, claim it, forward it, and reconcile its receipt |
| `GET` | `/api/moonclaw/supervisor-bridge/receipts/<kind>/<target-id>` | inspect one restart-safe activation, execution, Bookkeeper, or runtime-observation receipt |

MoonDesk starts or reconnects to the configured MoonClaw daemon and proxies
JSON without reinterpreting profile semantics. IDs and event cursors are
validated before constructing a loopback request. The direct proxy requires
callers to supply MoonClaw's authority and idempotency envelope unchanged.

The outbox bridge is narrower. A `grant-and-sync` POST with an empty JSON object
may materialize a five-minute `moonsuite.authority-decision-ref.v1` only when a
durable Town outbox record already identifies the user, command, target, and
exact request digest. The reference names MoonClaw's local daemon receiver and
is persisted with the transport receipt. This is a MoonDesk host/control-plane
decision derived from the explicit Town action; it does not create a MoonGate
grant or relax MoonClaw's independent live capability verification. Missing or
incomplete actor/action/digest identity fails closed before Town is claimed.

The desktop server also runs this bridge automatically for the active workspace.
It checks every two seconds while healthy, backs off exponentially to at most
30 seconds after unavailable or incomplete syncs, and uses the same process-wide
mutex as manual recovery. It first reads both Town outboxes; an idle cycle does
not start MoonClaw or materialize authority. `GET /api/moonclaw/supervisor-bridge`
reports auto-pump status, the next interval, pending count, active supervisor
count, and last reconciled receipt. Once an activation is acknowledged, the
same loop polls MoonClaw's exact status and cursor-bounded event replay and
reconciles a digest-bound `moonsuite.supervisor-runtime-observation.v1` into
Town. The observation is durably recorded before reconcile, so a restart
reposts the exact saved payload instead of skipping or synthesizing runtime
state. The POST remains an observability and manual-recovery surface, not a
required second operator step.

## Character activation boundary

MoonTown retains the readable character fields. The runtime receives only a
versioned command envelope and the generic
`moonsuite.supervisor-profile-activation.v1` payload. That
prevents runtime state from becoming a competing profile database. Activation
is not complete until MoonTown observes the corresponding MoonClaw receipt and
cursor; a locally persisted outbox item is `pending_runtime`, not `active`.

## Messaging and worker control

Bunnia's Messages tab is a phone-sized control surface over real projections.
A message is a durable command with an idempotency key and expected cursor.
Worker rows come from MoonClaw's existing child-run lineage; MoonTown only maps
those projections to agents walking and working in the town. Stop, steer, and
retry/resume actions target explicit command/run identities and are safe to
replay after restart.

Town execution actions are mapped through a fixed allowlist: supervisor
message/steer/wake/stop/resume and legacy cancel/retry map to their exact
MoonClaw commands; child stop/steer/retry map to the exact worker commands; and
`delegate` maps to the high-level `delegate` intent DTO.
The bridge hashes the canonical MoonClaw DTO and binds authority to that digest;
it never forwards a Town action as an HTTP path. Delegation additionally needs
an explicit Town web-search posture and finite worker bounds. MoonDesk binds the
task to the normalized installed active MoonBook, requires the exact
`gpt-5.6-sol` model, and forwards Town's explicit claim ceiling, budgets,
expiry, and the exact suite-relative `books/<book-id>/artifacts` scope. The
prefix has no URI scheme, wildcard, or trailing slash and must match the bound
book metadata. MoonClaw alone derives the durable worker run, job, and
child-delegation identity.

Town's durable execution `request_digest` remains the semantic user-action
digest. During the exact execution claim, MoonDesk supplies the independently
computed MoonClaw `transport_request_digest` and allowlisted transport endpoint;
it also supplies the canonical operation payload and the exact envelope-bearing
runtime command. Town hashes the operation payload, validates the command
envelope, and persists all four values on that claimed handoff. MoonDesk
requires the returned claim to contain the same values before forwarding, and
Town reconciles the MoonClaw receipt only against that previously bound
transport digest. On restart MoonDesk validates and reuses the exact persisted
runtime command, including its original authority evidence and timestamp. Both
digests remain visible in the bridge receipt, so transport verification never
weakens or overwrites the source-action audit identity.

## Acceptance and learning

The final agent submits immutable outcome evidence through MoonBook's existing
`bookkeeper.outcome.submit` path. This creates a pending
`DeliverableAcceptance`; it does not self-approve. A named human performs exact
acceptance. Only the accepted receipt may advance `ProductOutcomeClosure` and
the Three-Gap learning loop. Learning produces a reviewable proposal; it never
silently changes the live supervisor profile, book, or policy.

The adapter replays the same immutable submission after each named-human gate.
The bridge records the current pending gate and every exact changed receipt,
then stops at `closed_no_capability_change` or
`reviewed_proposal_handed_off`, and also stops on the exact terminal Reject
states `deliverable_rejected`, `assessment_rejected`, or `proposal_rejected`.
Reject receipts are reconciled once, never claimed for replay, and remain
non-activating. Replay never accepts a gate or activates a proposal.

## Release proof

One consolidated qualification run should prove:

1. a new user drafts, leaves, resumes, and activates the first character in the
   Bunnia/MoonTown UI;
2. the same command ID is harmless when replayed and a stale cursor is rejected;
3. a phone message reaches MoonClaw, delegates bounded workers, and produces
   real MoonTown movement/work projections;
4. process restart preserves the mailbox, worker lineage, and event cursor;
5. missing authority is denied, stop/steer/retry are observable, and no UI
   fabricates completion;
6. final evidence remains pending until a named Bookkeeper reviewer accepts it;
7. the accepted outcome creates durable book memory and a reviewable Three-Gap
improvement proposal.

The bridge consumes Town's reviewed Bookkeeper outbox as the single canonical
submission source. It writes the exact submission as an adapter input, invokes
the configured installed MoonBook pack's existing
`submit-product-outcome` adapter, validates the exact record identity and
non-activating receipt, and reconciles that receipt to Town. It deliberately
does not also pump MoonClaw's outcome outbox, which would double-submit the same
evidence through two owner paths.

Fixture-only visuals, local `accepted=true` flags, and a handoff that never
crosses the HTTP/runtime boundary do not satisfy this proof.
