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

After Phase 4 product-home migration stabilizes, add Phase 4.5 for contract
extraction:

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
package is available through MoonLib `0.1.1`. Moondesk now depends on that
version and `internal/moonwiki/moonsuite_layout.mbt` is a thin compatibility
adapter over `@moonsuite` for suite root, book root, product-home, manifest,
registry, cache, and service paths. Remaining product-local helpers should
follow the same wrapper pattern instead of carrying independent string
contracts.

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
- Moonstat advertises and writes MoonClaw provider manifests through
  `.moonsuite/products/moonclaw/providers.json`, and advertises MoonClaw model
  and config candidates under `.moonsuite/products/moonclaw`.
- MoonBook installs the MoonClaw extension provider manifest into the
  MoonSuite-level MoonClaw product home when a book lives under
  `books/<book-id>`, while standalone book roots use their own
  `.moonsuite/products/moonclaw` product home.
- MoonFish exposes a root product-home contract for
  `.moonsuite/products/moonfish`, `.tmp/products/moonfish`, and accepted
  MoonBook outputs under `books/<book-id>/outputs/moonfish`.
- MoonMoon exposes a root product-home contract for
  `.moonsuite/products/moonmoon`, `.tmp/products/moonmoon`, and accepted
  MoonBook outputs under `books/<book-id>/outputs/moonmoon`.
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
  native capability payload, and excludes `.moonsuite` sidecars from MoonCode
  commit-proof git status/staging.
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
- MoonClaw stores workflow job runtime state under
  `.moonsuite/products/moonclaw/jobs`; gateway startup, proposal CLI commands,
  and detached proposal inputs share the same product-home helper.
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

Remaining high-priority product slices:

- Moontown: finish remaining synthesis/runtime copy that still names old
  `.moontown` paths, while keeping book-layout paths for the Phase 5 cutover.
- MoonRobo: continue auditing residual runtime writers so RoboBook-owned
  receipts, telemetry, task executions, reviews, observations, and model edits
  remain under the book root while any remaining product orchestration ledgers
  move under `.moonsuite/products/moonrobo`.
- Rabbita and future products: add explicit product-home contracts and smoke
  tests.
