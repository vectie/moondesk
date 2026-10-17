# Build your specialist

## User workflow

1. Open **Packs → Agents → Build your specialist**.
2. Enter a name, purpose and a representative task.
3. Choose an installed, ready MoonBook. Choose preferred capabilities from its
   existing passport. Search within that Book and select up to 20 `wiki/` or
   `raw/` references. These are references, not copied or newly accepted knowledge.
4. Select **Create specialist**. Inspect the exact brief.
5. Select **Try in chat**. Desk refreshes the Book catalog, verifies Book identity,
   version and library, then prepares a fresh chat with the chosen files. Review
   the example and click ordinary **Send** to run it through the configured
   MoonClaw chat service. An unavailable service remains an ordinary chat error.
6. Return to **Build your specialist**, select **Revise**, change the work or
   selection, and select **Create revised specialist**. The revision number advances.
7. Select **Save specialist**. Close or reload Desk. Open the builder and select
   the named saved revision to reopen, revise or try it again.

A specialist here is a reusable, browser-local task brief over an installed
MoonBook. PackStudio continues to own pack create/install/activate. The creator
neither invents a new pack installer nor promotes the brief to adopted MoonBook
behavior. The existing passport owns the displayed inventory; capability choices
are preferences and confer no authority. Unselected capabilities are not a
security denylist. Existing Book context and configured runtime permissions apply.

## Persistence and interruption

- Saved definitions are browser-local and scoped to the exact Desk library on
  that origin. They do not sync across devices and clearing browser storage
  removes them. Saved entries carry Book ID, workspace ID, version, purpose,
  example, selected references and preferences.
- Closing the builder retains unsaved input only in the current page session.
  Reload restores explicitly saved definitions only.
- Cross-window saves are checked against the prior storage snapshot and the
  prior saved revision. A conflicting save retains the local draft and requires
  reopening the saved revision. Storage failures never report success.
- Changing the selected Book clears file and capability selections. Late search
  responses cannot attach another Book's files. A changed/removed Book version
  requires reselecting it. Files remain live references resolved at run time;
  source content is not pinned to a digest by this feature.
- Active chat, unsent Wiki or Code drafts (including image-only and pending Code
  submissions), document edits or review notes block example
  preparation. The creator retains the specialist so the operator can finish
  that work first. Duplicate Try clicks are single-flight.
- Cached and delayed conversation history cannot automatically replace a prepared
  example or its selected files. Already-queued automatic restores are checked
  again by the native reducer; deliberate Resume remains separate.
- Preparation is acknowledged by exact request ID. It is not a completed trial,
  provider result, permission grant, portable agent export or release acceptance.

## Existing integration points

- `GET /api/desktop/agents`: installed MoonBook passports.
- `GET /api/search?contract=pages-search.v1&workspace=...&mode=files&query=...`:
  exact Book-scoped knowledge discovery.
- Pack Home `open-specialist` signal lazily loads the creator.
- `prepare-specialist` uses the existing workspace selection and Wiki mode
  reducers, clears ambient previous-chat material, and stages selected file
  paths in `wiki_chat_file_paths`. The existing Send control uses
  `wiki_chat_submission_body` and the existing MoonClaw chat endpoint.
- Existing unsaved edit guards remain in force. No installation, provider call,
  scheduling or external effect is performed by creating or saving a definition.

## Verification

From the repository root:

```sh
bash scripts/test_specialist_workflow.sh
```

This runs production JavaScript controller code with explicit HTTP/storage and
minimal DOM fixtures, including visible create/try/revise/save/reopen controls
and the existing workspace runtime regressions. It does not claim a real browser
or native-host run. `main/specialist_builder_wbtest.mbt` covers exact staging,
context isolation and blocked conditions for the normal MoonBit UI test suite.

In the R563 cloud author environment, 57 Node checks pass. Focused MoonBit JS
tests, `moon info` and module-wide `moon fmt` are blocked before compilation by
missing declared `../../../moonleaf` workspace membership; the checkout also
has no restored UI dependency graph. The bundled `moonfmt` binary parses and
formats the five edited MoonBit files directly. No dependency substitute or
registry restoration was attempted. Browser startup is separately blocked and
was not retried. Live MoonClaw execution, compiled UI acceptance, native lifecycle,
layout/accessibility verification and production qualification remain open.


### Independent-review correction

The first R563 candidate missed the unsent MoonCode composer preserved while
visiting Pack Home, and automatic conversation restoration could erase a newly
staged example. The correction rejects preparation while Code draft/pending work
exists and distinguishes automatic history restoration from deliberate Resume.
Focused native tests cover the Pack Home transition and queued-restore race;
production JavaScript tests exercise cached and delayed history callbacks. Native
compilation remains blocked as above, so these native cases are source coverage,
not claimed executed passes.

## Compose saved specialist revisions

**Compose specialists** now turns 2–4 compatible saved specialist definitions
into one ordered reusable creator with explicit stage outputs/handoffs. It
uses the same guarded chat preparation path and preserves the source briefs
as revision snapshots. See [SPECIALIST_COMPOSITION.md](SPECIALIST_COMPOSITION.md)
for the workflow, limits, recovery behavior and focused verification.

## Reuse a creator with new inputs

Optional **Task template** fields now turn a saved specialist into a reusable
input form. Fill new inputs, preview the exact brief, and prepare through the
same guarded chat bridge without revising the saved creator. See
[SPECIALIST_TASK_FORMS.md](SPECIALIST_TASK_FORMS.md) for usage and recovery limits.

## Create independent variants from saved creators

In **Saved specialists**, select **Create variant of [name]**. Desk copies that
saved revision into an editable, separately named draft. Review the name and
fields, then use the ordinary **Create specialist → Try in chat → Save specialist**
flow. The variant gets its own ID and starts at revision 1. Later **Revise** updates
only the variant's own ID. Creating a variant does not alter or save over its
source, including any unsaved changes currently being made to that source.

The copy retains the source's Book identity, selected capabilities, knowledge
reference selections, reusable task form, ordered composition stages and their
saved source snapshots/handoffs. Each copy carries the immediate source ID,
source name and exact saved revision. These identify the origin of the copied
brief; they are not a digest or snapshot of knowledge file bytes. Reference
contents remain live and are resolved by the ordinary Book chat route. New task
input values and prepared previews are cleared, not copied into the variant.

The source and copy remain independently editable. If the saved source later
has a different revision, the builder shows that fact without silently refreshing
the copy. Copying a variant records that variant's own ID/revision as the immediate
source. The page retains an unfinished copy across Close/Escape; reload retains
only explicitly saved copies. Invalid lineage, identity collisions, conflicting
cross-window saves and storage failures cannot report a successful replacement.
A variant needs a different name from its immediate source; the existing 64-item
library, selected-reference and brief-size limits still apply.

`specialist-variants.test.mjs` and the mounted controls in
`specialist-builder-dom.test.mjs` exercise these workflows with bounded local
adapters. This adds an authoring/reuse convenience under the existing local
recovery and no-new-authority boundaries. It does not qualify MoonClaw runtime
review, anchored-discussion recovery or the complete progressive-disclosure PRD
acceptance. No provider job, pack installation, public graph import, accepted
Book behavior, synchronization, native build or real-browser visual result is
claimed by these tests.


## Prepare creator tasks from spreadsheet rows

A saved creator with a task form can import a local UTF-8 CSV, explicitly map
columns to fields, inspect per-row filled tasks/errors and prepare one selected
exact brief through the existing guarded chat bridge. Return to the builder for
another row; ordinary Send remains explicit for each task. See
[SPECIALIST_CSV_TASKS.md](SPECIALIST_CSV_TASKS.md) for limits and recovery.

After inspection, **Edit task inputs for CSV row N** now lets you correct a
blank/overlong input or adapt one valid row without reimporting or changing the
saved creator. Compare original/task values, apply, select the row and review
the refreshed exact brief. Cancel/reset preserve the imported cells; structural
CSV errors still require fixing the file. Corrections stay only in this page
session and are excluded from saved/exported creators.

To keep CSV mapping and applied corrections across reload, explicitly **Save
task checkpoint to file**. Reopen the same unchanged saved creator, **Restore
local task checkpoint**, then inspect/select again before preparing a fresh
brief. The checkpoint contains task data, including original unmapped columns;
review it before sharing. Task-only files and run results are excluded. See
[SPECIALIST_TASK_CHECKPOINTS.md](SPECIALIST_TASK_CHECKPOINTS.md).

## Explore imported creator tasks

After inspecting a CSV, JSONL or restored checkpoint, use **Explore task rows**
to search mapped input values, focus on correction or observation status and
order by an input. Source row numbers and exact task bindings remain unchanged
through selection, editing and preparation. Checkpoints and results retain
their complete original export scope. See
[CREATOR_TASK_EXPLORATION.md](CREATOR_TASK_EXPLORATION.md) for a worked example,
matching-versus-historical response filters, recovery and verification limits.

## Move a saved creator explicitly by file

In **Saved specialists**, select **Export [name]** to request a local
`.creator.json` download of that exact saved revision. The current unsaved draft,
filled task inputs and CSV rows are not exported. Export includes the brief,
Book identity/version, reference paths, capability preferences, optional task
template, variant lineage and ordered composition snapshots/handoffs. These are
user-authored definitions; review their text for private information before
sharing the file. No referenced knowledge-file bytes, origin/library storage,
credential fields, runtime grants or provider results are bundled. Downloads
are requested through the browser; Desk does not claim the file reached disk.

To reuse the file in another Desk library or browser:

1. Open **Build your specialist → Move a saved creator by file**.
2. Choose **Import local creator JSON**, then inspect **Review imported
   definition**. Import accepts the dedicated `moondesk.specialist-portable.v1`
   envelope, not a browser storage dump or a pack installer.
3. Explicitly choose **Bind to installed MoonBook**. Only ready installed
   passports with the exact Book ID/version and all selected capability
   preferences appear. The old workspace ID is informational. If multiple
   installed workspaces match, choose the intended one; there is no inferred
   match by name or silently substituted version.
4. Select **Use imported definition**. Desk refreshes the catalog and rechecks
   the chosen Book before replacing the current draft. **Cancel creator import**
   keeps that draft unchanged. This step does not save or send anything.
5. Inspect/edit the imported fields and follow ordinary **Create specialist →
   Try in chat → Save specialist**. Create allocates a distinct local ID at
   revision 1; original IDs/revisions are unverified provenance, never adopted
   creator identities. Composition source snapshots remain descriptive data.
   Both the main definition and stage references bind to the chosen installed
   Book. Ordinary Try refreshes that Book again and retains all chat/unsent-work
   guards; ordinary **Send** is still a separate action.

Imports reject unknown/authority/runtime fields, malformed templates and nested
stage snapshots, unsafe reference paths, incompatible contracts and invalid
UTF-8. Files are limited to 256 KiB (declared and actual bytes), and the full
brief must fit the existing 48,000-character chat limit. Other creator bounds
and local storage conflict checks still apply. No installation, network file
upload, other-origin storage access, implicit synchronization, source-content
pinning, permission grant or adoption into accepted Book behavior occurs.
Imported names, IDs and variant lineage are never trusted as local identity or
an authority claim. Creating a later local variant identifies its immediate
local saved source instead.

Cancel, New, Revise, saved-creator navigation and a newer selected file invalidate
obsolete asynchronous import completions. Close/Escape cancel pending work;
an already decoded review or adopted draft remains in the page session only.
Reload restores only explicitly saved creators. New edits during the adoption
catalog check prevent the callback from replacing those edits. A catalog error
retains a decoded review for explicit retry after reopening; a changed/missing
Book requires an explicit compatible selection. Reimporting creates another
independent draft, never an overwrite; saving it remains explicit. Storage
failure retains the created draft and never reports a successful save.

The focused `specialist-portable.test.mjs` and mounted controls in
`specialist-builder-dom.test.mjs` exercise file handling, exact Book rebinding,
composition/form preservation, new identities, ordinary guarded preparation,
cancel/repeated/stale operations and honest failures. These are bounded Node
controller/minimal-DOM checks. Actual browser download dialogs, visual/layout
and accessibility acceptance, compiled/native lifecycle, live MoonClaw execution
and full release qualification remain unrun blocking gates. The authored PRD
has no portable-creator acceptance item: this is source-scope implementation
only and does not close MoonClaw host round-trip, Work Package export, Published
Work graph import or progressive-disclosure acceptance.

## Bring fresh files to one creator task

**Files for this task only** adds local UTF-8 snapshots to the next exact trial,
filled form or selected CSV-row brief through ordinary guarded chat preparation.
The file text stays out of saved/exported creators and clears after preparation.
See [SPECIALIST_TASK_FILES.md](SPECIALIST_TASK_FILES.md) for limits and recovery.

## Maintain a composed creator's stages

While revising a composition, choose a saved **Replacement for stage N**,
compare the current/proposed brief snapshots, then apply it in place. This
keeps the stage's handoff and order, recomputes selected references, and leaves
Create/Save explicit. See [SPECIALIST_STAGE_REPLACEMENT.md](SPECIALIST_STAGE_REPLACEMENT.md)
for refresh, replacement, interruption and source-scope verification.
