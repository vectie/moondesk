# MoonSuite Layout Migration Plan

This plan makes MoonSuite v2 the fresh default filesystem contract. There is no
legacy compatibility target for new writes: MoonDesk should initialize and use a
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
      moongate/
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
products. MoonDesk should discover products from this registry instead of
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
- `moongate`
- `moonfish`
- `moonmoon`
- `moonrobo`
- `bookkeeper`
- `lepusa`
- `rabbita`

## Shared Contract Layer

Decision: the shared MoonSuite contract layer belongs in MoonLib. MoonGate is
not the right owner because its job is observation, validation, metrics, and
drift reporting over live workspaces. Putting the contract in MoonGate would
make every product depend on an analytics/status product just to construct
paths, which is the wrong dependency direction.

MoonSuite filesystem contracts should be defined in `moonlib`, not `moongate`.
`moonlib` is the shared source of truth for low-level suite layout contracts:
suite root discovery, product registry schema, product state paths, suite temp
paths, book paths, artifact classes, and typed path constructors. It must stay
dependency-light and deterministic so every Moon product can use it without
pulling in status, analytics, or daemon behavior.

`moongate` should consume the `moonlib` contract layer. Its responsibility is to
audit live workspaces, report drift, index metrics/snapshots, and surface health
views. It can enforce that products follow the contract, but it should not own
the contract itself.

Phase 4.5 is now the active MoonLib-first contract extraction track running
alongside the remaining product-home migration:

1. Create the MoonSuite contract package in `moonlib`.
2. Move shared product ids, registry schema, and path constructors into that
   package.
3. Replace product-local string helpers with `moonlib` contract calls.
4. Make `moongate` validate workspaces against `moonlib` contracts and report
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
roots and still derive the correct owning suite product home. MoonDesk depends
on MoonLib `0.1.3` and `internal/moonwiki/moonsuite_layout.mbt` is a thin
compatibility adapter over `@moonsuite` for suite root, book root, product-home,
workspace-root-derived product artifacts, manifest, registry, cache, and
service paths. Remaining product-local helpers should follow the same wrapper
pattern instead of carrying independent string contracts.
- MoonGate now depends on MoonLib `0.1.2` and consumes `@moonsuite` for its
  home `.moonsuite` state directory plus MoonClaw product-home provider, model,
  and config manifest paths. MoonGate also exposes `moongate suite drift` and
  `/suite/drift` as a MoonLib-derived drift report over legacy `.moontown`,
  `.moonclaw`, repo-local runtime, old MoonGate state paths, MoonRobo product
  runtime paths, old global SDK E1 temp files, and book-local
  `.moonclaw/providers.json` / `.moonclaw/mooncode/sessions` drift under
  `books/<book-id>`. MoonGate remains an observer/reporter over the shared
  contract rather than the source of path definitions. Validation for the latest
  MoonGate slice: `moon fmt`, `moon info`, `moon check`, and `moon test` with
  `774/774` tests passing.
- MoonGate commit `26531ce` removes the remaining empty-root MoonSuite
  constructors from active suite/config defaults. MoonGate app config, suite
  status, MoonClaw provider/model/config manifest candidates, and suite
  integration commands now derive from the active workspace root or explicit
  workspace-root helpers, while `books/<book-id>` roots are tested to resolve to
  suite-level `.moonsuite/products/...` paths instead of nested book-local
  state. Validation for this slice: MoonGate `moon fmt`, clean `moon info`,
  `moon check`, `moon test` with `774/774` tests passing, and
  `git diff --check`.
- MoonTown now depends on MoonLib `0.1.3` for book-root-derived and
  workspace-root-derived MoonSuite paths.
  PlanBook repair job indexes and proposal ledgers now resolve to
  `.moonsuite/products/moonclaw/jobs/...` through `@moonsuite`, MoonClaw store
  maintenance compacts that product-home job store, and PlanBook's MoonClaw run
  result reader passes the derived MoonClaw product home into the MoonClaw
  runtime instead of falling back to `cwd/.moonclaw`. Validation for this slice:
  `moon fmt`, `moon info`, `moon check`, and `moon test` in MoonTown with
  `925/925` tests passing.
- The MoonTown MoonBook adapter now derives MoonClaw provider manifests from the
  MoonClaw product home and MoonCode sidecar sessions from the MoonCode product
  home through `@moonsuite.product_artifact_for_book_root`, removing another
  book-local `.moonclaw` writer/reader pair. Validation for this slice:
  `moon fmt`, `moon info`, `moon check`, and `moon test` in MoonTown with
  `926/926` tests passing.
- MoonTown commit `ad205ae8` replaces the central storage helper's empty-root
  MoonSuite calls with MoonLib workspace-root adapters. The no-arg
  `moontown_product_*` helpers now derive from the active working directory,
  and new explicit `*_for_workspace_root` helpers prove that a
  `books/<book-id>` root resolves to the suite-level
  `.moonsuite/products/moontown` home rather than a nested book-local
  `.moonsuite`. Default runtime path tests now compare against storage-derived
  product artifacts instead of stale relative `.moonsuite/...` literals.
  Validation for this slice: MoonTown `moon fmt`, `moon info`, `moon check`,
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
- MoonDesk commit `e54c4400` moves MoonCode desktop session/event sidecar path
  derivation onto MoonLib workspace-root helpers. `internal/mooncode` now
  exposes explicit workspace-root constructors for session directories,
  command logs, runtime command/receipt logs, snapshots, event logs, and stream
  checkpoints, while `internal/moonwiki` consumes those constructors instead of
  joining a relative `.moonsuite/products/mooncode/sessions` path onto the
  selected workspace root. Suite-hosted book roots now resolve MoonCode
  sidecars to the owning suite's `.moonsuite/products/mooncode` lane instead of
  nested `books/<book-id>/.moonsuite` state. Validation for this slice:
  MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with `451/451`
  tests passing, targeted old-join scan clean, and `git diff --check`.
- MoonDesk commit `52dd6de9` moves the MoonTown bridge request/dispatch path
  contract onto MoonLib workspace-root helpers. `internal/moonwiki` now derives
  MoonTown product homes, request ledgers, dispatch ledgers, daemon state,
  standing-goal state, book-result summaries, watcher records, and town service
  paths from the owning suite when the selected workspace is a
  `books/<book-id>` root. UI-facing relative bridge paths remain centralized as
  display strings, while filesystem reads/writes use absolute
  workspace-root-derived product artifacts. Validation for this slice:
  MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with `453/453`
  tests passing, targeted active old-join scan clean except the intentional
  centralized relative display prefixes, and `git diff --check`.
- MoonDesk commit `abb10fc2` routes MoonClaw job roots through MoonLib
  workspace-root helpers and stops creating nested
  `books/<book-id>/.moonsuite/products/moonclaw/jobs` directories for new
  MoonBooks. The generic workspace path resolver now redirects the intentional
  `.moonsuite/products/moonclaw/jobs/...` UI path to the owning suite's
  MoonClaw product home, rejects arbitrary `.moonsuite` and `.tmp` fallbacks,
  and keeps MoonClaw run raw-artifact reads working through that explicit
  product-path branch. Validation for this slice: MoonDesk `moon fmt`,
  `moon info`, `moon check`, `moon test` with `454/454` tests passing,
  targeted active old-join scan clean except intentional centralized display
  prefixes, and `git diff --check`.
- MoonDesk commit `103f86ac` moves MoonDesk-owned daemon state, daemon policy,
  preference records, and town LaunchAgent log paths onto MoonLib
  workspace-root product artifacts. Suite-hosted book roots now resolve
  MoonDesk daemon and preference state to the owning suite's
  `.moonsuite/products/moondesk` lane, and generated town LaunchAgent plists no
  longer write logs under `books/<book-id>/.moonsuite`. Validation for this
  slice: MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `456/456` tests passing, targeted active MoonDesk old-join scan clean, and
  `git diff --check`.
- MoonDesk commit `d4293c77` strengthens the trash-path coverage for
  suite-hosted book workspaces. Direct Desk and HTTP trash/restore flows now
  assert that `.moonsuite/products/moondesk/trash/files/...` UI paths resolve
  through the owning suite's MoonDesk product home, that receipts use the same
  suite-level product home, and that trashing entries does not create a nested
  `books/<book-id>/.moonsuite` directory. Validation for this slice: MoonDesk
  `moon fmt`, `moon info`, `moon check`, `moon test` with `456/456` tests
  passing, active one-line old-path file-operation scan with zero hits,
  narrowed active legacy literal scan with only filters/service identifiers, and
  `git diff --check`.
- MoonDesk Desk smoke gates now enforce the same trash contract end to end. The
  API smoke resolves returned `.moonsuite/products/moondesk/trash/files/...`
  paths against the owning suite root instead of the selected book root, and the
  browser smoke asserts the MoonDesk product-home trash directory exists while
  legacy `books/<book-id>/.moontown/trash` and nested
  `books/<book-id>/.moonsuite/products/moondesk/trash` directories do not.
  Validation for this slice: `bash -n scripts/desk_mode_api_smoke.sh`,
  `node --check scripts/desk_mode_browser_smoke.mjs`,
  `scripts/desk_mode_api_smoke.sh`, and `scripts/desk_mode_browser_smoke.sh`.
- MoonDesk commit `c13ab594` removes the remaining fresh-default compatibility
  treatment for stale `.moontown`, `.moonclaw`, and `.moonclaw-worktrees`
  surfaces. Desk VFS hiding and creation guards now protect only the current
  internal roots such as `.moonsuite` and `.tmp`, source-layer inference
  classifies MoonClaw artifacts through the current MoonSuite product home or
  explicit MoonClaw job UI path instead of the old `.moonclaw` home, and the
  town LaunchAgent label is now `app.vectie.moonsuite.town`. Validation for this
  slice: MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `456/456` tests passing, zero quoted `.moontown`/`.moonclaw` literals in
  MoonDesk MoonBit source, zero active old-path file-operation hits, and
  `git diff --check`.
- MoonDesk metadata now treats `.moonsuite/product-registry.json` as a live UI
  source instead of only a bootstrap artifact. `/api/workspaces/metadata`
  returns the registry products, the Desk sidebar renders a compact
  registry-backed product summary, and the first-run/no-book screen now shows
  the active MoonSuite root, `books/` library path, MoonBook count, and installed
  core products before Code/Wiki interaction begins. Validation for this slice:
  MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with `457/457`
  tests passing, `npm run build` for the Rabbita desk bundle, `git diff --check`,
  API verification showing `product_count: 13`, and visible app verification at
  `http://127.0.0.1:4535/?activity=files`.
- MoonDesk title/root helpers now use the loaded MoonSuite workspace metadata
  when no MoonBook is selected. The global title bar shows
  `MoonSuite: <root-name>` instead of `No workspace`, and `workspace_root(...)`
  resolves to the active suite root during first-run/no-book flows. Validation
  for this slice: MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test`
  with `457/457` tests passing, `npm run build`, `git diff --check`, and
  visible app verification at `http://127.0.0.1:4535/?activity=files` showing
  `MoonSuite: moondesk-phase4-cleanup-run`.
- MoonDesk product chips now honor the Phase 7 rule that normal UI avoids
  hidden internal paths. The Rabbita UI model ignores registry `state_path` and
  `service_path`, renders product status as human text such as `INSTALLED`, and
  keeps chip titles to `Product: Status` instead of exposing
  `.moonsuite/products/...` internals. Validation for this slice: MoonDesk
  `moon fmt`, `moon info`, `moon check`, `moon test` with `457/457` tests
  passing, `npm run build`, `git diff --check`, and visible app verification at
  `http://127.0.0.1:4535/?activity=files` showing no `.moonsuite/products`
  text or chip titles.
- MoonDesk product summary now renders every product from the registry instead
  of a hardcoded core subset. The first-run/no-book Desk UI shows all 13
  installed products in registry order, including MoonGate, MoonFish, MoonMoon,
  MoonRobo, Bookkeeper, Lepusa, and Rabbita, while still keeping hidden
  `.moonsuite/products/...` paths out of normal text and chip titles.
  Validation for this slice: MoonDesk `moon fmt`, `moon info`, `moon check`,
  `moon test` with `457/457` tests passing, `npm run build`, `git diff --check`,
  and visible app verification at
  `http://127.0.0.1:4535/?activity=files` showing `chipCount: 13`.
- MoonDesk Code mode transcript no longer fabricates a `Working on it...`
  assistant reply for pending prompts or runtime progress without an assistant
  answer. Pending prompts stay visible immediately as user messages, and the
  rendered transcript shows a folded `Thinking` activity row for the queued
  prompt until MoonClaw streams real runtime events or an assistant reply. The
  local-unavailable MoonClaw fallback also stops appending a second prompt-shaped
  command event with `Local agent is not reachable yet...` as its detail when
  the original prompt command has already been recorded; that text remains
  status metadata instead of conversation content.
  Validation for this slice: MoonDesk `moon fmt`, `moon info`, `moon check`,
  `moon test` with `458/458` tests passing, `npm run build`,
  `git diff --check`, and visible app verification at
  `http://127.0.0.1:4535/?activity=code` showing no `Working on it...` or
  saved-local-agent message.
- MoonDesk workspace kind naming now treats the root workspace as a MoonSuite
  root rather than a MoonTown root. The shared `WorkspaceKind` variant is
  `SuiteRoot`, general MoonCode and empty-library discovery use that variant,
  the Rabbita workspace label renders `suite`, and `docs/STATUS.md` describes
  the active MoonSuite root instead of a `.moontown`-gated root. Validation for
  this slice: MoonDesk `moon fmt`, `moon info`, `moon check`, `moon test` with
  `458/458` tests passing, `npm run build`, `git diff --check`, and visible app
  verification at `http://127.0.0.1:4535/?activity=files` showing MoonSuite UI
  with no town-root wording.
- MoonDesk MoonCode capability contracts now describe MoonClaw durable session
  sidecars as product-home state instead of book-local state. The
  `runtime_claim_state` and MoonClaw runtime gap contract strings point to
  commands, receipts, events, and cold sidecar list/show endpoints in the
  MoonClaw product home. Validation for this slice: MoonDesk `moon fmt`,
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
- MoonTown commit `44b1e5f7` propagates MoonBook's fresh executable-event path
  contract into the MoonTown MoonBook adapter. The decoded
  `moonbook.book_state.v1` fixture now expects `events/latest.json` instead of
  the retired `.moonbook/events/latest.json` path. Validation for this slice:
  MoonTown `moon fmt`, `moon info`, `moon check`, `moon test` with `926/926`
  tests passing, `git diff --check`, and an active-code stale-layout scan with
  zero MoonTown hits.
- MoonTown commit `bc3bb5ea` removes stale path fixtures that kept asserting
  retired `.moontown`, `.moonclaw`, and `.moonclaw-worktrees` strings after the
  product-home migration. Remaining MoonClaw adapter fixtures now name
  `.moonsuite/products/moonclaw/...`, cookbook readiness fixtures use the
  MoonTown product home, and the source-layout audit no longer allows root
  `.moontown` or `.moonclaw` directories. Validation for this slice: MoonTown
  `moon fmt`, `moon info`, `moon check`, `moon test` with `926/926` tests
  passing, `git diff --check`, `scripts/audit-source-layout.sh`, and a refined
  stale-layout scan with zero MoonTown hits.
- MoonRobo commit `43621e82` removes the remaining empty-root MoonSuite path
  constructors from product status and SDK E1 bridge sidecar defaults. Product
  status now reports MoonRobo and MoonClaw product homes through explicit
  workspace-root adapters derived from the selected robot book root, and SDK E1
  snapshot/command defaults expose workspace-root helpers that map book roots to
  the suite-level `.tmp/products/moonrobo` temp lane. Validation for this slice:
  MoonRobo `moon fmt`, clean `moon info`, `moon check`, `moon test` with
  `453/453` tests passing, and `git diff --check`.
- MoonVis commit `6e86154` teaches its suite-layout helper to infer
  `books/<book-id>` workspace roots without requiring the caller to pass a
  duplicate book id. MoonVis state remains under
  `.moonsuite/products/moonvis`, temporary files remain under
  `.tmp/products/moonvis`, and accepted output resolves to
  `books/<book-id>/outputs/moonvis` for both explicit and inferred flows.
  Validation for this slice: `node --check` for the MoonVis layout helper and
  CLI wrapper, MoonVis fresh-suite product-home smoke, MoonDesk residual guard,
  MoonLib consumer-pin guard, full cross-product fresh-suite smoke, and
  MoonVis `git diff --check`.
- MoonDesk removes the remaining active `moonclaw-jobs` source-layer
  compatibility alias. Fresh Desk source classification now treats only the
  MoonSuite product-home job path `.moonsuite/products/moonclaw/jobs/...` as a
  run artifact, while retired `moonclaw-jobs/...` paths fall back to ordinary
  workspace files. Validation for this slice: MoonDesk `moon fmt`, `moon info`,
  `moon check`, `moon test` with `458/458` tests passing, Rabbita desk
  `npm run build`, a refined active `moonclaw-jobs` scan with only regression
  test hits, and `git diff --check`.

Migration rules from this point forward:

1. New MoonSuite path helpers belong in MoonLib first.
2. MoonDesk, MoonClaw, MoonTown, MoonBook, MoonFish, MoonMoon, MoonRobo,
   Lepusa, Rabbita, and Bookkeeper may keep local helpers only as adapters over
   MoonLib.
3. MoonGate may add diagnostics, reports, drift indexes, and health projections
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
- `moongate`: metrics DB, snapshots, analytics, embeddings and indexes.
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

MoonClaw and MoonTown errors must be explicit. They should not silently queue
forever when a required service is missing.

Phase 6 MoonDesk API rewrite slice:

- Added a shared `moonsuite.phase6.v1` response envelope for API success/error
  payloads with `ok`, `status`, `message`, and `next_action`.
- `/api/workspaces/metadata` now exposes active suite root, requested root,
  books root, product registry, workspace count, workspace records, and
  product records from the MoonSuite context.
- `/api/mooncode/status` exposes runtime readiness separately from prompt
  submission.
- MoonCode session creation and command submission now persist the user message,
  command packet, command queue, runtime-command queue, transcript line, and
  event log before returning. They no longer wait for MoonClaw runtime dispatch
  before the UI can append the prompt.
- MoonClaw daemon/model responses now return explicit
  configured/running/unreachable status, service path/config fields, and next
  actions instead of vague local-agent queueing.
- MoonTown state/daemon responses now resolve through the owning suite context
  and return explicit missing-state/service-configuration status.

## Phase 7: UI Update

Desk should show:

- Active MoonSuite root.
- Book list from `books/`.
- Selected book.
- Product/service status.
- Clean Code conversation stream.

Normal UI should avoid exposing hidden internal paths.

Phase 7 MoonDesk UI update slice:

- Rabbita Desk now carries the Phase 6 metadata contract through the UI model:
  active suite root, requested root, books root, product count, and registry
  products.
- Desk renders the active MoonSuite by display name, shows the canonical
  `books/` library lane, and lists MoonBooks as `books/<book-id>` labels instead
  of raw absolute paths.
- Desk adds a compact service status band for MoonSuite, MoonBooks, product
  registry, MoonClaw, and MoonTown, backed by the existing daemon/progress
  fetches.
- Code mode session rows and accessibility titles now avoid raw `cwd` paths in
  normal UI, keeping the rail focused on the selected book/general chat and the
  clean conversation stream.

## Phase 8: Test Gates

Phase 8 turns the migration into enforceable gates. The goal is not to add a
large pile of shallow tests; it is to prove that every product derives the fresh
layout from the shared MoonLib contract and that MoonDesk, MoonCode, Lepusa, and
service daemons behave correctly from a brand-new suite root.

### Phase 8 Execution Plan

Phase 8 is a test-hardening phase, not a product-behavior migration phase. The
implementation rule is: if a Phase 6 or Phase 7 behavior is important enough to
keep, Phase 8 must give it a repeatable gate. The gates should catch regressions
at the lowest useful layer first, then prove the user-visible path with browser
and packaged-app smoke tests.

Execution order:

1. Contract floor: make MoonLib layout tests the first source of truth for
   `.moonsuite`, `.tmp`, `books`, product homes, service homes, registries,
   and selected-book-to-owning-suite resolution.
2. MoonDesk bootstrap/API floor: prove a blank selected folder becomes a valid
   suite root, prove `books/` is the only active MoonBook library, and prove
   API metadata exposes the Phase 6 contract.
3. Product registry floor: cover every suite product in one deterministic
   registry test surface so missing Moon-branded products fail loudly.
4. Service floor: prove MoonClaw and MoonTown derive config, logs, status, and
   provider/runtime state from `.moonsuite/products/*`, with explicit
   missing/running/unreachable statuses.
5. MoonCode conversation floor: prove append-only transcript behavior from
   prompt submission through intermediate thinking/progress and final answer.
6. Browser floor: prove the production Rabbita bundle renders fresh suite,
   empty library, populated library, selected book, VFS navigation, product
   status, service status, and clean Code conversation flows without console or
   runtime errors.
7. Lepusa packaged floor: prove the packaged sidecar and UI bootstrap both
   empty and populated suite roots without old hidden product roots.
8. Cross-product floor: prove every migrated product consumes MoonLib layout
   contracts directly and does not recreate private path logic.
9. Residual scan floor: fail on stale layout strings in active fresh-path code,
   while allowing migration docs, drift detectors, negative tests, and explicit
   error copy.
10. Release wall: wire the fast and full command walls so Phase 9 can reuse
    Phase 8 as a hard dependency.

Phase 8 work packages:

| Work package | Primary proof | Done signal |
| --- | --- | --- |
| 8.1 Contract tests | MoonLib package tests | Canonical suite/book/product paths covered, including negative legacy roots |
| 8.2 Fresh bootstrap | MoonDesk native tests and API smoke | Empty folder creates `.moonsuite`, `.tmp`, and `books` idempotently |
| 8.3 Workspace APIs | `/api/workspaces*` and `/api/books*` tests | Metadata and discovery use only the fresh suite contract |
| 8.4 Product registry | Registry tests and UI fixtures | MoonDesk, MoonBook, MoonWiki, MoonCode, MoonClaw, MoonTown, MoonGate, MoonFish, MoonMoon, MoonRobo, Bookkeeper, Lepusa, Rabbita, and later suite products are visible |
| 8.5 Services | MoonClaw/MoonTown service tests | Status/config/log paths live under `.moonsuite/products/*` |
| 8.6 MoonCode E2E | Browser or state-machine transcript tests | User prompt, folded thinking, progress, and final reply keep append-only order |
| 8.7 Desk browser smoke | Production Rabbita browser smoke | No loading deadlocks, console errors, raw path leaks, or broken Desk/Code flows |
| 8.8 Lepusa smoke | Packaged fresh-suite smoke | Packaged sidecar creates and serves fresh roots in empty and populated cases |
| 8.9 Product consumers | Cross-repo contract tests | Products import MoonLib layout contracts rather than MoonDesk or MoonGate internals |
| 8.10 Residual scans | Fresh-suite residual validator | Old layout strings are classified or fail the gate |
| 8.11 CI/release wall | `phase8_migration_gates.sh` | Fast and full gates are repeatable, documented, and usable by Phase 9 |

Current Phase 8 status:

- The Phase 8 wall exists as `scripts/phase8_migration_gates.sh` with `fast`
  and `full` modes.
- The full wall already includes native MoonDesk checks/tests, Rabbita JS
  check/test/build, MoonLib consumer pins, residual scan, core-boundary
  validation, API smoke, Desk browser smoke, and fresh-suite product smoke.
- Desk browser smoke has been hardened for populated and empty library
  scenarios, console/runtime problem capture, and MoonCode ordering checks.
- Lepusa fresh-suite smoke covers both populated and empty roots through
  `scripts/lepusa_fresh_books_smoke.sh`.
- The remaining Phase 8 risk is coverage completeness, not gate existence:
  every product and user-visible flow must stay connected to these gates as the
  migration continues.

Phase 8 operating rules:

- Add low-level tests before high-level browser smoke when the bug is a path or
  contract bug.
- Add browser smoke when the bug is ordering, visibility, loading, or UI
  interaction.
- Add packaged Lepusa smoke when the bug could differ between local `moon run`
  and the packaged sidecar.
- Add residual-scan rules only for stale behavior that should never return in
  active fresh-path code.
- Do not keep compatibility tests for old hidden roots as successful behavior;
  keep them only as negative tests or drift-detection tests.
- Every new Phase 8 slice must record the exact commands that passed in this
  section before the slice is treated as closed.

### Phase 8.1: Canonical Layout Contract Tests

Scope:

- Add or extend MoonLib `@moonsuite` tests for every canonical path:
  `.moonsuite`, `.tmp`, `books`, product-home, product artifacts, service
  config, service logs, registry files, and per-book workspace roots.
- Cover both suite-root input and `books/<book-id>` input. A suite-hosted
  MoonBook must resolve back to the owning suite for product-home paths.
- Add negative cases proving old roots such as `.moontown`, `.moonclaw`,
  repo-local runtime folders, and global temp folders are not accepted as
  alternate valid layouts.

Acceptance:

- MoonLib tests become the source of truth for path semantics.
- Products can import `vectie/moonlib/moonsuite` without importing MoonGate,
  MoonDesk UI packages, MoonClaw runtime packages, or daemon packages.
- `moon test` in MoonLib passes with no snapshot drift.

### Phase 8.2: Fresh Bootstrap Tests

Scope:

- Add fresh-root bootstrap tests for MoonDesk `serve` and CLI bootstrap paths.
- Start from an empty user-selected folder and assert the resulting structure:
  `.moonsuite/`, `.moonsuite/products/`, `.moonsuite/suite-status.json`,
  `.tmp/`, and `books/`.
- Assert product directories are created lazily or explicitly according to the
  product registry contract, not by stale hidden-folder fallbacks.
- Assert bootstrapping a folder that already contains `books/` is idempotent.

Acceptance:

- A clean folder becomes a valid MoonSuite root in one run.
- Running bootstrap twice does not duplicate state or switch back to old layout.
- No test fixture writes `.moontown`, `.moonclaw`, or old hidden MoonBook
  library paths as valid fresh output.

### Phase 8.3: Workspace API Integration Tests

Scope:

- Extend `/api/workspaces`, `/api/workspaces/metadata`, `/api/workspaces/*`,
  and `/api/books/*` tests.
- Assert MoonBooks are discovered only from `books/`.
- Assert metadata returns active suite root, requested root, books root, product
  registry, workspace count, workspace records, and product records.
- Assert normal VFS listings hide `.moonsuite` and `.tmp` while internal API
  logic can still use them.
- Assert suite root and selected MoonBook behavior both preserve the same owning
  suite context.

Acceptance:

- API tests fail if book discovery falls back to old hidden MoonBook paths.
- API tests fail if response metadata omits Phase 6 contract fields.
- API tests fail if normal user-facing listings expose `.moonsuite` or `.tmp`.

### Phase 8.4: Product Registry Coverage

Scope:

- Add registry tests covering all current MoonSuite products:
  MoonDesk, MoonBook, MoonWiki, MoonCode, MoonClaw, MoonTown, MoonGate,
  MoonFish, MoonMoon, MoonRobo, Bookkeeper, Lepusa, and Rabbita.
- Assert each product has a stable id, display name, status, product-home path,
  and expected service/artifact locations when applicable.
- Add explicit coverage for previously missed products: MoonRobo, MoonMoon,
  MoonFish, and other Moon-branded suite products.

Acceptance:

- Product registry output is deterministic.
- Missing product metadata is reported as a test failure, not silently hidden in
  UI or API defaults.
- MoonDesk UI service/product panels have fixture coverage for the complete
  registry list.

### Phase 8.5: Service Config And Daemon Tests

Scope:

- Add MoonClaw tests proving daemon config, provider manifests, stdout/stderr
  logs, runtime status, and next-action messages resolve under
  `.moonsuite/products/moonclaw`.
- Add MoonTown tests proving daemon state, progress state, and service status
  resolve under `.moonsuite/products/moontown`.
- Assert missing daemon/config cases return explicit status objects rather than
  vague queueing or "local agent unavailable" copy.
- Assert both suite root and selected `books/<book-id>` roots resolve service
  config to the owning suite product home.

Acceptance:

- MoonClaw and MoonTown tests fail if `$HOME/.moonclaw`, `.moontown`, or
  book-local product homes are used as fresh defaults.
- API responses include actionable missing/running/unreachable statuses.
- UI fixtures can render service status without raw internal paths.

### Phase 8.6: MoonCode End-To-End Tests

Scope:

- Add tests for the complete prompt lifecycle:
  immediate user-message append, command packet persistence, runtime-command
  persistence, event log append, thinking/progress placement, final assistant
  append, and ordered transcript hydration.
- Cover new chat, existing chat, refresh during stream, daemon unavailable,
  daemon available, and stale session-list polling.
- Assert AI events are appended to the correct active conversation and are not
  reordered above the user's prompt.
- Assert folded thinking/progress remains between user prompt and final answer
  after completion.

Acceptance:

- Tests fail if the UI waits for MoonClaw before showing the user's prompt.
- Tests fail if final assistant text is prepended, merged into the user message,
  duplicated, or attached to the wrong session.
- Tests fail if hidden tool payloads or raw command blobs appear in normal chat
  display.

### Phase 8.7: Desk Browser Smoke Tests

Scope:

- Extend browser smoke coverage for first-run root, empty `books/`, populated
  `books/`, selected MoonBook, VFS navigation, product status, service status,
  and clean Code conversation UI.
- Run against the production `ui/rabbita-desk/dist` bundle, not only dev mode.
- Verify the browser has no console errors and does not show loading forever.
- Verify visible copy uses display labels such as `MoonSuite: <name>` and
  `books/<book-id>`, not raw absolute paths in normal UI.

Acceptance:

- Browser smoke fails on JavaScript runtime errors, stale bundle crashes, raw
  internal path leaks, missing MoonCode input, or loading-screen deadlocks.
- The smoke script leaves the app opened for visual inspection after completion.

### Phase 8.8: Lepusa Fresh-Suite Smoke

Scope:

- Build or launch Lepusa with a brand-new MoonSuite root.
- Assert the packaged app points its sidecar at the fresh root, serves the
  production Rabbita bundle, and reaches the same health/readiness endpoints.
- Run both a populated MoonBook projection scenario and an empty selected-folder
  scenario; the empty case must prove the packaged sidecar creates the
  MoonSuite layout itself.
- Verify Desk and Code modes render from the packaged runtime, not only the
  local `moon run cmd/main -- serve` path.

Acceptance:

- Lepusa smoke fails if the sidecar uses old workspace defaults.
- Lepusa smoke fails if the app cannot create/read `books/` or product homes.
- Lepusa smoke fails if a blank user-selected folder does not bootstrap
  `.moonsuite`, `.tmp`, `books/`, inbox/export roots, and default product
  homes without legacy hidden roots.
- The final smoke URL/app window is shown for inspection.

### Phase 8.9: Cross-Product Contract Consumers

Scope:

- For each migrated product, add or update tests proving it derives paths from
  MoonLib:
  MoonDesk, MoonGate, MoonClaw, MoonTown, MoonFish, MoonMoon, MoonRobo,
  Bookkeeper, Lepusa, Rabbita, MoonBook, MoonWiki, and MoonCode.
- Keep consumer tests focused on integration boundaries: given suite root or
  book root, product derives the same canonical product home and artifact
  locations as MoonLib.
- Add a small "contract fixture" shared by products where practical, but avoid
  coupling product tests to MoonDesk implementation details.

Acceptance:

- Product tests fail if a product recreates path logic locally and diverges from
  MoonLib.
- Product tests fail if a product depends on MoonGate or MoonDesk UI for core
  layout derivation.

### Phase 8.10: Drift And Residual Scans

Scope:

- Keep MoonGate drift-report tests for old `.moontown`, `.moonclaw`,
  repo-local runtime, and global temp paths. MoonGate commit `cf7fd62` already
  covers the first drift-report slice.
- Add MoonDesk residual scans for old layout strings outside documentation,
  migration notes, and explicit drift/error messages.
- Classify every remaining old-layout string as one of:
  test fixture, migration doc, drift detector, user-facing error, or bug.

Acceptance:

- Residual scans fail on old-layout strings in active fresh-path code.
- Old-layout references are allowed only where they explain migration, test
  drift detection, or report invalid legacy state.

### Phase 8.11: CI And Release Gate Wiring

Scope:

- Wire the Phase 8 gates into repeatable commands:
  `moon check`, `moon test`, targeted MoonDesk API smoke, browser smoke,
  Lepusa smoke, boundary validation, and residual scan.
- Keep fast unit/white-box tests separate from slower browser/Lepusa tests so
  local iteration remains practical.
- Document the exact command order and expected pass criteria.

Required gate order:

1. `moon fmt`
2. `moon info`
3. `moon check --target native`
4. `moon test --target native`
5. Rabbita `moon check --target js`
6. Rabbita `moon test --target js`
7. Rabbita `npm run build`
8. MoonDesk API smoke
9. Desk browser smoke
10. Lepusa fresh-suite smoke
11. Core-boundary validation
12. Residual old-layout scan

MoonDesk gate commands:

- `bash scripts/phase8_migration_gates.sh fast` runs the repeatable local
  Phase 8 wall: MoonDesk native format/info/check/test, Rabbita JS
  check/test/build, MoonLib consumer pins, MoonSuite filesystem contract
  rollout validation, fresh-suite residual scans, and cross-repo boundary
  validation.
- `bash scripts/phase8_migration_gates.sh full` runs the fast wall plus API
  smoke, Desk browser smoke, and cross-product fresh-suite smoke. The Desk
  browser smoke wrapper defaults to `all`, which runs both the populated
  MoonBook library scenario and the empty-library first-run scenario against
  the production Rabbita bundle.
- `bash scripts/fresh_suite_product_smoke.sh` can be run alone when validating
  product-home behavior across MoonTown, MoonClaw, MoonBook, MoonRobo,
  MoonFish, MoonMoon, MoonChat, MoonVis, MoonGate, and Lepusa.
- `bash scripts/lepusa_fresh_books_smoke.sh` can be run alone to validate the
  Lepusa packaged runtime against both populated and empty fresh-suite roots;
  pass `populated` or `empty` to isolate one scenario.

Acceptance:

- Phase 8 is complete only when every required gate has an explicit command,
  documented owner/product scope, and a passing run recorded in this migration
  log.
- Failures must point to a product or contract boundary, not require manual
  interpretation of raw logs.

### Phase 8 Completion Criteria

Phase 8 can close when:

- Fresh MoonSuite bootstrap is proven from an empty folder.
- All active products derive canonical paths from MoonLib.
- MoonDesk APIs and UI expose the Phase 6/7 contract without raw internal path
  leaks in normal views.
- MoonCode prompt/event/final-answer ordering is covered by end-to-end tests.
- MoonClaw and MoonTown missing/running/unreachable states are explicit and
  tested.
- Browser and Lepusa smoke tests pass on production bundles.
- Residual old-layout scans leave only approved migration/drift references.

Phase 8 gate-hardening evidence:

- MoonDesk commit `8feb13de` stabilizes MoonCode browser-smoke ordering. New
  chat draft transcripts now stay selected from local pending prompt state
  rather than incidental composer status text, pending prompts always render a
  folded `Prompt queued` thinking row before fast backend answers, and browser
  smoke diagnostics report transcript state on ordering failures. Validation
  passed with Rabbita JS tests (`451/451`), production bundle build,
  `scripts/desk_mode_browser_smoke.sh`, and
  `bash scripts/phase8_migration_gates.sh full`.
- The next Phase 8 browser-gate slice wires the existing empty-library
  first-run scenario into the default Desk browser smoke wrapper. `bash
  scripts/desk_mode_browser_smoke.sh` now runs both `full` and `empty`
  scenarios against separate fresh MoonSuite roots, proving populated-library
  navigation plus empty `books/` bootstrap/create behavior in the production
  bundle. Validation passed with `bash scripts/desk_mode_browser_smoke.sh` and
  `bash scripts/phase8_migration_gates.sh full`; the full gate also passed
  MoonDesk native tests (`465/465`), Rabbita JS tests (`451/451`), API smoke,
  MoonLib consumer pins, residual scans, core-boundary validation,
  cross-product fresh-suite smoke, and Lepusa fresh-books smoke.
- The next Phase 8 browser-quality slice adds CDP console/runtime problem
  capture to the Desk browser smoke. The smoke now fails on page runtime
  exceptions, `console.error` / failed assertions, or Chrome log errors after
  driving the production Rabbita bundle. This exposed a real `/favicon.ico`
  404 in the shell, fixed by adding an inline SVG favicon declaration to
  `ui/rabbita-desk/index.html`. Validation passed with `npm run build`,
  `bash scripts/desk_mode_browser_smoke.sh`, and
  `bash scripts/phase8_migration_gates.sh full`.
- The next Phase 8 Lepusa slice splits `scripts/lepusa_fresh_books_smoke.sh`
  into `populated` and `empty` scenarios. The populated scenario keeps proving
  an existing `books/research-alpha` projection is packaged with the correct
  sidecar command, while the empty scenario starts from a blank selected folder,
  launches the bundled `moondesk-sidecar`, waits for `__moondesk_health`, and
  asserts `books/`, `.tmp`, inbox/export roots, `.moonsuite` manifests, and
  default product homes are created without legacy `.moontown` or `.moonclaw`
  roots. Validation passed with `bash scripts/lepusa_fresh_books_smoke.sh empty`
  and `bash scripts/lepusa_fresh_books_smoke.sh`.

## Phase 9: Cutover

Phase 9 removes migration-mode ambiguity. Fresh MoonSuite v2 is the standalone
default, old hidden roots are drift signals only, and every remaining legacy
path reference must be either documentation, a drift detector, or a negative
test assertion.

Cutover steps:

1. Stop writing the old hidden MoonBook library.
2. Stop writing `.moontown/moondesk-daemon`.
3. Update tests, docs, and smoke fixtures to `books/`.
4. Make MoonSuite v2 the fresh default.
5. Launch a fresh Lepusa/MoonDesk app for visual verification.

Phase 9 gates:

- `bash scripts/phase9_cutover_gates.sh fast` runs the Phase 8 fast wall and
  the Phase 9 cutover validator.
- `bash scripts/phase9_cutover_gates.sh full` runs the Phase 8 full wall and
  the Phase 9 cutover validator, covering API smoke, Desk browser smoke,
  cross-product fresh-suite smoke, and Lepusa packaged runtime smoke.
- `bash scripts/validate_phase9_cutover.sh` can be run alone to scan active
  source in MoonLib, MoonDesk, MoonRobo, MoonTown, MoonClaw, MoonGate,
  MoonBook, MoonFish, MoonMoon, MoonChat, MoonVis, and Lepusa for unapproved
  Phase 9 legacy cutover paths and retired source-checkout redirect helpers.
- `bash scripts/validate_conversation_contract_rollout.sh` can be run alone to
  prove the shared conversation contract is source-owned by MoonLib, consumed
  by MoonDesk's MoonCode adapter, and not mirrored by product-local old
  conversation contract ids or wrappers.
- `bash scripts/validate_moonsuite_contract_rollout.sh` can be run alone to
  prove the shared filesystem contract is source-owned by MoonLib, consumed by
  MoonDesk's MoonWiki/core adapters, and not replaced by hard-coded product-home
  formulas in active product source.

Phase 9 completion criteria:

- Active source no longer contains unapproved `.moontown/books`,
  `.moontown/moondesk-daemon`, book-local `.moontown/trash`, `.moonbook`,
  `moonclaw-jobs`, `.moonclaw-worktrees`, or `.moonclaw-tool-journal` paths.
- Active source no longer contains source-checkout redirect compatibility
  helpers or warning copy such as the old dedicated-workspace fallback.
- MoonDesk command surfaces that create or package live app roots use a
  selected/configured MoonSuite root, `MOONDESK_WORKSPACE_ROOT`, or the fresh
  default `~/moonsuite`; they do not infer the retired home-derived workspace
  name.
- Any remaining legacy strings are explicitly scoped to drift detection or
  negative smoke assertions.
- Phase 9 full gate passes and the fresh app is shown from a MoonSuite v2 root.

Phase 9 cutover evidence:

- This Phase 9 slice adds the cutover validator and gate wrapper. The validator
  scans all 12 active source repos for unapproved old hidden MoonBook library,
  MoonDesk daemon, MoonClaw jobs, and legacy worktree paths. Validation passed
  with `bash scripts/validate_phase9_cutover.sh`,
  `bash scripts/phase9_cutover_gates.sh fast`, and
  `bash scripts/phase9_cutover_gates.sh full`.
- This Phase 9 root-selection slice removes the source-checkout redirect
  compatibility layer. `serve`, bundle/release root resolution, launch-agent
  setup, and Lepusa live-project generation now normalize and honor the
  selected workspace root directly, even when the folder contains `moon.mod`.
  The API smoke now proves a source-checkout-shaped selected folder is
  bootstrapped as the MoonSuite root instead of silently switching to a retired
  workspace folder name.
- This Phase 9 gate-hardening slice extends the cutover validator to reject the
  retired source-checkout redirection helpers and warnings, including the old
  dedicated-user-workspace fallback copy. The only allowed MoonDesk script
  reference is the API smoke assertion proving that the warning is absent.
- This Phase 9 contract-hardening slice adds
  `scripts/validate_moonsuite_contract_rollout.sh` and wires it into the Phase
  8 and Phase 9 gates. The validator checks MoonLib `0.1.8` as the single
  owner of `ProductHome`, workspace-root suite normalization, product artifact
  constructors, accepted-output paths, and the default product registry;
  verifies MoonDesk consumes those contracts through the MoonWiki layout facade
  and `core/paths.mbt`; and scans MoonLib, MoonDesk, MoonRobo, MoonTown,
  MoonClaw, MoonGate, MoonBook, MoonFish, MoonMoon, MoonChat, MoonVis, and
  Lepusa active source for unapproved direct `.moonsuite/products` or
  `.tmp/products` product-home formulas. The only active-source mirror allowed
  is MoonVis's frontend-only layout module; concrete smoke scripts may still
  assert filesystem effects and absence of stale homes.
- This Phase 9 default-root cleanup removes the retired MoonDesk CLI fallback
  from `$HOME` or `USERPROFILE` to the old workspace folder name. `serve`,
  `desktop`, `bundle`, `release`, launch-agent generation/install, and Lepusa
  live-project commands now use a selected/configured workspace root, while
  `MOONDESK_WORKSPACE_ROOT` remains an explicit environment override and
  `~/moonsuite` is the fresh first-initialization default.
- This Phase 9 explicit-root gate slice extends the cutover validator so the
  retired `USERPROFILE`/home-derived legacy workspace fallback and old
  multi-input default-root helper shape cannot return in active source.
- This Phase 9 standalone-source slice removes MoonTown's machine-local Codex
  adapter defaults and validation command text from active source. The Codex
  ACP target now defaults to the portable `codex` command unless `CODEX_BIN` is
  explicitly set, and Phase 9 validation now rejects machine-local absolute
  paths such as macOS user-home paths, Windows user-home paths, or CI host
  paths in active MoonBit source across the 12 migrated repos.
- Phase 9 full cutover evidence is current as of this slice:
  `bash scripts/phase9_cutover_gates.sh full` passed the Phase 8 full wall,
  including MoonDesk native tests (`476/476`), Rabbita JS tests (`432/432`),
  production build, API smoke, Desk browser full and empty-library smokes,
  cross-product fresh-suite smokes, Lepusa populated and empty fresh-books
  packaged runtime smokes, and the Phase 9 12-repo cutover validator.
- The shared conversation-contract rollout is now part of the Phase 9 gate.
  `scripts/validate_conversation_contract_rollout.sh` checks MoonLib source
  version `0.1.8`, the `vectie/moonlib/conversation` package and interface,
  MoonDesk's MoonCode delegation imports, the synchronized MoonClaw
  `mooncode/core` mirror, all MoonLib consumer pins, and all 12 active source
  repos for retired `mooncode-conversation.v1`,
  `mooncode-conversation-contract`, `moonlib_target`, or unapproved
  product-local conversation wrappers.
- MoonRobo's fresh-suite product-home smoke now sanitizes copied example
  fixtures by removing any generated `.moonsuite`, `.tmp`, or `.moonrobo`
  directories from the copied book root before bootstrap. This keeps the smoke
  faithful to a first-time project and prevents dirty local example state from
  recreating stale book-local product homes.
- The next Lepusa standalone packaging slice makes live MoonDesk bundles
  self-contained: generated localhost runtime manifests now launch the bundled
  `moondesk-sidecar` with `--ui` pointing at
  `Contents/Resources/lepusa/assets/main` inside the app bundle, and the
  bundle step copies Rabbita `dist` assets there. `scripts/lepusa_fresh_books_smoke.sh`
  now asserts the manifest no longer points sidecar launches at the source
  checkout UI directory.
- Full-gate evidence for the bundled-UI slice: `bash
  scripts/phase9_cutover_gates.sh full` passed after the change, including
  populated and empty Lepusa fresh-books packaged runtime smokes whose generated
  local-service commands used the bundled `Contents/Resources/lepusa/assets/main`
  UI directory.

## Cross-Product Migration Log

Completed slices:

- MoonDesk initializes fresh MoonSuite roots, discovers MoonBooks from `books/`,
  writes product service state under `.moonsuite/products/*`, hides
  `.moonsuite` and `.tmp` in the normal VFS, and stores MoonCode sessions under
  `.moonsuite/products/mooncode/sessions`.
- MoonDesk now depends on MoonLib `0.1.3` and uses
  `@moonsuite.product_artifact_for_workspace_root` through its MoonWiki adapter
  for scoped Desk trash state. Workspace trash files and receipts now live under
  `.moonsuite/products/moondesk/trash`, even when the selected workspace is a
  suite-hosted `books/<book-id>` MoonBook; restore/listing resolve only that
  MoonDesk product-home prefix instead of treating old `.moontown/trash` paths
  as valid workspace paths. MoonCode capability copy and README service
  descriptor copy now name the current product-home paths. Validation for this
  slice: MoonDesk `moon update`, `moon fmt`, `moon info`, `moon check`, and
  `moon test` with `448/448` tests passing.
- MoonDesk MoonClaw daemon probing now reads `daemon.json` from
  `.moonsuite/products/moonclaw` through
  `@moonsuite.product_artifact_for_workspace_root`, and MoonDesk-launched
  MoonClaw daemon stdout/stderr logs now go under
  `.moonsuite/products/moonclaw/logs`. The fallback no longer probes or writes
  `$HOME/.moonclaw`, and white-box coverage asserts suite-hosted
  `books/<book-id>` workspaces derive the owning suite's MoonClaw product home.
- MoonDesk commit `e54c4400` routes MoonCode desktop session/event sidecar
  paths through MoonLib workspace-root constructors. The internal MoonCode
  package now exposes workspace-root APIs for all session sidecar paths, and
  MoonWiki read/write handlers use them so suite-hosted `books/<book-id>` roots
  write to suite-level `.moonsuite/products/mooncode/sessions` rather than a
  nested book-local product home. Validation passed with MoonDesk `moon fmt`,
  `moon info`, `moon check`, `moon test` (451/451), targeted old-join scan
  clean, and `git diff --check`.
- MoonGate advertises and writes MoonClaw provider manifests through
  `.moonsuite/products/moonclaw/providers.json`, and advertises MoonClaw model
  and config candidates under `.moonsuite/products/moonclaw`.
- MoonGate commit `0428848` splits the active suite-status and product-state
  defaults: suite discovery now writes `.moonsuite/suite-status.json`, while
  MoonGate-owned usage request logs, session sync offsets, and editable model
  pricing now default under `.moonsuite/products/moongate`. Help text, README
  copy, and white-box coverage assert the fresh suite-root/product-home
  boundary. Validation passed in MoonGate with `moon fmt`, `moon info`,
  `moon check`, `moon test` (774/774), and `git diff --check`.
- MoonGate commit `62d9ebb` moves the app config default from suite state into
  `.moonsuite/products/moongate/config.json`. Config backups and skill
  state/backups/install directories follow MoonGate's product-home config root,
  with README copy and white-box coverage asserting the new path. Validation
  passed in MoonGate with `moon fmt`, `moon info`, `moon check`, `moon test`
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
- MoonTown stores default town snapshots, standing goals, watcher ledgers,
  daemon runtime files, live/autonomy projections, book-result bridges, book
  template requests, civic schedules, book-quality runtime files, and town
  synthesis under `.moonsuite/products/moontown`.
- MoonTown stores book-quality audits, AI review packets/results, review run
  ledgers, and repair bridge defaults under
  `.moonsuite/products/moontown/book-quality`, with README copy and daemon
  scheduled-job tests updated to the product-home paths.
- MoonTown stores civic protocol registries, status projections, protocol
  ledgers, civic service status, and civic service result bridges under
  `.moonsuite/products/moontown`, and Rabbita/cookbook operator copy now points
  at the MoonSuite product-home paths.
- The Rabbita/MoonTown Vite bridge serves town snapshots, live autonomy,
  standing goals, watcher ledgers, operator-request queues, book-template
  queues/configs, civic status, editor pipeline state, MoonDesk bridge records,
  and book-result records from `.moonsuite/products/moontown`; generated
  MoonBook projection discovery remains on the existing book workspace root
  until the book-layout cutover.
- MoonTown final-integration installs write the Wenyu integration status file
  under `.moonsuite/products/moontown/integration`, with usage docs and
  white-box path coverage updated to the product-home location.
- MoonTown exported keeper/MoonClaw packet files now default to
  `.moonsuite/products/moontown/packets`, with modeled execution records,
  Rabbita demo records, operational docs, and adapter white-box coverage updated
  to the product-home path.
- MoonTown cookbook stable-state manifests now default to
  `.moonsuite/products/moontown/cookbook/stable-state.json`, with cookbook
  path coverage and operator docs updated to the product-home path.
- MoonTown PlanBook/editor operator copy now names
  `.moonsuite/products/moontown` for live-autonomy, town-journal, PlanBook
  autonomy/repair/validation, and editor-pipeline state; focused tests assert
  the generated copy no longer emits the old product-runtime paths.
- MoonTown README, frontend, usage, doc-structure, and generated cookbook copy
  now point standing-goal/watch ledgers, operator request queues,
  book-template request/config/event files, MoonDesk bridge records, and
  book-result bridges at `.moonsuite/products/moontown`; cookbook tests assert
  the generated book-template flow no longer emits the legacy inbox path.
- MoonTown's MoonBook catalog default now writes
  `.moonsuite/products/moontown/moonbooks.json`, matching MoonDesk's bridge
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
- MoonTown daemon runtime policy now defaults health/log summaries to
  `.moonsuite/products/moontown/daemon.log`, and editor-pipeline civic protocol
  evidence points at
  `.moonsuite/products/moontown/civic/protocols/<building-id>/*.jsonl`; targeted
  daemon/editor tests and the full MoonTown test suite assert the product-home
  contract.
- MoonTown civic service history now derives the product-home book-result path,
  and the default external MoonClaw checkout root is
  `.moonsuite/products/moontown/external/moonclaw`; civic and MoonClaw adapter
  tests assert the old `.moontown` paths are not emitted.
- MoonTown now depends on MoonLib `0.1.1`; its storage product-home, service,
  temp, snapshot, standing-goal, watcher, and mayor town-synthesis paths are
  thin adapters over `@moonsuite`, and town synthesis execution records register
  the mayor workspace root as `.moonsuite/products/moontown` instead of
  `.moontown`.
- MoonTown commit `8ae8672c` adds a storage-level
  `moontown_product_artifact(...)` adapter over MoonLib
  `@moonsuite.product_artifact(...)`, then routes default civic protocol/status
  artifacts, communication schedules/runs, visual projection, book-result
  bridges, cookbook manifests, MoonBook catalog state, MoonClaw packet exports,
  daemon logs, and final-integration status through that adapter. MoonTown docs
  and operator copy no longer name `.moontown/civic`,
  `.moontown/book-results`, `.moontown/book-projection-policy`, or
  `.moontown/visual-projection` for product-owned state. Validation passed with
  `moon check`, `moon test` (922/922), `moon fmt`, `moon info`, and a final
  `moon check`.
- MoonTown commit `d4b79996` starts the Phase 5 book-layout cutover by moving
  default MoonBook workspace roots from `.moontown/books/<book-id>` to
  MoonLib-backed `books/<book-id>` paths. The slice updates catalog defaults,
  editor/planbook source-root helpers, backlog target paths, civic result
  routing, Rabbita missing-projection copy, cookbook generated copy, and
  operator docs. The checked source/docs set no longer contains the old
  `.moontown/books` or `.moontown/moonbooks.json` contracts. Validation passed
  with `moon check`, `moon test` (923/923), `moon fmt`, `moon info`, and a final
  `moon check`.
- Cross-repo residual cleanup landed in MoonTown commit `a9088181` and MoonDesk
  commit `49589f69`. MoonTown's handoff asset and README now name
  `books/<book-id>` for book workspace packs and output bundles. MoonDesk source
  layer inference now classifies `.moonsuite/...` and `.tmp/...` as internal
  config surfaces, and its explorer test no longer uses `.moontown/books` as the
  config example. A broad scan across MoonDesk, MoonBook, MoonClaw, MoonGate,
  MoonRobo, MoonFish, MoonMoon, MoonTown, and MoonLib found no active
  `.moontown/books`, `.moontown/moonbooks.json`, or `.moontown/books.json`
  contracts outside this historical migration log. Validation passed with
  MoonDesk `moon check`, `moon test` (445/445), `moon fmt`, `moon info`, final
  `moon check`, plus MoonTown `moon check`, `moon test` (923/923), `moon fmt`,
  `moon info`, and final `moon check`.
- Phase 5 fresh-root projection coverage landed in MoonTown commit `19dfada1`
  and MoonDesk commit `a6cac733`, proving the Rabbita/MoonDesk book path
  contract from both sides. The MoonTown Rabbita Vite bridge defaults
  `booksRootPath` to the fresh suite `books` root, keeps product-owned bridge
  files under `.moonsuite/products/moontown`, and exposes
  `MOONTOWN_SUITE_ROOT`, `MOONTOWN_BOOKS_ROOT`, and
  `MOONTOWN_PRODUCT_STATE_ROOT` overrides for smoke runs. `npm run
  smoke:book-projections` creates a temporary fresh suite root and asserts that
  `books/wenyu-social-square/book/moonbook-ui-state.json` flows into
  `loadModuleProjectionIndex()` with the generated-site link intact. MoonDesk's
  `internal/moonwiki` white-box coverage builds the matching fresh suite root
  and asserts Desk workspace discovery exposes the MoonBook, canonical virtual
  entries, and projection file resolution without creating
  `.moontown/books/<book-id>`. Validation passed with Rabbita `npm run
  smoke:book-projections`, MoonTown `moon check`, `moon test` (923/923),
  `moon fmt`, `moon info`, final `moon check`, plus MoonDesk `moon check`,
  `moon test` (446/446), `moon fmt`, `moon info`, and final `moon check`.
- MoonDesk commit `76ba4069` extends the full Desk browser smoke to cover the
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
- MoonDesk commit `801b23b0` adds the Lepusa-native fresh-books smoke gate. The
  new `scripts/lepusa_fresh_books_smoke.sh` seeds a temporary fresh MoonSuite
  root with `.moonsuite`, `.tmp`, and `books/research-alpha` containing
  `book/moonbook-ui-state.json` plus `book/site/generated/index.html`; runs
  `lepusa live-smoke macos --strict` against that root and the Rabbita Desk UI;
  then parses the generated live project and runtime manifest to assert the
  bundled `moondesk-sidecar serve <fresh-root>` command, readiness URL, and
  absence of legacy `.moontown/books`. Validation passed with
  `scripts/lepusa_fresh_books_smoke.sh`, `moon check`, `moon test` (446/446),
  `moon fmt`, `moon info`, and final `moon check`.
- MoonGate commit `cf7fd62` closes the current Phase 8 drift-report slice. The
  report now carries explicit probe paths and scopes, exposes MoonRobo
  canonical product-home and suite-temp paths, and treats legacy `.moontown`,
  `.moonclaw`, `.moontown/moondesk-daemon`, `moonclaw-jobs`, root-local
  `moongate`, MoonRobo `runs/gateway-commands`, `runs/robo-loops`,
  `runs/proof-sessions`, and old global SDK E1 bridge temp files as drift
  candidates. Tests use an injectable `global_tmp_root` so production can still
  inspect `/tmp` while the suite stays deterministic. Validation passed with
  MoonGate `moon check`, `moon test` (773/773), `moon fmt`, `moon info`, and a
  final `moon check`.
- MoonDesk adapters and MoonWiki run readers now expose MoonClaw run artifacts
  through `.moonsuite/products/moonclaw/jobs` instead of `moonclaw-jobs` or
  `.moonclaw/jobs/runs`, while the MoonTown adapter derives town snapshots,
  daemon state, standing goals, and watcher roots from MoonLib
  `@moonsuite.product_artifact`. The matching MoonWiki fixture seeds forwarded
  run artifacts under the MoonSuite product home, and adapter tests assert the
  old `moonclaw-jobs` section is gone.
- MoonTown launchd install/uninstall scripts now write plist and stdout/stderr
  logs under `.moonsuite/products/moontown/launchd` and
  `.moonsuite/products/moontown`, not `.moontown/launchd`; usage docs now point
  operators at the product-home launchd paths.
- MoonTown MoonBook adapter residuals now route the MoonCode book-result
  processed ledger through
  `.moonsuite/products/moontown/mooncode-book-results/<book-id>/processed.jsonl`
  and default the local MoonBook checkout fallback to
  `.moonsuite/products/moontown/external/moonbook`, eliminating the active
  `.moontown/mooncode-book-results` and `.moontown/moonbook` write targets.
  Validation passed with MoonTown `moon fmt`, `moon info`, `moon check`, and
  `moon test` (925/925).
- MoonTown commit `4eb1f047` upgrades to MoonLib `0.1.3` and routes the
  remaining active MoonClaw home/config writers in the MoonClaw command
  adapter, book-quality review dispatch/reconcile flow, and Wenyu build
  preseed through MoonLib-derived MoonClaw product homes. Book-quality review
  config now writes
  `.moonsuite/products/moontown/book-quality/.moonsuite/products/moonclaw/moonclaw.json`,
  direct review polling reads jobs from that matching product home, and Wenyu
  preseed no longer creates root-local `moonclaw.json` or `.moonclaw` config
  files. Validation passed with MoonTown `moon update`, `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- MoonTown commit `8f56f390` removes the next active `.moonclaw` home targets
  from PlanBook repair ACP config and editor feature-selection MoonClaw
  dispatch. PlanBook repair now writes Codex ACP target config through
  `@moonsuite.product_artifact_for_workspace_root(workspace_root, "moonclaw",
  "moonclaw.json")`, and editor feature-selection imports/runs pass the
  workspace root as MoonClaw `--home` so MoonClaw derives the product home
  itself. Validation passed with MoonTown `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (926/926), and `git diff --check`.
- MoonTown commit `1eaff85d` moves the MoonClaw run polling adapter onto the
  MoonLib product-home job store. The adapter now derives
  `.moonsuite/products/moonclaw/jobs` through `@moonsuite` for suite-root
  callers while still accepting already-derived MoonClaw product homes from
  book-quality and PlanBook flows. Wenyu build review prompts now tell workers
  to read run-workspace `run.json` instead of stale `.moonclaw/run.json`, and
  run-polling/PlanBook path tests seed fresh product-home fixtures instead of
  `.moonclaw/jobs`. Validation passed with MoonTown `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- MoonTown commit `0c4e6f33` aligns public operator/frontend documentation
  with the already-migrated runtime product-home paths. `docs/USAGE.md` and
  `docs/FRONTEND.md` now describe active town snapshots, daemon state/runtime
  files, standing-goal inputs, watcher ledgers, book-quality review artifacts,
  town synthesis, and the MoonClaw job-store archive under
  `.moonsuite/products/moontown/...` or `.moonsuite/products/moonclaw/jobs/...`
  instead of `.moontown/...` or `.moonclaw/jobs/...`. Validation passed with
  MoonTown `moon fmt`, clean `moon info` after reverting unrelated generated
  `.mbti` EOF churn, `moon check`, `moon test` (926/926), and
  `git diff --check`.
- MoonTown commit `03217510` removes the next stale live-autonomy and MoonDesk
  handoff fixture paths from operator-facing surfaces. Live-autonomy markdown
  and Rabbita viewport fixtures now advertise
  `.moonsuite/products/moontown/...` product paths and PlanBook wiki history
  paths, the MoonDesk handoff tilemap module now stages agent profiles and
  operator requests under the MoonTown product home, and README copy points the
  MoonClaw hot-store archive at `.moonsuite/products/moonclaw/jobs/archive`.
  Validation passed with MoonTown `moon fmt`, clean `moon info` after reverting
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
- MoonGate commit `e776bef` updates the suite drift report to match that
  MoonCode ownership boundary. Book-local
  `books/<book-id>/.moonclaw/mooncode/sessions` drift now reports the canonical
  target as `.moonsuite/products/moonclaw/mooncode/sessions` and product owner
  `moonclaw`, not `.moonsuite/products/mooncode/sessions`. Validation passed
  with MoonGate `moon fmt`, clean `moon info`, `moon check`, `moon test`
  (774/774), and `git diff --check`.
- MoonRobo commit `c69cc9ea` expands the public product-status MoonSuite
  contract so Rabbita, MoonDesk, and status consumers can see every migrated
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
- MoonGate commit `2d9b732` upgrades the observer to MoonLib `0.1.3` and
  derives book-local MoonClaw provider/session drift targets through
  `@moonsuite.product_artifact_for_workspace_root(...)`. The suite drift report
  now proves the current workspace-root contract for suite-hosted MoonBooks
  while keeping MoonGate a validator/reporter instead of a path-schema owner.
  Validation passed with MoonGate `moon update`, `moon fmt`, clean `moon info`,
  `moon check`, `moon test` (774/774), and `git diff --check`.
- MoonGate commit `26531ce` removes the remaining active empty-root MoonSuite
  calls from app config, suite status, MoonClaw provider/model/config manifest
  defaults, and suite integration command output. Public workspace-root helpers
  now expose MoonGate product home, suite status, and MoonClaw provider manifest
  paths for suite-hosted book roots, and white-box tests prove those roots map
  to suite-level `.moonsuite` paths rather than nested `books/<book-id>` state.
  Validation passed with MoonGate `moon fmt`, clean `moon info`, `moon check`,
  `moon test` (774/774), and `git diff --check`.
- MoonTown now removes the remaining runtime-test fixtures that explicitly
  exercised `root/moonbooks.json` as the catalog location for cookbook and
  book-quality bootstraps. Those tests now use
  `@storage.moontown_product_artifact_for_workspace_root(root,
  "moonbooks.json")`, proving the fresh suite product-home catalog contract in
  the same flows. Validation passed with MoonTown `moon fmt`, clean
  `moon info`, `moon check`, `moon test` (926/926), and `git diff --check`.
- MoonTown MoonBook evidence accounting now recognizes operational MoonClaw
  run evidence only when the completed workflow path is under the MoonSuite
  product-home job store
  `.moonsuite/products/moonclaw/jobs/run-...`. The retired
  `moonclaw-jobs/run-...` root is covered as ordinary domain evidence rather
  than an active operational marker. Validation for this slice: MoonTown
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
- MoonTown active skill/template/cookbook copy now advertises watcher ledgers,
  standing-goal registration, generated cookbook state, and MoonClaw execution
  workspaces under `.moonsuite/products/moontown/...` and
  `.moonsuite/products/moonclaw/jobs/...` instead of retired `.moontown` or
  book-local `.moonclaw/jobs` paths. Validation for this slice: MoonTown
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
- MoonTown central operator and architecture docs now describe executable-book
  events, MoonCode sidecars, processed sidecar ledgers, daemon state, watcher
  ledgers, book-template inboxes, book-quality artifacts, PlanBook autonomy,
  live digests, and town synthesis outputs under `.moonsuite/products/...`
  product homes instead of retired book-local or repo-local `.moonbook`,
  `.moonclaw`, and `.moontown` roots. Validation for this slice: MoonTown
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
- MoonTown Wenyu building/status/valley docs now describe protocol ledgers,
  watcher ledgers, daemon state, town-runtime projection, and backup scope
  under `.moonsuite/products/moontown/...` instead of the retired
  repo-local `.moontown` root. Validation for this slice: MoonTown `moon fmt`,
  `moon info`, `moon check`, `moon test` with `927/927` tests passing, focused
  MoonTown docs stale-path scan with only the `com.vectie.moontown` launchd
  identifier false positive, restored whitespace-only generated `.mbti` churn
  from `moon info`, and `git diff --check`.
- MoonDesk Wiki-mode E2E test planning now routes backward-run MoonClaw
  artifacts to `raw/analysis-runs` or the product-home jobs lane at
  `.moonsuite/products/moonclaw/jobs` instead of presenting retired
  `moonclaw-jobs` as an active inspection location. Validation for this slice:
  focused `docs/WIKI_MODE_TEST_PLAN.md` stale-path scan and `git diff --check`;
  broader residual scans still show intentional drift/regression fixtures in
  MoonGate, MoonClaw, MoonBook, MoonTown, and MoonDesk tests.
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
- MoonGate OpenClaw standalone workspace state now belongs to MoonGate's
  product home. The `/workspace/files...` and `/workspace/memory...` helpers
  derive `.moonsuite/products/moongate/openclaw/workspace` through MoonLib's
  workspace-root product-artifact constructor instead of writing directly to
  `~/.moonsuite/openclaw/workspace`; white-box coverage now asserts the
  product-owned workspace and memory paths and rejects the old standalone
  location. Validation for this slice: focused MoonGate OpenClaw workspace
  stale-path scan, `moon fmt`, `moon info`, `moon check`, `moon test` with
  `775/775` tests passing, and `git diff --check`.
- MoonGate-owned auth and gateway token stores now live under MoonGate's
  product home. Codex OAuth credentials, Copilot credentials, and the Claude
  Desktop gateway token derive
  `.moonsuite/products/moongate/auth/...` through MoonLib workspace-root
  product-artifact constructors instead of using top-level `~/.moonsuite`
  files; the external Codex CLI source credential at `.codex/auth.json`
  remains an external source-of-truth reader. Validation for this slice:
  focused MoonGate auth/token stale-path scan, no generated `.mbti` changes,
  `moon fmt`, `moon info`, `moon check`, `moon test` with `779/779` tests
  passing, cleanup of test-created untracked `.moonsuite` runtime output, and
  `git diff --check`.
- MoonDesk's optional MoonGate plugin now discovers MoonGate through the active
  workspace's suite-status contract instead of concatenating the operator home
  directory with `/.moonsuite/suite-status.json`. The plugin derives
  `.moonsuite/suite-status.json` from MoonLib's workspace-root suite
  constructor, keeps rejecting legacy shortcut status shapes, and has
  white-box coverage for suite-hosted book workspaces. Validation for this
  slice: focused MoonDesk MoonGate plugin stale-path scan, no generated
  `.mbti` changes, `moon fmt`, `moon info`, `moon check`, `moon test` with
  `459/459` tests passing, and `git diff --check`.
- MoonClaw and MoonTown now apply the same MoonGate plugin suite-status
  discovery contract. Their optional MoonGate clients derive the active
  workspace's `.moonsuite/suite-status.json` path through MoonLib instead of
  reading `$HOME/.moonsuite/suite-status.json`, with white-box coverage for
  suite-hosted book workspaces and stale-path scans limited to canonical test
  expectations. Validation for this slice: MoonClaw `moon fmt`, `moon info`,
  `moon check`, `moon test` with `1003/1003` tests passing and cleanup of
  test-created untracked `.moonsuite` runtime output; MoonTown `moon fmt`,
  `moon info` with unrelated whitespace-only `.mbti` churn restored,
  `moon check`, `moon test` with `928/928` tests passing; focused plugin
  stale-path scans; and `git diff --check` in both repos.
- MoonBook's optional MoonGate plugin now uses the same MoonLib-derived
  suite-status discovery path as MoonDesk, MoonClaw, and MoonTown. The plugin
  reads the active workspace's `.moonsuite/suite-status.json` instead of
  deriving `$HOME/.moonsuite/suite-status.json`, with white-box coverage for
  suite-hosted book workspaces and a focused stale-path scan limited to the
  canonical test expectation. Validation for this slice: MoonBook `moon fmt`,
  `moon info` with no generated `.mbti` changes, `moon check`, `moon test`
  with `200/200` tests passing, and `git diff --check`. The MoonBook push also
  reconciled Gitee's older divergent `main` without keeping legacy
  `moon.mod.json` or the stale singular `plugin/moongate` directory.
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
- MoonDesk's MoonCode and executable-book architecture docs no longer show
  book-local `.moonclaw/mooncode/sessions` as the durable layout. The current
  docs describe native MoonCode session sidecars under the selected
  MoonSuite root's MoonClaw product home at
  `.moonsuite/products/moonclaw/mooncode/sessions/...`, keeping the public
  architecture guidance aligned with the runtime contract used by MoonClaw and
  MoonDesk projections. Validation for this slice: focused stale-layout doc
  scan, MoonDesk `moon test` with `459/459` tests passing, and
  `git diff --check`.
- MoonTown's top-level README no longer advertises retired
  `.moontown/civic/...` schedule, scenario, or pattern-run paths. The operator
  quickstart now matches the rest of the MoonTown civic docs and runtime
  helpers by pointing communication-pattern state at
  `.moonsuite/products/moontown/civic/...`. Validation for this slice: focused
  README stale-path scan and `git diff --check` in MoonTown and MoonDesk.
- MoonClaw's todo tool coverage no longer renders `.moonclaw/repos/...` as an
  example repository inspection target in user-visible todo output. The fixture
  now uses the MoonClaw product home at
  `.moonsuite/products/moonclaw/repos/...`, while the remaining MoonClaw
  `.moonclaw` scan hits are negative regression assertions or deliberate
  legacy-reader fixtures. Validation for this slice: focused MoonClaw
  todo/operator-output stale-path scan, `moon fmt`, `moon info`, `moon check`,
  `moon test`, and `git diff --check`.
- MoonGate's suite integration JSON no longer advertises home-global
  `~/.moonsuite/products/moonclaw/...` candidates for MoonClaw model and config
  files. The MoonClaw integration now exposes only the active workspace-root
  product-home paths derived through MoonLib, and coverage rejects the old
  home-global candidates. Validation for this slice: focused MoonGate
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
- MoonDesk now consumes MoonLib `0.1.4` in its internal MoonWiki MoonSuite
  facade. Workspace-derived product home and service paths resolve through
  `@moonsuite.product_home_for_workspace_root`, while the direct suite-root
  product-directory wrapper remains only for preparing product directories in
  an already-selected suite root. Validation for this slice: MoonDesk `moon
  update`, `moon fmt`, `moon info`, `moon check`, full `moon test`, focused
  facade primitive-formula scan, and `git diff --check`.
- MoonTown now consumes MoonLib `0.1.4` in its storage facade. Product state,
  service, and temp path helpers derive from
  `@moonsuite.product_home_for_workspace_root`, while arbitrary product
  artifacts stay on the existing MoonLib artifact constructor. Validation for
  this slice: MoonTown `moon update`, `moon fmt`, `moon info`, `moon check`,
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
- MoonGate now consumes MoonLib `0.1.4` for suite status and drift canonical
  product paths. Suite canonical product homes, MoonRobo suite-temp SDK paths,
  and legacy drift canonical targets now derive from MoonLib `ProductHome`
  fields instead of direct `product_dir`/`product_tmp_dir` formulas, and the
  workspace-root MoonGate product-home helper uses the workspace-root
  `ProductHome` constructor. Validation for this slice: MoonGate `moon update`,
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
- MoonTown runtime, storage, and book-quality residuals now consume MoonLib
  `ProductHome` fields directly. The PlanBook MoonClaw runtime adapter,
  MoonTown temp-dir assertion, and book-quality MoonClaw home helpers no longer
  rebuild product state/temp homes through primitive constructors or empty
  artifact paths. The remaining MoonDesk MoonWiki suite-root facade also now
  returns `ProductHome.state_path` instead of delegating to the primitive
  product-dir constructor. Validation for this slice: MoonTown `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`928/928`), MoonDesk `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`459/459`), generated-interface
  churn restore, `git diff --check`, and a cross-product `.mbt` scan proving
  zero remaining direct calls to `@moonsuite.product_dir`,
  `@moonsuite.product_tmp_dir`, or `@moonsuite.product_service_path` in the
  scanned product repos.
- MoonTown PlanBook runtime display text now routes product-home examples
  through a storage-owned display helper instead of hand-written
  `.moonsuite/products/moontown/...` literals. `storage` now exposes
  `moontown_product_display_artifact` for relative documentation/operator
  strings, and PlanBook autonomy digest, repair-plan, UI-spine, and validation
  next-action text use that helper. Validation for this slice: MoonTown
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`928/928`),
  generated-interface diff review for the intentional storage API addition,
  generated-interface churn restore, `git diff --check`, and a focused
  PlanBook/runtime storage scan proving zero remaining hard-coded
  `.moonsuite/products/moontown` strings in non-test MoonBit source for those
  packages.
- MoonTown native cookbook, civic, and book-quality display text now also
  routes product-home examples through storage-owned display helpers.
  `storage` exposes `moontown_product_display_state_dir` for product-home root
  references, the cookbook package has local formatting helpers backed by
  storage, and cookbook stable-state manifests/pages, civic protocol ledger
  text, and book-quality packet readme text no longer hand-write
  `.moonsuite/products/moontown/...` literals. Validation for this slice:
  MoonTown `moon fmt`, `moon info`, `moon check`, full `moon test` (`928/928`),
  generated-interface diff review for the intentional storage API addition,
  generated-interface churn restore, `git diff --check`, a focused native
  package scan proving zero remaining hard-coded `.moonsuite/products/moontown`
  strings in non-test `src/cookbook`, `src/civic`, and `src/book_quality`
  MoonBit source, and a broader remaining-source scan showing the remaining
  active display literals are isolated to PlanBook/editor template text and the
  Rabbita-town JS UI package.
- MoonTown PlanBook/editor template packages and the Rabbita-town JS UI package
  now clear the remaining active MoonTown product-home display literals.
  PlanBook/editor native template text uses the storage-owned display helper;
  `editor_pipeline` and `planbook_policy` declare native targets after the
  storage dependency. The JS UI package keeps a local pure-string display helper
  because the browser target cannot depend on native storage. Validation for
  this slice: MoonTown `moon fmt`, `moon info`, `moon check`, full `moon test`
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
  MoonDesk now consumes the shared helper through `core` and routes MoonClaw
  job paths, MoonTown bridge paths, MoonDesk trash paths, PDF watch MoonTown
  publish metadata, and MoonCode contract text through it. MoonRobo's
  product-status display helper now delegates to the MoonLib contract instead
  of owning the formula locally. Validation for this slice: MoonLib clean
  worktree `moon fmt`, `moon info`, `moon check`, full `moon test` (`37/37`),
  `moon publish` for `vectie/moonlib@0.1.5`, MoonDesk `moon fmt`, `moon info`,
  `moon check`, full `moon test` (`459/459`), MoonRobo `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`453/453`), generated-interface
  diff review/churn restore, `git diff --check`, and focused active-source
  scans proving MoonDesk has zero `.moonsuite/products` literals while MoonRobo
  has zero `.moonsuite/products/moonrobo` literals and no MoonLib `0.1.4` pin.
- The remaining clean product repos now consume MoonLib `0.1.5` for this
  display-contract slice. MoonTown storage and Rabbita-town display helpers
  delegate to `product_display_dir` / `product_display_artifact`, and the
  MoonClaw run/evidence bridge uses MoonLib display helpers for MoonClaw job
  paths. MoonClaw MoonCode session display text, ACP help text, daemon/job
  capability text, rules output, and skills/daemon comments now route through
  the shared display contract or avoid hand-written product-home paths.
  MoonGate command help derives the MoonClaw providers path through MoonLib.
  MoonBook extension tests now assert expected MoonClaw product paths through
  MoonLib constructors. MoonFish, MoonMoon, and Lepusa were upgraded to the
  same dependency version so the clean suite-wide consumers are aligned on the
  published contract. Validation for this slice: MoonTown `moon fmt`,
  `moon info`, `moon check`, full `moon test` (`928/928`), MoonClaw
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`1005/1005`),
  MoonGate
  `moon fmt`, `moon info`, `moon check`, full `moon test` (`779/779`),
  MoonBook `moon fmt`, `moon info`, `moon check`, full `moon test`
  (`200/200`), MoonFish `moon fmt`, `moon info`, `moon check`, full
  `moon test` (`145/145`), MoonMoon `moon fmt`, `moon info`, `moon check`,
  full `moon test` (`143/143`) with the existing two unused-value warnings,
  Lepusa `moon fmt`, `moon info`, `moon check`, full `moon test` (`374/374`),
  generated-interface churn review/restore, MoonClaw/MoonGate test-output
  cleanup, `git diff --check`, a clean touched-repo stale-pin scan for
  `vectie/moonlib@0.1.4` and older, and active-source scans proving MoonTown
  and MoonClaw have no raw `.moonsuite/products` literals outside tests and
  generated interfaces.
- MoonTown now has an explicit `MOONTOWN_SUITE_ROOT` fresh-suite override for
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
  `vectie/moonlib@0.1.8`. Its generic `ProductHome` contract remains the shared
  source for runtime product paths, product display paths, and accepted-output
  book-id inference when a workspace root is already `books/<book-id>`.
  MoonLib `0.1.8` also owns the shared `vectie/moonlib/conversation` contract
  used by MoonCode to project append-only user, progress, and assistant turns.
  The local MoonLib source checkout now carries that published package, and the
  Phase 9 conversation rollout validator keeps source, registry pins, and
  product adapters aligned.
  MoonFish, MoonMoon, and MoonChat now cover both explicit and inferred
  book-root layouts in unit tests and fresh-suite smokes. Current product-repo
  pin gates expect all MoonLib consumers to use `vectie/moonlib@0.1.8`:
  MoonDesk, MoonRobo, MoonTown, MoonClaw, MoonGate, MoonBook, MoonFish,
  MoonMoon, MoonChat, and Lepusa.
- MoonGate: Phase 8 drift coverage for the known legacy product homes,
  repo-local runtimes, and MoonRobo global temp files is now covered. Keep
  consuming MoonLib contracts for workspace validation, health projection, and
  future drift additions, but do not add a parallel path schema there. The
  book-local MoonClaw provider and MoonCode sidecar drift targets now derive
  from the MoonLib workspace-root product-artifact helper, matching MoonClaw's
  current durable product-home contract. Suite status canonical paths and
  legacy-drift canonical targets now consume MoonLib `ProductHome` fields
  directly. The next MoonGate cleanup slice makes drift-report suite roots
  workspace-root aware as well: passing `books/<book-id>` now normalizes back to
  the owning suite root before canonical paths and product artifacts are
  reported, while the global temp root remains a plain trimmed temp root.
  MoonFish's suite-status helper now follows the same workspace-root rule, so
  a book-root caller resolves the owning suite `.moonsuite/suite-status.json`
  instead of a nested book-local status file. MoonFish's legacy `.moonfish`,
  MoonMoon's legacy `.moonmoon`,
  MoonChat's legacy `.moonchat`, and MoonVis's legacy `.moonvis` suite-root
  homes, plus stale `.moondesk`, `.moonbook`, `.moonwiki`, `.mooncode`,
  `.bookkeeper`, `.lepusa`, and `.rabbita` suite-root homes, are now reported
  as drift against their matching `.moonsuite/products/<product>` homes;
  remaining work should focus on new drift coverage rather than local
  product-home formula cleanup. The canonical drift payload now also exposes
  the full first-party product-home set for
  MoonDesk, MoonBook, MoonWiki, MoonCode, MoonGate, MoonClaw, MoonTown,
  MoonRobo, MoonFish, MoonMoon, MoonChat, MoonVis, Bookkeeper, Lepusa, and
  Rabbita through MoonLib-derived paths, so downstream validators can compare
  every product against one contract report. MoonLib's default product registry
  now also includes MoonChat and MoonVis, closing the gap where those products
  had fresh product-home smoke gates and MoonGate drift reporting but were not
  present in the shared registry list. The registry update is published in
  MoonLib `0.1.6`, and MoonDesk now consumes that version so its fresh
  workspace serve-prep test asserts explicit MoonChat and MoonVis registry
  entries instead of count-only coverage. The touched product-repo pin scan now
  reports only MoonLib `0.1.6` across MoonDesk, MoonRobo, MoonTown, MoonClaw,
  MoonGate, MoonBook, MoonFish, MoonMoon, MoonChat, and Lepusa. The first clean
  sibling consumer batch pushed MoonTown `main` commit `30701910`, MoonRobo
  `moondata` commit `e072f398`, MoonBook `main` commit `0a7458a`, MoonFish
  `main` commit `8c91614`, MoonMoon `main` commit `eafebca5`, and Lepusa
  `main` commit `c402ad2`. The final stale-pin batch pushed MoonGate `main`
  commit `65286de` and MoonClaw `main` commit `cb88edc1` to both their tracking
  origins and GitHub mirrors. MoonChat `main` commit `fcc229b` carries the same
  pin locally, but that checkout has no configured remote and
  `git ls-remote git@github.com:vectie/moonchat.git` reports the repository is
  unavailable, so it still needs a publish destination before it can be pushed.
  `scripts/validate_moonlib_consumer_pins.sh` now makes this product-repo pin
  audit repeatable from MoonDesk and fails if any touched consumer drifts away
  from the expected MoonLib version.
- MoonGate commit `7edaf0d` removes the remaining cwd-local Warp temporary
  launch script pattern. Warp resume scripts now derive their directory from
  MoonLib's workspace-root MoonGate product home and are written under
  `.tmp/products/moongate/warp`, including when the selected cwd is
  `books/<book-id>`. Validation passed with MoonGate `moon fmt`, `moon info`,
  `moon check --target native --diagnostic-limit 80`, full
  `moon test --target native` (`780/780`), `git diff --check`, the MoonDesk
  residual guard, the MoonLib consumer-pin guard, and the full cross-product
  `scripts/fresh_suite_product_smoke.sh` gate.
- MoonClaw: commit `3a6aeaa3` moves the daemon/UI discovery path onto the
  served workspace root instead of OS home. Detached daemon startup now waits
  on the MoonLib-derived product-home `daemon.json` for the selected
  `--serve` root, foreground daemon startup passes the same root as `home`,
  model loading uses that root, and the native/VSC UI bootstrap passes its
  active workspace root to daemon startup, API discovery, and shutdown. This
  closes the active UI/runtime mismatch where MoonClaw wrote fresh product-home
  daemon state but the UI still looked under the user-home product directory.
  Validation passed with MoonClaw `moon fmt`, `moon info`,
  `moon check --target native --diagnostic-limit 80`, full
  `moon test --target native` (`1006/1006`), `git diff --check`, and
  `scripts/fresh-suite-product-home-smoke.sh`. The current UI TypeScript
  checks still stop on existing package alias/type-root issues unrelated to
  this slice: stale `@maria/core` imports in the core/native renderer packages,
  missing `node` type roots in native, and unresolved `@moonclaw/core`
  workspace package aliases in native/VSC package-local `tsc` runs.
- MoonDesk: MoonCode session/event sidecars and the MoonTown bridge
  request/dispatch ledgers now derive from MoonLib workspace-root helpers, and
  MoonClaw job roots plus MoonDesk daemon/preference state now resolve through
  the owning suite instead of nested book-local `.moonsuite` directories. Trash
  file and receipt coverage now proves the same suite-root behavior for direct
  Desk and HTTP flows. The internal MoonWiki layout facade now consumes
  MoonLib `ProductHome` for suite-root and workspace-derived product home and
  service paths. MoonDesk `core` now exposes MoonLib-backed product display
  helpers plus suite-root and books-root helpers, and active
  MoonWiki/MoonCode/MoonBook adapter product-home display strings route
  through that shared contract. MoonDesk `core` now also centralizes the
  MoonLib-derived `.moonsuite` and `.tmp` internal relative-path policy used by
  source-layer inference, HTTP path resolution, Desk listing hides, and Desk
  create-route protection. The Rabbita Desk UI now derives the visible
  MoonSuite root and MoonBook library path through those core/MoonLib helpers
  instead of parsing or appending `/books` inside the frontend state layer.
  The current MoonDesk MoonBit scan has zero quoted
  `.moontown`/`.moonclaw` literals, zero active old-path file-operation hits,
  and zero active `.moonsuite/products` literals outside generated interfaces
  and tests. MoonDesk serve-prep coverage now also asserts a fresh workspace
  creates the full first-party MoonLib registry, including MoonChat and MoonVis,
  and does not recreate stale suite-root product homes such as `.moondesk`,
  `.moonbook`, `.mooncode`, `.moonchat`, `.moonvis`, `.lepusa`, or `.rabbita`.
  The new `scripts/fresh_suite_product_smoke.sh` gate runs the
  MoonTown, MoonClaw, MoonBook, MoonRobo, MoonFish, MoonMoon, MoonChat,
  MoonVis, and Lepusa fresh-suite smoke scripts from one MoonDesk command,
  giving the migration a single cross-product integration check for the main
  writer surfaces and product-home contracts already cut over to product homes.
  After the MoonLib `0.1.6` rollout, this full cross-product smoke gate passed
  end-to-end: each product-specific fresh-suite gate reported success and the
  Lepusa fresh-books/live bundle check completed with `Fresh MoonSuite product
  smoke passed`. The new `scripts/validate_fresh_suite_residuals.sh` Phase 8
  guard now makes the active-source residual scan repeatable across MoonDesk,
  MoonRobo, MoonTown, MoonClaw, MoonGate, MoonBook, MoonFish, MoonMoon,
  MoonChat, MoonVis, and Lepusa. It fails on unapproved quoted legacy hidden
  product-home strings in production source while allowing MoonGate's drift
  probes and the current negative regression assertions. The first run passed
  for all 11 scanned repositories, so the remaining residual work should be
  driven by deeper behavioral smoke coverage rather than broad hidden-home
  string cleanup.
  Remaining Phase 4 work should focus on cross-product residuals and any
  product-home display/API text that belongs in Phase 6 or Phase 7 rather than
  MoonDesk old-writer cleanup.
  A later active-source scan moved the MoonDesk MoonTown snapshot adapter to
  MoonLib workspace-root product-artifact helpers as well, so selecting a
  `books/<book-id>` root now resolves town snapshots, daemon state, standing
  goals, and watcher directories through the owning suite product home instead
  of a nested book-local `.moonsuite/products/moontown`.
  The MoonDesk MoonWiki layout facade now also treats its suite-level helpers as
  workspace-root aware: `moonsuite_root`, state, books, tmp, products,
  services, product registry, product directories, and suite manifest helpers
  normalize `books/<book-id>` roots through MoonLib before constructing paths.
  Workspace metadata and the shared core `moonsuite_books_root` wrapper now
  report the owning suite's `books/` and `.moonsuite/` paths for a selected
  book root instead of nested book-local suite state.
  The next MoonDesk boundary slice introduces an explicit MoonWiki
  `WorkspaceContext` so root workspace API metadata and health responses derive
  requested root, suite root, books root, state dir, tmp root, and product
  registry path once before presenting them to Phase 6 API and Phase 7 UI
  callers.
  Follow-on Phase 6/7 propagation moved MoonBook creation/import, book contract
  verification, app-tool portable discovery/export, and book standing-goal sync
  onto that context-owned book-root contract. These routes now accept either a
  suite root or selected `books/<book-id>` root and write/read sibling books and
  MoonTown state through the owning suite instead of recomputing local
  `books/` paths per handler.
  The broad replacement sweep then moved the remaining MoonDesk MoonCode,
  MoonClaw daemon, MoonTown analytics/events/requests, daemon lifecycle,
  LaunchAgent, template-registry, runtime-support, review fallback, server, and
  HTTP file-resolution edges away from local `workspace_root` normalization.
  Route handlers now either derive the owning suite through `WorkspaceContext`
  or deliberately use the requested workspace root for file operations scoped
  to the selected workspace.
- MoonTown: remaining Phase 5 work should focus on any product-owned residual
  writers discovered by new smoke coverage; the programmatic Rabbita/MoonDesk
  contract, full Desk browser smoke, Lepusa-native fresh-books smoke, and
  launchd product-home script path are now covered. The MoonCode sidecar
  processed-result ledger and MoonBook fallback checkout path are now
  product-home based, and the active MoonClaw command/book-quality/preseed,
  run polling, plus PlanBook repair/editor feature-selection MoonClaw home
  flows now use MoonLib-backed MoonClaw product homes instead of `.moonclaw`.
  The storage facade now derives MoonTown product state, service, and temp
  paths from MoonLib `ProductHome`; the PlanBook runtime adapter and
  book-quality MoonClaw homes now also derive through MoonLib `ProductHome`
  fields. PlanBook runtime operator/display strings now use the storage-owned
  product display helper for MoonTown product artifacts. Native cookbook,
  civic, book-quality, PlanBook/editor template, and Rabbita-town UI display
  strings also route through MoonLib-backed storage-owned or package-local
  display helpers. Civic service result routing now delegates suite-hosted
  MoonBook detection to a storage helper backed by MoonLib workspace-root
  normalization instead of matching raw `books/` substrings inside the civic
  package.
  MoonTown CLI writers now honor `MOONTOWN_SUITE_ROOT`, default MoonBook roots
  derive from that active suite root, and a fresh-suite writer smoke gate covers
  representative product-owned PlanBook, course, cookbook, book-quality, and
  live-autonomy outputs. Remaining MoonTown work should focus on newly
  discovered product-owned residuals from deeper smoke coverage, not local
  product-home display formula cleanup.
  The MoonClaw run polling store now uses the MoonLib workspace-root
  product-artifact helper for the `jobs` store, while preserving direct
  handling of an already-selected MoonClaw product home. White-box coverage now
  writes and polls a run using a `books/<book-id>` home and asserts no
  book-local `.moonsuite/products/moonclaw` path is created.
- MoonBook: the MoonClaw wiki extension now keeps its workspace-owned
  `moonclaw.jobs.json` beside the book, but writes the MoonClaw runtime config
  to the suite product home at `.moonsuite/products/moonclaw/moonclaw.json`
  instead of recreating a book-root `moonclaw.json`. The extension manifest
  advertises the product-home config entry, provider manifests remain under the
  MoonClaw product home, and `scripts/fresh-suite-extension-smoke.sh` now runs
  native `wiki init` plus `wiki enable moonclaw` against a fresh
  `books/<book-id>` root to prove both product-home writes and absence of
  legacy `.moonclaw`, root `moonclaw.json`, and `moonclaw-jobs` paths. The
  skill hub now derives its ignored `.moonsuite` and `.tmp` directory names
  from MoonLib state/temp constructors instead of carrying separate local
  literals in debug metadata and recursive scan filtering. The MoonClaw
  extension runtime helper now uses MoonLib `product_home_for_workspace_root`
  directly for the product state directory, and embedded extension tests now
  assert config/provider paths with workspace-root artifact constructors rather
  than suite-root-only `product_home` or `product_artifact` examples.
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
  compatibility. The latest MoonRobo executable contract cleanup removes the
  remaining suite-root-only `product_home`/`product_artifact` examples from
  bridge sidecar, RoboBook runtime, and product-status tests; those assertions
  now feed the selected `books/<book-id>` root into MoonLib workspace-root
  constructors and prove the same suite-level product homes are derived from
  that book root.
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
  The latest MoonClaw residual slice also routes starter attachment storage,
  ACP default workspace selection, MoonCode `moon_check` watcher state, system
  skill installation, and rules discovery through MoonLib workspace-root
  constructors, with explicit `books/<book-id>` coverage proving those surfaces
  resolve to the suite product home instead of recreating book-local
  `.moonsuite/products/moonclaw` paths.
  A follow-up active-runtime scan now leaves only helpers that already receive
  a normalized suite root before calling suite-root MoonLib APIs; onboarding
  default workspace creation, default MoonClaw/agent log paths, and gateway
  robot-routine ledgers have moved to workspace-root constructors, with
  `books/<book-id>` tests covering onboarding and robot-routine ledger writes.
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
