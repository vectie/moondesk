# MoonDesk handoff notes

Read this with `AGENTS.md` before starting work. Record concrete pitfalls and
their resolution here; keep task-specific evidence in `docs/`.

Work directly on `main`; do not create a branch unless the user requests one.

## Live MoonCode bug delivery 2026-11-06

- Ran the actual main-checkout MoonClaw daemon with a real Codex OAuth model,
  plain /turns prompt and no injected tool calls. MoonCode fixed display_name
  for repeated trailing slashes; coordinator provided the two failing
  acceptance assertions first and did not revise the model's patch afterward.
- Canonical usage: 16 responses, input 562434 (cached 269312), output 2354;
  37 tool results, 12 successful/25 failed. Command-to-finish 124.712 seconds,
  independent core acceptance about 141 seconds. Cash cost unknown, not zero;
  these counts exclude this chat's coordination model use.
- Delivery passed independent checks, but autonomous verification did not:
  no MoonFort process route was configured. The model disclosed the refusals;
  coordinator ran tests. Do not count this as no-takeover success or tick the
  general quality/cost baseline. Report: docs/MOONCODE_LIVE_BUGFIX_2026-11-06.md.
- Actual trace exposed three Claw bugs, fixed by the coordinator: neutral edit
  placeholders rejected valid calls, work-step failure marked an active turn
  failed, and read_skill rendered as a write. No feature, gate or authority
  changes. Real journal-prefix/edit-argument replay passed; temporary replay
  test removed, minimal permanent regressions retained.
- Final Claw native 1845/1845, Desk native 1726/1726; core native/JS each 24/24;
  JS workspace 2291/2291 includes UI 839, not an additional count. Info/fmt,
  interfaces and whitespace checked; .mbti unchanged. No browser/install or
  post-fix live-model rerun, so no token/latency improvement claim.
- Tooling pitfall: standalone .mbtx imports resolved app dependencies outside
  the local moon.work overrides and hit the old moonzip manifest. Use the
  ordinary project test for this baseline; do not change dependencies to make
  an evaluation pass. This preparation issue is not a MoonCode tool failure.
- Timing uses numeric journal recorded_at values; canonical started_at and
  updated_at were empty in this run. Do not derive live latency from those
  optional display fields or conflate finish, settlement and service idle time.

## Runtime ownership and control/projection simplification 2026-11-06

- Recorded the bounded meaning of ideal module boundaries: one owner per fact,
  traceable consumers and no duplicated behavior. JSON at dynamic ABI/provider/
  journal boundaries is not a reason to add an IR or extra validation.
- Claw groups its four live execution fields separately from session metadata;
  preserves the pre-task startup reservation and uses the existing execution
  lease instead of the second running branch. External metadata stays the same.
- Controls apply claimed steering once; follow-up request assembly uses one
  loop. Planner ledger reads canonical results without a temporary JSON
  protocol. Existing response projections moved to the receipt owner.
- Retired one duplicate synthetic single-flight case and retained its assertions
  in the existing wake fixture. Real lease/restart/cancel/steering tests remain.
- No added validator, runtime state, approval, retry limit, package or desktop
  execution responsibility. No UI/install or end-to-end quality claim.
- Validation: final Claw native 1844/1844, Desk native 1726/1726 and real
  capability probe passed; initial focused tests were 53/53 before merging the
  duplicate case. Info/fmt,
  whitespace and .mbti checked. Production -61/test -63 lines, net -124,
  including embedded .mbt test blocks; moved projection bytes unchanged.
- Counting pitfall: .mbt filenames do not distinguish all tests. The retired
  service test was embedded in a normal source file; do not report its removal
  as a production-code saving or count file moves as deleted implementation.

## Boundary closure: tool resume and planner pauses 2026-11-06

- Recorded the eight-responsibility assessment in the design checklist:
  functional ownership is clearer than type/package isolation. Continue with
  actual boundary leaks and duplication; do not introduce eight packages,
  a full IR, new scheduler or confirmation workflow.
- Claw continuation owns decoded tool position/quantum end/in-call distinction
  and optional validated approval. Turn consumes these directly. A newer
  execution checkpoint must not resurrect a superseded approval wait; the
  existing service fixture now covers that recovery pitfall.
- Resumed and in-quantum planner pauses share one production chooser and
  checkpoint serialization. Removed two separate constructors and mutable
  duplicate pause state; existing fixtures exercise the real production path.
- Memory/filesystem/lock scope and command/plan/result Json limits remain.
  No desktop execution/recovery state or wire contract changes were added.
- Validation: Claw native 1845/1845, Desk native 1726/1726, focused
  recovery/approval 28/28 and producer/consumer probe passed. Check/info/fmt,
  interfaces and whitespace checked; .mbti unchanged. Production .mbt -85,
  tests +44, net -41; no new test cases, UI/install or live-provider claim.

## Eight-module re-audit: session metadata and execution evidence 2026-11-05

- Claw now restores first-prompt/title metadata and command count through the
  same existing snapshot/journal-pair entry. Intake no longer performs a
  separate first-prompt restore. The current task/revision remains distinct.
- Preserve cache/snapshot priority and owner validation. The removed duplicate
  reads affect cold/missing-prompt recovery; warm bindings already avoided
  them. No new cache/store, client projection or public API is introduced.
- Removed five test-only Claw production wrappers; real model round, provider
  retry/transport, sandbox config and receipt exit handling stay authoritative.
  One predicate test was retired; existing recovery and actual MoonBit command
  fixtures were extended. Negative exits are read from the real receipt rather
  than assumed to be 1. The fixture reports Degraded isolation, not production
  MoonFort enforcement. Retry test names now match the evidence they observe.
- Validation: Claw native 1845/1845, Desk native 1726/1726, core JS 64/64,
  UI 839/839; metadata/model-workspace 20/20, process/listing 28/28 and
  producer/consumer probe passed. Info/fmt and whitespace checked; .mbti
  unchanged. Production .mbt -66, tests +15, net -51. No new state machine,
  runner, model request or confirmation; no UI/install, live-provider or
  end-to-end performance qualification. See the current eight-module checklist.

## Eight-module re-audit: stream reads and typed readiness 2026-11-05

- Capability negotiation and readiness reuse one typed decode and the existing
  decision. Boolean readiness no longer builds/parses a status JSON object.
  Public response shapes and acceptance/error rules are unchanged.
- Claw raw diagnostics share one locked scanner for wait summaries and local
  spool output; zero-wait replay skips the discarded summary pass. Network
  delivery stays outside session/journal locks. Canonical watch remains the UI
  source; no desktop replay, index/store or new execution state was added.
- Removed test-only array replay/encoders and their positional cursor fallback.
  Existing production spool/HTTP tests cover physical positions, payload cursor
  shadowing, JSONL/SSE bytes, reconnect and rejection before 200. Six old-path
  tests and a duplicate daemon fixture were retired; no alternate producer oracle.
- Same-scanner local composition measurement: 1000 events, 10 iterations,
  three warmed batches 596/575/574 ms -> 386/386/388 ms. Includes spool/cleanup,
  excludes HTTP, model, compile/fixture and cold disk; no end-to-end speed claim.
  Temporary measurement code removed.
- Validation: Claw native 1846/1846, Desk native 1726/1726, core JS 64/64,
  UI 839/839; focused stream 8/8 and capability/routes 32/32, producer/consumer
  probe passed. Info/fmt and whitespace checked; .mbti unchanged. Production
  .mbt net -232, tests -293, total -525. No UI layout/package install or
  live-provider/full-task performance qualification. The eight-module checklist
  retains actual context, file, ownership, recovery and dependency limits.
- Tooling pitfall: refresh `moon ide` with its normal check after edits;
  `--no-check` can report stale/empty references from earlier source positions.

## Eight-module re-audit: catalog and execution ownership 2026-11-05

- Removed the duplicated core command/tool execution descriptions in both
  repos. Capabilities retain names/aliases/protocol ownership; actual schemas,
  argument checks, grants, tool policy and finish remain runtime-owned.
- Native packet assembly now serializes validated submissions directly,
  removing a full capability-tree allocation per submit and inferred packet
  control/approval fields. Real approval actions/IDs still pass through.
- commands is now an action-name array; tool_specs, old input-field catalogs
  and approval/review/completion labels are removed. No compatibility shim.
  Removed Desk's deprecated wrappers and three test-only bridge exports;
  Claw core drops 28 unused exports. Check .mbti removals, not just compilation.
- Old untagged cancellation matching and its fixture are gone; current tagged
  receipt replay, pinned targets and automatic startup recovery remain.
  The active-cancel predicate moved beside its producer without new logic.
- Retired five obsolete tests across both repos. One MoonWiki review test
  silently passed on an empty tools array; it did not prove runtime behavior.
  Actual schema/grant/file/finish/cancel/restart and UI regressions remain.
- Eight contracts were reviewed without forcing new abstractions: retain the
  context compiler, distinct lock lifetimes, native CAS and journal projection.
  Large scans, external writers and partial dependency provenance retain their
  limits. No new store, runner, state machine, model request or confirmation.
- Validation: Claw native 1852/1852, Desk native 1726/1726, core JS 64/64,
  UI 839/839, final cancel/recovery 14/14 and producer/consumer probe passed.
  Info/fmt and .mbti removals reviewed. Production .mbt net -2585, tests -379,
  total -2964; predicate relocation is not counted as deletion. No UI layout /
  package install or live-provider/end-to-end performance qualification.

## Process / Thread and restart recovery 2026-11-05

- MoonClaw daemon startup now discovers unfinished sessions from configured
  trusted Books and resumes the ordinary service without desktop resubmission.
  The desktop does not own a recovery queue, scheduler or new confirmation.
- Only pending candidates restore bindings. Existing journal claims,
  continuations, results and execution leases remain the execution authority.
  A queued command can precede a service finish; ordinary drain gaps resume.
- Explicit active-cancel events distinguish user stops from process shutdown;
  a cancelled coroutine alone does not carry that intent. Existing pending
  withdrawal and lifecycle boundaries remain distinct.
- Unresolved approvals wait; durable decisions can resume. Finished explicit
  manual limits stay stopped. Interrupted services retain their ID and options;
  max_turns remains per invocation, without a new cross-restart quota mechanism.
- Temporary local scan: 100 completed small sessions plus one empty fixture,
  23/25 ms, no retained bindings. No model/compile/cold-disk or large-log claim.
  Measurement code removed. See the design checklist for the full contract.

- Validation: Claw native 1854/1854, Desk core JS 65/65 and real producer /
  consumer probe passed. Info/fmt and whitespace checked; .mbti unchanged.
  65 local links and 11 unchanged archive hashes checked. Production .mbt
  net +163 and tests +287 for the missing startup path; no deletion claim.
  The existing quantum test now exercises new Daemon serve instances and
  cancellation/restart. No UI/install change, live-provider, SIGKILL /
  power-loss or production performance qualification.

## Data Model / Compute Engine convergence 2026-11-05

- Completed operation events own their execution header and tool_result.
  Checkpoints use event_id/event_digest or inline_execution for synthetic
  results, with no copied header or journaled_result flag. Event display
  names must not decide storage shape; patch/finish results can be refs.
  Operation recovery and hydration share mooncode_tool_execution_from_event.
- Initial/current/follow-up selection matches the existing ResumePoint.
  Quantum, transport and replan follow-ups share one assembly; retain
  steering, guidance and finish_rejected semantics. No new state machine.
- Receipt consumers use canonical nested result. Old flat worker fallback
  and flat-only conversation assumption are removed; fixtures now match
  the real producer. No legacy reader or output approval stage was added.
- Removed dead patch-verification metadata classification and its empty
  test. Ordinary patch completion has no new mandatory check or action.
- Temporary measurement: 100 write results with 33020-char source arguments,
  history serialization 3561392 -> 12692 ASCII chars. Original result events
  and current transcript are excluded; no model tokens/latency claim.
  Digest calculation and reference traversal still have their existing cost.

- Validation: Claw native 1852/1852; data/receipt/worker 75/75; model resume
  and steering 50/50 before retiring the old test; reference roundtrips 4/4;
  Desk core JS 65/65, UI 839/839; real producer/consumer probe passed.
  Info/fmt and whitespace checked; .mbti unchanged. Production net -68 lines,
  tests net +21, total -47. One obsolete test removed; existing tests extended.
  63 local links and 11 unchanged archive hashes checked. No app install,
  live-provider or end-to-end performance qualification.



## Eight primitive contracts audit 2026-11-05

- Current responsibilities are process/thread, memory, filesystem, I/O,
  synchronization, fault tolerance, data model and compute engine. See
  the runtime boundary and MoonDesk design synthesis for per-interface
  inputs/outputs, logic, actual guarantees and sibling comparisons.
- Retired unused `PruneResult`, `calculate_pruning` and `prune_messages`,
  four direct package dependencies and eleven legacy-only tests. Context
  has one real compiler; don't restore a second in-place pruning API.
- External execution entry points acquire session gates; internal
  `*_under_runtime_gates` borrow them. The loop no longer accepts a Boolean
  deciding whether to reacquire ownership. Lifecycle, execution, journal
  and native file locks protect different resources and remain distinct.
- Parallel scheduling reads the existing policy, not a second tool-name
  allowlist. Resource reads retain canonical identity. Declared read-only
  result recall and MCP listing now qualify for ordinary batches.
- Work-step identity follows operation_id on the runtime path. Provider
  call IDs can repeat upstream; they are not cross-round execution keys.
  Existing tests cover reuse, ordered parallel recall and no effect replay.
  Work steps use item_id/command_id/event_id; removed duplicate aliases
  step_id/turn_id/evidence_ref. Top-level turn/message IDs remain.
- Uncertain-operation recovery uses the common execution constructor.
  No extra state machine, agent, store, model call or human step was added.
- Remaining limits: cooperative native file locks; process tools/external
  writers do not participate. The boot discovery gap recorded at this audit
  is closed by the Process / Thread update above. Internal Json and
  partial dependency provenance do not constitute a typed IR or full DAG.

- Validation: Claw native 1853/1853; identity/session 21/21; initial focused
  checks 43/43; Desk core JS 65/65 and UI 839/839; real producer/consumer
  probe passed. Info/fmt and interface diff reviewed. Production .mbt net
  -157, tests net -282. No UI layout/build or installed-app change; no live
  provider/performance qualification. Archive hashes remain unchanged.



## Programmable single-agent path 2026-11-05

- Initial/follow-up share one model round. Ordinary tools and checkpoint share
  result assembly; consumers use the canonical result boundary.
- Completed operation IDs identify results; tool-call IDs join start/result.
  Same-millisecond parallel reads must never collapse or match by tool name.
- `read_result` reads only retained session results, including patch events.
  Compaction preserves exact or first/last references through repeated passes.
  It does not rerun effects or reconstruct output already truncated at execution.
- Work graph is a disposable canonical projection and uses existing UI cards
  and file navigation. It is not a scheduler, completion rule or new store.
- Known local chunks use existing shell/project scripts; tiny native edits are
  faster locally. Measurement: six read/write calls 4 ms; fixture-bridge .mbtx first
  512 ms / warm 204 ms (script also checked outputs; no model time/tokens; Degraded fixture,
  not a production MoonFort performance measurement).
  Do not claim end-to-end speedup or live deliverable-quality improvement.
- Validation: Claw native 1864/1864 + final projection focus 30/30; Desk
  native 1729/1729; core JS 65/65 + graph codec 3/3; UI 839/839; Node 24/24.
  Real producer/consumer probe, info/fmt and production UI build passed.
  Build 53.57 s; main chunk +4049 bytes vs baseline. Source production net
  +482/test +341; shared round/result consolidation alone net -61 production.
  Existing warnings remain; live-provider and installed-app qualification
  are not included. The historical archive remains unchanged.



## Projection/Telemetry cleanup 2026-11-05

- Canonical watch moved to MoonClaw's existing session/journal projection.
  MoonDesk resolves the Book and adapts session metadata, preserving exact
  revision strings and runtime status. Do not restore raw-event downloads,
  event-count cursors or a desktop completion/replay reducer.
- Removed unused typed resume, replay/cursor trial code, synchronous metrics
  exporter and export-only SDK method. Planner observations reuse existing
  final events; canonical usage no longer depends on compacted historical plans
  or repeated receipts. Distinct responses reuse the daemon UUID source because
  timestamps can repeat. Missing usage/prices remain unmeasured/unpriced.
- Snapshot rebuild still reads full history; metadata polling and a temporary
  command index reduce repeated work without another projection cache. Dedicated
  graph UI is delivered in the later five-step plan; complete dependency edges
  and live outcome/cost baselines remain unchecked in the synthesis. No new state machine, store or human gate.
- Validation: Claw native 1862/1862; Desk native 1729/1729; core JS 65/65;
  UI watch/usage 108/108; real producer/consumer probe passed. Info/fmt and
  interface review passed. Code/tests net -2046 lines (-1307 production,
  -739 tests). 42 local links and 11 unchanged archive hashes checked.
- Runtime and desktop both advertise the watch endpoint; update them together.
  Existing warning debt and lack of installed-app/live-provider qualification
  remain. The SDK stream cursor/export methods were intentionally removed.

## Context/Journal cleanup 2026-11-05

- MoonClaw uses the existing context compiler by default for initial and
  follow-up planning. Fixed suffixes, shadow/active flags and overload transcript
  rewrites are removed; tool result JSON is no longer clipped again by planner.
- One recovery-position decoder reuses the existing loop and operation results.
  The append cache retains directory-sync success, invalidated before lifecycle
  moves; ordinary cached appends sync file bytes. No new state machine, store,
  model round or human confirmation was added.
- Checklist sections 3 and 6 record implementation and limits. Model-facing
  history lookup was unchecked at that step; read_result shipped later. The desktop continues to
  consume canonical conversation facts without a local replay path.
- MoonClaw native 1873/1873 and the real producer/consumer probe passed;
  public interfaces are unchanged. Code/tests together net -1611 lines, with
  95 test-helper lines moved rather than counted as deletion. The historical
  archive's 11 hashes are unchanged. No UI or packaged-app change was needed.

## MoonCode design discussion

MoonCode design discussion is archived in
`docs/mooncode-discussion-2026-11-04/README.md`, including all four projects'
16-question answers and the full conversation. Use `CURRENT_PLAN.md` there as
the implementation baseline: automation first, one primary agent, deletion of
duplicate mechanisms, and no compatibility requirement. Earlier proposals for
a new runtime framework and universal acceptance gates were superseded; do not
combine all historical plans into implementation requirements. Active references
are `docs/MOONCODE.md` and `docs/CODE_MODE_TEST_PLAN.md`; the old MoonCode phase
plans and execution diary were removed. Do not restore document-phrase closure
checks or treat dated test reports as current readiness.

The 2026-11-05 synthesis is
`docs/MOONCODE_AGENT_MACHINE_AND_DYNAMIC_GRAPH.md`: execution primitives,
OS/compiler/database/dataflow mappings, framework comparison, executable
top-down work and task-driven dynamic graphs. Keep the November 4 archive
unchanged. Minimal graph presentation has shipped; do not turn this design record
into another completion gate, graph database or user-authored wiring workflow.

## Current single-agent implementation

- Goal APIs, separate quality/no-change policy and desktop
  package-review/proof-gate inference were removed; ordinary completion uses
  `finish` and the existing canonical runtime projection.
- The task-controls surface keeps the editable working plan, removes the Goal
  form and hides an empty agent team. Do not recreate a desktop task state
  machine. A DOM interaction test verifies plan saving without a Goal form.
- The full discussion archive is historical and unchanged. Active runtime
  behavior is documented in MoonClaw's executable-book boundary.
- Capabilities and listings no longer require or project the nine-step
  executable-book lifecycle report. The canonical conversation and actual
  runtime owner/session/watch contracts remain authoritative. Update producer
  and consumer together; no old-protocol compatibility is required.
- `integration/mooncode_contract_probe` runs the real MoonClaw producer against
  the MoonDesk decoder using explicit local workspace dependencies. Keep this
  behavioral check instead of document phrases or duplicated readiness rules.
- MoonClaw now uses one native catalog for initial and follow-up requests.
  Keyword bundles, native tool search/loading and their trial tests were
  removed. Read-only subsets, explicit selection and MCP remain; no extra
  framework or approval step was added.
- Empty follow-ups resume through existing claims and results without a
  milestone prerequisite. Progress notes neither permit retries nor grant
  completion. MoonClaw preserves rejected-finish state across repeated empty
  responses; MoonDesk continues to display its canonical runtime facts.
- The runtime now documents its process/thread, memory, filesystem, IO,
  synchronization and fault-tolerance mapping. One shared model instruction
  applies top-down decomposition until executable, then implementation and
  verification. This adds no desktop phase, state machine or plan approval.

## Tool boundary cleanup 2026-11-05

- The synthesis's current plan is organized by Task, Execution, Context,
  Workspace, Tools, Journal, Completion, Projection and Telemetry. It replaces
  the rejected generic phases 0–5 with concrete responsibility/removal targets.
  Task/Completion/Execution are implemented; Tools/Workspace now have a
  first cleanup pass, with unchecked resource-identity/ABI/isolation work still
  pending. The older ten-item checklist covers the earlier tool cleanup.
  Keep real authority/data contracts while removing redundant policy.
- The design synthesis now contains a completed ten-item cleanup checklist
  and evidence. MoonClaw owns pure tool semantics in `internal/mooncode_tools`;
  MoonDesk continues to project canonical runtime facts, with no new UI phase.
- Guardian shadow qualification and the command-wide post-commit seal were
  removed. The same authorized command can commit, repair, verify and finish;
  changed verification inputs still prevent stale completion.
- MoonClaw native 1917/1917 and pure module 17/17 passed; two sandbox/runtime
  commit tests and the real cross-repo capability probe passed. Existing
  interfaces are unchanged. Production MoonBit net -623 lines; tests net -498.
- All 32 local design links resolve; November 4 archive hashes remain unchanged.
  No desktop runtime/UI code changed, installed-app update or live-model
  quality qualification was performed. Existing release warning debt remains.

## Task Completion Execution cleanup 2026-11-05

- The design checklist now marks Task, Completion and Execution complete;
  Context/Workspace/Tools/Journal/Projection/Telemetry remain pending.
- MoonClaw removed keyword-driven catalog/completion rules, the project-specific
  dynamic skill gate, forced recovery reads and read/retry rejection policies.
  Full requests and ordered task updates are preserved, and completion facts
  are owned by the existing completion file. Required checks, fingerprints,
  authorization, cancellation and journal recovery remain in place.
- MoonClaw native 1899/1899, related recovery/control 118/118 and final focused
  checks 20/20 passed. The real producer/consumer probe passed; interfaces are
  unchanged. Production `.mbt` net -1122 lines; tests net -1069.
- Documentation links and the unchanged November 4 archive were checked.
  MoonDesk runtime/UI was not changed. Existing warning debt and the lack of
  live-model/installed-app qualification remain; do not claim those passed.

## Tools Workspace cleanup 2026-11-05

- Removed command-word approval inference and planner-based exemptions.
  Explicit approval annotations always remain effective; normal execution
  binds the exact configured MoonFort capability without an extra human step.
- Removed global shell-authoring prohibitions and file-tool MoonBit manifest
  grammar checks. Project instructions and real compiler checks remain.
  Shell now has one execution entry and one shared preflight implementation.
- The pure policy exposes only parallel-read, after-skill and replay facts.
  Removed obsolete sensitive/install/overwrite/inline-authoring parsing and
  associated tests; retained actual read-only scheduling and check semantics.
- Unified single/multi-file diffs use one executor with file/hunk identity,
  fingerprints, prevalidation and existing rollback. Scope is parsed once;
  absolute in-book paths compare like relative paths. Whole-workspace scope
  skips the Git snapshot; narrow scope snapshot failure precedes execution.
- Authoring shells invalidate prior checks through the existing boundary.
  Receipt changed paths join tracked check inputs; the collector returns
  paths directly instead of constructing artificial before/after states.
- Do not mark the entire Workspace/Tools plan done. General ABI/schema
  convergence, canonical symlink identity, narrow/formatter snapshot cost
  and external/concurrent-write isolation remain unchecked. Current grants
  have no per-task writable-path field; snapshots are not transactions.

- Validation: final native 1892/1892; final completion/formatter/repair checks
  17/17; real MoonClaw producer → MoonDesk decoder probe passed. `moon info`
  and `moon fmt` passed; the only interface diff removes obsolete internal
  tool properties/functions. Six existing daemon warnings remain. Production
  `.mbt` net -568 lines; tests net -447. No new package/state machine, human
  approval step or model request. No desktop runtime/UI change or installed
  app/live-provider qualification. Full-workspace scope removes entire Git
  snapshots, but narrow scopes retain their existing O(worktree) cost.

## Tools ABI and Workspace identity follow-up 2026-11-05

- The cached runtime catalog now owns schemas and supported-name lookup.
  One validator covers model decoding, pre-approval calls and execution.
  Removed legacy request aliases and hidden patch verification execution;
  actual grants and result/event/provider contracts remain distinct.
- Both repositories removed the unused native command policy tables,
  tool sequences and result checklists. Capability fingerprints changed
  together; keep the real producer/consumer probe, not those phrase tests.
- Physical workspace paths now join scope, aliases, parallel-read identity,
  verification and command selectors. Check receipts bind actual paths;
  retargeting an alias to equal bytes still invalidates the earlier check.
- Native writes reuse OS locks, pinned Book resource comparisons and atomic
  sibling rename. Stable per-resource lock paths survive inode replacement;
  other files proceed. Optional expected_fingerprint supports stale writes.
  Rollback only compares/restores successfully committed patch members.
- Pitfalls: /var and /private/var aliases must agree in shell boundaries and
  argv; pre-approval schema checks prevent malformed calls waiting on humans.
  A scope snapshot lists dirty tracked files, not every tracked file: a clean
  missing baseline needs read-only HEAD content, not deletion or blind restore.
  Runtime lock metadata belongs to .moonsuite, excluded like product state.
- Limits: CAS retains the reused 16 MiB text-reader bound and preserves rwx,
  not inode/owner/xattrs or cross-file/power-loss transactions. Process tools
  do not participate in native file locks; non-cooperative writes and hostile
  parent replacement remain stronger-isolation work. No new package, state
  machine, model round, global workspace mutex or human confirmation.

- Validation: MoonClaw native 1890/1890; MoonDesk native 1733/1733;
  protocol-core JS 66/66; focused runtime/core 16/16 and boundaries 23/23;
  real producer → decoder probe passed. Info/fmt passed, with the existing
  six daemon warnings. 40 local links and 11 archive hashes checked.
- Production MoonBit net -1695 across both repos (-901 Claw, -794 Desk).
  Tests net +66 after replacing retired policy assertions with four actual
  boundary regressions. Moving the catalog is not counted as deletion.
  Interfaces remove 25 unused policy APIs, add the shared validator and
  Stat.mode, and replace unchecked Git restore with read-only HEAD lookup.
  No installed-app or live-provider qualification was performed.

## Validation 2026-11-04

- Last MoonDesk code validation (`5f6174bc`): native 1734/1734, UI 2293/2293,
  JavaScript 514 with one skipped. Later rounds change MoonDesk docs only.
- MoonClaw's shared-program cleanup passed its full native suite 1927/1927,
  including generic and Kimi-identified local transport/restart fixtures.
  Public interfaces are unchanged; the real producer/consumer probe passed again.
- The strict release gate still stops at existing warnings: unused Flow
  sandbox declarations, an unused UI pack helper, and four unnecessary
  annotations in external MoonLeaf. No installed-app update or live-model
  quality qualification was performed.
- Native Flow crossing requires its separately configured fixture; ordinary
  suite success does not establish that external integration.

## UI preview and packaged application

- The installed Lepusa app serves its frontend and API on port 4201. A separate
  development backend may be running on 4199. Inspect the actual app URL rather
  than assuming that a browser preview uses the installed backend.
- For UI iteration, run the existing Vite development command with
  `MOONDESK_API_ORIGIN=http://127.0.0.1:4201`. The default proxy target is 4321.
  Inspect the development preview before doing the production frontend build.
- UI-only edits need a frontend build, resource installation and app signature
  verification. They do not require relinking the native executables. Native
  backend changes require the corresponding native build and packaging path.
- Canonical Desk section aliases may be localized; authored names and real
  paths must remain content. `app` and `apps` are separate section identities
  and must remain distinguishable in Chinese.
- File selection accepts workspace drops on the whole dialog. Preserve this
  interaction when removing the old instructional dropzone. Keep loading,
  empty results and failures distinct.
- Attached editors that replace their form DOM must set
  `data-popup-focus-dismiss="false"`. Native WebKit can briefly restore focus
  to the main workspace during reconciliation; treating that as an outside
  dismissal closes the editor immediately. Outside pointer/Escape dismissal
  remains handled by `quiet-controls-runtime.js`.

Latest inspection: `docs/UI_UX_AUDIT_2026-11-04.md`.

Secondary-surface continuation: `docs/UI_SECONDARY_AUDIT_2026-11-04.md`.

- Legacy activity selections can close the command palette without opening a
  modern focus-view tool. Route settings/search to their actual local tool
  messages and verify the destination, not only palette dismissal.
- Drawer redraws must preserve unsaved preference/learning drafts per book.
  Input availability updates should not rebuild the form or lose focus.
- Icon-only utilities need localized accessible labels. DOM tests should find
  them through those labels rather than visible text.
- Native WebKit can render selects shorter than the shared minimum height.
  Single-select controls in secondary surfaces use explicit height/appearance
  and the shared chevron; verify them in the native app, not only Chromium.

State/narrow-window continuation: `docs/UI_STATES_AUDIT_2026-11-04.md`.

- Book's Markdown/image/source viewer must consume `preview_state`, not infer
  loading from `preview == None`. A failed request can legitimately have no
  preview; show its failure and retry the selected path locally.
- Markdown uses the generic preview path, while
  `wiki_document_path_supported` identifies Office/PDF/artifact handling.
  Do not reuse that predicate to decide whether a normal Markdown file exists.
- Loaded setup drafts must not retain an in-flight `loading` flag after their
  old DOM is detached. Refresh success must clear stale errors even when data
  has not changed; apply the same rule to room polling.
- Shell `data-state` updates also occur while Code is polling. Recreating
  calendar/room runtime roots on each update resets scroll, focus and pending
  requests. Retain the local view for the current book/document, and restore
  its position when the shell reattaches it.

Code/Flow continuation: `docs/UI_CODE_FLOW_AUDIT_2026-11-04.md`.

- Translate changing typed status text before rendering it. Automatic
  localization can replace a text node retained by the virtual DOM; the next
  state can otherwise leave a stale translated loading message on screen.
- A non-Git MoonBook needs an explicit Changes state with refresh. An unloaded
  source editor must not claim Saved or clean diagnostics.
- Code's working-panel controls use stable button roles and pressed/expanded
  state, and explicitly restore their enabled state. Opening a local panel
  never requires a selected file, chat or PTY. Preserve direct click handlers
  and keyboard switching when changing the runtime-managed controls.
- Flow composition retrieval failure is independent of an empty runs listing.
  Keep the previous composition on failure and offer Retry locally.
- A Flow listing refresh should retain a verified result viewer when its exact
  artifact identity is unchanged. Reset its review context and invalidate the
  viewer when the refreshed identity changes.
