# Visual alignment and less explanatory chrome

The previous UI pass did not fully align the working surfaces. This pass
inspected Desk, Book, Code, Flow and Packs against the existing MoonVis rules,
then removed concrete duplicate content and corrected component geometry.

## Changes

| Surface | Change |
| --- | --- |
| Code | Chat header and panel toolbar share a 40px baseline. Active panel labels retain their width; utilities use 32px targets. |
| Compare | Removed the repeated pane title, introductory paragraph, infrastructure badge and idle footnote. Mode spans the form; models and approaches occupy matching A/B columns. Fields share 13px text, padding and 6px corners, including native WebKit selects. |
| Suggestions | Removed the section heading and Show/Hide text. Chips share a row with a named collapse icon; Chinese labels remain on one line. |
| Composer status | Routine model counts and workspace-ready messages no longer sit below the composer. |
| Book | Removed the empty-chat instruction and permanent drag-instruction strip. The entire composer accepts workspace-file drops; attachment selection and accessible instructions remain available. |
| Flow | One empty state, with task/file actions together. Empty canvases omit zoom controls. Removed repeated book context, revision explanation and duplicate run status. Review is represented separately from active execution. |
| Flow details | Canvas help, step explanation and routine evidence are disclosed locally. Setup errors, result qualification and execution consequences remain visible. |
| Packs | Removed duplicate installed/available totals from the toolbar. |
| Collaboration | Removed the descriptive preamble, record total and repeated footer. Read-only and Refresh occupy a compact row; member names and roles align without nested cards. The uninitialized state no longer repeats an English backend sentence. |

Actual filenames, task titles and authored content are unchanged. The shared
guidance is recorded in `../moonvis/docs/ICON_LANGUAGE.md` under “Let arrangement
explain the interface.”

## Verification

- `moon check --target js`, `moon info --target js`, `moon fmt`.
- 70 focused MoonBit tests passed: Flow listing/empty/error states, review
  outcome, owner evidence, single-step controls, Packs and Book context/drop.
- 35 JavaScript tests passed: locale boundaries, coding comparison behavior
  and suggestion generation.
- Production frontend built; installed resources updated in
  `/Applications/MoonDesk.app`; ad hoc signature verified.
- Inspected the actual packaged Book composer, Flow empty state, Packs
  collaboration drawer and Code comparison. Browser geometry confirmed both
  Code header sections are 40px high and the selected panel label is unclipped.
- Suggestion collapse/reopen verified through UI. Existing chats were opened
  for inspection; no new execution or comparison was submitted.

Screenshots are in `docs/design/visual-alignment-20261028/`. This pass verifies
the named desktop surfaces in Chinese, plus locale regression checks. It does
not claim every possible dialog, theme or narrow-screen state is pixel-perfect.

## Second round — secondary surfaces

Reviewed Code setup, task creation, Book review/sources/history, the empty Flow
editor entry, and Packs Studio against the running desktop app.

| Surface | Change |
| --- | --- |
| Code setup | Removed repetitive introductions. Scope remains in an accessible information disclosure. Empty skills use a single action row. Model and connection forms use aligned 32px controls and a compact action at the bottom right. Repeated edit, remove, use and test actions use named icons. |
| Task creation | Header title and book context share a baseline. Code offers coding presets; Book offers document recipes. Changing the working view retains the unsent prompt and keyboard focus. |
| Book | Header utilities share a quiet transparent treatment. Empty document view offers one file-selection action. Review has one empty message, no empty filter row, a local action toolbar and an aligned assignment/submit row. Sources and history omit repeated introductory paragraphs. |
| Flow | The edit disclosure exists only when this book has a source graph to edit. It no longer opens an empty area. |
| Packs Studio | Replaced four explanatory cards with compact disclosure rows. Descriptions and commands remain available on expansion. |
| Initial loading | One localized status line and restrained progress indicator; removed the title card, brand repetition and component list. Reduced-motion preference is respected. |

Validation: 55 focused MoonBit checks and 74 JavaScript checks passed. The latter
includes a regression for changing task type without losing the draft. The
shared locale suite checks text, tooltips, submitted option values and authored
content boundaries. No files were renamed, no model task was sent, and no review
discussion or settings record was saved during visual inspection.

For future UI passes, `MOONDESK_API_ORIGIN` can point the existing Vite development
server at the installed backend (4201); production packaging retains the same
API routes. This allows visual iteration before the production bundle is built.

The second-round production build was installed into `/Applications/MoonDesk.app`
and its signature verified. Native inspection confirmed the model form, Book
empty-document action, Packs disclosure expansion, Flow empty state and task
picker. Screenshots: `setup-round2-packaged.png`, `packs-round2-packaged.png`
and `task-round2-packaged.png` in the same evidence directory. Review and source
forms were checked in the browser against the installed backend.
