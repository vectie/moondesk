# MoonDesk productization status

The authoritative scope and phase gates are defined in `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`.

## Current execution

The productization program has reached its finite Phase 10 decision:
**Not ready**. Phases 0–8 have passed their recorded repository or hosted gates.
Phase 9's repository-owned distribution path is implemented and locally
validated, but the Phase 9 external gate remains blocked.

The consolidated audit, exact owners, target dates, and evidence required to
change the decision are in
[`FINAL_RELEASE_READINESS_2026-07-30.md`](FINAL_RELEASE_READINESS_2026-07-30.md).
The distribution implementation and external proof boundaries are in
[`PHASE9_NATIVE_DISTRIBUTION_REPORT.md`](PHASE9_NATIVE_DISTRIBUTION_REPORT.md).

The latest full local validation completed every functional stage before its
clean-tree assertion: 338 native tests, 501 UI tests, 6 localization tests, 8
release-verifier tests, the Phase 9 non-credentialed smoke, the production
build, generated-interface verification, and whitespace checks passed. The
root check still reports 331 warnings, so warning-clean release readiness is
not claimed.

No current hosted-CI, Developer ID, notarization, Gatekeeper, hosted update,
clean-machine, lifecycle, rollback, removal, or 24-hour soak result is inferred
from local checks.

## Evidence policy and navigation contract

Repository-local work is complete only when its phase gate passes. Hosted CI,
signing, notarization, clean-machine, update/rollback, and soak claims remain
external evidence until their actual artifacts or URLs are recorded; missing
external proof does not block repository-local work that the authoritative
plan explicitly marks independent, but it does block dependency gates such as
Phase 2 to Phase 3.

Primary navigation remains exactly **Desk, Wiki, Code, Flow, Packs**, with
**Requests, Runs, Review, Publish** below Wiki.

## MoonSuite integration status

MoonDesk now follows the suite's single-runtime, graph-first topology:

- MoonFind owns discovery and desired-capability graph intent; MoonDesk presents
  its executable Work model for selection and inspection.
- MoonFlow owns validation, scheduling, execution, reconciliation, and restart
  recovery.
- MoonGate owns exact capability and authority resolution.
- MoonClaw is the sole agent runtime; MoonCode is a role/profile.
- MoonBook owns MoonWiki functionality, Bookkeeper outcome closure, and
  reviewed Three-Gap proposals.
- MoonTown owns civic coordination and reviewable cross-book synthesis.

The composition boundary accepts `moonsuite.work-model.v1`, resolves nodes
against `moonflow.capability-catalog.v1`, and keeps unsupported or unvalidated
operations unavailable. Validation and import share one digest-pinned catalog
snapshot and server-UTC evaluation time; their snapshot, report, and receipt
are retained under MoonDesk product state. Controls delegate to MoonFlow, and
missing runtime evidence disables rather than fabricates controls. Continuation
comes from graph dependencies and runnable state rather than hardcoded product
cards.

The locally validated MoonFind robotics reference has 63 stages, 43 unique
operations, 63 typed primary requests, and 11 domain-product owners. It
contains no MoonMini or MoonStat node and no publication, trade/order, or
physical robot command.

This integration evidence does not change the Phase 10 release decision.
MoonDesk still requires hosted-CI and warning-clean evidence, signing,
notarization, clean-machine install/update/rollback/removal, and a 24-hour
lifecycle/resource soak. A production suite run additionally requires
host-published unexpired adapter health, real credentials, licensed providers
and data, named reviewers, rights/customer evidence, calibrated robotics
simulation, a safety case, and separately granted external or physical
authority.
