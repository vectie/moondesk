# Export table records as JSON or JSONL

Use these downloads to move a selected set of spreadsheet or CSV records into
scripts, local data tools, or another JSON reader, without editing your source.

1. Open a saved CSV, TSV, JSON, JSONL, NDJSON or XLSX file with **View as table**.
2. For XLSX, choose the named worksheet you need.
3. Set filters and sorting, then choose **Apply exploration**.
4. Choose **Export filtered JSON** for an array of objects, or **Export filtered
   JSONL** for one compact object per line. Both contain all matching records
   in the displayed order.
5. To download aggregate records instead, choose **Group by**, optionally
   **Sum numeric column**, apply, then choose **Export summary JSON** or
   **Export summary JSONL**.

Try `docs/samples/table-records/orders.csv`: filter status containing `open`,
sort amount numerically descending, and group by region with sum amount.
Filtered downloads contain River, Northwind 東京 and Acme, Inc. in that order.
The summary contains West: one row totaling 2500, then East: two rows totaling
1550.5. CSV source values remain strings in individual records; summary counts
and sums are JSON numbers. This is useful when identifiers such as `001` must
stay text.

## What is exported

- Each header becomes an exact object key. Key order follows table columns;
  record order follows the filtered/sorted table. Escaped quotes, newlines,
  Unicode, and keys such as `__proto__` are ordinary JSON strings.
- Text stays a JSON string, even if it looks like a number, boolean, formula,
  JSON object, or `null`. Nonempty CSV/TSV fields stay text; blank CSV/TSV
  fields are empty cells and become null. No type inference is performed
  during export.
- Typed numeric cells become JSON numbers. Their current numeric token is
  preserved, avoiding another floating-point serialization round. An invalid
  or non-finite numeric token fails the whole download with its record and
  column number. Existing readers may already normalize source numbers.
- Typed booleans stay JSON booleans. Empty/missing table cells become JSON null.
  Empty text remains `""`. Spreadsheet error values are literal strings.
- The existing JSON table reader flattens nested arrays/objects and explicit
  JSON null into text. These exports preserve that displayed projection,
  including `"null"`, rather than reconstructing original nested JSON or
  distinguishing every original input type. Missing fields become JSON null.
- XLSX formulas use their stored cached text, or null when no cache exists,
  without recalculating. Formatting, formulas and other workbook features are
  outside this record projection.
- Duplicate output headers are rejected because JSON objects cannot preserve two
  distinct columns with the same name. The page explains how to rename them
  in a separately saved source, or use CSV/XLSX. Even an empty matching result
  with duplicate headers is rejected. Headers are never silently renamed.
  A grouped summary has its own distinct output headers and remains exportable.
- An empty result is `[]` plus a newline for JSON and an empty file for JSONL.
  Nonempty JSONL has exactly one complete object per line and a final newline;
  embedded cell newlines are JSON-escaped. Empty results have no schema record.
- Summary keys are the displayed summary headers. A missing sum is null, a real
  zero is numeric zero, and overflow is the string `"Overflow"`.

## Saved context and limits

Download URLs retain the saved file, selected worksheet, filters, sorting and
summary settings. Reload and Back keep that exploration. Each download rereads
the current saved source: it is not a snapshot of an earlier preview. Changing
worksheet order keeps an explicit name selection; removing or renaming that
worksheet fails clearly. Source bytes are never rewritten by this workflow.

Existing table/parser/archive limits apply, including the rectangular
CSV/TSV/XLSX one-million-cell bound. Output is buffered, not streamed. These
formats are available for ordinary explorer rows and its grouped summary;
separate pivot/compare/lookup/append/reshape reports keep their existing
CSV/XLSX downloads.

## API

GET `/api/workspaces/<id>/json-table?path=<encoded-path>&format=json|jsonl`
accepts the existing optional `sheet`, text/numeric filters, sort and group
settings. Set `projection=summary` for grouped records; omit it or use `rows`
for individual records. JSON uses `application/json; charset=utf-8`; JSONL uses
`application/x-ndjson; charset=utf-8`. Attachment names are `json-table.json`,
`json-table.jsonl`, `table-summary.json`, and `table-summary.jsonl`.

Duplicate headers, invalid numeric cells, invalid filters, missing worksheets,
missing summary group, invalid projection or unsupported format return 400
without a partial attachment or any source write. The existing workspace path
boundary applies.

## Focused verification

`internal/moonwiki/workspace_table_records_wbtest.mbt` covers typed/literal
semantics, exact numeric tokens, duplicate/ragged schema rejection, empty
results, and an actual native localhost route journey across six input formats.
It follows served download links, checks row/summary order, MIME/filenames,
reload/context, source-byte preservation, changed sources, and worksheet
reorder/removal. Retained HTTP output is independently parsed by Python.
No graphical browser, accessibility, macOS lifecycle, complete product or
cumulative qualification is claimed.
