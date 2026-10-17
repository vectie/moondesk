# Remove a JSON member or item from a creator draft

MoonDesk is a place to create creators and inspect their working files. Existing
JSON exploration, replacement and insertion did not let operators remove an
obsolete task or property without manually repairing commas. This extends the
same source editor (MOONDESK-UC01/UC02); it does not write files automatically.

Open docs/samples/json-removal/draft.json in the source editor. Expand Explore
JSON values, inspect /tasks/1, and choose Preview removal of displayed member or
item. Compare the parent before/after, then choose Remove from draft. The editor
returns to /tasks so the shifted array positions are visible. Inspect /obsolete
and repeat for an object property. Cancel leaves the draft unchanged. Use the
existing editor Undo/Redo or Save controls when ready.

Only the selected member/item and its necessary separator are removed. Surviving
number and string tokens retain their original spelling, including large integer
values. The document root is not removable; replace it with an explicit value
instead. Missing/ambiguous duplicate-key pointers cannot be removed. Changing the
draft, source, pointer or editor availability invalidates the preview.

The explorer's existing 120,000 UTF-16-unit, 10,000-node and 64-container limits
apply. Before/after previews show at most 4,000 units each and disclose shortening.
Apply always uses the complete prepared range and emits one existing draft-input
event. No source file or external service is changed by preview or draft editing.

Tests: node --test ui/rabbita-desk/source-json-*.test.mjs

51 focused tests pass, including installed production click/input handlers via a
minimal DOM adapter. Real browser layout, native host, Undo/Redo history ownership,
Save/reopen and full release gates are not qualified by these tests. Native inputs
and public MoonBit interfaces are unchanged, so no native build/info/fmt was run.
