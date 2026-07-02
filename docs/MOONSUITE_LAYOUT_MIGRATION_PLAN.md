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
- MoonBook commit `ce5224d` removes the remaining active hidden `.moonbook`
  write paths from wiki state, executable event persistence, extension
  manifests, skill-hub state, and the default external MoonClaw checkout.
  Book-owned state now lands in visible fresh-layout paths such as `state/`,
  `events/`, and `extensions/`, while MoonBook-owned internal skill-hub and
  external-tool state uses the MoonLib-derived
  `.moonsuite/products/moonbook/...` product home. Validation for this slice:
  MoonBook `moon fmt`, `moon info`, `moon check`, `moon test` with `198/198`
  tests passing, `git diff --check`, a direct active `.moonbook` scan with zero
  hits in MoonBook wiki/CLI source, and a broader active legacy scan leaving
  only the intentional negative `.moonclaw/providers.json` assertion.
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
- Lepusa commit `32b21b7` upgrades the root product-home facade to the MoonLib
  `0.1.3` contract. Lepusa now derives state, service, native runtime, update
  metadata, temp, and aggregate product-home paths through `@moonsuite`
  workspace-root helpers, and suite-hosted book roots resolve to the owning
  suite's `.moonsuite/products/lepusa` and `.tmp/products/lepusa` lanes instead
  of nested book-local state. Validation for this slice: Lepusa `moon update`,
  `moon fmt`, `moon info`, `moon check`, `moon test` with `374/374` tests
  passing, active empty-root constructor scan clean, and `git diff --check`.
- Rabbita commit `0c45c31` removes active empty-root MoonSuite constructors
  from its root product-home facade. Rabbita now exposes explicit
  workspace-root helpers for state, service, runtime, cache, temp, and the
  aggregate product-home payload, with suite-hosted book-root coverage proving
  those paths resolve to the owning suite's product home. Validation for this
  slice: Rabbita `moon fmt`, `moon info`, `moon check`, root-package
  `moon test .` with `5/5` tests passing, native `moon test --target native`
  with `25/25` tests passing, active empty-root constructor scan clean, and
  `git diff --check`.
- Moondesk commit `e54c4400` moves MoonCode desktop session/event sidecar path
  derivation onto MoonLib workspace-root helpers. `internal/mooncode` now
  exposes explicit workspace-root constructors for session directories,
  command logs, runtime command/receipt logs, snapshots, event logs, and stream
  checkpoints, while `internal/moonwiki` consumes those constructors instead of
  joining a relative `.moonsuite/products/mooncode/sessions` path onto the
  selected workspace root. Suite-hosted book roots now resolve MoonCode
  sidecars to the owning suite's `.moonsuite/products/mooncode` lane instead of
  nested `books/<book-id>/.moonsuite` state. Validation for this slice:
  Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with `451/451`
  tests passing, targeted old-join scan clean, and `git diff --check`.
- Moondesk commit `52dd6de9` moves the Moontown bridge request/dispatch path
  contract onto MoonLib workspace-root helpers. `internal/moonwiki` now derives
  Moontown product homes, request ledgers, dispatch ledgers, daemon state,
  standing-goal state, book-result summaries, watcher records, and town service
  paths from the owning suite when the selected workspace is a
  `books/<book-id>` root. UI-facing relative bridge paths remain centralized as
  display strings, while filesystem reads/writes use absolute
  workspace-root-derived product artifacts. Validation for this slice:
  Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with `453/453`
  tests passing, targeted active old-join scan clean except the intentional
  centralized relative display prefixes, and `git diff --check`.
- Moondesk commit `abb10fc2` routes MoonClaw job roots through MoonLib
  workspace-root helpers and stops creating nested
  `books/<book-id>/.moonsuite/products/moonclaw/jobs` directories for new
  MoonBooks. The generic workspace path resolver now redirects the intentional
  `.moonsuite/products/moonclaw/jobs/...` UI path to the owning suite's
  MoonClaw product home, rejects arbitrary `.moonsuite` and `.tmp` fallbacks,
  and keeps MoonClaw run raw-artifact reads working through that explicit
  product-path branch. Validation for this slice: Moondesk `moon fmt`,
  `moon info`, `moon check`, `moon test` with `454/454` tests passing,
  targeted active old-join scan clean except intentional centralized display
  prefixes, and `git diff --check`.
- Moondesk commit `103f86ac` moves Moondesk-owned daemon state, daemon policy,
  preference records, and town LaunchAgent log paths onto MoonLib
  workspace-root product artifacts. Suite-hosted book roots now resolve
  Moondesk daemon and preference state to the owning suite's
  `.moonsuite/products/moondesk` lane, and generated town LaunchAgent plists no
  longer write logs under `books/<book-id>/.moonsuite`. Validation for this
  slice: Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `456/456` tests passing, targeted active Moondesk old-join scan clean, and
  `git diff --check`.
- Moondesk commit `d4293c77` strengthens the trash-path coverage for
  suite-hosted book workspaces. Direct Desk and HTTP trash/restore flows now
  assert that `.moonsuite/products/moondesk/trash/files/...` UI paths resolve
  through the owning suite's Moondesk product home, that receipts use the same
  suite-level product home, and that trashing entries does not create a nested
  `books/<book-id>/.moonsuite` directory. Validation for this slice: Moondesk
  `moon fmt`, `moon info`, `moon check`, `moon test` with `456/456` tests
  passing, active one-line old-path file-operation scan with zero hits,
  narrowed active legacy literal scan with only filters/service identifiers, and
  `git diff --check`.
- Moondesk Desk smoke gates now enforce the same trash contract end to end. The
  API smoke resolves returned `.moonsuite/products/moondesk/trash/files/...`
  paths against the owning suite root instead of the selected book root, and the
  browser smoke asserts the Moondesk product-home trash directory exists while
  legacy `books/<book-id>/.moontown/trash` and nested
  `books/<book-id>/.moonsuite/products/moondesk/trash` directories do not.
  Validation for this slice: `bash -n scripts/desk_mode_api_smoke.sh`,
  `node --check scripts/desk_mode_browser_smoke.mjs`,
  `scripts/desk_mode_api_smoke.sh`, and `scripts/desk_mode_browser_smoke.sh`.
- Moondesk commit `c13ab594` removes the remaining fresh-default compatibility
  treatment for stale `.moontown`, `.moonclaw`, and `.moonclaw-worktrees`
  surfaces. Desk VFS hiding and creation guards now protect only the current
  internal roots such as `.moonsuite` and `.tmp`, source-layer inference
  classifies MoonClaw artifacts through the current MoonSuite product home or
  explicit MoonClaw job UI path instead of the old `.moonclaw` home, and the
  town LaunchAgent label is now `app.vectie.moonsuite.town`. Validation for this
  slice: Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `456/456` tests passing, zero quoted `.moontown`/`.moonclaw` literals in
  Moondesk MoonBit source, zero active old-path file-operation hits, and
  `git diff --check`.
- Moondesk metadata now treats `.moonsuite/product-registry.json` as a live UI
  source instead of only a bootstrap artifact. `/api/workspaces/metadata`
  returns the registry products, the Desk sidebar renders a compact
  registry-backed product summary, and the first-run/no-book screen now shows
  the active MoonSuite root, `books/` library path, MoonBook count, and installed
  core products before Code/Wiki interaction begins. Validation for this slice:
  Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with `457/457`
  tests passing, `npm run build` for the Rabbita desk bundle, `git diff --check`,
  API verification showing `product_count: 13`, and visible app verification at
  `http://127.0.0.1:4535/?activity=files`.
- Moondesk title/root helpers now use the loaded MoonSuite workspace metadata
  when no MoonBook is selected. The global title bar shows
  `MoonSuite: <root-name>` instead of `No workspace`, and `workspace_root(...)`
  resolves to the active suite root during first-run/no-book flows. Validation
  for this slice: Moondesk `moon fmt`, `moon info`, `moon check`, `moon test`
  with `457/457` tests passing, `npm run build`, `git diff --check`, and
  visible app verification at `http://127.0.0.1:4535/?activity=files` showing
  `MoonSuite: moondesk-phase4-cleanup-run`.
- Moondesk product chips now honor the Phase 7 rule that normal UI avoids
  hidden internal paths. The Rabbita UI model ignores registry `state_path` and
  `service_path`, renders product status as human text such as `INSTALLED`, and
  keeps chip titles to `Product: Status` instead of exposing
  `.moonsuite/products/...` internals. Validation for this slice: Moondesk
  `moon fmt`, `moon info`, `moon check`, `moon test` with `457/457` tests
  passing, `npm run build`, `git diff --check`, and visible app verification at
  `http://127.0.0.1:4535/?activity=files` showing no `.moonsuite/products`
  text or chip titles.
- Moondesk product summary now renders every product from the registry instead
  of a hardcoded core subset. The first-run/no-book Desk UI shows all 13
  installed products in registry order, including MoonStat, MoonFish, MoonMoon,
  MoonRobo, Bookkeeper, Lepusa, and Rabbita, while still keeping hidden
  `.moonsuite/products/...` paths out of normal text and chip titles.
  Validation for this slice: Moondesk `moon fmt`, `moon info`, `moon check`,
  `moon test` with `457/457` tests passing, `npm run build`, `git diff --check`,
  and visible app verification at
  `http://127.0.0.1:4535/?activity=files` showing `chipCount: 13`.
- Moondesk Code mode transcript no longer fabricates a `Working on it...`
  assistant reply for pending prompts or runtime progress without an assistant
  answer. Pending prompts stay visible immediately as user messages, and the
  rendered transcript shows a folded `Thinking` activity row for the queued
  prompt until MoonClaw streams real runtime events or an assistant reply. The
  local-unavailable MoonClaw fallback also stops appending a second prompt-shaped
  command event with `Local agent is not reachable yet...` as its detail when
  the original prompt command has already been recorded; that text remains
  status metadata instead of conversation content.
  Validation for this slice: Moondesk `moon fmt`, `moon info`, `moon check`,
  `moon test` with `458/458` tests passing, `npm run build`,
  `git diff --check`, and visible app verification at
  `http://127.0.0.1:4535/?activity=code` showing no `Working on it...` or
  saved-local-agent message.
- Moondesk workspace kind naming now treats the root workspace as a MoonSuite
  root rather than a Moontown root. The shared `WorkspaceKind` variant is
  `SuiteRoot`, general MoonCode and empty-library discovery use that variant,
  the Rabbita workspace label renders `suite`, and `docs/STATUS.md` describes
  the active MoonSuite root instead of a `.moontown`-gated root. Validation for
  this slice: Moondesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `458/458` tests passing, `npm run build`, `git diff --check`, and visible app
  verification at `http://127.0.0.1:4535/?activity=files` showing MoonSuite UI
  with no town-root wording.
- Moondesk MoonCode capability contracts now describe MoonClaw durable session
  sidecars as product-home state instead of book-local state. The
  `runtime_claim_state` and MoonClaw runtime gap contract strings point to
  commands, receipts, events, and cold sidecar list/show endpoints in the
  MoonClaw product home. Validation for this slice: Moondesk `moon fmt`,
  `moon info`, `moon check`, `moon test` with `458/458` tests passing,
  `npm run build`, `git diff --check`, and visible app verification at
  `http://127.0.0.1:4535/?activity=code` showing no book-local sidecar wording.
- MoonRobo commit `6d706483` removes stale `.moonclaw` home examples from the
  Rabbita cockpit MoonClaw routine fixtures. The fixtures now use a neutral
  `/tmp/moonclaw-root` suite root and assert the current
  `.moonsuite/products/moonclaw/robot-routine-runs` product-home path directly
  instead of carrying negative `.moonclaw/robot-routine-runs` checks. Validation
  for this slice: MoonRobo `moon fmt`, `moon info`, `moon check`, `moon test`
  with `453/453` tests passing, direct old-home file-operation scan with zero
  hits, and `git diff --check`.
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
- MoonClaw commit `56531ec9` removes the last active lifecycle-contract wording
  that described executable-book status as durable book-local sidecars. The
  daemon lifecycle report now names MoonSuite product-home session state as the
  source for MoonClaw status, while Bookkeeper/MoonBook acceptance evidence
  remains the requirement for `accept_result`. Validation for this slice:
  MoonClaw `moon fmt`, `moon info`, `moon check`, `moon test` with `1001/1001`
  tests passing, `git diff --check`, and an active-code stale-layout scan with
  zero MoonClaw hits.
- MoonClaw commit `06ee7020` removes routine stale-path negative assertions and
  legacy runtime-commit fixtures from MoonClaw tests. The native MoonCode commit
  proof now commits normal book files while leaving `.moonsuite` and `.tmp`
  uncommitted, and product-home tests rely on positive MoonSuite assertions
  instead of repeating retired `.moonclaw`, `.moontown`, or
  `.moonclaw-worktrees` names. Validation for this slice: MoonClaw `moon fmt`,
  `moon info`, `moon check`, `moon test` with `1001/1001` tests passing,
  `git diff --check`, and the refined MoonClaw stale-layout scan reduced from
  `34` to `8`, with the remaining hits limited to explicit legacy-ignore
  fixtures for old manifests and old skill/model directories.
- Moontown commit `44b1e5f7` propagates MoonBook's fresh executable-event path
  contract into the Moontown MoonBook adapter. The decoded
  `moonbook.book_state.v1` fixture now expects `events/latest.json` instead of
  the retired `.moonbook/events/latest.json` path. Validation for this slice:
  Moontown `moon fmt`, `moon info`, `moon check`, `moon test` with `926/926`
  tests passing, `git diff --check`, and an active-code stale-layout scan with
  zero Moontown hits.
- Moontown commit `bc3bb5ea` removes stale path fixtures that kept asserting
  retired `.moontown`, `.moonclaw`, and `.moonclaw-worktrees` strings after the
  product-home migration. Remaining MoonClaw adapter fixtures now name
  `.moonsuite/products/moonclaw/...`, cookbook readiness fixtures use the
  Moontown product home, and the source-layout audit no longer allows root
  `.moontown` or `.moonclaw` directories. Validation for this slice: Moontown
  `moon fmt`, `moon info`, `moon check`, `moon test` with `926/926` tests
  passing, `git diff --check`, `scripts/audit-source-layout.sh`, and a refined
  stale-layout scan with zero Moontown hits.
- MoonRobo commit `43621e82` removes the remaining empty-root MoonSuite path
  constructors from product status and SDK E1 bridge sidecar defaults. Product
  status now reports MoonRobo and MoonClaw product homes through explicit
  workspace-root adapters derived from the selected robot book root, and SDK E1
  snapshot/command defaults expose workspace-root helpers that map book roots to
  the suite-level `.tmp/products/moonrobo` temp lane. Validation for this slice:
  MoonRobo `moon fmt`, clean `moon info`, `moon check`, `moon test` with
  `453/453` tests passing, and `git diff --check`.
- Moondesk removes the remaining active `moonclaw-jobs` source-layer
  compatibility alias. Fresh Desk source classification now treats only the
  MoonSuite product-home job path `.moonsuite/products/moonclaw/jobs/...` as a
  run artifact, while retired `moonclaw-jobs/...` paths fall back to ordinary
  workspace files. Validation for this slice: Moondesk `moon fmt`, `moon info`,
  `moon check`, `moon test` with `458/458` tests passing, Rabbita desk
  `npm run build`, a refined active `moonclaw-jobs` scan with only regression
  test hits, and `git diff --check`.

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
- Moondesk commit `e54c4400` routes MoonCode desktop session/event sidecar
  paths through MoonLib workspace-root constructors. The internal MoonCode
  package now exposes workspace-root APIs for all session sidecar paths, and
  MoonWiki read/write handlers use them so suite-hosted `books/<book-id>` roots
  write to suite-level `.moonsuite/products/mooncode/sessions` rather than a
  nested book-local product home. Validation passed with Moondesk `moon fmt`,
  `moon info`, `moon check`, `moon test` (451/451), targeted old-join scan
  clean, and `git diff --check`.
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
- Lepusa commit `32b21b7` turns that root contract from local string
  concatenation into a MoonLib adapter. The public API now exposes explicit
  workspace-root variants for state, service, runtime, update metadata, temp,
  and the aggregate `LepusaMoonSuiteProductHome`; coverage proves a
  suite-hosted book root maps those product-owned paths to the suite root. The
  slice also stabilizes the native auto-launch status test so unsupported host
  platforms assert the explicit unavailable error instead of expecting a native
  payload. Validation passed with Lepusa `moon update`, `moon fmt`,
  `moon info`, `moon check`, `moon test` (374/374), active empty-root
  constructor scan clean, and `git diff --check`.
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
- Rabbita commit `0c45c31` removes the empty-root MoonLib calls left in that
  adapter and adds explicit workspace-root variants for every public
  product-home path. Suite-hosted book roots now map Rabbita product state and
  temp paths to the suite-level `.moonsuite/products/rabbita` and
  `.tmp/products/rabbita` lanes instead of a nested book-local suite. Validation
  passed with Rabbita `moon fmt`, `moon info`, `moon check`, root-package
  `moon test .` (5/5), native `moon test --target native` (25/25), active
  empty-root constructor scan clean, and `git diff --check`; full JS
  `moon test` remains outside this gate because the documented pre-existing DOM
  README examples require a browser `document`.
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
- Moontown now removes the remaining runtime-test fixtures that explicitly
  exercised `root/moonbooks.json` as the catalog location for cookbook and
  book-quality bootstraps. Those tests now use
  `@storage.moontown_product_artifact_for_workspace_root(root,
  "moonbooks.json")`, proving the fresh suite product-home catalog contract in
  the same flows. Validation passed with Moontown `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- Moontown MoonBook evidence accounting now recognizes operational MoonClaw
  run evidence only when the completed workflow path is under the MoonSuite
  product-home job store
  `.moonsuite/products/moonclaw/jobs/run-...`. The retired
  `moonclaw-jobs/run-...` root is covered as ordinary domain evidence rather
  than an active operational marker. Validation for this slice: Moontown
  `moon fmt`, clean `moon info` after reverting unrelated generated `.mbti`
  EOF churn, `moon check`, `moon test` with `927/927` tests passing, refined
  active `moonclaw-jobs` scan with only the negative regression fixture left,
  and `git diff --check`.
- MoonBook serve live-reload runtime state now uses the visible book-output
  state lane `state/moonbook-livereload.token` instead of the retired hidden
  `.moonbook-livereload` file in the generated output root. The serve/watch
  writer creates the state directory before updating the token, and MoonWiki
  server coverage locks the token path away from hidden `.moonbook*` names.
  Validation for this slice: MoonBook `moon fmt`, `moon info`, `moon check`,
  `moon test` with `199/199` tests passing, refined active `.moonbook` scan
  with only the negative assertion and product-name strings left, and
  `git diff --check`.
- MoonClaw provider-task prompts now describe the current internal lanes
  `.moonsuite` and `.tmp` as generated/runtime trees and no longer tell worker
  agents to treat retired `.moonclaw` homes as a fresh-default internal path.
  White-box prompt coverage asserts the provider-task system prompt contains
  the fresh lanes and excludes the retired `.moonclaw` instruction. Validation
  for this slice: MoonClaw `moon fmt`, `moon info`, `moon check`, `moon test`
  with `1002/1002` tests passing, refined active provider-prompt `.moonclaw`
  scan with only the negative prompt assertion left, cleanup of untracked
  test-created `.moonsuite` runtime output, and `git diff --check`.
- MoonClaw job package documentation now describes process output under
  `.moonsuite/products/moonclaw/jobs/processes/<id>` and workflow run
  workspaces under `.moonsuite/products/moonclaw/jobs/<run-id>` instead of
  retired `.moonclaw/jobs` or `moonclaw-jobs` roots. Validation for this slice:
  MoonClaw `moon fmt`, `moon info`, `moon check`, `moon test` with `1002/1002`
  tests passing, refined job README stale-path scan, cleanup of untracked
  test-created `.moonsuite` runtime output, and `git diff --check`.
- MoonClaw operator-facing setup docs now use the fresh MoonSuite product home
  for gateway examples, example workspaces, UI serving notes, and expected
  behavior contracts. Active guides no longer instruct users to start under
  `~/.moonclaw`, inspect `<workspace>/moonclaw-jobs/<run-id>`, or treat
  `.moonclaw` hidden run metadata as the fresh default. Validation for this
  slice: MoonClaw `moon fmt`, `moon info`, `moon check`, `moon test` with
  `1002/1002` tests passing, refined operator-doc stale-path scan, cleanup of
  untracked test-created `.moonsuite` runtime output, and `git diff --check`.
- Moontown active skill/template/cookbook copy now advertises watcher ledgers,
  standing-goal registration, generated cookbook state, and MoonClaw execution
  workspaces under `.moonsuite/products/moontown/...` and
  `.moonsuite/products/moonclaw/jobs/...` instead of retired `.moontown` or
  book-local `.moonclaw/jobs` paths. Validation for this slice: Moontown
  `moon fmt`, `moon info`, `moon check`, `moon test` with `927/927` tests
  passing, refined active-copy stale-path scan with only product helper names
  left, restored whitespace-only generated `.mbti` churn from `moon info`, and
  `git diff --check`.
- MoonBook active README and operator docs now match the fresh visible and
  product-home storage paths already used by implementation: `wiki state`
  writes `state/state.json`, executable events live under `events/`, extension
  manifests live under `extensions/`, and the skill hub advertises
  `.moonsuite/products/moonbook/skill-hub/...` instead of retired
  `.moonbook/...` or `.moonbook-skill-hub` locations. Validation for this
  slice: MoonBook `moon fmt`, `moon info`, `moon check`, `moon test` with
  `199/199` tests passing, refined active-doc `.moonbook` stale-path scan, and
  `git diff --check`.
- MoonClaw active model/setup/routine docs now describe credentials, model
  manifests, gateway config, provider manifests, run metadata, and job
  workspaces under `.moonsuite/products/moonclaw/...` with visible run
  workspaces at `.moonsuite/products/moonclaw/jobs/<run-id>`. They no longer
  present `~/.moonclaw`, `<workspace>/.moonclaw`, `moonclaw-jobs`, or
  `.moonclaw-tool-journal` as the fresh default for active setup and routine
  operation. Validation for this slice: MoonClaw `moon fmt`, `moon info`,
  `moon check`, `moon test` with `1002/1002` tests passing, focused active
  setup/model/routine stale-path scan, cleanup of untracked test-created
  `.moonsuite` runtime output, and `git diff --check`.
- Moontown central operator and architecture docs now describe executable-book
  events, MoonCode sidecars, processed sidecar ledgers, daemon state, watcher
  ledgers, book-template inboxes, book-quality artifacts, PlanBook autonomy,
  live digests, and town synthesis outputs under `.moonsuite/products/...`
  product homes instead of retired book-local or repo-local `.moonbook`,
  `.moonclaw`, and `.moontown` roots. Validation for this slice: Moontown
  `moon fmt`, `moon info`, `moon check`, `moon test` with `927/927` tests
  passing, focused central-doc stale-path scan with only the
  `com.vectie.moontown` launchd identifier false positive, restored
  whitespace-only generated `.mbti` churn from `moon info`, and
  `git diff --check`.
- MoonClaw remaining active job/agent documentation now describes job indexes,
  run artifacts, runtime skills, AI-orchestration skill contracts, gateway
  agent sessions, credentials, conversations, logs, and model config under the
  MoonClaw product home at `.moonsuite/products/moonclaw/...` instead of
  `~/.moonclaw` or project-local `.moonclaw` roots. Validation for this slice:
  MoonClaw `moon fmt`, `moon info`, `moon check`, `moon test` with
  `1002/1002` tests passing, focused stale-path scan across the patched docs
  with zero hits, cleanup of test-created untracked `.moonsuite` runtime
  output, and `git diff --check`.
- MoonBook keeper call-chain and system architecture docs now point observed
  MoonClaw run metadata, event logs, step files, and output artifacts at
  `.moonsuite/products/moonclaw/jobs/...`, and use the fresh visible
  `extensions/` plus `state/` book contracts instead of retired `.moonclaw`,
  `moonclaw-jobs`, or `.moonbook` paths. Validation for this slice: MoonBook
  `moon fmt`, `moon info`, `moon check`, `moon test` with `199/199` tests
  passing, focused MoonBook docs stale-path scan with zero hits, and
  `git diff --check`.
- Moontown Wenyu building/status/valley docs now describe protocol ledgers,
  watcher ledgers, daemon state, town-runtime projection, and backup scope
  under `.moonsuite/products/moontown/...` instead of the retired
  repo-local `.moontown` root. Validation for this slice: Moontown `moon fmt`,
  `moon info`, `moon check`, `moon test` with `927/927` tests passing, focused
  Moontown docs stale-path scan with only the `com.vectie.moontown` launchd
  identifier false positive, restored whitespace-only generated `.mbti` churn
  from `moon info`, and `git diff --check`.
- Moondesk Wiki-mode E2E test planning now routes backward-run MoonClaw
  artifacts to `raw/analysis-runs` or the product-home jobs lane at
  `.moonsuite/products/moonclaw/jobs` instead of presenting retired
  `moonclaw-jobs` as an active inspection location. Validation for this slice:
  focused `docs/WIKI_MODE_TEST_PLAN.md` stale-path scan and `git diff --check`;
  broader residual scans still show intentional drift/regression fixtures in
  MoonStat, MoonClaw, MoonBook, Moontown, and Moondesk tests.
- MoonClaw active ACP, onboarding, gateway, proposal, model-selection, channel,
  and example-job docs now present `/path/to/MoonSuiteRoot` as the explicit
  suite root and place product runtime files under
  `/path/to/MoonSuiteRoot/.moonsuite/products/moonclaw/...` instead of using
  the operator's home directory as the example root. Validation for this slice:
  focused MoonClaw active-doc scan for `--home ~`, `~/.moonsuite`, and
  `~/Workspace/review-scratch`; MoonClaw `moon fmt`, `moon info`,
  `moon check`, `moon test` with `1002/1002` tests passing; cleanup of
  test-created untracked `.moonsuite` runtime output; and `git diff --check`.
- MoonClaw daemon package docs and public doc comments now describe the daemon
  lock as
  `/path/to/MoonSuiteRoot/.moonsuite/products/moonclaw/daemon.json` rather than
  `~/.moonsuite/products/moonclaw/daemon.json`, keeping daemon operator
  instructions aligned with the explicit suite-root examples. Validation for
  this slice: focused MoonClaw daemon/docs scan for `~/.moonsuite`, `--home ~`,
  and `home directory`, plus MoonClaw `moon fmt`, `moon info`, `moon check`,
  `moon test`, and `git diff --check`.
- MoonClaw gateway, model loader, agent, and skills package docs/comments now
  treat the `home` argument as the explicit MoonSuite root and describe skill,
  model, and agent state under
  `/path/to/MoonSuiteRoot/.moonsuite/products/moonclaw/...` instead of teaching
  `~` or the user's OS home directory as the fresh contract. Validation for
  this slice: focused MoonClaw docs/comment scan for `~/.moonsuite`,
  `--home ~`, `home directory`, `user's home`, and `system's home`; MoonClaw
  `moon fmt`, `moon info`, `moon check`, `moon test`; cleanup of test-created
  untracked `.moonsuite` runtime output; and `git diff --check`.
- MoonStat OpenClaw standalone workspace state now belongs to MoonStat's
  product home. The `/workspace/files...` and `/workspace/memory...` helpers
  derive `.moonsuite/products/moonstat/openclaw/workspace` through MoonLib's
  workspace-root product-artifact constructor instead of writing directly to
  `~/.moonsuite/openclaw/workspace`; white-box coverage now asserts the
  product-owned workspace and memory paths and rejects the old standalone
  location. Validation for this slice: focused MoonStat OpenClaw workspace
  stale-path scan, `moon fmt`, `moon info`, `moon check`, `moon test` with
  `775/775` tests passing, and `git diff --check`.
- MoonStat-owned auth and gateway token stores now live under MoonStat's
  product home. Codex OAuth credentials, Copilot credentials, and the Claude
  Desktop gateway token derive
  `.moonsuite/products/moonstat/auth/...` through MoonLib workspace-root
  product-artifact constructors instead of using top-level `~/.moonsuite`
  files; the external Codex CLI source credential at `.codex/auth.json`
  remains an external source-of-truth reader. Validation for this slice:
  focused MoonStat auth/token stale-path scan, no generated `.mbti` changes,
  `moon fmt`, `moon info`, `moon check`, `moon test` with `779/779` tests
  passing, cleanup of test-created untracked `.moonsuite` runtime output, and
  `git diff --check`.
- Moondesk's optional MoonStat plugin now discovers MoonStat through the active
  workspace's suite-status contract instead of concatenating the operator home
  directory with `/.moonsuite/suite-status.json`. The plugin derives
  `.moonsuite/suite-status.json` from MoonLib's workspace-root suite
  constructor, keeps rejecting legacy shortcut status shapes, and has
  white-box coverage for suite-hosted book workspaces. Validation for this
  slice: focused Moondesk MoonStat plugin stale-path scan, no generated
  `.mbti` changes, `moon fmt`, `moon info`, `moon check`, `moon test` with
  `459/459` tests passing, and `git diff --check`.
- MoonClaw and Moontown now apply the same MoonStat plugin suite-status
  discovery contract. Their optional MoonStat clients derive the active
  workspace's `.moonsuite/suite-status.json` path through MoonLib instead of
  reading `$HOME/.moonsuite/suite-status.json`, with white-box coverage for
  suite-hosted book workspaces and stale-path scans limited to canonical test
  expectations. Validation for this slice: MoonClaw `moon fmt`, `moon info`,
  `moon check`, `moon test` with `1003/1003` tests passing and cleanup of
  test-created untracked `.moonsuite` runtime output; Moontown `moon fmt`,
  `moon info` with unrelated whitespace-only `.mbti` churn restored,
  `moon check`, `moon test` with `928/928` tests passing; focused plugin
  stale-path scans; and `git diff --check` in both repos.
- MoonBook's optional MoonStat plugin now uses the same MoonLib-derived
  suite-status discovery path as Moondesk, MoonClaw, and Moontown. The plugin
  reads the active workspace's `.moonsuite/suite-status.json` instead of
  deriving `$HOME/.moonsuite/suite-status.json`, with white-box coverage for
  suite-hosted book workspaces and a focused stale-path scan limited to the
  canonical test expectation. Validation for this slice: MoonBook `moon fmt`,
  `moon info` with no generated `.mbti` changes, `moon check`, `moon test`
  with `200/200` tests passing, and `git diff --check`. The MoonBook push also
  reconciled Gitee's older divergent `main` without keeping legacy
  `moon.mod.json` or the stale singular `plugin/moonstat` directory.
- MoonFish suite-status references now use structured path construction for
  the active MoonSuite state file. The model helper derives
  `.moonsuite/suite-status.json` with MoonLib `state_dir` plus `pathx.join`
  instead of hand-concatenating path text, tests cover both standalone and
  suite-hosted roots, and the PA Agent migration plan now names
  `<MoonSuiteRoot>/.moonsuite/suite-status.json` instead of the retired
  home-global status file. Validation for this slice: focused MoonFish stale
  status-path scan, `moon fmt`, `moon info` with unrelated whitespace-only
  `.mbti` churn restored, `moon check`, `moon test` with `145/145` tests
  passing, and `git diff --check`.
- Moondesk's MoonCode and executable-book architecture docs no longer show
  book-local `.moonclaw/mooncode/sessions` as the durable layout. The current
  docs describe native MoonCode session sidecars under the selected
  MoonSuite root's MoonClaw product home at
  `.moonsuite/products/moonclaw/mooncode/sessions/...`, keeping the public
  architecture guidance aligned with the runtime contract used by MoonClaw and
  Moondesk projections. Validation for this slice: focused stale-layout doc
  scan, Moondesk `moon test` with `459/459` tests passing, and
  `git diff --check`.
- Moontown's top-level README no longer advertises retired
  `.moontown/civic/...` schedule, scenario, or pattern-run paths. The operator
  quickstart now matches the rest of the Moontown civic docs and runtime
  helpers by pointing communication-pattern state at
  `.moonsuite/products/moontown/civic/...`. Validation for this slice: focused
  README stale-path scan and `git diff --check` in Moontown and Moondesk.
- MoonClaw's todo tool coverage no longer renders `.moonclaw/repos/...` as an
  example repository inspection target in user-visible todo output. The fixture
  now uses the MoonClaw product home at
  `.moonsuite/products/moonclaw/repos/...`, while the remaining MoonClaw
  `.moonclaw` scan hits are negative regression assertions or deliberate
  legacy-reader fixtures. Validation for this slice: focused MoonClaw
  todo/operator-output stale-path scan, `moon fmt`, `moon info`, `moon check`,
  `moon test`, and `git diff --check`.
- MoonStat's suite integration JSON no longer advertises home-global
  `~/.moonsuite/products/moonclaw/...` candidates for MoonClaw model and config
  files. The MoonClaw integration now exposes only the active workspace-root
  product-home paths derived through MoonLib, and coverage rejects the old
  home-global candidates. Validation for this slice: focused MoonStat
  `~/.moonsuite/products/moonclaw` scan, `moon fmt`, `moon info`, `moon check`,
  `moon test`, cleanup of test-created untracked `.moonsuite` output, and
  `git diff --check`.
- MoonClaw OAuth credential storage now has explicit workspace-root APIs for
  Codex and Copilot credentials. The onboarding CLI and daemon auth endpoints
  use the selected MoonSuite root instead of silently storing MoonClaw-owned
  credentials under the process OS home; the remaining no-argument credential
  helpers are only the compatibility/default surface for subprocesses whose
  `HOME` is already set to the suite root. New coverage proves explicit-root
  Codex and Copilot saves land under the suite MoonClaw product home and do not
  create OS-home product credentials. Validation for this slice: focused
  MoonClaw OAuth home-global scan, `moon fmt`, `moon info`, `moon check`,
  `moon test`, cleanup of test-created untracked `.moonsuite` output, and
  `git diff --check`.
- MoonRobo's SDK E1 sidecar default snapshot and command paths now compose the
  MoonLib-derived product tmp directory with structured path joins instead of
  interpolating slash-suffixed strings. This keeps the active bridge sidecar
  defaults aligned with the shared MoonSuite tmp contract and removes the last
  active MoonRobo `product_tmp_dir(...)/sdk-e1/...` string-concatenation path.
  Validation for this slice: focused MoonRobo SDK E1 product-tmp scan, `moon
  fmt`, `moon info`, `moon check`, `moon test`, and `git diff --check`.
- MoonRobo's host API Robo loop and Robo turn response paths now compose the
  MoonLib-backed product-home directories with `@pathx.join` instead of
  slash-appending persisted response filenames. This keeps the remaining
  product orchestration response paths on the same structured path contract as
  the migrated runtime adapters. Validation for this slice: focused MoonRobo
  Robo loop/turn concat scan, `moon fmt`, `moon info`, `moon check`, `moon
  test`, and `git diff --check`.
- MoonLib's MoonSuite contract now has a source-level `0.1.4` shared
  `ProductHome` surface with product state, service, cache, temp, and accepted
  book-output paths plus workspace-root constructors. This is the shared layer
  needed to remove the remaining duplicated MoonFish/MoonMoon product-home
  facade formulas after the MoonLib publish/consume slice. Validation for this
  slice: MoonLib `moon fmt`, `moon info`, `moon check`, focused `moon test
  moonsuite`, and `git diff --check` on the touched MoonLib files.
- MoonLib `0.1.4` is now published and consumed by MoonFish and MoonMoon.
  Their root product-home facades keep the existing product-specific public
  structs but wrap the shared `@moonsuite.product_home_for_workspace_root`
  contract, removing the duplicated product state/service/cache/temp/output
  path formulas from both products. Validation for this slice: MoonFish and
  MoonMoon `moon update`, `moon fmt`, `moon info`, `moon check`, full `moon
  test`, focused facade primitive-formula scans, and `git diff --check`.
- MoonRobo now consumes MoonLib `0.1.4` for product-home projection in
  `src/product_status`. The public MoonRobo/MoonClaw product-home helpers keep
  their existing string-returning API, but derive the home paths from the shared
  `@moonsuite.product_home_for_workspace_root` contract instead of locally
  reconstructing `product_dir(...)`. Validation for this slice: MoonRobo `moon
  update`, `moon fmt`, `moon info`, `moon check`, full `moon test`, focused
  product-status `product_dir` scan, generated-interface churn restore, and
  `git diff --check`.
- Moondesk now consumes MoonLib `0.1.4` in its internal MoonWiki MoonSuite
  facade. Workspace-derived product home and service paths resolve through
  `@moonsuite.product_home_for_workspace_root`, while the direct suite-root
  product-directory wrapper remains only for preparing product directories in
  an already-selected suite root. Validation for this slice: Moondesk `moon
  update`, `moon fmt`, `moon info`, `moon check`, full `moon test`, focused
  facade primitive-formula scan, and `git diff --check`.
- Moontown now consumes MoonLib `0.1.4` in its storage facade. Product state,
  service, and temp path helpers derive from
  `@moonsuite.product_home_for_workspace_root`, while arbitrary product
  artifacts stay on the existing MoonLib artifact constructor. Validation for
  this slice: Moontown `moon update`, `moon fmt`, `moon info`, `moon check`,
  full `moon test`, focused storage primitive-formula scan,
  generated-interface churn restore, and `git diff --check`.
- MoonClaw now consumes MoonLib `0.1.4` for its active product-home facade and
  temp/state lanes. The job product-home helper, ACP state parent, analysis
  tool-journal temp directory, and worktree scratch root now derive from
  MoonLib `ProductHome` fields, and ACP fixtures no longer create product
  homes through primitive `product_dir` calls. Validation for this slice:
  MoonClaw `moon update`, `moon fmt`, `moon info`, `moon check`, full
  `moon test`, focused primitive-constructor scan, generated-interface diff
  review, test-output cleanup, and `git diff --check`.
- MoonStat now consumes MoonLib `0.1.4` for suite status and drift canonical
  product paths. Suite canonical product homes, MoonRobo suite-temp SDK paths,
  and legacy drift canonical targets now derive from MoonLib `ProductHome`
  fields instead of direct `product_dir`/`product_tmp_dir` formulas, and the
  workspace-root MoonStat product-home helper uses the workspace-root
  `ProductHome` constructor. Validation for this slice: MoonStat `moon update`,
  `moon fmt`, `moon info`, `moon check`, full `moon test`, focused
  primitive-constructor scan, generated-interface diff review,
  test-output cleanup, and `git diff --check`.
- The remaining MoonLib `0.1.3` consumers have been cleared. MoonBook now
  depends on MoonLib `0.1.4`; Lepusa and Rabbita both consume MoonLib `0.1.4`
  and route their product-home facades through shared `ProductHome` fields for
  state, service, cache where applicable, and temp paths. Validation for this
  slice: MoonBook, Lepusa, and Rabbita `moon update`, `moon fmt`, `moon info`,
  `moon check`; MoonBook full `moon test` (`200/200`), Lepusa full `moon test`
  (`374/374`), Rabbita focused native/root and MoonSuite layout tests after the
  full Rabbita suite hit the pre-existing JS DOM-doc `document is not defined`
  environment failure; focused old-pin and primitive-constructor scans, Lepusa
  generated-interface churn restore, and `git diff --check`.
- MoonRobo runtime and bridge sidecar residuals now consume MoonLib
  `ProductHome` fields directly. The RoboBook runtime product-home helper and
  SDK E1 sidecar snapshot/command temp paths no longer rebuild
  `product_dir`/`product_tmp_dir` formulas locally, and their tests now assert
  through the shared `ProductHome` contract. Validation for this slice:
  MoonRobo `moon fmt`, `moon info`, `moon check`, full `moon test` (`453/453`),
  focused primitive-constructor scan, generated-interface churn restore, and
  `git diff --check`.
- Moontown runtime, storage, and book-quality residuals now consume MoonLib
  `ProductHome` fields directly. The PlanBook MoonClaw runtime adapter,
  Moontown temp-dir assertion, and book-quality MoonClaw home helpers no longer
  rebuild product state/temp homes through primitive constructors or empty
  artifact paths. The remaining Moondesk MoonWiki suite-root facade also now
  returns `ProductHome.state_path` instead of delegating to the primitive
  product-dir constructor. Validation for this slice: Moontown `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`928/928`), Moondesk `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`459/459`), generated-interface
  churn restore, `git diff --check`, and a cross-product `.mbt` scan proving
  zero remaining direct calls to `@moonsuite.product_dir`,
  `@moonsuite.product_tmp_dir`, or `@moonsuite.product_service_path` in the
  scanned product repos.
- Moontown PlanBook runtime display text now routes product-home examples
  through a storage-owned display helper instead of hand-written
  `.moonsuite/products/moontown/...` literals. `storage` now exposes
  `moontown_product_display_artifact` for relative documentation/operator
  strings, and PlanBook autonomy digest, repair-plan, UI-spine, and validation
  next-action text use that helper. Validation for this slice: Moontown
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`928/928`),
  generated-interface diff review for the intentional storage API addition,
  generated-interface churn restore, `git diff --check`, and a focused
  PlanBook/runtime storage scan proving zero remaining hard-coded
  `.moonsuite/products/moontown` strings in non-test MoonBit source for those
  packages.
- Moontown native cookbook, civic, and book-quality display text now also
  routes product-home examples through storage-owned display helpers.
  `storage` exposes `moontown_product_display_state_dir` for product-home root
  references, the cookbook package has local formatting helpers backed by
  storage, and cookbook stable-state manifests/pages, civic protocol ledger
  text, and book-quality packet readme text no longer hand-write
  `.moonsuite/products/moontown/...` literals. Validation for this slice:
  Moontown `moon fmt`, `moon info`, `moon check`, full `moon test` (`928/928`),
  generated-interface diff review for the intentional storage API addition,
  generated-interface churn restore, `git diff --check`, a focused native
  package scan proving zero remaining hard-coded `.moonsuite/products/moontown`
  strings in non-test `src/cookbook`, `src/civic`, and `src/book_quality`
  MoonBit source, and a broader remaining-source scan showing the remaining
  active display literals are isolated to PlanBook/editor template text and the
  Rabbita-town JS UI package.
- Moontown PlanBook/editor template packages and the Rabbita-town JS UI package
  now clear the remaining active Moontown product-home display literals.
  PlanBook/editor native template text uses the storage-owned display helper;
  `editor_pipeline` and `planbook_policy` declare native targets after the
  storage dependency. The JS UI package keeps a local pure-string display helper
  because the browser target cannot depend on native storage. Validation for
  this slice: Moontown `moon fmt`, `moon info`, `moon check`, full `moon test`
  (`928/928`), generated-interface churn restore, `git diff --check`, and an
  active non-test MoonBit source scan proving the only remaining
  `.moonsuite/products/moontown` literal is the UI helper's single source of
  truth.
- MoonRobo active MoonBook/readiness projections now route the remaining
  product-home display literals through a product-status display helper instead
  of hand-written `.moonsuite/products/moonrobo/...` strings. The helper keeps
  user-facing contract strings separate from root-sensitive runtime
  `ProductHome` paths while MoonBook task evidence, MoonBook memory cards, and
  readiness runtime-health checks all consume the same display contract.
  Validation for this slice: MoonRobo `moon fmt`, `moon info`, `moon check`,
  full `moon test` (`453/453`), generated-interface diff review for the
  intentional product-status API addition, generated-interface churn restore,
  `git diff --check`, and an active non-test MoonBit source scan proving the
  only remaining `.moonsuite/products/moonrobo` literal is the product-status
  display helper's single source of truth.
- MoonLib `0.1.5` now owns the shared root-independent product display-path
  contract: `product_display_dir`, `product_display_artifact`, and
  `product_display_absolute_artifact`. The helper separates user-facing
  relative contract strings from root-sensitive runtime `ProductHome` paths.
  Moondesk now consumes the shared helper through `core` and routes MoonClaw
  job paths, Moontown bridge paths, Moondesk trash paths, PDF watch Moontown
  publish metadata, and MoonCode contract text through it. MoonRobo's
  product-status display helper now delegates to the MoonLib contract instead
  of owning the formula locally. Validation for this slice: MoonLib clean
  worktree `moon fmt`, `moon info`, `moon check`, full `moon test` (`37/37`),
  `moon publish` for `vectie/moonlib@0.1.5`, Moondesk `moon fmt`, `moon info`,
  `moon check`, full `moon test` (`459/459`), MoonRobo `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`453/453`), generated-interface
  diff review/churn restore, `git diff --check`, and focused active-source
  scans proving Moondesk has zero `.moonsuite/products` literals while MoonRobo
  has zero `.moonsuite/products/moonrobo` literals and no MoonLib `0.1.4` pin.
- The remaining clean product repos now consume MoonLib `0.1.5` for this
  display-contract slice. Moontown storage and Rabbita-town display helpers
  delegate to `product_display_dir` / `product_display_artifact`, and the
  MoonClaw run/evidence bridge uses MoonLib display helpers for MoonClaw job
  paths. MoonClaw MoonCode session display text, ACP help text, daemon/job
  capability text, rules output, and skills/daemon comments now route through
  the shared display contract or avoid hand-written product-home paths.
  MoonStat command help derives the MoonClaw providers path through MoonLib.
  MoonBook extension tests now assert expected MoonClaw product paths through
  MoonLib constructors. MoonFish, MoonMoon, and Lepusa were upgraded to the
  same dependency version so the clean suite-wide consumers are aligned on the
  published contract. Validation for this slice: Moontown `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`928/928`), MoonClaw
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`1005/1005`),
  MoonStat
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`779/779`),
  MoonBook `moon fmt`, `moon info`, `moon check`, full `moon test`
  (`200/200`), MoonFish `moon fmt`, `moon info`, `moon check`, full
  `moon test` (`145/145`), MoonMoon `moon fmt`, `moon info`, `moon check`,
  full `moon test` (`143/143`) with the existing two unused-value warnings,
  Lepusa `moon fmt`, `moon info`, `moon check`, full `moon test` (`374/374`),
  generated-interface churn review/restore, MoonClaw/MoonStat test-output
  cleanup, `git diff --check`, a clean touched-repo stale-pin scan for
  `vectie/moonlib@0.1.4` and older, and active-source scans proving Moontown
  and MoonClaw have no raw `.moonsuite/products` literals outside tests and
  generated interfaces.
- Moontown now has an explicit `MOONTOWN_SUITE_ROOT` fresh-suite override for
  CLI product writers, and its default MoonBook workspace roots derive from the
  same active suite root. This aligns command-line writer behavior with the
  folder-selected VFS model instead of relying on the process cwd. The new
  `scripts/fresh-suite-writers-smoke.sh` gate runs PlanBook, Wenyu course,
  cookbook, book-quality, and live-autonomy writers against a temporary fresh
  suite root, then asserts durable product state lands under
  `.moonsuite/products/moontown`, generated MoonBooks land under `books/`, the
  repo cwd is not polluted with generated books, and retired `.moontown`,
  `.moonclaw`, and `moonclaw-jobs` paths are not recreated.

Remaining high-priority product slices:

- MoonLib: expand `vectie/moonlib/moonsuite` only when a missing contract is
  shared by more than one product; keep it deterministic and free of daemon,
  analytics, and UI dependencies. Current published contract version is
  `vectie/moonlib@0.1.5`; its generic `ProductHome` contract is now the shared
  source for runtime product paths, and its product display-path contract is the
  shared source for root-independent user-facing product artifact strings.
  Current product-repo scan has no remaining `vectie/moonlib@0.1.3` or
  `vectie/moonlib@0.1.4` pins in the touched product repos: Moondesk,
  MoonRobo, Moontown, MoonClaw, MoonStat, MoonBook, MoonFish, MoonMoon,
  MoonChat, MoonVis, and Lepusa.
- MoonStat: Phase 8 drift coverage for the known legacy product homes,
  repo-local runtimes, and MoonRobo global temp files is now covered. Keep
  consuming MoonLib contracts for workspace validation, health projection, and
  future drift additions, but do not add a parallel path schema there. The
  book-local MoonClaw provider and MoonCode sidecar drift targets now derive
  from the MoonLib workspace-root product-artifact helper, matching MoonClaw's
  current durable product-home contract. Suite status canonical paths and
  legacy-drift canonical targets now consume MoonLib `ProductHome` fields
  directly. MoonFish's legacy `.moonfish`, MoonMoon's legacy `.moonmoon`,
  MoonChat's legacy `.moonchat`, and MoonVis's legacy `.moonvis` suite-root
  homes are now reported as drift against their matching
  `.moonsuite/products/<product>` homes; remaining work should focus on new
  drift coverage rather than local product-home formula cleanup. The canonical
  drift payload now also exposes the full first-party product-home set for
  Moondesk, MoonBook, MoonWiki, MoonCode, MoonStat, MoonClaw, Moontown,
  MoonRobo, MoonFish, MoonMoon, MoonChat, MoonVis, Bookkeeper, Lepusa, and
  Rabbita through MoonLib-derived paths, so downstream validators can compare
  every product against one contract report.
- Moondesk: MoonCode session/event sidecars and the Moontown bridge
  request/dispatch ledgers now derive from MoonLib workspace-root helpers, and
  MoonClaw job roots plus Moondesk daemon/preference state now resolve through
  the owning suite instead of nested book-local `.moonsuite` directories. Trash
  file and receipt coverage now proves the same suite-root behavior for direct
  Desk and HTTP flows. The internal MoonWiki layout facade now consumes
  MoonLib `ProductHome` for suite-root and workspace-derived product home and
  service paths. Moondesk `core` now exposes MoonLib-backed product display
  helpers, and active MoonWiki/MoonCode/MoonBook adapter product-home display
  strings route through that shared contract.
  The current Moondesk MoonBit scan has zero quoted
  `.moontown`/`.moonclaw` literals, zero active old-path file-operation hits,
  and zero active `.moonsuite/products` literals outside generated interfaces
  and tests. The new `scripts/fresh_suite_product_smoke.sh` gate runs the
  Moontown, MoonClaw, MoonBook, MoonRobo, MoonFish, MoonMoon, MoonChat,
  MoonVis, and Lepusa fresh-suite smoke scripts from one Moondesk command,
  giving the migration a single cross-product integration check for the main
  writer surfaces and product-home contracts already cut over to product homes.
  Remaining Phase 4 work should focus on cross-product residuals and any
  product-home display/API text that belongs in Phase 6 or Phase 7 rather than
  Moondesk old-writer cleanup.
- Moontown: remaining Phase 5 work should focus on any product-owned residual
  writers discovered by new smoke coverage; the programmatic Rabbita/Moondesk
  contract, full Desk browser smoke, Lepusa-native fresh-books smoke, and
  launchd product-home script path are now covered. The MoonCode sidecar
  processed-result ledger and MoonBook fallback checkout path are now
  product-home based, and the active MoonClaw command/book-quality/preseed,
  run polling, plus PlanBook repair/editor feature-selection MoonClaw home
  flows now use MoonLib-backed MoonClaw product homes instead of `.moonclaw`.
  The storage facade now derives Moontown product state, service, and temp
  paths from MoonLib `ProductHome`; the PlanBook runtime adapter and
  book-quality MoonClaw homes now also derive through MoonLib `ProductHome`
  fields. PlanBook runtime operator/display strings now use the storage-owned
  product display helper for Moontown product artifacts. Native cookbook,
  civic, book-quality, PlanBook/editor template, and Rabbita-town UI display
  strings also route through MoonLib-backed storage-owned or package-local
  display helpers.
  Moontown CLI writers now honor `MOONTOWN_SUITE_ROOT`, default MoonBook roots
  derive from that active suite root, and a fresh-suite writer smoke gate covers
  representative product-owned PlanBook, course, cookbook, book-quality, and
  live-autonomy outputs. Remaining Moontown work should focus on newly
  discovered product-owned residuals from deeper smoke coverage, not local
  product-home display formula cleanup.
- MoonBook: the MoonClaw wiki extension now keeps its workspace-owned
  `moonclaw.jobs.json` beside the book, but writes the MoonClaw runtime config
  to the suite product home at `.moonsuite/products/moonclaw/moonclaw.json`
  instead of recreating a book-root `moonclaw.json`. The extension manifest
  advertises the product-home config entry, provider manifests remain under the
  MoonClaw product home, and `scripts/fresh-suite-extension-smoke.sh` now runs
  native `wiki init` plus `wiki enable moonclaw` against a fresh
  `books/<book-id>` root to prove both product-home writes and absence of
  legacy `.moonclaw`, root `moonclaw.json`, and `moonclaw-jobs` paths.
- MoonRobo: continue residual audits for any newly discovered writers, keeping
  RoboBook-owned receipts, telemetry, task executions, reviews, observations,
  and model edits under the book root while any remaining product orchestration
  path must remain a MoonLib-backed adapter. Runtime supervisor, health,
  validation, calibration, bridge dispatches, bridge contracts, gateway
  commands, dry-run evidence, approval records, Robo loops, Robo turns,
  prove-loop records, proof sessions, live exercises, and SDK IPC state are now
  product-home or suite-temp based; product-status product homes now derive
  from MoonLib `ProductHome`; the runtime adapter and SDK E1 bridge sidecar now
  resolve product state/temp paths through MoonLib `ProductHome` fields from
  either a suite root or a `books/<book-id>` workspace root. Rabbita cockpit
  UI/parser fixtures and active MoonBook/readiness projections now advertise
  those product-home paths through product-status display helpers backed by the
  shared MoonLib display contract for the migrated artifact classes. The new
  `scripts/fresh-suite-product-home-smoke.sh` gate drives native bootstrap,
  gateway-command, prove-loop, proof-session, Robo turn, and Robo loop CLI
  surfaces against a temporary `books/<book-id>` root, then asserts product
  orchestration artifacts land under `.moonsuite/products/moonrobo`, RoboBook
  memory/task artifacts stay under the book root, and legacy `.moonrobo`,
  root-level `runs/gateway-commands`, `runs/robo-loops`,
  `runs/proof-sessions`, plus book-local `.moonsuite/products/moonrobo` paths
  are not recreated. MoonRobo native HTTP wrappers were also refreshed to the
  current `moonbitlang/async/http` `Client` and `Server` APIs so the native CLI
  and smoke gate compile on the fresh dependency set instead of relying on stale
  compatibility.
- MoonClaw: remaining residuals are mostly historical compatibility docs,
  explicit project-local override policy coverage, and any newly discovered
  readers from deeper smoke runs. New runtime writes for conversations, jobs,
  gateway, onboarding config, workspace defaults, ACP state, OAuth credentials,
  starter attachments, provider-task artifacts, worktree scratch, MoonCode
  sessions and watchers, skills, rules, daemon lock, robot routine ledgers, and
  todo session state are now MoonLib-backed product-home or suite-temp based.
  The active MoonClaw product-home facade, ACP state parent, job-analysis tool
  journals, and worktree scratch roots now consume MoonLib `ProductHome`
  fields directly instead of rebuilding product state or temp formulas locally.
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
  stores. The new `scripts/fresh-suite-product-home-smoke.sh` gate drives the
  native `onboard init` and `acp add codex` CLI surfaces against a temporary
  fresh suite root, then asserts `moonclaw.json` plus managed workspace files
  land under `.moonsuite/products/moonclaw` and legacy `.moonclaw`,
  root-level `moonclaw.json`, `moonclaw-jobs`, and `.moonclaw-worktrees` paths
  are not recreated.
- Rabbita and future products: Rabbita now has an explicit root product-home
  contract and white-box coverage, and its facade consumes MoonLib `ProductHome`
  fields instead of local product state/service/cache/temp formulas. Remaining
  work is broader browser-backed smoke integration for Rabbita and future
  products rather than local string-contract extraction. MoonFish, MoonMoon,
  MoonChat, and MoonVis have root product-home contracts. MoonFish, MoonMoon,
  and MoonChat consume MoonLib directly; MoonVis is a frontend-only Vite
  product, so its local contract mirrors the MoonLib `ProductHome` fields and
  is covered by the same cross-product smoke gate. MoonFish, MoonMoon, and
  MoonChat also have native CLI `layout` commands, and MoonVis has a Node
  `scripts/moonsuite-layout.mjs` command, plus
  `scripts/fresh-suite-product-home-smoke.sh` gates, which resolve temporary
  `books/<book-id>` workspace roots through the shared MoonLib contract and
  assert product state/service/cache paths land under
  `.moonsuite/products/<product>`, temp paths land under
  `.tmp/products/<product>`, accepted outputs stay under
  `books/<book-id>/outputs/<product>`, and stale hidden product homes or
  book-local `.moonsuite/products/<product>` paths are not advertised.
