# MoonCode Workspace

MoonCode is the code/chat editing mode for a selected executable MoonBook. It
sits beside MoonWiki:

```text
MoonWiki = edit what the book says
MoonCode = edit what the book can do
```

Both modes operate on the same MoonBook. MoonCode should not become a separate
truth store, an automation console, or a hidden runtime inside Moondesk.

## Product Boundary

Moondesk owns the desktop experience:

- select the MoonBook and MoonCode session
- render chat, streams, diffs, tests, packages, and review controls
- route operator commands to the configured MoonClaw runtime
- project durable MoonBook and MoonClaw sidecars into a native UI
- package generated tools and miniapps for the selected book

MoonClaw owns execution:

- model loop and tool execution
- prompt, steer, cancel, runtime loop, and runtime service behavior
- file edits, tests, builds, package generation, and event streaming
- durable runtime sidecars under the selected MoonSuite root's MoonClaw product
  home

MoonClaw must remain a standalone agent runtime. Moondesk should be able to
start, probe, and render it, but the runtime must also be useful to a CLI,
Moontown worker, or future standalone `mooncode` app without importing
Moondesk internals.

MoonBook owns durable outputs:

- `tools/`, `apps/`, `schemas/`, `book/site/generated/`
- `wiki/reviews/mooncode/`
- `portable/app-tool/`
- accepted code, review receipts, package manifests, and generated artifacts

`internal/mooncode` must stay UI-free and filesystem-neutral where practical.
It owns protocol/data projection. `internal/moonwiki` owns HTTP routing and host
IO. The Rabbita UI renders the result.

## Core Packages

```text
mooncode/core
  shared protocol constants and capability surface

internal/mooncode
  command, stream, runtime, readiness, review, package, and session contracts

internal/moonwiki
  Moondesk HTTP surface, local file IO, MoonClaw probes, and persistence

ui/rabbita-desk/main
  MoonCode screens and operator controls
```

This split is the standalone path. A standalone `mooncode` project should be
able to reuse the protocol/runtime contracts without taking MoonWiki, Rabbita,
or Moondesk desktop packaging.

## Shared Runtime, Separate Lanes

MoonCode, MoonWiki, and generic automation can share MoonClaw's runtime
substrate: sessions, event logs, tool execution, cancellation, process
lifecycle, and model/tool loops. They should not share one vague task/chat API.

- `MoonCode`: coding lane for executable book code, diffs, tests, packages, and
  proof artifacts.
- `MoonWiki`: book-editing lane for human-language wiki/source/review changes.
- `Moontown`: coordination lane for scheduling, book-to-book messages, and
  standing goals.
- Generic MoonClaw tasks: bounded background jobs for automation.

Each lane may call the same MoonClaw standalone runtime, but each keeps its own
typed protocol, durable evidence, and product vocabulary.

The visual shell is intentionally deferred while Lepusa settles. Until then,
MoonCode work should stay in the backend contracts, durable book layout,
MoonClaw runtime API, and host projections. New UI-specific behavior belongs
behind these contracts, not inside them.

`mooncode/core` must stay source-path neutral. It may name stable component ids
such as `mooncode.projection`, `moonwiki.host`, and `moonclaw.runtime`, but it
must not name Moondesk internals, MoonWiki implementation packages, or a sibling
MoonClaw checkout path. Host-specific package paths belong in host projections
such as `internal/mooncode/capabilities.mbt`.

## Desktop API

Moondesk exposes MoonCode through `/api/mooncode`. This namespace is a desktop
projection shell, not the runtime engine.

Top-level:

```text
GET /api/mooncode/status
GET /api/mooncode/capabilities
GET /api/mooncode/eval-harness
GET /api/mooncode/standalone-boundary
GET /api/mooncode/readiness-contract
GET /api/mooncode/sessions
GET /api/mooncode/sessions?format=listing
POST /api/mooncode/sessions
```

Session routes:

```text
GET  /api/mooncode/sessions/<id>/events
GET  /api/mooncode/sessions/<id>/stream
GET  /api/mooncode/sessions/<id>/stream-state
POST /api/mooncode/sessions/<id>/stream-state
GET  /api/mooncode/sessions/<id>/commands
POST /api/mooncode/sessions/<id>/commands
GET  /api/mooncode/sessions/<id>/preflight
GET  /api/mooncode/sessions/<id>/action-plan
GET  /api/mooncode/sessions/<id>/readiness
GET  /api/mooncode/sessions/<id>/change-set
GET  /api/mooncode/sessions/<id>/patch-set
GET  /api/mooncode/sessions/<id>/tool-approvals
GET  /api/mooncode/sessions/<id>/tool-authorization
POST /api/mooncode/sessions/<id>/tool-authorization
GET  /api/mooncode/sessions/<id>/test-runs
GET  /api/mooncode/sessions/<id>/package-candidates
GET  /api/mooncode/sessions/<id>/eval-report
POST /api/mooncode/sessions/<id>/eval-report
POST /api/mooncode/sessions/<id>/package-result
GET  /api/mooncode/sessions/<id>/runtime-handoff
GET  /api/mooncode/sessions/<id>/session-store
GET  /api/mooncode/sessions/<id>/runtime-commands
GET  /api/mooncode/sessions/<id>/command-jsonl
GET  /api/mooncode/sessions/<id>/runtime-events
POST /api/mooncode/sessions/<id>/runtime-events
GET  /api/mooncode/sessions/<id>/runtime-claim
POST /api/mooncode/sessions/<id>/runtime-claim
GET  /api/mooncode/sessions/<id>/runtime-replay
POST /api/mooncode/sessions/<id>/runtime-replay
GET  /api/mooncode/sessions/<id>/runtime-execution-plan
GET  /api/mooncode/sessions/<id>/runtime-supervisor
POST /api/mooncode/sessions/<id>/runtime-supervisor
POST /api/mooncode/sessions/<id>/runtime-service
GET  /api/mooncode/sessions/<id>/runtime-control
GET  /api/mooncode/sessions/<id>/runtime-evidence
```

These routes are intentionally projections and operator controls. They should
not reimplement MoonClaw execution or generic background-job chat.

## Runtime API

MoonClaw owns the native executable-code API under `/v1/code`:

```text
GET  /v1/code/capabilities
GET  /v1/code/sessions
GET  /v1/code/sessions/<id>
GET  /v1/code/sessions/<id>/stream
POST /v1/code/sessions/<id>/commands
GET  /v1/code/sessions/<id>/runtime-control
GET  /v1/code/sessions/<id>/runtime-claim
POST /v1/code/sessions/<id>/runtime-claim
POST /v1/code/sessions/<id>/runtime-turn
POST /v1/code/sessions/<id>/runtime-loop
GET  /v1/code/sessions/<id>/runtime-service
POST /v1/code/sessions/<id>/runtime-service
GET  /v1/code/sessions/<id>/runtime-events
POST /v1/code/sessions/<id>/runtime-events
POST /v1/code/sessions/<id>/tool-exec
GET  /v1/code/sessions/<id>/eval-report
GET  /v1/code/sessions/<id>/package-result
POST /v1/code/sessions/<id>/package-result
```

Moondesk may probe these endpoints and render their state. It should not expose
MoonClaw's noninteractive automation API as the MoonCode product path.
Durable runtime settlement is represented by claim/turn receipts in
`runtime-receipts.jsonl`, not a separate runtime API.

The `/v1/code/sessions/<id>/commands` payload is part of the shared
`mooncode/core` protocol. `native_command_body_required_fields()` and
`native_command_body_supported_fields()` define the stable top-level command
envelope so Moondesk producers and MoonClaw intake validation stay aligned
from the same field contract.

## Durable Layout

MoonCode native session state is product-home scoped under the selected
MoonSuite root:

```text
<MoonSuiteRoot>/
  .moonsuite/
    products/
      moonclaw/
        mooncode/
          sessions/<session-id>/
            session.json
            events.jsonl
            commands.jsonl
            runtime-commands.jsonl
            runtime-receipts.jsonl
            package-results.jsonl
books/<book-id>/
  wiki/
    reviews/
      mooncode/<session-id>/
        action-plan.json
        change-set.json
        patch-set.json
        tool-approvals.json
        test-runs.json
        eval-report.json
        runtime-handoff.json
  portable/
    app-tool/
      mooncode/<session-id>/
```

MoonClaw may write runtime sidecars. MoonBook owns accepted review/package
artifacts. Moondesk only joins paths, displays state, and persists desktop-side
records when needed.

## Command Model

MoonCode commands are typed:

- `prompt`: start or queue a coding turn
- `steer`: guide the active or next turn
- `cancel`: stop active or pending work
- `run_tests`, `run_build`, `run_eval`: request verification
- `apply_patch`, `revert_patch`: modify files with reviewable evidence
- `accept`, `reject`: record review decisions
- `package`: produce a reusable book-owned artifact

Every command should produce durable evidence: command records, stream events,
tool events, diffs, test results, package manifests, or review receipts.

## Readiness

Readiness is an evidence summary, not a ranked assessment. The contract is:

```text
GET /api/mooncode/readiness-contract
GET /api/mooncode/sessions/<id>/readiness
```

The response lists checks, evidence, first blocker, next action, and next
owner. Missing evidence keeps a session blocked until MoonClaw, MoonBook, or
Moondesk supplies the responsible artifact.

## Executable-Book Lifecycle

The portable lifecycle contract lives in `mooncode/core` as
`executable_book_lifecycle_contract_json()`. It is intentionally independent of
any desktop framework. The required path is:

```text
select_book
-> start_session
-> propose_change
-> edit_code
-> verify_code
-> review_diff
-> accept_result
-> package_output
-> resume_session
```

MoonClaw owns runtime evidence, MoonBook owns accepted artifacts, and
Bookkeeper owns acceptance. A host may render or select, but completion is
proved only by current evidence for the same `book_root` and `session_id`.

`internal/mooncode` derives
`mooncode-executable-book-lifecycle-report` from the same readiness evidence
and attaches it to `session_summary` as `executable_book_lifecycle`. This keeps
the executable-book proof backend-owned and reusable by Rabbita, Lepusa, a CLI,
or another host without changing the runtime protocol.

## Completion Criteria

MoonCode is complete when a user can:

1. Select a MoonBook.
2. Switch between MoonWiki and MoonCode.
3. Start or resume a durable coding session.
4. Chat with MoonClaw through the MoonCode UI.
5. Generate or modify executable book code.
6. See live reasoning, progress, tool calls, diffs, tests, and artifacts.
7. Review and accept or reject changes.
8. Run tests/builds/evals from the UI.
9. Package results as MoonBook-owned tools, miniapps, generated sites, or
   portable app-tools.
10. Resume from durable session, command, and event logs.
11. Extract the MoonCode protocol/runtime contracts without breaking MoonWiki
    or Moondesk.
12. Prove every step in `mooncode-executable-book-lifecycle.v1` without relying
    on a specific desktop framework.

The focused test strategy for this completion path lives in
[Code Mode Test Plan](CODE_MODE_TEST_PLAN.md).
