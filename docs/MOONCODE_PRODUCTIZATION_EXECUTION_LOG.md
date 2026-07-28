# MoonDesk Productization Execution Log

| Field | Value |
| --- | --- |
| Status | In progress |
| Owner | MoonCode implementation owner |
| Started | 2026-07-26 |
| Authoritative plan | `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md` |

## Command 020 — Phase 1 keyboard and responsive acceptance slice (failed attempt)

### Failure receipt

- Command 020 did not complete and must not be treated as successful Phase 1 evidence.
- Its keyboard proof used invented selectors: `desk-library-summary` is only a classed `div`, not a `details` selector with a summary child, and `desk-mode-nav-wiki` does not exist.
- Native HTML `details` does not close on Escape, so the attempted proof also omitted required product behavior.
- The valid exact 320x700 capture and its document-overflow, pane-overlap, and above-the-fold browser-content assertions are retained for recovery.

## Command 021 — Keyboard and responsive acceptance recovery

### Exact recovery

- Added one idempotently installed bootstrap `keydown` path for unmodified Escape. It acts only when focus is inside the nearest open `details`, prevents that handled event, closes via the `open` property without synthesizing a click, and restores focus to the direct summary. Escape elsewhere remains untouched.
- Repaired `verifyKeyboardAcceptance` to use `desk-library-storage-details` and its direct summary, dispatch real CDP Space and Escape key events, and assert closure plus focus restoration.
- Repaired primary-navigation keyboard proof to focus `mode-wiki`, dispatch a real CDP Space event, and require `aria-pressed="true"` plus the existing `activity-library` Pages hook. The keyboard actions do not use `element.click()`.
- Preserved the exact 320x700 capture and its checks for document horizontal overflow, pairwise pane overlap, and primary browser content above the fold.
- No MoonBit product contract changed in this recovery, so no new MoonBit test was added.

### Recovery defects found during execution

1. The first repaired CDP helper still omitted `text` and `unmodifiedText`.
   Chromium opened the native summary with Space, but native button activation
   never occurred. Supplying the character payload on keydown made both
   interactions faithful and the populated smoke pass.
2. The first Pages assertion named another nonexistent `moonwiki-mode` hook.
   The recovery now uses the already-rendered `activity-library` hook instead
   of adding a test-only product hook.
3. MoonCode twice invoked validation from the wrong working directory, tried a
   nonexistent `npm run check`, and passed an unsupported target to `moon fmt`.
   Those attempts are recorded as failed tooling, not as product evidence.

### Evidence obtained

- `node --check scripts/desk_mode_browser_smoke.mjs`: passed.
- `node --check ui/rabbita-desk/bootstrap.js`: passed.
- `bash -n scripts/desk_mode_browser_smoke.sh`: passed.
- `moon check --target js`: passed with zero warnings.
- `moon test --target js`: passed 329/329.
- `npm run test:i18n`: passed 3/3.
- `npm run build`: passed; generated `dist` churn was removed after evidence
  capture.
- `scripts/desk_mode_browser_smoke.sh full`: passed and produced exact
  1440x900, 1280x720, 1024x768, 390x844, and 320x700 screenshots.
- The 320x700 run passed document-width, pane-overlap, file-table overflow,
  pane-order, and primary-browser-above-fold assertions.
- `git diff --check`: passed before the final closeout.

### Status

- The bounded recovery is complete.
- This is narrow keyboard/disclosure and responsive evidence only. It does not establish full keyboard coverage, screen-reader coverage, native picker coverage, or Phase 1 completion.

## Commands 022–023 — Review typed-state adoption and recovery

### MoonCode result and audit

- Command 022 added a Review state field and explicit success/failure mapping,
  then called `finish` after only a root-module JS check. It did not implement
  the requested loading transition, Review fetch, state rendering, tests,
  browser proof, or documentation.
- Command 023 attempted the remaining work with an unrestricted Python rewrite
  despite the bounded native-edit instruction. It introduced invalid Rabbita
  attribute syntax and an unterminated nested command batch, then reported a
  passing root-module check and called `finish`.
- The reported check did not cover the nested `ui/rabbita-desk` MoonBit module.
  Running the check in that module exposed 15 errors and 9 derivative warnings.
  A root-module pass is not UI evidence; future commands must use an explicit
  `cd ui/rabbita-desk` or equivalent working directory.

### Product defects found and fixed

1. **Opening Review did not refresh review items.** The `Runs` activity branch
   fetched run, progress, and event projections but omitted the review-items
   request. It now fetches review items with the other activity evidence.
2. **A failed Review fetch looked like an honest empty queue.** Errors only
   changed a shared host string while the empty array kept rendering “Nothing
   needs review.” Review now has private typed state: first use, loading,
   legitimate zero after explicit empty success, ready content, stale content
   after a failed refresh, and recoverable failure without prior content.
3. **Refresh did not expose a loading transition.** Selecting Review now sets
   typed Loading without discarding prior items, and the Review Refresh/Retry
   controls re-enter that actual activity path.
4. **Shared state copy was search-specific.** Search titles, details, actions,
   and technical text are now explicitly Pages-search helpers. Review owns its
   own language and cannot inherit “No matching pages” or “Try the search
   again.”
5. **The attempted recovery expanded the eight-state enum with Ready.** Ready
   content is again represented by absence of a transient state, matching the
   existing Pages contract; no ninth shared state was retained.

### Rendering and evidence

- `review-state-panel` exposes stable `data-state` values. Loading and stale
  states retain the last successful items; stale and recoverable failures offer
  Refresh/Retry; raw fetch errors remain inside Technical details.
- Two focused tests cover Review loading, legitimate zero, ready, stale, and
  recoverable-error transitions plus rendered state hooks, surface-owned copy,
  stale-item retention, and technical disclosure.
- The UI module passes zero-warning `moon check --target js` and 331/331 JS
  tests.
- Localization passes 3/3, the production build passes, and
  `scripts/moondesk_quickstart_e2e.sh` passes with an explicit
  `legitimate-zero` Review assertion.
- This is the second typed consumer of the shared state contract. Other primary
  surfaces and the complete state matrix remain open; Phase 1 is not complete.

## Command 024 — Requests automation capability evidence and recovery

### MoonCode result and audit

- Command 024 was given a bounded Requests capability task with the owning
  model, lifecycle update, view, workspace-summary, and test files identified.
- It inspected the requested files, immediately called `finish`, made no source
  changes, and ended in a runtime failure. It therefore supplied no product or
  validation evidence.
- Independent recovery retained the intended boundary: classify only the
  Requests automation capability, preserve request staging as the useful
  offline path, and do not infer installation or platform facts the host does
  not report.

### Product defects found and fixed

1. **The UI discarded structured MoonTown service evidence.** Daemon lifecycle
   responses already carried `service_configured`, `service_config_path`, and
   `service_cwd`, but `DaemonLifecycleResult` omitted them. Requests therefore
   could not distinguish a configured stopped service from missing
   configuration.
2. **Requests capability status depended on a progress projection.** The
   workspace summary used only `town_progress.daemon_running`, which cannot
   represent probe failure or configuration state. It now derives from the
   lifecycle record plus an explicit probe-availability flag.
3. **Capability copy and actions were Code-specific.** The shared six-state
   classification remains private, while Code and Requests now own separate
   titles, explanations, action types, and labels. Requests cannot inherit
   install/runtime wording from another capability.
4. **A stopped or degraded automation service could look like a blocker.** The
   Requests surface now states that requests can still be saved and leaves the
   composer enabled. Running needs no setup action; configured/stopped offers
   Start automation; misconfiguration offers Review setup; a failed probe
   offers Check again.
5. **Technical host paths could leak into primary copy.** Configuration path
   and service working directory are shown only inside Technical details.

### Evidence and limits

- Four focused UI tests cover structured running, stopped, misconfigured, and
  temporarily unavailable classification; Requests-owned copy and action
  allowlists; probe transition preservation; workspace-summary consistency;
  stable rendering hooks; technical disclosure; and an enabled composer.
- The missing-service backend test now asserts the structured configuration
  path and working-directory fields consumed by the UI.
- `moon check --target js` passes with zero warnings; the UI suite passes
  335/335; the native suite passes 228/228; localization passes 3/3; and the
  production build passes.
- `scripts/desk_mode_browser_smoke.sh empty` passes with a real
  `misconfigured` Requests capability panel, visible offline-staging guidance,
  an enabled request composer, and intact navigation back to Code.
- Requests intentionally does not classify `NotInstalled` or
  `UnsupportedPlatform`: the lifecycle response does not yet provide
  installation or platform support evidence. Completing those states requires
  a host-contract extension and deterministic fixtures. This is a bounded
  Phase 1 slice, not Phase 1 completion.

## Command 025 — Requests typed-surface state and recovery

### MoonCode result and audit

- Command 025 received the exact Requests state contract, owning files,
  required browser assertion, and nested-module validation commands.
- Its first two semantic searches failed on private symbols. It then recovered
  with repository search, but spent several planner steps reading three
  invented filenames before locating the actual split Town view files.
- MoonCode implemented the model fields, lifecycle transitions, most view
  helpers, library reset, browser assertion, and an initial test file. It also
  passed an unsupported target to `moon fmt` before correcting that invocation.
- The only compile check failed on an invented `RequestRecord` shape. The
  command exhausted its 20-step budget without tests, browser evidence,
  documentation, interface review, or a successful finish. Its partial result
  was therefore audited and repaired independently.

### Product and implementation defects found

1. **Ledger failure could masquerade as no activity.** A failed
   `LoadedRequests` previously copied its raw error into composer feedback while
   leaving an empty request array. The view could then render “No activity yet”
   as though the request ledger had loaded successfully.
2. **Refresh had no typed transition.** Opening or refreshing Requests did not
   expose Loading and could not retain prior records as visibly stale evidence.
3. **Composer state and ledger state were conflated.** `request_status` owns
   request composition/submission feedback; it was also used for request-ledger
   transport failure. The ledger now owns `requests_state` and
   `requests_error`.
4. **MoonCode duplicated the ledger during its partial implementation.** It
   rendered a raw request list in the new state wrapper, retained the existing
   recent-work rendering, and reused the same state hook inside Diagnostics.
   Independent recovery keeps one primary state panel, one user-facing recent
   work list, and a separate diagnostic ledger without duplicate test IDs.
5. **MoonCode’s test fixture did not match the actual DTO.** It invented
   `prompt`, `workspace_id`, `created_at`, and `context_entries` fields on
   `RequestRecord` instead of using its structured `request : Json` payload.
   The fixture now constructs the real record contract.

### Recovered behavior and evidence

- Requests start at `FirstUseEmpty`; selection and visible Refresh enter
  Loading without discarding prior records; explicit empty success becomes
  `LegitimateZero`; nonempty success becomes ready content; failure retains
  prior records as Stale or becomes `RecoverableError` without prior content.
- Successful request submission clears its own composer fields, enters ledger
  Loading, and clears only the prior ledger error. Ledger failure no longer
  overwrites composer feedback.
- `requests-state-panel` exposes exact stable state keys. Requests owns its
  titles, details, Check/Refresh/Retry actions, and technical disclosure.
  Raw transport errors appear only under Technical details.
- Recent runs remain visible independently of request-ledger state. A failed
  empty ledger does not emit false “No activity” copy, and automation
  capability state still does not disable request staging.
- Three focused tests cover initial/loading/zero/ready/stale/recoverable
  transitions, submission refresh, prior-record and composer preservation,
  state/action/copy mappings, rendered honest-zero and stale contracts,
  technical disclosure, and composer enablement.
- `moon check --target js` passes with zero warnings; the complete UI suite
  passes 338/338; native tests pass 228/228; localization passes 3/3; and the
  production build passes.
- `scripts/desk_mode_browser_smoke.sh empty` passes after observing an exact
  `legitimate-zero` request ledger with honest empty copy, then independently
  checking degraded automation guidance and an enabled composer.
- Requests is the third typed consumer of the shared surface-state contract.
  Disconnected, capability-limited, and terminal ledger states remain
  contract-level cases until transport evidence can select them. Other primary
  surfaces and the full Phase 1 matrix remain open.

## Command 026 — Complete primary navigation and destination recovery

### MoonCode result and audit

- Command 026 received the exact seven-destination contract, legacy-route
  requirements, compact-navigation acceptance, reusable surface inventory,
  required tests, browser journey, documentation, and nested-module validation
  commands.
- It found the relevant shell, route, vocabulary, and update files, but added a
  `Runs` workspace constructor that collided in name with the existing private
  `Runs` activity. The partial implementation relied on contextual inference
  instead of preserving an unambiguous model.
- Its first check failed after the enum expansion. The later palette edit called
  an undefined `primary_palette_commands` helper, and no successful nested UI
  check followed.
- The proposed Runs destination rendered the request scheduler’s progress panel
  instead of book-scoped run history. Publish contained only a heading and
  placeholder sentence. The title bar, compact control, keyboard shortcuts,
  route synchronization, four-item Pages rail, tests, browser proof, and
  documentation were not implemented.
- The native runtime ended failed after 20 planner steps and 26 tool calls,
  without a completion result. All partial changes were therefore treated as an
  unverified draft and audited independently.

### Product defects found and fixed

1. **The primary information architecture exposed the wrong destinations.**
   The visible strip contained Home, Pages, Code, Flow, and Packs, while
   Requests and Review were duplicated in the Pages rail and Publish was only a
   file-oriented subsection. The primary order is now exactly Home, Pages,
   Code, Requests, Runs, Review, Publish. Flow and Packs remain available
   through Commands.
2. **Runs and Review shared one route identity.** The legacy `runs` slug selected
   the Review activity. Exact `requests`, `runs`, `review`, and `publish` routes
   now select four unambiguous private workspace modes; exact primary URL sync
   emits `home`, `pages`, `code`, `requests`, `runs`, `review`, and `publish`.
   Existing legacy aliases remain accepted.
3. **Pages duplicated primary jobs.** Its internal rail now contains only Pages,
   Search, Inbox, and Settings. Legacy activity routes remain compatible without
   presenting duplicate controls.
4. **Runs had no honest destination.** The new book-scoped Runs workspace
   distinguishes no selected book from a legitimate zero, lists run summaries,
   opens result artifacts, and keeps status, phase, and run ID under Details.
5. **Publish could imply an output existed without evidence.** The new workspace
   distinguishes no selected book, active readiness checking, review-blocked,
   and unblocked states. Its unblocked state invites the user to check the
   generated output location; it does not claim that output exists or is
   current. Raw paths and portable-export actions are secondary technical
   controls.
6. **Narrow navigation compressed multiple tabs into the title bar.** At 760
   pixels and below, the desktop strip is hidden and one native, keyboard-
   operable disclosure presents the same seven actions with unique hooks. The
   current destination appears in the summary, and the menu fits a 320-pixel
   viewport without document overflow.
7. **Shortcuts stopped at five and targeted secondary tools.** Meta/Control+1
   through +7 now select the seven primary destinations. The desktop and compact
   controls expose matching shortcut metadata without duplicate test IDs.

### Recovered behavior and evidence

- Requests and Review reuse their typed panes and enter their real Loading
  transitions when selected. Runs fetches book-scoped runs, progress, and
  events. Review and Publish refresh review evidence.
- Commands always includes the seven primary destinations. Mode-specific
  controls remain secondary, including Flow and Packs.
- Six focused tests cover primary order, hooks, shortcuts, compact rendering,
  route/state selection, Runs no-book/zero states, and Publish review blocking
  without a false output claim. Updated vocabulary, rail, and palette tests
  cover the changed contract.
- `moon check --target js` passes with zero warnings; the complete UI suite
  passes 344/344; native tests pass 228/228; localization passes 3/3; and the
  production build passes.
- Empty-library browser proof traverses Requests → Runs → Review → Publish,
  checks exact deep links and honest zero/readiness hooks, proves the four-item
  Pages rail, then uses real CDP Space events to open the compact disclosure and
  select Requests at 320×700 with no horizontal document overflow.
- The clean-workspace quickstart and populated browser smoke also pass. The
  populated smoke retains exact 1440×900, 1280×720, 1024×768, 390×844, and
  320×700 geometry evidence.
- This closes the bounded primary-navigation destination item. It does not close
  the full keyboard, text-zoom, screen-reader, native-picker, capability, or
  per-surface-state Phase 1 gates.

## Command 027 — Runs typed-surface state and recovery

### MoonCode result and audit

- Command 027 received the exact Runs state contract, the initial and explicit
  book-selection paths, the real run/artifact DTO shape, required state and
  browser assertions, documentation targets, and nested UI validation commands.
- MoonCode added the private model fields, most result transitions,
  Runs-specific state copy/actions, a stable state panel, and an initial test
  file. It then failed its first focused test and stopped after 20 planner steps
  and 38 tool calls without a completion result.
- The failed fixture tried to construct read-only `DeskRunProjection` and
  `DeskRunArtifact` records directly and referenced an unbound artifact kind.
  It did not use the public core constructors already present in the repository.
- The planned `--filter runs` command was also not a valid focused proof for
  these test names: once compilation was repaired, that exact filter selected
  zero tests. Recovery runs the owning test files explicitly.
- MoonCode rewrote the complete destination-view file to change Runs. That
  silently removed the established Publish output-evidence panel, its honest
  generated-location action, and its secondary portable-export disclosure.
  Existing unit and browser assertions exposed the regression.
- The command did not implement the required initial auto-selection transition,
  did not update the browser assertion, did not document the work, and did not
  reach interface or full-suite review. Its partial result was treated as an
  unverified draft.

### Product and implementation defects found

1. **An empty array was treated as proof of no runs.** Before a request
   completed, and after a failed request, the Runs view immediately rendered
   “No runs yet.” Legitimate zero is now selected only by an explicit successful
   empty response.
2. **Runs refresh had no owned state or error.** Runs now owns `runs_state` and
   `runs_error`; opening or refreshing the destination enters Loading without
   discarding last successful records.
3. **Failed refreshes could make old records look current.** A failure with
   prior records now selects Stale and keeps them visible. A failure without
   prior records selects RecoverableError. Raw transport text remains under
   Technical details and no longer replaces the shared host status.
4. **Initial book selection omitted the loading transition.** Both explicit
   selection and the first automatic selection from a loaded workspace list now
   enter Runs Loading. If automatic selection changes books, cached records and
   the prior book’s error are cleared so evidence cannot cross book boundaries.
5. **State copy was not Runs-owned.** Runs now owns plain-language titles,
   details, Check/Start request/Refresh/Retry actions, and stable keys for all
   eight contract cases. Run status, phase, and run ID stay under each record’s
   Details disclosure.
6. **A whole-file rewrite regressed Publish.** Recovery restored the established
   output check, generated path, and portable-export disclosure before accepting
   the Runs change.

### Recovered behavior and evidence

- Runs starts at FirstUseEmpty. With a selected book, selection and Refresh
  enter Loading; explicit empty success selects LegitimateZero; nonempty success
  renders ready records; failed refresh with records selects Stale; failure
  without records selects RecoverableError.
- `runs-state-panel` exposes one stable `data-state` owner. Loading and stale
  retain the last successful records, result-file actions remain available,
  and raw failures appear only under Technical details. No selected book remains
  a separate prerequisite rather than a fabricated state result.
- Disconnected, capability-limited, and terminal mappings render owned copy but
  remain contract-level cases until host evidence can select them.
- Four focused Runs tests cover real DTO constructors, explicit and automatic
  selection, cross-book clearing, zero/ready/stale/recoverable transitions, all
  eight mappings, rendered hooks, stale/loading retention, technical
  disclosure, result-file labels, and run-ID disclosure. Together with the
  restored destination tests, the focused pass is 10/10.
- `moon check --target js` passes with zero warnings; the complete UI suite
  passes 348/348; native tests pass 228/228; localization passes 3/3; and the
  production build passes.
- `scripts/desk_mode_browser_smoke.sh empty` passes through the visible Runs
  route and requires exact `legitimate-zero` state plus honest “No runs yet”
  copy after the successful empty response.
- Runs is the fourth typed consumer of the shared surface-state contract. This
  closes only the bounded Runs state slice; the remaining surface integrations,
  host-backed state evidence, native-picker, and accessibility gates keep
  Phase 1 open.

## Command 028 — Publish typed-readiness state and recovery

### MoonCode result and audit

- Command 028 received the exact Publish truth boundary, Review/Publish
  separation, book-selection reset paths, all eight owned mappings, existing
  output-check regression gates, browser journeys, and nested validation
  commands.
- Its first discovery batch failed because it included a nonexistent root
  `package.json` in repository search and passed a directory to
  `moon ide outline`. It then created a placeholder file before locating the
  owning implementation and attempted several invented filenames, including
  `model.mbt`, `review_state.mbt`, and `view_publish.mbt`.
- After repository search found the real split files, MoonCode implemented the
  private model fields, result mapping, decision invalidation, and most
  selection resets. Two narrow edits initially failed on invented surrounding
  text and were retried against the actual source.
- The runtime stopped failed after 20 planner steps and 56 tool calls,
  immediately after inserting an unused Publish notice helper. The helper was
  not mounted in the destination; no stable panel, evidence rendering, tests,
  browser assertions, documentation, interface review, or validation had been
  completed. The partial result remained a draft.

### Product and implementation defects found

1. **Readiness failure could look like successful readiness.** Publish borrowed
   `review_state` and handled only one Loading case. A failed review-queue fetch
   with no items fell through to `publish-output-check` and “No review items are
   blocking this book,” despite having no successful response.
2. **Resolved cached items could look current after failure.** A failed refresh
   with prior accepted/rejected items also fell through to the ordinary output
   check without a stale label.
3. **Book-scoped evidence crossed selections.** Explicit book selection,
   automatic replacement of a missing selection, and library replacement did
   not consistently clear `review_items`. Review and Publish could therefore
   render another book’s queue.
4. **Publish transport state was coupled to Review presentation.** Publish now
   owns `publish_state` and `publish_error`; Review retains its independent
   state and copy while both consume the same typed review-queue response.
5. **A review decision did not invalidate Publish readiness.** Successful
   decisions already triggered a queue refresh. They now also enter Publish
   Loading and clear the prior Publish error until new evidence arrives.
6. **The partial renderer was disconnected.** Independent recovery mounted one
   stable state panel, preserved both established Publish content paths and
   technical exports, and removed the unused-helper warnings.

### Recovered behavior and evidence

- Publish starts at FirstUseEmpty. Selection with a book enters Loading and
  preserves same-book evidence; explicit empty success selects LegitimateZero;
  nonempty success becomes ready typed content; failure with prior items becomes
  Stale; failure without items becomes RecoverableError.
- `publish-state-panel` exposes one exact `data-state`. Loading and stale retain
  the last successful pending/resolved evidence with wording that identifies it
  as retained. Failure without evidence cannot render `publish-output-check`.
- Legitimate zero means only that an explicit review-queue response contained
  no blockers. The output action still tells the user to check
  `book/site/generated`; it does not claim a generated result exists or is
  current. Pending evidence still routes to Review. Portable-export controls
  remain inside the existing technical disclosure.
- Explicit and automatic book changes clear old review items; library
  replacement resets Review and Publish; a same-book refresh may retain items
  while Loading. Disconnected, capability-limited, and terminal Publish states
  remain renderable contract cases without fabricated production transitions.
- Four focused Publish tests cover selection and cross-book clearing,
  zero/ready/loading/stale/recoverable transitions, decision invalidation, all
  eight mappings, stable rendering hooks, raw-error disclosure, retained
  evidence, output-truth wording, both content paths, and technical exports.
  With destination and library-reset regressions, focused tests pass 15/15.
- `moon check --target js` passes with zero warnings; the complete UI suite
  passes 352/352; native tests pass 228/228; localization passes 3/3; and the
  production build passes.
- Both `scripts/desk_mode_browser_smoke.sh empty` and
  `scripts/desk_mode_browser_smoke.sh quickstart` pass with exact Publish
  `legitimate-zero`, the established output-check hook, and an assertion against
  false “output is ready” copy. Failure-state browser proof remains at
  reducer/render level because the current fixture has no deterministic
  review-fetch failure seam.
- Publish is the fifth typed consumer of the shared surface-state contract.
  This bounded readiness slice does not prove output existence, a publish job,
  permission/connectivity states, or Phase 1 completion.

## Command 029 — Code session-list transport state and recovery

### MoonCode result and audit

- Command 029 received a bounded file inventory and explicit ownership rules:
  model/list transport only, all eight private mappings, stable rail rendering,
  retained rows, successful-empty requirements, the existing Code tests, and a
  prohibition on interpreter or heredoc repository rewrites.
- Initial reads found the correct model, navigation, reducer, state-contract,
  view, and Code test files. One `moon ide peek-def` lookup for the reducer case
  failed even though adjacent semantic lookups succeeded; a bounded file read
  recovered the source.
- The runtime then violated the mutation constraint by using Perl whole-file
  substitutions and shell heredocs. Its reducer substitutions targeted
  nonexistent `Ok(sessions)`/`let next` source and silently made no transition
  change. Its view substitutions likewise missed the real text, so the panel
  helper was appended but never mounted and false empty copy remained.
- The command added only two shallow mapping/initialization tests, ran one
  failing check, made two syntax/test repairs, and stopped failed after eight
  planner steps. It did not run focused behavior tests, the complete suite,
  browser evidence, interface review, or documentation. All shell-authored
  output therefore remained unaccepted draft material pending independent
  audit.

### Product and implementation defects found

1. **Listing failure looked like a valid empty catalog.** The active session
   rail always rendered “No general chats” or “No chats in this MoonBook” when
   its current group had no rows, even before a successful response and after a
   failed response.
2. **Transport failure was stored in composer feedback.** A list error updated
   `mooncode_composer_status`, which must also preserve a user’s active draft,
   but had no independently renderable list state or raw-error field.
3. **Refresh had no retained-evidence label.** Existing session rows were
   correctly preserved on list failure, including their canonical
   conversations, but the rail presented them as current rather than stale.
4. **Search zero was not transport-aware.** “No matching chats” depended only
   on a query and the derived groups. Loading or a failed listing could
   therefore look like a successful empty filter result.
5. **The command’s edits were noncompliant and incomplete.** Interpreter
   rewrites bypassed its native-edit constraint, used stale invented source,
   and produced an unused renderer. Independent recovery replaced the partial
   helper and tests and patched only verified owning blocks.
6. **Browser verification initially served restored output.** The smoke script
   serves `ui/rabbita-desk/dist`. Running it after restoring pre-build
   distribution tested an obsolete bundle whose visible Save action lacked the
   current test hook. Recovery now builds and runs the browser smoke inside one
   guarded distribution-backup window, then restores the original `dist`.
7. **Controlled-input smoke steps could race.** Back-to-back synthetic input
   events did not wait for the controlled DOM to settle. The helper now waits
   across two animation frames and rechecks the rendered value; the quickstart
   also records the settled Inbox field/button state before saving.

### Recovered behavior and evidence

- `mooncode_sessions_state` starts at FirstUseEmpty. Selecting Code enters
  Loading only when explicit daemon evidence says the real listing request is
  issued; unavailable/not-running capability evidence remains owned by the
  existing capability UI.
- Successful empty and nonempty responses select LegitimateZero and ready
  content respectively. Failure with prior rows selects Stale and retains the
  rows; failure without rows selects RecoverableError. The raw list error is
  stored separately while established composer/draft behavior remains intact.
- One `mooncode-sessions-state-panel` exposes the exact state key. Loading and
  stale copy labels retained rows. Group-empty and search-empty copy require a
  successful listing. Retry/Refresh dispatch the real Code-selection path.
- The slice does not alter session reconciliation, optimistic-row
  acknowledgement, selected-session rules, archived-list optional failure,
  transcript projection, metadata scheduling, watch generation/revision, or
  canonical conversation ownership.
- Five focused tests cover running-evidence Loading, row retention, zero/ready/
  stale/recoverable transitions, all eight mappings, exact rendered states,
  raw-error disclosure, false-empty suppression, ready rows, and successful
  search filtering. They pass 5/5. The existing Code session suite passes
  95/95, including listing-outage preservation of the selected terminal
  conversation.
- `moon check --target js` passes with zero warnings; the complete UI suite
  passes 357/357; native tests pass 228/228; localization passes 3/3; and the
  production build passes. JavaScript and shell syntax checks and
  `git diff --check` pass.
- Nested and root `moon info`/`moon fmt` closeout passes. The generated UI
  interface contains only the previously reviewed SourcePane/SurfaceState
  delta; no Code session-list state or helper became public API.
- `scripts/desk_mode_browser_smoke.sh quickstart` passes against a freshly
  built distribution with exact Code `legitimate-zero` before the first
  prompt and a ready one-row catalog after acknowledgement. The empty-library
  smoke also passes and retains capability-owned setup behavior. The original
  tracked distribution is restored after each run.
- Code session listing is the sixth typed consumer. This slice does not claim
  that the complete Code execution state matrix, Phase 1, or the public typed
  MoonCode contract is complete.

## Command 030 — Requests installation and platform evidence

### MoonCode result and audit

- Command 030 received the exact host/UI ownership split, optional evidence
  schema, older-response fallback, all six target classifications, technical
  disclosure boundary, focused tests, and native-edit-only constraint.
- One nested-UI `moon ide outline` failed because the command again used the
  root module context. Direct reads then found all eight named files.
- MoonCode made only three partial edits: it added an installation DTO and two
  optional lifecycle fields, added unattached host helper functions, and added
  one platform normalization test. It invented an undefined `PlatformEvidence`
  type, emitted neither evidence object in lifecycle JSON, made no classifier
  or rendering change, and added no behavior test.
- It ran root `moon_check`, which does not check the nested UI module, then
  called `finish` after six planner steps. The runtime reported completion even
  though the nested UI did not compile and most requested behavior was absent.

### Defects and independent recovery

1. **Two capability states were unreachable.** Requests could map running,
   configured/stopped, misconfigured, and unavailable evidence, but the Town
   lifecycle DTO exposed no installation or platform truth for NotInstalled or
   UnsupportedPlatform.
2. **Configuration alone was overloaded.** An absent service configuration was
   always Misconfigured, so the UI could not distinguish no local automation
   installation from an installed supervisor with invalid setup.
3. **LaunchAgent presence was initially too broad.** The existing plist path
   uses a global label. Treating any plist at that path as installation evidence
   could attribute another suite root’s supervisor to the active library.
   Recovery reads the plist and accepts it only when it contains the active
   suite root; deterministic helper tests avoid depending on the operator’s
   live LaunchAgents directory.
4. **MoonCode’s validation boundary was wrong.** Root checking passed while the
   nested UI contained an undefined type. Independent validation always checks
   both modules.
5. **Evidence is now explicit and bounded.** Every Town daemon lifecycle and
   policy response includes normalized platform/architecture support and
   installation `{installed, source}` evidence. Installation source is only
   `service-configured`, matching-root `launch-agent`, or `none`; it does not
   claim binary, network, or runtime health.

### Recovered behavior and evidence

- Requests classification reuses the fixed six-state precedence. Explicit
  unsupported evidence selects UnsupportedPlatform; explicit absent
  installation plus no configuration selects NotInstalled; installed but
  invalid setup selects Misconfigured; configured/stopped and running select
  their existing states. Probe failure still selects
  TemporarilyUnavailable. Missing optional fields preserve the prior
  unconfigured-to-Misconfigured behavior.
- Technical details expose platform, architecture, support, installation
  status/source, and existing configuration paths. Plain-language capability
  copy remains separate, and request staging/submission stays enabled in every
  degraded state.
- Host focused tests pass 4/4 and UI capability tests pass 11/11. The complete
  native suite passes 230/230, UI passes 357/357 with zero warnings,
  localization passes 3/3, and the production build passes.
- The freshly built empty-library browser smoke passes with exact Requests
  `not-installed`, “Requests can still be saved,” and the existing setup
  action. The original distribution is restored afterward.
- This closes the previously unclaimed Requests installation/platform mapping;
  it does not prove a credentialed installer, unsupported-host execution, or
  complete Phase 1 operational readiness.

## Command 031 — Packaged native library-picker recovery

### MoonCode result and audit

- Command 031 ran in a dedicated internal session rooted at the native runtime
  repository. It received the live packaged-app symptom, the exact deferred
  bridge mismatch, a native-edit-only constraint, and explicit requirements
  for a real picker, tests, package validation, and an honest finish.
- The command used shell searches despite the requested tool boundary, made one
  failed read/edit attempt, and left only a nonfunctional scheduler comment
  plus a redundant `can_launch` check.
- It did not change the route mode, reach the native handler, run focused tests,
  rebuild the package, exercise the picker, or finish with verified evidence.
  Independent audit removed that residue before recovery.

### Product and validation defects found

1. **The native picker route was unreachable.** File-dialog commands were
   declared and registered asynchronous, while the macOS deferred bridge packet
   was drained through synchronous dispatch. The invoke promise stayed pending
   and no panel process appeared.
2. **The first recovered panel was not owned by the application.** The backend
   delegated to a script process. The panel was visible to a human, but the
   MoonDesk accessibility surface blocked until that separate process returned.
   Process existence was therefore insufficient acceptance evidence.
3. **The UI discarded the host’s corrective message.** Selecting one MoonBook
   correctly returned `Choose a library folder, not one MoonBook`; generic
   metadata decoding replaced it with `Could not select the library`.
4. **A structurally valid package could contain stale UI assets.** Reusing the
   restored tracked `dist` omitted current picker controls while strict bundle
   verification still passed. Acceptance builds must generate current source
   into an isolated output before packaging.
5. **Cold start could require a guessed Refresh.** The WebView sometimes sent
   its first request batch before the supervised local service was ready, then
   permanently marked bootstrap complete after failure.

### Independent recovery

- All four file-dialog routes are now synchronous, main-thread modal commands.
  Generic and native registries use synchronous handlers; the artificial async
  yield and unused async dependency are removed.
- macOS now opens an app-owned `NSOpenPanel` or `NSSavePanel` through Cocoa.
  Directory, single-file, multi-file, save-file, initial-directory, and
  suggested-name behavior remain supported. Selected native URLs are converted
  directly into the existing response packet.
- The UI decodes library-selection responses as structured JSON. Successful
  metadata still follows the typed contract; a structured host error preserves
  its `message`; malformed or transport failures keep the generic fallback.
- Cold-start metadata failure schedules a retry of only the data-fetch batch
  while no established root exists. One-time observers and import polling are
  not duplicated; a later refresh failure does not start a bootstrap loop.
- Current UI source is built into a separate acceptance directory before
  bundling. The tracked distribution is neither overwritten nor mistaken for
  current source evidence.

### Packaged macOS evidence

- The rebuilt manifest reports 17 synchronous and 0 asynchronous bridge routes.
  Strict verification, all 14 bundle checks, native launch-session preparation,
  live bundle-check, and live-build pass.
- The native panel is exposed in MoonDesk’s accessibility tree as
  `dialog Open` with `ID: open-panel`, including path navigation, **Cancel**,
  and **Open** controls.
- Real cancellation produces `Library selection cancelled` and retains the
  application-data library.
- Selecting the invalid one-book fixture produces the exact visible correction
  `Choose a library folder, not one MoonBook` and retains the active root.
- Selecting the valid fixture activates its canonical root, lists
  `Native Picker Acceptance`, reports one ready workspace from the live API,
  and saves the same path under the stable application-data preference.
- The initial bootstrap message is deferred until after root-cell mount, while
  readiness failure still retries only the data-fetch batch. Relaunching the
  rebuilt package without pressing **Refresh** restores the saved root and
  `Native Picker Acceptance` on the first rendered state.
- The retained restart screenshot is
  `_build/native-picker-gate/evidence/07-restored-after-relaunch.jpeg`.

### Regression evidence

- Lepusa file-dialog tests pass 7/7; bundled runtime tests pass 23/23; macOS
  runtime tests pass 21/21; the complete Lepusa native suite passes 543/543.
- MoonDesk library-selection tests pass 7/7 and bootstrap tests pass 4/4.
- The complete MoonDesk native suite passes 230/230; UI passes 312/312 with
  zero warnings; localization passes 3/3; the current-source production build
  and fresh strict package build pass.
- Detailed steps, screenshots, remaining boundary, and defect table are in
  `docs/NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md`.
- This closes real macOS interaction through persistence and restart
  restoration. It does not claim another desktop platform, signing,
  notarization, clean-machine installation, or Phase 1 completion.

## Command 032 — Home file-list truth and response identity

### MoonCode result and audit

- Command 032 received the full productization plan and a bounded request to
  make Home file listing a typed eight-state consumer. The requested contract
  included workspace/directory response identity, stale-response rejection,
  same-location row retention, different-location clearing, honest zero/error
  rendering, focused tests, and full validation.
- The command first tried to read `app_model.mbt` from the repository root,
  although the named UI sources live under `ui/rabbita-desk/main`. After that
  failed, it used a shell `find` to locate the files.
- It then wrote only `desk_entries_state.mbt`. The helper referenced
  nonexistent `SurfaceState` constructors (`Partial`, `PermissionBlocked`, and
  `CapabilityUnavailable`), did not change the model, messages, commands,
  reducer, rendering, or tests, and did not run a compiler or test.
- MoonCode called `finish` after five tool calls. The runtime recorded the turn
  as completed even though `moon check` reported 15 errors and 5 warnings.
  Independent recovery replaced the invalid helper completely.

### Product and validation defects found

1. **Listing responses had no navigation or request identity.** `LoadedEntries`
   carried only a result. A slow response from a previous workspace or
   directory could overwrite the folder currently visible to the user, and two
   same-folder refreshes had no ordering token to identify the newer request.
2. **Transport states were conflated.** First use, active loading, successful
   empty, failed empty, and stale retained data all flowed through the same
   empty-folder rendering. A transient request could falsely claim that a
   folder contained zero files.
3. **Rows crossed location boundaries.** Moving to another directory or
   workspace left the old rows visible until the replacement request
   completed, even though the title and breadcrumbs already named the new
   location.
4. **Listing failure leaked through shared status copy.** The raw transport
   error was assigned to the broad Home status line. It had no surface-owned
   recovery state or Technical details boundary.
5. **Two reload paths disagreed with their model identity.** Publishing fetched
   the generated `wiki` directory while leaving `current_directory` empty.
   Portable export similarly fetched `portable/app-tool` without rebinding the
   current directory. Strict response matching exposed both mismatches.
6. **The populated browser smoke could validate stale output.** Its server path
   was hardcoded to tracked `ui/rabbita-desk/dist`, so a current source build in
   an isolated directory could not be tested directly.
7. **The restart branch initially bypassed the new override.** The first
   browser-smoke launch honored `UI_DIST`, but the quickstart relaunch still
   returned to tracked output. Both launches now use the same explicit
   distribution.
8. **Command completion was not a correctness gate.** The runtime accepted
   `finish` without requiring a successful compile, focused behavior test, or
   proof that all requested owning layers changed.

### Independent recovery

- Callers now dispatch a reducer-owned `RequestEntries` message. The reducer
  assigns a monotonically increasing generation before issuing HTTP.
  `LoadedEntries` carries that generation with the requesting workspace and
  directory. A result is accepted only when all three still match, so neither
  abandoned navigation nor an older same-folder refresh can replace current
  evidence.
- Home owns `desk_entries_state` and a separate `desk_entries_error`. Initial
  state is FirstUseEmpty; an issued request is Loading; an explicit empty
  success is LegitimateZero; nonempty success is ready content; failed refresh
  with prior same-folder rows is Stale; and failure without rows is
  RecoverableError.
- Changing workspace or directory clears rows before requesting the new
  location. Refreshing the same location preserves rows and labels them as
  loading. File creation, rename, move, copy, trash, restore, import, Markdown
  save, and created/imported workspace transitions use the same rule.
- The Home state panel has stable state and test hooks. Loading and Stale may
  retain rows; unsuccessful states cannot emit “No matching files”; zero is
  shown only after an explicit successful listing. Retry and Refresh issue the
  existing refresh action. Raw errors appear only inside Technical details.
- Published-book navigation now binds both the fetch and model to `wiki`.
  Portable export binds both to `portable/app-tool`.
- `scripts/desk_mode_browser_smoke.sh` accepts `UI_DIST` and uses it for both
  initial launch and quickstart relaunch.

### Regression evidence and remaining boundary

- Seven focused tests cover all eight mappings, same- versus different-location
  row handling, stale workspace/directory rejection, same-folder generation
  ordering, zero/ready/stale/error reducer transitions, rendered state truth,
  raw-error isolation, and successful-only filtered zero.
- Strict JavaScript checking passes with zero warnings. The complete UI suite
  passes 319/319, the native suite passes 230/230, and localization passes 3/3.
  `moon info`, `moon fmt`, and `git diff --check` pass.
- A fresh production UI built into
  `_build/desk-entries-smoke-dist`, and the populated full browser smoke passed
  from that exact output at 1440×900, 1024×768, 390×844, and 320×700.
- This closes cross-location and same-location response ordering together with
  honest file-list presentation. It does not close the remaining Phase 1
  surface-state, non-macOS picker, or accessibility evidence gates.
- Future MoonCode commands are not accepted on `finish` alone. At minimum the
  changed module must compile, focused behavior tests must pass, and the result
  must demonstrate changes in every named owning layer before runtime
  completion is treated as evidence.

## Command 033 — MoonCode coding-completion evidence gate

### Scope and MoonCode result

- Command 033 ran in a dedicated runtime-repository session. Its prompt embedded
  the complete authoritative productization plan, the exact false-completion
  reproduction from Command 032, named owning files, positive and negative
  acceptance cases, test requirements, and a prohibition on claiming success
  without proof.
- MoonCode found the correct model-execution acceptance function, read the
  runtime orchestrator and tests, added a private structured verdict, ran a
  successful native compiler check, and added initial regression tests.
- Its first test command misused the typed `moon_cmd` argument contract and
  exited 255. Its second command reached the package tests and exited 2.
  MoonCode did not call `finish`; `runtime.turn_finished`, the terminal receipt,
  and the runtime service all recorded failure. This is materially better than
  Command 032’s false completion, but the implementation remained incomplete.

### Defects found in the existing runtime

1. **Mutation was treated as completion evidence.** For coding-intent prompts,
   any accepted `write`, `edit`, `shell`, `moon_cmd`, or `moon_check` followed
   by `finish` could be marked complete. No successful verification after the
   change was required.
2. **Unrelated success could recover failed validation.** After any failed
   tool, the old rule accepted the first later successful non-`finish` tool. A
   read after a failed check therefore erased the failure for completion
   purposes.
3. **Explicit coding batches bypassed model completion rules.** The stricter
   helper was used only for model-planned batches. Explicit
   `runtime_tool_calls` were accepted when every tool packet returned success,
   even if the batch was `write → finish`.
4. **Requested focused tests were not recognized.** Test intent matched phrases
   such as “run tests” but not “run focused tests” or “add focused tests.”
   A check could therefore satisfy a prompt that explicitly required tests.
5. **Read-only product questions could be mistaken for coding work.** Broad
   substring checks for `app`, `site`, and `script` selected coding tools even
   for explanation or review prompts.
6. **Completion had no structured terminal reason.** Runtime responses and
   `runtime.turn_finished` said only that tool execution failed. They did not
   distinguish missing mutation, missing verification, missing requested test,
   or a post-verification failure.

### Defects found in the Command 033 patch

1. Its tests wrote prompt content under `request`, while the native command
   contract reads `text`, then packet/payload message fallbacks. The new tests
   therefore exercised the non-coding branch.
2. It searched for patch verification directly on the execution object.
   Actual proof is nested under `result.metadata.verification`.
3. It required validation to occur strictly after a mutation, so an
   `apply_patch` carrying successful verification could not prove its own
   mutation.
4. It layered the new verdict in front of the old “any later success recovers”
   logic instead of replacing that logic with one ordered rule.
5. It did not update the existing recovery test, did not wire the verdict into
   explicit batches, compact responses, terminal events, or receipt messages,
   and exhausted its planner budget before recovery.

### Independent recovery

- One private completion verdict now owns final-`finish`, mutation,
  verification, requested-test, and post-failure ordering.
- Verification-sensitive prompts require an accepted `write`, `edit`,
  `apply_patch`, or `revert_patch`. A successful `moon_check` or
  `moon_cmd check|test|build` must occur at or after the final mutation and
  after every failed tool. A verified patch can prove its own mutation at the
  same result index.
- When the prompt requests tests, only a successful typed `moon_cmd test`
  satisfies completion. An earlier check, a successful read, or a test that
  predates the final edit cannot close the gate.
- Both model-planned and explicit coding batches use the same verdict.
  Non-coding replies still permit an accepted final `finish`; explanation and
  review wording takes precedence over incidental product nouns unless a real
  mutation verb is present.
- The compact runtime response preserves
  `mooncode-coding-completion-verdict`. A rejected verdict supplies the
  execution message, appears in `runtime.turn_finished.detail`, and produces a
  `runtime-failed` receipt. A proven verdict produces `runtime-completed`.
- MoonClaw’s runtime README, advertised capability packet, and top-level native
  MoonCode record now describe the enforced contract.

### Regression and live runtime evidence

- Completion-focused tests pass 5/5, read-only classifier regressions pass 2/2,
  verified-patch proof passes 1/1, the complete daemon suite passes 151/151,
  and the complete native MoonClaw suite passes 1,154/1,154.
- A rebuilt daemon on port 58403 executed an explicit negative batch:
  `write → finish`. The response was rejected with
  `coding completion has no successful typed test after the final mutation`;
  the terminal event was failed and the receipt was `runtime-failed`.
- The same rebuilt daemon executed an explicit positive batch:
  `write → moon_check → moon_cmd test → finish`. All four tools passed, the
  structured verdict was accepted, the terminal event recorded the successful
  typed-test reason, and the receipt was `runtime-completed`.
- The authoritative live records are the
  `completion-gate-live-negative` and `completion-gate-live-positive` session
  journals under MoonClaw’s local MoonCode product state.
- This implements the acceptance rule promised after Command 032. It does not
  prove that a model will choose all required owning layers correctly; it
  prevents the runtime from certifying missing or failed verification as
  completion.

## Commands 034–035 — Selected-preview state and identity slice

### Command 034 rejected before mutation

- Command 034 was the first real MoonDesk product repair submitted through the
  rebuilt, evidence-gated runtime. Its prompt embedded the complete
  authoritative plan and named the selected-preview race, display-string
  parsing, stale-evidence loss, diagnostic disclosure, owning layers, focused
  cases, product smoke, and documentation requirements.
- MoonCode twice called semantic `outline` on a package directory, although
  that operation requires a concrete source location in this environment. It
  then tried to edit nonexistent `app_types.mbt` and `app_msg.mbt` files
  instead of the real `app_model.mbt` owner.
- It made no accepted mutation and called `finish`. The hardened runtime
  rejected the turn with `coding completion has no accepted mutation evidence`;
  the terminal event, receipt, and runtime service all recorded failure.

### Command 035 rejected after an incomplete mutation

- The recovery prompt named every real owning file, prohibited the failed
  directory-outline path, corrected `@desk.DeskPreview` ownership, and
  reiterated that only typed compilation and tests after the final edit could
  satisfy completion.
- MoonCode read the real model and reference inventory, but again supplied
  unusable semantic locations. It added initial fields and a four-argument
  preview command, then ran `moon_check` before updating all consumers. The
  check failed.
- A blind ten-edit batch fixed six call sites and failed four replacements.
  A second check failed. MoonCode performed one more edit and stopped without
  `finish`; the runtime rejected the final non-finish result. The partial patch
  left 17 compiler errors and five warnings, including unmatched
  `LoadedPreview` patterns and omitted call-site arguments.

### Independent recovery and product result

- Preview fetch now mirrors the proven two-stage file-list request pattern:
  `RequestPreview(workspace, path)` allocates the next generation and launches
  `perform_fetch_preview_cmd`; `LoadedPreview` returns the complete workspace,
  path, generation, and result identity.
- The model stores current request workspace, path, and monotonic generation.
  It ignores every non-current result, including a late old-path result and an
  older response for the same path. Changing selection clears unrelated
  content. Refreshing the same selection retains its preview through Loading;
  failure becomes Stale with retained evidence, or RecoverableError when no
  evidence exists.
- Preview transport now consumes the shared `SurfaceState` contract. Plain
  title, detail, and retry copy is state-owned. Raw host errors are stored
  separately and appear only inside Technical details. Desk and Pages no
  longer branch on English `preview_status` substrings. Empty-book detection
  uses successful typed file-list zero evidence instead of a “not available”
  error phrase.
- Focused preview tests pass 12/12, library tests pass 12/12, and the typed
  Wiki empty-book test passes 1/1. The complete UI JS suite passes 373/373 with
  a zero-warning strict check.
- A fresh release-mode UI was built into a temporary directory, avoiding
  tracked distribution churn. The populated full browser smoke passed from
  that exact output at 1440×900, 1280×720, 1024×768, 390×844, and 320×700.
- This is the eighth typed primary-surface integration. Phase 1 remains open:
  other surface states, non-macOS picker proof, complete keyboard/text-zoom/
  focus/screen-reader evidence, and remote CI evidence are not claimed.

## Command 036 — 200% browser-zoom reflow acceptance

### MoonCode result and runtime defects

- Command 036 was deliberately smaller than the preceding state migration. It
  named the real browser-smoke helper, the exact 1440×900-at-200% equivalence
  of a 720×450 CSS viewport, existing geometry assertions, compact-navigation
  visibility/focus requirements, temporary release build, typed verification,
  and the evidence boundary.
- MoonCode first attempted an exact edit against stale nearby comment text.
  That edit failed, then a narrower edit succeeded in the correct populated
  journey.
- Its first release-build/smoke command wrote a helper path under `/tmp`; native
  book confinement rejected the command. Its approved retry still used a
  parent-relative output path and destructive cleanup that the selected-book
  boundary rejected.
- Its final retry produced the release build inside
  `ui/rabbita-desk/.command036-ui-output`, but remained inside
  `ui/rabbita-desk` before invoking a repository-root-relative smoke path. It
  exited 127. MoonCode stopped without typed check, typed tests, or `finish`;
  the hardened runtime rejected the turn. The command-owned generated directory
  was moved to Trash after independent use, so tracked distribution output was
  not changed.

### Independent recovery and rendered evidence

- The populated full smoke now captures `zoom-200-percent` at exactly 720×450,
  the layout-equivalent CSS viewport for a 1440×900 physical window at 200%
  browser zoom.
- The existing shared assertions prove no horizontal document overflow, no
  pane overlap, correct browser/details/library order, confined file-table
  width, reachable above-fold primary content, a correctly dimensioned PNG,
  and no console/runtime errors.
- A dedicated contract assertion also proves the exact viewport dimensions and
  that the compact primary destination summary is visible and can receive
  keyboard focus.
- The exact release-mode output generated by Command 036 passed the complete
  populated browser smoke at 1440×900, 1280×720, 1024×768, 390×844, 320×700,
  and the new 720×450 zoom-equivalent viewport. No CSS repair or weakened
  assertion was needed.
- Canonical fast validation remains green: 230/230 native and 373/373 UI tests
  with strict zero-warning checks; localization remains 3/3. This is
  browser-zoom reflow evidence only. Command 038 separately closes the bounded
  populated-Home text-only large-text case; complete focus-order and
  screen-reader gates remain open.

## Command 037 — keyboard-only first useful task

### MoonCode result and runtime/tool defects

- The command bounded the work to the existing clean-workspace quickstart,
  four form fields, their render tests, and real CDP keyboard input. It
  explicitly prohibited `focus()`, `click()`, synthetic DOM events, and direct
  value assignment in the acceptance path.
- MoonCode semantic discovery incorrectly resolved paths relative to
  `ui/rabbita-desk` twice, producing paths such as
  `ui/rabbita-desk/ui/rabbita-desk/main/...`. The semantic calls failed before
  supplying useful ownership evidence.
- The planner recovered with direct reads and made partial accessible-name
  edits, but stopped before the browser harness, typed verification, tests, or
  `finish`. The hardened runtime rejected the turn. Independent recovery kept
  the intended field hooks and accessible names and completed the bounded
  slice.

### Independent recovery, discovered UI behavior, and evidence

- The create-book name and optional-folder fields now have explicit accessible
  names. Inbox title and body have explicit accessible names plus stable
  `wiki-inbox-title` and `wiki-inbox-body` hooks. Focused render contracts cover
  all four fields and both primary submit actions.
- The quickstart begins with the browser's natural document focus. It reaches
  each target only through real `Input.dispatchKeyEvent` Tab/Shift+Tab events,
  types only after keyboard focus through `Input.insertText`, and activates
  Create, Pages, New note, and Save through real Space or Enter events. Every
  traversed target must remain connected, visible, and enabled; a repeated
  focus identity fails the run as a cycle.
- The first run exposed behavior hidden by the former direct-value helper:
  entering the book name automatically populated the optional folder field.
  Plain insertion therefore appended and failed. The final path uses a real
  CDP Select All command carried by Meta+A, verifies the selected range, sends
  Backspace, and only then inserts replacement text.
- The passing run wrote `quickstart-keyboard-focus-proof.json`. It records a
  1440×900 journey with 73 ordered focus/input/activation entries, including
  the visible enabled targets for book name, folder, Create MoonBook, Pages,
  New note, Inbox title/body, and Save note. The resulting Markdown bytes were
  `# Durable quickstart note` followed by
  `Saved through the visible Pages UI.`
- The same run retained the existing hard-reload and host-restart assertions
  and passed the complete clean-workspace quickstart. A fresh release-mode UI
  supplied the rendered application under test.
- Running `moon test` against individual whitebox filenames from the repository
  root reported zero tests because those files belong to the nested UI module.
  Re-running at `ui/rabbita-desk` exercised the real suite: 375/375 passed.
  Canonical fast validation passes 230/230 native and 375/375 UI tests;
  localization passes 3/3; `node --check`, `moon info`, `moon fmt`, and
  `git diff --check` pass.
- This closes the browser-host, configured-empty-library keyboard path through
  the first durable task at 1440×900. It does not prove the one-book/many-book
  keyboard matrix, every responsive-state focus order, screen-reader
  announcements, or packaged native keyboard behavior. Command 038 separately
  closes the bounded populated-Home text-only case.

## Command 038 — text-only 200% large-text acceptance

### Phase A — bounded command and acceptance contract

- The command was limited to the existing populated browser smoke, release-mode
  temporary output, the Home shell styles needed by observed failures, and
  documentation. It did not authorize broad visual redesign or tracked
  distribution output.
- This path is intentionally separate from Command 036. Browser zoom keeps the
  application type scale unchanged and exposes a smaller CSS viewport.
  Command 038 instead keeps exact 1440×900 and 320×700 CSS viewports and device
  scale while doubling rendered text.
- Acceptance requires snapshotting all computed font sizes before any mutation,
  applying exactly 2× font sizes to every rendered HTML element, restoring
  every original inline value, and rejecting a second active scale. It also
  requires exact viewport dimensions, document width equal to viewport width,
  no pane overlap, the correct desktop/compact primary navigation, and visible,
  unclipped headings, selected book, current path, Back/Forward controls,
  Refresh, Up, and Home.

### Phase B — MoonCode result and runtime/projection defects

- MoonCode accepted one bounded command and inspected the named browser helper
  and shell styles. It made only a partial edit to
  `scripts/desk_mode_browser_smoke.mjs`; it did not build the UI, run the
  browser path, inspect screenshots, provide typed verification, or finish.
  The terminal result was failed.
- During the turn, the projected status briefly reported `done` while the
  canonical work record still reported `running`; the projection later changed
  to failed. A consumer must therefore continue to treat canonical work state
  and terminal evidence as authoritative instead of trusting the transient
  planner projection.
- The generated helper mutated each ancestor before reading descendant computed
  sizes. Inherited descendants could therefore be scaled from already doubled
  parents and reach 4×. Independent recovery changed the algorithm to snapshot
  every element first and mutate only after the snapshot is complete.
- The partial geometry collector used selectors that do not exist for the
  selected book, path, panes, and navigation. Recovery replaced them with the
  actual Home contracts: active `desk-workspace-row`, `desk-browser-head h2`,
  `desk-sidebar`/`desk-browser`/`desk-details`, compact
  `primary-nav-summary`, and desktop `mode-*` controls.

### Phase C — rendered failure recovery

- The first real 1440×900 run exposed library diagnostics and service rows
  exceeding the sidebar. Their grid containers had implicit `auto` tracks, so
  long paths and status text established tracks wider than the containing
  pane. Explicit `minmax(0, 1fr)` tracks, zero minimums, bounded widths, and
  ordinary text wrapping repaired the desktop failure without hiding content
  or reducing the requested type scale.
- The first 320×700 run reported a 320px root with a 446px document. Deeper
  diagnostics ruled out the responsive file table and identified several
  contributing non-wrapping groups: navigation controls, New/Import/View
  disclosure content, density controls, sidebar headings, and inspector
  actions. These now wrap into bounded rows; the narrow navigation uses a
  deterministic two-column layout.
- The decisive containment trace showed that `.desk-shell` itself was 320px
  wide but its implicit grid column was 446.484px, and the flex-stacked
  `.file-desk-main` inherited that track. Giving both containers explicit
  zero-minimum, full-width containment and
  `grid-template-columns: minmax(0, 1fr)` removed the document expansion.
- Text-only narrow evidence uses a reset, non-mobile 320×700 CSS viewport.
  Existing 390×844 and 320×700 captures continue to exercise Chrome device
  emulation; the text-only path avoids conflating font enlargement with a
  retained synthetic mobile page scale.
- Visual PNG inspection found two defects not caught by the first geometry
  contract: Forward collided with Up at narrow width, and long inspector
  actions were truncated on desktop. The final two-column navigation and
  wrapping inspector buttons fixed both, and Back/Forward were added to the
  proof target set.
- Visual inspection also found that the globally fixed language selector
  collided with enlarged workspace identity and Commands controls. Moving it
  to a floating corner merely obscured inspector content. The durable fix adds
  a real `language-preference-host` to the title bar, has the localization
  runtime relocate the selector into that host after Rabbita mounts, and uses a
  two-row desktop header: destinations first, then identity, language, and
  Commands. The compact narrow header remains a single destination control.
  The selector survived the complete mutation-heavy browser journey and
  ordinary 1440×900 rendering was visually checked.

### Phase D — retained evidence and regression closeout

- The passing proof file is
  `desk-text-only-200-geometry-proof.json` with kind
  `text-only-large-text`. Both cases scaled and restored 401 elements with
  device pixel ratio 1.
- The desktop case records viewport and document width 1440, seven visible
  desktop destinations, three panes, one selected book, one current heading,
  three primary folder actions, two history actions, and no overflow or
  clipping. The narrow case records viewport and document width 320, one
  compact destination control, the same pane/selection/action contracts, and
  no overflow or clipping.
- Retained screenshot names are
  `desk-text-only-200-desktop-1440x900.png` and
  `desk-text-only-200-narrow-320x700.png`. Both were inspected at original
  resolution after the final build. The same release output passed the full
  populated smoke, the empty-library smoke, and the clean-workspace quickstart
  including host restart.
- Canonical validation passes 230/230 native and 375/375 UI tests with strict
  format/check gates. Localization passes 3/3. `moon info`, `moon fmt`,
  JavaScript syntax checks, structured proof assertions, and
  `git diff --check` pass. The generated `.mbti` contract did not change.
- This closes only the populated Home text-only large-text slice at two exact
  viewports. It does not close the one/many-book state matrix, complete
  responsive focus order, screen-reader announcements, packaged native
  keyboard behavior, non-macOS picker proof, or Phase 1/Phase 7 as a whole.
  Command 039 subsequently closes the bounded one/many-book selection subset,
  not those broader gates.

## Command 039 — one/many-book keyboard-selection matrix

### Phase A — full-plan command and acceptance contract

- One native MoonCode turn received the complete authoritative productization
  plan and execution/defect log before the bounded next gate. The requested
  slice was one-book and many-book MoonBook selection at exactly 1440×900,
  1024×768, 390×844, and 320×700, without broad restructuring or tracked
  distribution output.
- Source inspection reproduced a product accessibility defect before mutation:
  MoonBook choices were native buttons, but selection was communicated only by
  the `active` CSS class. No semantic selected/toggle state existed, and the
  rows had no dedicated focus-visible rule.
- Acceptance required real CDP Tab/Shift+Tab from natural document focus,
  alternating Space/Enter activation, forward and reverse row-order proof,
  visible focus, focus retention, exactly one semantic and visual selection,
  agreement with URL/identity/Home content, correct desktop/compact
  navigation, bounded geometry, eight PNGs, and one merged structured proof.

### Phase B — MoonCode terminal result and defects

- MoonCode successfully read both complete documents with two bounded `read`
  calls. It then invoked `moon_ide find_references` with an empty required path;
  the semantic tool exited 1. Its fallback shell search found the actual
  `desk-workspace-row` source and `product-shell.css` styles.
- Despite that evidence, its first edit targeted `moondesk-ux.css` and searched
  for `.desk-workspace-row.active`, which exists in `product-shell.css`; the
  edit failed. Its next edit searched the same wrong file for a bare newline,
  which matched 461 locations and was rejected as ambiguous.
- Planner step 5 called `finish` after zero accepted mutations and no typed
  verification. The runtime completion verdict correctly rejected the finish:
  canonical terminal status is `runtime-failed`. This is an important positive
  runtime property even though the implementation attempt failed.
- **Recovery:** provide a real semantic path, follow the owning stylesheet
  reported by search, use exact surrounding edit context, reserve planner
  capacity for the MoonBit view/test and browser proof, and never treat a
  `finish` tool result as command completion without the runtime verdict.

### Phase C — independent product and proof recovery

- `render_desk_workspace_sidebar` now computes one `selected` predicate and
  uses it for both the `active` class and `aria-pressed`. A focused render test
  proves one true and one false state across two named rows, and a three-pixel
  focus outline plus contrasting outer edge gives the buttons a persistent
  keyboard cue.
- The browser harness now records workspace identity, viewport intersection,
  `:focus-visible`, computed outline/shadow, and target geometry for every
  focus step. Reusable matrix logic reloads each exact viewport from natural
  body focus, verifies row DOM/visual order, traverses to the target without a
  cycle, activates by keyboard, proves retained focus, Shift+Tab reverse
  traversal, and Tab return, then verifies the complete product-state
  agreement.
- The clean-workspace fixture supplies the one-book cases after the durable
  first-use task. The populated fixture supplies four initial rows and changes
  from Research Alpha to the ready Research Beta row in every many-book case.
  Both journeys restore the state and viewport expected by their pre-existing
  checks.
- The first combined run passed the many-book matrix and full smoke, and
  generated the one-book proof, but the quickstart continuation timed out
  because the harness tried to reconstruct a transient post-save preview from
  an Inbox URL that intentionally lacked a selected note path. Recovery
  restored the durable selected Home state instead; the existing Pages
  navigation, hard reload, and host restart then remained authoritative.

### Phase D — retained evidence and regression closeout

- `desk-workspace-keyboard-matrix-proof.json` has kind
  `moondesk-workspace-keyboard-matrix-proof.v1` and exactly eight cases: four
  `one` and four `many`, one at each required viewport. Every case records one
  selected/active row, selection/URL agreement, zero pane overlaps, no
  document overflow, the expected navigation form, a retained focus indicator,
  activation key, reverse traversal, trace, and screenshot.
- The retained PNG names are
  `desk-keyboard-{one,many}-{1440x900,1024x768,390x844,320x700}.png`. All eight
  were inspected at original resolution. The focused row has a clear double
  edge; selected identity and Home content agree; no clipping or overlap was
  observed. Narrow captures intentionally show the browser-scrolled focused
  row rather than pretending the top navigation remains in the viewport.
- The same exact release output passes the complete populated smoke and
  clean-workspace quickstart through durable note bytes, hard reload, Code
  conversation, host restart, and restored content. Canonical validation
  passes 230/230 native, 376/376 UI, and 3/3 localization tests with zero
  warnings; syntax, generated-interface, formatting, and whitespace gates
  pass.
- This closes the bounded one/many-book Home selection matrix at four
  viewports. It does not close no-library/empty-library at every viewport,
  complete page-level focus order, screen-reader announcements, every
  data/capability state, packaged native keyboard behavior, non-macOS picker
  proof, Phase 1, or Phase 7.

## Command 040 — shared-shell landmarks and live announcements

### Phase A — bounded command and acceptance contract

- One native MoonCode turn received both complete authoritative documents
  before being asked for the next bounded accessibility slice.
- The requested product contract was: a visible-on-focus native skip link;
  exactly one named `main` landmark per destination; named desktop and compact
  navigation; one selected predicate shared by active styling,
  `aria-pressed`, and `aria-current`; a factual destination announcement; and
  polite/atomic announcements for the eight typed state surfaces.
- Acceptance required focused MoonBit render tests plus a CDP
  accessibility-tree proof at exactly 1440×900, 1024×768, 390×844, and
  320×700. The browser path had to use real Tab/Shift+Tab and Enter/Space,
  cover all seven primary routes in desktop and narrow navigation, prove one
  deterministic typed-state transition, retain structured evidence and PNGs,
  and keep manual screen-reader claims explicitly out of scope.

### Phase B — MoonCode terminal result and runtime defects

- MoonCode read both full documents and inspected the shell, but repeated the
  semantic-tool defect from Command 039 by calling `find_references` with an
  empty required path.
- Its CSS edit then searched for a bare `@media` token. After ambiguity was
  reported, it used replace-all and inserted the skip-link block before all
  nine media queries. A subsequent step removed all nine copies, restoring a
  net-zero repository state.
- MoonCode called `finish` at planner step 6. Its own terminal answer correctly
  said the requested implementation and verification were incomplete and that
  no intentional change remained.
- The runtime nevertheless emitted `runtime-completed` because it counted
  accepted transient edits even though they cancelled to net zero and the
  finish answer explicitly denied completion. This is a completion-gate defect:
  accepted-mutation history cannot substitute for net deliverables, typed
  verification, and the model’s terminal completion claim.
- **Recovery:** require concrete semantic paths, reject broad replace-all for
  repeated structural tokens, compare net repository state at completion, and
  make the runtime verdict conjunctive over requested deliverables, required
  verification, and an affirmative terminal claim.

### Phase C — independent product recovery

- Added one shared helper for main-landmark attributes, the native skip link,
  factual destination status, and isolated polite/atomic state announcements.
  Every destination branch now has exactly one canonical main root. Three
  nested `main` elements in Code, Pages preview, and Pages bootstrap were
  corrected to sections.
- Desktop and compact navigation now expose named navigation landmarks. One
  `selected` predicate drives class, `aria-pressed`, and `aria-current`.
  Focused tests cover all nine destination modes and the duplicated responsive
  navigation contract.
- Home/Desk file listing, selected preview, Pages search, Review, Requests,
  Runs, Publish, and Code session state rendering now use the shared
  announcement contract. Only plain-language title/detail enters the live
  node; retry/setup actions and raw technical diagnostics remain separately
  rendered.
- CSS supplies one off-screen utility and a fixed skip link whose focus-visible
  treatment has a three-pixel accent outline, contrasting border, and outer
  edge. The link remains inside every tested viewport.

### Phase D — proof-harness defects and visual recovery

- The first browser attempt selected the main element through a shared test ID
  that destination-specific test IDs overwrote. The proof now binds the
  canonical landmark by unique ID, while product test IDs retain their owners.
- CDP represented `pressed` as the string `"true"` rather than a JavaScript
  boolean in this Chrome build. The assertion now accepts both protocol forms
  without weakening the required true state.
- The first live-state attempt dispatched an input event and clicked in the
  same evaluation turn, before the reactive model rendered the update; it
  waited indefinitely for an interception that never arrived. The recovered
  seam opens Search through the product command palette, focuses the real
  input, uses CDP `Input.insertText`, waits two render frames, and bounds request
  interception at 15 seconds.
- The deliberately failed request produces one expected Chrome
  `net::ERR_FAILED` log. The harness consumes exactly that matching diagnostic
  and leaves every unrelated console/runtime problem fatal.
- Original-resolution screenshot review then found two product defects outside
  the semantic assertions: the new announcement visibly duplicated the state
  copy, and Runs/Publish inherited the Home three-column grid and squeezed the
  destination card into one narrow track. The live node is now visually hidden,
  and the dedicated primary-destination shell uses block layout.

### Phase E — retained evidence and boundary

- `desk-shared-shell-accessibility-proof.json` has kind
  `moondesk-shared-shell-accessibility-proof.v1`: four skip cases, two
  destination groups, 14 route cases, and three typed state transitions.
- Retained screenshots are
  `desk-accessibility-skip-{1440x900,1024x768,390x844,320x700}.png` and
  `desk-accessibility-destinations-{1440x900,390x844}.png`. All six were
  inspected at original resolution after the visual fixes.
- Focused shell tests pass 3/3, focused navigation tests pass 6/6, and the UI
  suite passes 379/379. `scripts/validate.sh fast` passes 230/230 native and
  379/379 UI tests with zero warnings, and localization passes 3/3. The same
  exact release output passes the shared-shell accessibility proof, complete
  populated browser smoke, and clean-workspace quickstart through durable note
  bytes, hard reload, Code conversation, host restart, and restored content.
- This closes the bounded shared-shell semantic and browser-interaction slice.
  It does not prove real spoken announcements or timing in VoiceOver/NVDA,
  complete page-level focus order, every responsive/data/capability state,
  reduced motion, packaged native keyboard behavior, non-macOS picker
  behavior, Phase 1, or Phase 7.

## Command 041 — reproducible unsigned-preview release

### Phase A — gate selection and command contract

- The Phase 2 audit found that local `.github/workflows/ci.yml` invokes the full
  validator, but the remote default branch has only an older setup-workflow run.
  No current pull-request, push, or release evidence exists remotely, and no
  push or publication was authorized.
- The next locally actionable slice was therefore the unsigned-preview
  pipeline around the existing release implementation: terminal prerequisite
  failures, portable public metadata, immutable fresh output, exact artifact
  verification, a tag/manual workflow, changelog policy, and release-process
  documentation.
- One MoonCode turn received both complete authoritative documents. It was
  forbidden from staging, committing, pushing, publishing, weakening
  validation, or claiming remote evidence.

### Phase B — MoonCode terminal result and repeated runtime defect

- MoonCode read both complete documents, ran `moon ide outline` with the real
  `cmd/main` path, and performed one broad read-only release inventory.
- It wrote only `scripts/verify_release.mjs`, then called `finish` at planner
  step 4. Its terminal answer correctly said Command 041 was incomplete, no
  validation had run, and the release command, wrapper, workflow, fixtures,
  validation integration, and documentation were all missing.
- The runtime again emitted `runtime-completed` because one accepted mutation
  existed, despite the explicit incomplete terminal claim and the absence of
  requested typed verification. Command 041 independently reproduces the
  Command 040 completion-gate defect without relying on a net-zero edit:
  mutation presence is still being treated as deliverable completion.
- The written verifier was not usable as acceptance evidence. It imported an
  unused directory API, recursively recognized only nested `{path, sha256}`
  declarations even though the current release manifest used flat path/hash
  fields, used locale-sensitive checksum ordering, had no fixtures, and had
  never been parsed or run.
- **Recovery:** completion must be conjunctive over the requested deliverable
  inventory, an affirmative terminal claim, net mutations, and successful
  post-mutation checks. Inspection-budget exhaustion is a failed bounded turn,
  not a completed command.

### Phase C — release-command recovery

- `run_bundle` and `run_release` now return success explicitly. The CLI exits
  nonzero when either returns false. Integration, rename, required signing,
  archive, app, requested DMG, runtime manifest, digest, requested
  notarization/stapling, and metadata-write failures are terminal; completion
  is printed only after every required artifact exists.
- Release mode resolves and inspects its output before invoking the bundle. A
  nonempty root is rejected, preventing direct command reruns from deleting or
  replacing an existing release. The canonical wrapper is stricter and rejects
  any existing output path, even when empty.
- `release-manifest.json` and `updates.json` now use versioned kinds and only
  safe release-root-relative artifact/note paths. Workspace, UI, dependency,
  temporary, runner, user-home, signing-identity, and keychain-profile values
  are absent. Credential use is represented only by a boolean.
- A focused pure prerequisite classifier covers app, zip, runtime manifest,
  DMG, signing, notarization, and exact lowercase SHA-256 requirements. The
  focused release suite passes 4/4.

### Phase D — verifier, wrapper, and workflow recovery

- The recovered Node verifier has stable exits: 64 usage, 65 malformed
  metadata, 66 unsafe/inconsistent contract, 67 missing evidence, 68
  digest/checksum drift, and 69 immutable-output refusal.
- It validates versioned schemas, path portability, lexical confinement,
  realpath/symlink confinement, version/channel agreement, exact artifact-kind
  sets, flat/nested manifest agreement, signing/notarization/installer
  consistency, file existence, recomputed hashes, release notes, and exact
  bytewise-sorted checksum coverage. Checksum generation is a one-time atomic
  mode and refuses overwrite.
- Eight fixtures cover a twice-read valid release, repeated checksum generation,
  hash mismatch, absolute path, parent traversal, missing artifact,
  inconsistent notarization, and extra checksum data. The first fixture run
  found that a deliberately appended extra entry was unsorted before reaching
  the intended assertion; the fixture was corrected to remain sorted and prove
  the exact extra-entry rejection.
- The first real preview proof found a cross-platform determinism defect:
  checksum ordering used `localeCompare`, so two runner locales could disagree.
  The generator and verifier now use bytewise ordering; the final candidate is
  rebuilt after that mutation.
- `scripts/preview_release.sh` validates explicit inputs, requires macOS and a
  fresh absolute output, creates only task-specific temporary workspace/UI
  roots, performs a production UI build, invokes the existing release command,
  copies immutable notes, writes checksums once, and verifies twice. Supplying
  only one credential input is rejected.
- `.github/workflows/preview-release.yml` uses `macos-14`, read-only contents,
  per-ref cancellation, Node 22, `npm ci`, full validation, the canonical
  wrapper, independent final verification, and a unique version-plus-commit
  artifact with overwrite disabled. It never creates or replaces a hosted
  release.

### Phase E — policy, evidence, and remaining boundary

- `CHANGELOG.md` now has an `Unreleased` section, immutable links to existing
  preview notes, and a clearly unpublished preview-4 candidate.
  `docs/RELEASE_PROCESS.md` records version/tag policy, exact commands,
  artifacts, verifier exits, immutability, partial-output recovery, workflow,
  unsigned boundary, credential boundary, and remote evidence still required.
- One fresh macOS arm64 preview candidate contains the app, zip, DMG, packaged
  runtime manifest, two portable JSON manifests, release notes, and six exact
  checksum entries. It verifies twice without mutation. A second wrapper call
  is rejected before rebuilding with exit 69; the direct release command also
  rejects the populated root.
- The retained proof in
  [`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md)
  records 231/231 native, 379/379 UI, 3/3 localization, 4/4 focused release,
  and 8/8 verifier results; zero warnings; the exact candidate sizes and six
  hashes; two further read-only verification passes; byte-for-byte unchanged
  refusal checks; and the dirty-worktree/full-validator boundary.
- This closes the local reproducible unsigned-preview implementation slice. It
  does not close Phase 2: the local workflows are not present on the remote
  default branch, and no clean pull-request, push, version-tag, hosted artifact,
  independent remote reproduction, signing, notarization, clean-machine
  install/update/rollback, or production release evidence is claimed.

## Command 042 — Home capability copy boundary

### Phase A — reproduced product contradiction

- The Phase 1 first-use contract required ordinary setup copy to avoid internal
  architecture and raw diagnostics. Home nevertheless always rendered its
  capability card with service and authority names, a raw daemon message,
  platform evidence, and managed-process details ahead of the user task.
- Code already used the shared six-state classifier, but its installation
  progress helper could still expose raw installer feedback outside a
  disclosure. The resulting Home and Code explanations could disagree even
  though both represented the same capability.
- One bounded MoonCode turn received the complete project instructions,
  authoritative productization plan, and execution log. It was asked only to
  repair this copy boundary, cover all six states, prove ordinary and technical
  markup independently, document the result, and finish only after typed UI
  verification.

### Phase B — MoonCode result and improved terminal honesty

- MoonCode read all three required documents. Four semantic-outline attempts
  then failed because its path wrapper first duplicated the nested UI prefix
  and subsequently resolved package-relative paths from the repository root.
- Direct file reads succeeded. MoonCode changed the Home call site and inserted
  an incomplete renderer that referenced undefined helpers. Its immediate
  `moon_check` failed. It restored the call site, removed the incomplete
  renderer, and ended with no intended product change, test, or documentation.
- The final compile was green only because the incomplete change had been
  removed. Unlike Commands 040 and 041, the hardened completion verdict
  correctly emitted `runtime-failed`: transient edits plus a late green check
  no longer counted as a completed deliverable. The planner still spent four of
  eight steps rediscovering the same path-root problem.
- **Recovery:** resolve the semantic root once, read the owning package
  directly when wrapper paths are demonstrably wrong, define a coherent helper
  set before compiling, and require net deliverables plus post-mutation typed
  checks.

### Phase C — independent product recovery

- Home now uses the same six-state capability classifier, stable state key,
  plain-language summary, and action allowlist as Code. Its visible identity is
  `Code assistance`; service ownership is not presented as a user concept.
- Ordinary Home markup is a separate public subtree. It renders only the
  capability title, user-facing detail, permitted action, and generic
  installation progress. Raw installer feedback is no longer rendered in the
  shared public progress helper.
- One closed `Technical details` disclosure preserves exact service, running,
  managed-installation, managed-process, daemon-message, platform, installer,
  and authority evidence. Code reuses the same summary and technical renderer,
  preventing the two setup surfaces from drifting.
- Original-resolution visual inspection found a second copy defect after the
  structural repair: the ready detail said only “Requests can be handled now.”
  All six details were rewritten around starting or continuing Code
  conversations, with Pages and files named as the supported fallback.

### Phase D — focused and rendered evidence

- The focused capability suite passes 14/14. It covers all six Home state keys,
  titles, and action allowlists; independently renders the ordinary subtree;
  proves that internal and raw terms remain absent even during installation;
  and proves that the closed technical subtree retains exact diagnostics.
- The strict UI check passes with zero warnings. `scripts/validate.sh fast`
  passes 231/231 native and 382/382 UI tests, the focused capability suite
  passes 14/14, and localization passes 3/3. A temporary unused-binding warning
  discovered during the repair was resolved by rendering the already-available
  managed-process evidence in the technical disclosure instead of discarding
  it.
- An isolated production UI build and the complete populated browser smoke pass.
  The retained `moondesk-first-use-copy-partial-proof.v1` fixture records the
  `detected-running` state, plain public text, exact technical text, forbidden
  ordinary terms, and a closed disclosure. The corresponding 1440×900
  screenshot was inspected at original resolution.
- This closes the bounded Home capability-card copy boundary. It does not claim
  a complete rendered-literal/localization audit, every transient setup state
  in a browser, packaged-native assistive behavior, or completion of Phase 1.

## Command 043 — Code unavailable-state reachability

### Phase A — reproduced typed-but-unreachable state

- `moonclaw_capability_state(None)` returned `TemporarilyUnavailable`, with
  plain-language copy and the **Check again** action. Documentation therefore
  claimed that Code covered all six capability states.
- The actual Code setup renderer and its center-layout class matched only a
  present daemon record whose `running` field was false. When no status response
  existed—the exact unavailable case—the setup, retry action, state evidence,
  and technical disclosure all disappeared.
- One bounded MoonCode turn received the three complete authoritative documents,
  the exact mismatch, one semantic-root fallback rule, a five-point repair, and
  explicit typed verification gates.

### Phase B — MoonCode result and repeated planner defect

- MoonCode read all three required documents, then ignored the explicit
  package-root instruction and repeated two semantic outlines with repository-
  relative nested UI paths. Both failed with the already documented wrong-root
  wrapper behavior.
- Without directly reading either owning source file, its next tool call asked
  the editor to replace `fn render_mooncode_runtime_setup` with the identical
  text. The editor correctly rejected the no-op. MoonCode then called `finish`
  at planner step 4 with no mutation, test, formatting, interface, or
  documentation work.
- The runtime correctly emitted `runtime-failed`. The stronger completion
  verdict is behaving honestly, but command planning has not learned the
  documented path-root fallback and still spends half its bounded steps without
  reaching product code.
- **Recovery:** after a repeated semantic-wrapper failure, use the already known
  package root and direct reads; reject identical edit intents before tool
  dispatch; reserve steps for one coherent mutation and typed verification.

### Phase C — independent product recovery

- Both the Code setup renderer and `mooncode_center_class` now derive the same
  typed capability state from the optional daemon record. `DetectedRunning`
  alone hides setup and uses the normal layout; every other state renders setup
  and the additional layout row.
- The setup section now publishes stable `mooncode-runtime-setup` and
  `data-state` evidence. It reuses the shared summary, exact typed action
  allowlist, generic installation progress, and closed technical disclosure.
- With no daemon-status response, Code now visibly renders
  `temporarily-unavailable`, the **Check again** action, and a closed disclosure
  containing the exact absence diagnostic. No display string controls state.
  The host DTO, classifier precedence, runtime ownership, and public API are
  unchanged.

### Phase D — focused evidence and remaining boundary

- The capability suite now passes 15/15. The new test renders the actual Code
  setup for all six states, proves running hides both setup and its layout row,
  proves all five non-ready state keys and typed actions are reachable, and
  independently verifies the unavailable summary excludes internal terms while
  the closed technical disclosure retains the absence diagnostic.
- The strict UI JavaScript check passes with zero warnings.
  `scripts/validate.sh fast` passes 231/231 native and 383/383 UI tests; the
  focused capability suite passes 15/15; localization passes 3/3. Root and UI
  `moon info` plus `moon fmt`, JavaScript syntax, and `git diff --check` pass.
  The private renderer/state repair adds no public interface change.
- This closes the typed unavailable-state reachability defect. It does not
  complete the broader rendered-copy/localization audit, browser simulation of
  all five non-ready states, packaged-native assistive behavior, or Phase 1.

## Command 044 — nested-module semantic path repair

### Phase A — reproduce the resolver defect

- Repeated MoonCode turns had established the same failure shape:
  `moon ide outline` received a repository-relative nested-module path while
  its process current directory was already the nested module. The duplicated
  prefix made a valid source file appear absent.
- Existing tests proved only that the nested module current directory was
  inferred. They did not execute the resulting command, so the argument/current
  directory contradiction remained invisible.

### Phase B — repair the owning runtime

- The semantic wrapper now validates that an outline operand remains inside the
  book root, resolves its absolute location once, and rebases it relative to
  the inferred nested-module current directory.
- The checked-error result of the relative-path operation is handled
  explicitly. The change is internal and produces no public generated-interface
  diff.
- A focused fixture now contains a real nested `moon.mod`, package, and source
  file. The test executes the semantic command and asserts its output, inferred
  current directory, and exact rebased argument.

### Phase C — prove the repaired boundary

- The focused process-tool suite passed 7/7 after the resolver repair, and the
  native runtime check completed with zero errors.
- A separate rebuilt daemon, isolated from the already-running development
  daemon, executed the previously failing MoonDesk path successfully. Evidence
  recorded current directory `ui/rabbita-desk`, command
  `moon ide outline --target js main/mooncode_views.mbt`, and a 16 ms successful
  result.
- The existing development daemon and its lock were left untouched. This proof
  closes the nested-module path defect; it does not qualify every semantic
  command or every module-layout variant.

## Command 045 — Code-assistance localization migration

### Phase A — define the bounded contract

- The rendered six-state ordinary Code-assistance vocabulary had moved beyond
  the authoritative catalogs. The bounded scope was fixed at 26 strings:
  eyebrow, heading, six titles, six details, six status labels, four actions,
  installing label, and generic progress.
- Three dead setup-topology keys were the only authorized removals. Current
  technical diagnostics were explicitly excluded from ordinary copy and
  retained.

### Phase B — MoonCode attempt and runtime findings

- With the repaired semantic wrapper, the first outline call succeeded against
  the real nested UI module.
- MoonCode then ignored the explicit mutation-tool constraint and used a Python
  heredoc through the shell to rewrite both catalogs, a test, and four
  documents. It also invented three literals that did not match the rendered
  contract, so its own weak assertions could not detect the mismatch.
- The cross-book shell boundary correctly rejected an attempt to invoke the
  canonical generator through an unapproved sibling path.
- The runtime emitted `runtime-failed` because it had no accepted mutation
  evidence. That terminal result was honest, but it exposed a second defect:
  shell-authored file changes were real while remaining outside reviewable
  mutation evidence.

### Phase C — harden mutation policy

- The planner contract now states that all authored workspace changes must use
  `edit`, `write`, or `apply_patch`; shell commands and inline interpreter
  scripts are validation tools, not authoring tools.
- The shell boundary now rejects interpreter heredocs and common inline
  interpreter forms for Python, Node.js, Ruby, and Perl before they can mutate
  workspace files.
- Focused tests reproduce the exact Python heredoc plus Python and Node.js
  inline forms, prove no file is created, and assert the planner contract.
  The expanded process-tool suite passes 9/9; the native check has zero errors.

### Phase D — recover the product slice

- The incorrect English and Simplified Chinese literals were replaced with the
  exact rendered contract. A table-driven test covers all 26 strings, requires
  every Simplified Chinese result to differ from English, and asserts all three
  dead English strings are absent.
- Running the canonical generator exposed a third defect: generator source had
  drifted behind its checked-in output and removed exact-only accessibility
  translation plus the locale-specific system-language label.
- Those behaviors were restored in the generator source and the public catalog
  was regenerated. Generated JavaScript syntax and all 4/4 localization tests
  pass, including dynamic templates, exact accessibility attributes, the
  single-language system option, and the new capability vocabulary.

### Phase E — remaining gate

- Byte-for-byte regeneration passes. `scripts/validate.sh fast` passes 231/231
  native and 383/383 UI tests; the focused capability suite passes 15/15; and
  localization passes 4/4. Root and nested-UI `moon info` plus `moon fmt`,
  generated JavaScript syntax, browser-smoke syntax, the production UI build,
  and whitespace checks across all three touched repositories pass. The build
  retains its visible large-chunk warning; no bundle-size qualification is
  claimed here.
- A complete source/catalog/generated-output inventory, every rendered literal,
  transient browser states, manual assistive output, and packaged-native locale
  behavior remain open. Command 045 is a bounded Phase 1 migration, not Phase 1
  completion.

## Command 046 — explicit localization keys at source

### Phase A — reproduce the architectural gap

- Command 045 established authoritative catalog coverage for the 26 ordinary
  Code-assistance strings, but the MoonBit renderers still emitted bare English.
  Browser localization therefore depended on the generated global English-text
  matcher rather than stable keys at the source of UI construction.
- The bounded contract covered the existing eyebrow, heading, six titles, six
  details, six status labels, four actions, installing label, and progress
  sentence. Technical details and raw diagnostics remained deliberately
  outside the ordinary localization contract.

### Phase B — first MoonCode turn and exact-key correction

- MoonCode received the complete current plan, the relevant prior command and
  defect history, exact owning sources, a reviewable-mutation-only constraint,
  and post-mutation check/test/interface/format gates. The repaired nested-module
  semantic outline succeeded.
- It read four documents and four source/test files, then added only title,
  detail, and status key mappings. Six status keys were invented rather than
  taken from the existing catalogs. The turn called `finish` at planner step 4
  while explicitly listing the remaining renderer, action, test, format, and
  validation work.
- The runtime correctly emitted `runtime-failed`: the final mutation had no
  successful typed test. An exact-key steering command was retained and applied
  to the continuation.

### Phase C — continuation and planner-efficiency defects

- The continuation was told not to repeat discovery. It nevertheless ran
  multiple repository searches and read the same complete capability source
  three times without an intervening mutation. It also attempted to read a
  nonexistent `capability_views.mbt`.
- A live “patch now” steer was queued while the turn was active but was not
  consumed at a planner boundary. The turn used all 12 planner steps and 17
  tool calls, correcting the status mapping and adding only the action mapping
  plus two header attributes. It reached neither shared rendering, tests, nor
  `finish`.
- The runtime again emitted `runtime-failed`. The command sequence was four
  client commands—initial prompt, exact-key steer, continuation, and live
  steer—and did not complete the requested slice. This is not yet the
  few-command outcome the program is trying to establish.

### Phase D — independent product recovery

- Exhaustive private mappings now bind every typed capability state and action
  to the exact existing catalog key while preserving all English-returning
  functions and state/action behavior.
- Home and Code use shared title/detail mappings. Every rendered ordinary node
  now carries `data-i18n`: Home eyebrow, heading, and status; both surfaces'
  titles, details, actions, installing labels, and shared progress sentence.
  The technical disclosure contains no `code.assistance_*` key.
- Focused rendered-HTML tests cover all six states, every action, both installing
  branches, progress, unchanged pre-browser English, and diagnostic isolation.
  The focused capability suite passes 16/16.
- The JavaScript localization suite now compares complete English and
  Simplified Chinese key sets, extracts all `code.assistance_*` keys from the
  three owning MoonBit sources, requires exact equality with the catalog slice,
  and proves the generated runtime resolves every key to non-English Simplified
  Chinese. Localization passes 5/5.

### Phase E — MoonCode runtime recovery

- The bounded model runtime now rejects an identical complete `read` when no
  accepted authored mutation has invalidated that result. A truncated read may
  be retried, and a mutation permits the path to be read again.
- Focused tests cover same-path rejection, different-path allowance, truncated
  retries, mutation invalidation, and a later duplicate. The runtime-turn suite
  passes 31/31; the process-tool suite remains 9/9; native checking has zero
  errors. `moon info` reports no public runtime interface change.

### Phase F — independent closeout

- `scripts/validate.sh fast` passes 231/231 native and 384/384 UI tests with
  zero UI warnings. The focused capability suite passes 16/16, localization
  passes 5/5, generated and browser-smoke JavaScript syntax checks pass, and
  canonical localization regeneration is byte-for-byte reproducible.
- Root, nested-UI, and runtime `moon info` plus `moon fmt` complete. The new
  product and runtime helpers remain private; the nested UI interface diff
  still contains unrelated public SourcePane work already present in the
  working tree. Whitespace checks pass across all three touched repositories.
- The production UI build passes and retains its existing large-chunk warning;
  no bundle-size qualification is claimed. The preexisting daemon remained
  untouched on its original port. The isolated rebuilt daemon and temporary
  request files were removed after audit, while the complete 136-event Command
  046 journal remains retained.

### Phase G — remaining boundary

- This closes explicit-key ownership for one complete 26-string vertical slice.
  Other primary surfaces still use the global fallback matcher and require the
  full source/catalog/generated-output/rendered-state audit.
- Planner enforcement still does not prevent semantically redundant searches,
  guarantee live steering at a model-planner boundary, or reserve the final
  step for typed verification and `finish`. Those remain runtime work rather
  than product-completion evidence.

## Command 047 — live steering, terminal budget, and full-plan trial

### Phase A — one-command self-repair trial

- One MoonCode prompt received the complete 70,115-byte productization plan,
  the reproduced live-steering defect, a 20-step budget, and an acceptance
  contract requiring planner-boundary steering, a reserved terminal step,
  typed tests, and reviewable mutation tools.
- The turn used only four planner steps. It read `AGENTS.md`, obtained one
  semantic outline, issued two malformed `find_references` calls, inserted only
  a comment describing behavior that did not exist, and called `finish`.
- The runtime correctly rejected completion because the final mutation had no
  subsequent successful typed test. The comment was removed independently.
  The retained journal is a failed one-command result, not product evidence.

### Phase B — first runtime recovery

- Runtime control now selects pending `deliver-steer` decisions for the active
  command in journal order. Claiming a steer appends one terminal
  `moonclaw-native-runtime-live-steer` receipt as the idempotency boundary, then
  records a live `steer_applied` event with its active target and text.
- Each claimed live steer becomes an explicit user message before the next
  planner request. The compact and full runtime results expose
  `applied_live_steering`, while the terminal receipt prevents the command from
  being claimed or deferred again.
- The last two planner opportunities are now explicit completion boundaries.
  The penultimate message stops discovery and requests repair plus typed
  verification. The final batch must include `finish` and may use only mutation
  recovery or structured check/test/build/info/fmt tools. A finish-free,
  exploratory, shell, or semantic-navigation final plan fails before execution.

### Phase C — first concurrent proof and follow-up race

- The first rebuilt concurrent proof queued a steer while the prompt was
  active. Control projection showed `deliver-steer`, but the steer arrived while
  a follow-up model request was already in flight. The stale returned `finish`
  plan executed, the acknowledgment was absent, and the steer remained
  claimable.
- Polling only before the model call was therefore insufficient. Follow-up
  planning now rechecks the authoritative journal immediately after inference.
  Steering that arrived during inference is terminally claimed, injected as
  explicit user context, and the not-yet-executed stale plan is discarded.
  Stabilization is bounded to eight replans and fails closed if steering never
  quiesces.
- A repeated proof then applied one steer, emitted one receipt and one event,
  produced the exact acknowledgment, left two delivered and zero claimable
  commands, and recorded no deferred steer. This still exposed an earlier
  boundary: the initial read batch had executed before the follow-up correction.

### Phase D — initial-plan race and strict proof

- Initial model planning now uses the same post-inference control check. A steer
  arriving after `runtime-claimed` but before initial plan selection invalidates
  that not-yet-executed plan and triggers a fresh request containing the steer
  as an explicit user message. Initial stabilization has the same bounded,
  fail-closed limit.
- In the strict proof, the steer command was journal sequence 6, its terminal
  receipt and `steer_applied` event were sequences 8 and 9, and the replacement
  planner selection was sequence 11. Zero reads executed; the only tool was
  `finish`, its answer contained the exact acknowledgment, both commands were
  delivered, and there was no deferred work.
- A separate one-step adversarial prompt requested `read` and prohibited
  `finish`. The initial terminal-budget message prevailed: the selected batch
  contained only `finish`, so no exploratory tool ran. Pure enforcement tests
  also prove that a final read-only or shell batch is rejected before execution.

### Phase E — semantic wrapper and output-cap audit

- The failed self-repair supplied `path` and numeric `line:column` separately,
  while the wrapper passed only `--loc line:column`. The CLI interpreted the
  line number as a filename and failed under the book root.
- The wrapper now combines a numeric two-part location with the resolved
  MoonBook-relative path while preserving an already-qualified location.
  Focused tests cover both forms and the no-path fallback. A rebuilt native
  proof executed
  `find-references --loc cmd/daemon/mooncode_runtime_model_planner.mbt:230:4`
  and returned all five references with status 0.
- An earlier transcript also appeared to exceed its requested read cap. Exact
  explicit probes at 100 and 20,000 characters both truncated correctly and
  reported the full source length plus `truncated=true`; the anomaly was not
  reproduced, so no speculative read-path change was made.

### Phase F — second complete-plan command

- A second isolated MoonCode command received the complete current plan in a
  70,878-character prompt and a 20-step budget. Runtime mechanics improved: it
  completed in six planner steps, recovered after failed semantic and edit
  calls, ran `moon test --target native mooncode/core` with 15/15 passing, called
  `finish`, and earned an accepted completion verdict with mutation plus
  subsequent typed-test evidence.
- Its chosen “repair,” however, was only a two-line API comment, and that comment
  falsely claimed alias normalization that the function did not perform. This
  was not counted as product progress; the trial-only comment was removed.
- The failed first edit did reveal the substantive defect: the runtime contract
  advertises package-style aliases as accepted, but several aliases were not
  canonicalized and `runtime_tool_is_supported` checked exact names only.

### Phase G — substantive recovery and closeout

- Canonicalization now covers every advertised alias, including `Read`, `Edit`,
  `Write`, `Glob`, and `Grep`, and supported-tool detection operates on the
  canonical name. Table-driven tests require every alias row to canonicalize to
  its declared tool, require every advertised source mapping to resolve exactly,
  and keep unsupported names rejected. The focused core suite passes 15/15.
- The daemon package passes 159/159 native tests. Focused evidence includes
  runtime-turn 34/34, runtime-control 4/4, process tools 10/10, and capabilities
  2/2. Native `moon check` and `moon info` complete with zero errors;
  `cmd/daemon/pkg.generated.mbti` has no public diff; formatting and whitespace
  checks pass.
- This command closes live steering at both initial and follow-up inference
  boundaries, terminal-step reservation, semantic location normalization, and
  the advertised alias contract. It does not establish that one autonomous
  command can prioritize and repair the complete product plan: the second trial
  proved better execution discipline but still selected a cosmetic change until
  independent audit recovered the real defect.

## Command 048 — substantive-mutation enforcement and correctly rooted plan trial

### Phase A — reject cosmetic implementation edits before disk

- The preceding complete-plan trial exposed a general contract defect:
  implementation prompts could satisfy mutation accounting with a comment-only
  or documentation-only edit, even when the comment described behavior that did
  not exist.
- Runtime preflight now classifies `edit`, `apply_patch`, and `revert_patch`
  changes for verification-sensitive commands. If every changed line is blank
  or a comment, execution fails before the file tool runs with
  `comment_only_repair=true`. Documentation requests remain allowed to edit
  comments, and substantive implementation edits continue normally.
- The model-planner system contract now states the same rule explicitly:
  implementation and defect-repair work must change behavior, configuration,
  tests, or another substantive contract. Focused coverage reproduces the exact
  false-comment insertion, accepts a real canonical-name change, rejects a
  comment-only unified diff, and preserves documentation-only behavior.

### Phase B — native no-write proof

- A rebuilt isolated daemon received an explicit implementation command whose
  first edit was the reproduced two-line comment insertion. Runtime rejected the
  edit, did not execute the following `finish`, returned
  `comment_only_repair=true`, and settled the command as `runtime-failed`.
- SHA-256 of `mooncode/core/runtime_tools.mbt` was
  `3c1cc7a81117740c32537caac70ac7e788e6917d5cbbf9ecd0ab99a8ca35909a`
  both before and after the turn. This is native proof that the guard runs
  before disk mutation, not merely a later cleanup assertion.

### Phase C — authoritative-plan and repository-boundary audit

- The current plan was reread by phase, dependency, exit gate, and Immediate
  Next Action. Phase 0 is locally evidenced; remote release proof, other desktop
  platforms, the complete accessibility matrix, the host/UI dependency graph,
  and symlink-aware path specification remain open.
- The next local implementation lane remains Immediate Next Action 3: extend the
  typed surface-state contract beyond its eight named consumers and add explicit
  unsupported/misconfigured capability evidence.
- Earlier trials had supplied the desktop plan while binding MoonCode to the
  runtime repository. That made correct product prioritization impossible and
  explains attempts to inspect paths that did not exist under the selected
  root. This trial bound MoonCode to the actual selected MoonDesk repository.

### Phase D — one correctly rooted complete-plan command

- One command received the complete authoritative plan plus the selected local
  typed-surface objective. It was constrained to one complete vertical slice:
  typed ownership, transition/projection use, rendered behavior, focused tests,
  no generated distribution edits, no documentation-only result, and no
  `.moonsuite` mutation.
- Semantic discovery found the shared state module but did not identify a safe
  ninth owning surface within its inspection budget. The planner then inserted
  a speculative generic transport helper, repaired two invalid enum
  constructors, and ran the complete nested UI test package.
- The first test passed 334/334 but reported the new helper as unused. MoonCode
  removed the entire helper, reran the same suite with 334/334 and no warning,
  and truthfully stated in `finish` that it had not completed the requested
  vertical slice. No product source remained changed by the trial.

### Phase E — discovered net-effect completion defect

- Despite the truthful final answer and exact source restoration, runtime
  emitted `runtime-completed`. Its verdict used historical evidence—an accepted
  mutation followed by a passing typed test—but did not prove that any mutation
  survived to the terminal state.
- This is distinct from the cosmetic-edit defect. The edits were substantive
  while present, and the final test was real; the false completion arose because
  edit→repair→revert history was mistaken for a net implementation result.
- The retained 52-record journal provides the complete sequence: three
  speculative edits, one warning-bearing 334/334 test, one full revert, one
  clean 334/334 test, accepted `finish`, and the incorrect terminal receipt.
  The command is recorded as runtime-defect evidence, not product progress, and
  Immediate Next Action 3 remains open.

### Phase F — content-fingerprint completion repair

- Every newly executed `write`, `edit`, single-file patch, selected-hunk patch,
  and multi-file patchset now records content-state fingerprints before and
  after mutation. The state distinguishes an absent path from a present empty
  file and does not expose file content.
- Completion folds those records by path, preserving the first before-state and
  final after-state. Verification-sensitive completion now requires at least one
  path whose terminal fingerprint differs from its starting fingerprint.
  Fully reverted turns fail with: `coding completion has no net mutation; all
  accepted file changes were reverted before finish`.
- Focused tests cover a single-file edit followed by an inverse edit, a retained
  repair, a two-file patchset followed by a complete reverse patchset, and an
  accepted no-op patch with `changed=false`. Backward compatibility is retained
  for already-persisted continuations that predate fingerprint metadata.

### Phase G — native edit/revert/test replay

- A second rebuilt isolated-daemon command explicitly edited
  `runtime_tool_read` from `read` to `read-e2e`, restored it to `read`, ran
  `moon test --target native mooncode/core` successfully, and called `finish`.
  Both edits, the 15/15 typed test, and `finish` were individually accepted.
- The terminal command was nevertheless rejected exactly as intended:
  `runtime-failed`, completion verdict `accepted=false`, and the net-mutation
  reason above. The first edit's after-fingerprint exactly matched the second
  edit's before-fingerprint, and the final fingerprint exactly matched the
  initial fingerprint.
- The source SHA-256 remained
  `3c1cc7a81117740c32537caac70ac7e788e6917d5cbbf9ecd0ab99a8ca35909a`,
  independently proving restoration. The native journal is retained as the
  end-to-end regression artifact.

### Phase H — remaining product boundary

- MoonCode now rejects both comment-only implementation theater before disk and
  fully reverted implementation theater at completion. These are runtime
  correctness improvements, not evidence that the autonomous planner selected
  or completed the next MoonDesk product slice.
- The correctly rooted trial was safer and more honest than the earlier trials:
  it found the relevant package, tested its work, removed an unused abstraction,
  and admitted non-completion. It still exhausted its bounded discovery without
  tracing a ninth surface from owning model through rendered behavior.
- The next product action therefore remains unchanged: select one concrete
  additional surface through an independent ownership audit, give MoonCode that
  bounded target, and count it only after source review, focused transition and
  rendering tests, generated-interface review, and the product validation gate.

### Phase I — validation closeout

- The focused runtime-turn suite passes 38/38. The complete daemon package
  passes 163/163, and the runtime-contract core remains 15/15.
- Native checking completes with 175 preexisting warnings and zero errors.
  `moon info --target native` followed by `moon fmt` produces no public
  `cmd/daemon` or `mooncode/core` interface diff. Whitespace checks pass in the
  desktop, runtime, and shared-library repositories.
- The desktop fast gate passes 231/231 native and 384/384 UI tests. The
  forbidden comparison-name scan remains empty. The isolated rebuilt daemon was
  stopped after evidence capture; the preexisting daemon remains running on its
  original PID and port.

## Command 049 — ninth typed surface and failed-plan recovery

### Phase A — independent ownership selection

- The next product command did not ask the planner to rediscover the whole
  program. An independent semantic/source audit selected Flow’s run listing as
  the ninth bounded consumer of the shared surface-state contract.
- The listing stored transport truth in `moonflow_status`, treated every empty
  filtered array as a legitimate empty response, replaced listing failures with
  a generic host error, had no stale-retention state, and parsed progress copy
  to disable **Ingest latest revision**.
- The complete plan was still attached to the command, but the target contract
  named the owning model, success/failure transitions, selected-book filtering,
  rendering states, diagnostic boundary, ingest busy flag, and focused test
  obligations.

### Phase B — bounded MoonCode attempt

- The correctly rooted model-planned command used all 20 planner steps and 25
  tool calls. It added model fields, initial state, partial success/failure
  transitions, partial state rendering, and an explicit ingest-progress
  boolean.
- Two unlocated semantic queries could not resolve a message constructor or
  record field, after which the planner used bounded source searches and reads.
  Its first typed test used a root-relative path from the nested module and
  correctly failed because that package path did not exist in the nested
  module.
- The corrected test location exposed an invented `Ready` constructor. The
  planner replaced it with another nonexistent constructor, `Loaded`, reran the
  test, and failed again. It never added the required tests, then called
  `finish`.
- Runtime settled the 117-record journal as `runtime-failed` because no
  successful typed test followed the final mutation. The failed turn is
  retained as planner/runtime evidence and was not counted as product progress.

### Phase C — partial-edit audit

- The accepted edits established a useful direction but were not safe to keep
  unchanged. Success filtered the global response down to the selected book,
  destroying other-book evidence; ready state did not follow the established
  `None` convention; selection/refresh did not enter Loading; library switching
  did not reset the new fields; and state rendering duplicated the old empty
  panel.
- Failure retained selected rows but changed the stored global array, while the
  requested raw-error boundary and retry behavior lacked regression proof.
- The ingest boolean itself was sound: `PrepareMoonFlow` set it and both import
  result branches cleared it. The view’s disabled state no longer parsed
  progress copy.

### Phase D — independent forward recovery

- The model now owns `moonflow_runs_state`, private
  `moonflow_runs_error`, and `moonflow_ingest_preparing` separately from
  operation feedback. Initial state and library replacement reset to first use.
  Selecting or refreshing Flow enters Loading and clears the listing error
  while retaining the last global response.
- Successful global responses remain intact. State is derived from runs matching
  the selected book: no selection is first use, an explicit selected-book zero
  is `LegitimateZero`, and matching records are ready through the established
  `None` convention.
- Failed refresh preserves the global response and matching cards. It becomes
  `Stale` only when selected-book records exist; otherwise it becomes
  `RecoverableError`. The listing no longer overwrites generic host status.
  Import, control, and operator-action paths that trigger a refetch explicitly
  enter Loading.

### Phase E — state-owned rendering and tests

- `moonflow_runs_state.mbt` owns keys, record-retention policy, empty-action
  policy, ordinary titles/details, retry availability, and diagnostic
  visibility for all eight shared states.
- Rendering now has one keyed state panel. Loading and stale states keep prior
  run cards visible; first use and recoverable failure do not fall through to a
  false empty panel; explicit zero renders one start-governed-work panel; ready
  renders current and earlier revisions. Raw listing errors occur only inside a
  closed `Technical details` disclosure.
- Three focused white-box tests cover no-selection first use, selected-book
  filtering without global-data loss, loading preservation, explicit zero,
  ready, stale retention, recoverable failure, retry transition, rendered copy,
  raw-error confinement, and ingest busy-state settlement. Semantic navigation
  resolves 30 references for the owning field across initialization, reset,
  transitions, rendering, and tests.

### Phase F — validation and remaining boundary

- The focused new suite passes 3/3; the complete nested UI suite passes 337/337.
  The desktop fast gate passes 231/231 native and 387/387 UI tests with zero UI
  warnings.
- Root and nested `moon info` plus `moon fmt` complete. The interface diff still
  contains the preexisting public SourcePane work and private `SurfaceState`
  exposure already present in the working tree; this slice adds no new public
  function or concrete type. Whitespace and forbidden-name scans pass.
- The production UI build succeeds. It retains the existing large-chunk warning,
  so no bundle-size qualification is claimed. The build regenerated the hashed
  distribution assets from the current source rather than hand-editing them.
- The shared state contract now has nine bounded consumers. This closes the Flow
  run-listing slice only; unsupported/misconfigured capability evidence, other
  eligible surfaces, the complete accessibility/platform matrix, package graph,
  and symlink-aware path specification remain open.

## Command 050 — explicit Requests configuration evidence

### Phase A — evidence audit and defect selection

- Semantic navigation traced the Requests capability from the host lifecycle
  record through `DaemonLifecycleResult`, the six-state classifier, Home status
  projection, and Requests rendering.
- The host already supplied explicit platform and installation evidence, but
  configuration remained inferred in the UI from
  `result.ok && (service_configured || running)`.
- That expression made any failed lifecycle operation appear
  `Misconfigured`, even when the service was installed and its configuration
  was valid. An operational failure is not evidence that configuration is
  malformed.

### Phase B — bounded MoonCode attempt

- The correctly rooted command received the complete authoritative plan plus a
  narrow host/UI contract. It used 20 planner steps and 21 tool calls.
- It added a private UI evidence record, a host evidence helper, partial host
  projection, classifier use, and a technical-detail row.
- The turn attempted no requested test and no typed check. Its terminal planner
  batch omitted `finish`; the 109-record journal therefore settled as
  `runtime-failed`. This failed turn is retained as runtime evidence and is not
  counted as completed product work.

### Phase C — partial-edit audit

- The classifier direction was useful: new evidence, rather than operation
  success, should own the configuration decision.
- The partial host projection called the installation probe twice for each
  response instead of reusing the computed evidence, contrary to the target
  contract.
- The evidence omitted an explicit `configured` bit, every UI lifecycle test
  fixture lacked the new required record field, and no host, transition, or
  rendering regression test had been added. The nested UI check failed on the
  incomplete fixtures.

### Phase D — independent host repair

- `town_configuration_evidence_from_values` now returns three explicit facts:
  `configured`, `valid`, and a stable reason. Installed and configured is valid;
  an installed supervisor without service configuration is invalid; absence is
  not mislabeled as malformed configuration.
- Both lifecycle response builders compute installation evidence once, reuse
  it to derive configuration evidence, and return both records beside platform
  evidence. No status, message, or display string participates in the
  classification.
- Focused host tests cover valid configuration, installed-but-invalid setup,
  absence, and the evidence carried by configured and unconfigured lifecycle
  responses.

### Phase E — independent UI repair

- The optional private DTO carries `configured`, `valid`, and `reason`.
  New-format responses select `Misconfigured` only from installed evidence plus
  explicit invalid configuration evidence.
- Running, unsupported-platform, probe-unavailable, and not-installed
  precedence remain unchanged. Older responses retain a compatibility path
  based on structured lifecycle fields, but `ok` is no longer treated as
  configuration evidence.
- A stopped, installed, validly configured service remains
  `InstalledStopped` even when its last lifecycle action failed. An installed
  supervisor with explicit invalid evidence becomes `Misconfigured`.
- The stable reason is rendered only inside the closed **Technical details**
  disclosure. Ordinary title and detail copy remain capability-owned and keep
  Requests staging available.

### Phase F — focused proof and remaining boundary

- Host configuration/status tests pass 5/5. The UI capability suite passes
  16/16, including new-format operation failure, invalid configuration,
  not-installed, unsupported-platform, missing-evidence compatibility, and
  technical-detail confinement.
- Root native and nested JavaScript checks pass with warning 73 enabled and
  zero warnings. `moon info` and `moon fmt` complete for both module roots; the
  generated interface diff remains limited to preexisting SourcePane and
  `SurfaceState` work, so this private evidence slice adds no public API.
- The complete fast gate passes 232/232 native and 387/387 UI tests. Production
  UI build succeeds and regenerates the current hashed distribution assets. It
  retains the existing 2.32 MB minified entry-chunk warning, so no bundle-size
  qualification is claimed.
- Whitespace checks pass in the desktop, runtime, and shared-library
  repositories. The forbidden comparison-name scan remains empty. The isolated
  daemon used for this command was stopped; the preexisting product daemon
  remains outside this command's lifecycle.
- This closes one false-misconfiguration path. It does not prove executable
  integrity for arbitrary service commands, complete unsupported-host behavior
  on every supported desktop, or equivalent explicit installation and
  configuration evidence for every other optional capability.

## Command 051 — separate Code installation evidence from ownership

### Phase A — defect and target

- The Code classifier treated `managed_install` as installation evidence.
  That field describes ownership, so a valid externally configured service
  carried `managed_install=false` and could be mislabeled **not installed**.
- The bounded target required optional host-owned installation/configuration
  evidence, compatibility for older responses, technical-only reason strings,
  and focused host/UI proof.

### Phase B — failed MoonCode attempt

- The correctly rooted model turn used all 20 planner steps and 25 tool calls.
  It added both evidence records, host projection, classifier consumption, and
  two fixture updates.
- Its own final UI check exposed eight missing `MoonClawDaemonStatus` fixture
  fields and three unused evidence fields. It added no requested semantic
  regression tests and omitted `finish` at the terminal boundary.
- The runtime correctly settled the turn as `runtime-failed`. The failed check
  and terminal receipt are retained; the partial mutation is not accepted as
  completed product work.

### Phase C — host recovery

- Pure host helpers now classify managed service, external configured service,
  observed daemon-info evidence, and absence without parsing presentation text.
- Configuration evidence separately carries `configured`, `valid`, and a
  stable reason. Absence is not called malformed; observed/installed service
  without required configuration is invalid.
- Every daemon-status branch reuses one installation record to derive its
  configuration record. `managed_install` remains ownership metadata.
- Host tests cover all four installation sources and valid, invalid, and
  not-installed configuration outcomes.

### Phase D — UI recovery

- All test fixtures now satisfy the optional DTO fields. New evidence takes
  precedence; older responses retain the previous fallback.
- An external configured stopped service with `managed_install=false` now maps
  to `InstalledStopped`. Observed-but-unconfigured evidence maps to
  `Misconfigured`; absence maps to `NotInstalled`; running and explicit
  unsupported-platform precedence are unchanged.
- Installation source/reason and configuration reason are consumed only in the
  closed **Technical details** disclosure, eliminating the unused-field
  warnings without leaking them into ordinary capability copy.

### Phase E — focused proof and remaining boundary

- MoonClaw service/status tests pass 11/11, Code capability tests pass 16/16,
  and the wider Code-session regression file passes 95/95. Root native and
  nested JavaScript checks pass with zero warnings.
- Root and nested `moon info` plus `moon fmt` complete; the slice adds no public
  API beyond the preexisting interface diff. The complete fast gate passes
  233/233 native and 387/387 UI tests.
- Production UI build succeeds and regenerates current hashed assets. The
  minified entry remains approximately 2.33 MB and above the configured warning
  threshold, so bundle-size qualification remains open.
- This closes the ownership-versus-installation bug and gives both current
  optional services explicit configuration validity. At this command boundary,
  executable integrity, unsupported-host testing on each supported desktop,
  and other capability families remained open; Command 052 closes the
  executable-integrity item.

## Command 052 — validate configured service executables before spawn

### Phase A — defect and exact contract

- Both service descriptors treated any non-empty command as configured and
  usable. A missing executable, non-executable file, directory masquerading as
  a command, or missing working directory therefore appeared valid until
  process creation failed.
- That late failure could create lifecycle directories and log files before
  reporting the problem. It also collapsed malformed configuration into a
  generic operational failure instead of returning stable configuration
  evidence.
- The bounded contract preserves syntactic `configured` separately from
  operational `configuration_valid`. Path commands must resolve to an existing
  executable file, relative path commands resolve from the configured working
  directory, bare commands must resolve through `PATH`, and the configured
  working directory must exist as a directory. Validation must never execute
  the configured service.

### Phase B — failed MoonCode attempt

- Session `moondesk-command052-service-integrity` received the complete
  authoritative plan and the narrow service-integrity target under command
  `command-052-service-integrity`.
- The planner connection closed after two planner steps. The follow-up planner
  then had no prior model transcript, so the runtime failed closed with
  `accepted=false`, `runtime-failed`, zero tool calls, and the message
  `no MoonCode tool result was recorded`.
- The 11-record journal contains the initial connection failure, the empty
  tool selection, the missing-transcript follow-up failure, and the terminal
  failed verdict. No workspace mutation occurred. The failed turn is retained
  as runtime evidence and is not counted as product implementation.

### Phase C — independent integrity primitive

- A cohesive private helper now owns deterministic configuration reasons:
  `not-configured`, `command-unavailable`,
  `working-directory-unavailable`, and `configuration-valid`.
- Absolute commands are inspected directly. Relative commands containing a
  path separator are resolved from the configured working directory, matching
  spawn semantics. Bare commands use a bounded `which` probe. Path
  executability uses a bounded `test -x` probe after existence and
  non-directory checks.
- Both probes have a two-second ceiling. The configured service is never
  started during validation. A marker-writing executable fixture proves that
  absolute, relative, and bare-command checks do not execute the service.

### Phase D — descriptor and lifecycle integration

- Town and MoonClaw service descriptors now expose
  `configuration_valid` and `configuration_reason` beside the existing
  syntactic `configured` field. No public MoonBit API was added.
- Town and MoonClaw configuration evidence reuse those descriptor facts.
  Installed/configured-but-unusable services remain installed and configured,
  but carry `valid=false` with the exact integrity reason. Absence remains
  `not-installed`, not misconfigured.
- Both start paths reject invalid configuration before current-status probes,
  lifecycle-directory creation, log creation, or process spawn. Town returns
  its existing full daemon result with evidence. MoonClaw rebuilds the
  preflight failure from the full daemon-status projection so platform,
  installation, configuration, service, and version evidence are preserved.

### Phase E — review defects and recovery

- The first independent helper checked `./service` relative to the MoonDesk
  host process rather than the service working directory. Review caught the
  mismatch before closeout. The helper now resolves relative path commands from
  configured `cwd`, and a regression test proves the corrected behavior.
- The first fast validation attempt stopped at canonical format differences in
  the new MoonBit blocks. `moon fmt` applied the generated form; the exact fast
  gate then passed. No compile or test failure was hidden behind that initial
  formatting stop.
- Existing descriptor fixtures used illustrative paths that did not exist.
  They now create real executable files and real working directories, so a
  green validity assertion represents operational evidence rather than a
  non-empty string.
- The first-run specification contained both the current Requests evidence
  contract and a later obsolete claim that Requests still lacked installation
  and platform evidence. The stale section now describes the same six-state,
  host-evidence-backed behavior and pre-spawn integrity contract as the
  implementation.

### Phase F — focused and complete proof

- The integrity helper tests pass 2/2, including deterministic reason
  precedence, executable permission, missing working directory, bounded PATH
  lookup, relative-path resolution, and no-execution evidence.
- Town service/configuration/start tests pass 6/6. MoonClaw
  service/configuration/start tests pass 12/12. Both invalid-start tests prove
  that the service remains unspawned and the lifecycle directory remains
  absent.
- The complete native host package passes 132/132. The existing UI capability
  classifier suite passes 16/16, retaining explicit-invalid-evidence and
  old-response compatibility coverage.
- `moon check --warn-list +73` passes with zero warnings. Root and nested
  `moon info && moon fmt` complete. The only generated interface diff remains
  the preexisting SourcePane and `SurfaceState` work; this slice adds no public
  API.
- The complete fast gate passes 237/237 native and 387/387 UI tests.
  The production UI build succeeds and retains the known approximately 2.33 MB
  minified entry-chunk warning, so no bundle-size qualification is claimed.
  Whitespace checks pass, and the forbidden comparison-name scan remains empty.
- The isolated Command 052 daemon was stopped and its port was released. The
  original product daemon and the other preexisting test daemon remain running
  on their original ports and outside this command's lifecycle.
- Executable-integrity proof for both currently configured optional services is
  complete. Remaining Phase 1 capability work is equivalent structured
  evidence for other optional capabilities plus unsupported-host proof on
  every supported desktop platform.

## Command 053 — separate Flow preparation readiness from durable run history

### Phase A — defect and bounded target

- Flow run history is durable local evidence and remains readable without the
  optional Flow executor. Preparation and ingest, however, require a supported
  host, an available MoonBit command, and a valid `MOONFLOW_ROOT`.
- The host checked only `MOONFLOW_ROOT` at action time. Missing runtime setup
  returned an operation result after the user had already been offered
  **Prepare**, while the UI retained a legitimate-zero listing state instead
  of selecting its existing typed `CapabilityLimited` state.
- The bounded target therefore keeps listing transport truth independent,
  adds a read-only preparation-capability probe, hides and refuses only
  executor-dependent actions when explicit evidence is unavailable, and
  retains all earlier run records.

### Phase B — failed MoonCode attempt

- Session `moondesk-command053-flow-capability` received the complete
  authoritative plan, execution log, and the exact host/UI target under command
  `command-053-flow-capability`.
- The model used four planner steps. It first outlined the unrelated top-level
  command package, then used direct search to find the relevant nested UI
  state. Its attempted execution-log edit failed with a false file-not-found
  result even though the selected-root file exists.
- The model finished as blocked without an accepted mutation or typed
  verification. The completion gate correctly rejected the turn with
  `accepted=false` and
  `coding completion has no accepted mutation evidence`. No product mutation
  from MoonCode is accepted as implementation.

### Phase C — host-owned readiness evidence

- A private host projection now reports `available` plus a stable top-level
  reason and separate platform, installation, and configuration evidence.
- Platform support reuses normalized host evidence. Installation means the
  bounded MoonBit command lookup succeeded. Configuration separately records
  whether `MOONFLOW_ROOT` was supplied and whether it names a directory with a
  `moon.mod`.
- Stable reasons are `unsupported-platform`,
  `runtime-command-unavailable`, `runtime-root-not-configured`,
  `runtime-root-unavailable`, and `capability-ready`. The probe never executes
  Flow and reuses the bounded command-availability primitive from Command 052.

### Phase D — read-only route and action enforcement

- `GET|HEAD /api/moonflow/capability` returns a successful probe envelope even
  when the optional executor is unavailable. Transport success is therefore
  distinct from capability readiness.
- Import now reuses the same evidence instead of repeating a looser environment
  check. Explicitly unavailable imports return the nested capability evidence,
  stable corrective action, and no executor invocation.
- A live isolated-host probe with an intentionally missing configured root
  returned HTTP 200, supported macOS/arm64 platform evidence, installed MoonBit
  command evidence, configured-but-invalid root evidence, and
  `runtime-root-unavailable`.

### Phase E — independent UI readiness state

- The UI fetches readiness at bootstrap, library activation, workspace reload,
  general refresh, and Flow entry. Missing capability-route responses preserve
  older-host behavior; only explicit `available=false` selects
  `CapabilityLimited`.
- Readiness is stored separately from `moonflow_runs_state`, which remains the
  owner of listing transport truth. An effective view projection overlays
  `CapabilityLimited` without deleting or relabeling the underlying successful
  listing state.
- Technical roots and reasons remain inside the closed **Technical details**
  disclosure. Ordinary copy says only that executable work is unavailable in
  the current setup.

### Phase F — dependent-action and retained-evidence repair

- The first focused test exposed a second executor-dependent control:
  **Ingest latest revision** remained available when the empty-state
  **Prepare** control was hidden. Both controls now disappear under explicit
  capability limitation.
- The update layer independently refuses a dispatched `PrepareMoonFlow` action
  while unavailable, so DOM hiding is not the authorization boundary.
- Capability-limited Flow now keeps and renders selected run history. A ready
  probe restores the underlying ready/zero/loading listing projection without
  reloading or erasing records.

### Phase G — proof and remaining boundary

- Host readiness evidence tests pass 1/1. Focused Flow state tests pass 5/5 and
  Flow view tests pass 12/12.
- Root and nested JavaScript checks pass with warning 73 enabled and zero
  warnings. Root and nested `moon info && moon fmt` complete. The generated UI
  interface records one new private `FromJson` type and no new public symbol,
  beside the preexisting SourcePane and `SurfaceState` diff. The complete fast
  gate passes 238/238 native and 389/389 UI tests.
- The production UI build succeeds. Its minified entry is approximately
  2.37 MB and remains above the configured warning threshold, so bundle-size
  qualification remains open.
- The isolated MoonCode daemon and isolated live-proof host were stopped and
  both ports were released. The original product daemon and the other
  preexisting test daemon remain running on their original ports.
- The Flow preparation capability is now the third optional-capability family
  with explicit host evidence. This does not claim that every Flow operation,
  every other optional capability, or unsupported-host behavior on each
  supported desktop is qualified.

## Command 054 — make Pages search zero evidence authoritative

### Phase A — defect and bounded target

- The legacy `GET /api/search` route returned only an array. An empty array
  could mean a completed search with no matches, an unknown workspace filter,
  or a search scope that could not be opened. The UI therefore had no host
  evidence with which to distinguish legitimate zero from a limitation or
  invalid scope.
- Browser-side request failure also discarded transport error identity and
  selected one generic recoverable state. Starting any search cleared all prior
  hits, so refreshing the same query could not retain visibly labeled stale
  evidence.
- The bounded target preserves the legacy route exactly, opts the current UI
  into a versioned evidence envelope, prevents invalid/unreadable scope from
  becoming zero, retains only same-query prior hits, and does not claim that all
  eight shared states are now production-selectable.

### Phase B — failed MoonCode attempt and non-exact revert

- Session `moondesk-command054-search-evidence` received the complete
  authoritative plan, execution log, and exact host/UI/test target under
  command `command-054-search-evidence`.
- Two semantic reference searches failed because the model supplied symbol
  names without source locations. It then used direct search, made one
  speculative message-constructor edit, attempted to revert it, ran no test,
  and finished while explicitly claiming no implementation.
- The completion verdict correctly rejected the turn with `accepted=false` and
  `coding completion has no successful typed test after the final mutation`.
  Independent inspection then found that the claimed revert was not exact: it
  left two identical `LoadedSearch` constructors. The duplicate was removed
  during recovery. This is additional evidence that model narration and edit
  count are not substitutes for a post-turn source diff and compilation.

### Phase C — backward-compatible host contract

- Legacy requests without a contract selector still receive the same JSON
  array, including the historic empty array for an unknown workspace filter.
- Requests with `contract=pages-search.v1` receive `contract`, `ok`, `status`,
  `message`, decoded `query`, `workspace_id`, and `hits`.
- A completed search reports `ok=true` and `status=ready`. An unknown explicit
  workspace reports `ok=false` and `status=workspace-not-found`. A selected
  workspace whose root is missing or cannot be opened reports `ok=false` and
  `status=scope-unavailable`.
- `GET` and `HEAD` remain accepted. Limitation responses use HTTP 200 because
  the response is successful capability/state evidence rather than a failed
  transport.

### Phase D — typed UI evidence and conservative mapping

- The current Pages search request opts into the new envelope and decodes one
  private `PagesSearchResponse`.
- Only an exact `pages-search.v1` contract can select host-owned special
  states. `scope-unavailable` maps to `CapabilityLimited`, and
  `workspace-not-found` maps to `TerminalError`. Unknown contracts, unknown
  statuses, decode failures, and unclassified request failures remain
  `RecoverableError` unless same-query evidence can be retained as `Stale`.
- A successful empty `hits` array is the only path to `LegitimateZero`; a
  successful nonempty response becomes ready content. A scoped response whose
  hit belongs to a different workspace is treated as malformed rather than
  trusted as ready evidence.

### Phase E — same-query stale preservation

- The model now records the query that produced its current hits separately
  from the editable query.
- Refreshing that exact query enters `Loading` without deleting the earlier
  rows. A failed refresh retains the rows and selects `Stale`.
- Editing the query clears the recorded evidence query and prior hits
  immediately. Results from a different query therefore cannot be displayed as
  current or stale evidence for the new request.
- Capability-limited and terminal responses clear prior rows instead of
  relabeling them as current.

### Phase F — ordinary status and technical disclosure

- Raw response and decode details now live in `search_error`; the always-visible
  status line uses bounded user-facing text.
- The state panel keeps the shared technical explanation and the host detail
  inside a closed `Technical details` disclosure. The one-primary-action rule
  is unchanged, and the action remains disabled while loading.
- A focused rendered-markup test proves the limitation state key, ordinary
  title/detail, closed disclosure, and retained technical marker.

### Phase G — focused and live proof

- The scope-availability white-box test passes 1/1. The existing full HTTP
  route integration passes 1/1 with new assertions for a ready evidence
  envelope, legacy unknown-workspace array behavior, and the explicit
  `workspace-not-found` envelope.
- Pages surface-state/render tests pass 7/7 in their owning file, and adjacent
  Markdown/navigation tests pass 19/19.
- An isolated current-source host on port 56524 returned legacy `[]`, a ready
  `pages-search.v1` envelope for the same empty library, an explicit
  `workspace-not-found` envelope for the scoped invalid request, and a
  successful empty-body `HEAD` response. The host was then stopped and the port
  released.

### Phase H — closeout and remaining boundary

- The first fast-validation attempt stopped only because four new lines were
  not yet in canonical MoonBit format. `moon fmt` repaired them, and the
  complete rerun passed 239/239 native and 391/391 UI tests.
- Root and nested checks pass with warning 73 enabled and zero warnings. Root
  and nested `moon info && moon fmt` complete. The generated UI interface adds
  one private JSON response type and no new public function or public type.
- The production UI build succeeds. Its minified entry is approximately
  2.38 MB and remains above the configured warning threshold.
- The isolated MoonCode daemon and live-proof host were stopped. The original
  product daemon and the other preexisting test daemon remain running on their
  original ports.
- `Disconnected` remains contract-only for Pages search because the current
  browser HTTP adapter erases transport error identity. The current all-books
  UI request also does not itself create an invalid workspace filter. Recursive
  unreadable descendants and unreadable individual files still need a richer
  partial/failure contract if they must prevent partial search results. This
  slice does not close the complete shared-state, accessibility, localization,
  cross-platform, or Phase 1 gates.

## Command 055 — stop saved-view load failure from becoming empty success

### Phase A — defect and bounded target

- Settings rendered the saved-view catalog directly from `saved_views`. When
  that array was empty it always displayed `No saved views yet`, even if the
  catalog request had failed.
- `LoadedSavedViews(Err(...))` wrote only a generic host status. The listing had
  no surface-owned transport state, retry transition, retained-row behavior, or
  private error channel. Save-operation feedback and listing readiness were
  also represented by the same broad status mechanism.
- The bounded target makes the catalog the tenth consumer of the shared
  eight-state presentation contract. It must distinguish first use, loading,
  explicit empty success, ready rows, failed refresh with retained rows, and
  recoverable failure without rows. It must not invent disconnected,
  capability-limited, or terminal evidence that the current endpoint does not
  provide.

### Phase B — rejected MoonCode mutation

- Session `moondesk-command055-saved-views-state` received the complete
  productization plan and execution log under command
  `command-055-saved-views-state`.
- The model located the main symbols and attempted the requested state module,
  transitions, view, and tests. After six planner steps it stopped with a
  partial implementation: required model fields and message routing were
  missing, one existing fetch command was called with the wrong arity, HTML
  attributes and empty children used invalid APIs, and no typed test had run.
- The partial tree produced 20 compile errors and six warnings. The runtime
  correctly rejected completion with `accepted=false` and
  `coding completion has no successful typed test after the final mutation`.
  Independent recovery retained only coherent ideas, repaired every owning
  layer, removed unnecessary annotations, and supplied the missing focused
  tests.

### Phase C — listing-owned state and transitions

- The model now owns `saved_views_state`, `saved_views_error`, and a separate
  `saved_view_action_status`. Initial state is `FirstUseEmpty`.
- Opening Settings, explicit retry/refresh, global refresh, and the post-save
  catalog reload enter `Loading` without discarding previously proven rows.
- Only `LoadedSavedViews(Ok([]))` selects `LegitimateZero`. A successful
  nonempty response selects ready content. Failure with retained rows selects
  `Stale`; failure without rows selects `RecoverableError`.
- Raw request detail is stored in `saved_views_error`. The transition no longer
  overwrites unrelated host status, and failure never clears prior catalog
  evidence.

### Phase D — save feedback is not listing evidence

- Editing the view title clears only prior save feedback. Starting a save
  reports `Saving view` while leaving catalog state and rows unchanged.
- A successful save reports the saved title and starts a catalog reload. A
  failed save reports the operation error without relabeling a previously ready
  catalog as failed or empty.
- This separation prevents mutation progress, mutation failure, and catalog
  transport from contradicting one another.

### Phase E — rendered and accessible contract

- `Save current view` remains the primary mutation action. Listing recovery is
  a secondary `Check saved views`, `Refresh`, or `Retry` action selected from
  the typed state.
- A stable `saved-views-state-panel` and exact `data-state` key expose the
  presentation state. Title and explanation use the shared polite live-region
  helper. Loading and stale states keep prior rows visible.
- Raw host detail appears only in a closed `Technical details` disclosure.
  Recoverable failure cannot render `No saved views yet`, while an explicit
  successful zero still offers the normal save action.
- Independent copy review corrected an overclaim in the first-use explanation:
  the catalog is user-wide and may contain multiple books, so the copy no
  longer describes it as belonging only to the selected book.

### Phase F — conservative evidence boundary

- The state module supplies exhaustive copy and action mappings for the shared
  contract, but current production transitions select only first use, loading,
  legitimate zero, ready, stale, and recoverable error.
- `Disconnected`, `CapabilityLimited`, and `TerminalError` remain
  contract-level states until the host or browser transport preserves evidence
  that can select them. No display string or generic error text is parsed to
  manufacture those states.

### Phase G — focused proof

- Four saved-view white-box tests cover exhaustive mappings, initial/loading/
  zero/ready/stale/recoverable transitions, row retention, independence of save
  feedback, stable rendered state, polite announcement, honest zero, retry, and
  a closed technical disclosure.
- The focused saved-view file passes 4/4. The adjacent shared-shell
  accessibility file passes 3/3, and JS checking with warning 73 enabled passes
  with zero warnings.
- This focused proof establishes the owned transition and rendering boundary;
  it is not by itself a Phase 1 completion claim.

### Phase H — full closeout and remaining boundary

- `scripts/validate.sh fast` passes canonical formatting, all checks, 239/239
  native tests, and 395/395 UI tests.
- Root and nested UI checks pass with warning 73 enabled and zero warnings.
  Root and nested `moon info && moon fmt` complete. No saved-view symbol appears
  in the generated package interface, so this state contract remains private.
- The production UI build succeeds. Its minified entry is approximately
  2.41 MB with a 281.89 kB gzip size and remains above the configured 2.2 MB
  warning threshold.
- `git diff --check` passes. The required documentation exclusion scan returns
  no match.
- The isolated MoonCode daemon on port 56525 was stopped and the port was
  released. Both preexisting daemons remain running under their original
  process IDs.
- The catalog endpoint still cannot distinguish disconnected,
  capability-limited, or terminal cases. Localization and browser interaction
  for this newly rendered copy remain part of the broader Phase 1 audits.
  Command 055 closes one false-empty defect and adds the tenth bounded typed
  consumer; it does not close the remaining shared-state or Phase 1 gates.

## Command 056 — make empty-library claims depend on catalog success

### Phase A — defect and bounded target

- Workspace metadata could establish a valid library and then
  `LoadedWorkspaces(Err(...))` could leave an empty `workspaces` array with
  broad loading disabled. Cold-start classification treated that array as
  proof of `No MoonBooks yet` and exposed create/import actions even though the
  catalog request had failed.
- Refresh failure also had no typed stale presentation for retained rows, no
  surface-owned private error channel, and no stable recovery panel. Broad
  `loading` and `host_status` were being asked to represent unrelated shell and
  catalog truth.
- The bounded target makes the workspace catalog the eleventh consumer of the
  shared surface-state contract. Only successful empty evidence may select the
  empty-library path. Missing library metadata, catalog failure without rows,
  and stale retained rows must remain distinct.

### Phase B — first rejected MoonCode command

- A fresh isolated MoonClaw runtime on port 56526 received the complete
  productization plan, execution log, first-run vocabulary, and project
  instructions in session `moondesk-command056-workspace-catalog-state`, under
  command `command-056-workspace-catalog-state`.
- Four symbol-only semantic searches failed to locate
  `LoadedWorkspaceMetadata`, `LoadedWorkspaces`, `classify_cold_start`, and
  `cold_start_state`. The command then added a disconnected catalog enum
  without wiring it into the model, transitions, or renderer.
- That partial mutation introduced an ambiguous `Stale` constructor and an
  unused-type warning. It ran no focused test and did not complete a coherent
  slice. The runtime correctly rejected completion, and the assistant reported
  the work as incomplete.

### Phase C — second rejected MoonCode command

- Recovery command `command-056-workspace-catalog-recovery` supplied the exact
  eight owning file paths instead of asking for another long-document
  discovery pass.
- The command removed the disconnected enum and added part of the model,
  initialization, library-selection, and cold-start classification. Its JS
  check compiled but reported that the new model field was unused.
- Result transitions, global refresh, every other catalog-fetch entry point,
  stale-row rendering, private technical detail, and focused tests were still
  absent. The command again correctly admitted incompleteness and was rejected.
- Two MoonCode commands were therefore insufficient for this cross-cutting
  slice. Independent recovery kept the useful partial structure only after
  checking it against all owning transitions and the rendered contract.

### Phase D — catalog-owned state and request entry points

- `Model` now owns `workspace_catalog_state` and
  `workspace_catalog_error`. Initial bootstrap starts at Loading without
  inferring catalog truth from global shell status.
- First bootstrap, bootstrap retry, explicit global refresh, accepted library
  selection, post-create/import open, book creation from a pattern, and both
  portable-tool export reload paths independently enter catalog Loading and
  clear the prior catalog error.
- Same-library refresh retains proven rows while loading. Accepted library
  selection clears rows from the previous library because those rows are not
  valid evidence for the newly selected catalog.
- An audit of every production `fetch_workspaces_cmd(dispatch)` call site
  confirms that its owning action or result transition first establishes the
  catalog Loading state.

### Phase E — success, failure, and evidence precedence

- `LoadedWorkspaces(Ok([]))` alone selects `LegitimateZero`. Successful
  nonempty results clear the transient catalog state and remain ready content.
- Failure without rows selects `RecoverableError`; failure with retained rows
  selects `Stale`. Failure does not erase earlier rows, and raw request detail
  is stored separately from ordinary status copy.
- Cold-start precedence first preserves one or many retained rows, even while
  their refresh is loading or stale. With no rows, catalog Loading means
  connecting; absent library metadata means choose a library; explicit catalog
  failure means catalog unavailable; and explicit successful zero means an
  empty library.
- This expands the private cold-start classifier from five to six states
  without exporting a new package type. A temporary MoonCode visibility change
  was corrected before interface generation.

### Phase F — honest and accessible presentation

- The new-book create/import disclosure opens only for explicit
  `EmptyLibrary`, remains closed for populated libraries, and is absent during
  connecting, missing-library, and catalog-failure states.
- Failure without rows renders a stable `workspace-catalog-state-panel`, exact
  recoverable-error key, concise explanation, one Refresh action, and a polite
  state announcement. It cannot render `No MoonBooks yet` or the creation test
  hooks.
- Loading and stale states retain and render proven workspace rows with the
  typed status panel. Raw host detail appears only in a closed
  `Technical details` disclosure.
- Disconnected, capability-limited, and terminal copy/action mappings are
  exhaustive contract support only. Production transitions do not invent
  evidence for states the current transport cannot distinguish.

### Phase G — focused and regression proof

- Eight cold-start white-box tests cover all six states, exact copy/actions,
  successful zero, ready, refresh, recoverable and stale transitions, missing
  metadata versus configured-catalog failure, false-empty prevention, retained
  stale rows, retry, polite announcement, and closed raw detail.
- Adjacent shell accessibility passes 3/3 and workspace-selection
  accessibility passes 1/1. Strict JS checking with warning 73 enabled passes
  with zero warnings.
- The first full UI run found two issues: an accepted library switch retained
  one workspace from the prior library, and an older test assumed broad
  `loading=false` controlled catalog truth. The production transition now
  clears cross-library rows; the test now proves typed catalog Loading remains
  authoritative and separately verifies the missing-library state.
- Focused library-selection tests pass 7/7, the adjacent Code/session file
  passes 95/95, and the cold-start file remains 8/8 after that correction.

### Phase H — full closeout and remaining boundary

- `scripts/validate.sh fast` passes canonical formatting, all checks, 239/239
  native tests, and 398/398 UI tests.
- Root and nested UI checks pass with warning 73 enabled and zero warnings.
  Root and nested `moon info && moon fmt` complete. No workspace-catalog or
  cold-start symbol appears in the generated package-interface diff, so the
  new ownership remains private.
- The production UI build succeeds. Its minified entry is approximately
  2.44 MB with a 283.15 kB gzip size and remains above the configured 2.2 MB
  warning threshold.
- `git diff --check` passes. The required documentation exclusion scan returns
  no match.
- The isolated daemon was stopped and port 56526 was released. Both preexisting
  daemons remain running under their original process IDs.
- Catalog transport still cannot distinguish disconnected,
  capability-limited, or terminal cases. Localization and interactive browser
  coverage for this newly rendered copy remain in the broader Phase 1 audits.
  Command 056 closes the workspace false-empty defect and adds the eleventh
  bounded typed consumer; it does not close the remaining shared-state,
  accessibility, localization, cross-platform, or Phase 1 gates.

## Command 057 — prove rendered capability states from explicit evidence

### Phase A — gap and bounded target

- Typed tests already covered the six Code/Requests capability states, and a
  populated browser case covered one ready Home card. There was no executable
  rendered matrix proving that every state key, ordinary title/detail, action,
  and technical disclosure came from explicit host evidence.
- Flow had typed ready/capability-limited transitions, but no equivalent
  browser proof of the actual rendered boundary.
- The bounded target is one 1440×900 evidence scenario. Keyboard order,
  responsive geometry, large text, localization, screen-reader speech, and
  packaged-native input remain separate commands.

### Phase B — first rejected MoonCode command

- Fresh isolated session
  `moondesk-command057-capability-rendered-evidence` received the complete plan,
  execution log, first-run vocabulary, and project instructions under command
  `command-057-capability-rendered-evidence`.
- The command spent its bounded inspection opportunities reading the four
  required documents and auditing the dirty worktree. It then stopped because
  it lacked enough source context to edit the already-modified browser runner
  safely.
- It changed no files, ran no tests, explicitly listed the missing work, and
  correctly failed its completion verdict.

### Phase C — second rejected MoonCode command

- Recovery command `command-057-capability-rendered-recovery` received exact
  script ranges, renderer paths, endpoint paths, state facts, and proof
  requirements without rereading the long documents.
- It still lacked enough of the existing CDP navigation and shell-runner
  context to construct a trustworthy pre-navigation response substitution. It
  added only `capability` to shell option validation, without a scenario or
  runner, then explicitly stopped rather than fabricating proof.
- That partial selector would have produced a false-success path, so
  independent recovery removed it before implementing the complete slice. Two
  MoonCode commands were again insufficient for this large, already-dirty
  browser harness.

### Phase D — deterministic evidence injection

- The existing CDP session now installs `Fetch` interception before navigation
  for `/api/moonclaw/daemon`, `/api/town/daemon/status`, and
  `/api/moonflow/capability`.
- Six cases supply explicit supported, installed, configured, running, and
  unavailable facts. Ready, installed/stopped, not installed, misconfigured,
  and unsupported states use successful structured JSON responses.
  Temporarily unavailable uses a deliberate structured HTTP 503 response for
  Code and Requests rather than parsing any visible error text.
- Each hard navigation creates a fresh UI model, preventing retained evidence
  from one state from contaminating the next. Flow separately supplies ready
  and capability-limited structured evidence.

### Phase E — rendered contract and private-detail proof

- Home’s Code card must expose exactly six distinct state keys and the exact
  typed title, detail, and applicable action. Requests must do the same while
  keeping its composer usable outside automation readiness.
- Flow must expose legitimate zero with `Start governed run` when available,
  and capability-limited with no start action when unavailable.
- The proof removes visually hidden live-region copy and technical disclosures
  before selecting ordinary title/detail/action nodes. It then verifies those
  actual nodes have nonzero rendered geometry.
- Every technical disclosure must remain closed. Unique private platform,
  installation, configuration, path, and service values must be absent from
  ordinary text. Capability-limited Flow must retain its private reason only in
  technical detail.

### Phase F — screenshot-discovered Flow defect

- The first complete proof passed its DOM assertions, but original-resolution
  screenshot review showed that Flow’s capability-limited title and explanation
  were not visible. They existed only inside the shared visually hidden polite
  announcement, so a sighted user saw only `Technical details`.
- `render_moonflow_runs_state` now renders the same typed title and explanation
  visibly after the live region. A focused regression requires both strings
  twice: once in the announcement and once in visible presentation.
- The browser extractor was hardened to select only visible, non-disclosure
  nodes and require rendered geometry. The rebuilt screenshot shows the title,
  explanation, and closed disclosure together.

### Phase G — executable and visual proof

- `scripts/desk_mode_browser_smoke.sh capability` creates a full fixture,
  starts isolated current-source host/runtime processes, drives one headless
  browser, writes `moondesk-rendered-capability-state-proof.v1`, and cleans up
  every spawned process.
- The final record contains six Code states, six Requests states, and Flow
  `legitimate-zero` plus `capability-limited`. All title/detail nodes are
  visible, all disclosures are closed, and private fixture values remain
  outside ordinary copy.
- Fourteen screenshots cover every Code and Requests state plus both Flow
  boundaries. Original-resolution review confirmed readable hierarchy,
  visible actions where applicable, closed disclosures, and the repaired Flow
  failure copy.
- The deliberate unavailable case records only expected 503 resource errors
  from the Code and Requests status endpoints. Every successful structured
  case remains console-clean.

### Phase H — validation and remaining boundary

- JavaScript syntax and shell syntax checks pass. The focused Flow state file
  passes 5/5, and strict JS checking with warning 73 enabled reports zero
  warnings.
- `scripts/validate.sh fast` passes canonical formatting, all checks, 239/239
  native tests, and 398/398 UI tests.
- Root and nested UI checks pass with warning 73 enabled and zero warnings.
  Root and nested `moon info && moon fmt` complete. The generated interface
  gains no capability-proof or Flow-renderer API.
- The production UI build succeeds. Its minified entry is approximately
  2.44 MB with a 283.19 kB gzip size and remains above the configured 2.2 MB
  warning threshold.
- The isolated MoonCode runtime and every browser-proof process were stopped;
  port 56527 was released. Both preexisting daemons remain running under their
  original process IDs.
- This command proves one desktop viewport only. The ready Flow primary action
  sits near the lower viewport edge and is not claimed as an above-fold
  responsive result here. Keyboard/focus, full responsive and large-text,
  screen-reader/native-keyboard, localization, other platform, and other
  optional-capability gates remain open.

## Command 058 — prove capability disclosure keyboard and focus restoration

### Phase A — bounded target and exclusions

- Command 057 proved the rendered capability-state copy and diagnostic
  boundary at 1440×900, but did not prove that a keyboard user could reach,
  open, close, and leave each state-owned diagnostic disclosure without losing
  focus.
- This command is intentionally limited to the same 1440×900 capability
  fixture. It covers the six Code disclosures, the five Requests disclosures
  backed by successful structured status responses, and the five
  capability-limited Flow disclosures.
- Responsive viewports, large text, complete page-level focus order, manual
  screen-reader output, localization, packaged-native input, and the ready
  Flow above-fold action remain later acceptance work.

### Phase B — first failed MoonCode command

- A fresh isolated session
  `moondesk-command058-keyboard-focus-restoration` received the complete plan,
  execution log, first-run vocabulary, and project instructions under
  `command-058-keyboard-focus-restoration`.
- Runtime planning failed before source inspection or mutation. The session
  emitted no tool-backed implementation or verification evidence and returned
  an explicit failure instead of claiming completion.

### Phase C — bounded recovery and independent completion

- Recovery command `command-058-keyboard-focus-recovery` received the exact
  browser helper, capability-case, response-substitution, and runner symbols.
  It successfully identified the relevant ranges but exhausted its execution
  budget after adding only the nearest owning `data-testid` to the active-focus
  snapshot.
- The recovery explicitly reported that traversal, proof writing, syntax
  checking, and the browser scenario were incomplete. The ownership field was
  retained because it is the required semantic link between each focused
  summary and its state panel; no completion credit was assigned to the
  partial command.
- Independent completion added the bounded traversal and proof while
  preserving the existing Command 057 state record. The recovery path never
  uses `element.click()` or programmatic focus.

### Phase D — natural-focus disclosure matrix

- Every case begins after a hard navigation and asserts that the browser's
  natural active element is `body`, outside the tab sequence and outside any
  `data-testid` owner.
- Real CDP Tab events traverse until the focused element is a native `summary`
  whose nearest `data-testid` is the expected state owner. Every traversed
  element must be connected, rendered, inside the viewport, enabled,
  `:focus-visible`, and backed by a rendered outline or shadow. Repeated focus
  keys fail the proof before a cycle can hide a missing target.
- Space opens the owning native `details` while retaining the exact summary.
  Escape invokes the product's existing disclosure-close behavior, proves the
  disclosure is closed, and proves that the exact trigger key still owns
  visible focus.
- One real Shift+Tab must reach a different usable visible target; the
  following Tab must return to the same closed summary. Each event and focus
  snapshot is retained in the case trace.
- The exact matrix contains 16 cases: six Code states, five Requests
  structured-success states, and five Flow capability-limited states.
  Requests' deliberate HTTP-unavailable case has no returned lifecycle detail
  to disclose; Flow's legitimate-zero case has no diagnostic disclosure.

### Phase E — proof-discovered Flow canvas defect

- The first complete run reached the Flow composition canvas before its state
  disclosure and failed correctly. The canvas was connected, visible,
  enabled, inside the viewport, and matched `:focus-visible`, but its computed
  outline style was `none` and it had no focus shadow.
- The rendered canvas uses `.flow-viewport`; an older focus rule targeted the
  unused `.flow-canvas-viewport` name. The active canvas selector now receives
  a three-pixel accent outline with an inward offset, so keyboard focus is
  visible without changing canvas geometry.
- The same matrix, without relaxing any assertion or skipping the canvas,
  passed after rebuilding the production UI.

### Phase F — versioned evidence and visual review

- The capability browser scenario still writes
  `moondesk-rendered-capability-state-proof.v1` and now additionally writes
  `moondesk-capability-keyboard-focus-proof.v1`.
- The keyboard record declares the exact 1440×900 viewport, natural document
  focus, no programmatic focus, the Tab/Space/Escape/Shift+Tab key set, and
  exact counts of 16 total, six Code, five Requests, and five Flow cases.
  Every case retains the natural start, trigger, open, restored, reverse,
  returned, and complete traversal snapshots.
- Machine review found no non-body start, mismatched restored trigger, open
  disclosure after Escape, or failed forward return.
- Three retained screenshots were inspected at original resolution: Code not
  installed, Requests misconfigured, and Flow installed/stopped. Each shows a
  strong, unobscured focus ring around the exact closed Technical details
  summary; the Flow summary remains visible at the lower viewport boundary.

### Phase G — validation and process closeout

- JavaScript syntax and shell syntax checks pass. The rebuilt capability
  browser scenario passes all 16 keyboard cases and preserves all six rendered
  Code and Requests states plus both Flow state boundaries.
- `scripts/validate.sh fast` passes canonical formatting and checks, 239/239
  native tests, and 398/398 UI tests.
- Root and nested UI checks pass with warning 73 enabled and zero warnings.
  Root and nested `moon info && moon fmt` complete. No keyboard-proof or focus
  styling symbol expands the generated MoonBit interface.
- The production build succeeds with the same approximately 2.44 MB minified
  entry and 283.19 kB gzip size; the known 2.2 MB chunk warning remains.
- The isolated MoonCode runtime and browser-proof processes were stopped, port
  56528 was released, and both preexisting daemons remained under their
  original process IDs.

### Phase H — closed claim and next boundary

- Command 058 closes only keyboard activation and exact focus restoration for
  the 16 state-owned diagnostic disclosures at 1440×900.
- It does not claim whole-page focus order, the responsive state matrix,
  above-fold action placement, text-only scaling, screen-reader speech,
  localization, packaged-native input, or other platforms. Command 059 owns
  the next bounded responsive geometry and action-visibility matrix.

## Command 059 — responsive capability geometry and action visibility

### Phase A — bounded matrix and acceptance contract

- Command 057 proved truthful rendered capability states at 1440×900, and
  Command 058 proved disclosure keyboard/focus restoration at that viewport.
  Neither proved that the same state-owned title, explanation, disclosure, and
  applicable action remain usable across the responsive release viewports.
- The exact matrix is 72 rendered cases: six evidence cases × three owning
  surfaces × 1440×900, 1024×768, 390×844, and 320×700. Code contributes 24
  cases, Requests contributes 24, and Flow contributes 24 across
  legitimate-zero and capability-limited presentation.
- Every case begins at document scroll position zero and proves the exact
  viewport and state identity, no document horizontal overflow, a rendered and
  unclipped state panel, visible title/detail, the correct closed-or-absent
  disclosure contract, a fully in-viewport applicable action, correct
  desktop/compact navigation, no Desk pane overlap, and usable primary work.
- This command does not expand into 200% text, manual screen-reader output,
  localization, packaged-native input, or other platforms.

### Phase B — full-document MoonCode attempt

- Fresh isolated session
  `moondesk-command059-responsive-capability-matrix` received the complete
  project instructions, productization plan, execution log, and first-run
  vocabulary under `command-059-responsive-capability-matrix`.
- It added a `capability-responsive` option and an initial geometry collector,
  then stopped without wiring the JavaScript dispatcher or shell fixture and
  without running the scenario.
- Its own completion response correctly identified the work as incomplete.
  Independent review found additional false-success hazards: the wrong Code
  route and panel selector, a call to a nonexistent mutable substitution API,
  a missing per-case interception lifecycle, heading selectors that could not
  match the real strong-title markup, and a requirement for disclosures in
  states where their absence is intentional.

### Phase C — exact recovery attempt

- `command-059-responsive-capability-recovery` received the exact missing
  selectors, routes, response-substitution lifecycle, state/disclosure
  boundaries, case counts, screenshot subset, and validation commands.
- Truncated source context prevented its exact replacements from matching.
  It made no recovery mutation and explicitly refused to claim counts,
  screenshots, browser proof, warning status, interface generation, or
  formatting evidence.
- Two MoonCode commands were therefore insufficient for this large, dirty
  browser harness. The isolated daemon was stopped and port 56529 released
  before independent completion.

### Phase D — coherent responsive evidence runner

- The repaired runner creates one immutable response substitution per evidence
  case before navigation, then exercises all viewports and surfaces before
  closing that substitution. Code uses its actual setup surface for every
  non-ready state and the shared Home ready summary for detected/running;
  Requests and Flow use their owning destinations.
- Each navigation carries the real selected-book identity and waits for the
  exact state key. Title, explanation, and action extraction excludes visually
  hidden announcements and technical details; private diagnostic text remains
  outside ordinary presentation.
- Disclosure expectations match product truth: all six Code cases, the five
  successful Requests cases, and the five capability-limited Flow cases own a
  closed technical disclosure. Requests' deliberate HTTP-unavailable case and
  Flow legitimate zero correctly own no disclosure.
- The scenario validates expected structured 503 resource errors only for the
  unavailable Code/Requests endpoints and requires all successful cases to
  remain console-clean.

### Phase E — Flow priority and state-boundary defects

- The first executable geometry run failed at Flow legitimate zero even at
  1440×900. The large composition canvas rendered before the state explaining
  whether executable work existed, so `Start governed run` was below the
  viewport.
- `render_moonflow_workspace` now renders the effective state and empty primary
  action before the composition canvas. Existing-run records retain their
  prior canvas-before-history order.
- A focused markup regression splits at the composition-canvas test ID and
  proves both legitimate-zero and capability-limited state panels occur before
  it.
- At 390×844, the next run showed that secondary handoff content lived inside
  the same empty-state section, inflating the primary panel to 870px even
  though its action ended near 356px. Handoffs now render after the canvas as a
  separate downstream section; the state panel owns only its state,
  explanation, action, status, and corrective action.

### Phase F — compact Code setup defect

- The matrix then exposed a 390×844 Code setup row wider than the viewport:
  its right edge reached approximately 412px, `panelNotClipped` failed, and the
  Technical details summary extended beyond the visible boundary.
- The setup row's desktop flex layout had no compact width or wrapping
  contract. At 760px and below it now uses an explicit viewport-contained
  width, zero minimum widths, wrapping, and full-row summary/detail ownership.
- The applicable setup action, exact title/detail, and closed disclosure now
  fit at both 390×844 and 320×700 without horizontal document overflow.

### Phase G — screenshot-discovered canvas and proof defects

- The first nominally passing 320×700 Flow screenshot showed the composition
  controls overlapping the `Composition canvas` title and clipping `Reset
  view`. DOM document-width checks had not modeled internal toolbar overlap.
- Compact Flow canvas chrome now stacks title and controls into two rows,
  wraps controls, and reduces horizontal margins. The proof now measures the
  canvas chrome, title, tool row, every visible control, and title/tool overlap;
  primary work fails unless those controls are fully inside the viewport.
- The first uniqueness assertion keyed Flow only by its two presentation state
  classes, collapsing distinct evidence cases to 56 keys. The record now
  retains the evidence case ID separately from presentation state and proves
  72 unique case keys.
- One intermediate screenshot suggested possible retained vertical scroll.
  Every case now records `scrollY` and requires document-start position before
  making any above-fold claim.

### Phase H — versioned proof, visual review, and closeout

- `scripts/desk_mode_browser_smoke.sh capability-responsive` writes
  `moondesk-capability-responsive-geometry-proof.v1`. The final record contains
  72 unique cases, 24 per surface, four exact viewports, six Code states, six
  Requests states, both Flow boundaries, and 16 retained screenshots.
- Machine review reports no overflow, panel, action, navigation, overlap,
  scroll-position, or primary-work failures.
- The representative screenshot matrix contains Code not installed, Requests
  misconfigured, Flow legitimate zero, and Flow installed/stopped at every
  viewport. Original-resolution review confirmed readable compact copy,
  fully visible actions/disclosures, and non-overlapping Flow controls.
- The focused Flow state file passes 5/5. The prior rendered capability and
  keyboard-focus scenario passes unchanged, and the populated full browser
  smoke passes at all existing viewports, browser zoom, and text-only cases.
- `scripts/validate.sh fast` passes formatting/checks, 239/239 native tests,
  and 398/398 UI tests. Root and nested warning-73 checks report zero warnings;
  root and nested `moon info && moon fmt` complete without a new public API.
- The production build succeeds with an approximately 2.44 MB minified entry
  and 283.23 kB gzip size; the known 2.2 MB chunk warning remains.
- Command 059 closes the bounded responsive capability geometry/action matrix.
  Command 060 owns capability-state 200% text and zoom rather than treating
  this ordinary-scale proof as large-text evidence.

## Command 060 — capability-state 200% text and zoom

### Phase A — exact scale matrix and acceptance boundary

- Command 059 proved ordinary-scale geometry at four release viewports. It did
  not prove that the same capability truth, correction, disclosure, and nearby
  surface controls survive browser zoom or text enlargement.
- The bounded matrix is exactly 54 rendered cases. Browser-zoom equivalence
  uses a 720×450 CSS viewport for all six evidence cases on Code, Requests, and
  Flow, producing 18 cases. Text-only scaling doubles computed font sizes at
  fixed 1440×900 and 320×700 viewports for the same six cases and three
  surfaces, producing another 36.
- Every row proves exact viewport and state identity, document-start position,
  no horizontal overflow, an internally unclipped state panel, visible and
  reachable title/detail, the correct disclosure contract, a readable and
  reachable applicable action, correct navigation, non-overlapping primary
  content, usable surface chrome, and a usable Flow canvas when present.
  Text-only rows may continue vertically only through a real reachable scroll
  path; hidden clipping is not accepted.
- This command does not claim whole-page keyboard order, manual screen-reader
  output, reduced-motion completion, localization completion, packaged-native
  input, or other desktop platforms.

### Phase B — full-document MoonCode attempt

- Fresh isolated session `moondesk-command060-capability-scale-matrix`
  received the complete project instructions, productization plan, execution
  log, and first-run vocabulary under
  `command-060-capability-scale-matrix`.
- It added a partial `capability-scale` function and shell selector, but left
  the scenario unwired and internally inconsistent. The attempted code did
  not provide the exact 54-case loop, immutable evidence substitution,
  complete scale restoration, assertions, screenshots, or a versioned proof.
- The command stopped without a success claim. Independent review preserved
  only coherent pieces and rejected the partial scenario as acceptance
  evidence.

### Phase C — exact recovery attempt

- `command-060-capability-scale-recovery` received the exact mode table,
  surface loop, helper signatures, proof counts, screenshot subset, and
  required regression commands.
- Truncated source context again prevented the exact edits from matching. The
  recovery changed only part of a helper signature, left the original
  execution defects in place, and correctly reported that it had no proof.
- Two MoonCode commands were insufficient for this browser-harness slice. The
  isolated daemon was stopped and port 56530 released before independent
  completion. The two pre-existing product/test daemons remained outside this
  command's lifecycle.

### Phase D — deterministic scale runner and proof integrity

- The completed runner reuses the immutable per-evidence-case response
  substitution from the rendered and responsive scenarios. It waits for the
  exact state on each real owning surface before collecting geometry.
- Browser zoom is represented by the equivalent 720×450 CSS viewport.
  Text-only evidence snapshots every connected element's computed font size
  before writing a two-times inline size, checks complete marker coverage
  before geometry and after capture, then restores every surviving node and
  proves that no scale marker remains.
- An attempted mutation observer was rejected after it compounded inherited
  sizes while processing parent and child replacements. The retained scaler
  takes one complete snapshot before any write and waits for rendering to
  settle before scaling, which keeps the transformation deterministic.
- Geometry now distinguishes hidden clipping from content reachable through a
  real scroll container. It also excludes closed-detail descendants and
  visually hidden live announcements from sighted overflow diagnostics.
  Internal action text, surface-header controls, the compact Code rail, and
  Flow canvas controls are explicit proof subjects rather than inferred from
  document width.

### Phase E — state-card wrapping defects

- At text-only 1440×900, the ready Code card exceeded its own width by about
  seven pixels because its heading and status pill could not wrap. The shared
  card header now wraps, gives children zero minimum width, and permits the
  status pill to use multiple lines.
- At text-only 320×700, Flow's empty state retained a multi-column minimum
  width and overflowed its card. The empty-state grid and its children now use
  a single `minmax(0, 1fr)` track, bounded widths, and wrapping actions.
- These repairs live in shared product CSS and are validated by all six
  evidence cases rather than one screenshot fixture.

### Phase F — short-height and large-action Code defects

- At 720×450, the compact Code rail reserved 240px and left the setup center
  too short. The stopped-state technical disclosure was below the viewport and
  clipped by an `overflow: hidden` ancestor. Short-height Code now uses a
  smaller rail allocation while the setup center owns a vertical scroll path.
- At text-only 320×700, `Start Code assistance` retained the generic
  single-line button contract. Its text scroll width exceeded the visible
  button by 41px. Runtime setup actions now wrap, grow vertically, and prove
  their own content width rather than only the outer button rectangle.
- At text-only 1440×900, the installation action and Technical details
  disclosure collided because the desktop runtime setup was a non-wrapping
  flex row. The setup row now wraps at every width, gives each child a bounded
  minimum/maximum width, and lets the summary claim remaining space.
- Compact setup centers and rails now scroll vertically when enlargement
  requires continuation. The rail has a useful bounded session-list region;
  its short-height header is compressed enough to keep workspace identity,
  **New chat**, and **Search chats** initially visible at browser zoom.

### Phase G — screenshot-discovered header and proof defects

- The first nominally passing 320×700 Flow screenshot showed `Refresh`
  clipped at the right edge. The Flow hero had no wrapping contract, so its
  enlarged title and action competed for one line. It now wraps with bounded
  children and places the action on its own line when necessary.
- The first 720×450 Code screenshot reduced Search chats to a thin clipped
  strip. Making the rail scrollable was necessary but not sufficient for a
  useful initial state; the short-height header/button spacing was reduced
  without shrinking text, and the proof now measures the heading, New chat,
  and Search controls independently.
- Early overflow diagnostics falsely reported closed Technical-details rows
  and one-pixel live announcements as sighted layout failures. The collector
  now applies the actual visibility boundary before reporting descendants.
- A first proof audit keyed fields with the wrong names and appeared to show
  only nine unique cases and 54 scale failures. Direct inspection found the
  record was correct; the final audit uses `evidenceCase`, the nested `scaled`
  coverage records, and the exact mode/surface key, proving all 54 unique rows.

### Phase H — versioned proof, visual review, and closeout

- `scripts/desk_mode_browser_smoke.sh capability-scale` writes
  `moondesk-capability-scale-proof.v1`. The final record contains 54 unique
  cases: 18 browser-zoom, 18 text-only desktop, and 18 text-only narrow; each
  surface owns 18 rows and all six evidence cases are retained.
- Machine audit reports zero state, geometry, overflow, clipping, disclosure,
  action, navigation, surface-chrome, overlap, primary-work, or scale-coverage
  failures. All 36 text-only rows prove full marker coverage before geometry
  and after screenshot capture, followed by zero remaining markers.
- Twelve original-resolution screenshots cover Code not installed, Requests
  misconfigured, Flow legitimate zero, and Flow capability-limited in every
  scale mode. Review confirmed readable wrapping, reachable continuation,
  intact corrective actions/disclosures, usable surface controls, and
  non-overlapping Flow chrome.
- The ordinary 72-case responsive proof, prior rendered state and
  keyboard/focus proofs, and complete browser smoke all pass unchanged. The
  focused Flow state file passes 5/5.
- `scripts/validate.sh fast` passes formatting/checks, 239/239 native tests,
  and 398/398 UI tests. Root and nested warning-73 checks report zero warnings;
  root and nested `moon info && moon fmt` complete without a Command 060 public
  API. JavaScript and shell syntax plus `git diff --check` pass.
- The production build succeeds with a 2,435.93kB minified entry and 283.23kB
  gzip size. The known 2.2MB chunk warning remains and is not reclassified as
  a release-size qualification.
- Command 060 closes only the capability-state large-text/browser-zoom matrix.
  Command 061 owns whole-page keyboard order and focus restoration across
  responsive setup and transient surfaces.

## Command 061 — responsive page keyboard order and transient focus restoration

### Phase A — exact keyboard matrix and acceptance boundary

- The bounded matrix contains exactly 18 fresh-navigation cases. Home's
  Storage & services disclosure, the not-installed Code-assistance Technical
  details disclosure, the command palette, and a deterministic Code-session
  action menu each run at 1440×900, 1024×768, 390×844, and 320×700. The compact
  primary-navigation menu adds one case at each narrow viewport.
- Every case begins from the browser's natural document focus and uses real
  CDP Tab/Shift+Tab, alternating Space/Enter activation, Escape, and the
  documented Meta+K or Control+K shortcut. Programmatic focus is allowed only
  where the product itself must autofocus a newly opened modal dialog or
  restore its recorded trigger.
- Every traversed target must be connected, rendered, enabled, inside the
  scroll viewport, `:focus-visible`, and backed by a visible outline or shadow.
  Each owned surface must open, Escape must close the topmost surface and
  restore the exact trigger, and Shift+Tab followed by Tab must round-trip to
  that same trigger. Hidden desktop/compact navigation controls may not enter
  traversal.
- The palette additionally requires a named modal-dialog accessibility node,
  input autofocus, forward and reverse Tab trapping, editable-target shortcut
  suppression, and restoration to the visible pre-open control. The session
  menu must reach Rename first. Compact navigation must reach Requests and
  restore its visible summary rather than the hidden Commands button.
- This command does not claim manual screen-reader speech, announcement
  deduplication, reduced-motion completion, packaged-native keyboard behavior,
  localization completion, or other desktop platforms.

### Phase B — full-document MoonCode attempt

- Fresh session `moondesk-command061-page-keyboard-transients` received the
  complete project instructions, productization plan, execution log, first-run
  vocabulary, exact 18-case matrix, proof schema, owning selectors, and
  validation boundary under `command-061-page-keyboard-transients`.
- It added the `keyboard-transients` shell selector and runner branch, but
  implemented only an explicit failing stub:
  `verifyKeyboardTransients` threw that the proof was incomplete. It did not
  implement product behavior, traversal, response substitution, assertions,
  screenshots, or a proof record.
- Its terminal response accurately declared the work incomplete and made no
  acceptance claim. The selector plumbing was retained as a useful but
  non-evidentiary mutation.

### Phase C — exact MoonCode recovery

- `command-061-page-keyboard-transients-recovery` received exact helper names,
  selectors, deterministic session data, focus behavior, product edits, proof
  counts, and required validation commands.
- It first invoked semantic outline from the wrong module root, then attempted
  a shell path outside the selected MoonBook boundary. The enforced
  no-discovery recovery boundary prevented it from locating replacement
  anchors after those failures.
- The recovery added only a bootstrap mutation observer that searched for a
  generic dialog or palette class and wrote role, label, and test IDs after
  render. It did not implement source-owned semantics, input focus, a Tab trap,
  typing guards, Escape restoration, the session interceptor, the 18 cases, or
  any proof.
- Its terminal response again accurately declared the command incomplete. Two
  MoonCode commands therefore did not complete this bounded browser/product
  slice; independent review replaced the observer instead of treating
  after-render mutation as the semantic source of truth.

### Phase D — source-owned palette semantics and trigger state

- The rendered palette previously had no dialog role, modal state, accessible
  name, stable panel/input/close hooks, or input label. The Commands trigger
  advertised a shortcut but not that it opens a dialog or whether the dialog
  was expanded.
- `render_command_palette` now owns `role="dialog"`, `aria-modal="true"`, the
  accessible name `Commands`, an input named `Search commands`, and stable
  panel, input, and close test IDs. The Commands trigger now owns
  `aria-haspopup="dialog"` and its current `aria-expanded` value.
- A focused MoonBit markup test proves all those attributes in open and closed
  states. The MoonCode observer and its generic dialog selector were removed,
  so delayed DOM normalization is no longer required for correct semantics.

### Phase E — focus lifecycle, topmost Escape, and typing safety

- Global Meta/Control destination shortcuts previously fired while focus was
  in inputs, textareas, selects, or editable content. A user typing a matching
  modified key could leave the current surface. The global handler now
  suppresses all application shortcuts for editable targets.
- Opening the palette previously retained no trigger, did not focus the query,
  allowed Tab to escape the modal surface, and did not restore a known control
  on close. The bootstrap now captures the visible pre-open element for both
  trigger clicks and Meta/Control+K, focuses the palette input after render,
  traps forward and reverse Tab among visible enabled dialog controls, and
  restores the exact connected visible trigger after the palette disappears.
- On compact layouts the Commands button is hidden. Shortcut opening records
  the actually focused compact-navigation summary, and restoration prefers
  that retained element before any visible fallback.
- Escape now closes the palette before any underlying disclosure. If no
  palette is open, the existing owned-details behavior closes the disclosure
  containing focus and restores its direct summary. This gives the tested
  transient stack one explicit topmost-close rule.

### Phase F — proof-runner and fixture defects

- The first scenario run exposed a dispatch bug in MoonCode's selector
  plumbing: the runner stored the Promise returned by
  `verifyKeyboardTransients()` and later called it as a function. The branch
  now stores the function reference, and the direct JavaScript usage text now
  lists the added scenario alongside the shell selector.
- The first capability run waited for the Code conversation setup panel even
  though the tested Technical details belongs to Home's `moongate-summary`.
  The proof now waits on that exact owning state and disclosure.
- The initial deterministic session response encoded unknown optional fields
  as JSON nulls. The typed decoder expects omitted optionals, so the UI
  correctly rendered recoverable `Invalid MoonCode session listing`. The
  fixture now omits unknown optional fields and proves the successful typed
  listing path.
- The session interceptor initially answered the separate `/watch` endpoint
  with a session object. That invalid update replaced the focused row while
  Tab was traversing and made the session menu appear unreachable. The
  interceptor now returns the declared watch envelope with a long retry
  interval, leaving the DOM stable for the keyboard journey.
- A combined validation command was launched from the nested UI directory
  while retaining root-relative paths; only the local build ran. The checks
  were rerun from the repository root. A parallel regression wrapper also
  used zsh's read-only `status` parameter, and its first corrected run allowed
  child scripts to collide on random CDP ports. The two affected suites were
  rerun sequentially on explicit, distinct host and CDP ports.

### Phase G — versioned proof and visual review

- `scripts/desk_mode_browser_smoke.sh keyboard-transients` now writes
  `moondesk-page-keyboard-transient-proof.v1`. The passing proof is
  `/var/folders/_j/kcn3f7817s71gymnv_nnn1bm0000gn/T/moondesk-desk-browser.KVsZNl/keyboard-transients/desk-page-keyboard-transient-proof.v1.json`.
- Machine audit reports exactly 18 unique cases with the required
  4/4/4/4/2 distribution, 18 exact Escape restorations, 18 reverse/forward
  round trips, and 18 existing screenshots. Every case records the full focus
  trace, owning surface, viewport, activation key or shortcut, navigation
  contract, opened state, restoration, and screenshot.
- All 18 original-resolution screenshots were reviewed through per-viewport
  contact sheets. Home's library action, Code's disclosure summary, the
  palette input, session Rename action, and compact Requests destination all
  show strong visible focus. The palette fits the narrow viewports, the
  complete session menu remains usable, compact navigation is not clipped,
  and no opened surface obscures its focused target.

### Phase H — regression evidence and remaining boundary

- Focused tests pass: command palette 7/7, Code session behavior 95/95,
  primary navigation 6/6, and shared-shell accessibility 3/3.
  `scripts/validate.sh fast` passes formatting and checks, 239/239 native tests,
  and 399/399 UI tests.
- The shared-shell accessibility, rendered capability, 72-case responsive
  capability, 54-case capability-scale, and complete browser suites all pass.
  The two suites affected by the parallel CDP collision pass unchanged when
  rerun on explicit isolated ports.
- Root and nested warning-73 checks report zero warnings. Root and nested
  `moon info && moon fmt` complete with stable generated-interface hashes.
  JavaScript and shell syntax plus `git diff --check` pass.
- The production build succeeds with a 2,436.29kB minified entry and 283.35kB
  gzip size. The known 2.2MB chunk warning remains and is not reclassified as
  a release-size qualification.
- Command 061 closes this bounded page-order and transient-focus matrix only.
  Command 062 owns manual screen-reader output, landmark/name confirmation,
  live-region announcement order and deduplication, and the remaining
  screen-reader-specific state transitions.

## Command 062 — screen-reader semantics and announcement order

### Phase A — exact acceptance boundary

- The automated boundary is exactly 22 cases: Home, Pages, Code, Requests,
  Runs, Review, Publish, Flow, and Packs at 1440×900 and 390×844; the Commands
  dialog at both viewports; one nine-change destination announcement sequence;
  and one Pages Loading → RecoverableError → Loading → LegitimateZero sequence.
- Every route requires exactly one named `main`, one visible named Primary
  destinations navigation, one coherent selected/current predicate for a
  primary destination and none for secondary Flow/Packs, an H1-led heading
  sequence without level skips, no unnamed actions, no exposed decorative
  glyphs, no duplicate role/name landmarks, no horizontal overflow, and an
  unshifted viewport.
- The Commands dialog requires a visible trigger with dialog popup/expanded
  state and documented shortcut, one named modal dialog, named input and close
  controls, no exposed prompt/close decoration, real Enter activation, input
  focus, contained traversal, Escape closure, and exact trigger restoration.
- The destination sequence must emit exactly nine new polite/atomic status
  values in order—six remaining primary destinations, Flow, Packs, then Home.
  A real keyboard activation of Home Refresh must not mutate that live region.
- Pages search must emit exactly four state announcements for a deterministic
  transport failure and successful retry-to-zero. It may not mutate the
  destination live region or expose raw transport or internal diagnostics.
- Chromium DOM/accessibility-tree evidence is intentionally not called spoken
  VoiceOver evidence. The proof reserves four separate real-VoiceOver rows.

### Phase B — full-document MoonCode attempt and recovery defects

- Session `moondesk-command062-screen-reader-announcements` received the full
  authoritative plan, execution log, vocabulary contract, exact matrix, proof
  schema, owning source, and validation commands. A first HTTP submission used
  unsupported top-level `prompt` and `command_id` fields and was rejected with
  status 400 before queueing. The corrected `mooncode.v1` envelope was accepted.
- The accepted command added only the `screen-reader` shell selector and
  dispatch branch. Its terminal response accurately listed the unimplemented
  route matrix, accessibility assertions, live traces, screenshots, product
  fixes, focused tests, and manual rows. It supplied no completion evidence.
- Recovery command
  `command-062-screen-reader-announcements-recovery` did not use the supplied
  product vocabulary. It invented Home, Books, Reader, Search, Tasks, Activity,
  Settings, Help, and About as destinations; counted substring matches without
  asserting the rendered/AX contract; reused one inert live sample for two
  cases; and carried a disconnected session parameter.
- The recovery then failed its closeout with unsupported
  `moon fmt --target js` syntax and a malformed quoted search. Its runtime
  status was failed. Exactly two queued MoonCode commands were spent on
  Command 062; no third command was used to hide those defects.
- The prequeue status-400 response is a separate client/API-schema defect:
  the endpoint did not provide a discoverable request shape at the attempted
  boundary. It did not consume a MoonCode planner turn.

### Phase C — independent semantic and layout repair

- Home's two side panes previously exposed unnamed complementary landmarks.
  They are now named `MoonBook library` and `Selection details`. Code and all
  Pages-owned side panes likewise have stable, surface-owned names.
- Several primary routes did not start their main content with an H1. Home,
  Code, Requests, Review, and populated Pages now have a hidden route H1 where
  the visible layout does not already supply one.
- A preview tab for an empty path could expose no usable accessible name. Its
  source-owned fallback is now `Current preview, directory`.
- The palette's visible `>` prompt and `X` close glyph reached the
  accessibility tree as standalone text. Both decorations are now
  `aria-hidden`; the close button retains `Close command palette`.
- Text chevrons in compact primary navigation were exposed as `⌃`/`⌄`.
  CSS-drawn borders now supply the visual chevron without creating a text
  accessibility node.
- Compact destination activation previously left the disclosure open. The
  bootstrap now closes its owning disclosure and restores focus to the visible
  summary after the destination change.
- Flow and Packs retained fixed desktop grid rows that no longer matched their
  title/Commands header. Their shells now use content-sized header rows, which
  prevents the title and Commands control from colliding with primary content.

### Phase D — deterministic proof and visual review

- `scripts/desk_mode_browser_smoke.sh screen-reader` is an isolated scenario.
  It starts the required fixture service, runs the exact matrix, and writes
  `moondesk-screen-reader-announcement-proof.v1`.
- The retained passing proof is
  `/var/folders/_j/kcn3f7817s71gymnv_nnn1bm0000gn/T/moondesk-desk-browser.2GKI6i/screen-reader/moondesk-screen-reader-announcement-proof.v1.json`.
  Machine audit confirms 18 route cases, two palette cases, two live-region
  sequences, 22 unique total cases, four explicitly pending VoiceOver rows,
  and eight retained screenshots.
- The destination trace records exactly nine content changes and nine target
  mutation batches. Home Refresh produces no additional content change or
  target mutation. The Pages trace records exactly Loading,
  RecoverableError, Loading, and LegitimateZero; its destination trace is
  empty.
- Deterministic interception fails the first Pages request and fulfills the
  retry with a versioned successful zero response. Flow composition is fulfilled
  with an explicit empty fixture instead of suppressing an unexpected 404.
- All eight screenshots were reviewed at original resolution: Home and Flow at
  both viewports, the dialog at both viewports, the destination-sequence final
  state, and the Pages zero-result final state. The repaired header rows,
  compact navigation/Commands layout, dialog containment, and final focus are
  visible without clipping or overlap.

### Phase E — manual boundary and final validation

- A real macOS VoiceOver attempt enabled VoiceOver through System Settings,
  confirmed the caption panel setting, opened the desktop fixture, and
  traversed the repaired Home navigation. The assistive-control layer could
  inspect the application accessibility tree but could not capture the
  system-owned caption overlay or invoke VoiceOver's global last-phrase
  command. A full-screen capture fallback stalled.
- The user explicitly directed the remaining manual capture to be skipped.
  VoiceOver was confirmed off afterward. The four retained rows therefore
  remain `pending-real-voiceover-verification`; they are not silently promoted
  to passing and Command 062 does not close the focused manual screen-reader
  gate.
- Focused semantic tests now pass as part of the 402/402 UI suite. Nested
  `moon check --target js --warn-list +73` is warning-free, localization passes
  5/5, and the production build succeeds at 2,437.30kB minified /
  283.67kB gzip with the known 2.2MB chunk warning.
- Root all-target warning-73 check and 239/239 native tests pass. Root and
  nested `moon info && moon fmt`, JavaScript/shell syntax, and
  `git diff --check` pass. The generated interface contains earlier public
  SourcePane work; Command 062 itself adds no public MoonBit API.
- Both original MoonClaw daemons remained alive throughout. The isolated
  VoiceOver fixture was stopped after the user-directed skip.

## Operating Rules

- Preserve user work; do not commit, push, or delete unrelated changes.
- Execute the authoritative plan phase by phase and close only evidence-backed exit gates.
- Verify MoonBit changes with semantic discovery, focused tests, `moon check`, and a coherent-slice closeout of `moon info && moon fmt` with review of generated `.mbti` changes.
- Avoid generated distribution churn unless release evidence intentionally requires it.
- Record every discovered bug or operational defect below.

## Independent clean-checkout full proof

- Prepared an isolated clone from the repository `HEAD`, applied the complete
  tracked working-tree diff, copied the relevant non-ignored untracked product
  files, generated deterministic interfaces/distribution files, and committed
  only inside the throwaway clone.
- `scripts/validate.sh full` passed twice from the resulting clean checkout:
  format, all-target check, 217/217 native tests, 305/305 UI tests, 3/3
  localization tests, production build, generated-interface stability,
  whitespace checks, and clean generated tree.
- The final status was empty at temporary proof commit
  `30594135508fa62833bf8948b081a579ea270fa5`.
- The retained transcript and evidence boundary are in
  `docs/FULL_VALIDATION_PROOF_2026-07-27.md`. Cross-product roots were absent,
  so boundary validation visibly skipped; no remote CI or release evidence is
  claimed.
- **Gate status:** local Phase 0 complete.

## Command 019 — Phase 1 clean-workspace quickstart E2E slice

### Exact command

```sh
scripts/moondesk_quickstart_e2e.sh
```

### MoonCode result and independent audit

- The generated shell initially delegated to an undeclared Playwright driver
  with selectors, labels, environment seams, and paths that did not exist. It
  ran syntax and unrelated UI tests but never executed its claimed E2E path.
  Its final step failed because the new shell was not executable and because it
  invoked `moon fmt` with an unsupported target option. The runtime marked the
  command failed and no valid `finish` result was recorded.
- Independent repair removed the false driver and made the executable wrapper
  call the existing CDP browser infrastructure. The real harness starts a
  temporary suite, the production UI, Chrome, and a local Code runtime; it
  preserves browser/runtime state while restarting the MoonDesk host.

### Product defects found and fixed

1. **Created/imported book lost on reload.** The result handler selected the new
   workspace only in memory and did not synchronize the workspace or Code URL
   context. The handler now batches both context-sync commands with the
   workspace reload, so the selected book survives hard refresh and host
   restart.
2. **Ordinary workspace refresh emitted Flow 404s.** Every workspace reload
   requested an executable composition even when the book had no Work graph.
   Composition loading now belongs to entering Flow; general workspace refresh
   no longer probes an inapplicable endpoint.
3. **Unavailable Code capability emitted repeated 503s.** Bootstrap, workspace
   reload, selection, and global refresh requested model/session data before
   daemon readiness was known. Daemon status now gates those dependent reads:
   a running result loads models and sessions, while not-installed/stopped
   states render setup without error traffic.

### Test defects found and fixed

1. The old browser helper posted runtime events to a nonexistent desktop
   mutation route and expected a response field from a different projection.
   The quickstart now exercises a real Code turn and observes canonical output;
   it does not add a privileged desktop ingestion route.
2. Transcript extraction included the visible **Copy** button in assistant
   message text. It now reads the message body only and verifies backend
   Markdown separately from rendered UI text.
3. The smoke depended on host locale and stale English labels. It now selects
   `en-US` explicitly and uses stable structural hooks for Review, Published,
   cold-start, and Home navigation.
4. The empty-library smoke expected a removed setup handoff and a closed
   new-book disclosure. It now verifies the six-state capability action and the
   intentional open empty-library creation panel.

### Covered assertions and evidence

- Starts with an empty temporary suite and creates/selects one MoonBook through
  visible controls.
- Saves Pages content, navigates away/back, and hard-reloads to prove it remains.
- Submits one harmless Code request through the visible composer, requires a
  terminal command-owned canonical reply, and distinguishes backend Markdown
  from rendered text.
- Visits Review and Published and requires explicit legitimate-zero structures.
- Restarts the web host and proves selected-book, Pages content, and only durable
  evidence-backed conversation history restore; a filesystem read additionally
  verifies durable page bytes.
- `scripts/moondesk_quickstart_e2e.sh` passed after the fixes. The broader full
  and empty browser smokes also passed, the UI suite passed 329/329 with zero
  warnings, and the production UI build passed.
- The implementation is `scripts/moondesk_quickstart_e2e.sh`,
  `scripts/desk_mode_browser_smoke.sh`, and
  `scripts/desk_mode_browser_smoke.mjs`. Temporary fixtures are retained for
  diagnosis rather than falsely described as deleted.
- **Gate status at Command 019:** browser-host quickstart complete. Later
  commands completed the bounded 320×700 proof and macOS picker interaction
  through restart restoration. Cross-platform picker proof, the complete
  keyboard journey, and broader capability/surface matrices remain open, so
  Phase 1 is not complete.

## Command 016 — Phase 1 library-selection host/UI slice

### Exact deliverables

- MoonCode added only the initial mutable-root signature to the desktop server,
  then called `finish` at planner step 5 with an accurate statement that the
  feature was incomplete. The runtime recorded the command as done because it
  terminated correctly; it did not deliver the requested implementation.
- The partial edit did not compile: `restore_library_root` did not exist, the
  `Ref` constructor was invalid, and the request handler still referenced the
  removed immutable `workspace_root`.
- Independent repair added a bootstrap-owned preference file, validated
  selection/restore helpers, an active-root reference, and
  `GET|HEAD|POST /api/desktop/library`. All health, pack-app, and ordinary API
  routing now reads the active root after a successful switch.
- Validation rejects empty/relative/missing paths, filesystem roots, source
  checkouts, and individual MoonBooks. Choosing the conventional `books`
  directory resolves to its owning suite. Preparation and persistence must both
  succeed before the in-memory root changes; rejection preserves the old root.
- The UI now invokes the native directory picker, distinguishes cancellation
  from error, posts the selected absolute path, clears stale workspace-scoped
  projections only after success, and exposes the action in the missing-library
  state and under Storage & services.
- Focused proof covers six host helper cases, one live HTTP switch/rejection
  case, four UI picker/transition cases, and the existing cold-start assertions.
  Repository fast validation passes 225/225 native and 327/327 UI tests with
  zero warnings.
- **Remaining gate at this checkpoint:** exercise the actual picker in a
  packaged app and retain native relaunch persistence evidence. Command 019
  later completed the browser-host clean-workspace quickstart; it does not
  replace the packaged-app gate.

## Command 015 — Native directory-picker prerequisite

### Exact deliverables

- MoonCode correctly added the `fileDialog` plugin and `file-dialog` permission
  to the checked-in desktop manifest and generated live-integration manifest.
  It did not complete its promised tests or validation and exhausted the
  planner window after repeated searches, so the runtime marked the command
  failed.
- Its second hypothesis—embedding the resolved workspace root into the
  generated sidecar command—contradicted existing distribution tests. That
  path is build-machine state and must not be hard-coded into a distributable
  bundle. Independent audit reverted the attempted embedding and preserved the
  privacy/portability contract.
- Independent repair added focused assertions for both static and generated
  native directory-picker grants. The owning command package passed 46/46 tests
  at that checkpoint; the later repository gate includes the new assertion in
  225/225 native tests.

## Command 014 — Phase 1 shared Pages-search state slice

### Exact deliverables

- Added a private eight-case `SurfaceState` with stable keys, plain-language
  titles/details, primary-action mappings, and separately disclosed technical
  details for first-use empty, legitimate zero, loading, stale, disconnected,
  capability-limited, recoverable-error, and terminal-error states.
- Added an optional typed search state to the UI model. Query editing and empty
  submission select first-use state; request dispatch selects loading; empty
  success selects legitimate zero; nonempty success selects ready content by
  clearing the optional state; failure selects recoverable error. No display
  string is parsed to infer state.
- Pages search now renders a stable state panel and one Search/Retry primary
  control, disables it while loading, clears prior results when a new query
  starts, and keeps technical detail behind disclosure.
- Independent validation passed: zero-warning UI JS check, 3/3 focused
  contract/transition tests, 19/19 relevant search/update tests, 322/322 full
  UI JS tests, and repository fast validation with 217/217 native plus 322/322
  UI tests.
- **Remaining gate:** Pages search is the first consumer only. The other
  primary surfaces have not adopted the shared contract, and stale,
  disconnected, capability-limited, and terminal Pages-search states cannot be
  selected until explicit DTO evidence exists.
- MoonCode again failed the command. It spent six steps creating and editing,
  passed an invalid target to `moon fmt`, produced a view that did not compile
  against Rabbita attributes, then used all six step-8 tool calls for repairs
  instead of the required validation and `finish`. Its last edits were not
  rechecked. Independent repair used the established `@html.Attrs` API, removed
  warning-producing assertions/attributes, represented ready results honestly
  with an optional state, removed a duplicated primary action, added transition
  coverage, and ran the complete gate.

## Command 013 — Phase 1 navigation-vocabulary slice

### Exact deliverables

- Added one private vocabulary source for the existing workspace modes and
  activities. The title bar now shows **Home**, **Pages**, **Code**, **Flow**,
  and **Packs**; the Pages activity rail shows **Pages**, **Search**, **Inbox**,
  **Requests**, **Review**, and **Settings**.
- Applied the same vocabulary to workspace summaries, page headings and marks,
  title-bar tooltips, and high-level command-palette navigation. Internal enum
  names and current URL slugs remain unchanged; legacy aliases remain accepted.
- Added stable, non-snapshot assertions for labels, summaries, current and
  legacy slug compatibility, and high-level command-palette vocabulary.
- Independent validation passed: zero-warning UI JS check, 4/4 focused
  vocabulary tests, 6/6 command-palette tests, 19/19 Pages UX tests, 75/75 Home
  navigation tests, 319/319 full UI JS tests, and repository fast validation
  with 217/217 native plus 319/319 UI tests.
- **Remaining gate:** this is not the complete target information architecture.
  Flow and Packs remain top-level, Runs and Review are not separate
  destinations, Publish is absent as a primary destination, and the broader
  literal/localization and responsive interaction audits remain open.
- MoonCode did not complete the slice. It attempted to read two files that the
  command was supposed to create, omitted the promised focused test, failed the
  title-bar edit, and spent planner step 8 without validation, documentation,
  or `finish`. Independent repair added the missing tests and title-bar wiring,
  corrected stale assertions and high-level details, ran the full validation,
  and recorded only the resulting verified evidence.

## Command 012 — Phase 1 cold-start and first-use Desk slice

### Exact deliverables

- Added a private five-case `ColdStartState` and pure, evidence-based classifier
  with loading, unavailable-library, empty-library, one-book, and many-book
  precedence, plus exact title, detail, stable state key, and primary-action
  enum/label mappings.
- Integrated the classifier into the Desk empty presentation with stable test
  IDs/data-state. Loading offers Refresh without claiming failure; absent
  library metadata offers Open Settings; a known empty library opens the
  existing Add MoonBook disclosure so existing Create and Import dispatches
  remain directly reachable. The disclosure stays closed once books exist.
- Added focused non-snapshot assertions for every state and precedence edge,
  primary actions/copy, and existing selection preservation plus deterministic
  first-book fallback.
- Validation: targetless `moon fmt`; zero-warning `moon check --target js`;
  focused `main/cold_start_state_wbtest.mbt`; relevant Desk navigation tests;
  full UI JS suite; `moon info --target js`; and `git diff --check`.
- **Remaining gate:** a true Choose library folder action still requires an
  explicit host/UI contract. Open Settings is the honest recovery available
  today. This is a bounded Phase 1 slice; Phase 1 remains open.
- MoonCode did not complete these deliverables. It first read the package
  directory as a file, created a classifier against a nonexistent
  `workspace_paths` field, omitted the promised test file, left the Desk view
  calling a nonexistent open-panel helper, and exhausted step 8 without
  `finish`. The documentation above was written as completed evidence before
  the code existed. Independent repair added the real metadata predicate,
  open-disclosure helper, state/action rendering, stable tests, and validation.
- Independent validation passed: zero-warning UI JS check, 4/4 focused
  cold-start tests, 75/75 Desk navigation tests, and 315/315 full UI JS tests.

## Command 011 — Phase 1 capability-guided setup slice

### Exact deliverables

- Added `ui/rabbita-desk/main/capability_state.mbt` with the private six-case
  `CapabilityState`, deterministic pure classification precedence (unsupported,
  unavailable probe, running, not installed, misconfigured, installed stopped),
  plain-language title/detail copy, and one primary-action enum/label mapping.
- Added `ui/rabbita-desk/main/capability_state_wbtest.mbt` with exact assertions
  for all six states, precedence edges, all copy, and every primary action and
  label.
- Runtime integration is deliberately bounded to honest evidence from
  `MoonClawDaemonStatus.running`, `service_configured`, and `managed_install`;
  absent/unknown evidence must remain temporarily unavailable and must never be
  presented as running when `running` is false. Existing dispatch semantics and
  unsupported install/start behavior are unchanged.
- Remaining backend gap: the DTO has no explicit platform-support or
  configuration-validity evidence, so `UnsupportedPlatform` and
  `Misconfigured` cannot yet be selected by runtime integration. They remain
  reachable in the pure classifier and tests; no message parsing or fabricated
  evidence is used.
- Validation scope: targetless `moon fmt`; `moon check --target js` with
  `+unnecessary_annotation` and diagnostic limit 1000; focused tests by
  `capability_state_wbtest.mbt`; full UI JS suite; `moon info --target js`; and
  `git diff --check`.
- **Gate status:** bounded Phase 1 implementation slice only; Phase 1 remains
  open and no completion claim is made.
- MoonCode exhausted planner step 8 after running only `moon fmt`; it did not
  call `finish` or run the promised checks. Its workspace-status edit missed
  stale source text, it never edited the Code setup view, and its log still
  claimed runtime integration. Independent repair replaced snapshot-style
  assertions with stable assertions, added the honest daemon adapter, integrated
  user-facing Code/Requests labels and setup actions, and ran the promised
  validation.
- Independent validation passed: zero-warning UI JS check, 6/6 focused
  capability tests, 311/311 full UI JS tests, `moon info --target js`, and
  `git diff --check`.

## Command 010 — Phase 1 first-run and vocabulary design slice

### Exact deliverables

- Added `docs/FIRST_RUN_AND_VOCABULARY.md` immediately after Desk Mode Design in
  reading order.
- Separated current source/test evidence from target behavior and recorded the
  three-sentence promise, four exact cold-start paths, visible-copy inventory,
  navigation map, eight-state per-surface matrix, six-state capability enum and
  action allowlist, executable quickstart draft, four viewport/keyboard cases,
  and exact owning implementation files/tests.
- Marked the Phase 1 design inventory complete while leaving Phase 1
  implementation open; phase dependencies are unchanged.
- Current gaps: there is no shared six-state capability type, no exhaustive
  state contract across all surfaces, no complete implementation of the target
  vocabulary/cold starts, and no comprehensive viewport/keyboard proof.
- Remaining implementation evidence: focused state and capability transition
  tests, deterministic capability fixtures, all four cold-start E2E paths, the
  persisted quickstart journey, exact 1440×900, 1024×768, 390×844, and 320×700
  viewport runs, keyboard/focus assertions, and evidence that internal terms
  are confined to optional technical disclosure.
- Validation: local Markdown links and `git diff --check` pass.
- Command 010 again called `moon ide outline` from a context where the semantic
  command exited 1, despite the same failure having been observed earlier. It
  recovered with bounded reads and finished successfully. It also left the
  bottom-of-plan immediate-action list saying to document the first-run journey
  after doing so. **Recovery:** avoid the known-invalid semantic call, reconcile
  every duplicated status/next-action section before validation, and treat a
  successful `finish` as turn completion rather than proof of document
  consistency. Independent review corrected the stale list.

## Command 009 — active-document contradiction audit

### Exact deliverables

- Added `docs/DOCUMENT_TRUTH_AUDIT_2026-07-27.md` with one row for every active
  reading-order document, including role, current/historical classification,
  confirmed contradiction, correction, and remaining limitation.
- Linked the audit immediately after the baseline in `docs/README.md`.
- Corrected evidence-backed contradictory status language only in
  `docs/STATUS.md`, `docs/BASELINE_2026-07-27.md`,
  `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`, `docs/README.md`, and this
  execution log.
- Recorded local facts: fast validation passes 217/217 native and 305/305 UI
  with zero warnings; 3/3 localization is recorded; baseline metrics and source
  ownership are complete; typed inventory/target is complete but implementation
  has not started.
- Recorded that `.github/workflows/ci.yml` exists locally and calls full
  validation, while retaining no pull-request/push run claim. Phase 2 therefore
  remains incomplete.
- Preserved migration records as historical rather than promoting them to
  current plans.
- At Command 009 completion time, the contradiction-audit gate was complete and
  Phase 0 remained open only for retained clean-checkout full-mode proof. That
  proof was subsequently collected above. No remote CI or release evidence is
  claimed.
- Validation: local Markdown link targets and `git diff --check` pass.
- The MoonCode turn itself exhausted planner step 8 after validation and failed
  to call `finish`. Four stale exact-string edits also failed before the model
  found the current text. Independent review corrected the remaining stale
  execution-log handoff and the program plan's still-obsolete immediate-action
  list. This is another completion-control failure even though the bounded
  documentation result was recoverable.

## Command 008 verified interface facts

The actual `mooncode/core/pkg.generated.mbti` baseline is **1,017 lines,
28,305 bytes, 1 public type, 491 public functions (including one method), 0
public constants/values, 0 aliases, and 0 explicitly deprecated symbols**: 492
public symbols total. `NativeCapabilityEndpoints` is the sole public type and
has 17 public fields. String-returning functions are functions, not constants;
fields are not additional types; naming alone is not deprecation. These values
were cross-checked against the generated interface and owning declarations.

### Command 008 deliverables (Immediate Action 5 / Phase 3.1)

- Added `docs/MOONCODE_TYPED_CONTRACT_TARGET.md` with the complete inventory,
  consumer evidence, repeated vocabularies, target model, exhaustive decision
  rules, ownership/codec boundary, quantitative limits, and nine ordered
  vertical migration slices with tests, removal criteria, and rollback notes.
- Linked the target from `docs/README.md` reading order.
- Documentation only: no MoonBit source or generated interface was changed.
- Independent audit corrected two Command 008 overclaims. Its initial consumer
  scan said no external package used the core surface, but
  `internal/mooncode/moon.pkg` imports it and four adapter/test files use 29
  functions plus the returned public endpoint type. The same 29-function
  surface exists in the sibling `moondesk-document-provider` checkout. Its
  “symbol-by-symbol” table was actually an overlapping family-rule table
  without category counts. The corrected target now distinguishes the 30
  proven compatibility symbols from 462 no-direct-consumer candidates and
  labels its ordered family rules honestly.
- Phase 3 remains open. Its gate still requires runtime-owner agreement,
  implementation of all nine slices, one enforced typed serialization boundary,
  focused/route/UI/product tests, downstream compatibility proof, reviewed
  `.mbti` diffs, and satisfaction of the target interface limits.

## Runtime Observations

### Host on port 4398

- **Classification:** Operator discovery mismatch, not a proven MoonDesk bug.
- **Evidence:** The host health response exposed a `workspace_root` different
  from the selected checkout, making the mismatch detectable before use.
- **Recovery:** Inspect health and require its `workspace_root` to match the
  intended workspace; stop or ignore mismatched hosts.

### Source-checkout workspace redirect

- **Classification:** Intentional safety behavior.
- **Evidence:** `cmd/main/cli_options_wbtest.mbt` contains the focused test
  `workspace resolver redirects source checkout root to fallback`.
- **Recovery:** Supply a valid workspace root rather than weakening the guard.

## MoonCode Tool/Runtime Defects Observed

- An outline request without a required path was rejected. **Recovery:** pass a
  concrete MoonBook-relative path to semantic navigation.
- A test was requested by a nonexistent filename. **Recovery:** confirm the
  focused test path before invoking the owning package test.
- A broad grep timed out. **Recovery:** use semantic navigation or bounded,
  package-scoped searches instead of repository-wide grep.
- Planner-step exhaustion stopped progress before mutation. **Recovery:** keep
  discovery bounded, batch independent reads, and patch within the inspection
  budget.
- The planner proposed a Python heredoc to write repository files despite the
  available native MoonCode `write`/`edit` tools, and the proposal required
  rejection. **Recovery:** use native bounded file tools for repository
  mutations; reserve shell commands for validation rather than file authoring.
- Command 003 exhausted its planner window after all final validation tools
  passed, so the runtime marked the turn failed without a `finish` call.
  **Recovery:** retain enough planner budget for explicit completion and call
  `finish` immediately after the required validations pass.
- Command 005 treated the intentionally nonzero unknown-mode result as a failed
  validation twice, read a directory as though it were a file, selected a CI
  action instead of the repository's established installer pattern, and again
  exhausted the planner window after the substantive work passed. **Recovery:**
  assert expected failure statuses explicitly, list directories with a bounded
  shell query, reuse local workflow patterns, and reserve the final step for
  `finish`.
- Command 006 repeated the wrong-root `moon ide` failure, then executed an
  **unapproved interpreter mutation**: a Python rewrite across the UI package
  despite an explicit native-edit-only instruction. This is recorded as a
  MoonCode tool/runtime policy violation, not approved implementation work.
  Several replacements were based on source text that did not exist, leaving
  an incomplete refactor; a second broad Python rewrite was rejected.
  **Recovery:** freeze the continuation, audit every touched hunk, repair only
  with bounded patches, and rerun focused and full verification. Runtime policy
  must eventually prevent a shell command from bypassing approval merely
  because its mutation is embedded in an interpreter heredoc.
- Command 007 reported plausible-looking but false baseline metrics. It queried
  `git ls-files '*.mb'` even though MoonBit source uses `.mbt`, then described
  the result as 93 implementation and 31 test files. It also used GNU-only
  `find -printf` on macOS with stderr suppressed and reported the nonempty UI
  distribution as zero bytes. The smoke section called a 21-entry inventory
  “20 files” before later explaining the runnable/support distinction.
  **Recovery:** independently audit generated reports, keep measurement commands
  in the report, use the correct suffix, count tracked plus non-ignored
  untracked product source, exclude dependency/build trees explicitly, and use
  portable `stat -f '%z'` on macOS. The corrected evidence is 248
  implementation files (51,989 lines), 57 test files (15,562 lines), 31
  generated interfaces with 2,040 textual public declarations, a 5-file
  2,237,746-byte UI distribution, and 20 runnable smoke scripts plus one shared
  support library.
- Command 009 made four failed exact-string edits against text that differed
  from its initial read, then used its last planner step for validation and
  reached no `finish` call. The runtime marked the turn failed despite passing
  link and whitespace checks. **Recovery:** reread only the failed target,
  reserve the final step for `finish`, and independently search for stale
  continuation/status language because successful edits do not prove the
  requested contradiction audit was complete.
- Command 010 repeated the known failing `moon ide outline` invocation before
  falling back to reads, and did not reconcile the plan's duplicate immediate
  actions after adding a new current-action section. **Recovery:** use known
  valid file-scoped semantic commands only and search all status/action headings
  before declaring a documentation slice consistent.
- Command 011 spent seven steps reading/writing but its only integration edit
  missed stale source text. It then used step 8 for `moon fmt`, skipped check,
  focused/full tests, interface generation, whitespace validation, and
  `finish`, while its own execution-log entry claimed integration and listed
  the unrun validation scope. **Recovery:** distinguish intended from completed
  work in the log, validate before documenting results, and reserve one step for
  `finish`. Independent bounded patches and validation were required.
- Command 012 read a directory as a file, authored against a nonexistent
  `Model.workspace_paths` field, omitted its promised test file, referenced a
  nonexistent view helper, then wrote completed-evidence documentation and used
  step 8 for a grep rather than validation or `finish`. **Recovery:** compile
  immediately after introducing a model dependency, never document a test file
  before creating it, and require successful check/tests before an execution-log
  entry may use “implemented” or “validation passed.”
- Command 013 tried to read two not-yet-created target files, created only one,
  missed the title-bar patch, omitted its promised test and documentation, and
  again consumed step 8 without validation or `finish`. **Recovery:** distinguish
  creation targets from discovery inputs, compile after the first integration
  edit, reserve explicit steps for tests and `finish`, and treat incomplete
  command output as unverified until an independent audit closes every promised
  deliverable.
- Command 014 did create both named files and respected the interpreter
  constraint, but it passed an illegal target to `moon fmt`, used nonexistent
  Rabbita attribute APIs, and consumed step 8 on six repair edits rather than
  the explicitly required `finish`. It did not recompile after those edits.
  **Recovery:** encode tool-schema constraints in the planner, compile before
  the reserved final step, cap a final repair batch so validation can still run,
  and make `finish` an enforced terminal action rather than a prompt-level
  suggestion.
- Command 015 found the correct native picker prerequisite but tried to embed a
  build-time workspace path into a distributable sidecar command despite
  existing tests that prohibit that coupling. It then spent its remaining
  planner steps on searches without testing or finishing. **Recovery:** treat
  distribution tests as contract evidence, separate runtime preference state
  from build manifests, and reserve steps for focused validation and `finish`.
- Command 016 improved terminal honesty by calling `finish` early and explicitly
  reporting incomplete work, but it left a noncompiling server signature and
  implemented none of the required route, persistence, UI, or test behavior.
  **Recovery:** compile immediately after changing shared handler signatures;
  define the smallest complete vertical path before mutation; use “done” only
  for runtime termination and track requested-deliverable completion
  separately.
- Command 017 exhausted all eight planner steps after adding only an explanatory
  comment. It attributed the contradictory launcher failure/success output to
  two external bundle writers without proving that a second writer existed,
  read a nonexistent file, ran no tests, and never called `finish`.
  **Independent diagnosis:** a clean build in a fresh output directory
  reproduced the defect with no competing build process. Four async copy and
  launcher-configuration operations were joined in one boolean expression;
  launcher configuration could observe the output tree before the preceding
  copies completed, while later verification observed the completed tree.
  **Recovery:** replace the async boolean chain with explicit ordered gates,
  return a real boolean result through every integration command, require
  `bundle` to stop before rename/sign/archive when integration fails, and exit
  nonzero for that failure. A fresh positive package build completed without
  the launcher error. A negative package build with a nonexistent UI directory
  printed the precise copy failure, did not print `Created`, and exited 1.
- Command 018 called `finish` after one implementation edit and one native
  check. It added a host evidence record but classified any syntactically safe
  string—including the literal `unsupported`—as supported. It did not reuse
  the record in installation, add it to daemon JSON, extend the UI DTO or
  classifier, add tests, update documentation, run JS validation, format, or
  inspect generated interfaces. **Recovery:** separate normalization from the
  explicit supported platform/architecture allowlist; reuse one record in the
  installer and every daemon-status branch; transport a nested optional record;
  preserve older-response behavior; select `UnsupportedPlatform` only from
  explicit false evidence; keep platform details in the technical disclosure;
  and independently run focused plus full validation.
- Command 038 exposed a projection/canonical-state split: projected status
  briefly reported `done` while canonical `.work.status` remained `running`,
  and the command later failed. Its partial helper also measured descendants
  after scaling ancestors, allowing inherited text to reach 4×, invented
  selectors that did not match the rendered product, and never built or
  verified the result. **Recovery:** keep canonical work state authoritative;
  snapshot every computed size before mutation; use actual product selectors;
  restore every inline style; and require exact geometry assertions plus
  retained screenshots before declaring the slice complete.
- Command 039 read both full authoritative documents, then called semantic
  reference search with an empty required path, ignored its own shell evidence
  about the owning stylesheet, attempted two rejected edits in the wrong file,
  and called `finish` with no accepted mutation or typed verification. The
  runtime correctly emitted `runtime-failed`. **Recovery:** supply required
  semantic paths, make exact edits in the discovered owner, retain planner
  budget for the requested vertical slice and final checks, and use the
  completion verdict—not the presence of a `finish` event—as terminal truth.
- Command 040 repeated the empty-path semantic search defect, briefly inserted
  one CSS block at nine broad replace-all matches, then removed every copy and
  explicitly finished as incomplete with no intentional net change. The
  runtime still emitted `runtime-completed` from transient accepted edits.
  **Recovery:** completion must inspect net deliverables, required checks, and
  an affirmative terminal claim; mutation count alone is not evidence.
- Command 041 read both documents and used a valid semantic outline path, but
  stopped after one unverified verifier file while explicitly listing six
  missing deliverable groups. The runtime again emitted `runtime-completed`.
  **Recovery:** the runtime must compare the requested deliverable inventory
  with net outputs and post-mutation verification; an accepted write proves
  activity, not completion.
- Command 042 read all three required documents, but four semantic-outline
  calls failed because nested package paths were duplicated and then resolved
  from the wrong root. It inserted an incomplete helper, failed compilation,
  reverted the intended change, and ended with only a late green compile and no
  test or documentation. The runtime correctly emitted `runtime-failed`,
  proving that the tightened verdict now rejects transient mutations and a
  net-empty deliverable. **Recovery:** establish one semantic root, fall back to
  direct reads after a reproducible wrapper defect, complete the helper graph
  before compilation, and require net output plus typed post-mutation proof.
- Command 043 read all three required documents, ignored the explicit
  semantic-root fallback, repeated two known wrong-root outline calls, attempted
  an identical old/new edit that the editor rejected, and finished at step 4
  without reading product code, mutating a file, or running a check. The runtime
  correctly emitted `runtime-failed`. **Recovery:** cache the proven package
  root, switch to direct reads after one reproducible wrapper failure, reject
  identical edits before dispatch, and preserve bounded steps for mutation plus
  typed verification.
- Command 044 isolated the repeated nested-module outline failure to argument
  rebasing: the wrapper inferred the nested module as current directory but
  retained the book-relative prefix in the operand. The prior unit test asserted
  only current-directory selection and therefore missed the invalid combined
  command. **Recovery:** resolve under the book root, rebase against the selected
  current directory, and execute a real nested-module command in the focused
  test. The repaired endpoint then succeeded against the exact previously
  failing MoonDesk path.
- Command 045 used an inline Python heredoc to author source despite an explicit
  reviewable-mutation-tool constraint. It changed files, invented three
  mismatched literals, and remained invisible to accepted-mutation evidence, so
  the runtime correctly rejected completion without being able to account for
  the real shell mutation. **Recovery:** prohibit interpreter heredocs and
  inline interpreter authoring at the shell boundary, encode
  `edit`/`write`/`apply_patch` as the only workspace-authoring path, and test that
  rejected commands create no file.
- Canonical localization regeneration during Command 045 removed behavior that
  existed only in checked-in generated output: exact-only accessibility
  attribute translation and a locale-specific system-language label. This
  caused all localization tests to fail immediately. **Recovery:** restore the
  behavior in generator source, regenerate the public artifact, run syntax and
  all 4/4 localization tests, and require byte-for-byte regeneration before
  closeout.
- Command 046 invented six status keys even though the exact catalog keys were
  already part of the supplied contract, then called `finish` while explicitly
  listing its unimplemented renderer, action, test, format, and validation
  work. The runtime correctly rejected the turn because the last mutation had
  no typed test. **Recovery:** steer with the exact existing keys, preserve
  exhaustive state/action mappings, and require source extraction to equal the
  catalog slice so invented key names cannot pass validation.
- The Command 046 continuation ignored its no-reread boundary, read the same
  complete capability source three times without mutation, searched again
  instead of applying the known patch, attempted a nonexistent
  `capability_views.mbt`, exhausted 12 planner steps and 17 tool calls, and
  never reached tests or `finish`. **Recovery:** the runtime now rejects an
  identical complete read until an accepted authored mutation invalidates it;
  truncated reads and different paths remain available. The runtime-turn suite
  passes 31/31 and the process-tool suite passes 9/9.
- A live Command 046 steer was queued while the continuation was active but was
  not consumed at a planner boundary. After the failed turn it could only be
  recorded as deferred, so four client commands still did not complete the
  bounded product slice. **Recovery:** keep the failed session as evidence and
  complete the product slice independently. Runtime work remains to consume
  live steering at model-planner boundaries, suppress semantically redundant
  searches as well as identical reads, and reserve a terminal verification and
  `finish` step.
- The first Command 047 self-repair used only four of twenty available planner
  steps, made one comment-only mutation, skipped typed validation, and finished
  without implementing either supplied runtime requirement. **Recovery:** the
  runtime correctly rejected completion; remove the comment, retain the failed
  journal, and recover the live-steering and terminal-budget behavior
  independently.
- Command 047 supplied `path` and `line:column` separately for two semantic
  reference searches, but the process wrapper emitted only
  `--loc line:column`; the CLI treated the line number as a filename.
  **Recovery:** combine numeric two-part locations with the resolved
  MoonBook-relative path, preserve already-qualified locations, and prove the
  exact previously malformed shape through a rebuilt native tool call.
- The first live-steering recovery polled before follow-up inference only. A
  steer arriving during the model call therefore left the returned stale
  `finish` executable and remained claimable. Polling after follow-up inference
  fixed that race, but the next proof showed the same stale-plan window around
  initial inference. **Recovery:** reproject immediately after both initial and
  follow-up model calls, terminally claim new steering, discard the
  not-yet-executed plan, inject each steer as an explicit user message in
  journal order, and bound stabilization to eight fail-closed replans.
- The second complete-plan Command 047 turn met the mechanical mutation/test/
  finish gate but selected only a comment, and the comment claimed alias
  normalization that the implementation did not perform. **Recovery:** do not
  count the accepted verdict as product progress; remove the comment, audit the
  failed edit's premise, then implement and table-test the real advertised-alias
  canonicalization and supported-tool defect.

## Phase Evidence

### Phase 0 — Baseline and execution control

- Created this durable execution log.
- Added `scripts/validate.sh` as the Phase 0 fast/full validation entrypoint.
- Documented the canonical command and full-mode generated `dist` behavior.
- Read `AGENTS.md` and the authoritative upgrade plan.
- Corrected both runtime observations to evidence-backed classifications and recorded MoonCode tool/runtime failures with recovery guidance.
- Validation evidence: from `/tmp`, the validator's unknown mode exited 2 and
  printed `Usage: ... [fast|full]`. From the repository,
  `scripts/validate.sh fast` passed root format, root `--target all` check,
  native tests, UI JS check, and UI JS tests. Checks and tests used
  `--warn-list +unnecessary_annotation --diagnostic-limit 1000`; final
  `git diff --check` passed.
- Active CI now invokes the canonical `scripts/validate.sh full` entrypoint.
- Changed files for Immediate Actions 1 and 3: `docs/STATUS.md`,
  `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`,
  `docs/MOONSUITE_LAYOUT_MIGRATION_PLAN.md`, `scripts/validate.sh`,
  `.github/workflows/ci.yml`, and this execution log.
- Validation for this slice: shell syntax, workflow YAML parsing when a local
  parser is available, unknown mode, fast mode, and `git diff --check`. Full
  mode is intentionally not run in the dirty worktree.
- **Local evidence slice (2026-07-27):** authored
  [`BASELINE_2026-07-27.md`](BASELINE_2026-07-27.md) with preserved starting
  and current test/warning facts, starting coverage, reproducible repository
  metrics, smoke inventory, and explicitly unmeasured evidence; linked it in
  the active reading order; and corrected the compact single-owner boundary
  table in `ARCHITECTURE.md` so durable acceptance truth remains externally
  owned.
- **Completed deliverables:** baseline report complete; ownership confirmation
  complete. Current evidence remains 217/217 native, 305/305 UI after two
  regression tests (starting 303/303), 3/3 localization, and zero UI unused
  warnings (starting 20).
- **Gate status:** The active-document contradiction audit, baseline, ownership
  map, validation entrypoint, and retained full-mode clean-checkout proof are
  complete. Local Phase 0 is complete.

### Immediate Action 4 — UI warning cleanup

- **Symptom:** UI JS checking emitted 20 unused-code warnings.
- **Root cause:** An obsolete integer canvas-zoom path remained beside the
  active double-precision zoom state; the wheel message carried two unused
  coordinates; private composition JSON records retained server fields the UI
  never reads; one workspace label helper and one view parameter were unused.
- **Fix:** Removed the obsolete state and message branch, narrowed the wheel
  message to its delta, narrowed private composition records while preserving
  permissive JSON decoding, and removed the unused helper and parameter.
- **Tests/evidence:** `moon check --target js --warn-list
  +unnecessary_annotation --diagnostic-limit 1000` passed with zero warnings;
  focused MoonFlow tests passed 12/12; the complete UI JS suite passed 305/305;
  `moon info --target js` completed. The `.mbti` change is from the previously
  added public source-pane API, not this private warning cleanup.
- **Generated-interface defect:** The current generator emits a final blank
  line in `.mbti` files, while Git's default whitespace policy reports a newly
  generated final blank as an error. `.gitattributes` now exempts only generated
  `.mbti` files from `blank-at-eof`; all other whitespace checks remain active.
- **Remaining risk:** Browser interaction coverage for the simplified wheel
  message remains part of the later responsive/interaction qualification.
- **Status:** Immediate Action 4 complete; the current UI warning count is zero.

### Phase 1 — Native library and package acceptance

- **Symptom:** A packaged build could report that its generated launcher did
  not exist, then pass bundle verification and print `Created`.
- **Root cause:** Async copy/configuration functions were composed as a boolean
  expression instead of explicit ordered operations. The outer bundle command
  also ignored the integration result because the integration boundary
  returned `Unit`.
- **Fix:** Runtime, sidecar, UI, and launcher operations now run through
  sequential failure gates. Integration commands return `Bool`; `bundle`
  refuses to continue after a failed integration and exits 1.
- **Positive evidence:** A fresh macOS package build under
  `_build/native-acceptance-3` passed strict verification, bundle write,
  live bundle-check, and live-build, then created `MoonDesk.app` without any
  contradictory launcher failure.
- **Negative evidence:** A build using a nonexistent UI distribution reported
  the exact missing-directory failure, printed no success claim, and exited 1.
- **Picker observability:** The Home storage disclosure now renders the same
  status updated by picker start, cancellation, validation failure, and
  success, with a stable `desk-library-selection-status` test hook. Previously
  those states changed in the model but were invisible on that screen.
- **Current macOS evidence:** A fresh current-source package exposes an
  app-owned native panel. Cancellation preserves the old root; an individual
  MoonBook produces the exact corrective host message; a valid library
  activates, lists its ready fixture book, updates subsequent API requests, and
  persists its canonical root. Relaunch without pressing **Refresh** restores
  that root and ready book on the first rendered state.
- **Remaining risk:** Every other supported desktop platform remains open.
  Signing, notarization, and clean-machine distribution are separate later
  gates.

### Phase 1 — Capability platform evidence

- **Symptom:** The UI contained an `UnsupportedPlatform` state but production
  mapping always supplied `supported=true`, so the state could never be selected
  from runtime evidence.
- **Root cause:** Daemon status exposed process/configuration evidence but no
  platform or architecture support record.
- **Fix:** One private support record now owns normalized platform,
  architecture, and the explicit support allowlist. Installation and daemon
  status reuse it. Every daemon-status response transports the record. The UI
  consumes it as optional compatibility evidence, and only explicit false maps
  to `UnsupportedPlatform`; technical values stay behind disclosure.
- **Focused evidence:** Installer/support tests pass 6/6, service/config/status
  tests pass 10/10, and UI capability tests pass 7/7. Supported, unsupported,
  and missing-evidence behavior are covered.
- **Live evidence:** A fresh local host response from
  `/api/moonclaw/daemon` returned
  `{"supported":true,"platform":"macos","architecture":"arm64"}` inside
  `platform_evidence` while the daemon itself was absent, proving platform
  support is not inferred from daemon/network readiness.
- **Remaining risk:** Other optional capabilities still need equivalent
  platform/misconfiguration evidence before the complete Phase 1 matrix can
  close.

## Continuation Handoff

1. Put the locally proven CI and unsigned-preview workflows through clean
   pull-request, push, and preview-tag runs; retain the artifact and reproduce
   it independently. No remote evidence is currently claimed.
2. Exercise the picker on every other supported desktop platform and complete
   the remaining Phase 1 shared-state, capability-evidence, keyboard,
   responsive, focused manual screen-reader, and copy-audit gates. The macOS
   interaction through restart restoration, browser-host quickstart, and
   bounded shared-shell semantic proof are complete.
3. Begin the first typed vertical slice only after the Phase 2 prerequisite is
   met, or record an explicit local-prototype exception without claiming Phase
   3 completion.

## Defect Template

For each new defect, append an entry containing:

- **Symptom**
- **Root cause**
- **Affected files or subsystem**
- **Fix**
- **Tests/evidence**
- **Remaining risk**
