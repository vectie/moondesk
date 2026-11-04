# MoonDesk handoff notes

Read this with `AGENTS.md` before starting work. Record concrete pitfalls and
their resolution here; keep task-specific evidence in `docs/`.

Work directly on `main`; do not create a branch unless the user requests one.

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
unchanged. Graph presentation remains planned; do not turn this design record
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
