# Improve a creator from an observed task

Open **Packs → Agents → Build your specialist**, use a saved creator with a CSV
task form, and save an operator observation as described in
[creator task results](CREATOR_TASK_RESULTS.md).

1. Choose **Improve creator from observation N**. The original creator ID and
   revision, captured inputs/task, response, notes, complete brief and task-only
   file snapshots remain available together. Historical observations use their
   captured task, even when the current CSV row or task files have changed.
2. Write the concrete correction in **Purpose / concrete correction**. Adjust
   the ordinary name, example, reusable form, knowledge selections or composition
   fields as needed. **Create specialist** requires a changed purpose and makes
   a separate variant; it does not modify the source creator or save anything.
3. Review the full corrected brief. **Prepare same captured task in chat** uses
   that variant with the exact captured filled task and task-only file contents.
   Changes to the reusable template affect future tasks, not this fixed retry.
   The existing chat bridge checks the installed Book and unsent-work guards.
   A failed preparation keeps the correction and context. Successful preparation
   still requires the ordinary explicit **Send** in chat.
4. Reopen the builder and choose **Save specialist** to persist the correction
   as an ordinary creator. Its source lineage is the existing variant metadata.
   Save/reopen and portable creator export/import use the existing formats.
   This does not establish that the correction improved an output.
5. **Return to original observations** restores the original batch after Save.
   Before Save, the return button explicitly discards the unsaved correction.
   **Download original observations JSON** is also available while editing, so
   exporting the source evidence does not discard correction work.

Close/Escape preserve the current session. Reload does not persist refinement
context, observations or task-file bytes. New/import/switch controls are disabled
until the operator explicitly returns to the original batch. A completed
observation stores a session-local copy of its already-validated task files;
existing observation, task-checkpoint and creator export schemas are unchanged.
An older observation with missing file snapshots cannot be silently retried:
the complete original brief must reconstruct exactly or refinement is refused.
Knowledge paths remain live and do not pin Book file contents. Responses remain
operator reports, never execution receipts, accepted lessons or success claims.

## Qualification

Five new focused tests cover the helper and actual mounted builder controls:
source/task/file preservation after live edits, ordinary correction and Save,
fresh-controller reload, portable export, simulated unsent-work refusal, retry,
Close/Escape, literal response display and explicit discard. Existing Node
workflows and all 315 Node tests pass. The mounted journey uses a DOM adapter
and simulated bridge acknowledgements, not a real browser or provider run.

The declared MoonLeaf/MoonEdit workspace siblings remain absent. Compiled
UI/native, actual Send/provider execution, installed lifecycle, browser layout,
customer acceptance and release qualification remain blocked or unrun. No
MoonBit source/API, dependencies, Book learning authority or authored PRD
acceptance status changed. This addresses the B03/B04/R03 adjacent creator loop.
