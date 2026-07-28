# Phase 4 Package Ownership and Dependency Map

Status: prerequisite review deliverable only. This document does **not** complete Phase 4 and authorizes no extraction.

Evidence date: 2026-07-28, clean `github/main` worktree on branch `codex/moondesk-phase4-ownership-map`, before this document was added. The authoritative scope is Phase 4 of `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`.

## Measurement method and caveat

Counts below are repository-owned MoonBit files: `.git`, `.mooncakes`, `ui/rabbita-desk/.mooncakes`, and `vendor` are excluded. A test file ends in `_test.mbt` or `_wbtest.mbt`; all other `.mbt` files are production sources. Lines are physical lines from `wc -l`.

Reproduce the inventory from the repository root:

```sh
find . -path './.git' -prune -o -path './.mooncakes' -prune -o \
  -path './ui/rabbita-desk/.mooncakes' -prune -o -path './vendor' -prune -o \
  -name moon.pkg -type f -print
find . -path './.git' -prune -o -path './.mooncakes' -prune -o \
  -path './ui/rabbita-desk/.mooncakes' -prune -o -path './vendor' -prune -o \
  -name '*.mbt' -type f -print
```

| Baseline | Current value |
| --- | ---: |
| Repository-owned packages | 17 |
| Production `.mbt` files | 266 |
| Test `.mbt` files | 77 |
| Tracked generated package interfaces | 17 |
| `internal/moonwiki` production / test / total files | 105 / 28 / 133 |
| `ui/rabbita-desk/main` production / test / total files | 103 / 28 / 131 |

Largest repository-owned production files are `ui/rabbita-desk/main/desk_mode_views.mbt` (2,366), `internal/moonwiki/workspace_create_entry_handlers.mbt` (1,287), `ui/rabbita-desk/main/app_update_workspace_results.mbt` (1,240), `ui/rabbita-desk/main/app_update_navigation_actions.mbt` (1,101), and `mooncode/core/runtime_tools.mbt` (1,065). Largest tests are `ui/rabbita-desk/main/app_code_mode_session_wbtest.mbt` (3,110), `internal/moonwiki/moonwiki_request_wbtest.mbt` (2,759), `ui/rabbita-desk/main/app_desk_navigation_wbtest.mbt` (2,319), `mooncode/core/protocol_wbtest.mbt` (1,224), and `ui/rabbita-desk/main/capability_state_wbtest.mbt` (1,074).

### Check/test baseline

Installed toolchain: `moon 0.1.20260629 (3e587ed 2026-06-29)`, with `rr_moon_mod` and `rr_moon_pkg` enabled. One clean timed attempt was made with `time -p` for root native check/test and UI JS check/test. All four stopped during package discovery, before compilation or test execution, because `cmd/main/moon.pkg` contains `pkgtype`, which this installed toolchain reports as `Unexpected key 'pkgtype' found in moon.pkg`. The observed discovery times were 0.00–0.01 seconds and are **not** successful check/test timings. This document does not alter that manifest or claim a passing baseline.

Commands attempted:

```sh
moon check --target native
moon test --target native
(cd ui/rabbita-desk && moon check --target js)
(cd ui/rabbita-desk && moon test --target js)
```

## Current package graph

Every local `vectie/moondesk` edge below comes from a repository-owned `moon.pkg`. External imports are grouped by responsibility after the graph. An arrow means “imports / may call.” No local package cycle exists in the manifest graph.

```text
cmd/main
  -> host, internal/fsx, internal/mooncore, internal/moonwiki,
     internal/pathx, plugin/moongate
host -> core, internal/fsx, internal/pathx
adapters/moonbook -> core
adapters/moonclaw -> core
adapters/moontown -> core
internal/fsx -> internal/pathx
internal/moonfiles -> internal/fsx, internal/pathx
internal/mooncore -> core
internal/mooncode -> internal/mooncore, mooncode/core
internal/moonwiki
  -> adapters/moonbook, core, internal/fsx, internal/moonfiles,
     internal/mooncore, internal/mooncode, internal/pathx
ui/rabbita-desk/main -> core

No local MoonDesk imports: root package, mooncode/core, packapp, plugin/moongate.
```

### Edge classification

An edge can carry more than one concern; classifications describe why the dependency is relevant to Phase 4.

| Class | Current edges / imports | Present responsibility |
| --- | --- | --- |
| Domain DTO | `adapters/* -> core`; `internal/mooncore -> core`; `internal/moonwiki -> core`; `ui/rabbita-desk/main -> core` | Shared desktop routes, workspace/service DTOs, and cross-boundary contracts. |
| Filesystem | `host -> internal/fsx, internal/pathx`; `internal/fsx -> internal/pathx`; `internal/moonfiles -> internal/fsx, internal/pathx`; `internal/moonwiki -> internal/fsx, internal/moonfiles, internal/pathx`; `cmd/main -> internal/fsx, internal/pathx`; plus async/fs and moonlib/fsx imports | Path confinement, file reads/writes, discovery, and workspace operations. |
| HTTP transport | `internal/moonwiki` imports async/http, async/io, async/socket; UI imports rabbita/http; adapters use JSON contracts | Native request routing/response writing and browser HTTP effects. |
| Runtime adapter | `adapters/moonclaw` and `adapters/moontown` import moonlib/moonsuite; `internal/moonwiki -> adapters/moonbook, internal/mooncore, internal/mooncode`; `cmd/main -> host, plugin/moongate`; process/env/sys/time/crypto imports | MoonBook, MoonCode, MoonClaw, MoonTown, host, process, and daemon integration. |
| UI state | `ui/rabbita-desk/main -> core`; same-package model/update/command files | Global shell/workspace/Wiki/Code/Town/Flow/capability state and effects remain one compilation unit. |
| UI rendering | UI imports rabbita, dom, html, svg, js, cmark; same-package `*_views.mbt` files | DOM rendering, Markdown, and surface views. |
| Test helper | package test imports of `moonbitlang/core/test`, `internal/moonfiles` wbtest import of async, and same-package white-box tests | Assertions and access to private state/functions. |

## Ownership findings

- `core` owns public desktop DTOs and is correctly below adapters, host logic, runtime code, and UI. Public concrete desktop types must remain in the package consumers name as `@desk`, rather than migrating into an `internal/*` implementation package.
- `internal/moonwiki` is currently a host facade **and** the owner of workspace filesystem operations, HTTP handlers, review diff calculation, book creation/patterns, portable packaging, service lifecycle, and runtime adapters. Its 105 production files demonstrate the Phase 4 structural concern even though its generated interface is only 66 lines.
- `ui/rabbita-desk/main` combines state, effects, transport commands, and rendering in 103 production files. Its generated interface is 245 lines. Phase 4 requires explicit state contracts before package extraction; this map therefore proposes no UI package split.
- Generated interfaces are tracked one-for-one for all 17 repository-owned packages. They are the review signal for concrete public ownership: a behavior-preserving extraction must add only the intended target API and must not accidentally transfer or expose unrelated desktop/UI types. Current breadth signals include `mooncode/core/pkg.generated.mbti` (1,017 lines), `core/pkg.generated.mbti` (418), UI (245), and `internal/moonwiki` (66).

## Same-package cycles hidden by compilation-unit sharing

These are responsibility cycles, not manifest cycles. They become illegal package cycles if files are moved naively.

1. **Workspace filesystem ↔ HTTP transport.** `review_diff_handlers.mbt` parses an HTTP query, resolves workspace paths and reads files, computes a line diff, and writes JSON. `api_workspace_router.mbt` directly calls that handler. Extracting the whole file would make a review package depend upward on HTTP/workspace facade services while the facade depends downward on review.
2. **Workspace domain creation ↔ filesystem ↔ transport.** `workspace_creation_handlers.mbt` and `workspace_create_entry_handlers.mbt` combine body/JSON handling, workspace DTO lookup, path rules, file mutation, and HTTP error responses. A naive “workspace” move would pull transport down or require callbacks back into `internal/moonwiki`.
3. **UI state/effects ↔ rendering.** View files pattern-match same-package model records and emit messages whose updates issue HTTP effects; update files also encode cross-surface navigation assumptions. Splitting views first would expose broad internal UI concrete types and create pressure for rendering/state mutual imports.
4. **Service lifecycle ↔ route facade.** MoonClaw/MoonTown lifecycle and process helpers share route, JSON, status, filesystem, and daemon helpers in `internal/moonwiki`. Moving routers and lifecycle together would preserve breadth; moving only lifecycle without a typed service boundary would invite a facade callback cycle.

## Intended dependency directions and extraction constraints

```text
UI rendering -> explicit UI state/view models -> core domain DTOs
browser HTTP effects -------------------------> core domain DTOs
native HTTP route facade -> typed domain services -> filesystem/path primitives
native HTTP route facade -> runtime adapters -> external runtimes
cmd/main -> host facade; host facade -> services/adapters; never the reverse
```

Constraints:

1. Lower packages must not import `internal/moonwiki`, `cmd/main`, or UI rendering.
2. HTTP request/connection types remain in the route facade; filesystem access remains in workspace/service owners; pure calculations accept values and return typed values.
3. A package owns every public concrete type its callers construct, inspect, match, or invoke methods on. `core` continues to own public desktop DTOs. An extracted internal package may expose a narrow result type that it semantically owns, but must not become owner of `DeskWorkspace`, route DTOs, or UI model/message types.
4. Extract host-side pure leaves before filesystem services, then typed services before thinning routes. For UI, first define shell/workspace/Wiki/Code/Town/Flow/setup state and message/effect ownership inside the existing package; only then evaluate package boundaries.
5. Each extraction must preserve black-box behavior, add a generated interface for the target package, and avoid unrelated generated-interface changes.

## First extraction proposal: pure review line-diff calculation

**Proposal only; do not implement before independent review.**

| Item | Boundary |
| --- | --- |
| Exact current source owner | Pure blocks in `internal/moonwiki/review_diff_handlers.mbt`: `line_diff_summary`, `review_diff_lines`, `has_line`, and `diff_body_line`. The HTTP handler, `empty_review_diff`, and filesystem-aware `review_base_path` stay in `internal/moonwiki`. |
| Target package | `internal/review` |
| Allowed direction | `internal/moonwiki -> internal/review`. `internal/review` may use MoonBit core string/collection facilities only; it must not import `internal/moonwiki`, HTTP, filesystem/path, `core` desktop DTOs, or runtime adapters. |
| Public ownership | Prefer a narrow `ReviewDiffSummary` owned by `internal/review` with read-only inspection needed by the facade (added, removed, changed, body). Do not expose or relocate `DeskWorkspace`, HTTP, JSON transport, or UI types. JSON assembly remains in `internal/moonwiki`. |
| Exact callers | Production caller is `handle_workspace_review_diff` in the same source file. `api_workspace_router.mbt` calls only the HTTP handler and must not import the new package directly. Repository reference search found no other production caller of `line_diff_summary`. |
| Test boundary | Move the two calculation tests from `review_diff_handlers_wbtest.mbt` to black-box tests of `internal/review`: addition/removal detection and bounded long-line rendering. Retain the existing endpoint contract in `moonwiki_request_wbtest.mbt` as facade integration coverage. |
| Validation commands | With a compatible repository toolchain: `moon check --target native`; targeted `moon test internal/review`; targeted `moon test internal/moonwiki`; full `moon test --target native`; `moon info`; then verify only the intended new `internal/review/pkg.generated.mbti` and deliberate `internal/moonwiki/pkg.generated.mbti` change. UI JS behavior is not touched, but repository gate policy may additionally run its normal UI check/test. |
| Rollback signal | Roll back if the target imports HTTP/filesystem/runtime/UI packages, the facade must expose unrelated private types, endpoint JSON changes, either focused test boundary fails, any unrelated generated interface changes, or a local package cycle appears. |

This is the smallest useful first extraction because the four calculation helpers are deterministic and already isolated behind one production call; two focused tests exist; no filesystem, async, HTTP connection, workspace DTO, runtime, or UI type must cross the new boundary. It creates a real package seam and black-box test boundary while leaving route assembly and product behavior intact. Extracting all of `review_diff_handlers.mbt` would be larger and would violate the desired transport/filesystem/domain direction.

## Review gate

Approval of this document permits only a separately reviewed implementation of the proposal above. It does not mark Phase 4 complete, approve other candidate packages, begin later phases, or authorize UI redesign, behavior changes, speculative hardening, or a broad backlog.
