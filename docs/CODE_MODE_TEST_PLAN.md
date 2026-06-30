# Code Mode Test Plan

Moondesk currently has three workspace modes in `ui/rabbita-desk/main`:
`Desk`, `MoonWiki`, and `MoonCode`. This plan focuses only on `MoonCode`, the
code mode. The goal is to prove that coding functionality works end to end with
typed tool boundaries, deterministic harnesses,
durable sessions, command execution evidence, and realistic integration tests.

## Scope

Code mode is responsible for book-scoped coding sessions:

- selecting a MoonBook context from Desk or Wiki
- starting and resuming MoonCode sessions
- sending prompt, steer, cancel, test, build, eval, package, accept, and reject
  commands
- projecting MoonClaw runtime state without owning the runtime loop
- rendering transcript, stream events, tool calls, diffs, tests, packages,
  readiness, and review controls
- proving that durable MoonBook artifacts can survive reloads and process
  restarts

Out of scope for this plan:

- generic MoonWiki prose editing
- Moontown scheduling behavior except where it appears as context
- live model quality evaluation as a required unit-test gate
- Lepusa packaging except for smoke tests that ensure code mode still opens

## Test Architecture

Use four layers. Lower layers must be deterministic and run in ordinary
`moon test`; live runtime/model tests are explicit manual or scheduled gates.

1. Contract tests
   - Package: `mooncode/core`, `internal/mooncode`
   - Purpose: prove stable JSON shapes, command envelopes, readiness contracts,
     tool policies, runtime claim/replay, evidence projection, and package
     manifests.

2. Host API integration tests
   - Package: `internal/moonwiki`
   - Purpose: exercise `/api/mooncode` handlers against a temporary MoonBook
     tree and real JSON body readers. These should test routing, persistence,
     traversal rejection, method policy, and durable sidecar writes.

3. UI state integration tests
   - Package: `ui/rabbita-desk/main`
   - Purpose: exercise `WorkspaceMode.MoonCode`, reducer actions, command
     payloads, stream merge behavior, selected-session reloads, and status text.
     These tests should stay UI-framework-local and avoid browser dependence.

4. End-to-end smoke tests
   - Package or script: `cmd/main` plus optional shell/cram-style fixtures
   - Purpose: run the native host server against a temporary book, call real
     HTTP endpoints, and verify the resulting session files, event streams, and
     API projections. These tests are heavier but should still avoid real model
     calls by using deterministic runtime records.

## Reference Patterns To Reuse

Use existing coding-agent harness patterns as references, not dependencies.

- Tool boundary: mirror the split between raw provider/tool JSON and
  local typed actions. MoonCode equivalents are command packets, tool
  authorization previews, native command execution plans, and runtime receipts.
- Decode tests: every JSON intake path should have small tests for required
  fields, wrong types, unknown actions, and stable error messages.
- Deterministic harness: add a MoonCode harness that creates a temporary
  MoonBook, appends commands/events/receipts, and returns a report JSON that can
  be asserted without a model.
- Eval separation: model-backed coding evals should exist, but ordinary tests
  must use dry-run records and local oracles.
- CLI examples: copy the idea of offline cram-style tests for help,
  validation, session listing, and failure-before-network behavior.

## Fixtures

Create a reusable test fixture builder for code mode integration tests:

```text
tmp/
  workspace/
    .moontown/
      books/
        demo-book/
          raw/
          tools/
          apps/
          schemas/
          wiki/
            reviews/
              mooncode/
          .moonclaw/
            mooncode/
              sessions/
```

The fixture builder should support:

- empty book with no sessions
- book with one completed session
- book with one running session and pending runtime command
- book with pending tool authorization
- book with patch, test, eval, and package evidence
- malformed sidecar records for negative tests

Keep fixture paths temporary and generated at test runtime. Do not depend on
the developer's `.moontown`, `.moonclaw`, or `wiki` directories.

## End-to-End Scenarios

### Mode Selection

Prove the user can enter code mode from each supported route.

- Initial URL/state chooses `MoonCode` when the shell mode is `mooncode`.
- Desk "Open MoonCode" keeps selected workspace and context path.
- Wiki to Code preserves selected MoonBook context.
- Code to Desk does not erase selected MoonCode session state.
- Code mode always uses `Files` activity rather than Wiki-specific activity.

Suggested test files:

- `ui/rabbita-desk/main/app_code_mode_navigation_wbtest.mbt`
- extend `ui/rabbita-desk/main/app_desk_navigation_wbtest.mbt`

### Session Creation

Exercise UI payload, host API, and durable files together.

Flow:

```text
select demo book
-> NewMoonCodeSession
-> SetMoonCodePrompt("add a parser")
-> SendMoonCodeMessage
-> POST /api/mooncode/sessions
-> session.json, commands.jsonl, events.jsonl are created
-> GET /api/mooncode/sessions returns the new projection
-> UI selects the created session and clears the composer
```

Assertions:

- `workspace_id`, `context_path`, `model`, and `web_search` are preserved.
- the first command uses `prompt`, not `steer`
- session title follows current UI rules
- transcript and event projection are stable after reload
- general MoonCode without a selected book does not write into a book path

Suggested test files:

- `internal/moonwiki/mooncode_session_e2e_wbtest.mbt`
- `ui/rabbita-desk/main/app_code_mode_session_wbtest.mbt`

### Prompt, Steer, And Cancel

Exercise command routing after a session exists.

Flow:

```text
existing idle session
-> send composer
-> POST /commands action=prompt
-> mark session running or queued
-> send composer again
-> POST /commands action=steer
-> cancel command
-> runtime-control/readiness reflects cancellation
```

Assertions:

- `mooncode_composer_action` chooses `steer` for running, queued, or non-empty
  queued count.
- prompt text is trimmed and empty prompts are rejected in UI state before HTTP.
- command ordering is append-only.
- cancel does not delete prior evidence.

### Runtime Claim And Replay

Prove the desktop projection can drive a standalone runtime without becoming
the runtime.

Flow:

```text
POST /commands action=prompt
-> GET /runtime-claim shows claimable command
-> POST /runtime-claim leases command
-> GET /runtime-replay skips active lease
-> POST /runtime-events appends tool/progress/test events
-> POST /runtime-replay acknowledges delivery
-> GET /runtime-evidence reports command-scoped proof
```

Assertions:

- only one runtime claim owns a pending command at a time
- expired leases become claimable again
- invalid earlier commands block later commands in order
- delivered commands are not replayed
- runtime evidence requires command-scoped proof
- runtime event sink and session stream agree on event ids

Suggested test files:

- extend `internal/mooncode/runtime_claim_wbtest.mbt`
- extend `internal/mooncode/runtime_replay_ack_wbtest.mbt`
- `internal/moonwiki/mooncode_runtime_e2e_wbtest.mbt`

### Tool Authorization

Prove mutating tools are blocked until approved and safe previews remain cheap.

Flow:

```text
runtime proposes read tool
-> authorization preview auto-approves read
runtime proposes edit/shell/package tool
-> GET /tool-authorization shows pending gate
-> POST /tool-authorization approves or rejects
-> runtime claim/evidence reflects decision
```

Assertions:

- read-only previews do not create review gates.
- edit/write/shell/package previews require approval.
- repeated tool calls are isolated by tool call id.
- rejected tools remain visible as durable evidence.
- approval records include enough context for a human review surface.

### Patch, Test, Review, And Readiness

Exercise the executable-book lifecycle contract.

Flow:

```text
runtime emits patch proposal
-> GET /change-set and /patch-set render diff state
runtime emits moon check/test result
-> GET /test-runs includes passed/failed evidence
operator accepts or rejects patch
-> readiness/action-plan updates blockers and next owner
```

Assertions:

- readiness is blocked without file edit, command execution, patch review, test
  evidence, and package output where required.
- failed tests remain blockers.
- accepted patch receipts and rejected patch receipts are distinct.
- action plan recommends the next concrete step.
- `.mbti` and public API changes are visible as reviewable artifacts when
  present.

### Package Output

Prove accepted code can become a MoonBook-owned artifact.

Flow:

```text
accepted patch and passing tests
-> command action=package
-> POST /package-result with package manifest
-> GET /package-candidates
-> durable files appear under portable/app-tool/mooncode/<session-id>/
```

Assertions:

- package result rejects missing source readiness or invalid paths.
- package manifest keeps session id, command id, source path, output path, and
  test evidence.
- package candidates are stable after reload.
- exported app-tool paths stay inside selected MoonBook.

### Stream And Resume

Prove long-running sessions survive client reload and host restart.

Flow:

```text
GET /stream?since=0
-> POST /stream-state checkpoint
-> append more events
-> GET /stream?since=<cursor>
-> restart host or reconstruct model from disk
-> GET /sessions and /runtime-events
```

Assertions:

- incremental stream returns only newer events.
- stream-state clamps invalid cursors.
- duplicate event ids are deduped in UI merge helpers.
- selected session reload fetches both stream and runtime events.
- durable session summary matches the latest disk state.

### Negative And Security Cases

Every endpoint that reads or writes paths must have negative integration tests.

- path traversal in `book_root`, `context_path`, artifact paths, and review
  paths
- unknown session id
- malformed JSON body
- wrong HTTP method
- unsupported command action
- package result for a different session
- runtime receipt for an unknown command
- cross-book artifact path
- missing workspace root
- stale runtime event with older protocol version

Expected failures should assert response shape and durable state. A rejected
request must not create partial files.

## Harness Plan

Add a deterministic MoonCode harness package once the first host API E2E test
needs shared setup. Suggested location:

```text
internal/mooncode_harness/
  moon.pkg
  fixture.mbt
  report.mbt
  harness.mbt
  harness_wbtest.mbt
```

The harness should expose:

- `create_demo_book()`
- `create_session(book_root, title, prompt)`
- `append_runtime_command(session, action)`
- `append_runtime_event(session, event)`
- `append_receipt(session, command_id, status)`
- `run_code_mode_harness() -> Json`

The report should include:

- session count
- command count
- event count
- receipt count
- readiness status
- first blocker
- package candidate count
- rejected request count

This mirrors Openseek's deterministic tool harness: a single test can exercise
the same typed boundary the UI and runtime use, but without a model call.

## Proposed Test Matrix

```text
mooncode/core
  protocol field stability
  executable-book lifecycle contract
  native command body compatibility

internal/mooncode
  command decode and lifecycle
  runtime queue, claim, replay, receipt, evidence
  tool authorization gates
  action plan and readiness projection
  review patch/test/package artifacts
  session summary/listing/store

internal/moonwiki
  /api/mooncode route dispatch
  session create/list/show
  stream and stream-state
  command append and command-jsonl
  runtime claim/replay/events/evidence
  eval-report and package-result ingest
  traversal and malformed request rejection

ui/rabbita-desk/main
  MoonCode mode selection
  new session draft state
  composer prompt/steer behavior
  session selection reload commands
  stream merge and trim helpers
  runtime event sink projection
  command palette entries for code mode

cmd/main
  serve/desktop help and validation
  offline host startup smoke
  HTTP smoke for code mode routes
  native bundle opens code-mode route
```

## Validation Commands

Default gate:

```bash
moon check --target all
moon test
moon info && moon fmt
```

Targeted gates while developing:

```bash
moon test internal/mooncode
moon test internal/moonwiki --filter "mooncode"
moon test ui/rabbita-desk/main --filter "MoonCode"
moon test cmd/main --filter "mooncode"
```

Coverage pass:

```bash
moon coverage analyze > uncovered.log
```

Manual or scheduled gates:

```bash
moon run cmd/main -- serve /tmp/moondesk-code-mode-fixture --port 4188
curl http://127.0.0.1:4188/api/mooncode/capabilities
curl http://127.0.0.1:4188/api/mooncode/sessions
```

Live MoonClaw/model gates should be separate from ordinary CI and clearly
marked as nondeterministic. They should record the model, runtime version,
prompt, commands, events, package artifacts, and final readiness state.

## Done Criteria

Code mode is sufficiently tested when:

- a deterministic end-to-end test proves create session -> command -> runtime
  claim -> event ingest -> receipt -> readiness -> package projection
- UI reducer tests prove the user can enter MoonCode, start a session, send a
  prompt, steer a running session, and reload stream/runtime state
- host API tests cover every `/api/mooncode` route with at least one success or
  explicit method/validation test
- negative tests prove path traversal and malformed runtime records cannot
  create durable side effects
- resume tests prove sessions survive process restart from disk records
- live model/runtime tests exist as manual or scheduled checks, but deterministic
  tests remain the merge gate
- `.mbti` diffs from `moon info` are reviewed whenever public contracts change
