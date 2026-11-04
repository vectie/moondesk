# Packaged app: states and narrow windows — 2026-11-04

Continued the audit in the installed MoonDesk app, resizing its real native
window to approximately 725 and 425 CSS pixels wide. Used the same shared
typography, control, corner and icon rules as the prior passes.

## Findings and changes

| Surface | Finding | Change |
| --- | --- | --- |
| Book preview | A missing Markdown file stayed on “Opening file…” after its request failed. Office failures could fall back to “Ready to open.” | Show the actual preview failure, local Retry and optional technical details. Retained previews remain visible with their stale status. Markdown Edit requires loaded content. |
| Empty Book | Export appeared without any file, chat or context; document selection appeared twice. | Empty work omits Export and uses one central document picker. Existing files, including Markdown, and conversations keep Export. |
| Coding setup | An initial failure left “Loading setup…” visible. Refresh could retain the old error styling. | Explicit loading, failure and recovery states; refresh is unavailable while loading, clears stale failure on success and preserves drafts. Restored drafts never inherit an abandoned in-flight load. |
| Collaboration | An unchanged successful payload did not redraw after an error. Switching channels could show the old channel’s empty state or miss its new request. | Refresh clears stale errors, distinguishes pending from successful emptiness, and follows the selected channel after an earlier request finishes. |
| Comparison | A blank goal could submit; narrow A/B fields stayed side by side. | Run requires meaningful goal text and remains unavailable while starting. Draft and focus are preserved; narrow fields stack. |
| Specialist dialog | Empty creation remained enabled. | Creation follows required name, purpose, example and Book selection. Typing updates availability without rerendering the inputs; keyboard focus skips disabled actions. |
| Narrow shell | Current-destination accessibility label remained English in Chinese mode. | Compose the label from localized system fragments. |
| Narrow forms | Calendar columns and long attachment labels crowded actions. | Stack calendar/comparison fields below 560px; allow long attachment paths and channel inputs to wrap without squeezing action buttons. |
| Background updates | Code polling rebuilt open calendar/room views, resetting form scroll and focus. | Retain the local tool view for the same book/document and restore its scroll/focus during shell redraws, without repeating its initial load. |

## Verification

- Inspected the actual app’s Book, Code, Flow, Packs, file picker, preferences
  and specialist dialog in narrow windows. Verified local navigation and
  closing dialogs without creating user data.
- Reproduced missing-file loading/failure through the UI against the installed
  backend. Verified Retry preserves the current book/path and choosing a valid
  file restores its content.
- 115 focused JavaScript tests passed, including setup failure/retry, room
  failure/recovery, creation prerequisites, comparison drafts and localization.
- 65 focused MoonBit tests passed; `moon info --target js`, `moon fmt` and
  `moon check --target js` completed. No new public interface change.
- Setup and collaboration network failures were exercised through deterministic
  runtime tests. The live backend was not stopped to manufacture an outage.
- No collaboration messages, calendar events, model requests or files were
  created. No provider credentials or user-authored content were changed.

## Installed result

- Installed the production frontend into `/Applications/MoonDesk.app`, verified
  its ad hoc signature and matched its entry HTML to the production build.
- Previous assets are in `_build/ui-states-20261104/previous-assets`.
- Final screenshots are under `docs/design/ui-states-20261104/`.
- Native 425px inspection confirmed one-column comparison/calendar fields,
  localized collapsed navigation, disabled empty submission and reachable
  calendar footer actions after scrolling.
- With the final view-retention fix installed, the native calendar stayed at
  its footer across subsequent inspection/background updates; Cancel returned
  to its empty list. Closed the test form and restored the original window size.
