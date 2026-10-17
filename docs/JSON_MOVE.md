# Move and reorder JSON creator steps

The existing source editor can now move an exact JSON value between containers
or reorder members/items in one container. It extends Explore JSON values;
it does not create another source editor or save a file automatically.

1. Open `docs/samples/json-move/creator.json` in the normal source editor.
2. Expand **Explore JSON values**, inspect `/steps/1`, and choose
   **Move displayed member or item**.
3. Keep destination `/steps` and position `0`, then choose **Preview move**.
   Inspect the source container before/after removal and the destination
   before/after insertion. The draft is still unchanged.
4. Choose **Move in draft**. The read-inputs step is first, and the explorer
   selects `/steps/0`. The identifier's exact numeric spelling is retained.
5. To defer a step, inspect it, set destination `/later` and position `0`, then
   preview/apply. Use the editor's existing review and Save controls when ready.

Destination is an exact JSON Pointer into the original draft. Position is a
zero-based insertion index in that container **after the source is removed**.
For a three-item array, moving the first item to position `2` makes it last.
An object destination also needs a unique decoded key (an empty key is valid);
arrays ignore this field. Use `~0` for a tilde and `~1` for a slash in pointers.
Moving to a later sibling's container correctly adjusts its path after removal.
Moving the document root, into oneself/one's descendants, through an ambiguous
duplicate key, or over an existing object key is rejected without changing text.

The moved value's complete raw JSON text is preserved, including large integers,
decimal/exponent spelling and string escapes. Other value tokens stay exact;
container separators and the moved object member's key/colon formatting may
change. No semantic references elsewhere in the document are rewritten.

Apply is one ordinary editor input event. A changed draft, source identity,
displayed pointer, destination/key/position or editor availability invalidates
the preview. Cancel preserves the draft. Previews show up to 4,000 UTF-16 units
per before/after section and disclose shortening. The existing 120,000-unit,
10,000-node and 64-container explorer bounds apply to the complete result.

Tests exercise the production range-editing code and installed runtime handlers
using DOM adapters. They do not qualify real-browser layout, native host,
Undo/Redo history or Save/reopen persistence. Native MoonBit sources and public
interfaces are unchanged. PRD trace: MOONDESK-UC01/UC02, especially direct editing
with review while retaining exact source context.
