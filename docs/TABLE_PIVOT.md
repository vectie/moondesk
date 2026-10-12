# Pivot report from a saved table

Use a pivot report to compare two dimensions side by side, such as monthly
sales by region or counts of tasks by owner and status.

1. Open a saved CSV, TSV, JSON, JSONL, NDJSON or XLSX file with **View as table**.
2. Choose **Create pivot report**.
3. Select **Row groups** (for example region) and **Column categories** (month).
4. Choose **Count records**, or **Sum numeric values** and its numeric column.
5. Choose **Create pivot report**, inspect row/category/grand totals, and
   download **Export pivot CSV** or **Export pivot XLSX**.
6. For XLSX, select its named worksheet in the same form. If its columns differ,
   the page shows the missing selection so you can choose current columns.

The sample `docs/samples/table-pivot/sales.csv` groups East and West across Jan
and Feb. Sum amount to obtain East 150/blank (total 150), West 0/25 (total 25),
and a grand total of 175. Count mode includes every record, even missing amounts.

## What values mean

Groups and categories match exact displayed text, including case, whitespace,
Unicode and empty strings, in their first source appearance order. Two columns
must be different. Selectors bind to exact header names, so changing source
column order keeps the intended grouping. Duplicate headers are refused.

Count mode counts all records. A combination with no records is zero.
Sum mode accepts finite JSON-style numbers, including negative numbers, decimals
and exponents. Blank, `null`, currency, thousands separators, nested JSON and
other non-numeric text are ignored. The page shows how many numeric values were
included and how many source records were ignored. Missing combinations and
combinations with no numeric values stay blank; a genuine zero is numeric zero.
Floating-point arithmetic applies. An accumulated non-finite total displays
`Overflow`; other category and row totals are still independently computed.

The last column is the row total. The final row contains category totals and
the grand total. **Row type** distinguishes that final row from real keys named
Grand total. Category columns have the prefix `Category: `, avoiding collisions
with total/header labels. Empty categories retain that prefix with no following
value in downloads. On screen, category values use quoted JSON text, so an
empty string and a literal `(empty)` remain distinct. Empty input produces headers and a grand-total row: zero
for count, blank for sum. This is an aggregate report, not individual records.

XLSX output retains group keys as literal text, including `001` and `=1+1`.
Counts and finite totals are numeric cells; missing sums are empty cells.
CSV cannot encode cell types; spreadsheet apps may reinterpret literal text.
Imported XLSX uses cached formula values without recalculating them. This
projection does not preserve formulas, formatting or other workbook features.

## Saved context and recovery

The exact source path, worksheet, group/category headers, aggregation and value
header stay in form selections and download URLs. Reload and Back can restore
that context. Renamed/removed selected headers produce a recoverable form;
reordered headers still work. A missing worksheet returns the reader's error;
reopen the source explorer to choose an available worksheet.

Every saved source record participates. Explorer filters, sorting and grouping
do not apply to this separate report. Each request rereads the source, so a
later download can reflect saved changes since preview. Source bytes are never
rewritten. Save downloads separately.

Existing input limits apply. Output is bounded to 1,000 columns, 100,000 rows
and one million cells, including headers and totals. Too many distinct category
or row values produce an error before allocating the full matrix. Select less
varied dimensions or a smaller file.

## API and verification

The existing GET `/api/workspaces/<id>/json-table` endpoint accepts `pivot=1`,
`path`, optional exact-name `sheet`, `pivot_row`, `pivot_column`,
`aggregate=count|sum`, `pivot_value` (required for sum), and
`format=html|csv|xlsx`. URL-encode all values. An unconfigured HTML request
opens the chooser. Missing selections, invalid modes/headers, duplicate source
headers and unknown export formats return 400.

Focused verification exercises the actual native localhost host route, served
HTML, six source formats, CSV parsing and Leaf XLSX reopen, totals/types,
changed sources, named-sheet reordering and recoverable schema errors. It does
not qualify a graphical browser, accessibility, macOS application lifecycle,
full product or production readiness. Cumulative qualification remains R50;
R363 is a separately focused-tested change.
