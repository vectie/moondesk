# MoonDesk Documentation Guide

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
4. [WIKI_MODE_UX_PLAN.md](WIKI_MODE_UX_PLAN.md): normal-user Wiki information
   hierarchy, progressive disclosure, implementation phases, and UX E2E gates.
5. [WIKI_MODE_USER_E2E_PLAN.md](WIKI_MODE_USER_E2E_PLAN.md): user-visible Wiki
   journeys, rationale, expected behavior, methodology, and acceptance evidence.
6. [MOONCODE.md](MOONCODE.md): code-mode contract and MoonClaw handoff.
7. [MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md](MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md):
   canonical conversation/runtime upgrade plan.
8. [MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md](MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md):
   finite single-owner conversation, thinking, and live-update correction.
9. [STATUS.md](STATUS.md): current implementation state and known gaps.
10. [ROADMAP.md](ROADMAP.md): active product tracks and future gates.
11. [MOONSUITE_LAYOUT_MIGRATION_PLAN.md](MOONSUITE_LAYOUT_MIGRATION_PLAN.md):
   historical migration plan and validation record.

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
