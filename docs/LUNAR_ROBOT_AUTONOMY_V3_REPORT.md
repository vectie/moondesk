# Lunar Robot Autonomy v3 — Unattended Preparation Record

> **Live update (2026-07-12):** This preparation snapshot is superseded by the
> accepted r24 normal-path run and r25 automatic-recovery repeat. See
> `LUNAR_ROBOT_AUTONOMY_V3_LIVE_EXECUTION.md` for current evidence, product
> fixes, learning results, and remaining gates.

**Prepared:** 2026-07-12  
**Workspace:** `/Users/kq/moonsuite`  
**Run:** `flow-lunar-robot-autonomy-v3-r2`  
**Current state:** locally prepared; no external model, public search/fetch, or live-goal adapter has started; definitive soak running  
**Physical claim ceiling:** prohibited; the maximum planned result is scenario-qualified digital evidence

## Purpose

This is the third clean lunar-robot journey. It tests whether one approved
outcome can progress through MoonWiki, MoonTown, MoonCode, MoonRobo, MoonMoon,
and MoonBook under MoonFlow without a hidden operator constructing paths, result
receipts, final artifacts, acceptance reviews, or handoffs.

The live stage is intentionally paused before its first model request. Only the
approved goal, immutable work request, explicit dependency artifacts, and public
product-contract guidance will be placed in each isolated capsule. MoonWiki's
restricted capsule may send search queries and selected public URLs to public
search/fetch services. Sending either those requests or the capsules to the
configured external GPT model still requires explicit user approval.

## Step record

| Step | Owner | Input | Product-owned output | Quality gate | Result |
|---|---|---|---|---|---|
| 0. Baseline | Moon Suite | r2 backup and third-update plan | restorable starting point and intervention taxonomy | no previous benchmark overwritten | complete |
| 1. Goal compile | MoonBook | unchanged goal text, source digest `5de7e3…`, revision `r2` | seven-item executable document and Work graph | authority not inferred; physical work excluded; original outcome criteria unchanged | complete |
| 2. Envelope | MoonGate | r2 autonomy request, source digest, product grants, budget | `moongate.autonomy-envelope.v1` | unrevoked, expiring, digital-only, no external or physical effects | awaiting explicit data-boundary approval; expired r1 envelope is not reused |
| 3. Runtime preparation | MoonBook + MoonFlow | declarations, capabilities, installed product registry | v3 unattended manifest, review policy, usage ledger | every agent draft is distinct from its product final | complete |
| 4. Runtime install | MoonFlow | tested source commits | executables under `~/moonsuite/bin` | no `/private/tmp` or `~/Workspace` runtime path | complete; reproducible installer added |
| 4a. Generalization | MoonBook | unrelated research, software, and adversarial goals | three executable documents and unattended runtimes | no lunar-template leakage; no physical/external authority inferred | complete |
| 5. Research | MoonWiki | isolated goal capsule plus scoped public search/fetch | traceable evidence bundle with wrapper-owned Web provenance | every cited locator was successfully fetched; contradictions, limitations, gaps, query lineage, and stopping rationale remain visible | pending approval |
| 6. Deliberation | MoonTown | goal + accepted research | selected concept and civic evidence | plural contributions, unseeded idea, dissent, critique, ranking, independent review, distribution and return | pending |
| 7. Helper implementation | MoonCode / MoonClaw | goal + accepted deliberation | bounded executable helper DSL and native test evidence | allowlisted operations only; positive and negative vectors executed by wrapper; no physical claim | pending |
| 8. Digital build | MoonRobo | goal + accepted concept + accepted helper | RoboBook-backed generic digital design | requirements/components/hazards/margins; helper dependency satisfied; no scenario template | pending |
| 9. Validation | MoonRobo | accepted digital design | native constraint and resilience evidence | non-empty constraint results, negative cases, failure traces; failed constraints cannot be averaged away | pending |
| 10. Simulation | MoonMoon | accepted validation | deterministic nominal/adverse scenario evidence | explicit energy reserve, seeds, hazards, recovery, uncertainty, limitations, correct refusal | pending |
| 11. Audit and learning | MoonBook / Bookkeeper | accepted evidence chain | ordered outcome audit, three-gap graph, bounded procedure candidates | every criterion decided in order; claim ceiling preserved; cross-run reuse requires applicability and invalidation checks | pending |

## Implemented constitutional boundaries

- MoonGate authorizes every attempt at event time and persists denial receipts.
- MoonFlow binds the envelope source digest to the compiled graph before the
  first dispatch. Workspace or provenance mutation fails closed with a durable
  `moonflow.autonomy-binding-rejection.v1` receipt.
- MoonClaw receives only the immutable request and declared input artifacts in a
  per-trial capsule. Absolute paths, parent traversal, shell access, patching,
  and unrelated workspace reads are unavailable in restricted mode.
- Public Web tools exist only for observe-only MoonWiki evidence requests. The
  wrapper records successful search and fetch events, and MoonBook rejects a
  source locator that does not match a successfully fetched URL.
- MoonCode helper output uses `moonsuite-helper-dsl.v1`, not arbitrary host
  code. MoonClaw executes allowlisted two-input functions and all positive and
  negative vectors, then owns the build/test evidence consumed by MoonRobo.
- The model writes a draft only. MoonFlow never reconciles that draft as final.
- A product-native executable validates the product contract, invokes native
  product logic, and materializes a distinct final artifact.
- An independent reviewer sees the immutable criteria, exact final evidence,
  and product attestation; it cannot grant authority or alter criteria.
- MoonFlow resumes from durable request, result, attestation, and review
  checkpoints and reconciles final artifacts exactly once.
- Pause, resume, cancel, and authority narrowing are durable run controls.
  Authority can never widen, cancellation is terminal, and terminal runs reject
  contradictory control records.
- MoonDesk exposes the envelope, budgets, intervention scorecard, evidence
  identities, readiness ladder, and bounded controls without requiring a
  terminal.

## Quality-trial policy

Each MoonClaw execution allows at most three bounded trials. A failed or
incomplete JSON draft is retained, copied into the next isolated capsule, and
returned with contract-specific diagnostic findings. The next trial must revise
the smallest missing structure; it may not weaken criteria or receive a task
answer. Product guidance describes public contract shape only and contains no
lunar-robot solution, concept name, numeric answer, or benchmark fixture.

The product attestor remains authoritative even after local draft checks. A
weak draft that merely has the right fields can still be rejected by native
MoonTown emergence, MoonRobo design/validation, or MoonMoon replay logic.

## Recovery evidence already proven

The MoonFlow fault-injection harness kills the supervisor after adapter result,
after product attestation, and after review persistence. The fourth launch
reaches acceptance; a fifth duplicate launch is a no-op. The resulting run has
one logical attempt, one final artifact lineage, and an unattended-qualified
intervention scorecard. Product-native attestators additionally have direct
positive and negative tests.

The final recovery sequence was `[-9, -9, -9, 0, 0]`: three supervisor kills at
the durable result, attestation, and review boundaries; one successful resume;
and one duplicate terminal delivery. The final adapter lease is `reviewed`.

The wall-clock soak runner was exercised for two complete cycles. It records
atomic state plus one JSONL receipt per cycle and defaults to 72 hours with a
15-minute interval. This proves the runner, not the 72-hour duration; the real
soak remains an honest pending gate.

Earlier real soaks were intentionally superseded whenever qualification changed
the runtime boundary. The last superseded run completed two clean cycles and is
marked `superseded`, not passed; its elapsed time is excluded. The definitive
soak uses `qualification/unattended-soak/runtime-9fd437f1`, whose installed
runtime manifest SHA-256 is
`9fd437f13c4e212873e0010c96f9ef6e3f2b8bc8ede21fdde858098fc9c13aa8`.
It binds MoonFlow commit `3e5f1a9`, MoonBook `aaab16c`, MoonClaw `dc73a989`,
and MoonGate `8335b0f`. Every 15-minute cycle runs nine checks: the three-crash restart sequence,
seeded review-rejection/automatic revision, native bounded-helper execution, a
missing-model refusal, combined crash/delay/duplicate/immutable-revision
lineage, evidence-source mutation refusal, operator pause/resume, real MoonGate
budget exhaustion, and a seeded product-adapter crash followed by bounded
child recovery. State
and receipts are under
`qualification/unattended-soak/run-20260712-9fd437f1`; cycle 1 passed all nine
checks with zero failures. The 72-hour clock began at epoch
`1783849556.1028988`. An hourly task continuation monitors this exact path.

The combined lineage returns `[-9, -9, -9, 0, 0]`, delays the child result,
replays a duplicate terminal delivery as a no-op, retains distinct rejected
parent and accepted child evidence, invalidates exactly one checkpoint, and
charges exactly two attempts. A signal preflight also exposed that the runner's
sleep delayed SIGTERM completion; it now uses an interruptible event wait and
persists `interrupted` immediately.

All recurring harness work now lives under
`~/moonsuite/qualification/harness-work`. This replaced the operating system
temporary directory after macOS `/var` and `/private/var` aliases masked the
intended source-digest refusal behind a workspace-identity refusal.

## Automatic revision trial

A seeded independent reviewer rejected the parent result without changing the
original criterion. Bookkeeper recorded the execution gap, preserved the
negative review evidence, and generated a child graph whose only added input
was the diagnostic reflection. MoonFlow then:

1. persisted a criteria-preserving recovery proposal;
2. migrated the blocked parent into child revision
   `r1-auto-recovery-5`;
3. invalidated the rejected checkpoint instead of reusing it;
4. snapshotted both parent and child product finals under distinct immutable
   evidence identities;
5. charged two attempts to the same budget ledger; and
6. reached an independently accepted child outcome without a manual command.

This trial also exposed that blocked projections had not retained their typed
`acceptance-rejected` error kind. MoonFlow now preserves it, and MoonBook also
recognizes the durable rejection blocker for previously persisted projections.

A separate product-restart trial terminated the adapter before any result
receipt existed. The parent stopped with a visible `supervisor-blocked` error;
Bookkeeper created one bounded recovery child; MoonFlow invalidated the
incomplete checkpoint; and the child completed with a fresh input digest and
independent acceptance. Repeated recovery is capped by revision identity and
the shared attempt budget. Verified adapter drafts are also snapshotted before
product attestation, so later trials cannot erase rejected proposal evidence.

## Generalization and red-team evidence

- `sleep-research` compiled into MoonWiki → MoonTown → MoonBook only.
- `parser-library` compiled into MoonWiki → MoonTown → MoonClaw → MoonBook;
  MoonClaw now owns a native `moonclaw.software-result.v1` attestation gate.
  The safe unattended implementation ceiling is currently bounded helper DSL,
  so unsupported general code must block rather than fabricate build results.
- `adversarial-launch` preserved digital design, validation, and simulation but
  generated an unattended-digital envelope request with both external and
  physical effects set to false.
- All three prepared manifests resolve only content-addressed executables under
  `/Users/kq/moonsuite/bin`; scans found no `/private/tmp` or `~/Workspace`
  paths and no lunar/robot template text in the unrelated goals.
- Revoked and expired envelopes, authority/claim escalation, external
  destinations, path escapes, and budget overrun are explicit fail-closed
  tests. Source mutation now also leaves a durable refusal receipt.
- Structural procedure transfer, two-success promotion, and invalidation on
  changed criteria are direct MoonBook tests.

Latest focused/full evidence after the final changes:

| Product | Result |
|---|---:|
| MoonGate | 813/813 |
| MoonBook / MoonWiki / Bookkeeper | 255/255 |
| MoonFlow | 40/40 plus nine-check soak and signal preflights |
| MoonClaw / MoonCode | 1087/1087 |
| MoonTown | 983/983 |
| MoonRobo | 552/552 |
| MoonMoon | 201/201 |
| MoonLib | 58/58 |
| MoonDesk native | 536/536 |
| MoonDesk UI | 190/190 plus production build |

## UI/UX findings and fixes

1. **Outcome overstatement.** Active and blocked runs could visually resemble
   completion. The Flow state now derives from actual terminal outcome.
2. **Authority was invisible.** The cockpit now shows the envelope, effect
   bounds, budgets, intervention count, and physical ceiling.
3. **Intervention required a terminal.** Durable pause/resume/cancel/narrow
   controls and a local API were added. Browser verification used the real
   prepared run and proved pause then resume round-tripped correctly.
4. **Terminal-control contradiction.** The first control API allowed an
   accepted run to acquire a cancelled control label. Both backend and runtime
   now reject controls for accepted, blocked, or failed runs.
5. **Packaging looked successful without a binary.** MoonTown's first command
   package was outside its module source root. It was moved under `src/cmd`, and
   the executable build is now part of verification.
6. **Development paths leaked into runtime manifests.** Runtime preparation now
   resolves a product registry under `~/moonsuite/bin` and fails closed when an
   attestor is missing. A single installer builds, installs, and records binary
  and source digests.
7. **A research flag looked enabled without real research tools.** Restricted
   MoonWiki capsules now receive only scoped file tools plus public search and
   fetch. Their successful calls become wrapper-owned provenance, and native
   attestation rejects unfetched citations.
8. **“Code complete” could be a model assertion.** MoonCode's lunar helper stage
   now emits a bounded DSL. The native wrapper executes positive and negative
   vectors and materializes the build/test receipt; unallowlisted operations
   fail closed.
9. **The first graph skipped MoonCode.** The r2 compiler now inserts
   `helper-tools`, and MoonRobo's digital build depends on both the accepted
   MoonTown concept and accepted MoonCode helper evidence. r1 remains archived
   under `flow/revisions/r1-pre-helper-upgrade`.
10. **Supervisor stop could appear hung.** The first soak runner recorded the
    stop request but remained in its interval sleep. Signal handling now wakes
    the wait immediately and persists an honest interrupted terminal state.
11. **Temporary roots obscured identity and escaped the suite workspace.** The
    harness now uses `~/moonsuite/qualification/harness-work`; source mutation
    consequently produces the intended durable `source_digest` rejection.

Desktop and narrow-width Flow layouts were inspected. Control buttons wrap,
long identities truncate, and the physical-readiness boundary remains visible.

## Best practices extracted

- Treat agent output as a proposal, never as product evidence.
- Put truth ownership in native product attestors and acceptance ownership in
  independent reviewers.
- Give agents public contract schemas and prior diagnostics, not benchmark
  answers.
- Preserve rejected drafts, dissent, negative cases, limitations, and blockers
  as evidence rather than optimizing them away.
- Make every retry idempotent and every recovery checkpoint durable before the
  next effect.
- Keep runtime paths, binaries, books, logs, receipts, and controls beneath the
  declared suite root.
- Promote learned procedures only after repeated success or explicit review;
  retrieve them by structural applicability, and reject reuse when an
  invalidation signal matches.
- A correct refusal or authority pause is a successful constitutional outcome.

## Remaining qualification gates

- Explicit approval for this data boundary: transmit isolated goal/contract
  capsules and accepted predecessor evidence to `gpt-5.6-sol`, and transmit
  MoonWiki search queries plus selected public URLs to public search/fetch
  services. Credentials, private repository contents, absolute host paths, and
  unrelated workspace files are excluded.
- One uninterrupted goal-to-audit lunar robot run with native product finals.
- One accepted repeat demonstrating bounded procedure transfer in a live
  lineage (the compiler and Bookkeeper transfer policy are already qualified
  offline).
- A real 72-hour supervisor soak; this cannot be replaced by accelerated unit
  time while still honestly claiming a 72-hour observation.
- Final evidence bundle, rerating, main-branch merge, publication, and remote
  head audit.
