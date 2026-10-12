# Format or compact JSON in the source editor

Open a supported text file in Code → Workspace editors → Source editor.
Choose **Format JSON** to make a dense payload readable, or **Compact JSON**
to remove whitespace between JSON tokens.

1. Select a complete JSON value to change only that part of a document.
   With just a caret, the command operates on the entire draft.
2. Choose **Indent with: 2 spaces / 4 spaces / Tab** for Format JSON.
3. Click Format JSON or Compact JSON. Inspect the selected result.
4. Undo/Redo restores the text and selection. Use the ordinary Save action when
   ready; layout changes remain unsaved until then.

The whole result stays selected, including backward selections, so another
layout action needs no reselection. Each change is one Undo step. No-op and
parse errors preserve Undo/Redo. Each source tab retains its own history and
indentation setting. Loading, saving and unavailable sources have disabled
controls. A stale stored selection asks you to select again.

## What stays exact

Formatting never converts JSON to an object and back. It preserves key order,
duplicate keys, huge integers, negative zero and exponent spelling, string
escapes, literal Unicode, and all non-whitespace tokens. Unselected text and
outer whitespace around the JSON value remain untouched. Compact retains outer
whitespace too, including the final newline.

Pretty layout uses the first LF's style in the selected input: CRLF if preceded
by CR, otherwise LF. If there is no LF, inserted line breaks use LF. Internal
mixed layout whitespace may normalize; strings are never normalized or trimmed.
Empty containers remain inline; nonempty arrays/objects use one member per line.

## Inputs and errors

Use one strict JSON value. Comments, trailing commas, JSONL streams, BOMs,
unquoted keys and partial selections are rejected without changing the draft.
The error reports a zero-based UTF-16 offset from the start of the selected
input, or the draft if there was only a caret. A scalar such as a string or
number is also a JSON value. An already compact value can be a no-op.

The bounds are 1,048,576 input UTF-16 units, 64 nested containers and 4,194,304
output UTF-16 units. An oversized result is rejected atomically. This does not
validate a domain schema, sort keys, repair JSON or change save/conflict policy.

## Try the fixture

Open `payload-before.json`, leave a caret in it, and choose Format JSON with
two-space indentation. Compare with `payload-pretty-actual.json`. Compact JSON
then matches `payload-compact-actual.json`. The duplicate `id` keys, large
integer, `-0.00E+09`, `\u4e2D` escape and CRLF ending remain exact. Undo twice
restores the input. `payload-rendered.html` is actual compiled editor markup
from this synthetic controller journey, not a browser screenshot or a deployment.

The core tests cover syntax, exact tokens, limits, UTF-16 errors, selected
boundaries, revision binding and atomic history on JS and native. Compiled Desk
tests cover textarea selection capture, controls, errors, per-tab history and
disabled states. No graphical browser, Mac launch, save/reopen, accessibility,
large-file performance or deployed UI qualification is claimed. Build the paired
source UI before deployment.

## Inspect nested values without formatting

Use [Explore JSON values](SOURCE_JSON_VALUES.md) to follow exact data paths,
select a nested value and download its current-draft JSON tokens unchanged.
