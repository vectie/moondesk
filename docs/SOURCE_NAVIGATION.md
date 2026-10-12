# Source location navigation

MoonDesk's existing source editor now provides **Go to location**, **Back to
location**, and **Forward to location**. This is a local, read-only navigation
workflow for following diagnostic locations and returning to the working text.
It does not run a compiler, apply an edit, or save a file.

1. Open a supported source file. Enter `12` or `12:3` in **Line:column**, then
   choose **Go to location** or press Enter. Ctrl+G / Cmd+G focuses this field
   from the source textarea. Lines and columns are one-based; columns use UTF-16.
2. Follow a local F12 definition or an existing compiler definition/reference
   result. These jumps now share the same navigation history.
3. Choose **Back to location** to restore the original selection, selection
   direction and scroll position; choose **Forward to location** to revisit
   the target. A new successful jump discards the forward branch.
4. Cross-file jumps use the existing source path/Open controls. History is
   committed only once the destination editor is enabled and ready. If opening
   fails or is interrupted, **Cancel navigation** releases the pending jump
   without claiming the destination was reached. It does not cancel host I/O;
   a later file load can still open normally, without applying a pending caret.

An invalid line/column gives an inline status without moving the selection.
Locations beyond a line and positions splitting an astral Unicode character
are rejected. CRLF line endings count as one line break. A history return after
text changes bounds the old selection to current content (without splitting
surrogates) and explicitly reports that the text changed. This is not semantic
position tracking across revisions.

History is session-only and bounded to 50 origins plus 50 forward locations.
It retains source text references only to detect changed-text returns; no
source content or navigation history is written to storage or sent over the
network. Changing workspace clears history and pending navigation. Typing in
the source editor cancels a pending jump. Saving/disabled editors cannot be
navigated until the existing host enables them. No new source read/save API or
permissions are introduced. Navigation does not grant access to another book.

## Qualification

The implementation is the existing JavaScript source-editor runtime plus a
small location/history module. Node tests exercise the installed runtime event
handlers against explicit DOM doubles, including actual Open control dispatch,
local F12, Enter and Ctrl/Cmd+G routing, delayed destination readiness, exact
selection/scroll return, invalid input, changed text, cancellation and workspace
isolation. These tests do **not** qualify rendered browser layout, accessibility
in a real browser, native MoonDesk, compiler service availability, or filesystem
persistence. The MoonBit host/reducer and MoonEdit library are unchanged.

Run from `ui/rabbita-desk`:

```sh
node --test source-navigation*.test.mjs source-editor-runtime.test.mjs workspace-features-runtime.test.mjs workspace-features-performance.test.mjs
```

PRD trace: `MOONEDIT-W01` (navigate the text revision), `MOONDESK-UC01` and
`MOONDESK-UC02` (browse and inspect supported source files), and `MOONDESK-N02`
(context continuity). The underlying offline editor library already owns
revisioned edits; this closes a host navigation gap rather than adding a new
editor core or file format.

The [local code declaration outline](SOURCE_CODE_OUTLINE.md) provides discoverable,
filterable entry points into the same current-draft navigation history for
MoonBit, JavaScript, TypeScript and Python. It is distinct from the editable
Markdown section outline and is explicitly lexical rather than compiler-backed.
