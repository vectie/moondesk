# Native Library Picker Acceptance

| Field | Value |
| --- | --- |
| Date | 2026-07-27 |
| Platform | macOS arm64 |
| Package | Fresh unsigned local `MoonDesk.app` |
| Status | macOS interaction, persistence, and no-Refresh restart restoration passed |

## Purpose

This record closes the macOS portion of the real packaged-app library-picker
gate with evidence from the application users actually run. It distinguishes
static contract proof, native interaction, host validation, persistence, and
restart restoration so that one passing layer cannot hide a failure in another.

It does not claim signing, notarization, clean-machine installation, another
desktop platform or the broader Phase 9 distribution gate.

## Phase-by-phase acceptance

### Phase A — Contract and ownership audit

Acceptance requirements:

1. The packaged manifest exposes `fileDialog.openDirectory`.
2. The window has only the file-dialog permission needed by the picker.
3. The UI calls the native bridge and distinguishes selection, cancellation,
   bridge failure, and host rejection.
4. The host validates and activates the selected root.
5. The stable bootstrap root owns the saved preference.
6. Cancellation and rejection do not replace the active library.

Result: passed by source inspection, manifest inspection, and focused tests.

### Phase B — Fresh isolated package

The acceptance package was built from a freshly generated production UI into
an isolated `_build/native-picker-gate` output. The tracked `dist` directory was
not used as a proxy for current source.

Strict package verification passed with:

- 17 registered synchronous bridge routes
- 0 asynchronous bridge routes
- 14/14 bundle verification checks
- native launch-session preparation
- bundled runtime and sidecar executables
- local live bundle-check and live-build

This phase caught a validation-process problem: a package assembled from a
restored, older `dist` can be structurally valid while omitting current UI
behavior. Acceptance packaging now builds current source into a separate output
directory before bundling.

### Phase C — Bridge dispatch recovery

Initial symptom:

- pressing **Change library folder** changed the status to “Choose a MoonBook
  library folder”
- no chooser appeared
- no native picker process was launched
- the bridge promise never resolved

Root cause:

- file-dialog routes were declared and registered as asynchronous
- the macOS deferred bridge drain executed the synchronous dispatch path
- the asynchronous handler was therefore unreachable

Fix:

- declare all four modal file-dialog commands as synchronous
- keep their `MainThread` affinity
- register synchronous generic and native handlers
- remove the artificial async yield and unused async dependency
- add route-mode and selected/cancelled packet tests

Evidence:

- file-dialog tests: 7/7
- bundled runtime tests: 23/23
- macOS runtime tests: 21/21
- complete Lepusa native suite: 543/543
- rebuilt manifest: 17 synchronous routes, 0 asynchronous routes

### Phase D — App-owned native panel

The first recovered backend launched the macOS chooser through a separate
script process. A human could see that panel, but the application’s own
accessibility surface blocked while it was open. That failed the product-level
gate: a native control must remain operable through the owning application,
including assistive and automated interaction.

Fix:

- replace the script-process backend on macOS with an app-owned
  `NSOpenPanel`/`NSSavePanel`
- invoke the Cocoa panel on the registered main thread
- keep open-file, multi-file, directory, save-file, initial-directory, and
  suggested-name behavior
- collect selected URLs directly from the native panel

Evidence:

- the application accessibility tree exposes `dialog Open` with
  `ID: open-panel`
- the tree exposes sidebar locations, folder contents, path navigation,
  **New Folder**, **Cancel**, and **Open**
- the panel opens and closes without freezing the application accessibility
  surface

Local screenshot:
`_build/native-picker-gate/evidence/02-app-owned-native-panel.jpeg`.

### Phase E — Cancellation

Journey:

1. Open Home.
2. Expand **Storage and services**.
3. Choose **Change library folder**.
4. Press **Cancel** in the native panel.

Expected and observed:

- status becomes `Library selection cancelled`
- the active library remains the application-data workspace
- no new preference is committed
- the application remains interactive

Local screenshot:
`_build/native-picker-gate/evidence/03-cancel-preserves-library.jpeg`.

### Phase F — Invalid folder rejection

Fixture:
`_build/native-picker-gate/fixtures/invalid-book`, which is one MoonBook rather
than a library containing a `books` directory.

Initial symptom:

- the host returned `Choose a library folder, not one MoonBook`
- the UI replaced it with `Could not select the library`

Root cause:

- the generic JSON expectation tried to decode every response as successful
  workspace metadata
- when decoding the structured error body failed, the generic helper discarded
  the host’s `message`

Fix:

- decode the response as `Json`
- first attempt the successful metadata contract
- on mismatch, preserve the host’s structured `message`
- retain the generic fallback only for transport or malformed-body failure

Expected and observed after repair:

- visible status is exactly `Choose a library folder, not one MoonBook`
- the prior library remains active

Focused response-decoding and state-preservation tests pass. Local screenshot:
`_build/native-picker-gate/evidence/05-precise-invalid-library-rejection.jpeg`.

### Phase G — Valid folder activation

Fixture:
`_build/native-picker-gate/fixtures/selected-library`.

Journey:

1. Open the native panel.
2. Use the standard macOS path sheet.
3. Select the fixture library.
4. Press **Open**.

Expected and observed:

- active root becomes the canonical fixture path
- library path becomes `<root>/books`
- the Home list contains one ready MoonBook
- `Native Picker Acceptance` is visible and selectable
- subsequent `/api/desktop/library` requests report the new active root

Local screenshot:
`_build/native-picker-gate/evidence/06-valid-library-selected.jpeg`.

### Phase H — Persistence and restart restoration

Persistence evidence passed:

- the stable preference file under the application-data bootstrap root contains
  the canonical fixture path
- the live library API reports the same root, `workspace_count: 1`, and the
  ready fixture book

Cold-start recovery also needed repair. A packaged WebView could issue its
first HTTP batch before the supervised localhost service accepted requests,
mark itself bootstrapped, and then wait forever for a manual **Refresh**.
Metadata failure now schedules a retry of the data-fetch batch only while no
established root exists. One-time observers and import polling are not
duplicated. An established session does not turn an ordinary refresh failure
into a bootstrap loop. The initial bootstrap message is deferred until after
the UI runtime has mounted its root cell, so the startup command batch is not
started during pre-mount initialization. Four focused bootstrap tests pass.

The visual restart step passed:

1. stop the isolated package
2. relaunch the same package without pressing **Refresh**
3. observe `Native Picker Acceptance` and the saved root
4. retain a final screenshot

The first rendered state contained the saved book and did not contain
“Connecting to your library.” The live health and library APIs reported the
same canonical root, `workspace_count: 1`, and the ready fixture book.

Local screenshot:
`_build/native-picker-gate/evidence/07-restored-after-relaunch.jpeg`.

### Phase I — Regression and closeout gate

Current results:

| Scope | Result |
| --- | --- |
| Lepusa file-dialog tests | 7/7 |
| Lepusa bundled runtime tests | 23/23 |
| Lepusa macOS runtime tests | 21/21 |
| Lepusa complete native suite | 543/543 |
| MoonDesk native suite | 230/230 |
| MoonDesk UI suite | 319/319 |
| Localization suite | 3/3 |
| Library-selection focused tests | 7/7 |
| Bootstrap focused tests | 4/4 |
| Fresh production UI build | Passed |
| Strict macOS package build | Passed |

Generated-interface review found no new public picker or bootstrap API.
Formatting and whitespace validation pass. The macOS transcript is complete
for this unsigned local acceptance slice.

## Defect summary

| Defect | User impact | Resolution |
| --- | --- | --- |
| Async file-dialog routes were sync-drained | Picker did not open; request hung | Synchronous main-thread modal contract |
| Picker ran in a separate script process | Owning app was inaccessible while panel was open | App-owned Cocoa panel |
| Host rejection detail was discarded | User saw an unhelpful generic error | Structured error-message preservation |
| Acceptance package could use stale `dist` | Structurally valid package omitted current behavior | Isolated current-source production build |
| Cold-start request raced sidecar readiness | App could remain on “Connecting” until manual refresh | Defer initial bootstrap until mount and retry only the startup data-fetch batch before an established root |

## Remaining boundary

The macOS picker interaction is proven through valid selection and relaunch
restoration. The following remain outside this slice:

- equivalent interaction on every other supported desktop platform
- signed and notarized distribution
- clean-machine installation
- update delivery and rollback
- complete keyboard, text-zoom, focus-order, and screen-reader qualification
