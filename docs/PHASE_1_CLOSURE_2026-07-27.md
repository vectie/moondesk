# Phase 1 Closure

| Field | Value |
| --- | --- |
| Phase | 1 — Simplify the product story and first-run experience |
| Status | Complete locally |
| Closed | 2026-07-27 |
| Scope | Product clarity, first run, capability explanation, and first useful task |

## Closure decision

Phase 1 passes its user-facing exit gate. A new user can choose a library,
create or import a MoonBook, see the selected book and current destination,
edit durable Wiki content, use Code when available, and understand or recover
from unavailable optional capabilities without opening repository
documentation.

The phase closes against its declared outcome and exit gate. Exhaustive
localization, responsive-state, manual assistive-technology, packaged-native
input, cross-platform packaging, signing, installation, update, and soak
matrices remain valuable, but they belong to Phases 7 and 8 rather than the
Phase 1 product-clarity gate.

## Exit-gate evidence

| Exit criterion | Evidence |
| --- | --- |
| Identify where they are | The primary shell exposes Desk, Wiki, Code, Flow, and Packs with one selected destination. Requests, Runs, Review, and Publish are named Wiki tabs. Desktop and compact navigation tests pass. |
| Identify the selected book | The title bar, selected MoonBook row, URL workspace identity, and rendered workspace agree in the one/many-book keyboard matrix and clean-workspace journey. |
| Identify the primary action | Cold-start states expose one state-owned action: choose a library, create/import a MoonBook, refresh, or continue into the selected book. |
| Create or import a book | The clean-workspace browser journey creates a MoonBook. Folder, archive, and path import implementations have focused UI/update tests and a populated browser import journey. |
| Edit and save durable content | The clean-workspace journey creates and saves a Wiki note, survives a hard reload, restarts the host, and verifies the saved file bytes. |
| Understand unavailable Code or Requests features | The rendered capability journey proves all six structured availability states for Code and Requests with ordinary-language titles, explanations, and allowed actions. Raw diagnostics remain under Technical details. |
| Recover from setup failure without repository documentation | Misconfigured and temporarily unavailable states expose Review setup/configuration or Retry actions in the product UI. Capability actions and keyboard reachability are covered by focused tests and the rendered browser journey. |

## Accepted navigation

The five primary destinations are:

1. Desk
2. Wiki
3. Code
4. Flow
5. Packs

Wiki contains Pages, Requests, Runs, Review, and Publish as second-level tabs.
Existing activity route values remain compatible with saved links.

## Closure validation

The closure iteration ran:

```text
scripts/desk_mode_browser_smoke.sh quickstart
scripts/desk_mode_browser_smoke.sh capability
scripts/desk_mode_browser_smoke.sh accessibility
scripts/desk_mode_browser_smoke.sh screen-reader
sh scripts/validate.sh fast
npm --prefix ui/rabbita-desk run test:i18n
npm --prefix ui/rabbita-desk run build
```

The clean-workspace and capability journeys pass. The shared-shell
accessibility and screen-reader browser scenarios pass. Native and UI test
counts are recorded in `docs/STATUS.md`.

## Deferred to owning phases

- Phase 2 owns retained remote CI and preview-tag evidence.
- Phase 7 owns exhaustive localization, reduced-motion, responsive-state,
  page-level keyboard, and focused manual assistive-technology matrices.
- Phase 8 owns other-platform packaged picker proof, packaged-native keyboard
  behavior, signing, installation, update, rollback, and soak evidence.

These are not Phase 1 blockers and must not reopen Phase 1 unless the
first-run or first-use product contract regresses.
