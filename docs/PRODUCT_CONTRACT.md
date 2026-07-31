# MoonDesk product contract

Class: application
Form: desktop operator and pack-application host

Maturity: local single-user alpha

Last reviewed: 2026-07-31

## Outcome

MoonDesk is the human control surface for MoonSuite: it opens workspaces,
reviews evidence, operates MoonWiki and MoonCode, hosts pack applications and
presents MoonFind-authored cross-product work for selection and inspection.

## Users and jobs

- Operators browse books, files, tasks, artifacts and reviews.
- People approve, reject, steer and cancel agent work.
- Pack applications expose domain workflows without entering MoonDesk source.
- The composition canvas renders exact, catalog-compatible capabilities from a
  published Work graph.

## Ownership

MoonDesk owns desktop navigation, workspace projection, review interaction,
application hosting, local service lifecycle presentation, and composition UX.
It does not own discovery intent, agent reasoning, provider policy,
orchestration state, book truth, or pack domain rules.

The surrounding ownership is explicit:

- MoonFind owns discovery and desired-capability graph intent.
- MoonFlow owns validation, scheduling, execution, reconciliation, and restart
  recovery.
- MoonGate owns exact capability and authority resolution.
- MoonClaw is the sole agent runtime; MoonCode is one of its roles/profiles.
- MoonBook owns MoonWiki functionality, durable book truth, and Bookkeeper.
- MoonTown owns civic coordination and reviewable cross-book synthesis.

## Capability status

| Capability | Status |
| --- | --- |
| MoonBook/MoonClaw workspace inspection | available locally |
| MoonWiki and MoonCode operator modes | available locally |
| Pack discovery and same-origin application hosting | available |
| Review, authority and artifact surfaces | available |
| Composition canvas | available locally for published Work graphs; unsupported or unvalidated nodes remain unavailable |
| Catalog-backed conformant MoonFlow import | available locally when a valid catalog and configured MoonFlow runtime are present |
| Direct code editing | available locally, including save, reload, diff and conflict preservation |
| Direct DOCX/XLSX/PPTX editing | available locally for the supported fidelity contract |
| Localization, keyboard, reduced-motion and responsive UX | repository-local automated gate complete |
| Signed, notarized clean-machine release | not ready; external qualification remains blocked |

## Capability-truth rule

Every executable canvas node must come from the selected MoonBook's
`flow/work-graph.json` with contract `moonsuite.work-model.v1` and resolve
exactly against a `moonflow.capability-catalog.v1`. The catalog is derived from
an installed manifest plus a healthy adapter declaration and contains the
versioned operation, input and output schemas, authority class, claim ceiling,
review requirement, and endpoint evidence. Missing or incompatible evidence is
shown as unavailable. MoonDesk must never infer a callable operation from a
product name, palette row, repository, or friendly alias.

The Rabbita Flow surface exposes declaration and operation identities,
input/output schemas, requested authority, required claim, acceptance criteria,
primary artifacts, timeout, adapter claim ceiling, review requirement, and
health evidence. Inventory presence is not adapter readiness. Missing catalog,
validation, adapter, or health evidence remains explicitly unavailable.

MoonFind's locally validated robotics reference has 63 stages, 43 unique exact
operations, 63 typed primary requests, and 11 domain-product owners: MoonBook,
MoonCast, MoonChat, MoonClaw, MoonFind, MoonMold, MoonMoon, MoonProj, MoonRobo,
MoonTown, and MoonVis. MoonFlow, MoonGate, and MoonLib are support-plane
dependencies, not extra work items. MoonMini and MoonStat are not active graph
products.

## Application boundary

Packs own their UI and domain vocabulary. MoonDesk provides generic hosting,
navigation, authority, evidence, review and lifecycle contracts. A pack upgrade
or uninstall must preserve user-owned accepted evidence and assets.

Publication, financial trading, physical robot commands, and activation of a
learning or policy change are separately authorized effects. Selection on the
canvas does not grant any of them.

## Operation and recovery

MoonDesk must expose which local services are running, why an application or
node is unavailable, how to retry or recover, and which state is durable. It
must preserve MoonFind's reviewable desired graph separately from MoonFlow's
executable Work model. MoonFlow receives a dependency-closed selection and
performs catalog-backed validation and conformant import; MoonDesk presents the
result rather than claiming execution itself. MoonDesk pins one catalog digest
and one server-UTC evaluation time across validation and import, then persists
the catalog snapshot, validation report, and import receipt under
`.moonsuite/products/moondesk/moonflow-imports/<digest>/`.

Run autonomy, intervention-scorecard, and control data are evidence, not UI
defaults. When persisted evidence is absent, MoonDesk shows it as unavailable
and withholds the corresponding controls. When present, pause, resume, cancel,
and authority changes delegate to MoonFlow's control protocol; MoonDesk does
not rank or write MoonFlow control state itself.

## Verification

Use the repository's targeted MoonBit tests during implementation. Release
validation additionally requires:

- a clean-machine application launch;
- one complete human review and pack-app workflow;
- service restart and state recovery;
- direct file open-edit-save-reopen;
- update and rollback evidence.

## Release gates and next milestones

- Clear the warning-clean and latest-commit hosted-CI release blockers.
- Sign and notarize one immutable candidate.
- Prove clean-machine install, update, interruption, rollback and removal.
- Complete the frozen 24-hour lifecycle and resource soak.
- Exercise one live 63-stage graph with host-published, unexpired adapter
  health, real credentials, named reviewers, and restart evidence.
- Keep provider licensing, media rights, financial-data licensing, customer
  acceptance, robotics safety, and physical authority as external product
  gates; repository fixtures cannot satisfy them.
