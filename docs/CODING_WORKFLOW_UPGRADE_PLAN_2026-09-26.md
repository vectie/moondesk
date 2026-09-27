# MoonDesk coding workflow upgrade

Status: active implementation plan, 2026-09-26.

## Implementation checkpoint

The implementation now covers Phases 1 and 2 and a substantial local review
slice of Phase 3. Phase 1 has separate running-turn guidance and next-turn actions,
stable draft handling, idempotent retry identity, localized action labels,
and focused state tests. Its live
MoonClaw acceptance and keyboard flow still need an installed test runtime.

Phase 2 has a bounded read-only Git projection at
`/api/workspaces/<id>/git`, a Code change list, and one-click opening in the
existing source editor. Tests cover a real temporary repository, detached
HEAD, remote presence, staged rename, untracked paths, a plain MoonBook, a
broken repository, stale workspace responses, and rendered statuses. Desktop
and narrow browser checks confirmed the conversation remains reachable after
opening a changed file. MoonDesk product state under `.moonsuite` is excluded
from the Git change projection even in a repository without ignore rules.
Untracked MoonBit `_build` and `.mooncakes` output is also kept out of the
review queue; tracked files under those paths remain visible.
Code history now distinguishes MoonBooks with the same display title by adding
the folder name only for duplicate titles. At 390 px, the session rail is
shorter and scrollable so the composer and primary action remain visible.

Phase 3 now has a read-only per-file Git diff endpoint and a Code review pane
with Previous/Next file and hunk navigation. It compares HEAD with the
combined staged and working tree state, includes rename paths, synthesizes a
bounded text diff for untracked files (including files inside new directories),
and offers file-level review for binary
changes. The request is limited to
a path in the current change list. The UI drops responses for a different
workspace, path, or HEAD. A local review journal now saves file decisions and
hunk notes under MoonDesk product state, anchored to the exact HEAD and patch
digest. The server rechecks that anchor before each write; records for a
different patch are reported as stale instead of silently reattached. Notes
can target an exact old or new diff line; the server verifies the line exists
in the exact patch before saving. Renamed files reveal earlier-path records as
stale history. Repository-wide review progress revalidates each saved decision
against the current patch digest, so changed files return to pending. The
change list has a path search and All/Pending/Reviewed/Needs changes filters;
their counts and states come from the revalidated journal. Review
notes block ordinary file, session, and MoonBook switches until saved or
discarded. A stale save keeps the exact unsent note; refreshing the diff
reanchors the view without silently moving its selected line. Repository and
review-progress responses carry a request generation so older replies cannot
overwrite a newer same-HEAD refresh. The change list refreshes after new Code edit evidence or a watched
turn becoming terminal when no review is open. GitHub
context now discovers a strict `github.com` remote and shows open PRs for the
current branch, check states, closing issues, and whether the PR head matches
local HEAD. It reports missing auth or network separately. A connected
acceptance check against `vectie/moondesk` found an open PR for a fixture
branch and showed its mismatched remote head in the Code UI. A separate PR
conversation draft now posts a top-level GitHub comment only after the server
rechecks the discovered repository, selected branch, local HEAD, and live open
PR head. The UI keeps the draft when publication fails or the target becomes
stale, and distinguishes this public PR comment from MoonBook-local file
review notes. PR conversation drafts can now be saved in MoonDesk product
state and restored on reopening the PR; a saved draft for a PR absent from the
open list remains inspectable and discardable. The local draft inventory stays
available after an app restart even when GitHub is offline, provided the
MoonBook still has its GitHub remote. An unsaved edit remains in the active
window until explicitly saved. A read-only connected probe confirmed
the live GitHub PR API returns the head ref and SHA used for this check. This
conversation comment is separate from the new remote line review. The remote
review now loads the PR base-to-head file patches and allows a line comment
only when the local HEAD matches the open PR, with branch identity checked
when a branch is attached. The server rechecks the
PR before and after paging through files and again before posting; it validates
the base, head, file patch digest, hunk, side, and exact line. Binary and
oversized patches remain visible as files without a line-post control. PR
line drafts have a separate local store, restore across restarts, and remain
inspectable and discardable when GitHub is offline. Each saved draft keeps its
own exact line anchor, so several lines in the same PR can be drafted without
overwriting one another. Changing file, hunk, or line while text is unsaved is
blocked with a recovery message; changing the selection after saving clears the
active composer while retaining the saved draft inventory. An unsaved line draft
stays in the active window and blocks closing; a saved draft can be closed. Failed
publication retains the exact text. Disposable GitHub PR
[#5](https://github.com/vectie/moondesk/pull/5) supplied the connected write
check. Code restored a saved conversation draft after reload and published a
top-level comment; its exact right-side line 4 review posted an inline comment.
Advancing the remote head blocked a later saved line draft and retained its
text. The status no longer stays on "posting" after failure, and the client
now decodes the server's bounded rejection message. The QA PR was closed and
its remote branch removed. The connected PR file review was inspected in the
in-app browser at desktop and 390 × 844; native-app visual and keyboard QA
for PR publication remain open. An unsigned local MoonDesk app
was later built with an explicit local Lepusa checkout and its Code setup
screen inspected at desktop and 392-pixel width; that does not exercise the PR
draft composer. A read-only connected request
against the fixture PR confirmed GitHub returns base/head SHAs and file patches
with the fields consumed by the new projection; that request did not exercise
MoonDesk's guarded write path.

Code now discovers up to 20 open PRs for the selected repository, including
PRs from other branches. A guarded checkout action rechecks the live PR and
its exact head, fetches the GitHub PR ref into a private local ref, verifies
the fetched SHA, and creates a detached sibling worktree under the MoonBook
library. The original checkout and its dirty files remain in place. The new
worktree appears as a MoonBook and can be opened explicitly in Code; a changed
PR head creates a separate versioned worktree. Reopening an existing worktree
with the same Git common directory and exact HEAD reuses it; a conflicting
folder still fails closed. Local validation covers the request guards and
dirty-source isolation. Connected fixture QA fetched public PRs #2 and #3
from `vectie/moondesk`, kept a dirty source file intact, opened both MoonBooks,
and loaded PR #3's review diff from detached HEAD. No GitHub write was sent.
A changed PR head, stale-head rejection, and failure recovery still need a
disposable PR acceptance run.

Phase 4 already had a multi-buffer source pane, local search and highlighting,
and MoonFort-backed compiler diagnostics. Definition and reference buttons had
been present, but their backend correctly refused execution because it lacked
a typed capability. MoonClaw now has a bounded, workspace-bound `moon-ide`
MoonFort route with verified terminal receipts. MoonDesk uses that route for
definition and references and keeps dirty-buffer and non-MoonBit guards. Moon
IDE navigation now requests JSON locations, confines them to the selected
MoonBook, and ignores late responses after an edit, file switch, or workspace
switch. A saved source file restores compiler actions, and the source editor
receives more width when no Office document is open. Large source files stay
editable in plain text after local highlighting and structural diagnostics
pause, rather than making keystrokes wait for full recoloring. A browser check
opened a 128 KB MoonBit file, typed into it, and discarded the edit; the source
stayed visible, highlighting stayed paused, and the file returned to its saved
length. Desktop and narrow layouts were also inspected with a saved source
file open. Direct `moon ide --json` checks resolved a symbol across two files.
Local completion now maintains `aria-controls`, `aria-expanded`,
`aria-activedescendant`, and selected-option state while the keyboard moves
through suggestions; Tab closes the list and continues normal focus order.
An isolated MoonDesk–MoonClaw control probe authenticated successfully. A
fresh native MoonClaw executable now builds and serves the disposable
MoonBook fixture with its private control configuration. The fixture lacks an
operator-owned MoonFort executor configuration. This phase still needs live sandbox acceptance, navigation
result QA through the UI across files, and the complete keyboard/focus pass
before the editing gate can close.

A managed-daemon restart exposed a MoonDesk launcher bug: the fixed child
environment omitted the path to the private MoonDesk–MoonClaw control file.
The launcher now passes that path, plus an explicitly configured app-data root,
through its bounded environment. Its focused regression passed, and the
rebuilt fixture restarted MoonClaw with authenticated Code status and the
image-capable model catalog intact.

The remaining Phase 3 acceptance checks and unfinished Phase 4–7 deliverables
remain open. Real-executor scheduled Code work still requires connected
acceptance; the schedule owner and UI path
are implemented and exercised with a disposable local MoonBook below.

Phase 5 now has an ordered `content_parts` command contract for text and
PNG/JPEG/WebP images. MoonDesk and MoonClaw validate canonical base64,
signatures, media type, ordered text equality, four-image and 16 MB total
limits. MoonClaw journals the bounded bytes with the command, reconstructs
the ordered media message on planner restarts and follow-up calls, and keeps
only a receipt in planner checkpoints. The canonical user turn retains ordered
text and image references, including an image-only turn. Image bytes remain in
the validated journal, outside session/watch responses. An authenticated
MoonClaw media route and a bounded, same-origin MoonDesk proxy fetch each image
when the transcript renders it. The Code composer has picker, paste, and drop intake, previews,
remove controls, and retry retention after a failed submit. MoonGate's declared
input modalities reach MoonClaw routing and the Code model chooser; models
without declared image input are blocked with a visible explanation. Alternate
unowned media fields still fail closed. Codec, UI state, and daemon package
checks pass locally. Connected QA found that the native adapter copied
validated `content_parts` into the generic payload during session creation;
MoonClaw correctly rejected that duplicate. The adapter now carries media
only in the canonical native field, with a regression using the creation
passthrough. A disposable loopback image model then accepted mixed text/image
and image-only turns through MoonDesk. Its metadata receipt counted one image
in each request; both canonical turns completed, and the same-origin media
proxy returned bytes with the submitted PNG's SHA-256. After a managed
MoonClaw restart, the image-only answer, ordered part, and exact image bytes
replayed. The Code image button now opens a persistent file input inside the
trusted click, while Code paste/drop stop propagation to workspace import.
The in-app browser file-chooser automation set a filename without firing the
page's change event, so native picker, paste/drop preview, and narrow keyboard
QA remain open. A real provider and its failure recovery are also unverified.
The journal remains the media store for this phase; an external store is a
later scaling option.

A replay audit found that selected-book commands were journaled under the
MoonBook root while Code session lookup still queried only the suite root.
MoonClaw now offers one suite listing that includes direct MoonBooks; MoonDesk
uses each row's validated book root for session reads, lifecycle changes, watch,
and image retrieval. Local source checks and focused projection tests cover
the root boundary. The rebuilt daemon's connected suite listing places the
scheduled conversation under its exact child MoonBook and excludes it from
General. The disposable image-only turn now replays from that child MoonBook
after a managed daemon restart, including an authenticated media fetch whose
bytes match the submitted PNG.

For Phase 6, MoonClaw now marks planner usage as observed only when the
provider returned token counts, sums those measured responses into the
canonical turn, and leaves absent usage empty. MoonDesk shows the measured
input, output, and cached input counts in the turn's work evidence disclosure.
MoonClaw now projects `read_skill` as distinct canonical skill evidence with
the installed skill name, resource path, and content digest; MoonDesk labels it
as a Skill in the folded work evidence, without duplicating the full skill
body into the visible transcript. MoonClaw now also exposes a metadata-only
catalog for the selected MoonBook, separating book-local and installed skills;
Code shows names, descriptions, locations, and MoonClaw ownership on request.
The catalog does not imply a skill is active in a turn. A new MoonClaw
job-history endpoint pairs durable service start and terminal events into
distinct runs, including repeated service IDs. A run with no terminal event
after daemon restart is labeled interrupted, while a live run remains running.
MoonDesk resolves the session's owning MoonBook and shows the most recent 50
runs with status, timestamps, turn counts, and stop or failure reason. Local
projection and UI tests distinguish failed, waiting, and interrupted runs and
discard replies for another selected session. Cost estimates remain open;
MoonTown-owned scheduled Code work is implemented below. Connected fixture QA
showed the MoonClaw-owned skill catalog and the failed scheduled run in Code's
job history.
Code now offers a deliberate conversation JSON export from MoonClaw's canonical
projection. It includes user/assistant text, turn outcomes, and image counts;
it omits image bytes/names, tool logs, and hidden work evidence. Export refuses
a missing or wrong-session conversation. The connected fixture export returned
the exact session and one turn with image bytes omitted. Chinese QA also
exposed a setup-state bug: a stale daemon-info file was
counted as an installation. Runtime evidence now distinguishes a reachable
daemon from that stale file so the install action can be shown honestly.
The Code rail now keeps the selected MoonBook and books with chats visible,
while folding empty unselected books under one disclosure. This removes a long
list of zero-count destinations from the first screen without losing access to
them; search still surfaces matching chats. Connected browser QA at 390 × 844
showed no page or rail horizontal overflow and preserved the translated setup
action.
MoonTown's current standing-goal dispatch creates MoonBook watcher tasks, so
scheduled Code work needs a dedicated MoonTown-owned schedule record and a
MoonClaw session/service handoff. Reusing a standing-watch prompt would run a
different workflow and would not satisfy the durable Code-session gate.

The schedule implementation uses one owner and one retry key:

MoonClaw's native command queue now appends the command before updating its
in-memory binding. An exact command-ID retry returns the durable acceptance
without another queued event, while reuse of the ID for different content is
rejected. The submit endpoint checks the journal's claim state: an unresolved
prompt can resume the existing session service after a queue/start crash
window, while a delivered command does not start another service. MoonTown
now persists its own dispatch intent and reconciles command outcomes before
the next due turn.

1. MoonTown stores each Code schedule under its product state with a MoonBook
   identity, a stable MoonClaw session ID, prompt, selected model, cadence,
   enabled state, next due time, and last dispatch/result receipt. A creation
   request resolves the MoonBook from the catalog; callers do not supply an
   arbitrary filesystem root.
2. At a due tick MoonTown persists a dispatch intent before sending a native
   MoonClaw Code turn. The turn uses a deterministic schedule/run command ID.
   After timeout or restart, MoonTown reconciles that identity against the
   canonical MoonClaw session before any retry. MoonClaw's command queue uses
   explicit duplicate-ID handling so a transport retry is idempotent.
3. Code shows the schedule beside its owning conversation: next run, last
   accepted run, terminal outcome, pause/resume, and the exact next action on
   failure. A schedule never creates a second transcript or hides an uncertain
   dispatch as success. Technical receipts stay in a disclosure.

The owner API and MoonDesk schedule controls passed connected disposable
MoonBook create/read/pause/resume checks, including a Chinese Code-form create
through a fixture-only MoonGate model catalog. A fixture daemon accepted one
scheduled turn, recorded a runtime failure against its unavailable test model,
and MoonTown reconciled that exact command as failed on its next tick. This
run exposed a shared suite-store session identity bug: a child MoonBook chat
appeared under the suite. MoonClaw now binds listings and management to the
snapshot's exact book root, and Code opens a scheduled conversation only when
session ID, MoonBook ID, and root all agree. The rebuilt fixture daemon listed
the session under its exact child MoonBook; Code enabled **Open conversation**
and navigated to that session. A later loopback-model schedule completed once,
reconciled to done, and reopened after managed MoonClaw restart with one
journaled command. Ambiguous-response retry and real MoonFort execution still
need acceptance. The schedule is not a release-ready claim until that evidence
is recorded.

A duplicate-ID attempt through the Chinese form retained the unsent draft but
initially showed a generic unreadable receipt. The 409 response is JSON and
Rabbita reports it through its parsed-response branch. The UI now decodes the
owner's error body there, maps the exact duplicate and unavailable-book cases
to localized actions, and retains the draft on failure. The rebuilt Chinese
browser check displayed “此任务标识已存在，请换一个标识。” while both ID and Code task
remained editable with their original values. The UI test and seven locale
checks passed. The form now names the exact Code model selected for future runs
and keeps mobile form controls at a touch-sized minimum. The model cue appeared
in the connected Chinese browser check. The browser's viewport override still
reported 1280 pixels, so the unsigned native app was resized to a measured
392-pixel window: the schedule form stayed within the width, its fields and
submit control remained reachable through scrolling, and no horizontal
overflow was visible. A later Chinese browser check found and repaired two
English strings on the empty Code screen: the general conversation heading and
prompt. A connected phone-width run with a configured model
still needs proof.

The native patch audit found that a single-file `/dev/null` diff took a
different commit path from a multi-file patchset, and a deletion could ignore
content left by its hunks. Both deletion forms now use the guarded patchset
path. It refuses a missing target or any deletion that leaves content. A
partial/full deletion and reverse-creation regressions passed in the focused
native daemon test, alongside child-MoonBook listing cases.

The repository's preview helper now accepts an explicit local Lepusa checkout.
It creates and removes a temporary MoonBit workspace, copies the module-qualified
sidecar build output, and checks preview version syntax before doing expensive
work. A fresh unsigned `0.0.0-preview.4` package passed the full helper:
five-file checksums, release identity, and non-hosted preview channel metadata.
The bundled sidecar's SHA-256 matched its workspace build output, its Code
entry matched the checked-in production bundle, and its
schedule route returned the expected MoonTown-setup 503 rather than 404. Its
Chinese empty Code screen rendered from the packaged UI in the in-app browser.
The exact `0.0.0-preview.4` native app passed a measured 392 × 854 Code form
layout check. With
MoonTown absent, the schedule panel now presents a localized setup instruction
instead of remaining on Loading, and Refresh returns to the same action. Its
form fields and disabled submit remain reachable without horizontal overflow.
Tab visits schedule ID, task, and cadence, then skips the disabled submit.
The latest Code bundle's answer actions, copied feedback, and failed-work
status exposed explicit Chinese accessibility labels in a connected browser
check.
An unsigned `0.0.0-preview.6` package subsequently passed the same five-file
verification, release identity, and non-hosted channel checks after the
managed-control, image-picker, and canonical media adapter fixes. Its native
window check is pending because the Mac locked during QA. A disposable
MoonTown CLI owner tick dispatched one Code schedule to MoonClaw private
control, the loopback model completed it, and a later tick reconciled the
schedule to done. The paused schedule's journal contains exactly one command.
After a managed MoonClaw restart, that session reopened as done and the
journal still contained one command. Code's Chinese browser UI then opened the
same session and showed completed Work with its model answer.
That check exposed a rail label of 就绪 for a completed session. The rail now
labels completed and stopped outcomes explicitly; the rebuilt Chinese UI
displayed 已完成. The subsequent unsigned `0.0.0-preview.7` package passed the
same five-file checksum, identity, and preview-channel checks. The
`0.0.0-preview.8` package also passed packaging checks, but native QA on an
unlocked Mac showed that clicking the image-attachment button did not open
WebKit's picker. Code now renders a file input inside the visible attachment
control and listens for its change event. The `0.0.0-preview.9` package passed
packaging checks, but a connected browser test exposed an omitted top-level
image-message route. The route now passes a regression for attachment and
removal. A synthetic PNG selected through the rebuilt browser picker appeared
in the tray; removal and same-file reattachment worked; an image-only Code
turn completed against the disposable loopback model with one image, and the
image and answer survived reload. At 390 px the Code header no longer
collides: title and four actions use a two-column layout, and the transcript
and composer remain reachable without horizontal overflow. The latest
unsigned `0.0.0-preview.11` package passed five-file checksums, identity, and
preview-channel verification. Apple's WebKit documentation says macOS file
uploads require a `WKUIDelegate` open-panel callback; the local Lepusa runtime
now installs that callback for both native window paths and completes the
selection or cancellation from an app-owned panel. The latest unsigned
`0.0.0-preview.12` package includes the local host change and passed the same
packaging checks. With older preview instances stopped, the isolated `.12`
native app opened macOS's Open panel, selected the synthetic PNG, displayed
its preview and filename in Code, and removed it. The native host and Code
intake gate passed for the fixture; an image-capable provider run remains
pending. The
published Lepusa dependency still blocks a clean-checkout preview on this
compiler, and unsigned local packaging does not satisfy the external release
gate.

After the disposable PR publication and stale-head run, the unsigned
`0.0.0-preview.13` package passed five-file checksums, release identity,
non-hosted preview metadata, and an exact packaged UI asset comparison. It
contains the error-status and rejection-message fixes. This local package was
built from an uncommitted tree and carries no hosted CI or signature claim.

Bundle-size limits are temporarily disabled while the coding workflow grows.
The build test still reports raw and gzip sizes, and still verifies lazy chunk
boundaries and the minified JSON contract. Reintroduce a measured performance
budget during the later route-splitting work.

The current source tree now passes `scripts/check_moon_warning_budget.mjs` at
0/0 warnings for native and Code UI JavaScript targets. The compatibility
cleanup uses explicit derived-trait method extensions; test-only use of the
experimental Rabbita string renderer has scoped annotations. The remote PR
review now shows its base revision and rename source, and surfaces an owner
error in the review pane. This does not replace latest-commit hosted CI or the
credentialed release evidence.
Draft [MoonDesk PR #6](https://github.com/vectie/moondesk/pull/6) now supplies
a large connected review case. The first full GitHub file page exceeded the
server's bounded response; paging 20 files at a time loaded all 260 files.
The Code review renders their selected base-to-head patch, while a path search
filters file controls and reports its match count. The live search found five
matching files and presented an explicit no-match state; a selected diff stayed
visible during filtering, preserving a possible line draft. The UI and
localization tests cover case-insensitive and renamed-path search, count
translation, and empty results. The request still rechecks the exact PR head
and base after paging, so a changed remote patch cannot silently attach a
draft to a new revision.

This plan compares the current MoonDesk and MoonClaw workspaces with the local
OpenSeek 0.4.2 checkout. It improves the MoonCode journey without adding a
second agent runtime, conversation store, scheduler, or model policy to
MoonDesk. `MOONCODE.md`, `UI_DESIGN.md`, and `PRODUCT_CONTRACT.md` remain the
authoritative ownership and capability contracts.

## Product thesis

MoonDesk should be the best place to move from **request to reviewed change**
inside a MoonBook. The distinctive unit is not a chat message or a Git commit
alone. It is a *change journey*: request, live work, affected files, checks,
human decisions, and accepted book outcome, all connected by canonical
identities and evidence. Git provides repository history and collaboration;
MoonBook provides durable accepted knowledge and artifacts; MoonClaw owns agent
execution. The UI must show which authority each action uses.

The first-screen question in Code is: **What is happening to this change, and
what can I do next?** Keep the conversation central. Place file context and
review alongside it only when relevant. Keep raw receipts in developer details.
The primary action must follow the current state: send a request, guide running
work, inspect a changed file, resolve review, or accept an outcome. Never infer
success from a queued command, a local spinner, or an optimistic draft.

## Interaction principles

1. Preserve the one-owner conversation: MoonClaw's canonical turn is the only
   durable chat; MoonDesk may show local optimistic input but not replay raw
   events into a competing transcript.
2. Use one quiet, dense three-region workbench: session rail, conversation,
   contextual files/review. The context pane can collapse without losing the
   selected file or draft.
3. Connect each visible change to its source: path, baseline, tool or person,
   test, and review status. Offer the relevant action next to that evidence.
4. Explain action consequences in plain language. Distinguish guidance that
   joins running work from a new turn that waits. Keep Stop independently
   available, and make stale or failed controls recoverable.
5. Use native controls, visible focus, keyboard order matching visual order,
   readable status text, and 44px targets where touch input is possible.
6. Keep GitHub, Git, MoonBook review, and MoonFort promotion identities distinct.
   A PR comment does not accept a MoonBook outcome; a file save does not publish
   a PR; a selected trial does not promote it.
7. Preserve the current neutral visual identity. Avoid extra dashboards,
   decorative cards, emoji navigation, and a second global route hierarchy.

## Phases and gates

### Phase 0 — Map and stabilize the journey

**Deliverable:** this ownership and UI plan, plus a recorded baseline of the
existing Code states and working-tree changes. Audit the running UI at desktop,
narrow, and large-text sizes before claiming visual completion.

**Gate:** one state map for empty, running, queued, approval, failed,
disconnected, changed, reviewed, and accepted; no proposed action invents a
new durable owner.

### Phase 1 — Make conversation control unambiguous

**MoonDesk:** while a canonical Code turn is running, show separate **Guide
current** and **Queue next turn** actions. Guidance submits `steer`, never
creates an optimistic new turn, and restores its draft on failure. Queueing
retains the existing optimistic turn and canonical acknowledgement path. Stop
remains separately available. Present status and failure in a polite live
region. Keep Enter consistent with the dominant action.

**MoonClaw:** retain its existing ordered prompt/steer/cancel journal and
settlement events. Add any missing receipt fields before promising an exact
"applied to this turn" status in MoonDesk.

**Gate:** keyboard and pointer flows for running, turn finishing during input,
send failure, retry, cancellation, and switching sessions. No duplicate user
row and no dropped draft.

### Phase 2 — Repository context beside the conversation

**MoonDesk:** add a bounded, read-only Git project projection for recognized
repository roots: branch/HEAD, working changes, staged changes, and remote/PR
availability. Show one compact change list in the contextual pane. Open a file
in the existing source buffers. Give non-Git MoonBooks a normal file workflow,
not a broken Git empty state. Do not shell-interpolate paths or expose arbitrary
repository commands through the browser.

**Gate:** dirty files, renames, binary files, untracked files, detached HEAD,
missing remote, repository errors, and workspace switches render truthfully.
The conversation never moves or vanishes when Git context changes.

### Phase 3 — Review the change, then connect collaboration

**MoonDesk:** add navigable file and hunk review, baseline-aware line diffs,
review progress, and comments tied to stable path and revision identities.
Use GitHub PR/issue discovery and checks when a remote is configured. Separate
local review drafts from published GitHub comments; require exact anchor and
HEAD validation before posting. Connect a reviewed MoonBook outcome through
the existing authority boundary, never by treating a PR approval as book
acceptance.

**Gate:** stale base, rebased branch, renamed file, deleted file, binary diff,
offline GitHub, unsent draft, and failed publication all remain navigable and
recoverable. Review counts derive from source evidence rather than UI toggles.

### Phase 4 — First-class code editing and navigation

**MoonDesk:** evolve the existing multi-buffer source pane rather than creating
another editor store. Add precise diagnostics, definition/references, keyboard
navigation, search, and richer diff presentation. Preserve its current save,
reload, conflict, workspace scope, and source-path security behavior. Use Moon
IDE for MoonBit where available; missing language services leave a reliable
plain-text editor.

**Gate:** dirty-buffer transitions, external edits, multi-file review, focus
return, large files, and inaccessible language service errors are covered by
observable tests and real UI inspection.

### Phase 5 — Durable multimodal and contextual input

**MoonClaw and shared contract:** define ordered text/image content for Code
turns, durable references or bounded bytes, validation, and replay. Avoid
turning an image into a path string in a text prompt. Preserve media identity
through restart and model routing. **MoonDesk:** reuse its media intake for a
Code attachment tray with previews, remove/retry controls, accessible names,
and canonical transcript rendering. Keep unsupported models explicit.

**Gate:** paste, drop, picker, mixed text/images, replay, failed upload,
switching sessions, and model incompatibility. No image is lost after submit or
silently omitted from the canonical record.

### Phase 6 — Work evidence, skills, and automation

**MoonClaw:** audit OpenSeek's job lifecycle, bounded programmatic tools,
deletion approval, edit guards, usage, and terminal outcomes against native
MoonCode contracts. Implement runtime gaps there. **MoonDesk:** project
available skills with provenance and authority, per-run logs and outcomes,
token/cost evidence where measured, and MoonTown scheduled Code work with its
own canonical session. Keep runtime detail behind progressive disclosure.

**Gate:** every visible job or schedule links to a durable owner; interruption,
restart, partial failure, and missing measurements never appear as success.

### Phase 7 — Release quality and differentiation

Finish localization, responsive and assistive-technology review, clean-machine
packaging, updates, rollback, and long-running reliability evidence under the
existing release gates. Verify the complete request-to-reviewed-change journey
with a real MoonClaw runtime and, separately, a GitHub-connected repository.

**Gate:** no release claim until the external proofs named in `STATUS.md` exist.

## Sequencing and measurement

Phases 1–4 are the coding-workflow spine. Phase 5 can proceed when the shared
content contract is ready; Phase 6 runtime work belongs to MoonClaw and can
run alongside MoonDesk presentation work. Each phase should finish a complete
user journey before adding another partial panel.

Measure: time to first factual work update; number of context switches from
request to reviewed change; percentage of changed files with a clear review
state; draft loss on failures; duplicate transcript rows; actions requiring an
opaque identifier; and success/failure recovery after restart. Record real UI
observations separately from source-level or fixture-only checks.
