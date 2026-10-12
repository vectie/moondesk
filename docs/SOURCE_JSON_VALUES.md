# Explore and download a nested JSON value

Open a `.json` file in Code → Workspace editors → Source editor, then expand
**Explore JSON values**. This works on the current draft, including unsaved
edits. It needs no server request, agent, provider or additional package.

Try `docs/samples/json-values/orders.json`:

1. Choose the `orders` child, then `0`. The preview shows the first order.
2. Choose **Select value in editor** to select that entire object. The existing
   **Back to location** button restores your prior selection and scroll.
3. Choose **Download value JSON**. The browser receives `json-value.json`,
   containing that object only. It matches `first-order-value.json` in the
   sample folder, including the large ID, `-0.00E+09` and `\u4e2D` spelling.
4. Choose **Parent** or **Root** to keep exploring. Arrays and objects show
   50 children per page with **Previous values** and **Next values**.
5. Alternatively enter `/orders/0/details/paid` and choose **Inspect pointer**
   (or Enter). The preview and download now contain the JSON boolean `false`.

The pointer field is an input to **Inspect pointer**. Merely typing there does
not change the currently displayed value. **Select** and **Download** act on
that displayed value, identified in the status immediately above them.

## Paths and exact data

An empty pointer selects the root value. `/` selects an object member whose
name is empty. Array positions start at zero, without leading zeroes. Object
keys match exactly, including case, whitespace and Unicode. In a key, write
`~1` for `/` and `~0` for `~`: the sample's `/a~1b/~0label` selects `"🚀"`.
There is no URI-fragment (`#/…`), percent-decoding, JSONPath or wildcard syntax.

The explorer indexes source ranges instead of converting JSON values to
JavaScript objects. Selection and download retain all tokens and interior
whitespace, including numeric precision, exponent spelling, duplicate members,
string escapes, and literal Unicode. Surrounding whitespace outside the
chosen value is excluded, and no final newline is added. A scalar, `null`, an
empty array and an empty object are all downloadable JSON values. Output is
UTF-8, MIME `application/json;charset=utf-8`.

A parent containing duplicate keys remains inspectable and downloadable, but
a pointer through a repeated key is ambiguous and is refused. Both duplicate
children are marked unavailable rather than choosing one silently. For the
sample, `/review` downloads both `tag` members; `/review/tag` reports the
ambiguity. An escaped and unescaped spelling of the same decoded key count
as the same key.

## Edits, navigation and recovery

- Editing refreshes the active pointer against the current draft. If the key
  no longer exists, the preview clears and selection/download stop. The pointer
  is retained so you can correct it, use Parent/Root, or undo the edit.
- The entire draft must be strict JSON before any value can be explored.
  Incomplete input, comments, trailing commas, JSONL, and BOMs show an error
  with a zero-based UTF-16 offset. Fixing the draft restores the explorer.
- If the draft changes without the editor's ordinary input event, the next
  action refreshes it and asks you to inspect before selecting/downloading.
- Loading/saving/unavailable editors have disabled controls. Non-JSON source
  files do not show this panel. A file/workspace change or close/reopen resets
  the pointer to root. Pointers are not stored across page reloads.
- The preview shows at most 4,000 UTF-16 units and explicitly reports shortening.
  Selection/download still contain the complete selected value. Browser
  download acceptance or destination is owned by the browser; the panel says
  the download was requested, not that a file was saved successfully.

Inspection, navigation and download never alter source text, source-edit
history, dirty state or the host save protocol. Normal save/conflict/recovery behavior is unchanged.
Exactness is relative to the current textarea draft; existing textarea newline
normalization or decoding may already differ from on-disk bytes. Literal
unpaired UTF-16 surrogates are refused because UTF-8 download would replace
them; a JSON escape such as `"\ud800"` is retained exactly.

## Scope and verification

The explorer accepts at most 120,000 UTF-16 units, 10,000 JSON values and 64
nested containers. It is buffered and intended for modest local documents.
Inspection does not evaluate numbers, repair JSON or validate schemas.
Use the explicit [reviewed value replacement](SOURCE_JSON_REPLACEMENT.md) flow
to change one displayed value in the unsaved draft.

This fills a different workflow from [JSON layout](JSON_LAYOUT.md), which
changes whitespace in a draft, and [JSON tables](JSON_TABLES.md), which reads
a saved array of records into a flat projection. Nested objects and scalar
roots are available here without saving or flattening. Existing
[source navigation](SOURCE_NAVIGATION.md) supplies location history, while
this panel discovers exact data paths and produces reusable JSON subtrees.

From the repository root:

```sh
node --test ui/rabbita-desk/source-json-*.test.mjs ui/rabbita-desk/source-code-outline*.test.mjs ui/rabbita-desk/source-navigation*.test.mjs ui/rabbita-desk/source-editor-runtime.test.mjs
```

Focused Node tests execute the real installed source-editor runtime with
minimal DOM, Blob and download adapters. They cover the sample traversal,
exact output, selection/Back, changed and invalid drafts, ambiguity, paging,
file/workspace switches, disabled controls, close/reopen reset and download
failure. Existing navigation and declaration-outline tests also run. The
close/reopen case creates a fresh editor surface with supplied source text;
it does not exercise host file save/reload.

The production source runtime is wired through the existing lazy source-editor
load. The checked-in distribution bundle has not been regenerated: rebuild
the normal UI in a suitably provisioned environment before using this change
in a packaged app. No graphical-browser/file-download, native desktop,
accessibility, MoonBit compile, provider or full-product qualification is claimed.
