# Engineering Maturity Contract

MoonDesk does not infer product availability from source files, route names,
screens, or prose plans. The machine-readable authority is
`config/capability-maturity.json`; CI validates it with
`scripts/verify_maturity_manifests.mjs`.

## Capability stages

Stages are ordered and monotonic:

1. `declared`: named intent or contract, with no implementation claim.
2. `implemented`: production code exists.
3. `component_tested`: a component test executes the implementation.
4. `integrated`: the real producer and consumer execute together.
5. `journey_proved`: a user-visible fresh-root journey is recorded.
6. `packaged`: the packaged artifact repeats the journey.
7. `release_qualified`: clean-machine, operational, and external release gates
   pass.

Availability is derived from evidence. `available` requires
`release_qualified`; `preview` requires `packaged`; `internal` requires at
least `implemented`. A feature may have routes or UI while remaining `hidden`
or `internal`.

Every stage from `component_tested` onward requires its corresponding evidence
kind. Higher stages retain the evidence required by all lower stages. Known
gaps belong in `blockers`, not in a separate completion narrative.

## Suite integration

`config/moonsuite-integration.json` names the repositories, checkout paths,
root variables, and development refs used by the required CI job. The workflow
must match that manifest exactly. A missing checkout is an error; validation
must never silently skip a required repository.

Development CI intentionally tests the current `main` branches together so
drift becomes visible immediately. Release qualification must replace branch
refs with full commit SHAs and record the resolved revisions with its evidence.

The MoonCode integration probe compiles MoonClaw and MoonDesk in one temporary
MoonBit workspace. MoonClaw constructs its producer capability payload through
its public API, and MoonDesk must decode the complete payload. Their source
trees are intentionally different because they own different responsibilities.

## Updating maturity

For a capability-stage promotion:

1. add or update the executable evidence;
2. run the command from a clean checkout;
3. update the ledger stage, availability, evidence, and blockers;
4. run `node --test scripts/verify_maturity_manifests.test.mjs`;
5. run `scripts/validate.sh full` with all integration roots supplied.

Do not promote a capability merely because its implementation was merged. Do
not paste historical test totals into current status documents when the ledger
or CI evidence can state the result.
