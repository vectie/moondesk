# Write and reorder Markdown sections

Open a Markdown file in **Code → Workspace editors → Source editor**. The
Markdown sections panel updates from the current draft, including unsaved edits.
Each row shows the heading level, title, and one-based line number.

1. Select a heading to focus and select its whole section in the editor. The
   selection includes its text and deeper subsections, stopping at the next
   heading of the same or shallower level. Edit normally in the textarea.
2. Use **Up** or **Down** to move that section past an adjacent sibling. Nested
   sections stay together, and a section cannot move out of its parent.
3. Use the existing **Undo / Redo** controls or shortcuts. Each move is one
   step and shares history with typing and find/replace; each tab keeps its own.
4. **Save**, close the clean tab, and reopen to load the persisted Markdown.

Try `samples/markdown-outline/launch-plan.md`. Move **Customer communication**
above **Release checklist**, undo and redo, then change “Draft launch email” to
“Launch email ready”. Saving produces `launch-plan-reordered.md`. The fenced
heading example remains part of Smoke tests and does not appear in the outline.
These are synthetic sample files, not real commitments or customer data.

## Scope

The panel is enabled for `.md`, `.markdown` and `.mdx` source paths that the
existing host can open as text. It recognizes `#` through `######` headings
with up to three leading spaces, optional closing hashes, and backtick/tilde
fenced code. Inline Markdown is displayed as source text, safely escaped.
Setext headings, heading-like content inside HTML/front matter, container
headings and MDX syntax are not parsed. Use closed fences and ordinary ATX
sections for reordering. This is a source editor, not a rich Markdown renderer.

Moving sections retains their source text and nested headings. For a file with
no final LF, the separating line endings travel to the new boundary so the
headings remain separate and no final LF is added. Regular LF and CRLF inputs
are covered. Large-document/streaming performance is not qualified.

## Developer verification

MoonEdit owns parsing, ranges, selection and atomic movement. MoonDesk reuses
its existing immutable edit history, selection-to-textarea bridge, and source
transport. No dependency or host persistence protocol is added. Build with the
`moonedit`, `moonleaf`, and `moondesk` sibling layout selected by `moon.work`.

Focused compiled UI checks: `main/source_outline_wbtest.mbt` alongside
`main/source_literal_search_wbtest.mbt`. The opt-in
`main/source_outline_live_wbtest.mbt` uses a real, isolated native Desk host.
Copy the initial sample to `launch-plan.md` in a disposable workspace, set
`MOONDESK_LITERAL_HOST_ORIGIN` to the loopback host and
`MOONDESK_LITERAL_WORKSPACE` to its ID, then run the test with
`--target js --include-skipped`. It selects, reorders, undoes/redoes, edits,
saves and reopens that file. Optional `MOONDESK_OUTLINE_EVIDENCE` saves rendered
HTML into an existing directory. The retained round runner also checks the
persisted file byte-for-byte against the expected sample.

Evidence covers compiled controllers, HTML rendering and actual localhost
save/reopen. It does not establish graphical clicks/layout or macOS desktop
qualification. No browser launch was attempted for this feature.
