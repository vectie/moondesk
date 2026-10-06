# Human revisions of exact MoonProj output

The first slice supports one UTF-8 text output, at most 256 KiB, including an
empty edited result. From a currently unaccepted MoonProj task, open an exact
output in Desk, choose **Edit current text file**, edit, then choose **Save
revision for this task**. Return the retained revision to the same task for
review. No agent is asked to recreate the edit.

## What is saved

The action saves a separate immutable human revision. It never writes the
agent's live workspace file. The editor's base is the current file observed
when editing began, which may differ from the original agent-produced or
previously reviewed bytes. If that base has changed before capture, the editor
shows the current file and preserves the draft. The user can explicitly use
the displayed current file as a new baseline and save a new revision.

The host retains the exact draft, output lineage and base observation under
`.moonsuite/products/moonproj/human-revisions/<revision_id>/`. Only the final
`revision.json` publishes a return-ready revision; `content.txt` contains its
retained edited bytes. The manifest has contract `moonproj.human-revision.v1`
and `capture_scope: immutable_human_revision`. It binds task, original run,
session, original command, workspace, producing output command/path/evidence,
human authorship, base-current-file digest and edited-content digest/byte size.
It does not contain a new runtime command, model, promotion receipt or task
acceptance. Existing generic file editors are unchanged.

## Return and review

The return link contains only the revision ID and the existing task navigation
context. MoonProj reads the canonical captured revision and exposes it as a
separate `human_revision` result source. The user can inspect the retained
text, explicitly select it, submit a report and accept that report through the
existing review flow. Returning alone does none of those mutations. Original
execution, agent follow-ups and older reports keep their existing identities
and receipts. Accepted/done tasks remain inspection-only.

## Interrupted work

Desk retains the exact draft and pending operation identity in this browser
before sending capture. A missing response is retried with the same ID/input.
Once the base-observation marker is durable, retry finishes that same retained
revision even if the live file later changes or disappears. A definite
conflict remains a conflict for that identity. Failed storage/capture never
becomes a displayed success; drafts are preserved. Oversized edits are kept
intact with explicit feedback rather than truncated.

Current native session/Book identity verification remains required on recovery,
including archive and output-reference checks. If the native daemon is
unavailable after a response is lost, Desk displays the retained operation ID
and exact draft as confirmation pending; it does not infer a saved result from
local intent. Refresh/retry resumes that same operation when identity readback
returns. There is no daemon/provider workaround or automatic task import.

## Qualification

Source/reducer/handler verification is recorded with the isolated feature
evidence. Full mounted application, HTTP/Postgres integration, provider calls
and live browser behavior require separate qualification. Saving a revision
does not establish task correctness, customer approval, revenue or a receipt
for executing the edited artifact.
