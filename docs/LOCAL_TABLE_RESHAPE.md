# Reshape columns into rows

A wide monthly export such as `account,Jan,Feb` can now become a long table
with one record per account/month. This helps prepare data for charting,
joining to another table or analysis without manually copying each column.

1. Open a saved CSV, TSV, JSON, JSONL, NDJSON or XLSX table in the local data explorer.
2. Choose **Reshape columns into rows**.
3. Check the measurement columns, such as Jan and Feb. Every unchecked
   column remains an identifier repeated beside each resulting record.
4. Choose **Reshape table**, inspect the records, then download **Export
   reshaped CSV** or **Export reshaped XLSX**.
5. For XLSX, choose the named worksheet in the form. If a different sheet
   lacks the checked headers, the page reports them and lets you choose again.

## Meaning of the output

Each saved source record produces one output record per selected measurement.
Rows follow original record order, then original column order, regardless of
checkbox/query order. Blank measurement values and repeated source records
are retained. Selecting every column is supported; no identifier is required.
An input with headers but no records downloads headers only.

The output starts with Source path, Source worksheet and Source record
(one-based data record, excluding the header), followed by unchecked headers
prefixed with `Field: `, then Measurement and Value. Prefixing protects the
metadata from source columns with the same names. Empty worksheet means a
non-XLSX source. Names match exactly, including spaces, case and Unicode.
Duplicate source headers or repeated/missing selected names block reshaping.

Values are the source reader's displayed text. JSON null is `null`; nested
JSON remains compact text. XLSX stores identifiers, measurement labels and
values as literal text, preserving `001` and `=1+1`. Only Source record is a
numeric cell. CSV has no cell types and spreadsheet apps may reinterpret it.
Existing cached formula values are used without recalculation. This does not
preserve source formatting, formulas or other workbook features.

## Context and recovery

The form and export URLs retain the exact path, named worksheet and selected
header names. Reload and Back restore the selection. Reordered headers still
select the same names; output order follows the latest saved file. A renamed
or removed selected header reports an error instead of selecting by position.
A missing or renamed worksheet uses the existing source-reader error; reopen
the workbook's explorer to select an available sheet. Duplicate headers must
be renamed in the source and reloaded.

This transformation uses every saved record. Explorer filters, sorting and
grouping do not apply. Each preview/export reads the file afresh; an export
can reflect changes made after preview. The source is never modified. Save
downloads separately. Output is limited to 99,999 records, 1,000 columns and
one million cells including headers, in addition to existing input limits.
Reduce measurement selection or use a smaller source if expansion is too big.

## API and qualification

The existing `GET /api/workspaces/<id>/json-table` route accepts `unpivot=1`,
`path`, optional `sheet`, repeated exact-name `measure` parameters and
`format=html|csv|xlsx`. URL-encode values. No measurements opens the HTML
chooser; downloads without a selection return 400. Invalid names and duplicate
headers return 400 with a recoverable HTML form or the existing API error.

Focused acceptance covers native localhost HTTP, served HTML, all six input
formats, CSV parsing and real Leaf XLSX reopen. It does not establish actual
graphical-browser usability, accessibility, macOS host behavior, full product
or production readiness.
