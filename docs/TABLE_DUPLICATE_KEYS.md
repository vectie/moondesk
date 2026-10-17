# Resolve duplicate CSV/TSV keys in a draft

Open a CSV or TSV with the ordinary source editor. **Resolve duplicate table
keys** lets you choose exact header checkboxes and **Preview: Keep first** or
**Preview: Keep last**. Multiple selected columns form an exact text tuple.
There is no trimming, numeric conversion, case folding or fuzzy match.

The preview shows every duplicate group, all original cells, the chosen
survivor, and the complete retained and removed record lists. Record numbers
count the header as record 1, regardless of quoted newlines. The surviving
records keep their original order. **Apply to unsaved draft** changes only the
editor; ordinary Save remains a separate operator action. Cancel leaves the
draft unchanged. Undo restores the draft immediately preceding this operation
until another edit or file change invalidates that scoped undo.

Blank or whitespace-only components are shown as unresolved blank keys and
are always retained, even if several blank records repeat. Correct these
explicitly before using the saved file as a lookup. No blank-key record is
silently discarded. Selecting different keys invalidates the preview, as does
editing the draft or changing files. First/last survivor choices are made by
their separate preview buttons; review the resulting policy before Apply.

For example, open `samples/table-duplicate-keys/customers.csv`, choose `id`,
and preview Keep last. Record 2 (`001,Old name`) is removed; record 3 (`002,Other`)
and record 4 (`001,Current name`) survive in that order. Both keys are nonblank
and unique, meeting the documented key precondition for [table lookup](TABLE_LOOKUP.md).
Save and reopen through the ordinary workflow before using the saved lookup.
The sample's native save/reopen and lookup consumer were not exercised here.

Bounds: 512 KiB UTF-8 input/output, 100 data records, 32 columns, nonblank distinct
headers, and equal-width records. CSV quoted multiline values and TSV are
supported by the existing parser. Output quotes every cell and uses LF record
separators. Browser textarea normalization also uses LF for embedded newlines.
This is a draft-editing extension, not full spreadsheet or Office fidelity.
