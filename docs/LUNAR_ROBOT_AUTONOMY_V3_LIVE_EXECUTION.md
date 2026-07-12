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

Native verification from the relocated clones passed MoonBook 257/257,
MoonClaw 1,096/1,096, MoonDesk 536/536, MoonFlow 41/41, MoonGate 813/813,
MoonLib 58/58, MoonMoon 201/201, MoonRobo 552/552, and MoonTown 986/986.
The clean-after-test gate exposed two repository-hygiene defects: MoonClaw
tracked a pre-build-generated version file and did not ignore its `.moonsuite`
test workspace, while MoonLib tracked 48 `_build` artifacts. Both boundaries
were corrected and the affected suites were rerun successfully with clean Git
status. Broad formatter drift in vendored legacy MoonClaw code was discarded as
an unrelated stale-compatibility migration.

The relocated UI surfaces also passed production qualification: MoonDesk
510/510 JavaScript tests, MoonMoon 200/200, MoonRobo 550/550, and MoonTown
367/367, with all four Vite production builds accepted. MoonTown additionally
passed server, user-workflow, and book-projection smoke tests plus artifact
verification. This pass found and fixed one product defect: MoonRobo's portable
suite executed a native disk-capacity assertion. The test now preserves the
native positive assertion and independently requires the typed
`disk-space-unsupported` outcome on non-native targets.

The stronger MoonMoon gait gate then exposed two integration defects hidden by
the ordinary production build. Its E1 visualization depended on an ignored
mesh extraction in `~/Workspace/moonrobo` and an archive in `~/Downloads`; the
audited archive is now under `~/moonsuite/inputs/noetix-e1`, generated caches
remain ignored, and evidence uses logical `moonsuite-input://` identities.
The heavy evidence exporter also attempted diagnostics before loading the
adapter runtime; it now initializes that runtime explicitly. The repaired gate
passes 24 gait/Moonphys frames, 38 loaded contacts, 24 driven motor frames, 25
STL references, compiled suite review, bridge freshness, and production build.

The final active-source scan removed two more historical leaks. MoonClaw had
17 MiB of tracked runtime conversations, jobs, checkpoints, artifacts, and logs
containing old absolute paths; runtime state is now ignored and its 1,096 tests
remain green. MoonTown reference metadata and its fresh-suite writer smoke used
`~/Workspace`, `~/Downloads`, and `/tmp`; they now use logical asset identities,
the sibling MoonBook clone, and suite-local `.tmp`. MoonTown remains green at
986 native and 367 UI tests, six server tests, fresh-suite smoke, and production
artifact verification.
