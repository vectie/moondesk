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
Across all layers, MoonLib is the only shared MoonSuite filesystem contract
provider. Code-mode tests may call Moondesk's local adapter when they are
testing Moondesk behavior, but the adapter itself must be proven to wrap
MoonLib. MoonStat may appear only as a validator or drift-report consumer, not
as the source used to build code-mode paths.

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
    books/
      demo-book/
        raw/
        tools/
        apps/
        schemas/
        wiki/
          reviews/
            mooncode/
    .moonsuite/
      product-registry.json
      products/
        mooncode/
          sessions/
        moonclaw/
          jobs/
        moontown/
          requests/
    .tmp/
      products/
        mooncode/
```

The fixture builder should support:

- empty book with no sessions
- book with one completed session
- book with one running session and pending runtime command
- book with pending tool authorization
- book with patch, test, eval, and package evidence
- malformed sidecar records for negative tests

Keep fixture paths temporary and generated at test runtime. Do not depend on
the developer's `.moontown`, `.moonclaw`, `.moonsuite`, or `wiki` directories.
Fixtures must build MoonSuite paths through MoonLib `@moonsuite` helpers, or
through a product-local adapter that is itself tested as a thin wrapper over
MoonLib. Do not add new test fixtures that duplicate `.moonsuite`, `.tmp`,
`books`, product-home, or product-registry string contracts.
If a new fixture needs a reusable path class that MoonLib does not expose yet,
the test plan is to add that constructor to MoonLib first, then consume it from
MoonCode/Moondesk tests.

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

### Prompt, Explicit Steering, And Cancel

Exercise command routing after a session exists.

Flow:

```text
existing idle session
-> send composer
-> POST /commands action=prompt
-> command response acknowledges queued canonical turn
-> UI/backend calls /runtime-service explicitly
-> runtime-service failure is surfaced as runtime-service failure, not submit failure
-> send composer again
-> POST /commands action=prompt
-> use explicit steering control/API
-> POST /commands action=steer
-> cancel command
-> runtime-control/readiness reflects cancellation
```

Assertions:

- ordinary composer text always posts `prompt`, including second and third
  messages in a running or failed session.
- backend command enqueue does not start runtime or synthesize runtime progress.
- runtime-service starts are explicit and fenced once per queued command count.
- if native MoonClaw later emits a command-scoped final assistant answer, that
  answer becomes the canonical completion for the same turn instead of leaving
  stale infrastructure state visible as the final chat state.
- explicit steering remains covered through the command API/control surface, not
  through ordinary chat input.
- prompt text is trimmed and empty prompts are rejected in UI state before HTTP.
- command ordering is append-only.
- cancel does not delete prior evidence.

### Native Sidecar Reply Ingestion

Exercise raw MoonClaw sidecar evidence as input, not as a second transcript.

Flow:

```text
fresh code session
-> send first prompt
-> send second prompt
-> send third prompt
-> append raw MoonClaw assistant_message events with command_id for each command
-> GET /api/mooncode/sessions imports sidecar events into Moondesk append log
-> GET /api/mooncode/sessions/:id/events returns imported canonical events
-> GET /api/mooncode/sessions/:id/stream returns the same ordered replies
```

Assertions:

- native `assistant_delta`, `assistant_message`, reasoning, runtime update, and
  terminal error events preserve `command_id` as normalized `command_packet`
  ownership.
- native runtime contract reports mark command-scoped chat/progress events as
  projection-safe and flag unscoped assistant/chat evidence as unsafe.
- unscoped watcher, service lifecycle, usage, and runtime-loop events remain
  diagnostic-only and do not become chat turns.
- sidecar evidence is deduped into Moondesk's append log before projection.
- first, second, and third assistant replies appear under the matching user
  turns and stay stable across replay.
- the browser smoke writes deterministic native sidecar replies after three
  visible prompt sends and waits for the chat surface to render those replies in
  turn order.
- a stale runtime-unavailable event can be recovered by a later command-scoped
  `done` assistant final, but a real failed final remains failed.
- the main chat never renders direct sidecar rows, fake working rows, or
  runtime-service lifecycle messages as conversation items.

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
- runtime event ingest and session stream projections agree on event ids

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
-> GET /sessions and stream-state from durable logs
```

Assertions:

- incremental stream returns only newer events.
- stream-state clamps invalid cursors.
- duplicate event ids are deduped in UI merge helpers.
- selected session reload fetches canonical session data and stream updates,
  not browser-owned runtime diagnostic snapshots.
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
  ordinary composer prompt behavior
  explicit steering controls
  session selection reload commands
  stream merge and trim helpers
  canonical conversation projection
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
moon check ui/rabbita-desk/main --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000
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

Current live contract gate:

```bash
scripts/mooncode_live_runtime_contract_smoke.sh
scripts/mooncode_live_runtime_loop_smoke.sh
scripts/mooncode_live_runtime_multiturn_smoke.sh
scripts/mooncode_live_runtime_control_boundary_smoke.sh
```

This gate starts a temporary MoonSuite root, launches a real MoonClaw daemon,
posts a command-scoped assistant event through MoonClaw's native
`/v1/code/sessions/<id>/runtime-events?book_root=<path>` endpoint, then asks
Moondesk to import the native state. It fails if the native contract is not
projection-safe, if unsafe unscoped projection events are present, if the final
assistant reply is not the canonical conversation output, or if a legacy
`.moonclaw` root appears.

The loop and multiturn gates additionally prove native command replay and
explicit runtime-service execution. The multiturn gate is the regression check
for first/second/third prompt order: it fails if later replies duplicate,
reorder, or erase earlier conversation turns.

The loop gate also checks event-backed runtime-service recovery: after importing
MoonClaw's native `runtime.service_finished` event, Moondesk must release its
local runtime-service lease and allow an immediate same-command-count service
restart.

The control-boundary gate drives prompt -> steer -> prompt -> cancel through the
real Moondesk runtime-service boundary. It fails if steer/cancel text leaks into
the canonical chat transcript, if deferred steering is not later applied through
MoonClaw evidence, if dropped cancel is missing, or if a legacy `.moonclaw` root
appears.

Visible progress projection gate:

```bash
moon test internal/mooncode --filter "mooncode conversation projection *progress*" --target native
```

This deterministic gate protects the Phase 25 transcript boundary. It fails if
a generic command-scoped `runtime_update` becomes a chat progress row, if
allowed MoonClaw turn-start/reasoning/tool evidence stops appearing between the
owning user prompt and assistant reply, or if visible progress exposes
MoonClaw/runtime bookkeeping, `model-tool-calls`, command ids, or raw tool JSON.

Model planner evidence gate:

```bash
moon test internal/mooncode --filter "mooncode model planner evidence*" --target native
```

This deterministic Phase 26 gate protects the first-time clean runtime
contract for model-backed turns. It fails if a queued model command is treated
as active work, if a started turn without planner evidence remains in a vague
thinking state, if `runtime.planner_failed` is not accepted as durable
command-scoped failure evidence, or if a planner-to-assistant sequence cannot
prove one append-only command owner.

Turn ownership and abort gate:

```bash
moon test internal/mooncode --filter "mooncode conversation projection*" --target native
moon test internal/mooncode --filter "mooncode runtime control*" --target native
```

This deterministic Phase 27 gate protects append-only turn ownership. It fails
if visible conversation rows lack command/turn/run owner fields, if unscoped
runtime failures attach to the latest active turn, if prompt-scoped
`runtime_aborted` does not close the owning turn as cancelled, if cancel-scoped
abort evidence leaks into chat, or if steer/cancel runtime-control decisions do
not advertise their required MoonClaw settlement events.

Package/review model-flow gate:

```bash
moon test internal/mooncode --filter "mooncode package review model flow*" --target native
moon test internal/mooncode --filter "mooncode runtime receipt*" --target native
```

This deterministic Phase 28 gate protects package/review model decisions from
stale or broad evidence. It fails if accepted package runs lack package
manifest, review accept receipt, passing tests, verified package readiness, and
assistant summary from the same command owner; if reject receipts do not close a
rejected run; if command-scoped failures are not terminal; or if old-command
package/review evidence can settle the current package command.

Browser conversation stability gate:

```bash
scripts/desk_mode_browser_smoke.sh full
moon check ui/rabbita-desk/main --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000
```

This Phase 29 gate protects the actual browser surface. It submits first,
second, and third MoonCode prompts, samples the transcript for transient
front-page flashes and reorder windows, fails duplicate or disappearing user
messages, checks that activity rows stay under their owning command, imports
event-backed native assistant replies, verifies completed progress is folded,
and then reloads to prove the old conversation persists.

The browser gate opens MoonCode with `mooncodeRuntime=manual`. That disables
only UI runtime auto-start for the smoke run; normal product sessions still
start MoonClaw automatically. This keeps the ordering/reload test deterministic
while still requiring real canonical backend events before the UI can show
assistant replies.

Runtime-service failure gate:

```bash
scripts/mooncode_runtime_service_failure_smoke.sh
```

This gate starts a temporary MoonSuite root without a MoonClaw service, submits
the first MoonCode prompt, calls the explicit `/runtime-service` endpoint, and
then fetches canonical sessions again. It fails if submit fabricates an
assistant reply, if runtime-service failure does not return an API error, if the
turn stays queued/thinking, if the failed assistant reply is attached to a
different command id, or if a legacy `.moonclaw` root appears.

Frontend/backend ownership gate:

```bash
moon check ui/rabbita-desk/main --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test internal/moonwiki --filter "mooncode code mode HTTP routes preserve three prompt conversation order" --target native
```

These Phase 30 gates keep the normal session-list contract clean: the backend
must send full canonical conversation state, and the browser must not hide a
missing or regressed conversation by copying an older local transcript over a
newer response. The UI reducer assertion lives in the Rabbita desk wbtest
source; the current Moon package selector does not expose that JS-only main
package as a runnable `moon test` target by path, so use the JS package check
plus the backend HTTP E2E as the executable gate.

Frontend route ownership gate:

```bash
scripts/validate_mooncode_frontend_routes.sh
moon test core --target native --filter "mooncode desktop routes*"
(cd ui/rabbita-desk && moon check main --target js --warn-list +73 --diagnostic-limit 80)
```

This Phase 31 gate keeps desktop MoonCode route construction out of individual
frontend command handlers. It fails if active Rabbita MoonCode code contains raw
`/api/mooncode` strings outside the shared core boundary, or if session
listing, command submit, stream polling, stream checkpoint, and runtime-service
route helpers stop encoding workspace/session ids correctly.

Phase 39 removes the old Rabbita-local helper entirely. MoonCode desktop URL
formatting now lives in `vectie/moondesk/core`, and the validator rejects
reintroducing `ui/rabbita-desk/main/mooncode_route_helpers.mbt`.

Shared desktop route ownership gate:

```bash
scripts/validate_rabbita_desktop_routes.sh
moon test core --target native --filter "desktop api route builder*"
moon test core --target native --filter "workspace desktop routes*"
moon test core --target native --filter "product and system desktop routes*"
(cd ui/rabbita-desk && moon check main --target js --warn-list +73 --diagnostic-limit 80)
```

This Phase 40 gate keeps generic desktop API URL construction out of active
Rabbita command and settings code. It fails if production UI code reintroduces
raw `/api/` route literals or frontend-local `encode_component` /
`encode_path` route encoders instead of consuming the shared `@desk` helpers.

Desktop API method contract ownership gate:

```bash
moon test core --target native --filter "desktop api route contracts*"
moon test internal/moonwiki --target native --filter "desktop api route contract drives*"
scripts/validate_desktop_api_backend_method_contract.sh
```

This Phase 41 gate gives generic non-MoonCode desktop API families the same
method-contract shape as MoonCode. It fails if workspace, town, MoonClaw,
review/preferences, or book routers reintroduce branch-local `GET` / `POST`
method policy, if contract-backed `405 Allow` responses drift, or if the stale
`/api/town/control` route comes back instead of `/api/town/dispatch`.

Frontend session effect ownership gate:

```bash
(cd ui/rabbita-desk && moon test main --target js --filter "mooncode session effects*")
```

This Phase 32 gate keeps timing-sensitive MoonCode follow-up effects out of
individual reducer branches. It fails if submit acknowledgement stops
refreshing canonical sessions/streams, if manual mode accidentally starts the
runtime service, if runtime-service success/failure settlements drift, or if
polling no longer uses one canonical effect plan.

Backend route contract ownership gate:

```bash
moon test internal/moonwiki --target native --filter "mooncode backend route contract*"
node scripts/validate_mooncode_backend_route_ownership.mjs
moon test internal/mooncode --target native --filter "desktop projection endpoint contract*"
```

This Phase 33 gate keeps backend-routed MoonCode desktop API paths synchronized
with the published MoonCode route contract. It fails if the router serves a
desktop endpoint that is absent from `desktop_projection_required_endpoints`, or
if the contract advertises a path the router no longer serves.

Phase 38 removes the old copied MoonWiki route list from this gate. The backend
route source validator now compares endpoint helper calls in
`api_mooncode_router.mbt` with the helper calls used by
`desktop_projection_route_contracts`, and rejects reintroduced static
`/api/mooncode` route mirrors in the backend route test.

Backend route method contract ownership gate:

```bash
moon test internal/moonwiki --target native --filter "mooncode backend route contract*"
node scripts/validate_mooncode_backend_route_ownership.mjs
moon test internal/mooncode --target native --filter "desktop projection endpoint contract*"
```

This Phase 34 gate extends the backend route contract from path ownership to
path plus method ownership. It fails if a router endpoint changes between
read-only, command-ingest, mixed GET/POST, or POST-only behavior without the
published `desktop_projection_route_contracts` surface changing with it. The
contract explicitly counts `HEAD` for read routes because the desktop router
accepts `HEAD` anywhere it accepts `GET`.

Contract-backed MoonCode method dispatch gate:

```bash
moon test internal/moonwiki --target native --filter "mooncode backend route contract*"
bash scripts/validate_mooncode_backend_method_dispatch.sh
node scripts/mooncode_http_method_contract_smoke.mjs
```

This Phase 35 gate removes raw MoonCode method policy from the router branches.
MoonCode route branches still own path segmentation, but method acceptance now
flows through the published `desktop_projection_route_contracts` surface. The
same contract drives `405 Method Not Allowed` responses, including the `Allow`
header and JSON `allowed_methods` payload field. The source validator prevents
raw `is_read_method`, `method_ is Post`, or generic 405 calls from returning to
`api_mooncode_router.mbt`.

Phase 36 extends the same gate to the host-visible HTTP boundary. Phase 37
publishes `desktop_route_contracts` through `/api/mooncode/capabilities` and
makes the smoke consume that live capability surface. It starts a fresh Moondesk
server, creates a real MoonCode session, accepts `HEAD /api/mooncode/status`,
then probes every advertised desktop route with a rejected method and verifies
the correct `Allow` header, `allowed_methods`, and shared API contract fields.
This catches response-helper, route addition, or server-boundary drift that
source-level method ownership cannot see.

## Done Criteria

Code mode is sufficiently tested when:

- a deterministic end-to-end test proves create session -> command -> runtime
  claim -> event ingest -> receipt -> readiness -> package projection
- an explicit runtime-service test proves submit acknowledgement is enqueue-only
  and native work starts through `/runtime-service`, not hidden command-response
  side effects
- a runtime-control integration smoke proves prompt, steer, and cancel stay in
  append-only command/runtime-command order and project to the expected
  `start-turn`, `queue-steer`, and `withdraw-pending` effects
- a runtime-service failure smoke proves MoonClaw startup failure becomes one
  durable command-scoped failed assistant turn instead of an endless thinking
  state or composer-only error
- a runtime-loop smoke proves terminal native service lifecycle events release
  Moondesk's runtime-service lease without waiting for a timeout
- a control-boundary smoke proves explicit steer/cancel commands stay out of the
  user/assistant transcript and settle only through runtime evidence
- a visible-progress projection gate proves arbitrary runtime events stay out of
  chat while command-scoped MoonClaw progress evidence is rendered with
  user-facing wording
- a model-planner evidence gate proves local UI state cannot pretend active
  work; MoonClaw must emit command-scoped planner evidence, assistant/failure
  evidence, or a clear runtime contract failure
- a turn ownership and abort gate proves every visible row carries its owner
  tuple and unscoped runtime diagnostics cannot move or rewrite chat turns
- a package/review model-flow gate proves package decisions are accepted,
  rejected, failed, or stale only from command-owned manifest, review, test,
  readiness, and assistant-summary evidence
- a browser conversation stability gate proves first/second/third MoonCode
  prompts append immediately in the visible UI, owner-tagged progress stays
  between the owning user and assistant, completed progress is folded, and hard
  reload preserves the transcript
- a frontend/backend ownership gate proves normal session-list responses are
  authoritative and the UI does not repair backend conversation regressions with
  cached local conversation state
- a frontend route ownership gate proves browser command handlers call the
  shared core MoonCode desktop route formatter instead of hard-coding
  `/api/mooncode` paths
- a frontend session effect ownership gate proves reducer branches invoke one
  typed plan for MoonCode runtime-service, session/stream refresh, polling, and
  shell-sync followups
- a backend route contract ownership gate proves the MoonCode server router and
  `desktop_projection_required_endpoints` describe the same desktop API surface
- a backend route method ownership gate proves the MoonCode server router and
  `desktop_projection_route_contracts` describe the same path and method
  surface, including `HEAD` support for read routes
- a contract-backed method dispatch gate proves MoonCode router branches use
  the published route contract for GET/HEAD/POST acceptance and 405
  allowed-method reporting
- an HTTP method-contract smoke proves MoonCode route method policy is visible
  through the real host API response, not only through internal router tests
- the HTTP method-contract smoke derives its coverage from
  `/api/mooncode/capabilities.desktop_route_contracts`, so every advertised
  desktop route gets host-visible method coverage
- a backend route source ownership gate proves MoonWiki tests do not maintain a
  static route mirror and the backend router references the same endpoint helper
  set as `desktop_projection_route_contracts`
- a shared frontend route formatting gate proves Rabbita no longer maintains a
  second MoonCode route formatter and consumes the public core helpers instead
- a shared desktop route formatting gate proves active Rabbita command and
  settings code consumes public core route helpers for all desktop API
  families, not raw `/api/` strings or frontend-local encoders
- a desktop API method contract gate proves generic non-MoonCode routers use
  the public core route method contract and no longer own independent
  branch-local method policy
- a desktop API capability smoke proves the running host publishes the generic
  desktop API route contract at `/api/desktop/capabilities`, derives every
  generic route method check from that payload, and keeps retired
  `/api/town/control` out of the live surface
- a portable API route contract gate proves app-tool portable consumes the core
  desktop portable API subset for offline snapshot routes, dynamic workspace
  content support, manifest/status publication, and unsupported-route warnings
- a host-visible portable API contract smoke proves `/api/desktop/capabilities`
  publishes the portable snapshot route list, dynamic workspace content
  patterns, and combined offline supported route set from the same core contract
- a desktop capability schema ownership gate proves MoonWiki serves the
  core-owned `DesktopApiCapabilities` object instead of rebuilding capability
  fields locally
- a MoonCode native endpoint ownership gate proves internal projection code
  consumes the typed `mooncode/core` native endpoint contract instead of
  carrying mirrored `/v1/code/*` literals
- a native runtime endpoint builder gate proves concrete MoonClaw
  `/v1/code` URLs and the runtime contract native-target description are
  formatted by `mooncode/core`, not by internal projection string builders
- a readiness contract ownership gate proves MoonCode readiness and the
  executable-book lifecycle use backend canonical conversation turns as chat
  proof, not raw transcript-lane event counts
- UI reducer tests prove the user can enter MoonCode, start a session, send
  first/second/third ordinary prompts, use explicit steering controls, and reload
  stream/runtime state
- host API tests cover every `/api/mooncode` route with at least one success or
  explicit method/validation test
- negative tests prove path traversal and malformed runtime records cannot
  create durable side effects
- integration tests prove MoonCode/MoonClaw/Moontown records use the MoonLib
  MoonSuite contract paths and do not recreate legacy `.moontown` or
  `.moonclaw` roots
- contract-consumer tests prove the code-mode fixture, MoonCode session
  sidecars, MoonClaw runtime records, and Moontown handoff records derive
  canonical paths from MoonLib rather than local layout constants
- contract-boundary tests prove MoonCode can consume MoonLib path contracts
  without importing MoonStat or status/analytics packages
- resume tests prove sessions survive process restart from disk records
- live model/runtime tests exist as manual or scheduled checks, but deterministic
  tests remain the merge gate
- `.mbti` diffs from `moon info` are reviewed whenever public contracts change
