# Desk User-Journey E2E Report - 2026-07-10

## Scope

Executed the methodology in
[DESK_MODE_USER_JOURNEY_E2E.md](DESK_MODE_USER_JOURNEY_E2E.md) against Desk at
Git revision `6cd3450d` plus the Desk fixes identified during this run.

Environment:

- macOS 26.2
- MoonBit `0.1.20260629`
- Node.js `22.22.1`
- built Rabbita production UI
- real Moondesk native host and temporary MoonSuite roots
- headless Chrome CDP plus the Codex in-app browser for restart observation
- native Lepusa/WKWebView bundle verification

## Result

All P0 journeys are **Achieved**. No P1 journey is Blocked. J12 is **Achieved
with friction** because strict release verification requires signing that is not
configured in this development environment, and the browser-side 300-row render
target does not yet have a harness-native timing marker.

| Journey | Rating | User result and evidence |
| --- | --- | --- |
| J01 Orientation | Achieved | Populated first viewport identifies MoonBook, folder, files, and primary actions; internal paths/services/layers remain closed. DOM leakage assertions and desktop screenshots passed. |
| J02 First MoonBook | Achieved | Empty library explains the state, creates a MoonBook under `books`, selects it, and opens starter content. Empty and post-create browser/file assertions passed. |
| J03 Find and navigate | Achieved | Back/Forward/Up/Home, breadcrumbs, outline, search, sort, density, typed path, pointer, and keyboard navigation stay synchronized. Browser and state tests passed. |
| J04 Inspect and continue | Achieved | Selection exposes type, modified, size, access, preview, Rename, Reveal, and Wiki handoff; raw path/source area stay closed. Browser disclosure and preview assertions passed. |
| J05 Create/import | Achieved | Folder/note creation and browser-originated file/folder/MoonBook import persist exact scoped content and skip VCS/build metadata. API, browser, and filesystem assertions passed. |
| J06 Organize | Achieved | Rename, duplicate, move, copy, cut, and paste refresh list/selection and preserve bytes with conflict-safe behavior. API/browser/filesystem assertions passed. |
| J07 Batch work | Achieved | Mouse and keyboard multi-selection produce correct counts, aggregate details, and multi-path mutations. State, API, and browser assertions passed. |
| J08 Quick access/isolation | Achieved | Favorites/Recent remain reachable; workspace switching clears stale directory, preview, operation status, and same-book clipboard after protecting unsaved drafts. Regression tests and browser switch passed. |
| J09 Trash/restore | Achieved | Selected items move to scoped reversible trash and restore to the receipt path without overwrite. API, receipt, browser, and filesystem assertions passed. |
| J10 Error/security recovery | Achieved | Traversal, absolute paths, generated/system paths, duplicate targets, cross-book access, and source-root writes are rejected without outside effects. Offline Refresh now gives a local plain-language retry message. |
| J11 Responsive/keyboard | Achieved | Focus/listbox semantics and live feedback are present. Desktop, small desktop, tablet, and phone have no pane overlap or document overflow; tablet retains inspector; phone starts with MoonBook/file browser and Name/Type fit without horizontal scrolling. |
| J12 Scale/restart/native | Achieved with friction | 300-entry API returned in 35 ms and browser rendered all 300 rows including `item-300.txt`. Stop/Refresh/restart preserved cached context and recovered on retry. Non-strict native live smoke passed; strict gate stopped only at missing signing configuration. |

## Defects Found And Fixed

### 1. Unsaved Draft Test Did Not Match Current Safety Contract

The Desk workspace-switch test expected an immediate switch while a Markdown
draft was active. Current behavior correctly protects the draft.

Fix: assert that the switch is queued, the draft is retained, and confirmation
then clears stale Desk state and loads the target MoonBook.

### 2. Workspace Switch Leaked Transient State

After switching MoonBooks, status text and clipboard scope from the previous
MoonBook could remain in the new workspace.

Fix: clear create/rename/move/copy/path/trash status, selection inputs, and the
same-book clipboard at the confirmed workspace boundary.

### 3. Tablet Removed The Inspector

At `1024x768`, CSS hid selection details with no replacement control.

Fix: retain the library at left and stack the inspector below the browser in the
right column.

### 4. Phone Put The Library Before The User's Task

At `390x844`, the complete library and Quick Access consumed the first viewport;
the active folder and files appeared far below it.

Fix: order browser, selection details, then library on phones; include the active
MoonBook above the folder; reduce the phone table to Name and Type; assert no
internal table overflow.

### 5. Operation Feedback Was Visual Only

Desk success/error text had no live-region semantics.

Fix: non-idle operation feedback now uses `role="status"` and
`aria-live="polite"`; the browser E2E asserts both attributes.

### 6. Offline Refresh Had No Primary Recovery Message

When the host stopped, Refresh kept cached rows but did not tell the user why no
new data appeared.

Fix: show `Refreshing folder...`, then a plain-language connection/retry message
on failure, retain cached context, and clear the message after a successful
post-restart Refresh.

## Commands And Evidence

Passing gates:

```sh
moon check
moon test                                  # 528/528 native
cd ui/rabbita-desk && moon test            # 177/177 JS, including 73/73 Desk
npm --prefix ui/rabbita-desk run build
scripts/desk_mode_api_smoke.sh
scripts/desk_mode_browser_smoke.sh all
```

Latest browser artifacts were generated under:

```text
/var/folders/_j/kcn3f7817s71gymnv_nnn1bm0000gn/T/
  moondesk-desk-browser.KVyskI/full/screenshots/
  moondesk-desk-browser.KVyskI/empty/screenshots/
```

Native evidence:

- Lepusa non-strict populated live smoke: passed.
- WKWebView dependency, native launch session, bridge routes, bundle contents,
  runtime manifest, bundled sidecar, and package readiness: passed.
- Strict release gate: not passed because macOS signing is not configured.

Reliability evidence:

- 300-entry API: HTTP 200, 106,503-byte response, 35 ms.
- Browser: 300 rendered rows and `item-300.txt` present.
- Restart: cached rows/location retained during failure; visible polite retry
  message shown; same-port restart plus Refresh cleared the message and restored
  live content without duplicate rows.

## Residual Risks

- Add an in-page timing marker around directory request-to-render completion so
  the 2-second 300-row UI target can be measured without browser-control latency.
- Configure a development/release signing identity before treating strict Lepusa
  release readiness as passed.
- Run a screen-reader session on VoiceOver for announcement phrasing and rotor
  order; semantic/live-region automation passed, but assistive-technology audio
  output was not exercised.
- Add reviewed pixel-diff baselines after the responsive hierarchy is accepted;
  this run used screenshot inspection plus geometric/overflow assertions.
