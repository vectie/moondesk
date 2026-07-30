# MoonDesk Documentation Guide

Start with the [product contract](PRODUCT_CONTRACT.md) for current maturity,
capability-truth rules, pack hosting and release gates.

MoonDesk is the human desktop shell for MoonSuite. It should make books,
files, Wiki work, Code work, town requests, runtime evidence, and app-tool
packaging visible to an operator without taking ownership of the runtimes or
domain workflows it displays.

## Scope And Boundary

MoonDesk owns the local desktop experience:

- workspace and book discovery
- scoped file browsing, preview, search, edit, import, and export
- MoonWiki and MoonCode presentation for the selected book
- MoonTown request and daemon controls
- MoonClaw status, stream, package, and review projections
- Lepusa bundle/release integration for the native shell

MoonDesk does not own durable book truth, agent execution, town scheduling,
suite metrics, or domain-specific workflow logic. Those boundaries belong to
MoonBook, MoonClaw, MoonTown, MoonGate, and product packs. Shared filesystem
contracts come from MoonLib.

## Reading Order

1. [PLAN.md](PLAN.md): product model, user flow, non-goals, and engineering bar.
2. [ARCHITECTURE.md](ARCHITECTURE.md): package ownership, HTTP surface, and
   cross-product boundaries.
3. [DESK_MODE_DESIGN.md](DESK_MODE_DESIGN.md): file/workspace mode behavior.
4. [FIRST_RUN_AND_VOCABULARY.md](FIRST_RUN_AND_VOCABULARY.md): evidence-backed
   first-run inventory, target vocabulary, state matrix, and capability setup.
5. [NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md](NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md):
   packaged macOS picker phases, defects, interaction evidence, persistence,
   and remaining restart/platform boundary.
6. [WIKI_MODE_UX_PLAN.md](WIKI_MODE_UX_PLAN.md): normal-user Wiki information
   hierarchy, progressive disclosure, implementation phases, and UX E2E gates.
7. [WIKI_MODE_USER_E2E_PLAN.md](WIKI_MODE_USER_E2E_PLAN.md): user-visible Wiki
   journeys, rationale, expected behavior, methodology, and acceptance evidence.
8. [MOONCODE.md](MOONCODE.md): code-mode contract and MoonClaw handoff.
9. [MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md](MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md):
   canonical conversation/runtime upgrade plan.
10. [MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md](MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md):
   finite single-owner conversation, thinking, and live-update correction.
11. [MOONCODE_TYPED_CONTRACT_TARGET.md](MOONCODE_TYPED_CONTRACT_TARGET.md):
   Phase 3.1 public-surface inventory, typed target, decisions, and migration slices.
12. [STATUS.md](STATUS.md): current implementation state and known gaps.
13. [BASELINE_2026-07-27.md](BASELINE_2026-07-27.md): reproducible Phase 0
    starting/current evidence, repository metrics, and explicitly unmeasured gaps.
14. [DOCUMENT_TRUTH_AUDIT_2026-07-27.md](DOCUMENT_TRUTH_AUDIT_2026-07-27.md):
    active-document contradiction audit, evidence boundary, and Phase 0 gate state.
15. [FULL_VALIDATION_PROOF_2026-07-27.md](FULL_VALIDATION_PROOF_2026-07-27.md):
    retained clean-checkout full-validation transcript and evidence boundary.
16. [RELEASE_PROCESS.md](RELEASE_PROCESS.md): phase-by-phase preview and
    credentialed release procedure, immutable-output policy, and remote gate.
17. [PREVIEW_RELEASE_PROOF_2026-07-27.md](PREVIEW_RELEASE_PROOF_2026-07-27.md):
    exact local unsigned-candidate commands, checksums, refusal tests, and
    evidence boundary.
18. [ROADMAP.md](ROADMAP.md): active product tracks and future gates.
19. [MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md](MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md):
   phased plan for product clarity, typed contracts, package boundaries,
   security, observability, release discipline, and operational proof.
20. [MOONSUITE_LAYOUT_MIGRATION_PLAN.md](MOONSUITE_LAYOUT_MIGRATION_PLAN.md):
   historical migration plan and validation record; it is not a current plan.

## Implementation Map

- `core/`: small DTOs shared by desktop surfaces.
- `internal/mooncore/`: reusable record, JSON, transcript, and session helpers.
- `internal/moonwiki/`: workspace, VFS, preview, book-pattern, town, daemon,
  import, and app-tool host logic.
- `internal/mooncode/`: canonical conversation, MoonClaw stream, command,
  package, test, review, and runtime projection contracts.
- `cmd/main/`: local host, desktop launch, bundle, release, and LaunchAgent CLI.
- `ui/rabbita-desk/main/`: Rabbita UI for Desk, Wiki, Code, Town, Runs, and
  Settings.

New code should land in the narrowest owning package. Do not put product-pack
logic in MoonDesk because a UI needs to display it.

## Canonical Validation

Run the Phase 0 gate from any working directory:

```sh
/path/to/moondesk/scripts/validate.sh fast
/path/to/moondesk/scripts/validate.sh full
```

`fast` runs root formatting/check/native tests and UI checks/tests without a
production build. `full` additionally runs localization, release-verifier
positive/negative fixtures, the production build, generated-interface
verification, opt-in boundary validation, and `git diff --check`. Set
`MOONCLAW_ROOT`, `MOONBOOK_ROOT`, and `MOONTOWN_ROOT` together to explicit
checkout roots to enable the core boundary validator; if none are set it is
skipped, and a partial set is an error. The full production build can update
tracked generated `dist` artifacts; review those changes and do not run full
mode merely as an authoring check in a dirty worktree.

## Testing Guidance

Use focused tests for changed packages, then run a product smoke when behavior
crosses package or UI boundaries.

```sh
moon check
moon test
npm --prefix ui/rabbita-desk run build
```

For workspace and Desk behavior, use the API smoke scripts under `scripts/`
against a fresh MoonSuite root. For Code mode, verify that user messages append
immediately, MoonClaw-backed progress appears only from runtime evidence, final
assistant text appends in order, and old turns persist after reload.
For Wiki mode, use [WIKI_MODE_TEST_PLAN.md](WIKI_MODE_TEST_PLAN.md) for forward
and backward behavior and [WIKI_MODE_UX_PLAN.md](WIKI_MODE_UX_PLAN.md) for the
normal-user information hierarchy. Use
[WIKI_MODE_USER_E2E_PLAN.md](WIKI_MODE_USER_E2E_PLAN.md) for user-centered
journeys, methodology, and release acceptance evidence.

## Worth Noticing

- `~/moonsuite` is the fresh default root when no explicit root is supplied.
- Normal user-facing file views should hide `.moonsuite` and `.tmp` unless an
  internal/debug surface explicitly asks for them.
- A selected `books/<book-id>` root must still resolve product homes through
  the owning suite root.
- MoonCode UI state should be append-only from the user's point of view.
  Re-sorting runtime events into older turns is a bug.
- Do not show fake "working" states. Show progress only after a MoonClaw or
  local runtime signal exists.

## Future Plan

- Execute the finite MoonCode/OpenSeek alignment plan: one MoonClaw-owned
  ordered conversation, one stable work disclosure per turn, and a thin
  MoonDesk renderer.
- Add longer fresh-root and reload UI smokes for Desk, Wiki, and Code.
- Keep extracting path/layout helpers to MoonLib instead of growing local string
  utilities.
- Keep domain workflows packaged as MoonBook/MoonClaw tools or app-tool packs.
- Prove clean-machine native install/update behavior with Lepusa bundles.
