# Wrap selected text in Markdown

Open a supported text file in the source editor. Select the exact text to
mark up, then choose **Wrap bold**, **Wrap italic**, or **Wrap code** beside
the existing line tools. These add source delimiters and keep the original
content selected for immediate editing. Each click is one Undo step; Redo
restores it. At a caret, delimiters are inserted with the caret between them.
Use the ordinary Save action when the draft is ready.

These are explicit wrapping actions, not toggles or a rich-text Markdown
formatter. Repeating a click adds another pair. Bold inserts `**` and italic
inserts `*`. Existing Markdown, punctuation, leading/trailing whitespace and
surrounding delimiters can change how emphasis renders. Select the intended
words without edge spaces and inspect the source/preview. Empty pairs are
an authoring starting point, not a promise of rendered formatting.

Code chooses a backtick delimiter longer than any backtick run inside the
selection. It pads selected edge backticks, and paired edge spaces around
nonblank content, so ordinary code-span content survives Markdown's padding
rule. Source line endings are retained even in multiline selections; a
Markdown renderer may normalize code-span newlines to spaces. The tool does
not interpret surrounding code fences, HTML blocks or other Markdown syntax.

UTF-16 positions support emoji and backward selections. The host now captures
selection direction and restores backward selections without collapsing
them; previously its range check dropped backward ranges. A stale out-of-range
stored selection leaves the draft unchanged and asks you to select again.
Unavailable/loading/saving sources cannot be changed by these controls.

## Try it

Open the kit's `inline-before.md`. Select `Release 😀` and choose Wrap bold.
Select the literal `` `status` `` on the second line and choose Wrap code.
Compare with `inline-actual.md`. Undo twice restores the input, Redo twice
restores the output. Both files use CRLF line endings.

The compiled controller/render tests exercise this journey, actual textarea
selection capture, backward selection, Unicode, repeated actions, empty and
multiline selection, invalid stored selection, and undo/redo. The public core
also checks stale revisions and embedded backticks. No graphical browser,
desktop, accessibility, file-save/reopen or large-file qualification is claimed.
The UI bundle must be rebuilt from source before deployment.
