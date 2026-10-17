# Maintain a composed creator without rebuilding its stages

A saved researcher can improve while a report creator still holds its old
brief. Previously, using the newer definition meant removing the stage and
adding it again, losing its required output/handoff and its position. Stage
replacement updates that one snapshot explicitly and preserves the work around
it. It can also replace an unavailable/deleted source with another compatible
saved specialist.

## Use it

1. Open **Packs → Agents → Build your specialist**. Open the saved composed
   creator and select **Revise**. Replacement also works while authoring a new
   composition.
2. At the stage you want to change, choose **Replacement for stage N**. Select
   the current saved source to refresh its snapshot, or a different saved
   single-stage specialist. The menu shows saved names and revision numbers.
   Incompatible Books, duplicate stages and already-identical definitions are
   disabled. A differing saved definition with the same ID is called out, but
   never adopted automatically.
3. Select **Review replacement for stage N**. Compare the current and proposed
   source name/ID/revision, Book identity, purpose, representative example,
   preferred capabilities and selected knowledge paths. The unchanged required
   output/handoff is shown beneath the comparison.
4. Select **Apply stage replacement** to update the draft, or **Cancel stage
   replacement** to leave it alone. Applying preserves the stage's exact
   position and handoff and recalculates the composition's deduplicated
   reference/capability selections. Check that the handoff still makes sense
   for the replacement; edit it if needed.
5. Select **Create revised specialist**, inspect the exact composed brief, then
   **Save specialist**. This advances the composed creator's own revision and
   keeps its ID. Neither source specialist is modified. The existing Save
   conflict and storage-failure handling remains in force.
6. **Try in chat** prepares that exact updated brief and its selected references
   through the normal Book check and unsent-work guards. Ordinary **Send** is
   still required. The configured assistant receives the selected stage
   purposes and required outputs in order, within one conversation.

For example, change an evidence-gathering stage from a saved researcher's
revision 1 to revision 3 while retaining “Pass cited findings and unresolved
questions to the critic.” The critic remains second, and its final-report
handoff remains intact. The new exact chat brief contains revision 3's purpose,
example and references, not the retired stage's selections.

## Recovery and boundaries

- A comparison never changes the draft or storage. Apply changes only the
  current draft. Create and Save are separate. Repeated Apply cannot apply
  twice or advance a revision; cancelled/detached controls do nothing.
- Editing any draft field or handoff after comparison makes Apply reject the
  old comparison and retain the edits. Compare again. Stage reorder, removal,
  addition, creator navigation, Close and Escape cancel pending comparisons.
  Close/Escape keep the unfinished draft in this page session. Reload restores
  explicitly saved creators only.
- A source changed or deleted in another window blocks comparison/application
  until Close and reopen refreshes the saved library. The local draft remains
  intact. A missing source is never invented; another compatible saved source
  can be chosen explicitly.
- The replacement must be a valid saved single-stage definition over the same
  exact workspace ID, Book ID and version. It cannot duplicate another stage,
  contain itself, or expand the union beyond 20 references/16 preferred
  capabilities. The ordinary Create step still validates the entire composition
  and its 48,000-character brief limit. An oversized replacement may require
  shortening or replacing the draft before it can be created.
- The catalog loaded by the builder checks authoring compatibility. Ordinary
  Try refreshes the catalog again; comparison does not establish installed
  health at execution time. Capability preferences confer no authority.
- Saved source definitions are brief snapshots. Knowledge-file bytes remain
  live references, not digest-pinned evidence. Imported composition source IDs
  remain unverified provenance; choosing a local replacement explicitly copies
  that selected local definition and does not infer lineage or freshness.
- R626 task-only files and filled task inputs stay outside source snapshots.
  Revise clears them as before; a late pending file read cannot populate the
  revised creator. Fresh task-only files added after Create apply only to the
  next prepared brief and remain absent from Save/export.

## Source scope and verification

This is a local creator-editing/reuse workflow grounded in
`SPECIALIST_COMPOSITION.md`'s explicit snapshot-replacement contract,
`PRODUCT_CONTRACT.md`'s Desk composition ownership, and
`EXECUTABLE_BOOK_ARCHITECTURE.md`'s MoonClaw runtime / MoonBook truth boundary.
MOONDESK-B04 (selected material and recovery) and MOONDESK-R03 (contextual
controls) are contextual PRD anchors only. This does not satisfy their full
acceptance criteria or qualify MoonFlow graph import, accepted Book behavior,
provider execution, receipt handoff or Work Package export.

Run `bash scripts/test_specialist_workflow.sh` from the repository root.
R635 passes 145 tests of the actual production JavaScript controller, mounted
minimal-DOM controls and existing workspace runtime. Eleven focused controller
checks and two mounted-control journeys cover renamed/revised/deleted sources,
exact save/reload/prepare, handoff/order preservation, cancelled/repeated/stale
operations, incompatible Books, source/selection bounds, save failure and
R626 task-file isolation. The test adapters do not establish browser layout,
keyboard accessibility or compiled/native behavior.

The broader 34-file Node suite initially reported 267 passed and one failed:
the minification test could not import absent `terser`. That same failure
reproduced unchanged in the accepted R626 base. Restoring the exact locked
minifier exposed absent Vite config imports; restoring those exact locked
versions too resolved the gate. With the private external test dependency
graph and resolver hook, the unchanged minification checks pass 3/3 and the
full Node suite passes 268/268. The locked versions are Terser 5.50.0, Vite
7.3.2 and @rabbita/vite 0.2.0, with their transitive versions from the source
lockfile, downloaded from official npm with install scripts disabled. Source
package/lockfiles and dependency directories are unchanged. Original failures
and restoration provenance are retained in the R635 evidence directory.

This checks existing bundled-asset fixtures as well as production JavaScript;
it does not rebuild the UI or qualify those older bundled assets as containing
this feature. Full UI build remains unrun with absent Leaf/Edit workspace
members. Browser launch was not retried. Native lifecycle, live MoonClaw/provider
execution and release gates remain unrun and unqualified. No MoonBit source or
interface changed.
