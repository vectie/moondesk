# Lunar Robot Autonomy v3 — Accepted Live Qualification

**Date:** 2026-07-12  
**Primary run:** `flow-lunar-robot-autonomy-v3-r24`  
**Repeat:** `flow-lunar-robot-autonomy-v3-r25-auto-recovery-14`  
**Claim ceiling:** scenario-qualified digital evidence

## Result

r24 completed MoonWiki research, MoonTown deliberation, MoonCode helper
execution, MoonRobo design and native validation, MoonMoon simulation, and
MoonBook audit. Every product-native final and every independent criterion
review was accepted. Its intervention scorecard records zero required
interventions, zero hidden orchestration, zero normal-path manual actions, and
`unattended_qualified=true`.

r25 independently repeated the same goal. Its parent MoonTown adapter failed
without a result receipt. Bookkeeper produced a bounded recovery revision;
MoonFlow reused accepted research, invalidated incomplete descendants, and the
child completed all seven stages. The accepted child is also unattended
qualified.

## Accepted artifact chain

| Stage | Product evidence |
|---|---|
| Research | 3 fetched authoritative sources, 9 traceable claims, contradictions, limitations, 9 remaining gaps, query lineage, stopping rationale |
| Deliberation | unseeded P3 contribution, dissent P4, five comparison criteria, unresolved assumptions, civic review and delivery receipts |
| Helper | three allowlisted functions and eight wrapper-executed test results |
| Build | RoboBook-backed Shadow Edge Information Scout, digital-only mission, requirement traceability, hazards, margins, unsupported assumptions |
| Validation | eight constraint results, two negative cases, seven native scenario executions with resolved inputs and state histories |
| Simulation | four deterministic canonical scenario results with fixed seeds, scripts, actual outputs and traces |
| Audit | all three immutable criteria accepted in order; four open gaps and residual risks preserved; scalar `scenario-qualified` ceiling |

## Product fixes proved by the run

- MoonFlow binds `book_id` into every durable adapter request.
- MoonBook reserves one bounded recovery unit beyond normal stages.
- MoonClaw preflights exact MoonBook audit shapes and gives actionable scalar
  enum diagnostics.
- MoonRobo requires typed safety predicates mapped to executable adverse cases.
- MoonMoon publishes only the scenario inputs its native executor consumed.
- The independent reviewer recognizes replay-complete product-native scenario
  results.
- Bookkeeper keys procedures structurally, migrates volatile legacy keys,
  unions evidence, and retains digest/revision changes as invalidation signals.

## Learning result

After r24 and r25, the MoonBook procedure index contains exactly seven
structural procedures and all are accepted: research, deliberation, helper
implementation, digital build, validation, simulation, and outcome audit.
Every procedure contains successful reflection evidence from both accepted
lineages.

## UX lessons

- Show accepted continuation outcome beside the blocked parent; a blocked
  parent is not the final lineage outcome.
- Distinguish normal-stage budget from the explicit recovery reservation.
- Display native inputs, outputs, scripts and traces together; otherwise direct
  evidence resembles an agent summary.
- Schema diagnostics must name exact allowed types and enum values.
- Show a procedure's structural key, success count, evidence identities and
  invalidation conditions separately.

## Remaining project gates

The live product matrix is qualified, but the project is not yet complete. The
immutable frozen-runtime soak must reach 72 wall-clock hours with no failed
cycles. Only then may the final audit, rerating, merges, publication, and
remote-head verification proceed. No physical-readiness claim is authorized.

## Repeatable final audit

The suite workspace now contains one fail-closed gate at
`qualification/final_audit.py`. It verifies:

- all nine source repositories are clean, self-contained clones under
  `~/moonsuite/development/sources` at their audited heads and have only
  non-local publication remotes;
- installed binary digests and source commits match the live-runtime manifest;
- r24 and the r25 recovery child each have seven accepted stages and zero
  required, hidden, or normal-path manual interventions;
- r25 reused research, invalidated six incomplete descendants, and retained
  the unchanged source digest;
- all seven structural procedures are accepted and contain r24 and r25
  reflection evidence;
- all 11 constitutional product boundaries accept while both forbidden
  physical-authority probes reject;
- the frozen runtime and both soak harnesses retain their recorded digests;
- every soak cycle contains exactly the required nine status-zero checks and
  the combined recovery assertion; and
- active binaries, runtime metadata, source repositories, and symlink targets
  remain within `~/moonsuite`.

`--allow-running` produces a preparation result only. Without that flag, the
command returns failure until the soak state is `completed` after at least 72
wall-clock hours. This prevents a green functional run or an early partial soak
from authorizing merge and publication.

## Workspace-boundary repair

The upgrade branches initially lived in clean Git worktrees under
`/private/tmp`, whose common Git directories still pointed to `~/Workspace`.
They were moved and then converted into independent clones under
`~/moonsuite/development/sources`, preserving every branch, commit, and remote.
All nine clones passed Git object verification, and the obsolete temporary
worktrees, symlinks, and imported scratch source were removed. The frozen soak
was not restarted or modified by this repair.
