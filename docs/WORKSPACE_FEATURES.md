# MoonDesk workspace features

Status: implemented locally

Last verified: 2026-09-26

## User experience

MoonDesk remains a chat-and-document workspace. The five-stage system and the
general MoonClaw agent operate behind that surface; internal prompts, reasoning,
queues and tool mechanics are not presented as user workflow.

Use **Find** or **Choose document** to open **Find & Add**. Exact, Meaning,
Structure, Code and Issues providers search names, bounded contents, document
headings, declarations and review language; every result explains why it
matched. Work mode covers completed and active work. Results refer to existing
workspace paths. **Import copies** and **Import folder** remain separate,
explicit actions, so opening or attaching material never silently duplicates
it.

Drag a workspace item onto Find & Add, paste a safe workspace-relative path, or
select a result. DOCX, XLSX and PPTX selections open beside the general chat.
The chat is routed to the general MoonClaw agent, not the MoonCode profile.

Select text in a DOCX preview, or double-click a cell or slide object, to open
the anchored actions **Ask**, **Explain**, **Check**, **Improve**, **Use as
source**, and **Comment**. The prompt sent to MoonClaw includes the selected document, section,
reference and bounded visible quote. It does not expose editor or agent internals.

The **Review** button opens one document toolbox with seven quiet surfaces:

- **Review** maps warnings, proposed changes, evidence and review items back to
  their document or conversation location. Items can be marked reviewed.
- **Conversations** resumes, renames and archives bounded visible chat history
  and the general MoonClaw task ID from server-owned workspace storage. Starting a new conversation
  never changes the document.
- **Sources** gathers typed workspace, document-location, artifact, and web references in visible answers and
  pinned material. Stable answers also expose Copy, Use in document and Pin.
- **History** captures bounded saved and proposed Office states,
  compares any two captured versions and filters Content, Formatting, Formula
  and Layout changes.
- **Check packs** offers document quality, spreadsheet consistency, citation
  audit and presentation polish without exposing prompts or skill files.
- **Preferences** manages user-approved terminology, names, tone, and document
  conventions with workspace or global scope.
- **Inbox** reveals the selected MoonBook's real `inbox/` folder in Finder and
  keeps file/folder import as an explicit alternative.

When a supported Office item changes, MoonDesk shows a document-native review
with before and proposed values, semantic change labels, **Reject change** and
**Apply change**. Apply retains the existing baseline, conflict and package
validation contract.

Use **Synthesize** to pin documents, evidence or run artifacts. Pinned items keep
their workspace paths. MoonDesk can request a brief, report, presentation or
spreadsheet through the general agent, with source preservation and validation
included in the request.

**Background work** is intentionally quiet. It summarizes tasks, results and
review items without exposing the agent’s internal process. Automations explain
their purpose, cadence, next and last run, allowed source policy, review policy
and target book. A person may run an enabled automation once or open its results.
Only actionable warnings should interrupt normal work.

**Export Work Package** downloads a standalone HTML receipt containing the
visible conversation, selected document, completed work, artifacts, review
decisions, pinned sources and warnings. Hidden reasoning is excluded.

## Coding workflow

MoonCode keeps the canonical MoonClaw conversation central. Running work has
separate **Guide current** and **Queue next turn** actions. For Git MoonBooks,
Code shows the current branch and changed files, opens the existing source
editor, and provides per-file and per-hunk diff navigation. Untracked text
has a reviewable new-file diff; binary changes support a file-level decision.
Untracked MoonBit build output stays out of the review queue while tracked
files in those directories remain visible. Local review decisions and hunk
notes are saved under MoonDesk product state against the
exact patch digest; an edited patch makes earlier records stale and returns the
file to pending in review progress. Unsent notes remain in the review pane and
block ordinary file, session, and MoonBook switches until saved or discarded.
When all current Git changes have local review decisions, Code offers a link to
the separate MoonBook outcome review.
Changed-file context refreshes after new Code edit evidence or turn completion
when no review is open. A GitHub remote adds read-only PR, check, and linked
issue context with a visible local
HEAD match. Saved MoonBit files can request compiler diagnostics and typed
definition/reference locations through the MoonFort-bound Moon IDE route.
GitHub comment publication and multimodal Code turns are still under
implementation.

## Implementation boundary

- Durable workspace truth, search results, tasks, reviews and artifacts remain
  in MoonBook/MoonClaw-backed MoonDesk state.
- Modal, synthesis-board and review presentation state lives in the lazy
  `workspace-features-runtime.js` controller. This keeps transient UI state out
  of the large MoonBit model and preserves the production parse budget.
- Conversation archives are server-owned workspace records with atomic writes;
  local storage is an offline recovery copy. Follow-up drafts, review
  acknowledgements, enabled check packs, and Office history remain bounded
  presentation state. Only visible user/assistant/reference text is retained;
  hidden reasoning is never recorded.
- Search accepts a typed `mode` and an optional current-book scope. Host reads
  are confined and bounded to 512 KiB per candidate.
- Office apply/reject delegates to the established Office editor messages; the
  lazy controller does not write documents directly.
- Automation execution delegates to the existing request submission path.
- Production builds use Terser and keep workspace features and MoonCode
  developer tools in separate lazy chunks. Bundle sizes are reported by the
  build test without enforcing temporary size limits.

## Verification

Run:

```sh
moon check --target js --warn-list +73
moon test --target js
npm run build
npm run test:bundle
npm run test:i18n
npm run test:workspace-features
```

Also exercise Find & Add, synthesis, automation cards, the background-work
disclosure and Office before/apply/reject behavior through the real browser UI.
