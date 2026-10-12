# Compare two saved local tables

Open a supported file in Desk or Wiki, choose **View as table**, then
**Compare with another saved table**. This read-only workflow answers which
records were added, removed or changed between two saved tables, even when
rows or columns have been reordered.

## Example: reconcile a revised sales export

1. Put `docs/samples/table-comparison/before.csv` and `after.json` in the same
   workspace. Open `before.csv` with **View as table**.
2. Choose **Compare with another saved table**. Enter the workspace-relative
   path of `after.json` and choose **Open comparison file**.
3. Select `id` for **Before key** and `record` for **After key**, then choose
   **Compare tables**. Key columns may have different names.
4. The result shows one added, one removed, one changed and one unchanged
   record. `001` changed amount from `10` to `12.5`; `gone` was removed;
   `=1+1` was added. The reordered Tokyo record is unchanged.
5. Choose **Export differences CSV** or **Export differences XLSX**. The
   files contain the same changed/removed/added records as the page, with
   before/after values and source record numbers. Unchanged records are omitted.

Opening another comparison file clears its worksheet and both key choices.
For XLSX inputs, **Choose worksheets** lets you select each side's exact named
sheet, independently. **Open worksheets** clears both key choices; choose
appropriate keys for the newly selected schemas. Downloads and reload retain
both paths, selected worksheet names and exact key column names. Changing
source column order does not silently change the selected key.

**Return to the before table** opens the original source and selected
worksheet. Comparison intentionally uses all saved rows; previous explorer
filters, sorting and grouping are not carried into the comparison.

## Reading the differences

- Keys are exact displayed strings, including case and surrounding whitespace.
  `01` differs from `1`. A numeric `1` and text `1` compare equal because this
  is a displayed-value comparison, not a type/fidelity comparison.
- All non-key columns align by exact name. Reordering columns is harmless;
  renamed non-key columns appear as a removed column and an added column.
  The page lists schema additions/removals. A missing column differs from an
  existing column whose value is blank.
- Changed and removed records follow their order in the before file. New
  records follow their order in the after file. Row reordering alone does not
  create differences.
- `Before record` and `After record` are one-based data record numbers,
  excluding CSV/TSV/XLSX headers. JSONL blank lines are not records. These are
  record references, not byte offsets or guaranteed physical line numbers.
  Exported record-column headers identify both paths and selected worksheets.
- `Changed columns` lists differing non-key column names. Each field has a
  before/after column pair. Missing records/columns export blank cells;
  the change status and column-presence labels establish which side is absent.
- A change to a key is reported as removal of the old key and addition of the
  new key. Blank or whitespace-only keys, duplicate keys and duplicate headers
  fail explicitly. Correct the saved input or choose another unique key.
  No occurrence matching or fuzzy guessing is performed.
- XLSX exports preserve keys and compared values as text, including `001`,
  `=1+1` and embedded newlines. Record numbers are numeric cells. CSV does not
  carry types: import it as text where exact identifiers matter, and heed your
  spreadsheet application's formula interpretation rules.
- When no records differ, counts still show unchanged records and exports
  contain headers only. Schema changes can exist even when both tables have
  no data rows, so check the schema notice too.

## Supported scope

Both sides independently use the existing MoonLeaf readers for CSV, TSV, JSON,
JSONL, NDJSON and XLSX. JSON top-level keys define columns, nested values remain
compact JSON text, missing fields are blank and null is `null`. CSV/TSV/XLSX
use the first row as headers. XLSX formulas use cached values without
recalculation. This workflow does not compare workbook styles, formulas,
merged-cell layout or arbitrary Office fidelity and does not merge or edit
sources. No network data connector is involved.

Source reader limits still apply. A comparison permits at most 1,000 output
columns and a conservative maximum of one million potential output cells,
computed from both input record counts and the paired output width. Use
smaller saved tables for larger inputs. Files are reread on every request:
exports reflect current saved contents rather than a pinned snapshot of a
previous view. This is a local inspection aid, not an acceptance receipt.

## HTTP and verification

The existing `GET /api/workspaces/<id>/json-table` route accepts
`comparison=1`, the before `path`, the after `compare_path`, optional `sheet`
and `compare_sheet`, exact header names `key` and `compare_key`, and
`format=html|csv|xlsx`. URL-encode paths, sheet names and key names. An HTML
request without an after path or key choices opens the appropriate selection
step. Invalid after sources or key selections return HTTP 400 with a
recoverable HTML form; incomplete/invalid downloads return HTTP 400. An
unavailable before file/worksheet uses the existing table reader error
response; reopen the file from the original Desk tab. Source paths remain
restricted to the selected workspace by the existing reader.

`internal/moonwiki/workspace_table_compare_wbtest.mbt` exercises keyed value
comparison, reordered records/columns, independently named keys, schema
changes, empty/key-only input, ambiguous selections, and a real localhost
host journey with downloaded CSV/XLSX opened through Leaf. The HTTP flow
covers every supported format, Unicode names, selected worksheets, reload,
source preservation and error recovery. Evidence is retained when
`MOONDESK_JSON_TABLE_EVIDENCE` points to an existing directory.

This qualifies served HTML and native localhost HTTP, not a graphical browser,
macOS desktop launch, accessibility, production deployment or all product tests.
