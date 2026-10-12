# Review and curate duplicate records

Use the saved table explorer to investigate repeated records, then download the
rows you want to keep. This is a local projection, not an edit to the saved file.
It works with CSV, TSV, JSON arrays, JSONL/NDJSON and a selected XLSX worksheet.

1. Open your saved table in MoonDesk's table view.
2. Optionally filter to the records you want to inspect.
3. In **Review duplicate records**, select **All rows with repeated keys**.
4. Choose **Match key**. Leave **All columns** for exact whole-row duplicates,
   choose one column for an identifier, or add a distinct **Second key** for a
   composite identifier such as account plus invoice number.
5. Apply exploration and inspect the repeated records. Switch to **First row for
   each key** or **Last row for each key** to curate one representative. **Only
   keys seen once** excludes every member of a repeated group.
6. Download the selected rows as CSV, XLSX, JSON or JSONL. Group summaries count
   and sum the same selected rows. Keep the original file for comparison.

For the shipped `docs/samples/table-duplicates/orders.csv`, Match key `id` gives:

| View | Amounts in saved order |
| --- | --- |
| First | 10, 7, 2 |
| Last | 7, 20, 2 |
| Only keys seen once | 7, 2 |
| All rows with repeated keys | 10, 30, 20 |

Filtering status to Open before choosing Last retains 7, 30, 2; sorting amount
numerically descending then displays 30, 7, 2. A region summary gives West 37
and East 2. Choosing id plus region instead keeps four distinct keys.

## Exact behavior and boundaries

- The operation order is filters, duplicate selection, sort, then summary.
  First/last uses saved row order among rows surviving filters, never sort order.
- Matching uses exact displayed text, with case and whitespace significant.
  Number 1 and text `1` match; `01` differs. Empty cells and empty text match.
  Formulas use cached displayed values without recalculation. Key matching does
  not change the type or value of the selected record in typed downloads.
- Composite keys encode field boundaries, quotes, newlines and Unicode safely.
  Duplicate header names remain selectable by displayed column number, but
  object-record exports still reject duplicate headers to avoid losing fields.
- No fuzzy matching, case folding, whitespace trimming, preference scoring or
  combining of fields from different records occurs. Inspect differences before
  choosing a representative.
- Selection and filters survive links and reload through URL parameters. Reset
  all clears them while retaining the current worksheet. Each request rereads
  the saved source; later edits can change the result. Column selections refer
  to positions, so reselect keys after changing source column order.
- Invalid active keys or unknown views produce a clear error. Switch to All rows
  or Reset all to recover. All rows does not apply stale key selections.
- Exports use the existing bounded table readers and writers. They are not a
  full-fidelity workbook round trip or an original-JSON reconstruction.

For scripted local links, use `duplicates=first|last|unique|repeated|all`,
`duplicate_key=<zero-based-column>` and optional `duplicate_key2=<other-column>`.
Omit both keys to compare all columns. Omit `duplicates` for the previous view.

Focused automated native localhost tests cover these routes. A graphical browser,
accessibility, macOS lifecycle and the full product are not newly qualified.
