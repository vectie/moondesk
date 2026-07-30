# MoonDesk product contract

Class: desktop operator application

Maturity: local single-user alpha

Last reviewed: 2026-07-31

## Outcome

MoonDesk is the human control surface for MoonSuite: it opens workspaces,
reviews evidence, operates MoonWiki and MoonCode, hosts pack applications and
composes approved cross-product work.

## Users and jobs

- Operators browse books, files, tasks, artifacts and reviews.
- People approve, reject, steer and cancel agent work.
- Pack applications expose domain workflows without entering MoonDesk source.
- The composition canvas connects installed, compatible capabilities.

## Ownership

MoonDesk owns desktop navigation, workspace projection, review interaction,
application hosting, local service lifecycle presentation and composition UX.
It does not own agent reasoning, provider policy, orchestration state, book
truth or pack domain rules.

## Capability status

| Capability | Status |
| --- | --- |
| MoonBook/MoonClaw workspace inspection | available locally |
| MoonWiki and MoonCode operator modes | available locally |
| Pack discovery and same-origin application hosting | available |
| Review, authority and artifact surfaces | available |
| Composition canvas | experimental; not every displayed operation is executable |
| Direct code editing | available locally, including save, reload, diff and conflict preservation |
| Direct DOCX/XLSX/PPTX editing | available locally for the supported fidelity contract |
| Localization, keyboard, reduced-motion and responsive UX | repository-local automated gate complete |
| Signed, notarized clean-machine release | not ready; external qualification remains blocked |

## Capability-truth rule

Every executable canvas node must be generated from an installed manifest and a
healthy adapter that declares versioned operations, schemas, authority classes,
claim ceiling and endpoint. Planned nodes remain visibly non-executable.
MoonDesk must never infer a callable operation from a product name.

## Application boundary

Packs own their UI and domain vocabulary. MoonDesk provides generic hosting,
navigation, authority, evidence, review and lifecycle contracts. A pack upgrade
or uninstall must preserve user-owned accepted evidence and assets.

## Operation and recovery

MoonDesk must expose which local services are running, why an application is
unavailable, how to retry or recover, and which state is durable. External
effects remain separately authorized even when initiated from the desktop.

## Verification

Use the repository's targeted MoonBit tests during implementation. Release
validation additionally requires:

- a clean-machine application launch;
- one complete human review and pack-app workflow;
- service restart and state recovery;
- direct file open-edit-save-reopen;
- update and rollback evidence.

## Release gates and next milestones

- Replace aspirational canvas nodes with capability-derived nodes.
- Clear the warning-clean and latest-commit hosted-CI release blockers.
- Sign and notarize one immutable candidate.
- Prove clean-machine install, update, interruption, rollback and removal.
- Complete the frozen 24-hour lifecycle and resource soak.
