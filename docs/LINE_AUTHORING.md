# Edit a block of source lines

Open a supported text file in MoonDesk's source editor. Place the caret on a
line or select a block, then use the **Selected lines** toolbar:

- **Indent** adds the chosen indentation to each touched line.
- **Outdent** removes one leading tab, or up to the chosen number of spaces.
- **Duplicate lines** copies complete lines immediately below the selection
  and selects the copy for editing or repeated duplication.
- **2 spaces**, **4 spaces**, and **Tab** choose the indentation unit. Tab
  outdent removes up to four spaces when a line starts with spaces.

Keyboard shortcuts work while the source textarea has focus:

| Action | Shortcut |
| --- | --- |
| Indent | Ctrl/Cmd + ] |
| Outdent | Ctrl/Cmd + [ |
| Duplicate lines | Alt + Shift + Down |

Tab keeps its normal focus-navigation behavior. Composition events do not run
these shortcuts. Buttons remain available if a keyboard layout or operating
system reserves a shortcut. Undo and Redo use the existing source editor
history; every block action is one step. Save persists through the existing
host workflow.

A selection ending at the start of the following line does not include that
line. A caret, including a caret on an empty line, affects exactly its line.
The chosen indentation is kept with the open source tab. Reopening a file or
discarding/reloading its draft returns to the default two-space choice.

## Example: build a small code block

Use `docs/samples/line-authoring/main.mbt` as synthetic input:

1. Select its two `println` lines, ending at the start of `}`.
2. Choose two spaces and click Indent. Outdent reverses it; Undo restores it.
3. Place the caret in the `Launch` line and click Duplicate lines.
4. Edit the selected copy to print `Ready`. Use Undo/Redo to check the result.
5. Save, close the source tab, and reopen it.

The expected saved file is `main-authored.mbt` in the same sample folder.

## Scope and verification

MoonEdit owns UTF-16 range handling, indentation, exact line duplication and
atomic history. MoonDesk captures the textarea's current selection, exposes
buttons and shortcuts, restores the resulting selection and uses its existing
per-tab history and host save protocol. Actions are unavailable while loading
or saving. No language-server connection or provider configuration is needed.

This is explicit text authoring, not language-aware formatting. It does not
infer project indentation, offer multi-cursor block operations, or add native
desktop integration. The core preserves LF/CRLF and final-newline behavior;
the browser textarea retains its existing newline-normalization behavior.
Large-file performance and graphical-browser/desktop interaction are not
qualified by the compiled tests.

Focused compiled JS tests are in `main/source_line_authoring_wbtest.mbt`.
They cover buttons, shortcuts, UTF-16 textarea selection capture, ordinary
history, repeated edits, tab continuity, no-op outdent and disabled states.
The opt-in `main/source_line_authoring_live_wbtest.mbt` exercises the compiled
controller against an isolated native Desk host: open, indent/outdent,
duplicate, edit, undo/redo, save, close, reopen and compare exact output.
Its fixtures are disposable and must not point at a user's real workspace.

For that live test, set `MOONDESK_LITERAL_HOST_ORIGIN` to the local fixture
host and `MOONDESK_LITERAL_WORKSPACE` to its returned workspace ID. The host
must serve the sample as `src/main.mbt`. `MOONDESK_LINE_EVIDENCE` optionally
names an existing output directory for rendered control HTML. The round's
retained `verify.mbtx proof` prepares and runs that isolated journey.
