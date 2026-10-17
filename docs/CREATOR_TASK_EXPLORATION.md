# Explore a creator task batch

Open **Build your specialist**, reopen an unchanged saved creator with a task
form, and import a local CSV, JSONL, or task checkpoint. Map each input and
select **Inspect CSV tasks**. The **Explore task rows** controls now let you
find a particular task, focus on corrections or observed responses, and choose
a useful row order without rewriting the imported batch.

## Try the example

Use a creator template such as `Review {{topic}} for {{audience}}` and import
[`samples/creator-exploration/tasks.csv`](samples/creator-exploration/tasks.csv).
Map `topic` to `Subject` and `audience` to `Reader`, then inspect.

1. Enter `FOUNDER` as the literal search, choose `audience` for **Search input**,
   and choose `topic` for **Order task rows by**. Click **Apply task exploration**.
   Source rows 4, 5 and 2 appear in that order. Row 4 needs a subject; row 5 is
   the lowercase `alpha` task. The row numbers still refer to the source table.
2. Select row 5 and inspect its exact brief. Choose **Edit task inputs for CSV
   row 5**, change `topic` to `Adapted alpha`, and apply. The edit affects source
   row 5, even though it is now displayed earlier in the list. Select it again.
3. Choose **Save task checkpoint to file**, clear the batch, then restore that
   file against the same saved creator. Inspect again and choose **With
   corrected inputs**. Row 5 retains the correction. Checkpoints contain every
   imported row and all applied corrections; they do not save the view filter.
4. Select the corrected row and choose **Prepare selected CSV task in chat**.
   Review the normal chat composer and use ordinary **Send** separately. The
   view never sends or runs tasks.

## Search and ordering

- Search matches literal text in the current mapped input values, including
  applied corrections. It is case-insensitive, with a 200-character limit.
  Spaces and newlines are literal; regular expressions are not interpreted.
- Search one template input or all mapped inputs. Unmapped source columns,
  creator instructions, attached file contents and observed responses are not
  searched. Thus the sample's `unmapped-secret` does not match any task.
- Apply search, field, status and order together, or press Enter in the search
  input. **Reset task exploration** returns to all rows in source order.
  No-match results retain the full batch and offer the same controls.
- Sort by source row number or an input, ascending or descending. Input sorting
  is lexical on lowercased strings using JavaScript's UTF-16 ordering, not
  numeric, date or locale-specific sorting. `10` sorts before `2`; equal values
  keep their original source order in either direction. Original cells, row
  numbers and observation bindings are never reordered or renumbered.
- Applying or resetting a view clears the selected brief. Select a visible row
  again before preparing. Pending row edits or unfinished observations must be
  applied/saved or cancelled before changing the view.

## Task and observation filters

- **Ready to select**: the current inspected task has no input/brief errors.
- **Needs correction**: a current input, structure or brief error blocks it.
- **With corrected inputs**: at least one applied input differs from its import.
- **With matching observations**: at least one operator-entered response is
  bound to this exact source row, current inputs and complete brief.
- **Ready without matching observations**: a valid task has no response that
  matches its current inputs and brief. This includes a changed task whose
  earlier observations are now historical.
- **Only historical observations**: this row has earlier responses but none
  match the current task. The earlier responses stay in the result archive.

Counts describe the entire inspected batch, independently of the search/status
filter, and count tasks rather than responses. Several observations on one row
count as one observed task. Rows show matching/historical response counts too.
An observation is never a provider receipt, a success mark or accepted knowledge.

For example, select a ready row and record a response you actually observed
separately. Under **Ready without matching observations**, that row disappears
and its selection clears. Choose **With matching observations** to find it.
Edit the row's inputs and apply; the old response now appears under **Only
historical observations**. Multiple identical source rows keep separate
bindings. Changing task files invalidates the inspected view; inspect again
before relying on fresh match status.

## Recovery and scope

Applied exploration persists through Close/Escape in this page session. Reload,
another batch import or checkpoint restoration resets it. A search edited in
the controls but not applied is not saved and can be lost on another action.
Source edits and task-only files retain their existing recovery limits.

Filtering never changes export scope: task checkpoints include the complete
imported table, mappings and corrections; result exports include all saved
observations, even if no current row is visible. Review private content before
sharing either file. The controls state this explicitly. Exploration is not an
export-selection tool, a batch runner or a completion tracker.

## Verification boundary

Run `npm run test:specialists` in `ui/rabbita-desk`. The helper tests cover
literal/Unicode search, stable ordering, status combinations, duplicate rows,
changed brief identity and the supported 100-row bound. Mounted production
controls exercise search/order → source-row edit → full checkpoint → restore →
exact unsent preparation, observation changes, no-match recovery, Enter,
interruption and stale controls. These tests use minimal DOM and local service
adapters; they do not qualify browser layout/accessibility, compiled MoonBit
UI, native lifecycle or live provider execution.
