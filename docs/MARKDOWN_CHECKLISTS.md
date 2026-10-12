# Author Markdown checklists

Open a text source in MoonDesk, select the lines to change, then use the
Markdown checklist controls beside the existing selected-line actions:

- **Make checklist** adds `- [ ] ` to eligible plain lines.
- **Mark complete** changes recognized unchecked tasks to `[x]`.
- **Mark incomplete** changes recognized `[x]` or `[X]` tasks to `[ ]`.
- **Remove task prefixes** removes only a recognized bullet/checkbox prefix.

A caret affects its line. Selections affect whole touched lines; an ending
position at column zero excludes that final line. Each action is one Undo
step, and repeating the same action does not create another history entry.
Save uses the normal source editor workflow; these controls only change the
draft. They do not run tasks or synchronize an external task service.

LF and CRLF endings, Unicode content and transformed UTF-16 selections are
retained. Ordinary lines can have zero to three initial spaces. Creation
conservatively skips blanks, four-space/tab-indented code, existing tasks and
lines starting with `#`, `>`, `-`, `+`, `*`, or a digit. Thus numbered prose
and existing list bullets are intentionally left alone rather than guessed.

Recognized tasks have zero to three leading spaces, `-`, `+` or `*`, one space,
`[ ]`, `[x]` or `[X]`, and one space before the content. Other spellings are
left unchanged by marking/removal. Removing prefixes preserves indentation.

Top-level backtick and tilde fences with up to three leading spaces are
excluded, including their opening and closing lines. A selection crossing
a fence changes eligible lines outside it only. An unclosed fence excludes
the rest of the document. This is a bounded source-authoring scanner, not a
full CommonMark parser: container fences, HTML blocks and front matter are
not interpreted. Check the visible result before saving such documents.

## Try it

Open `docs/samples/checklists/release-before.md`. Select the two lines
beginning “Review” and “Confirm”; choose Make checklist. Put the caret on
“Review” and choose Mark complete. The result should match
`release-after.md`. Undo twice restores the original, and Redo twice restores
the checklist. A fenced literal example stays unchanged.

The compiled reducer/render tests cover this sample, selection capture,
repeat/no-op behavior, undo/redo, CRLF and Unicode. They are not graphical
browser, native desktop, keyboard accessibility, or storage qualification.
Rebuild the UI distribution from source before deployment.
