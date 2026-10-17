# Resume creator tasks after interruption

To collect responses after working through tasks, use the adjacent
[creator task-results workflow](CREATOR_TASK_RESULTS.md). It captures
operator-entered responses against exact task inputs and exports downstream
JSON/CSV/Markdown. Results remain separate from these input-only checkpoints.

An explicit local task checkpoint connects imported CSV tasks, applied row
corrections and the existing saved-creator/chat workflow. Previously, reloading
Desk discarded the CSV, mapping and corrections. A checkpoint lets you return
without reimporting the spreadsheet and repeating that work.

## Save, reload and resume

1. Open **Packs → Agents → Build your specialist** and reopen a saved creator
   with a task form. Import a CSV, map columns, inspect tasks and apply any row
   corrections. Partial mappings and original invalid rows can also be saved.
2. Choose **Save task checkpoint to file**. Apply or cancel a pending row edit
   first. Check that your browser actually downloaded the `.creator-tasks.json`
   file. Desk reports a download request, not a verified disk write.
3. After reload, reopen the same unchanged saved creator. Under **Use saved
   creator with spreadsheet rows**, choose **Restore local task checkpoint**.
   Successful validation replaces the current batch. Invalid files leave the
   current batch, corrections and pending row editor unchanged.
4. Choose **Inspect CSV tasks**. Original and corrected values are available
   for comparison. Inspect structural/field errors, select a ready row and
   review the fresh exact brief. Mapping remains locked while corrections exist.
5. Choose **Prepare selected CSV task in chat**, then use ordinary **Send**
   separately. Restoration neither prepares a chat nor records task completion.

Try the portable CSV and instructions in
[`samples/creator-task-checkpoint/`](samples/creator-task-checkpoint/README.md).

## Contents and privacy

The file includes the exact original decoded CSV text (including unmapped
columns), CSV filename, explicit mappings, applied input corrections and an
allowlisted creator definition with Book identity/version, selected reference
paths, optional lineage and ordered composed stage snapshots/handoffs. CSV
quoting, BOM, line endings and lexical cell text are preserved. Corrections
remain distinct from original cells; the source CSV is never rewritten.

The file contains task data and user-authored creator text. Review private
information before sharing it. This is explicit local file output, with no
upload or automatic browser-storage persistence. Unknown legacy storage fields,
task-only files and their contents, pending row edits, manual task-form inputs,
inspected briefs, selection, request IDs, grants and run results are excluded.

Clear task-only files before restoring. This prevents unrelated current files
from silently entering resumed briefs. Add intended files again explicitly, then
inspect rows again. Export may be used while completed task files are present,
but does not include them; an in-flight task-file read blocks export. A task-file
read started during restore causes restore to fail while retaining both the
existing batch and selected file.

## Exact-definition and recovery boundary

- Restore requires the current creator to be saved, unchanged and identical to
  the checkpoint's allowlisted definition. This includes ID, revision, Book
  workspace/version, template, preferences, reference paths and every composed
  stage snapshot/handoff. Matching only the name or revision is insufficient.
- This path cannot create, import, revise, rebind or recover a lost creator. A
  separately imported portable creator receives a new local ID and will not
  match an old task checkpoint. Keep the original saved creator available.
- A checkpoint is editable, untrusted input data, not a signed artifact or an
  execution/acceptance receipt. No cached preview or selection is accepted.
  Reference paths remain live; this does not pin knowledge-file bytes.
- Supported JSON has exact field allowlists, valid UTF-8 and a 4 MiB file limit.
  Embedded CSV retains its 512 KiB, 100-row and 32-column limits. Corrections
  require complete valid mapped inputs and structurally valid rows; task and
  complete-brief size limits are rechecked. Original invalid rows stay visible.
- Changed/unavailable local creator storage fails safely. Close/reopen after an
  external save, then select the exact matching saved creator. A read in flight
  rechecks storage and creator identity before applying.
- Close/Escape, clearing tasks, revising or switching creators cancels unfinished
  restore reads. A newer CSV/checkpoint read owns replacement. Late failures do
  not overwrite new data or status. In-memory batches still clear on reload;
  only a file explicitly downloaded and later restored crosses that boundary.
- Book/version/capability refresh, single-flight dispatch and ordinary unsent
  work guards remain required at preparation time. Missing services remain
  unavailable. There is no bulk Send, provider call, scheduling or execution.

## Verification and scope

From the source root:

```sh
node --test ui/rabbita-desk/specialist-task-batch.test.mjs ui/rabbita-desk/specialist-task-csv.test.mjs ui/rabbita-desk/specialist-builder-dom.test.mjs
```

The production parser/controller and minimal mounted DOM tests cover a fresh
controller resume, exact-definition binding, literal/invalid input preservation,
privacy, download failure, stale controls/reads, cross-window changes, concurrent
task files, Book drift and guarded one-row preparation. Existing creator tests
remain separate regressions. These are source-level event-flow checks, not a
rebuilt UI or real-browser/native/provider qualification. Known absent
MoonLeaf/MoonEdit workspace members and prior browser denial remain unchanged.
No Chromium launch was retried.

MOONDESK-B04 and MOONDESK-R03 are contextual source-scope anchors for recovery and
task-context controls. This adjacent creator workflow closes no authored PRD
criterion and changes no status, estimate, runtime authority or release gate.
