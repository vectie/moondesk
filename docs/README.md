# MoonDesk Documentation Guide

Start with the [product contract](PRODUCT_CONTRACT.md) for current maturity,
capability-truth rules, pack hosting and release gates.
Use [ENGINEERING_MATURITY.md](ENGINEERING_MATURITY.md) for the executable
capability stages, integration manifest, and evidence-promotion rules.

MoonDesk is the human desktop shell for MoonSuite. It should make books,
files, Wiki work, Code work, MoonFind-authored graphs, town requests, runtime
evidence, and app-tool packaging visible to an operator without taking
ownership of the runtimes or domain workflows it displays.

## Scope And Boundary

MoonDesk owns the local desktop experience:

- workspace and book discovery
- scoped file browsing, preview, search, edit, import, and export
- MoonWiki and MoonCode presentation for the selected book
- catalog-backed Work-graph selection, inspection, and MoonFlow handoff
- MoonTown request and daemon controls
- MoonClaw status, stream, package, and review projections
- Lepusa bundle/release integration for the native shell

MoonDesk does not own durable book truth, discovery intent, agent execution,
workflow scheduling/recovery, exact authority policy, civic synthesis, or
domain-specific workflow logic. MoonBook owns MoonWiki and Bookkeeper;
MoonFind owns discovery and desired graph intent; MoonFlow owns workflow
execution and recovery; MoonGate owns exact capability/authority resolution;
MoonClaw is the sole agent runtime; MoonTown owns civic coordination and
reviewable cross-book synthesis. Shared filesystem contracts come from MoonLib.

## Reading Order

1. [PLAN.md](PLAN.md): product model, user flow, non-goals, and engineering bar.
2. [ARCHITECTURE.md](ARCHITECTURE.md): package ownership, HTTP surface, and
   cross-product boundaries.
3. [SUITE_COMPOSITION_CANVAS.md](SUITE_COMPOSITION_CANVAS.md): MoonFind intent,
   catalog-backed selection, MoonFlow import, and effect-authority boundary.
4. [MOONFLOW_RECEIVER_LOOP.md](MOONFLOW_RECEIVER_LOOP.md): generic
   manifest-owned app intake, receipt return, visible state, and recovery.
5. [SUPERVISOR_CLOSED_LOOP.md](SUPERVISOR_CLOSED_LOOP.md): first-agent
   ownership, MoonDesk's narrow MoonClaw control proxy, Bookkeeper acceptance,
   and the restart-safe cross-product call chain.
6. [DESK_MODE_DESIGN.md](DESK_MODE_DESIGN.md): file/workspace mode behavior.
7. [FIRST_RUN_AND_VOCABULARY.md](FIRST_RUN_AND_VOCABULARY.md): evidence-backed
   first-run inventory, target vocabulary, state matrix, and capability setup.
8. [NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md](NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md):
   packaged macOS picker phases, defects, interaction evidence, persistence,
   and remaining restart/platform boundary.
9. [WIKI_MODE_UX_PLAN.md](WIKI_MODE_UX_PLAN.md): normal-user Wiki information
   hierarchy, progressive disclosure, implementation phases, and UX E2E gates.
10. [WIKI_MODE_USER_E2E_PLAN.md](WIKI_MODE_USER_E2E_PLAN.md): user-visible Wiki
   journeys, rationale, expected behavior, methodology, and acceptance evidence.
11. [MOONCODE.md](MOONCODE.md): code-mode contract and MoonClaw handoff.
12. [MoonCode agent machine and dynamic graph design](MOONCODE_AGENT_MACHINE_AND_DYNAMIC_GRAPH.md):
    consolidated execution primitives, data model, framework comparison and
    task-driven runtime graph; separates current implementation from design,
    records the completed cleanup and the remaining module-by-module deletion
    plan from the OS/compiler/data-system perspective.
    The [November 4 plan](mooncode-discussion-2026-11-04/CURRENT_PLAN.md)
    retains the historical simplification and deletion decisions.
13. [CODE_MODE_TEST_PLAN.md](CODE_MODE_TEST_PLAN.md): focused runtime,
    conversation, recovery, and deliverable checks.
    [November 6 real bug delivery](MOONCODE_LIVE_BUGFIX_2026-11-06.md) records
    actual-model quality, rework, token cost, elapsed time and verification gaps.
    [Real executor delivery](MOONCODE_LIVE_EXECUTOR_BUGFIX_2026-11-06.md)
    records autonomous repair/testing followed by independent main acceptance.
    [Full real-repository Native delivery](MOONCODE_LIVE_NATIVE_REPOSITORY_2026-11-06.md)
    records direct MoonLib main execution, full Native acceptance and all three
    attempts' costs.
    [Three-run token audit](MOONCODE_TOKEN_AUDIT_2026-11-06.md) traces tool
    failures, repeated exploration and context growth, with fixed-history
    projection replay and a real peer-task rerun; records all failed costs.
    [Follow-up audit](MOONCODE_TOKEN_AUDIT_FOLLOWUP_2026-11-06.md) records the
    remaining duplicate input, SDK/snapshot fixes and the 213,432-input rerun,
    including unsuccessful and inconclusive measurements.
14. [MOONCODE_DEVELOPER_TOOLS.md](MOONCODE_DEVELOPER_TOOLS.md): optional
    terminal evidence, browser preview, and explicit comparison surfaces.
15. [MoonCode discussion archive](mooncode-discussion-2026-11-04/README.md):
    complete four-project analysis, source material, and design revisions.
16. [AGENT_WORKSPACE_EVOLUTION.md](AGENT_WORKSPACE_EVOLUTION.md): implemented
    document-agent workflows and portable MoonBook agent ownership.
17. [OWB_SECOND_ROUND_FEATURE_COMPARISON.md](OWB_SECOND_ROUND_FEATURE_COMPARISON.md):
    feature-only comparison and recommended Agent Library, learning, agenda,
    collaboration, artifact, multimodal, and subscribed-source journeys.
18. [STATUS.md](STATUS.md): implementation evidence and known gaps.
19. [BASELINE_2026-07-27.md](BASELINE_2026-07-27.md): dated Phase 0 baseline,
    repository metrics, and explicitly unmeasured gaps.
20. [DOCUMENT_TRUTH_AUDIT_2026-07-27.md](DOCUMENT_TRUTH_AUDIT_2026-07-27.md):
    historical document audit; its phase status is not current readiness.
21. [FULL_VALIDATION_PROOF_2026-07-27.md](FULL_VALIDATION_PROOF_2026-07-27.md):
    retained clean-checkout validation transcript and its evidence boundary.
22. [RELEASE_PROCESS.md](RELEASE_PROCESS.md): preview and credentialed release
    procedure, immutable-output policy, and remote gate.
23. [PREVIEW_RELEASE_PROOF_2026-07-27.md](PREVIEW_RELEASE_PROOF_2026-07-27.md):
    dated unsigned-candidate commands, checksums, refusal tests, and limits.
24. [qualification/README.md](qualification/README.md): UI-to-UI qualification
    rules, case results, interproduct seams, and retained evidence.
25. [ROADMAP.md](ROADMAP.md): active product tracks and future gates.
26. [MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md](MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md):
    MoonDesk-wide productization and external release gates.
27. [MOONSUITE_LAYOUT_MIGRATION_PLAN.md](MOONSUITE_LAYOUT_MIGRATION_PLAN.md):
    historical migration and validation record, not a current plan.

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

- Follow the current MoonCode simplification plan: one primary agent, one
  completion decision, reused journal/recovery, and a thin MoonDesk renderer.
  Delete superseded mechanisms rather than layering new frameworks.
- Add longer fresh-root and reload UI smokes for Desk, Wiki, and Code.
- Keep extracting path/layout helpers to MoonLib instead of growing local string
  utilities.
- Keep domain workflows in their owning product packs and expose only typed
  operations and pack-owned applications to MoonDesk.
- Prove clean-machine native install/update behavior with Lepusa bundles.

- [Explore JSON values](SOURCE_JSON_VALUES.md): inspect current-draft nested
  objects/arrays by JSON Pointer and download exact subtrees.

- [Review and replace a JSON value](SOURCE_JSON_REPLACEMENT.md): correct one nested draft value after before/after review, preserving all surrounding source tokens.

## Source Markdown link maintenance

[Inspect and retarget Markdown links](MARKDOWN_LINK_MAINTENANCE.md) inventories
supported current-draft inline destinations, selects exact source locations and
previews one/all exact-match replacements before an ordinary unsaved draft edit.
