# Enrich a saved table with lookup fields

For duplicate CSV/TSV lookup keys, use the source editor's
[duplicate-key preview and first/last resolution](TABLE_DUPLICATE_KEYS.md).
Review and Apply to the unsaved draft, explicitly correct any retained blank
keys, then Save and reopen. Lookup matching and its key requirements stay exact.

Need an explicit split/trim key first? The source editor can
[preview and append a derived CSV/TSV column](TABLE_DERIVED_COLUMN.md).
Choose Apply and Save yourself, then reopen the saved table and select that
column. Lookup matching itself remains exact and unchanged.

Open a saved table in Desk or Wiki with **View as table**, then choose
**Enrich from a lookup table**. Match a customer, product or other identifier
against a saved reference table and download a combined file. Both inputs stay
unchanged. This is a many-to-one left lookup: every source record appears once
in its original order, with the matching lookup fields appended.

## Example: add customer names to orders

1. Put `docs/samples/table-lookup/orders.csv` and `customers.json` in the same
   workspace and open `orders.csv` with **View as table**.
2. Choose **Enrich from a lookup table**, enter the workspace-relative path of
   `customers.json`, and choose **Open lookup file**.
3. Set **Source key** to `customer` and **Lookup key** to `id`, then choose
   **Enrich table**. The key names need not be the same.
4. Inspect 4 matched and 2 unmatched source records, plus 1 unused lookup
   record. The two orders for `001` both receive Acme's name; neither source
   row is removed or multiplied. A missing customer and a blank key stay
   present and marked `Unmatched`.
5. Choose **Export enriched CSV** or **Export enriched XLSX**. Both contain the
   displayed records, including unmatched ones. XLSX creates one `Enriched
   table` worksheet with literal text values and numeric record references.

For XLSX inputs, **Choose worksheets** independently selects each input's
exact named worksheet. **Open worksheets** clears the key choices so you can
select keys in the new schemas. Opening another lookup file also clears its
worksheet and both key choices. The source worksheet remains selected.
The selected paths, worksheet names and exact key names travel in forms and
download links; reload repeats that selection. **Return to the source table**
returns to its original path and selected worksheet. Prior filters, sorting
and grouping do not apply: enrichment reads all saved source records.

## What matching and outputs mean

- Lookup keys must be unique and nonblank. Duplicate or whitespace-only lookup
  keys stop enrichment with a recoverable error. Choose another key or correct
  the saved lookup. Duplicate headers on either side also need correction.
- Source keys may repeat. Blank or whitespace-only source keys stay unmatched,
  as do keys absent from the lookup. No source record is dropped.
- Keys match exact displayed text, including case and whitespace. `001` differs
  from `1`; numeric `1` and text `1` match. No fuzzy matching, trimming or
  case-folding is performed. JSON null displays as `null`, not a blank key.
- `Match` distinguishes a missing lookup from a matched record with blank
  fields. `Source record` and `Lookup record` identify one-based data records,
  excluding the header; JSONL blank lines are not records. Their exported
  headers include each source path and selected worksheet name.
- `Source:` and `Lookup:` prefixes distinguish every original field, including
  both selected key columns and fields with the same name on the two sides.
  Unmatched lookup fields and lookup record references are blank.
- Matched and unmatched counts count source records. Unused lookup count counts
  distinct lookup records never used by any source record. Unused lookup rows
  are not appended to the output.
- All displayed input values export as text in XLSX, including leading zeroes,
  formula-looking strings, dates, amounts and booleans. Only record references
  are numeric cells. This avoids changing identifiers; convert selected amount
  columns explicitly in your spreadsheet if you need arithmetic afterward.
  CSV carries no types. Import it as text when exact identifiers matter, and
  follow your spreadsheet application's formula-interpretation precautions.
- Empty sources with headers produce a headers-only download; an empty lookup
  with headers leaves every source row unmatched. A table without any columns
  cannot provide a key and must be given a header before enrichment.

## Scope and recovery

Both inputs independently support CSV, TSV, JSON, JSONL, NDJSON and XLSX using
the existing real MoonLeaf readers. JSON top-level keys become columns, nested
values remain compact JSON text, missing fields are blank and null is `null`.
CSV/TSV/XLSX use the first row as headers. XLSX uses cached formula values
without recalculation. No workbook styling, merged-cell layout, formula
editing, type-fidelity merge, network integration or source writeback is
provided.

Output is bounded to 1,000 columns and one million cells including its header.
Existing input reader limits still apply. All rows render together; this is
for modest local saved files. Files are reread on every request, so a download
may reflect an edit saved after the page opened. It is not a pinned snapshot.
A renamed or removed selected key or lookup worksheet produces a clear error;
reopen the lookup or change the keys to recover. An unavailable source file or
source worksheet uses the existing table-reader error response; reopen it
from the Desk tab. Paths remain inside the selected workspace.

## HTTP and focused verification

The existing `GET /api/workspaces/<id>/json-table` route accepts `lookup=1`,
source `path`, `lookup_path`, optional `sheet` and `lookup_sheet`, exact header
names `source_key` and `lookup_key`, and `format=html|csv|xlsx`. URL-encode
paths, key names and worksheet names. Missing lookup/key selections open an
HTML chooser; invalid selections produce HTTP 400 with a recoverable form.
Incomplete or invalid downloads return HTTP 400.

`internal/moonwiki/workspace_table_lookup_wbtest.mbt` exercises repeated source
keys, exact matching, blank/missing/unmatched keys, duplicate lookup rejection,
field-name collisions, empty inputs, output limits, real localhost selection
forms, all six input formats, independently selected XLSX worksheets, saved
column reordering, CSV/XLSX download/reopen, escaping, reload and source-byte
preservation. `MOONDESK_JSON_TABLE_EVIDENCE` retains the actual HTTP outputs
when pointed to an existing directory.

Qualification covers native localhost HTTP and served HTML. It does not claim
graphical-browser interaction, accessibility, macOS desktop, deployment or a
full product test pass.
