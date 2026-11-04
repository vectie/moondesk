# Code panels and Flow recovery — 2026-11-04

Scope: the installed `/Applications/MoonDesk.app`, its served frontend on port
4201, and focused state/interaction tests. Preserve authored paths and filenames.

## Repairs

| Surface | Finding | Change |
| --- | --- | --- |
| Files | Empty editor offered Open and claimed Saved/clean diagnostics. | Open requires a path; Saved requires loaded content; diagnostics remain blank while unavailable. |
| File tabs | System labels were English, and path labels could enter automatic translation. | Localize tab actions and Markdown link tools; explicitly preserve authored path labels and tooltips. |
| Changes | Non-Git books rendered an empty panel. A translated loading node could retain its old text after completion. | Show a concise non-Git/unloaded state with refresh; localize state text before reconciliation. |
| Workbench | Native panel controls intermittently retained an unavailable state on entry. Selection attachment had no prerequisite. | Explicitly keep local panel controls enabled, with stable toolbar button roles, direct activation and pressed/expanded states; preserve keyboard switching and disable attachment without a real selection. |
| Preview | Blank preview offered reload, external open, element selection and evidence preparation. External open used an unsubmitted address draft. | Actions follow the opened page; hide unused stage/evidence; external open uses committed navigation. |
| Preview layout | Repeated isolation explanation and inconsistent utility controls. | Shared icons, heights/corners, wrapping toolbar; isolation details in a local disclosure. |
| Terminal | Loading, empty and failed listing overlapped; no explicit refresh; search/selection actions were usable without inputs. | Separate states, add refresh and recovery, enforce input prerequisites, localize runtime labels, preserve actual terminal names/output. |
| Flow load | Failed composition retrieval looked like a successfully empty workflow. | Distinct failure/stale banner, local Retry and disclosed technical detail; preserve the prior graph. |
| Flow execution | Pending actions retained ordinary labels and allowed item switching. | Show running/checking status and retain the pending item. |
| Flow result | Refresh invalidated an open, verified result solely because the listing generation advanced. | Retain its viewer for the same exact saved artifact; close it if the refreshed artifact changes. Review is reopened separately. |

## Verification

- Focused JavaScript tests: **50 passed**. Includes preview navigation/action
  prerequisites; terminal 503 failure → refresh → successful empty recovery;
  workbench direct activation; unavailable editor diagnostics; Markdown link
  editing; locale parity and authored-content protection.
- Focused MoonBit tests: **45 passed**. Source editor, repository states, Flow
  loading/retry, single-step states and retained-result refresh/identity changes.
- JS `moon info`, `moon fmt`, `moon check`, release frontend build and focused
  whitespace checks completed. Existing unrelated unused declarations remain.
- The optional compiled-UI retained-response fixture is unconfigured; it does
  not replace the actual application checks below.

## Actual application checks

- Opened `wiki/index.md` in native Code without changing it; verified empty
  file action prerequisites and local panel switching.
- On final first entry, all five panel controls were enabled. Clicked Files,
  Changes and Preview directly and used the right-arrow key to switch from
  Files to Changes. The non-Git message replaced loading correctly.
- Created a test PTY through native Terminal and ran read-only `pwd`. It
  returned the installed library's `books/coding` directory. Closed that test
  terminal afterwards.
- Inspected blank Preview: unavailable actions are disabled, and isolation
  information stays in a disclosure.
- Selected the existing isolated library
  `/Users/kq/moonsuite/qualification/desktop-flow-20261022/workspace` through
  the application's folder chooser. Restored its saved `desktop-flow-check-r1`
  execution and opened verified `operation-receipt.json` with outcome `applied`.
- Checked the real native Flow window at approximately 550 CSS pixels wide.
  Run actions, disclosures and the retained-result entry remain reachable.
- Checked native Code at the same narrow width, then restored the normal
  window. File tabs, the path/actions row and editor remain usable.
- Reopened the final installed app, inspected the same result and refreshed
  Flow. The verified result viewer remained open with the same saved artifact.
- Restored the original 44-book library after the isolated Flow check.

The final frontend was copied into the installed app, its `index.html` matched
the build, and the ad-hoc application signature passed deep strict verification.

This pass reopens an existing reference-operation execution. It does not claim
a new external-provider execution, production qualification, physical execution,
or approval of its retained result. Error/retry fault injection is covered by
the focused state and runtime tests; the user library is not deliberately broken.

Evidence: `docs/design/ui-code-flow-20261104/`.
