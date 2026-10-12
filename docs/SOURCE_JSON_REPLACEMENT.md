# Review and replace one nested JSON value

Open a `.json` file in Code → Workspace editors → Source editor, then expand
**Explore JSON values**. You can now correct a nested field or replace a whole
subtree without selecting its text range by hand or rewriting the rest of the
file. This uses the current draft, including unsaved edits, and requires no
server request, agent, provider or additional dependency.

## Try the complete correction

Open `docs/samples/json-values/orders.json` in the source editor:

1. Enter `/orders/0/details/paid`, then choose **Inspect pointer**. The selected
   value is the JSON boolean `false`.
2. Choose **Replace displayed value**. Its complete current JSON tokens are
   copied into the **Replacement JSON value** field.
3. Change the replacement to `true`, then choose **Preview replacement**.
4. Review the displayed pointer, before/after types, lengths and JSON text.
   The draft has not changed yet.
5. Choose **Apply replacement to draft**. Only the selected value changes;
   the inserted value remains selected. The result matches
   `docs/samples/json-values/orders-paid-draft.json`.
6. Use the existing source editor **Undo** or **Redo** controls to change your
   mind. Choose the normal **Save** action when ready. Applying a replacement
   does not save the file or bypass the host's external-change conflict flow.

The large ID `900719925474099312345`, `-0.00E+09`, `\u4e2D`, duplicate members
in the separate review object, source order and surrounding whitespace remain
untouched. You can also replace `/orders/0/details` with a complete JSON object,
an array or any scalar. An empty pointer replaces the root value while retaining
whitespace before and after that root, including a final newline.

**Cancel replacement** closes the form and discards its input without editing
the draft. An identical replacement is a no-op: Apply stays disabled. Invalid
replacement JSON displays an error and leaves the draft unchanged; correct the
replacement and preview again.

## Exactness and review scope

The operation replaces one source range. It never parses numbers into
JavaScript numbers or serializes the rest of the document. All untouched draft
text and all interior replacement tokens/whitespace remain exact. Whitespace
outside the replacement's single root value is excluded. Exactness is relative
to textarea text, not original on-disk encoding or line endings. Textarea
normalization may already have changed those before this feature runs.

The whole draft and replacement must each be one strict JSON value. Comments,
trailing commas, JSONL, BOMs and incomplete values are not accepted. A JSON
string needs quotes: `"ready"`; a boolean uses `true` or `false`; an empty
string is `""`, not an empty input. This does not validate a schema, rename or
remove keys, insert array elements, or import JSON Patch operations.

Pointer selection follows [the explorer's exact JSON Pointer rules](SOURCE_JSON_VALUES.md).
An ambiguous duplicate-key descendant cannot be replaced. Its unambiguous
parent can be replaced as a whole. A replacement object may itself contain
duplicate members; their tokens are preserved, and later ambiguous descendants
remain unavailable rather than silently picking one member.

Before/after previews display at most 4,000 UTF-16 units per value and clearly
report shortening. Apply uses the complete replacement, not that shortened
preview. Use **Select value in editor** and the full replacement field to
inspect longer values. The source, replacement input and combined output must
fit the explorer's 120,000 UTF-16-unit, 10,000-value and 64-container-depth
limits. A replacement that fits alone may exceed the limits in its destination;
that case is rejected before changing the draft.

## Interruptions and recovery

- Review binds the entire draft, displayed pointer and exact replacement input.
  Changing any of them requires another preview. Even a change elsewhere in the
  draft invalidates the review. Replacement input is retained after a draft
  edit so you can review it against the current value.
- Merely typing into the pointer field does not change the displayed target.
  Inspect it first. The replacement review always names the displayed target.
- Choosing another value, switching file/workspace, leaving JSON or reopening
  an editor clears the replacement form. It is not persisted across reloads.
- Loading/saving/unavailable editors disable the controls and invalidate a
  prepared review. A missing or ambiguous target stays unavailable until you
  choose a valid pointer or repair the draft.
- Apply consumes its review. A repeated click cannot add another edit. It
  dispatches one ordinary bubbling `input` event on the source textarea, the
  same established boundary used by local completion. The existing
  `EditDraft` reducer owns dirty state, bounded Undo/Redo and eventual Save.
  This feature does not add an independent file writer or history stack.

## Qualification

From the repository root:

```sh
node --test ui/rabbita-desk/source-json-*.test.mjs ui/rabbita-desk/source-code-outline*.test.mjs ui/rabbita-desk/source-navigation*.test.mjs ui/rabbita-desk/source-editor-runtime.test.mjs
```

The pure JavaScript tests execute exact-range preparation/application, sample
output, root/subtree type changes, exact keys, ambiguity, invalid JSON and
combined bounds. Minimal DOM adapters execute the actual installed source
runtime event handlers: open/edit/preview/apply, one emitted source input,
selected result, value download, no-op/cancel, stale review recovery, disabled
controls, context switches, long previews and insertion failure recovery.

These are Node tests with DOM doubles, not a graphical browser. Emitting one
input event is verified; the compiled MoonBit reducer, actual host Undo/Redo,
Save/conflict/reload, browser textarea behavior, layout, accessibility, native
host and full product were not executed for this change. The inspected existing
source wires that input to `SourcePane(EditDraft(value))` and records one history
entry for a changed draft. That source inspection is not host qualification.

The existing lazy source-runtime import includes this UI. The checked-in
production bundle has not been regenerated; rebuild through the normal UI
workflow in a suitably provisioned environment before using it in a packaged
app. No dependency installation, network access, browser launch or Moon command
was needed. R50 remains the last fully verified cumulative baseline; R51–55
remain separate, and this is a separately focused-tested source change.
