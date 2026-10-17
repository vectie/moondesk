# Spreadsheet-driven creator tasks

This workflow reuses a saved single-stage or composed creator with a task form
for rows from a local spreadsheet export. It adds explicit column mapping and
row-level inspection to the manual one-task form from R582. It does not revise,
fork, schedule, or execute the creator.

To preserve the batch across reload, use the explicit local
[task checkpoint workflow](SPECIALIST_TASK_CHECKPOINTS.md). It saves original
CSV text, mapping and applied corrections to a separate file, then requires the
exact unchanged saved creator and fresh inspection/selection on restore. The
ordinary in-page and saved-creator lifecycle described below stays the same.

## Complete the workflow

1. Export the spreadsheet as **UTF-8 comma-separated CSV**, with one header row.
   Open **Packs → Agents → Build your specialist** and choose a saved creator
   that has a task template, for example `Compare {{topic}} for {{audience}}`.
   Save a newly created or revised definition before importing.
2. Under **Use saved creator with spreadsheet rows**, use **Import local CSV**.
   Choose a file of at most 512 KiB, 32 columns and 100 task rows. Imported data
   stays in this page session. No file is uploaded and no task is submitted.
3. Explicitly map each named template input to a CSV column. Columns are shown
   with their ordinal and original header; fields are never guessed. A column
   can supply more than one template input when that is intentional.
4. Choose **Inspect CSV tasks**. Expand each row to inspect its exact filled task
   or correction errors. Empty required values, wrong-width rows, overlong inputs
   and oversized tasks/briefs remain visible and cannot be selected. Use **Edit
   task inputs for CSV row N** to correct that task's mapped values locally,
   following the workflow below. Structural cell-count errors still require
   correcting the source spreadsheet and reimporting it.
5. Choose **Select CSV row N** for one ready row. Review the **Exact brief**,
   including creator revision, Book/version, reference paths, variant lineage
   and composed stage snapshots. Then choose **Prepare selected CSV task in chat**.
6. Desk revalidates the Book and uses the existing guarded ordinary chat bridge.
   Review the staged brief and use ordinary **Send** in chat to submit that task.
   Preparation itself records no execution or completion.
7. Return to **Build your specialist** without selecting a different creator.
   The batch, mappings, inspected rows and selection remain available. Select
   another ready row, review its brief, and prepare it individually. Finish or
   clear the previous chat draft before preparing another task.

## Correct one imported task

1. After inspection, choose **Edit task inputs for CSV row N** for a row with
   the correct number of cells. Review each named input's original column and
   imported value, then edit only the values that need to change. You can also
   adapt a valid row to a one-off task without changing the spreadsheet.
2. Choose **Apply row corrections**. Desk validates the whole task and its full
   brief again. Blank/NUL/overlong values, oversized filled tasks, and oversized
   complete briefs keep the editor open with the error and leave previously
   applied values unchanged. No preparation happens on Apply.
3. Expand the corrected row to compare original and task values. Choose
   **Select CSV row N**, review its refreshed **Exact brief**, then **Prepare
   selected CSV task in chat**. Ordinary Send remains separate. Repeated Apply
   or Prepare controls cannot prepare the task twice while a request is pending.
4. **Cancel row edit** discards only pending changes. **Reset CSV row N
   corrections** restores that row's imported values; **Reset all row
   corrections** restores every row. Reset requires **Inspect CSV tasks** again
   and may bring back the original errors. Editing, cancellation and reset clear
   selection, so an earlier brief cannot be prepared silently.

Corrections are task-input overrides, not edits to the source CSV, saved creator,
selected knowledge or other rows. If two inputs use the same column, each may be
corrected independently. Formula-looking text, markup, dollar signs and braces
stay literal. Applied corrections keep their explicit column mapping locked;
cancel any pending edit and reset corrections before remapping. This avoids
quietly carrying a correction over to a different source column.

Wrong-width rows remain blocked. Task editing cannot infer which missing column
was intended or silently drop extra cells. Repair those rows in the original
spreadsheet, then export and reimport. Malformed quoting and invalid UTF-8 also
remain import errors. This feature is not a general spreadsheet editor.

Close/Escape keeps applied corrections and a pending row editor in this page
session. Returning can finish the same edit. Switching or revising the creator,
creating a new draft/variant/composition, clearing CSV tasks, a successful new
CSV import, or reload removes them. A failed replacement import keeps the old
batch and edits. Save/export of a creator never includes row corrections.
Task-only files still participate in full-brief validation; changing them
invalidates row previews while retaining corrections. Successful preparation
clears those files under the existing R626 rule, so inspect again before another
task. Manual task-form values remain independent.

## CSV data contract

- Headers must be distinct after surrounding-whitespace comparison, nonblank,
  and no longer than 200 characters. Header spelling and whitespace are retained
  for display; mappings use explicit column indexes rather than object keys.
- UTF-8 is decoded strictly, with an optional initial BOM. Invalid UTF-8, NUL,
  malformed quoting, missing data rows and file/row/column-limit violations fail
  the import. An existing batch remains intact on failure.
- Commas, LF/CRLF/CR record delimiters, quoted commas/newlines, and doubled quotes
  are supported. Spaces after a closing quote are rejected rather than silently
  repaired. A terminal record delimiter does not invent an extra row. A real
  blank row is retained for validation. Row numbers identify logical CSV records,
  including the header as row 1; quoted multiline cells can span physical lines.
- Cell contents stay strings, including leading zeroes, decimal spelling,
  dates, booleans, spaces, markup, formula-looking text, `$` and `{{braces}}`.
  There is no type coercion, formula evaluation, interpolation of cell contents,
  HTML rendering, spreadsheet workbook parser, or automatic column inference.
- Every mapped task field remains required and bounded to 4,000 characters.
  Whitespace-only values are invalid but accepted values are never trimmed.
  The filled task fits 8,000 characters and its full brief fits 48,000 characters.
  Unknown/unmapped extra columns are not added to the brief. Formula text is
  literal input to the selected task; it is not executed as a spreadsheet formula.

## Ownership and interruption

- Import deep-copies the selected saved definition. Each task uses that exact
  creator ID/revision and its existing composed stage snapshots. Later saved
  creator changes do not refresh the imported batch; a visible warning identifies
  the difference after reopening. Stage reference paths remain live references,
  not snapshots of knowledge file contents. Composed source examples stay
  illustrative; only the overall task template is filled from the selected row.
- Mapping changes clear inspection and selection. Preparation rechecks the
  selected filled task against the displayed exact brief. Invalid rows cannot
  prepare. A newer file read owns the import; late results or failures from an
  older read, dismissed panel or switched/revised creator cannot replace it.
- Pending row edits block row selection/preparation. Applying uses a candidate
  correction map and fresh complete-brief validation before changing the batch.
  Original cells are retained unchanged; reset is reversible to those originals.
  Corrected tasks use the same Book/version/capability and unsent-work checks.
- Preparation is single-flight and locks row/mapping/import actions. It retains
  the existing guards for active chat, unsent Wiki/Code text or images/pending
  submissions, unsaved document edits and review notes. Book/version/capability
  drift, catalog failures and native bridge rejection retain the batch for retry.
  Only the matching request acknowledgement closes the builder.
- Close/Escape preserves a completed import in the page session and cancels an
  unfinished file read or catalog preparation. **Clear CSV tasks**, switching or
  revising creators, starting a new draft/variant/composition, and reload remove
  the batch. CSV content/mappings/previews are not written to browser storage.
  Manual task-form input values remain independent. Preparing one row stages its
  values in ordinary chat, whose existing persistence and submission rules apply.
- No bulk Send, batch execution, provider call, workflow automation, result
  receipt, permission grant, installed pack or acceptance claim is added.

## Grounding and qualification

The authored `prd_work/content/moondesk.json` describes service ownership and
no implied execution authority (MOONDESK-B03), exact selected context with honest
recovery boundaries (MOONDESK-B04), and contextual advanced controls
(MOONDESK-R03). CSV-driven creator tasks are an adjacent bounded extension of
those principles, not a separately specified PRD requirement or full acceptance
of those requirements. R568 composition, R582 manual task forms and R591 variants
remain separate, preserved workflows.

Run `bash scripts/test_specialist_workflow.sh` from the source root or invoke its
absolute path. It runs built-in Node syntax checks and the parser/controller,
mounted-control adapter, composition/variant/history and bridge-runtime checks.
The new tests cover strict UTF-8 and CSV boundaries, lexical preservation,
explicit/reordered mapping, row errors, literal markup, saved composed snapshots,
exact one-row preparation, repeated return, stale reads/controls, catalog drift,
unsent-work rejection responses and recovery without saved-definition changes.
The native guard-presence check is static; it does not execute MoonBit reducers.

No MoonBit source changes, compilation/info/fmt, dependency installation,
production bundle build, real-browser layout/accessibility run, native lifecycle,
real user Send, live MoonClaw/provider execution or release qualification was
performed. A minimal DOM adapter qualifies control wiring and state transitions,
not visual/native acceptance. These remain explicit unrun gates.

R644 adds executed production-controller and mounted-control adapter coverage
for invalid-row correction, original/current-value comparison, exact one-row
preparation, stale-preview rejection, cancel/reset, mapping protection,
Close/Escape recovery, row/creator switching, malformed-width refusal, literal
inputs, task-file isolation, late catalog cancellation, and task/brief limits.
The authored PRD and native inventory have no row-correction acceptance item.
MOONDESK-B04 and MOONDESK-R03 are contextual source-scope links only; their
authored and native statuses, complete acceptance criteria and broader gates
remain unchanged. See the R644 `FEATURE.json` for exact executed counts.
