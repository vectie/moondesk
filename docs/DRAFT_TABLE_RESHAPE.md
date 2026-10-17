# Reshape the current CSV or TSV draft

Use this when an unsaved monthly export needs one row per account/month.
The source editor's **Reshape draft columns into rows** panel reads the
current textarea, including edits that have not been saved.

1. Open a `.csv` or `.tsv` file in the source editor and make any draft edits.
2. Check the exact measurement headers, such as `Jan` and `Feb`.
   Every unchecked column remains an identifier. Selecting every column is
   allowed, producing only the variable and value columns.
3. Enter explicit variable and value output names, for example `month` and
   `amount`. Names must be nonblank, at most 200 characters and distinct
   from each other and retained identifiers, including trimmed collisions.
   A removed measurement header can be reused as an output name.
4. Choose **Preview reshape**. Inspect the output headers and every output
   row. Source record numbers count the header as record 1, not physical
   lines. Preview and **Cancel preview** leave the draft unchanged.
5. Choose **Apply to unsaved draft**. This emits the ordinary editor input
   event; it does not write a file or invoke Save. Save explicitly if wanted.
6. **Undo reshape** restores the exact previous textarea value and selection
   while the scoped Undo is still available.

## Data and limits

Output follows source record order, then original measurement-column order,
regardless of checkbox selection order. Identifier values repeat beside each
measurement. Blank cells, repeated records, quoted multiline text, Unicode,
leading zeros, and formula-like strings remain literal text. Nothing is
calculated or type-coerced. CSV/TSV has no cell types: another spreadsheet
application may interpret `001` or `=1+1` on import.

Input and output are each limited to 512 KiB UTF-8, 100 data records and 32
columns. The existing strict CSV parser rejects malformed quoting, NUL,
missing data rows, and blank or trimmed-duplicate headers. Every record must
have exactly the header width. Header selection is exact, including case,
spaces and Unicode. Expansion record count, column count and serialized
UTF-8 size are checked before expanded rows are allocated. Serialized output
is reparsed and compared against all expected headers and values.

Every output cell is quoted. Record separators are LF. The browser textarea
already normalizes CRLF and CR to LF, including quoted multiline content;
the feature preserves the current textarea's cell values, rather than the
original file's byte encoding or line endings. A leading BOM is not retained
by Apply; scoped Undo restores the exact original textarea string, including
any BOM and original quoting. Use explicit Save only after review.

## Context and recovery

Draft edits, measurement or output-name edits, path/workspace changes,
replacement editor instances, and observed disabled/read-only transitions
invalidate stale previews and scoped Undo. Unsupported file types hide the
panel and discard its state. Apply rechecks the current text and all settings
against the preview. Undo is unavailable after later draft or settings edits.
Neither operation is durable across page reloads.

A failed replacement, retained-output check, or event dispatch restores the
pre-operation draft and selection and reports the failure. A failed Undo
similarly retains the already-applied draft. These operations do not read the
saved file or bypass existing Save/conflict handling.

The separate [saved-table explorer reshape](LOCAL_TABLE_RESHAPE.md) reads saved
files, supports additional formats, and exports separate files. This draft
panel is scoped to CSV/TSV editing with the smaller limits above.

## Validation scope

Product-native Node tests cover the pure transform and installed production
editor event handlers using a minimal DOM adapter with textarea newline
normalization. They cover preview, Apply, cancel, Undo, stale state, exact-name
selection, limits and injected replacement failures. Graphical-browser layout,
accessibility, native Save/reopen, external filesystem conflicts, MoonBit
build/check/test/info/fmt, clean-machine installation and full release gates
were not exercised for this draft feature. Existing release blockers remain.
