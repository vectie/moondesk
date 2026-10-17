# Reusable creator task forms

Saved specialists previously staged only their representative example. Task forms
let their creator define the changing inputs once, then use that same revision
for different work without repeatedly rewriting or saving the creator.

## Use it

1. Open **Packs → Agents → Build your specialist**, create a specialist or reopen
   one and choose **Revise**. This also works for a composed specialist.
2. Keep a representative example for ordinary **Try in chat**. In **Task template**,
   enter for example `Compare {{topic}} for {{audience}} using cited sources`.
   Use 1–8 distinct lowercase input names, starting with a letter, with numbers
   and underscores allowed. Repeated placeholders use the same input value.
3. Create and save the specialist. Its optional task form is saved in the same
   browser-local, exact-library-scoped definition as its purpose and references.
4. Under **Use creator for a new task**, fill every input and choose **Preview
   filled task**. Review the exact complete brief, Book, references and stages.
5. Choose **Prepare filled task in chat**. Desk refreshes and verifies the actual
   installed Book and stages the exact preview through the existing guarded chat
   preparation bridge. Use ordinary **Send** there when ready.
6. Return and change inputs for the next task. The creator ID/revision, source
   stage snapshots, representative example and saved bytes stay unchanged.

## Recovery and limits

- Changing an input removes the preview and blocks preparation until a fresh
  preview is created. Literal replacement is single-pass; braces, `$` or markup
  within values are data, never additional template evaluation or HTML.
- Every input is required, maximum 4,000 characters. Templates and filled tasks
  each have an 8,000-character limit; the complete chat brief remains bounded by
  the existing 48,000-character limit. Invalid templates cannot be created or
  loaded from saved storage. There are no expressions, defaults or hidden inputs.
- Input values and previews are page-session-only. Close/Escape retains them;
  reload, switching creators, starting a new draft, or revising clears them.
  The task inputs are not saved to browser storage. Preparing the task intentionally
  stages its values in chat; ordinary chat persistence and submission rules apply.
- Preparation is single-flight. While the catalog refresh is pending, input
  editing is blocked. Closing cancels stale completion. Missing Books, changed
  versions/capabilities and existing native unsaved-work errors preserve the
  inputs and preview for correction/retry. Detached controls cannot prepare or
  edit a newer rendered state.
- A composed creator substitutes only its overall task. Captured stage examples
  remain illustrative context and handoffs remain unchanged. A source specialist's
  own form does not become another invocation inside a composition.
- Preparation is not execution, successful output, adoption or new authority.
  MoonClaw remains the runtime; MoonBook/Bookkeeper own accepted knowledge.

## Source grounding and qualification

The actual authored PRD `prd_work/content/moondesk.json` requires exact selected
material and truthful recovery scope (MOONDESK-B04), service ownership and no
implied execution authority (MOONDESK-B03), and contextual advanced controls
(MOONDESK-R03). This feature extends the real creator controller and mounted
builder described in SPECIALIST_BUILDER.md and SPECIALIST_COMPOSITION.md,
consistent with PRODUCT_CONTRACT.md and EXECUTABLE_BOOK_ARCHITECTURE.md.

Run `bash scripts/test_specialist_workflow.sh` from the repository, or invoke its
absolute path from anywhere. Production JS controller, mounted-control DOM
adapters, template boundaries and the existing workspace/history regressions
run on Node without external dependencies. No MoonBit source was changed.
Native compilation, the integrated production bundle, real-browser layout and
accessibility, actual MoonClaw/provider execution, long-lived host recovery and
release qualification are unrun. Tests do not fabricate those results.


## Spreadsheet-driven inputs

Saved task-form creators also support explicit CSV column mapping and row-level
inspection without changing their revision. The manual form remains independent.
See [SPECIALIST_CSV_TASKS.md](SPECIALIST_CSV_TASKS.md) for the import, inspect,
select, prepare and return workflow and its page-session-only recovery boundary.
