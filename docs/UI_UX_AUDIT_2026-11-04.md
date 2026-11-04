# UI/UX audit — 2026-11-04

Applied the Working style and UI/UX sections of `AGENTS.md`, using the installed
MoonDesk frontend/backend and a Vite preview of the changes.

## Findings and changes

| Surface | Finding | Result |
| --- | --- | --- |
| Desk | `App` and `Apps` both appeared as 应用 | Canonical `app` now reads 主应用; canonical `apps` remains 应用. Real paths and authored filenames are unchanged. |
| Book file picker | Repeated eyebrow, two-part empty instructions, drag instructions and copy disclaimer | One title, search, recent paths and an Open path action. The whole dialog accepts workspace drops. Advanced file actions remain in the menu; focused document/workflow pickers omit the unrelated Synthesis jump. |
| Search states | Ordinary loading and emptiness repeated explanatory paragraphs | One status line for ordinary states; failures retain recovery guidance and technical details. Recent path labels are explicitly authored content. |
| Results | Whole raw requests expanded in every card | Two-line disclosure previews; full source text remains available on expansion. Refresh uses the shared icon treatment. Loading/errors no longer appear together with a successful empty result. |
| Task schedules | Empty state sent users to an invisible calendar elsewhere | Concise empty state with a working View results action in the same drawer. Open last run is available only with a conversation ID. |
| Code schedules | Task name stretched to match a textarea; save actions fell below the visible panel | Name and request get their own rows; model and start time share a row. During editing, the form takes the panel and the calendar/list returns on Cancel. Actions align right; timing guidance stays in a disclosure. |
| Code knowledge | Empty library reserved a blank source column; empty actions still submitted | Empty library uses the form width. Source/retrieval explanations move into disclosures. Extract, save and search enable independently when their matching fields contain content. |
| Code composer | Routine daemon port message appeared in English beneath the input | Healthy daemon status is omitted from the composer; failures remain visible. |
| Native attached editors | Schedule creation closed its drawer when a render temporarily returned focus to the workspace | Schedule and coding-setup editors stay open during focus reconciliation. Explicit outside clicks, close controls and Escape still dismiss them. |
| Flow | Empty canvas retained space for removed controls below it | Empty canvas fills the available working area. Existing task/file actions stay together. |
| Packs | Compact app cards and collaboration status retained the previous pass's arrangement | Rechecked the app list and collaboration drawer; no new change to ownership or execution behavior. |

## Inspection and validation

- Inspected Desk, Book, Code, Flow and Packs, including file selection, results,
  task schedules, code schedule create/cancel, setup knowledge and collaboration.
- Checked Chinese labels and relevant English catalog parity; documents,
  filenames, conversation titles and provider/model identifiers remain content.
- Focused JavaScript checks cover localization boundaries, result projection,
  schedules, knowledge action prerequisites and local file pickers. The owner
  integration test is opt-in and is not counted as passing when skipped.
- MoonBit checks cover Desk aliases, Book context, Flow states and code
  schedules. `moon info`, `moon fmt` and `moon check --target js` completed.
- Existing generated native bridge interface changes predate this pass; this
  UI pass introduces no public interface change.

This pass does not submit a model request, save a knowledge source, enable an
existing schedule, publish an app, or claim to qualify every live operator or
every possible screen state. Packaging and visual evidence are recorded below
after installation.

## Installed result

- Installed the production frontend in `/Applications/MoonDesk.app`, verified
  the ad hoc signature and compared its entry HTML with the built distribution.
  Previous resources are in `_build/ui-ux-audit-20261104/previous-assets`.
- Confirmed the native schedule editor stays open when New is clicked, focuses
  the name input and returns to the schedule list on Cancel. Captured
  `docs/design/ui-ux-audit-20261104/schedule-packaged.png`.
- Confirmed the native file picker contains one title/status and its local
  controls, and closes through Escape. Captured `file-picker-packaged.png` in
  the same directory.
- Verified results expand to show their complete text and the empty schedule
  View results button opens the Results tab in the same drawer against the
  installed backend. Captured `results-installed.png`.
- 52 focused MoonBit tests passed. The initial JavaScript selection passed 44
  tests and skipped one opt-in owner integration test. Popup/keyboard/setup
  checks passed (10 tests, including five setup tests already in that selection).
  The schedule regression and result/calendar checks passed again after the
  native focus fix. No live recurring run was triggered for this UI audit.

Updated `../moonvis/docs/ICON_LANGUAGE.md` and recorded preview, packaging and
native focus pitfalls in the repository's `HANDOFF.md`.
