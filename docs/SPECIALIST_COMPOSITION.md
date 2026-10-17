# Compose specialist creators

## User workflow

1. In **Packs → Agents → Build your specialist**, create and save two or more
   single-stage specialists over the same installed MoonBook version.
2. Choose **Compose specialists**. Name the new creator, describe its overall
   purpose, and enter the actual representative task you want it to perform.
3. Add 2–4 saved specialist revisions. Enter each stage's **required output /
   handoff**, including the final stage's output. Move stages up/down or remove
   them until the visible sequence matches the work.
4. Choose **Create specialist**. Review the exact composed brief. It includes
   every source specialist's ID/revision, purpose, illustrative example,
   preferred capabilities, selected references, and required handoff.
5. Choose **Try in chat**. The existing Book validation and unsaved-work guards
   prepare the composed brief plus the deduplicated selected file references.
   Review it and use the ordinary **Send** control to ask the configured
   MoonClaw assistant to perform the ordered work in one conversation.
6. **Save specialist** retains the composition in this browser and exact Desk
   library. Reopen it after reload, or **Revise** its overall task, handoffs,
   stage order or stage membership and create the next revision.

This adds a reusable composed creator, beyond saving and reopening one brief.
For example, a researcher can hand cited findings to a critic, and a writer
can turn the critic's qualified findings into the final requested report.
The stages are task instructions for one ordinary chat. Desk does not create
independent agents, schedule a DAG, import a Work graph, or claim a trial ran.
MoonClaw remains the runtime, and Bookkeeper acceptance remains separate.

## Boundaries and recovery

- Composition uses a nested `moondesk.specialist-composition.v1` record on the
  existing `moondesk.specialist-preset.v1` definition. Legacy single-stage
  definitions remain readable without modification.
- Sources must be saved single-stage definitions from the same workspace ID,
  Book ID and Book version. Nested compositions, duplicate source IDs and
  self inclusion are rejected. The UI disables incompatible selections and
  the controller independently enforces the same boundary.
- Each source definition is copied as a revision snapshot. Later changes to a
  source do not silently change a composed creator. Use the explicit
  [stage replacement comparison](SPECIALIST_STAGE_REPLACEMENT.md) to adopt a
  newer saved revision or another compatible specialist in place, retaining
  its handoff and position. Original saved definitions are never edited by
  composition, stage removal, reorder, or composed-revision saves.
- References remain live paths; this feature does not pin file content or
  claim source freshness. The deduplicated union permits at most 20 knowledge
  references and 16 preferred capabilities. The final brief must fit the
  existing 48,000-character chat-preparation limit. Each handoff is required
  and limited to 2,000 characters.
- Stage reference/capability selections remain tied to the captured source
  definition. Change the source and explicitly replace its stage to alter
  those selections. Preferences confer no additional tool authority and do
  not create per-stage isolation or a security denylist.
- Close/Escape retains an unfinished composition in the current page session.
  Reload retains only explicitly saved definitions. Cross-window conflicts
  and storage failures preserve local drafts and existing stored bytes.
- Reordering retains each stage's own handoff. Detached controls cannot edit
  a reordered stage or replace a newer draft. Duplicate preparation is
  single-flight; the exact preparation acknowledgement remains distinct from
  a result. Missing or changed Books and native staging errors preserve the
  composition for correction.

## Source grounding

The authored MoonDesk PRD (`prd_work/content/moondesk.json`, 30 September
2026 evidence dossier) requires service ownership and truthful unavailable
states in MOONDESK-B03, exact selected material and explicit recovery scope in
MOONDESK-B04, and contextual advanced controls in MOONDESK-R03. This extension
preserves those contracts; it does not complete the PRD's separate
MOONDESK-B05 catalog-backed MoonFlow graph import qualification.

`docs/ROADMAP.md` calls for reusable book patterns. `SPECIALIST_BUILDER.md`
provides the existing saved-brief and guarded chat path. `PRODUCT_CONTRACT.md`
assigns composition UX to Desk; `EXECUTABLE_BOOK_ARCHITECTURE.md` retains
execution in MoonClaw and durable accepted knowledge in MoonBook. The new
feature reuses those real boundaries and consumes no missing Leaf/Edit source.

## Verification

Run from any working directory:

```sh
bash /absolute/path/to/moondesk/scripts/test_specialist_workflow.sh
```

The script checks both production JavaScript modules and executes 73 tests:
the prior 57 regression checks and 16 composition/controller/DOM-adapter
checks. Coverage includes visible source selection, handoffs, reorder/remove,
create/revise, save/reload, exact existing chat dispatch, source immutability,
stale Book/version/capability rejection, malformed stored composition,
combined reference limits, oversize brief rejection, failed saves,
interrupted preparation, Escape recovery and detached controls.

The existing workspace runtime lazy-imports `./specialist-builder.js`; that
module now statically imports `./specialist-composition.js`. Both paths are
inside the existing Vite source graph, with no absolute deployment path or
additional runtime registration. Tests verify this source route and execute
the imported modules, but do not claim a production bundle was built.

No MoonBit files were changed. Compiled UI, native lifecycle, live provider,
real-browser layout/accessibility and production qualification were not run.
Current Leaf/Edit source and the integrated UI dependency graph remain
unavailable; no older substitute, registry change, or browser retry was used.
