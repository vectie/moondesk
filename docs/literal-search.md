# Find and replace in the source editor

Markdown authors can also [navigate and reorder complete sections](MARKDOWN_OUTLINE.md)
with the same source editor and shared Undo / Redo history.

Open a file in Code → Workspace editors → Source editor. Enter literal text
in Find to see the current match and total count. Use Next / Previous to
navigate with wraparound. Match case is on initially; turning it off folds
ASCII A–Z, while other Unicode characters remain exact.

Enter replacement text, then choose Replace next or Replace all. Dollar signs,
backslashes, and regex metacharacters are ordinary text. Undo restores an
entire Replace all in one step; Redo reapplies it. Each tab keeps its own
search and edit history. Save uses the existing source-save command; closing
the clean tab and reopening loads the persisted contents from the host.

Keyboard shortcuts in the source textarea: Ctrl/Cmd+F focuses Find,
Ctrl/Cmd+G advances (Shift reverses), Ctrl/Cmd+Z undoes, Ctrl/Cmd+Shift+Z or
Ctrl+Y redoes, and Ctrl/Cmd+S saves. Enter in Find advances; Shift+Enter reverses.
The existing Open as table action for saved JSON/JSONL remains available.

Build the frontend from `ui/rabbita-desk` with the `moonedit`, `moonleaf`, and
`moondesk` directories as siblings. `moon.work` selects those local sources.
MoonEdit owns matching, selection navigation, and atomic replacement. Desk
owns immutable per-tab history and its existing preview/save transport.

Focused checks: run `moon test --target js main --filter 'source*'` in the UI
module. The opt-in `source_literal_live_wbtest.mbt` test runs the compiled UI
controller against a real native Desk host. Set `MOONDESK_LITERAL_HOST_ORIGIN`
to a loopback origin and `MOONDESK_LITERAL_WORKSPACE` to an isolated fixture
workspace ID; create `src/main.mbt` containing `😀 cat CAT cat` and
`literal [.*] cat`, each ending in LF. Run that file with `--include-skipped`.
The test replaces, undoes, redoes, saves and reopens this disposable file.

Validation includes real HTTP save/reopen and table view/export. A graphical
browser run was unavailable because the executor blocks Chromium's required
Unix sockets; no graphical click or layout result is claimed.
