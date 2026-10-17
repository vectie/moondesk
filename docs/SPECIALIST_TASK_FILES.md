# Give a creator fresh task files

Open **Packs → Agents → Build your specialist** and create or reopen a creator.
Under **Files for this task only**, choose a local UTF-8 text file. Inspect its
text and the updated **Review the exact brief**. You can add up to four files,
remove an individual file or clear the set. Supported inputs include plain text,
Markdown, CSV and JSON; binary Office/PDF files need a plain-text export first.

For a filled task form, select **Preview filled task** again after changing files.
For CSV tasks, select **Inspect CSV tasks**, then a row, after changing files.
Each preview contains the exact task and task-file text that will be prepared.
**Try in chat** or the task-specific prepare control uses the existing Book
identity check and unsent-work guard. Ordinary **Send** remains the only action
that submits the prepared chat to its configured runtime.

## Lifetimes and boundaries

- These are UTF-8 snapshots, not live paths. Filenames are labels, not Book
  `wiki/` or `raw/` references. Snapshot bytes are not truncated, normalized,
  interpreted as formulas, rendered as HTML, or installed as capabilities.
- At most four distinct plain filenames, 200 characters each; 32 KiB per file;
  64 KiB total; the complete prepared brief must fit the existing 48,000-character
  chat limit. Invalid UTF-8, blank/binary text, unsafe filenames, duplicate names
  and oversize content fail with existing files intact. Remove an old snapshot
  explicitly before replacing the same filename.
- Data remains in the current page only, separate from saved definitions, variants,
  portable creator exports and accepted MoonBook knowledge. Closing retains
  completed reads but cancels pending reads. Reload, switching/revising creators,
  or successful chat preparation clears the file set. Add files again explicitly
  for the next task or CSV row; there is no implicit batch-wide reuse.
- Newer file selection, Clear, removal and creator navigation invalidate pending
  reads and stale previews. Only the latest file selection can finish. Preparation
  is blocked while a read is pending. Book drift, failed reads and rejected chat
  preparation retain current files for explicit repair/retry.
- No file upload or provider run happens in this panel. The exact text becomes
  part of the normal prepared composer; inspect private data before ordinary
  Send. Existing Book context and runtime permissions still apply.

This fills a creator's task-input gap and supports MOONDESK-B04's selected-material
conversation authoring. It does not close the full cross-source search/anchoring
requirement, MOONDESK-B03 host round-trip, or any release gate. It introduces no
new accepted-knowledge store or permission grant.

## Verification

`bash scripts/test_specialist_workflow.sh` runs the production controller and
minimal DOM event adapters using built-in Node modules. Focused coverage includes
snapshot bytes/escaping, exact trial/form/CSV preparation, saved/export separation,
one-task lifetime, limits, invalid input, repeated/cancelled/stale reads, detached
controls, Book drift and unsent-work rejection. This is source-level JavaScript
qualification. Real-browser layout/accessibility, compiled/native lifecycle and
live provider execution remain unrun and unqualified.
