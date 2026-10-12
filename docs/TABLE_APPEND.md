# Combine saved tables

Use MoonDesk's local data explorer to combine saved monthly exports, batches
or worksheet partitions into one downloadable table. The first table's rows
come first, followed by every row from the second table. Repeated records are
kept; no key, deduplication or row matching is required.

## Walkthrough

1. Open a saved CSV, TSV, JSON, JSONL, NDJSON or XLSX table through the existing
   local data explorer action. Select the intended worksheet for XLSX.
2. Choose **Combine rows with another table**.
3. Enter the second file's workspace-relative path and choose **Combine
   tables**. Either file may use any supported format.
4. For XLSX, select the named first and second worksheets independently and
   choose **Combine selected worksheets**. You may select two sheets from one
   workbook. Opening a different second file resets its worksheet selection.
5. Inspect both exact paths, worksheet names, row counts, shared/one-sided
   columns and the combined rows. Download **Export combined CSV** or
   **Export combined XLSX**. The output opens independently.

Example: a first CSV with `id,amount` and a second with
`amount,id,department` aligns `id` and `amount` by name, leaves department blank
for first-file rows and includes every second-file record. Reordering headers
in either source does not move values to an unrelated field.

## Data and context

- Headers match exact text, including case and whitespace. Fields appear in
  first-table order, then second-only fields in second-table order.
- Source path, Source worksheet and Source record columns identify each row.
  Original headers receive a `Field: ` prefix to distinguish them from those
  metadata columns, including original fields named Source path.
- Source record is a one-based data-record number excluding the header. JSONL
  blank lines are not records. A blank worksheet means a non-XLSX input.
- Missing columns and empty cells are blank. JSON null displays as literal
  `null`; nested objects and arrays remain compact JSON text.
- Every saved row is included. Explorer filtering, sorting and grouping do
  not apply. Selecting the same path and worksheet twice repeats its rows.
- XLSX data is a literal displayed-text projection. Identifiers like 001 and
  formula-looking text like =SUM(A1) remain text. Only Source record is a
  numeric cell. Cached formula values are used without recalculation.
  Formatting, formulas, merged cells and other workbook features are not
  carried into this derived table.
- CSV cannot preserve cell types. Spreadsheet applications may reinterpret
  identifiers or formula-looking values; prefer XLSX for literal text.
- URL state and download links retain both paths and selected worksheet names,
  including the first-sheet default. Reload, Back and links can restore that
  selection. Files are read afresh for each request, so an export can reflect
  saved changes made after its preview. This is not a version-pinned snapshot.
- Both inputs are read-only. Downloading never appends into or overwrites a
  source. Save the derived file separately using the browser's download flow.

## Recovery and limits

Duplicate headers within either table are ambiguous and block combination.
Correct them in the source and reload; the form retains the second path.
Missing second files or renamed worksheets show a recoverable error. Reopen
that file to select its current first worksheet, then choose the intended
name. If the first source is unavailable, reopen it from the Desk tab; the
existing source-reader error applies. Paths must remain within the selected
workspace. Empty inputs are allowed; two empty inputs download headers only.

Output is bounded to 99,999 data records, 1,000 columns including the three
provenance columns, and one million cells including headers. Existing input
reader size and supported-format limits also apply. No input rows are
silently truncated. The workflow combines two inputs per request.

## HTTP and qualification

The existing `GET /api/workspaces/<id>/json-table` route accepts `append=1`,
`path`, `append_path`, optional `sheet` and `append_sheet`, and
`format=html|csv|xlsx`. URL-encode paths and worksheet names. Opening without a
second file displays the chooser; incomplete or invalid downloads return 400.

The focused test file is
`internal/moonwiki/workspace_table_append_wbtest.mbt`. It exercises pure data
alignment plus real localhost HTTP selection, all six formats, source-byte
preservation, CSV/XLSX download and real Leaf reopen, worksheet reordering,
reload, schema edits, duplicate-header recovery, empty inputs and bounds.
`MOONDESK_JSON_TABLE_EVIDENCE` retains actual HTTP outputs in an existing folder.
Qualification is native localhost HTTP and served HTML only. It does not
establish graphical-browser usability, accessibility, macOS desktop, a full
product pass, or production readiness.
