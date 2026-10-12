# Local data explorer

Select a saved `.json`, `.jsonl`, `.ndjson`, `.csv`, `.tsv`, or `.xlsx` file in Desk or Wiki and choose **View as table**. This explicit action opens a read-only explorer in a separate tab. Code also offers it for supported editable sources after saving. Normal source and Office editing remain unchanged.

For an XLSX workbook, choose its named **Worksheet** and **Open worksheet**.
The selected sheet name is shown above the rows. Switching sheets clears the
old column filters, sort and group settings, since each sheet can have a
completely different schema. Applying an exploration, resetting its transforms
or downloading CSV/XLSX keeps that worksheet. Exported XLSX contains one sheet
with the selected source name. Opening another file starts from that file's
first worksheet; it does not reuse the previous file's sheet selection.

Try `docs/samples/table-explorer/sales.csv` in a workspace:

1. Choose **status** under Text column and enter `open` under Contains.
2. Choose **amount** under Numeric column, minimum `100`, maximum `2000`.
3. Sort **amount** as Number, Descending.
4. Group by **region**, sum **amount**, then **Apply exploration**.
5. The view shows 2 of 5 rows: Northwind 東京, then Acme, Inc. East has 2 numeric values totaling 1550.5.
6. **Export filtered CSV** downloads those two rows in that order, including the header. The XLSX link exports the same projection. **Reset all** returns all five rows. Your source bytes are never rewritten.

The selected worksheet name and filter/sort/group settings remain in the URL and in the form after applying, so reload and browser Back retain that exploration. A malformed numeric bound shows the form again with the error; reset remains available. Exports always run the same filter and sort on all saved source rows. Use the separate **Export summary CSV** or **Export summary XLSX** links to download the displayed group summary after choosing **Group by** and applying the exploration. Filtered exports still contain individual rows.

## Export a grouped summary

1. Choose **Group by**, optionally choose **Sum numeric column**, then **Apply exploration**.
2. Under the visible summary, choose **Export summary CSV** or **Export summary XLSX**.
3. Open the downloaded `table-summary.csv` or `table-summary.xlsx`. It contains one row per displayed group, not the individual source records.

The column names identify the selected group and sum columns. With no sum column,
exports contain group and row count only. With a sum column, they also contain the
numeric-value count and sum. A group with no numeric values has a blank sum;
a real zero total is `0`. Non-finite accumulated totals are the text `Overflow`.
XLSX counts and finite totals are numeric cells, while group keys remain text
(including leading zeroes and strings beginning with `=`).

Groups use exact values and follow their first appearance in the filtered,
sorted rows. Empty group keys display as `(blank)` and remain empty cells in
exports; a literal `(blank)` key is a separate group. If no rows match, the page
says so and downloads contain headers only. A selected XLSX worksheet stays
selected and provides the exported worksheet name. Other inputs use the
worksheet name `Group summary`.

Filters, sorting and worksheet selection travel in each download link. The
source is reread on download, as with ordinary row exports. These summaries are
local table projections and do not replace the HTML Work Package workflow.
CSV does not encode cell types; its quoted text should be imported as text in
spreadsheet software when exact textual group keys matter.

## Data meaning and limits

- Existing MoonLeaf readers handle every format. There is no new CSV/XLSX/JSON parser or modified dependency.
- JSON uses an array of objects; JSONL/NDJSON uses one object per nonblank line. Columns follow the first appearance of top-level keys, and nested values remain compact JSON text. Missing values are blank and null is `null`.
- CSV/TSV and the selected XLSX sheet use row 1 as headers. Blank headers become Column N; numbered selectors distinguish duplicate labels. Sparse rows are filled with blank cells. There is no header-row inference. The initial XLSX view uses the first worksheet in workbook order; the chooser lists the names exposed by the existing MoonLeaf reader.
- Text contains is case-insensitive. Text and numeric filters combine with AND. Bounds are inclusive and use finite JSON-style numeric syntax, such as `12.5`, `-20`, or `1e3`; currency signs, thousands separators and localized decimal commas are not numeric values. Blank/non-numeric values do not match numeric bounds.
- Text sorting is lexical and case-sensitive. Numeric sorting puts blank/non-numeric values last in either direction. Ties keep source order. Groups use exact displayed values and are listed in first-seen order after sorting. Numeric sums use floating-point arithmetic; the numeric-value count exposes omitted cells.
- XLSX formulas use stored cached values, without recalculation; formulas without cached values are blank. This is a data projection, not a workbook-fidelity or formula editor. Use the original Office view to inspect formatting, formulas, and warnings. The explorer does not preserve workbook layout or add a full workbook editor.
- CSV/TSV/XLSX rectangular projections are limited to one million cells, 100,000 rows, and 1,000 columns. Existing parser/archive limits also apply. Results are rendered in full, with no pagination or streaming. Intended for modest local files, not database-scale analysis.
- Worksheet names are matched exactly, including case and Unicode. A renamed, removed or ambiguous sheet fails explicitly instead of silently opening another sheet. Remove the stale `sheet` query or reopen the file to choose again. Reordering worksheets leaves an explicit name selection unchanged.
- The source is re-read on each apply/export. Concurrent source edits may change an export relative to a previously opened view; this is not a pinned snapshot. No external account or remote data connector is involved.

## HTTP and verification

The existing `/api/workspaces/<id>/json-table?path=<encoded-path>&format=html|csv|xlsx` route now accepts all the supported formats. Query fields are optional `sheet` (URL-encoded exact XLSX worksheet name), `text_column`, `contains`, `number_column`, `min`, `max`, `sort`, `sort_type=text|number`, `direction=asc|desc`, `group`, and `sum`. CSV/XLSX requests may also set `projection=summary` to export grouped results (`rows` or omitted keeps individual rows). Summary requests require a valid `group`; an invalid nonblank `sum` or unknown projection returns HTTP 400. Column selectors are zero-based; blank means unset. Keep the historical route name for compatibility.

Focused tests: `internal/moonwiki/workspace_table_explorer_wbtest.mbt` covers projection/reset/empty results and a real localhost host journey across CSV, TSV, JSON, JSONL and XLSX with reopened filtered CSV and source-byte preservation. `internal/moonwiki/json_table_http_wbtest.mbt` retains JSON editing and CSV/XLSX export regression coverage. `ui/rabbita-desk/main/source_json_table_wbtest.mbt` checks compiled UI selection and original editor state. Set `MOONDESK_JSON_TABLE_EVIDENCE` to an existing private directory to retain workflow HTML, sample inputs and filtered CSV outputs.


Worksheet-focused verification: `internal/moonwiki/workspace_table_worksheets_wbtest.mbt`
checks escaped/Unicode names, selection and reset controls, workbook order,
empty and missing sheets, sheet reordering, another-file isolation, and actual
localhost filter/sort/group/export/reload. It reopens exported CSV and XLSX and
checks source bytes. Set `MOONDESK_JSON_TABLE_EVIDENCE` to an existing private
directory to retain the three-sheet workbook, selected/default/error HTML and
actual filtered outputs. These tests cover served HTML and HTTP rather than a
graphical browser, macOS desktop, accessibility or a source snapshot guarantee.

Summary-focused verification: `internal/moonwiki/workspace_table_summary_wbtest.mbt`
covers exact blank/quoted/Unicode keys, numeric typing, zero versus missing sums,
overflow, counts-only and empty summaries, invalid selectors, and actual localhost
HTML download links across CSV, TSV, JSON, JSONL and selected XLSX worksheets.
Downloaded files are reopened through real Leaf readers; source bytes and ordinary
row exports are checked independently. Set `MOONDESK_JSON_TABLE_EVIDENCE` to retain
served HTML and the actual summary CSV/XLSX outputs.

## Compare with a revised table

Choose **Compare with another saved table** to reconcile this file with a
second workspace CSV, TSV, JSON, JSONL, NDJSON or XLSX file by a unique key.
The comparison shows changed, added and removed records and downloads the
same before/after differences as CSV or XLSX. Both sources remain unchanged.
See [Compare two saved local tables](TABLE_COMPARISON.md) for the walkthrough,
worksheet selection, exact-value semantics and limits.

To append fields from a separate saved reference table, choose
**Enrich from a lookup table**. It keeps every source row, supports repeated
source keys, identifies unmatched records, and downloads enriched CSV/XLSX.
See [Table lookup](TABLE_LOOKUP.md) for matching, worksheet selection and limits.

To stack monthly exports or worksheet partitions, choose
[Combine rows with another table](TABLE_APPEND.md). Exact headers align across
files, missing columns stay blank, and CSV/XLSX downloads retain each row's
source path, worksheet and record number.

## Compare categories side by side

Choose **Create pivot report** for row groups versus column categories, using
record counts or numeric sums. Row/category/grand totals download as CSV or
XLSX. See [Pivot report](TABLE_PIVOT.md) for the walkthrough, exact header
selection, blank-versus-zero semantics and saved-context recovery.

## Download JSON records

Use **Export filtered JSON** or **Export filtered JSONL** to reuse the displayed
records in scripts and data tools. **Export summary JSON/JSONL** downloads the
displayed aggregate records. Typed numbers and booleans stay typed, text stays
text, and empty cells become null. Duplicate headers are refused. See
[JSON and JSONL record downloads](TABLE_RECORD_EXPORT.md) for the walkthrough
and the existing reader's nested-JSON/null projection boundary.
