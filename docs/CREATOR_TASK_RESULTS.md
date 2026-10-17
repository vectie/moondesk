# Collect and export creator task outputs

Open **Packs → Agents → Build your specialist**, reopen a saved creator with a
task form and import/map/inspect a CSV task batch. R672 adds an output workflow
after preparing tasks: record separately observed responses beside the exact
inputs, compare attempts and export useful results for downstream work.

## Complete journey

1. Select a valid CSV row and inspect its exact brief. Prepare/send the task in
   the ordinary chat only when intended; the output notebook never sends tasks
   or reads responses from a provider automatically.
2. Return to the saved creator and inspect/select the intended row. Choose
   **Record an observed response for selected task**. Paste the response you
   observed and add notes or a next step. **Save operator observation** captures
   the original row cells, corrected input values, filled task and complete brief.
3. Repeat for another row or another response to the same task. Earlier
   observations stay separate and immutable. Correct an earlier report by
   recording another observation and explaining the correction in notes.
4. Edit/correct task inputs normally. Each observation shows whether its exact
   captured inputs and complete brief still match the current batch. Changed
   inputs, mappings, task-file contents or missing current rows mark a historical
   observation; earlier text is retained rather than relabeled. If a task
   changes during observation editing, Save refuses and preserves the text.
   Restore those exact inputs/files or cancel and select the intended task.
5. Download **exact task-results JSON**, **spreadsheet-safe task-results CSV** or
   **task-results Markdown**. JSON is the complete exact archive; Markdown is a
   readable report with creator identity, captured briefs, responses and notes.
   CSV contains one observation per row for downstream sorting/transformation:
   observation number, source row, match flag, captured input values, task,
   response, notes and current input errors. It omits complete creator/brief and
   original cell details available in JSON/Markdown.

Try `samples/creator-task-results/tasks.csv` with this task form:

```text
Explain {{topic}} for {{audience}}. Cite the available source and name missing evidence.
```

The separate R672 example outputs contain synthetic observations. The example
creator identity is fixture context, not a creator installed in your library.

For a concrete correction and same-task retry, choose **Improve creator from
observation N**. The [creator refinement journey](CREATOR_TASK_REFINEMENT.md)
keeps the original observation and its task-only file snapshot while editing
and saving an independent creator variant. The results export format is unchanged.

## Exactness, privacy and continuity

- Saved observations are operator-entered reports. There are no success labels,
  inferred grades, runtime receipts, automatically accepted lessons or changes
  to the saved creator. A matching task says only that its exact input/brief
  projection matches the currently open batch. Live knowledge paths do not pin
  their target file bytes; this does not verify what a model actually received.
- Complete briefs include explicitly selected task-file text. JSON and Markdown
  can therefore contain private selected files, inputs and responses. The UI
  warns before use/export. Unrelated storage fields, grants, credentials, hidden
  reasoning and unrelated files are not copied by the allowlisted creator path.
- CSV serializes every value as JSON before CSV quoting. Text cells visibly
  contain JSON string literals, preventing formula-looking values such as `=`,
  `+`, `-` and `@` from becoming spreadsheet formulas. Parse a cell as JSON to
  recover exact strings, including CRLF, quotes and Unicode. This is intentional
  rather than a silent apostrophe prefix or mutation of original text.
- Observations remain in this page session when the builder closes. Export
  before reload, new CSV/checkpoint intake, clear, revise or switching creators.
  The existing task checkpoint still excludes observations. Result JSON is an
  archive, not a resumable task checkpoint; there is no result-file import.
- Task-file snapshots may be cleared by the existing successful chat preparation
  acknowledgement. Re-add intended files and inspect the exact brief before
  attaching a later observation. An operator is responsible for relating the
  pasted response to the displayed captured task; Desk cannot attest that link.
- Save or cancel unfinished observation text before result export. Failed
  downloads keep all records. Browser download requests do not prove disk writes.
  Detached controls are invalidated by the existing mounted-view epoch checks.

## Bounds and output

At most 100 observations per batch; each response is 1–16384 UTF-16 code units
and nonblank, notes at most 8192. New response/notes reject NUL or unmatched
Unicode surrogates. A conservative aggregate check reserves space under the
4 MiB exact-JSON archive limit; over-limit additions keep prior observations and
the unfinished text. Each download is bounded to 4 MiB without truncation. Very
dense Markdown may exceed that bound; JSON remains the compact exact archive.
Legacy malformed Unicode in captured task text is preserved through JSON/CSV
escapes and blocks Markdown rather than changing bytes silently.

Markdown fences exceed literal backtick runs; response markup is inert in the
app's text nodes. Downloads have the format's MIME type and clean up their
temporary link/Blob URL. No network transmission is added.

## Verification and qualification

The full Node suite passes 310 tests, including 15 new tests: production
controller output journeys, mounted actual controls, exact source/corrected-row
binding, repeated attempts, input/file drift, pending edits, malformed/large
inputs, output bytes/MIME/resource cleanup, literal spreadsheet-safe CSV and
failed downloads. The focused results/DOM/checkpoint/CSV closure passes 75 tests.
The real existing Pack Home lazy entrypoint remains the route to these controls.

No MoonBit source or API changed. Actual declared dependencies remain pinned;
the full Node suite uses the retained locked Terser/Vite/Rabbita resolver without
installing or changing packages. Compiled Desk UI remains blocked on absent
declared MoonLeaf/MoonEdit workspace sources. Browser/native/installed lifecycle,
providers, customer acceptance and release qualification remain unrun/blocking.
Chromium was not retried. This is an adjacent creator output workflow with
MOONDESK-B04/R03 context, not closure of authored PRD acceptance criteria.
