# Compare a JSON reference with the current draft

Open a `.json` file in Code → Workspace editors → Source editor and expand
**Compare JSON versions**. Paste another JSON version in **Reference JSON
before the current draft**, then choose **Compare versions**. This answers
which nested values were added, removed or changed, even when object members
were reordered. It compares the entire current editor draft, including unsaved
changes. It does not change either input or save a file.

## Try the complete review

1. Open `docs/samples/json-comparison/current.json` in the Source editor.
2. Copy the complete contents of `docs/samples/json-comparison/reference.json`
   into the reference field. Choose **Compare versions**.
3. Review 2 added, 1 removed and 3 changed subtrees. `/account/plan` changed
   from `"trial"` to `"paid"`; `/account/legacy` was removed; `/orders/1/amount`
   changed from `10` to `12.5`; `/orders/2` was added; `/a~1b/~0flag` changed
   from `false` to `true`; `/enabled` was added with JSON `null`.
4. Choose **Select current value in editor** beside `/account/plan`. The exact
   `"paid"` value is selected. Existing **Back to location** restores your
   earlier selection and scroll position. Removed values cannot be selected in
   the current draft; their reference text remains visible.
5. Choose **Download difference report** to request `json-differences.json`.
   It contains all six differences with complete before/after JSON tokens,
   types and exact JSON Pointers. The download does not save your editor draft.
6. Correct values through ordinary editing or the existing **Explore JSON
   values → Replace displayed value** flow, then compare again. Use the normal
   Source editor Save action only when ready.

The sample's large identifier `900719925474099312345` and exponent `-0.00E+09`
remain unchanged. Reordered object members and `"\u4e2D"` versus `"中"` do not
produce differences. Comparison needs no server, provider or extra dependency.

## What counts as a difference

- Objects match exact decoded member names, ignoring order. Names remain case
  sensitive; whitespace in a key matters. Names containing `/` and `~` use
  JSON Pointer escapes `~1` and `~0`. An empty pointer means the root; `/`
  means an empty member name. Labels display quoted pointers so these differ.
- Strings compare their decoded contents. Equivalent Unicode/slash escapes do
  not count as changes. Reported changed values retain their exact original
  token spelling, rather than re-serializing their contents.
- Numbers compare exact tokens without conversion to JavaScript numbers.
  Large identifiers do not round. `1`, `1.0` and `1e0` differ; so do `0` and
  `-0`. This intentionally does not claim mathematical equivalence.
- Arrays compare zero-based positions. Inserting, removing or reordering an
  early item can report changes at subsequent positions. This is not a
  record-key join, sequence alignment or move detector. Use the saved-table
  comparison workflow for records with a unique identifier.
- When a type changes, or an entire member/array item is added or removed,
  one difference contains that complete subtree. Descendants are not counted
  again. The counts describe differing subtrees, not rows or individual keys.
- JSON `null` is a present value, distinct from an absent side. In a report,
  an absent side is JSON `null`; a present null has `type: "null"` and
  `json: "null"` inside its value descriptor.
- Changed/removed object members follow reference order; additions follow
  current-draft order. Arrays follow position. Formatting-only changes produce
  a zero-difference result, whose empty report is still downloadable.
- Any duplicate decoded member name anywhere in either input stops the whole
  comparison, including escaped spellings of the same name. Correct the
  ambiguous object first. The explorer can still inspect its parent separately.

## Report, review and recovery

The page shows 25 differences per page. **Previous differences** and **Next
differences** expose the rest; the download always contains the complete
report, not just the page. Each visible before/after preview is limited to
1,000 UTF-16 units and labels shortening. Selection and report use complete
values. Text is rendered as text, never as HTML or executable code.

The `moondesk.json-comparison.v1` report contains comparison rules, counts,
changes, workspace/path context and explicit input labels. Each present side
has `type`, `json`, `start` and `end`; the last two are zero-based UTF-16 offsets
into that particular input, not disk byte offsets. Raw JSON values are strings
inside the report, so opening the report does not round the original numbers.
It includes complete changed subtrees, which can contain private data. Review
before sharing. It excludes unrelated files and unchanged sibling subtrees;
it does not redact secrets inside changed values. A report is an inspection
output, not an executable JSON Patch, automatic merge, pinned saved-file
version, acceptance decision or signed receipt.

Editing either input clears the previous result and disables download/selection
until another explicit comparison. The pasted reference is retained when the
draft changes or the editor becomes unavailable. Loading/saving disables
controls and requires comparing again afterward. A stale page button cannot
select an old range. Switching files or workspaces, leaving JSON mode, closing
and reopening the editor, or **Clear comparison** forgets the reference and
report. Nothing is persisted across reloads. The source's existing save,
conflict, dirty-state and Undo/Redo boundaries remain in control of source edits.

Both inputs must be complete strict JSON documents: no comments, trailing
commas, JSONL, BOM or incomplete edit. Parse errors identify the reference or
current draft and the UTF-16 position. Each input uses the explorer limits:
120,000 UTF-16 units, 10,000 values and 64 nested containers. Literal unpaired
surrogates are rejected; escaped JSON forms remain supported. At most 1,000
differing subtrees and 1,000,000 combined pointer/value UTF-16 units are allowed.
An oversized comparison fails explicitly without returning a partial result.
Use smaller documents. Exactness is relative to textarea contents; preexisting
newline normalization/decoding may already differ from original file bytes.

Download status says requested, because the browser owns download acceptance
and destination. A browser download failure is reported without discarding the
comparison or changing either input.

## Qualification and product rationale

The actual `prd_work/output/MoonDesk_PRD.docx` names inspection and safe
before/after review in MOONDESK-UC01, UC02 and B02. This feature gives nested
JSON drafts a structural review route, distinct from line diff, one-value
replacement, and the existing flat saved-table comparison. It is a bounded
contribution to those requirements, not completion of their native/Office
acceptance gates or the MoonProj digest-bound acceptance handoff.

From the repository root:

```sh
node --test ui/rabbita-desk/source-json-*.test.mjs ui/rabbita-desk/source-code-outline*.test.mjs ui/rabbita-desk/source-navigation*.test.mjs ui/rabbita-desk/source-editor-runtime.test.mjs
```

The focused suite executes exact comparison and report parsing plus the actual
installed runtime event handlers with minimal DOM/Blob/download adapters. It
covers the sample review, current-value selection and navigation return,
no emitted source input during read-only actions, stale input invalidation,
invalid input recovery, paging, complete long-value export, disabled controls,
context reset, empty results and download failure. These are Node tests with
DOM doubles, not graphical-browser tests. The actual browser, clipboard,
textarea behavior, download destination, layout, accessibility, compiled
MoonBit host, Save/conflict/reload, native lifecycle and full product were not
executed for this change.

The existing lazy source-editor runtime includes this panel. The checked-in
production bundle was not regenerated. A normal UI rebuild in an appropriately
provisioned environment is required before packaged-app use. No Moon command,
dependency installation, network call or browser launch was needed. R50 remains
the last fully verified cumulative baseline; R51–55 remain separate.
