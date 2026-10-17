# Prepare a split column in the source editor

Open a saved `.csv` or `.tsv` in Desk's ordinary source editor. The **Derive a
column by splitting text** panel appends a new field without altering existing
cell values. It is available on the source draft, not the native View as table
page. The extension determines comma versus tab separators.

For `id,value` records containing `001, customer:: A01 `, enter source header
`value`, literal delimiter `::`, part `2`, new column name `customer_key` and
optionally select **Trim selected part**. Choose **Preview derived column**.
The first ten original/derived pairs are shown with the full record count.
Nothing changes until **Apply to unsaved draft**. Then the appended field is
ordinary editable source; use the normal Save action when ready.

Splitting is literal, case-sensitive and one-based. Missing parts become blank;
leading, trailing and adjacent delimiters can produce empty parts. Trimming is
off by default and only affects the derived value. Identifiers, formula-looking
strings, quotes, newlines and leading zeroes remain text. Every output field is
quoted and line endings become LF, so formatting bytes can change while
existing parsed cell values remain equal. The original BOM is not retained.

Cancel drops a preview. **Undo derived column** restores the exact pre-Apply
draft, including its original bytes represented in the text editor. Undo is
single-step and valid only for that exact unchanged post-Apply draft and file
identity. Other source edits or editor availability changes invalidate it;
ordinary editor undo behavior is not separately qualified. Changing a source
or parameter invalidates a preview. A failed editor application restores source
and selection without emitting a successful input event.

Bounds are inherited from the real task CSV parser: UTF-8 input and output each
at most512KiB, at most100 data records, nonblank distinct headers up to200
characters and at most31 input columns before appending the32nd. Header-only
inputs, malformed quotes, unequal record widths and duplicate headers reject.
The delimiter is nonempty and at most200 characters; part is1–999999. Output is
reparsed with the same parser before it can be applied. No type conversion,
formula execution, fuzzy matching or implicit source normalization occurs.

To use the prepared column with the existing native table lookup, save your
chosen draft, reopen it with **View as table**, and explicitly select the new
column as the source key. Matching remains exact under [TABLE_LOOKUP.md](TABLE_LOOKUP.md).
That native save/reopen/lookup journey was not exercised in this change.

Verification exercises the pure model, actual installed source-editor handlers
through minimal DOM adapters, rollback, stale review, scoped Undo, CSV/TSV and
existing source-editor/CSV regressions. Graphical-browser layout/accessibility,
native host, persistence and full-release qualification remain unrun.
