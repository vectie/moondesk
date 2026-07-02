# MoonSuite Layout Migration Plan

This plan makes MoonSuite v2 the fresh default filesystem contract. There is no
legacy compatibility target for new writes: Moondesk should initialize and use a
MoonSuite root directly.

## Target Layout

```text
MoonSuiteRoot/
  books/
  inbox/
  exports/
  .tmp/
  .moonsuite/
    suite.json
    product-registry.json
    products/
      moondesk/
      moonbook/
      moonwiki/
      mooncode/
      moonclaw/
      moontown/
      moonstat/
      moonfish/
      moonmoon/
      moonrobo/
      bookkeeper/
      lepusa/
      rabbita/
      <future-product>/
    services/
    cache/
```

Durable user truth belongs outside `.moonsuite`. Internal product state belongs
inside `.moonsuite/products/<product>`. Disposable state belongs inside `.tmp`.

## Product Registry

`.moonsuite/product-registry.json` is the source of truth for installed Moon
products. Moondesk should discover products from this registry instead of
hardcoding a short product list in the UI or backend.

Each product entry uses this shape:

```json
{
  "id": "moonrobo",
  "name": "MoonRobo",
  "kind": "moon-suite-product",
  "state_path": ".moonsuite/products/moonrobo",
  "service_path": ".moonsuite/products/moonrobo/service.json",
  "repo_path": "",
  "status": "installed",
  "capabilities": []
}
```

Default products:

- `moondesk`
- `moonbook`
- `moonwiki`
- `mooncode`
- `moonclaw`
- `moontown`
- `moonstat`
- `moonfish`
- `moonmoon`
- `moonrobo`
- `bookkeeper`
- `lepusa`
- `rabbita`

## Shared Contract Layer

Decision: the shared MoonSuite contract layer belongs in MoonLib. MoonStat is
not the right owner because its job is observation, validation, metrics, and
drift reporting over live workspaces. Putting the contract in MoonStat would
make every product depend on an analytics/status product just to construct
paths, which is the wrong dependency direction.

MoonSuite filesystem contracts should be defined in `moonlib`, not `moonstat`.
`moonlib` is the shared source of truth for low-level suite layout contracts:
suite root discovery, product registry schema, product state paths, suite temp
paths, book paths, artifact classes, and typed path constructors. It must stay
dependency-light and deterministic so every Moon product can use it without
pulling in status, analytics, or daemon behavior.

`moonstat` should consume the `moonlib` contract layer. Its responsibility is to
audit live workspaces, report drift, index metrics/snapshots, and surface health
views. It can enforce that products follow the contract, but it should not own
the contract itself.

Phase 4.5 is now the active MoonLib-first contract extraction track running
alongside the remaining product-home migration:

1. Create the MoonSuite contract package in `moonlib`.
2. Move shared product ids, registry schema, and path constructors into that
   package.
3. Replace product-local string helpers with `moonlib` contract calls.
4. Make `moonstat` validate workspaces against `moonlib` contracts and report
   legacy-path drift.

This extraction is a migration requirement, not an optional cleanup. Product
repos may keep local helpers only as thin adapters around MoonLib while they are
being migrated.

Phase 4.5 started in MoonLib with `vectie/moonlib/moonsuite`, which defines
artifact classes, suite root paths, book paths, product-home paths, suite temp
paths, external-tool homes, suite manifest JSON, and product registry JSON. The
package is available through MoonLib `0.1.3`; that version adds both
book-root-derived and workspace-root-derived suite/product path constructors so
products can receive either `books/<book-id>` workspaces or standalone book
roots and still derive the correct owning suite product home. Moondesk depends
on MoonLib `0.1.3` and `internal/moonwiki/moonsuite_layout.mbt` is a thin
compatibility adapter over `@moonsuite` for suite root, book root, product-home,
workspace-root-derived product artifacts, manifest, registry, cache, and
service paths. Remaining product-local helpers should follow the same wrapper
pattern instead of carrying independent string contracts.
- MoonStat now depends on MoonLib `0.1.2` and consumes `@moonsuite` for its
  home `.moonsuite` state directory plus MoonClaw product-home provider, model,
  and config manifest paths. MoonStat also exposes `moonstat suite drift` and
  `/suite/drift` as a MoonLib-derived drift report over legacy `.moontown`,
  `.moonclaw`, repo-local runtime, old MoonStat state paths, MoonRobo product
  runtime paths, old global SDK E1 temp files, and book-local
  `.moonclaw/providers.json` / `.moonclaw/mooncode/sessions` drift under
  `books/<book-id>`. MoonStat remains an observer/reporter over the shared
  contract rather than the source of path definitions. Validation for the latest
  MoonStat slice: `moon fmt`, `moon info`, `moon check`, and `moon test` with
  `774/774` tests passing.
- MoonStat commit `26531ce` removes the remaining empty-root MoonSuite
  constructors from active suite/config defaults. MoonStat app config, suite
  status, MoonClaw provider/model/config manifest candidates, and suite
  integration commands now derive from the active workspace root or explicit
  workspace-root helpers, while `books/<book-id>` roots are tested to resolve to
  suite-level `.moonsuite/products/...` paths instead of nested book-local
  state. Validation for this slice: MoonStat `moon fmt`, clean `moon info`,
  `moon check`, `moon test` with `774/774` tests passing, and
  `git diff --check`.
- Moontown now depends on MoonLib `0.1.3` for book-root-derived and
  workspace-root-derived MoonSuite paths.
  PlanBook repair job indexes and proposal ledgers now resolve to
  `.moonsuite/products/moonclaw/jobs/...` through `@moonsuite`, MoonClaw store
  maintenance compacts that product-home job store, and PlanBook's MoonClaw run
  result reader passes the derived MoonClaw product home into the MoonClaw
  runtime instead of falling back to `cwd/.moonclaw`. Validation for this slice:
  `moon fmt`, `moon info`, `moon check`, and `moon test` in Moontown with
  `925/925` tests passing.
- The Moontown MoonBook adapter now derives MoonClaw provider manifests from the
  MoonClaw product home and MoonCode sidecar sessions from the MoonCode product
  home through `@moonsuite.product_artifact_for_book_root`, removing another
  book-local `.moonclaw` writer/reader pair. Validation for this slice:
  `moon fmt`, `moon info`, `moon check`, and `moon test` in Moontown with
  `926/926` tests passing.
- Moontown commit `ad205ae8` replaces the central storage helper's empty-root
  MoonSuite calls with MoonLib workspace-root adapters. The no-arg
  `moontown_product_*` helpers now derive from the active working directory,
  and new explicit `*_for_workspace_root` helpers prove that a
  `books/<book-id>` root resolves to the suite-level
  `.moonsuite/products/moontown` home rather than a nested book-local
  `.moonsuite`. Default runtime path tests now compare against storage-derived
  product artifacts instead of stale relative `.moonsuite/...` literals.
  Validation for this slice: Moontown `moon fmt`, `moon info`, `moon check`,
  `moon test` with `926/926` tests passing, and `git diff --check`.
- MoonBook now depends on MoonLib `0.1.3` and uses
  `@moonsuite.product_artifact_for_workspace_root` for MoonClaw extension
  provider manifests. This removes MoonBook's local standalone-vs-suite-root
  string logic while preserving both standalone roots such as `/tmp/wiki` and
  suite book roots such as `/tmp/suite/books/research-wiki`. Validation for this
  slice: MoonLib `moon fmt`, `moon info`, `moon check`, `moon test` with
  `35/35` tests passing and `moon publish`; MoonBook `moon update`,
  `moon fmt`, `moon info`, `moon check`, and `moon test` with `198/198` tests
  passing.
- MoonFish and MoonMoon now depend on MoonLib `0.1.3` for their root
  MoonSuite product-home facades. Their public product status contracts still
  expose product id, state, service, cache, temp, and accepted book-output paths,
  but those values now come from `@moonsuite.product_dir`,
  `@moonsuite.product_service_path`, `@moonsuite.product_artifact`,
  `@moonsuite.product_tmp_dir`, and `@moonsuite.book_artifact` instead of
  product-local string concatenation. Validation for this slice: MoonFish
  `moon update`, `moon fmt`, `moon info`, `moon check`, and `moon test` with
  `144/144` tests passing; MoonMoon `moon update`, `moon fmt`, `moon info`,
  `moon check`, and `moon test` with `143/143` tests passing.
- MoonFish commit `31dab53` and MoonMoon commit `b7027a9b` remove the active
  empty-root MoonSuite constructors from their root product-home facades. Both
  products now expose explicit `*_for_workspace_root` helpers for product state,
  service, cache, temp, accepted MoonBook output, and the aggregate product-home
  payload; suite-hosted book roots under `books/<book-id>` are tested to resolve
  to suite-level `.moonsuite/products/...` and `.tmp/products/...` paths while
  preserving standalone relative defaults. Validation for this slice: MoonFish
  `moon fmt`, clean `moon info`, `moon check`, `moon test` with `144/144` tests
  passing, and `git diff --check`; MoonMoon `moon fmt`, `moon info`,
  `moon check`, `moon test` with `143/143` tests passing, and
  `git diff --check` (`moon info`/`moon check` still report the pre-existing
  unused warnings in generated Noetix suite-preview evidence).
- MoonClaw now depends on MoonLib `0.1.3` for the model loader's MoonSuite
  workspace-root path derivation. Model and provider config loading now reads
  `models/models.json` and `moonclaw.json` from
  `.moonsuite/products/moonclaw` through
  `@moonsuite.product_artifact_for_workspace_root`, including suite-hosted book
  roots under `books/<book-id>`. The loader no longer treats nested
  `.moonclaw/models/models.json` as a fresh-default source, and server/model
  fixtures now seed the MoonSuite product home. Validation for this slice:
  MoonClaw `moon update`, `moon fmt`, `moon info`, `moon check`, and
  `moon test` with `994/994` tests passing.
- MoonClaw commit `b1af34b0` extends the MoonLib-backed product-home contract
  from model loading into provider manifests, job config discovery, ACP config
  discovery, gateway config discovery, provider tasks, external proposal
  packets, provider resource listing, and provider resource reading. Fresh
  default readers now derive `providers.json` and `moonclaw.json` through
  `@moonsuite.product_artifact_for_workspace_root`; legacy
  `.moonclaw/providers.json`, `.moonclaw/moonclaw.json`, and bare
  `moonclaw.json` fixtures remain only as negative/legacy-ignore test inputs.
  Validation for this slice: MoonClaw `moon fmt`, `moon info`, `moon check`,
  `moon test` with `995/995` tests passing, and `git diff --check`.
- MoonClaw commit `83d8ecae` removes the next active config-discovery fallbacks
  from ACP runtime, channel bootstrap, channel model resolution, plugin runtime,
  workspace runtime, security runtime, and onboarding runtime. These runtimes
  now derive `moonclaw.json` from the MoonLib workspace-root product-home
  constructor instead of accepting bare `moonclaw.json` or nested
  `.moonclaw/moonclaw.json` as fresh-default inputs. Security pairing and
  approval state now persists under
  `.moonsuite/products/moonclaw/security/state.json` instead of
  `home/security/state.json`. Validation for this slice: MoonClaw `moon fmt`,
  clean `moon info`, `moon check`, `moon test` with `995/995` tests passing,
  and `git diff --check`.
- MoonClaw commit `f7f2415e` routes the core job, ACP session, conversation,
  and daemon-lock product homes through MoonLib workspace-root helpers.
  MoonClaw homes and CWDs under `books/<book-id>` now resolve jobs,
  `acp_sessions.json`, conversations, and `daemon.json` into the suite-level
  `.moonsuite/products/moonclaw` home instead of a nested book-local
  `.moonsuite`. Provider task resolution now separates manifest discovery from
  workspace affinity, so suite-level job run paths can still select the
  workspace-affine provider target when the originating book root is carried in
  metadata. Validation for this slice: MoonClaw `moon fmt`, clean `moon info`,
  `moon check`, `moon test` with `1001/1001` tests passing, and
  `git diff --check`.
- MoonRobo commit `43621e82` removes the remaining empty-root MoonSuite path
  constructors from product status and SDK E1 bridge sidecar defaults. Product
  status now reports MoonRobo and MoonClaw product homes through explicit
  workspace-root adapters derived from the selected robot book root, and SDK E1
  snapshot/command defaults expose workspace-root helpers that map book roots to
  the suite-level `.tmp/products/moonrobo` temp lane. Validation for this slice:
  MoonRobo `moon fmt`, clean `moon info`, `moon check`, `moon test` with
  `453/453` tests passing, and `git diff --check`.

Migration rules from this point forward:

1. New MoonSuite path helpers belong in MoonLib first.
2. Moondesk, MoonClaw, Moontown, MoonBook, MoonFish, MoonMoon, MoonRobo,
   Lepusa, Rabbita, and Bookkeeper may keep local helpers only as adapters over
   MoonLib.
3. MoonStat may add diagnostics, reports, drift indexes, and health projections
   over the MoonLib contract, but must not introduce a competing layout schema.
4. Product migrations should include a local adapter test and at least one
   cross-product integration assertion from a fresh MoonSuite root.
5. If a product needs a path that is reused by more than one product or test
   fixture, add the typed constructor to MoonLib before adding product-local
   wrappers.

## Phase 1: Layout Helper

Add one MoonSuite layout helper and route all server paths through it.

- `books/` replaces the old hidden MoonBook library.
- `.moonsuite/products/moonclaw/service.json` replaces
  `.moontown/moondesk-daemon/moonclaw-service.json`.
- `.moonsuite/products/moontown/service.json` replaces
  `.moontown/moondesk-daemon/service.json`.
- `.moonsuite/products/moondesk/daemon` replaces
  `.moontown/moondesk-daemon`.

## Phase 2: Fresh Startup

Desk startup should initialize a chosen MoonSuite root:

1. Create `books`, `inbox`, `exports`, `.tmp`, and `.moonsuite`.
2. Create every default product folder.
3. Write `suite.json`.
4. Write `product-registry.json`.
5. Show the active MoonSuite root before Code/Wiki interaction begins.

Random temporary roots should not be the normal user workspace.

## Phase 3: VFS Default

The normal Desk VFS exposes:

- `books`
- `inbox`
- `exports`

The normal Desk VFS hides:

- `.moonsuite`
- `.tmp`

Advanced/debug mode may reveal `.moonsuite/products/*`.

## Phase 4: Product State Homes

Product state should be isolated by owner:

- `moondesk`: window state, preferences, recent suite roots.
- `moonbook`: book catalog, templates, book-level indexes.
- `moonwiki`: wiki search and link indexes.
- `mooncode`: sessions, command queues, handoff, evals.
- `moonclaw`: daemon config, runtime jobs, logs, sandboxes, tool state.
- `moontown`: standing goals, town messages, events, routing, scheduler state.
- `moonstat`: metrics DB, snapshots, analytics, embeddings and indexes.
- `moonfish`: workflows, market-data cache, chart state, reports, planning runs.
- `moonmoon`: terrain, scenes, simulations, generated clips, evidence.
- `moonrobo`: robot profiles, URDF indexes, mesh refs, gait, telemetry, sim runs.
- `bookkeeper`: review queue, acceptance decisions, policies.
- `lepusa`: native shell runtime and update metadata.
- `rabbita`: UI runtime and build metadata.

Accepted product output belongs in the owning book under `books/<book-id>`.

## Phase 5: Book Layout

Each book uses this durable layout:

```text
books/<book-id>/
  book.json
  wiki/
  code/
  raw/
  reviews/
  outputs/
  apps/
```

## Phase 6: API Rewrite

Rewrite these surfaces to use MoonSuite layout helpers:

- `/api/workspaces`
- `/api/workspaces/metadata`
- `/api/workspaces/*`
- `/api/mooncode/*`
- `/api/moonclaw/*`
- `/api/town/*`
- `/api/books/*`

MoonClaw and Moontown errors must be explicit. They should not silently queue
forever when a required service is missing.

## Phase 7: UI Update

Desk should show:

- Active MoonSuite root.
- Book list from `books/`.
- Selected book.
- Product/service status.
- Clean Code conversation stream.

Normal UI should avoid exposing hidden internal paths.

## Phase 8: Test Gates

Minimum test gates:

1. Layout unit tests for every canonical path.
2. Bootstrap tests for complete fresh MoonSuite creation.
3. Workspace API tests for book discovery from `books/`.
4. Product registry tests covering MoonFish, MoonMoon, and MoonRobo.
5. Service config tests for MoonClaw and Moontown product-local configs.
6. MoonCode end-to-end tests for prompt append, runtime events, and ordered AI
   reply append.
7. Desk browser smoke tests for first-run root, VFS, workspace list, and clean
   conversation UI.
8. Lepusa smoke test from a fresh MoonSuite root.
9. MoonLib contract-consumer tests proving Moondesk, MoonStat, and each
   migrated product derive `.moonsuite`, `.tmp`, `books`, product-home, and
   product-registry paths from `@moonsuite`.
10. MoonStat drift-report tests proving old `.moontown`, `.moonclaw`,
    repo-local runtime, and global temp paths are reported as drift rather than
    treated as alternate valid layouts. Covered by MoonStat commit `cf7fd62`.
11. MoonLib contract-boundary tests proving products can import
    `vectie/moonlib/moonsuite` without depending on MoonStat, Moondesk UI code,
    MoonClaw runtime code, or daemon packages.

## Phase 9: Cutover

Cutover steps:

1. Stop writing the old hidden MoonBook library.
2. Stop writing `.moontown/moondesk-daemon`.
3. Update tests, docs, and smoke fixtures to `books/`.
4. Make MoonSuite v2 the fresh default.
5. Launch a fresh Lepusa/Moondesk app for visual verification.

## Cross-Product Migration Log

Completed slices:

- Moondesk initializes fresh MoonSuite roots, discovers MoonBooks from `books/`,
  writes product service state under `.moonsuite/products/*`, hides
  `.moonsuite` and `.tmp` in the normal VFS, and stores MoonCode sessions under
  `.moonsuite/products/mooncode/sessions`.
- Moondesk now depends on MoonLib `0.1.3` and uses
  `@moonsuite.product_artifact_for_workspace_root` through its MoonWiki adapter
  for scoped Desk trash state. Workspace trash files and receipts now live under
  `.moonsuite/products/moondesk/trash`, even when the selected workspace is a
  suite-hosted `books/<book-id>` MoonBook; restore/listing resolve only that
  Moondesk product-home prefix instead of treating old `.moontown/trash` paths
  as valid workspace paths. MoonCode capability copy and README service
  descriptor copy now name the current product-home paths. Validation for this
  slice: Moondesk `moon update`, `moon fmt`, `moon info`, `moon check`, and
  `moon test` with `448/448` tests passing.
- Moondesk MoonClaw daemon probing now reads `daemon.json` from
  `.moonsuite/products/moonclaw` through
  `@moonsuite.product_artifact_for_workspace_root`, and Moondesk-launched
  MoonClaw daemon stdout/stderr logs now go under
  `.moonsuite/products/moonclaw/logs`. The fallback no longer probes or writes
  `$HOME/.moonclaw`, and white-box coverage asserts suite-hosted
  `books/<book-id>` workspaces derive the owning suite's MoonClaw product home.
- Moonstat advertises and writes MoonClaw provider manifests through
  `.moonsuite/products/moonclaw/providers.json`, and advertises MoonClaw model
  and config candidates under `.moonsuite/products/moonclaw`.
- MoonStat commit `0428848` splits the active suite-status and product-state
  defaults: suite discovery now writes `.moonsuite/suite-status.json`, while
  MoonStat-owned usage request logs, session sync offsets, and editable model
  pricing now default under `.moonsuite/products/moonstat`. Help text, README
  copy, and white-box coverage assert the fresh suite-root/product-home
  boundary. Validation passed in MoonStat with `moon fmt`, `moon info`,
  `moon check`, `moon test` (774/774), and `git diff --check`.
- MoonStat commit `62d9ebb` moves the app config default from suite state into
  `.moonsuite/products/moonstat/config.json`. Config backups and skill
  state/backups/install directories follow MoonStat's product-home config root,
  with README copy and white-box coverage asserting the new path. Validation
  passed in MoonStat with `moon fmt`, `moon info`, `moon check`, `moon test`
  (774/774), and `git diff --check`.
- MoonBook installs the MoonClaw extension provider manifest into the
  MoonSuite-level MoonClaw product home when a book lives under
  `books/<book-id>`, while standalone book roots use their own
  `.moonsuite/products/moonclaw` product home.
- MoonFish exposes a root product-home contract for
  `.moonsuite/products/moonfish`, `.tmp/products/moonfish`, and accepted
  MoonBook outputs under `books/<book-id>/outputs/moonfish`.
- MoonFish commit `0518831` moves suite-status references off the old
  home-global `~/.moonsuite/suite-status.json` default and derives them through
  the MoonLib-backed `@model.moonsuite_suite_status_path(...)` helper. App-tool
  bindings, suite-settings defaults, product fixtures, planning/evaluation/
  acceptance/parity/workspace tests, and app-smoke state-path validation now use
  the suite-local `.moonsuite/suite-status.json` contract. Validation passed in
  MoonFish with `moon fmt`, `moon info`, `moon check`, `moon test` (144/144),
  and `git diff --check`.
- MoonMoon exposes a root product-home contract for
  `.moonsuite/products/moonmoon`, `.tmp/products/moonmoon`, and accepted
  MoonBook outputs under `books/<book-id>/outputs/moonmoon`.
- MoonFish commit `31dab53` and MoonMoon commit `b7027a9b` add explicit
  workspace-root variants for every root product-home facade path and remove the
  active `@moonsuite.*("", ...)` constructors. Their tests now prove that a
  suite-hosted book root maps product-owned state/cache/service/temp paths to
  the owning suite root, while accepted output remains in
  `books/<book-id>/outputs/<product>`. Validation passed with MoonFish
  `moon fmt`, clean `moon info`, `moon check`, `moon test` (144/144), and
  `git diff --check`; MoonMoon `moon fmt`, `moon info`, `moon check`,
  `moon test` (143/143), and `git diff --check` with only the pre-existing
  unused warnings from generated Noetix suite-preview evidence.
- Lepusa exposes a root product-home contract for
  `.moonsuite/products/lepusa`, including native runtime and update metadata
  paths.
- Moontown stores default town snapshots, standing goals, watcher ledgers,
  daemon runtime files, live/autonomy projections, book-result bridges, book
  template requests, civic schedules, book-quality runtime files, and town
  synthesis under `.moonsuite/products/moontown`.
- Moontown stores book-quality audits, AI review packets/results, review run
  ledgers, and repair bridge defaults under
  `.moonsuite/products/moontown/book-quality`, with README copy and daemon
  scheduled-job tests updated to the product-home paths.
- Moontown stores civic protocol registries, status projections, protocol
  ledgers, civic service status, and civic service result bridges under
  `.moonsuite/products/moontown`, and Rabbita/cookbook operator copy now points
  at the MoonSuite product-home paths.
- The Rabbita/Moontown Vite bridge serves town snapshots, live autonomy,
  standing goals, watcher ledgers, operator-request queues, book-template
  queues/configs, civic status, editor pipeline state, Moondesk bridge records,
  and book-result records from `.moonsuite/products/moontown`; generated
  MoonBook projection discovery remains on the existing book workspace root
  until the book-layout cutover.
- Moontown final-integration installs write the Wenyu integration status file
  under `.moonsuite/products/moontown/integration`, with usage docs and
  white-box path coverage updated to the product-home location.
- Moontown exported keeper/MoonClaw packet files now default to
  `.moonsuite/products/moontown/packets`, with modeled execution records,
  Rabbita demo records, operational docs, and adapter white-box coverage updated
  to the product-home path.
- Moontown cookbook stable-state manifests now default to
  `.moonsuite/products/moontown/cookbook/stable-state.json`, with cookbook
  path coverage and operator docs updated to the product-home path.
- Moontown PlanBook/editor operator copy now names
  `.moonsuite/products/moontown` for live-autonomy, town-journal, PlanBook
  autonomy/repair/validation, and editor-pipeline state; focused tests assert
  the generated copy no longer emits the old product-runtime paths.
- Moontown README, frontend, usage, doc-structure, and generated cookbook copy
  now point standing-goal/watch ledgers, operator request queues,
  book-template request/config/event files, Moondesk bridge records, and
  book-result bridges at `.moonsuite/products/moontown`; cookbook tests assert
  the generated book-template flow no longer emits the legacy inbox path.
- Moontown's MoonBook catalog default now writes
  `.moonsuite/products/moontown/moonbooks.json`, matching Moondesk's bridge
  path; adapter tests assert the default and book-quality status tests no
  longer depend on a repo-local legacy catalog fixture.
- MoonClaw stores MoonCode durable session sidecars under
  `.moonsuite/products/moonclaw/mooncode/sessions`, advertises that path in its
  native capability payload, and excludes fresh internal `.moonsuite` and
  `.tmp` lanes from MoonCode commit-proof git status/staging.
- MoonClaw loads global and local rule files from
  `.moonsuite/products/moonclaw/rules`, and its rules prompt copy names the
  MoonSuite product-home directory.
- MoonClaw installs and loads system, global, and local skills from
  `.moonsuite/products/moonclaw/skills`, and skill resource listing/reading
  tests cover the product-home path.
- MoonClaw stores the daemon lock/info file at
  `.moonsuite/products/moonclaw/daemon.json`, and daemon white-box tests assert
  that the legacy `.moonclaw/daemon.json` path is not created.
- MoonClaw stores robot routine run ledgers under
  `.moonsuite/products/moonclaw/robot-routine-runs`, and gateway white-box tests
  assert that the legacy `.moonclaw/robot-routine-runs` path is not created.
- MoonClaw commit `30740fb2` stores workflow job runtime state and process
  stdout/stderr under `.moonsuite/products/moonclaw/jobs`, keeps run metadata
  inside each run workspace instead of a nested `.moonclaw` directory, moves
  gateway sessions/channel/token state under `.moonsuite/products/moonclaw`,
  and makes proposal/gateway/onboard/ACP default `--home` mean the MoonSuite
  root. Onboarding and workspace config discovery now prefer
  `.moonsuite/products/moonclaw/moonclaw.json`, while tests keep legacy
  root-local and nested config reads as fallback inputs. Validation passed with
  MoonClaw `moon update`, `moon check`, `moon test` (985/985), `moon fmt`,
  `moon info`, and final `moon check`.
- MoonClaw commit `0d3cace0` moves the remaining active conversation store,
  default MoonClaw/Agent logs, ACP session state, and ACP/plugin/job/gateway/
  provider config discovery onto `.moonsuite/products/moonclaw`, with product
  config preferred over legacy home-level config while project-local config can
  still override it. Validation passed with MoonClaw `moon check`, `moon test`
  (991/991), `moon fmt`, `moon info`, final `moon check`, and
  `git diff --check`.
- MoonClaw commit `b81315ba` moves OAuth credential stores, starter attachment
  materialization, provider-task runtime artifacts, and MoonCode watcher state
  under `.moonsuite/products/moonclaw`; worktree scratch directories now use
  the suite temp lane at `.tmp/products/moonclaw/worktrees`. Focused tests
  assert the product-home/temp paths and absence of the old `.moonclaw` or
  `.moonclaw-worktrees` write locations. Validation passed with MoonClaw
  `moon check`, `moon test` (992/992), `moon fmt`, `moon info`, final
  `moon check`, and `git diff --check`.
- MoonClaw commit `b1af34b0` removes the remaining active provider manifest
  and `moonclaw.json` config readers from legacy root-local and `.moonclaw`
  locations in the provider registry, job analysis config, ACP CLI, gateway
  CLI, provider resource tools, and provider task fixtures. These now resolve
  through MoonLib workspace-root product-home constructors, with suite-hosted
  book roots covered by white-box tests. Validation passed with MoonClaw
  `moon fmt`, `moon info`, `moon check`, `moon test` (995/995), and
  `git diff --check`.
- MoonClaw commit `83d8ecae` continues that runtime cutover through ACP
  runtime loading, channel bootstrap and model resolution, plugin/workspace/
  security/onboarding runtime config loading, and security pairing/approval
  persistence. Root-local `moonclaw.json`, nested `.moonclaw/moonclaw.json`,
  and `home/security/state.json` are no longer active runtime defaults for
  these surfaces; tests seed the MoonSuite product home and assert legacy root
  configs are ignored where retained as fixtures. Validation passed with
  MoonClaw `moon fmt`, clean `moon info`, `moon check`, `moon test` (995/995),
  and `git diff --check`.
- MoonClaw commit `6a23ea1a` narrows MoonCode commit-proof git status/staging
  exclusions to the fresh internal `.moonsuite` and `.tmp` lanes. Legacy
  `.moonclaw`, `.moontown`, and `moonclaw-jobs` directories are no longer
  protected as runtime internals by the commit proof path; white-box coverage
  proves those legacy paths are committed when present while suite internal
  state remains unstaged. The daemon model test fixture also stopped creating
  an unused `.moonclaw` directory. Validation passed with MoonClaw `moon fmt`,
  clean `moon info`, `moon check`, `moon test` (995/995), and
  `git diff --check`.
- MoonClaw commit `5d63360e` moves the todo tool's active session ledger from
  `.moonclaw/todos/current_session.json` into
  `.moonsuite/products/moonclaw/todos/current_session.json` through the MoonLib
  workspace-root product-home constructor. Tool docs now advertise the fresh
  storage path, and black-box coverage proves suite-hosted books write the
  suite MoonClaw product-home ledger without creating the legacy `.moonclaw`
  todo file. Validation passed with MoonClaw `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (996/996), and `git diff --check`.
- MoonClaw commit `620127d6` replaces the remaining hand-built MoonClaw
  product-home helpers for MoonCode durable session storage, skills, rules,
  daemon lock files, and robot routine run ledgers with MoonLib `@moonsuite`
  constructors. MoonCode durable sessions use the workspace-root constructor so
  standalone roots keep local `.moonsuite/products/moonclaw/mooncode/sessions`
  storage while suite-hosted `books/<book-id>` roots resolve to the owning
  suite's MoonClaw product home. Validation passed with MoonClaw `moon fmt`,
  clean `moon info`, `moon check`, `moon test` (997/997), and
  `git diff --check`.
- MoonClaw commit `5f22fd04` moves job-analysis preferred skill loading to
  MoonLib workspace-root product-home constructors. Analysis prompts still
  accept explicit project-local `skills/<name>/SKILL.md` overrides, but
  MoonClaw product skills now come from
  `.moonsuite/products/moonclaw/skills`, and white-box coverage rejects legacy
  `.moonclaw/skills` as a fresh-default source. Validation passed with
  MoonClaw `moon fmt`, clean `moon info`, `moon check`, `moon test` (998/998),
  and `git diff --check`.
- MoonClaw commit `c31ff22a` moves job-analysis tool journals out of
  workspace-root `.moonclaw-tool-journal-*` files and into the MoonSuite temp
  lane at `.tmp/products/moonclaw/tool-journals`. The journal path now derives
  the owning suite from the analysis workspace root, so suite-hosted
  `books/<book-id>` workspaces write disposable tool trace state to the suite
  temp area instead of the book root. Validation passed with MoonClaw
  `moon fmt`, clean `moon info`, `moon check`, `moon test` (998/998), and
  `git diff --check`.
- MoonClaw commit `56250730` cleans provider-task runtime artifact paths. The
  artifact directory now uses the MoonLib workspace-root product-home
  constructor, so suite-hosted book roots resolve provider-task artifacts to
  the owning suite's `.moonsuite/products/moonclaw/provider-task` directory.
  Generated result/failure filenames dropped the legacy hidden
  `.moonclaw-provider-*` prefix in favor of `provider-<kind>-...json`.
  Validation passed with MoonClaw `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (999/999), and `git diff --check`.
- MoonClaw commit `c8e05dac` cleans the system-skill installation marker name.
  Installed system skills still live under
  `.moonsuite/products/moonclaw/skills/.system`, but the idempotency marker is
  now `system-skills.marker` instead of the legacy hidden
  `.moonclaw-system-skills.marker`. White-box coverage asserts the clean marker
  path and absence of the old marker filename. Validation passed with MoonClaw
  `moon fmt`, clean `moon info`, `moon check`, `moon test` (999/999), and
  `git diff --check`.
- MoonClaw commit `b8a1094c` aligns the Node UI daemon discovery helper and
  daemon command docs with the MoonSuite product-home lock file. The UI now
  reads `~/.moonsuite/products/moonclaw/daemon.json`, matching the backend
  `@moonsuite.product_artifact(home, "moonclaw", "daemon.json")` lock path,
  instead of probing the obsolete `~/.moonclaw/daemon.json`. Validation passed
  with MoonClaw `moon fmt`, clean `moon info`, `moon check`, `moon test`
  (999/999), and `git diff --check`. The UI `npm run check` gate now runs
  after installing dependencies, but remains blocked by pre-existing unrelated
  package errors in `events-display.tsx` and `task-utils.tsx`.
- MoonClaw commit `c675b993` aligns the public MoonCode sidecar and watcher
  documentation with the product-home implementation. The top-level README and
  daemon API guide now describe durable MoonCode sessions, event streams,
  runtime-event replay, eval evidence, and `moon_check` watcher state under
  `.moonsuite/products/moonclaw/mooncode/...` derived from the selected
  MoonBook root, and the commit-proof copy now names the fresh `.moonsuite`
  and `.tmp` internal lanes instead of legacy `.moonclaw`, `.moontown`, or
  `moonclaw-jobs` exclusions. Validation passed with MoonClaw `moon fmt`,
  clean `moon info`, `moon check`, `moon test` (999/999), and
  `git diff --check`.
- MoonRobo exposes product-home contracts in its product status projection for
  `.moonsuite/products/moonrobo` task bridge artifacts and
  `.moonsuite/products/moonclaw/robot-routine-runs`; MoonRobo docs now point
  MoonClaw routine ledgers at the MoonSuite product-home path.
- MoonRobo SDK E1 runtime IPC defaults now use the suite temp lane under
  `.tmp/products/moonrobo/sdk-e1` instead of global `/tmp` files; the supervisor
  script creates nested parent directories before starting collector/writer
  processes, and bridge/host API tests assert the new contract.
- MoonRobo gateway-command and Robo-loop artifacts now write, list, read, and
  feed loop-proof aggregation from `.moonsuite/products/moonrobo`, with host API
  integration tests asserting the old `runs/gateway-commands` and
  `runs/robo-loops` paths stay empty for those product-owned artifacts.
- MoonRobo proof-session and live-exercise product ledgers now use
  `.moonsuite/products/moonrobo/proof-sessions` and
  `.moonsuite/products/moonrobo/live-exercises`; host API integration tests
  assert proof sessions no longer write to `runs/proof-sessions`, product
  status exposes the product-home paths, and resident/memory context reads the
  new proof-session ledger.
- MoonRobo now depends on MoonLib `0.1.1`; product status helpers, runtime
  product-home helpers, product orchestration directory setup, and SDK E1
  suite-temp defaults are thin adapters over `@moonsuite`. The slice keeps
  RoboBook-owned receipts, telemetry, task executions, reviews, observations,
  and model edits under the book root, while product-owned gateway commands,
  dry-run evidence, approval records, Robo loops, Robo turns, prove-loop
  records, proof sessions, live exercises, and SDK IPC state derive from the
  MoonLib MoonSuite contract. Validation passed in MoonRobo with `moon update`,
  `moon fetch vectie/moonlib@0.1.1`, `moon check`, `moon test` (453/453),
  `moon fmt`, `moon info`, and a final `moon check`.
- MoonRobo commit `dea4141b` moves runtime supervisor launch receipts/logs,
  runtime-health records, runtime-validation reports/sessions, and
  runtime-calibration plans/resolutions under
  `.moonsuite/products/moonrobo`. The runtime package now exposes MoonLib-backed
  helpers for those product orchestration directories, launcher code uses the
  product-home supervisor path, and tests assert the new paths no longer use
  `runs/runtime-*`. Validation passed in MoonRobo with `moon check`,
  `moon test` (453/453), `moon fmt`, `moon info`, final `moon check`, and
  `git diff --check`.
- MoonRobo commit `08448318` moves bridge authority contract evidence from
  `runs/bridge-contracts` into
  `.moonsuite/products/moonrobo/bridge-contracts`. The runtime package now
  exposes the MoonLib-backed `moonrobo_bridge_contracts_dir(...)` adapter,
  readiness and platform-queue evidence point at the product-home latest
  contract, and tests assert the legacy `runs/bridge-contracts` directory is no
  longer created for bridge contract persistence. Validation passed in MoonRobo
  with `moon fmt`, `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `67a9cba2` moves bridge dispatch evidence from
  `runs/bridge-dispatches` into
  `.moonsuite/products/moonrobo/bridge-dispatches`. The runtime package now
  exposes the MoonLib-backed `moonrobo_bridge_dispatches_dir(...)` adapter,
  desktop/host execution paths persist dispatches through that product-home
  path, and task-status/resident/core projections no longer advertise the old
  `runs/bridge-dispatches` contract. Validation passed in MoonRobo with
  `moon fmt`, `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `2924fb0d` moves bounded Robo turn artifacts from
  `runs/robo-turns` into `.moonsuite/products/moonrobo/robo-turns`. The runtime
  package now exposes the MoonLib-backed `moonrobo_robo_turns_dir(...)`
  adapter, host API turn write/list/detail paths use the product-home ledger,
  and tests assert runtime setup no longer creates the old `runs/robo-turns`
  directory for this product-owned state. Validation passed in MoonRobo with
  `moon fmt`, `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `ff34fcec` moves bounded prove-loop records from
  `runs/prove-loop` into `.moonsuite/products/moonrobo/prove-loop`. The runtime
  package now exposes the MoonLib-backed `moonrobo_prove_loop_dir(...)` adapter,
  direct prove-loop and repeated proof-session attempts persist/read the
  product-home proof ledger, and resident/routine/MoonBook memory fixtures no
  longer normalize the old book-root prove-loop path. Validation passed in
  MoonRobo with `moon fmt`, `moon info`, `moon check`, `moon test` (453/453),
  and `git diff --check`.
- MoonRobo commit `79dc7359` moves safety-gate dry-run and approval evidence
  from `runs/dry-runs` and `runs/approvals` into
  `.moonsuite/products/moonrobo/dry-runs` and
  `.moonsuite/products/moonrobo/approvals`. The runtime package now exposes
  MoonLib-backed `moonrobo_dry_runs_dir(...)` and
  `moonrobo_approvals_dir(...)` adapters, task-message status paths advertise
  product-home evidence, and bridge/host API tests assert the old book-root
  evidence paths are not written. Validation passed in MoonRobo with
  `moon fmt`, `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `8cda56d3` completes the current residual audit for migrated
  product-owned runtime classes by removing stale legacy product-path fixtures
  from product-status and routine-context tests, and by documenting the boundary
  that replay annotations and MoonData references remain book-owned RoboBook
  evidence under `runs/annotations` and `runs/data-refs`. Runtime health,
  validation, calibration, supervisor logs, bridge contracts, dry runs, and
  approvals are documented under `.moonsuite/products/moonrobo`. Validation
  passed in MoonRobo with `moon fmt`, `moon info`, `moon check`, `moon test`
  (453/453), and `git diff --check`.
- MoonRobo commit `bdb26b04` refreshes Rabbita cockpit UI/parser smoke
  fixtures for product-owned MoonRobo artifact paths. Gateway commands, Robo
  loops, proof sessions, live exercises, runtime health, runtime validation,
  runtime calibration, and prove-loop records now appear in the cockpit
  fixtures under `.moonsuite/products/moonrobo/...`; book-owned task
  executions, telemetry, and RoboBook evidence remain under book `runs/...`.
  Validation passed in MoonRobo with `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (453/453), and `git diff --check`.
- MoonRobo commit `a24ac57b` aligns the Rabbita cockpit MoonClaw routine
  evidence fixtures with the MoonClaw product-home ledger. Cockpit parser and
  lifecycle tests now show persisted routine records under
  `.moonsuite/products/moonclaw/robot-routine-runs`, and README operator copy
  no longer advertises the stale `.moonclaw/robot-routine-runs` ledger.
  Validation passed in MoonRobo with `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (453/453), and `git diff --check`.
- MoonRobo commit `0c2297f0` removes stale product-runtime path claims from
  MoonRobo docs. Runtime supervisor, runtime health, runtime validation,
  runtime calibration, bridge dispatch, and bridge contract documentation now
  point at `.moonsuite/products/moonrobo/...`; SDK E1 bridge examples now use
  the MoonLib-derived suite temp lane under `.tmp/products/moonrobo/sdk-e1`
  instead of global `/tmp/moonrobo-sdk-e1*` files. Validation passed in
  MoonRobo with `moon fmt`, clean `moon info`, `moon check`, `moon test`
  (453/453), and `git diff --check`.
- Moontown daemon runtime policy now defaults health/log summaries to
  `.moonsuite/products/moontown/daemon.log`, and editor-pipeline civic protocol
  evidence points at
  `.moonsuite/products/moontown/civic/protocols/<building-id>/*.jsonl`; targeted
  daemon/editor tests and the full Moontown test suite assert the product-home
  contract.
- Moontown civic service history now derives the product-home book-result path,
  and the default external MoonClaw checkout root is
  `.moonsuite/products/moontown/external/moonclaw`; civic and MoonClaw adapter
  tests assert the old `.moontown` paths are not emitted.
- Moontown now depends on MoonLib `0.1.1`; its storage product-home, service,
  temp, snapshot, standing-goal, watcher, and mayor town-synthesis paths are
  thin adapters over `@moonsuite`, and town synthesis execution records register
  the mayor workspace root as `.moonsuite/products/moontown` instead of
  `.moontown`.
- Moontown commit `8ae8672c` adds a storage-level
  `moontown_product_artifact(...)` adapter over MoonLib
  `@moonsuite.product_artifact(...)`, then routes default civic protocol/status
  artifacts, communication schedules/runs, visual projection, book-result
  bridges, cookbook manifests, MoonBook catalog state, MoonClaw packet exports,
  daemon logs, and final-integration status through that adapter. Moontown docs
  and operator copy no longer name `.moontown/civic`,
  `.moontown/book-results`, `.moontown/book-projection-policy`, or
  `.moontown/visual-projection` for product-owned state. Validation passed with
  `moon check`, `moon test` (922/922), `moon fmt`, `moon info`, and a final
  `moon check`.
- Moontown commit `d4b79996` starts the Phase 5 book-layout cutover by moving
  default MoonBook workspace roots from `.moontown/books/<book-id>` to
  MoonLib-backed `books/<book-id>` paths. The slice updates catalog defaults,
  editor/planbook source-root helpers, backlog target paths, civic result
  routing, Rabbita missing-projection copy, cookbook generated copy, and
  operator docs. The checked source/docs set no longer contains the old
  `.moontown/books` or `.moontown/moonbooks.json` contracts. Validation passed
  with `moon check`, `moon test` (923/923), `moon fmt`, `moon info`, and a final
  `moon check`.
- Cross-repo residual cleanup landed in Moontown commit `a9088181` and Moondesk
  commit `49589f69`. Moontown's handoff asset and README now name
  `books/<book-id>` for book workspace packs and output bundles. Moondesk source
  layer inference now classifies `.moonsuite/...` and `.tmp/...` as internal
  config surfaces, and its explorer test no longer uses `.moontown/books` as the
  config example. A broad scan across Moondesk, MoonBook, MoonClaw, MoonStat,
  MoonRobo, MoonFish, MoonMoon, Moontown, and MoonLib found no active
  `.moontown/books`, `.moontown/moonbooks.json`, or `.moontown/books.json`
  contracts outside this historical migration log. Validation passed with
  Moondesk `moon check`, `moon test` (445/445), `moon fmt`, `moon info`, final
  `moon check`, plus Moontown `moon check`, `moon test` (923/923), `moon fmt`,
  `moon info`, and final `moon check`.
- Phase 5 fresh-root projection coverage landed in Moontown commit `19dfada1`
  and Moondesk commit `a6cac733`, proving the Rabbita/Moondesk book path
  contract from both sides. The Moontown Rabbita Vite bridge defaults
  `booksRootPath` to the fresh suite `books` root, keeps product-owned bridge
  files under `.moonsuite/products/moontown`, and exposes
  `MOONTOWN_SUITE_ROOT`, `MOONTOWN_BOOKS_ROOT`, and
  `MOONTOWN_PRODUCT_STATE_ROOT` overrides for smoke runs. `npm run
  smoke:book-projections` creates a temporary fresh suite root and asserts that
  `books/wenyu-social-square/book/moonbook-ui-state.json` flows into
  `loadModuleProjectionIndex()` with the generated-site link intact. Moondesk's
  `internal/moonwiki` white-box coverage builds the matching fresh suite root
  and asserts Desk workspace discovery exposes the MoonBook, canonical virtual
  entries, and projection file resolution without creating
  `.moontown/books/<book-id>`. Validation passed with Rabbita `npm run
  smoke:book-projections`, Moontown `moon check`, `moon test` (923/923),
  `moon fmt`, `moon info`, final `moon check`, plus Moondesk `moon check`,
  `moon test` (446/446), `moon fmt`, `moon info`, and final `moon check`.
- Moondesk commit `76ba4069` extends the full Desk browser smoke to cover the
  fresh generated-site projection path in the real UI. The smoke fixture now
  seeds `books/research-alpha/book/moonbook-ui-state.json` and
  `books/research-alpha/book/site/generated/index.html`, then drives Chrome
  through the Desk UI to prove the root virtual file list exposes
  `book/site/generated`, keeps raw `book` folded away, opens
  `book/site/generated/index.html`, and renders the Desk preview link through
  `/api/workspaces/book-research-alpha/file/book/site/generated/index.html`
  without creating `.moontown/books/...`. Validation passed with
  `scripts/desk_mode_browser_smoke.sh`, `moon check`, `moon test` (446/446),
  `moon fmt`, `moon info`, and final `moon check`.
- Moondesk commit `801b23b0` adds the Lepusa-native fresh-books smoke gate. The
  new `scripts/lepusa_fresh_books_smoke.sh` seeds a temporary fresh MoonSuite
  root with `.moonsuite`, `.tmp`, and `books/research-alpha` containing
  `book/moonbook-ui-state.json` plus `book/site/generated/index.html`; runs
  `lepusa live-smoke macos --strict` against that root and the Rabbita Desk UI;
  then parses the generated live project and runtime manifest to assert the
  bundled `moondesk-sidecar serve <fresh-root>` command, readiness URL, and
  absence of legacy `.moontown/books`. Validation passed with
  `scripts/lepusa_fresh_books_smoke.sh`, `moon check`, `moon test` (446/446),
  `moon fmt`, `moon info`, and final `moon check`.
- MoonStat commit `cf7fd62` closes the current Phase 8 drift-report slice. The
  report now carries explicit probe paths and scopes, exposes MoonRobo
  canonical product-home and suite-temp paths, and treats legacy `.moontown`,
  `.moonclaw`, `.moontown/moondesk-daemon`, `moonclaw-jobs`, root-local
  `moonstat`, MoonRobo `runs/gateway-commands`, `runs/robo-loops`,
  `runs/proof-sessions`, and old global SDK E1 bridge temp files as drift
  candidates. Tests use an injectable `global_tmp_root` so production can still
  inspect `/tmp` while the suite stays deterministic. Validation passed with
  MoonStat `moon check`, `moon test` (773/773), `moon fmt`, `moon info`, and a
  final `moon check`.
- Moondesk adapters and MoonWiki run readers now expose MoonClaw run artifacts
  through `.moonsuite/products/moonclaw/jobs` instead of `moonclaw-jobs` or
  `.moonclaw/jobs/runs`, while the Moontown adapter derives town snapshots,
  daemon state, standing goals, and watcher roots from MoonLib
  `@moonsuite.product_artifact`. The matching MoonWiki fixture seeds forwarded
  run artifacts under the MoonSuite product home, and adapter tests assert the
  old `moonclaw-jobs` section is gone.
- Moontown launchd install/uninstall scripts now write plist and stdout/stderr
  logs under `.moonsuite/products/moontown/launchd` and
  `.moonsuite/products/moontown`, not `.moontown/launchd`; usage docs now point
  operators at the product-home launchd paths.
- Moontown MoonBook adapter residuals now route the MoonCode book-result
  processed ledger through
  `.moonsuite/products/moontown/mooncode-book-results/<book-id>/processed.jsonl`
  and default the local MoonBook checkout fallback to
  `.moonsuite/products/moontown/external/moonbook`, eliminating the active
  `.moontown/mooncode-book-results` and `.moontown/moonbook` write targets.
  Validation passed with Moontown `moon fmt`, `moon info`, `moon check`, and
  `moon test` (925/925).
- Moontown commit `4eb1f047` upgrades to MoonLib `0.1.3` and routes the
  remaining active MoonClaw home/config writers in the MoonClaw command
  adapter, book-quality review dispatch/reconcile flow, and Wenyu build
  preseed through MoonLib-derived MoonClaw product homes. Book-quality review
  config now writes
  `.moonsuite/products/moontown/book-quality/.moonsuite/products/moonclaw/moonclaw.json`,
  direct review polling reads jobs from that matching product home, and Wenyu
  preseed no longer creates root-local `moonclaw.json` or `.moonclaw` config
  files. Validation passed with Moontown `moon update`, `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- Moontown commit `8f56f390` removes the next active `.moonclaw` home targets
  from PlanBook repair ACP config and editor feature-selection MoonClaw
  dispatch. PlanBook repair now writes Codex ACP target config through
  `@moonsuite.product_artifact_for_workspace_root(workspace_root, "moonclaw",
  "moonclaw.json")`, and editor feature-selection imports/runs pass the
  workspace root as MoonClaw `--home` so MoonClaw derives the product home
  itself. Validation passed with Moontown `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (926/926), and `git diff --check`.
- Moontown commit `1eaff85d` moves the MoonClaw run polling adapter onto the
  MoonLib product-home job store. The adapter now derives
  `.moonsuite/products/moonclaw/jobs` through `@moonsuite` for suite-root
  callers while still accepting already-derived MoonClaw product homes from
  book-quality and PlanBook flows. Wenyu build review prompts now tell workers
  to read run-workspace `run.json` instead of stale `.moonclaw/run.json`, and
  run-polling/PlanBook path tests seed fresh product-home fixtures instead of
  `.moonclaw/jobs`. Validation passed with Moontown `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- Moontown commit `0c4e6f33` aligns public operator/frontend documentation
  with the already-migrated runtime product-home paths. `docs/USAGE.md` and
  `docs/FRONTEND.md` now describe active town snapshots, daemon state/runtime
  files, standing-goal inputs, watcher ledgers, book-quality review artifacts,
  town synthesis, and the MoonClaw job-store archive under
  `.moonsuite/products/moontown/...` or `.moonsuite/products/moonclaw/jobs/...`
  instead of `.moontown/...` or `.moonclaw/jobs/...`. Validation passed with
  Moontown `moon fmt`, clean `moon info` after reverting unrelated generated
  `.mbti` EOF churn, `moon check`, `moon test` (926/926), and
  `git diff --check`.
- Moontown commit `03217510` removes the next stale live-autonomy and Moondesk
  handoff fixture paths from operator-facing surfaces. Live-autonomy markdown
  and Rabbita viewport fixtures now advertise
  `.moonsuite/products/moontown/...` product paths and PlanBook wiki history
  paths, the Moondesk handoff tilemap module now stages agent profiles and
  operator requests under the Moontown product home, and README copy points the
  MoonClaw hot-store archive at `.moonsuite/products/moonclaw/jobs/archive`.
  Validation passed with Moontown `moon fmt`, clean `moon info` after reverting
  unrelated generated `.mbti` EOF churn, `moon check`, `moon test` (926/926),
  and `git diff --check`.
- Rabbita commit `a6a69ad` adds the root package's explicit MoonSuite
  product-home contract. The public API now exposes `rabbita` product id,
  `.moonsuite/products/rabbita` state, service, runtime, cache, and
  `.tmp/products/rabbita` temp paths through a typed
  `RabbitaMoonSuiteProductHome`, with white-box coverage for the fresh default
  values. Validation passed with Rabbita `moon fmt`, clean `moon info`,
  `moon check`, root-package `moon test .` (4/4), native `moon test --target
  native` (24/24), and `git diff --check`; the full JS `moon test` still hits
  pre-existing DOM README examples that require browser `document`.
- MoonClaw commit `579085c7` aligns MoonCode's executable-book lifecycle
  contract and daemon capabilities payload with the already-migrated durable
  session store. The emitted contract now advertises
  `.moonsuite/products/moonclaw/mooncode/sessions/<id>/session.json` in the
  owning MoonClaw product home derived from the selected book root, and
  white-box coverage rejects the old `.moonclaw/mooncode/sessions` contract
  string. Validation passed with MoonClaw `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (997/997), and `git diff --check`.
- MoonClaw commit `b84c293b` aligns ACP configuration discovery with the
  workspace-first project-local override policy already used by the gateway
  command. `acp add codex` now reads and writes the workspace-derived
  `.moonsuite/products/moonclaw/moonclaw.json` when that project-local product
  config exists, falling back to the home product config only when no workspace
  config is present. White-box coverage proves the workspace product config
  overrides the home product config without mutating the home target, and
  provider-task docs now advertise
  `.moonsuite/products/moonclaw/providers.json` instead of legacy
  `.moonclaw/providers.json`. Validation passed with MoonClaw `moon fmt`,
  clean `moon info`, `moon check`, `moon test` (1000/1000), and
  `git diff --check`.
- MoonClaw commit `81ab4287` cleans current public CLI documentation so
  operators pass the MoonSuite root with `--home ~` instead of using
  `~/.moonclaw` as the home. README and command docs now point isolated
  workspaces, command examples, gateway startup, onboarding, ACP setup, and
  product config paths at `.moonsuite/products/moonclaw/...`, matching the
  MoonLib-backed runtime. Validation passed with MoonClaw `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (1000/1000), and `git diff --check`.
- MoonStat commit `e776bef` updates the suite drift report to match that
  MoonCode ownership boundary. Book-local
  `books/<book-id>/.moonclaw/mooncode/sessions` drift now reports the canonical
  target as `.moonsuite/products/moonclaw/mooncode/sessions` and product owner
  `moonclaw`, not `.moonsuite/products/mooncode/sessions`. Validation passed
  with MoonStat `moon fmt`, clean `moon info`, `moon check`, `moon test`
  (774/774), and `git diff --check`.
- MoonRobo commit `c69cc9ea` expands the public product-status MoonSuite
  contract so Rabbita, Moondesk, and status consumers can see every migrated
  MoonRobo product-home lane from one MoonLib-derived payload. The
  `MoonroboProductHomes` status now advertises dry-run evidence, approvals,
  bridge dispatches/contracts, robo turns, prove-loop records, runtime
  supervisor, runtime validation, runtime calibration, runtime health, and the
  cross-product MoonClaw robot-routine ledger through `@moonsuite` path
  constructors instead of a partial local schema. Validation passed with
  MoonRobo `moon fmt`, `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `3fb56af0` upgrades the runtime adapter to MoonLib `0.1.3`
  and routes every MoonRobo product orchestration directory through the
  workspace-root MoonLib constructor. A RoboBook mounted under
  `books/<book-id>` now creates gateway commands, dry runs, approvals,
  Robo loops/turns, prove-loop/proof-session records, bridge records, and
  runtime supervisor/validation/calibration/health state in the suite-level
  `.moonsuite/products/moonrobo` home rather than a nested book-local
  `.moonsuite`. Validation passed with MoonRobo `moon update`, `moon fmt`,
  clean `moon info`, `moon check`, `moon test` (453/453), and
  `git diff --check`.
- MoonRobo commit `43621e82` removes the remaining empty-root product-status
  and SDK E1 sidecar default path constructors. Product status now projects
  MoonRobo and cross-product MoonClaw homes from an explicit workspace/book
  root, and SDK E1 snapshot/command defaults derive the suite temp lane from
  that same root instead of `product_tmp_dir("", "moonrobo")`. Validation
  passed with MoonRobo `moon fmt`, clean `moon info`, `moon check`,
  `moon test` (453/453), and `git diff --check`.
- Rabbita commit `20d38ef` turns the root product-home contract from local
  string concatenation into a MoonLib adapter. The existing public
  `RabbitaMoonSuiteProductHome` surface stays stable, but state, service,
  runtime, cache, and temp paths now derive from `vectie/moonlib@0.1.3`
  `@moonsuite` constructors, matching the Phase 4.5 dependency direction.
  Validation passed with Rabbita `moon update`, `moon fmt`, clean `moon info`,
  `moon check`, root-package `moon test .` (4/4), native
  `moon test --target native` (24/24), and `git diff --check`; full JS
  `moon test` still hits the pre-existing DOM README examples that require a
  browser `document`.
- MoonStat commit `2d9b732` upgrades the observer to MoonLib `0.1.3` and
  derives book-local MoonClaw provider/session drift targets through
  `@moonsuite.product_artifact_for_workspace_root(...)`. The suite drift report
  now proves the current workspace-root contract for suite-hosted MoonBooks
  while keeping MoonStat a validator/reporter instead of a path-schema owner.
  Validation passed with MoonStat `moon update`, `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (774/774), and `git diff --check`.
- MoonStat commit `26531ce` removes the remaining active empty-root MoonSuite
  calls from app config, suite status, MoonClaw provider/model/config manifest
  defaults, and suite integration command output. Public workspace-root helpers
  now expose MoonStat product home, suite status, and MoonClaw provider manifest
  paths for suite-hosted book roots, and white-box tests prove those roots map
  to suite-level `.moonsuite` paths rather than nested `books/<book-id>` state.
  Validation passed with MoonStat `moon fmt`, clean `moon info`, `moon check`,
  `moon test` (774/774), and `git diff --check`.

Remaining high-priority product slices:

- MoonLib: expand `vectie/moonlib/moonsuite` only when a missing contract is
  shared by more than one product; keep it deterministic and free of daemon,
  analytics, and UI dependencies. Current published contract version is
  `vectie/moonlib@0.1.3`, including workspace-root-derived product artifact
  helpers for standalone and suite-hosted MoonBooks plus product-home and
  book-output constructors now consumed by MoonFish and MoonMoon.
- MoonStat: Phase 8 drift coverage for the known legacy product homes,
  repo-local runtimes, and MoonRobo global temp files is now covered. Keep
  consuming MoonLib contracts for workspace validation, health projection, and
  future drift additions, but do not add a parallel path schema there. The
  book-local MoonClaw provider and MoonCode sidecar drift targets now derive
  from the MoonLib workspace-root product-artifact helper, matching MoonClaw's
  current durable product-home contract.
- Moontown: remaining Phase 5 work should focus on any product-owned residual
  writers discovered by new smoke coverage; the programmatic Rabbita/Moondesk
  contract, full Desk browser smoke, Lepusa-native fresh-books smoke, and
  launchd product-home script path are now covered. The MoonCode sidecar
  processed-result ledger and MoonBook fallback checkout path are now
  product-home based, and the active MoonClaw command/book-quality/preseed,
  run polling, plus PlanBook repair/editor feature-selection MoonClaw home
  flows now use MoonLib-backed MoonClaw product homes instead of `.moonclaw`.
- MoonRobo: continue residual audits for any newly discovered writers, keeping
  RoboBook-owned receipts, telemetry, task executions, reviews, observations,
  and model edits under the book root while any remaining product orchestration
  path must remain a MoonLib-backed adapter. Runtime supervisor, health,
  validation, calibration, bridge dispatches, bridge contracts, gateway
  commands, dry-run evidence, approval records, Robo loops, Robo turns,
  prove-loop records, proof sessions, live exercises, and SDK IPC state are now
  product-home or suite-temp based; the runtime adapter now resolves those
  product-home paths from either a suite root or a `books/<book-id>` workspace
  root. Rabbita cockpit UI/parser fixtures now advertise those product-home
  paths for the migrated artifact classes.
- MoonClaw: remaining residuals are mostly historical compatibility docs,
  explicit project-local override policy coverage, and any newly discovered
  readers from deeper smoke runs. New runtime writes for conversations, jobs,
  gateway, onboarding config, workspace defaults, ACP state, OAuth credentials,
  starter attachments, provider-task artifacts, worktree scratch, MoonCode
  sessions and watchers, skills, rules, daemon lock, robot routine ledgers, and
  todo session state are now MoonLib-backed product-home or suite-temp based.
  Job-analysis tool journals now use the MoonClaw suite temp lane instead of
  root-level hidden `.moonclaw-tool-journal-*` files.
  Provider-task artifacts now derive product homes through the workspace-root
  MoonLib constructor and no longer generate `.moonclaw-provider-*` filenames.
  System-skill installation now uses a clean `system-skills.marker` idempotency
  marker under `.moonsuite/products/moonclaw/skills/.system`.
  Node UI daemon discovery now reads the backend product-home daemon lock at
  `.moonsuite/products/moonclaw/daemon.json` instead of `$HOME/.moonclaw`.
  MoonCode's public lifecycle/capability contracts and job-analysis preferred
  skill loading now advertise and consume the same product-home session/skill
  stores.
- Rabbita and future products: Rabbita now has an explicit root product-home
  contract and white-box coverage. Remaining work is broader browser-backed
  smoke integration for Rabbita and future products rather than local
  string-contract extraction. MoonFish and MoonMoon have root product-home
  contracts and now consume MoonLib for those paths.
