# MoonCode User-Journey End-to-End Test Report

Date: 2026-07-10

Verdict: **PASS - release-blocking conversation and planner defects resolved**

## Remediation Rerun

The 2026-07-10 remediation run fixed the conversation, workspace, rail,
recovery, and responsive UI defects found in the baseline run below.

Verified corrections:

- MoonClaw now keeps the first accepted MoonBook root immutable. A real UI
  coding turn wrote only under `books/code-lab/tools/...`; the suite-root
  counterpart was absent, and the native session snapshot retained the Code
  Lab root.
- Three real keyboard-submitted turns rendered as an unchanged append-only
  `user -> work -> assistant` prefix. Immediate user append measured 25, 27,
  and 28 ms, and the composer value was empty after every submit.
- Hard reload restored the same selected session from the URL and repainted the
  same nine ordered rows on the first rendered state. General and Code Lab
  grouping, counts, selected state, and order remained byte-for-byte stable
  across idle polling.
- General remains available without a MoonBook, and every MoonBook group stays
  visible even when it has no sessions. `New chat` clears the selected session,
  transcript, URL session parameter, and composer.
- Completed work disclosures toggle with Enter and Space, update
  `aria-expanded`, and actually hide/show their details. Active mode/group and
  selected session expose `aria-pressed`/`aria-current`.
- At 390x844 and 320x568, the composer was fully inside the first viewport,
  document width matched viewport width, and mode, New chat, and Prompt controls
  measured 44 px. The 844x390 landscape check also kept the composer visible.
- Submitting while MoonClaw was stopped appended the user row in 27 ms without
  synthetic work. The configured service restarted MoonClaw, then canonical
  work and an assistant reply appeared without reordering or losing the turn.
- Submit now starts MoonClaw's asynchronous runtime-service contract instead of
  blocking the HTTP request on the full runtime loop. An existing-session API
  submit returned its canonical queued turn in 158 ms and later projected the
  matching `ASYNC_OK` assistant reply.
- No browser warning or error entries were recorded during the real UI journey.

Final model-backed acceptance run:

- Session `mooncode-3b8f7bbcf9021a9c` completed three turns against the
  `book-code-lab` MoonBook with unique command ids and stable ordinals
  `0, 1, 2`.
- Turn 1 used the real `codex/gpt-5.4` planner and replied `MODEL_OK`.
- Turn 2 durably emitted queued, started, planning, read, and continued-planning
  progress before returning a correct one-sentence summary of `README.md`.
- Turn 3 wrote exactly `ROOT_OK` to `books/code-lab/tools/final-e2e.txt` and
  did not create the suite-root counterpart.
- The final canonical projection contained exactly three user rows, three
  completed work groups, and three assistant rows. It contained no duplicate
  command ids, failed work steps, or visible `finish` tool rows.
- Warm model planning took about 1.9 seconds for the direct reply. The two-step
  read-and-summarize turn completed in about 4.8 seconds. The deterministic
  write turn completed in under 0.3 seconds after runtime claim.

Automated rerun:

| Gate | Result |
|---|---|
| MoonDesk complete suite | PASS, 531/531 |
| MoonDesk backend package | PASS, 163/163 |
| Rabbita UI | PASS, 186/186 |
| MoonClaw complete suite | PASS, 1041/1041 |
| MoonClaw daemon package | PASS, 102/102 |
| Production UI build | PASS |

Resolved planner blocker:

- The timeout masked two invalid Codex Responses parameters. The endpoint
  rejected `max_output_tokens`, and `gpt-5.4` rejected reasoning effort
  `minimal`. MoonClaw no longer sends the unsupported output parameter and the
  MoonCode fast planner now requests supported effort `none`.
- Codex requests are no longer wrapped in an external planner timeout that can
  cancel an otherwise healthy stream. Other providers retain bounded timeout
  behavior.
- Non-retryable Codex 4xx responses now fail immediately with a bounded HTTP
  error summary instead of spending multiple exponential retries hiding the
  real cause.
- Explicit simple reads, exact writes, tools, and miniapps have bounded
  deterministic plans; semantic reads and ordinary chat still use the real
  model planner. Both paths passed the live acceptance run.

The sections below preserve the original failing baseline for comparison.

At baseline, MoonCode could complete ordinary General chat turns, preserve an
append-only three-turn transcript, and render a clean
`user -> work -> assistant` sequence. It could not be accepted as a coding
assistant at that point because MoonClaw executed MoonBook-relative tools
against the suite root, session grouping changed during hydration and reload,
and unavailable-runtime turns became orphaned queues. Those findings are
historical and are superseded by the passing remediation evidence above.

## Baseline Acceptance Answer

Can the user achieve the intended workflow?

- **General conversation:** yes for a healthy runtime. Three consecutive turns
  completed without duplicate, reorder, or disappearance during the live run.
- **MoonBook coding work:** no. The assistant reported a successful Code Lab
  write, but the file was created at the suite root instead of inside Code Lab.
- **Resume and navigation:** no. Reload and detail hydration changed session
  groups, selected a different session, and temporarily hid the selected
  transcript.
- **Failure and recovery:** no. A turn submitted while MoonClaw was unavailable
  stayed `Queued`, had no recovery action, and did not drain after restart.
- **Keyboard and mobile use:** partial. Core buttons and Enter submission work,
  but the work disclosure is not keyboard-operable and the mobile composer is
  below the first viewport with 34px controls.

Any one of the workspace escape, session mismatch, or missing reply findings is
release-blocking under the test plan. This run found all three.

## Environment

| Item | Value |
|---|---|
| MoonDesk URL | `http://127.0.0.1:4643/?activity=code&smoke=mooncode-user-journey-e2e` |
| Isolated root | `_build/e2e/mooncode-user-journey-20260710-1827` |
| MoonBook | `books/code-lab` (`book-code-lab`, `Code Lab`) |
| MoonDesk | one server on port `4643` |
| MoonClaw | one daemon, restarted once against the same isolated root |
| Interaction | in-app browser, real pointer clicks and keyboard typing/Enter |
| Viewports | 1440x900, 1024x768, 390x844, 320x568, 844x390 |
| Browser console | no warning or error entries after the journeys |

The test did not inject messages into browser state. Host and canonical API
reads were used only after visible UI actions to verify ownership and storage.

## Automated Gates

| Gate | Result |
|---|---|
| MoonLib conversation contract | PASS, 3/3 |
| MoonClaw core | PASS, 15/15 |
| MoonClaw daemon | PASS, 93/93 |
| MoonDesk `internal/mooncode` | PASS, 281/281 |
| MoonDesk `internal/moonwiki` | PASS, 162/162 |
| Rabbita UI JavaScript target | PASS, 184/184 |
| Production UI build | PASS |
| Final architecture, route ownership, dispatch, native endpoint, runtime-control, native projection, and runtime tool validators | PASS |
| Live contract, runtime-loop, three-turn, and HTTP method smokes | PASS |
| Runtime-control boundary smoke | FAIL: steer is projected as an ordinary visible user turn |

The broad deterministic suites passing did not predict the failures below. The
missing coverage is specifically the combined `selected MoonBook -> native
MoonClaw tool root -> canonical list -> reload/hydration` journey.

## Scenario Results

| ID | Result | Evidence and observed outcome |
|---|---|---|
| UJ-01 First entry | PASS | Code was selected; Code Lab, rail, empty state, and composer were visible. |
| UJ-02 General scope | PASS | General showed scope-aware empty copy and accepted a new chat without requiring a MoonBook. |
| UJ-03 MoonBook scope | FAIL | Code Lab was correct initially, but its empty group disappeared after selecting General; reload was required to reach it again. |
| UJ-04 New chat | FAIL | Healthy new chats opened correctly. After an offline queued turn, `New chat` did not detach from the queued session until reload and retained the prior draft. |
| UJ-05 First send | FAIL | Healthy General samples were 20, 28, and 27 ms; recovery was 59 ms. A later Code Lab sample took 127 ms and the offline sample took about 1.8 s, missing the 50 ms target. |
| UJ-06 Real work | PASS | No fabricated work row appeared while MoonClaw was stopped. A command-scoped work row appeared at 3.42 s for the timed Code Lab turn. |
| UJ-07 Final answer | FAIL | Simple replies completed, but a valid read-only Code Lab request ended in failed work with no assistant row. |
| UJ-08 Multi-turn | PASS | Three General turns ended as exactly `user/work/assistant` repeated three times with stable distinct ids and no prefix mutation. |
| UJ-09 Disclosure | FAIL | Pointer open/close worked and open state survived polling. Focused Enter and Space did not toggle it; `aria-expanded` was absent. |
| UJ-10 Session rail | FAIL | Counts and order worked in the initial General two-session test, then groups and titles flashed and changed as full sessions hydrated. |
| UJ-11 Switch sessions | FAIL | Initial A/B/A navigation restored independent transcripts. After reload, the first click hydrated Code Lab content while the header still said General chat; a second click corrected it. |
| UJ-12 Idle polling | PASS | Existing ordered rows and an open disclosure remained stable over multiple poll intervals in the healthy General session. |
| UJ-13 Hard reload | FAIL | Reload selected the stale offline session, moved the failed Code Lab session to General, changed its status to Ready, and showed no transcript until it was clicked and hydrated. |
| UJ-14 MoonClaw restart | FAIL | Existing chat data remained on disk, but grouping changed and the queued offline turn did not resume. |
| UJ-15 Runtime unavailable | FAIL | User text was delayed about 1.8 s, the rail said `Queued` indefinitely, and there was no error explanation, retry control, or recovery path. |
| UJ-16 Recovery | FAIL | A new post-reload prompt completed after restart, but the old queued turn remained stuck and session grouping changed. |
| UJ-17 MoonBook work | FAIL | Canonical metadata said Code Lab, but the requested artifact was written to the suite root and not to the MoonBook. |
| UJ-18 Keyboard | FAIL | Enter submission and native buttons worked; the work disclosure failed Enter/Space operation and selected controls lacked semantic state. |
| UJ-19 Responsive | FAIL | No horizontal overflow at tested widths. At 390x844 and 320x568 the composer was below the first viewport; primary buttons were 34px high, below the 44px target. |
| UJ-20 Reduced motion | PARTIAL | CSS contains a complete `prefers-reduced-motion: reduce` block for pulse, disclosure, hover transform, and transitions. OS media emulation was not exposed by the browser harness, so computed reduced-mode state was not executed. |
| UJ-21 Browser health | PASS | No uncaught browser warnings or errors were collected. |
| UJ-22 Storage boundary | PASS | Test data stayed under `_build/e2e/.../.moonsuite`; no standalone `.moonclaw`, `moondesk-workspace`, or source-tree suite state was found. The suite-root artifact escape remains UJ-17. |

Summary: 7 pass, 14 fail, and 1 partial. UJ-22 passes legacy-storage isolation;
the distinct suite-root artifact escape is covered by UJ-17.

## Timings

| Interaction | User row | First real work | Assistant/terminal |
|---|---:|---:|---:|
| General turn 1 | 20 ms | model-dependent | completed |
| General turn 2 | 28 ms | model-dependent | completed |
| General turn 3 | 27 ms | model-dependent | completed |
| Recovery-online turn | 59 ms | present | assistant at about 12 s |
| Timed Code Lab read | 127 ms | 3.42 s | failed at about 3.2 s canonical time; no assistant |
| MoonClaw unavailable | about 1.8 s | never | still queued after restart |

The Code Lab failure timestamp is earlier than the first visible work sample
because the UI polls canonical state; the important rendering result is that
the user saw one ordered failed work row and no answer.

## Release-Blocking Defects

### MC-E2E-001 - P0: MoonClaw executes MoonBook tools at the suite root

Reproduction:

1. Select Code Lab.
2. Ask MoonCode to create `tools/e2e-user-journey.txt` in the MoonBook.
3. Wait for the assistant to report success.
4. Inspect both the selected MoonBook and the suite root.

Observed:

- MoonDesk canonical session metadata contained:
  `workspace_id=book-code-lab` and
  `cwd=.../books/code-lab`.
- The requested file did not exist at
  `books/code-lab/tools/e2e-user-journey.txt`.
- It existed at suite-root `tools/e2e-user-journey.txt` with the exact requested
  content and newline.
- A later read-only request for `README.md` and `wiki/index.md` failed because
  MoonClaw tried suite-root `README.md`.
- MoonClaw's native session snapshot stored `book_root` as the suite root even
  though the durable command packet carried the Code Lab root.

User impact: code can be read or changed outside the selected project while the
assistant claims the requested project was changed. This violates the primary
workspace safety boundary.

Required correction:

- bind an immutable validated `workspace_root` to the native session when the
  command is accepted
- execute every read/write/tool path from that session root, never the daemon's
  suite `--serve` root
- reject a command when packet, session, and requested `book_root` disagree
- add a live negative assertion that the suite-root counterpart does not exist

### MC-E2E-002 - P1: Rail grouping is rebuilt from conflicting summary and detail records

Reproduction:

1. Create General and Code Lab sessions.
2. Reload while a failed or queued Code Lab session is selected.
3. Click the session that the initial list placed under General.

Observed:

- reload changed General from 4 to 5 sessions and Code Lab from 2 to 1
- the failed Code Lab session appeared under General as Ready
- the stale offline session became selected with an empty center transcript
- clicking the failed session hydrated its canonical Code Lab metadata and moved
  it to Code Lab while the main header still said General chat
- clicking it a second time aligned the header and conversation

User impact: the rail flashes, sessions appear to move or disappear, and the
project label can disagree with the displayed conversation.

Required correction:

- define one canonical rail DTO with immutable session/workspace identity
- group only from explicit canonical `workspace_id`, with General as an explicit
  identity rather than a missing-data fallback
- never regroup a session during detail hydration
- preserve selected `session_id` through reload and hydrate it before painting a
  conflicting empty center state

### MC-E2E-003 - P1: Offline queued turns are orphaned across restart

Observed:

- the user row appeared only after about 1.8 s
- no false work row appeared, which is correct
- the rail displayed `Queued` indefinitely with no factual explanation
- restarting MoonClaw did not claim or complete the queued command
- `New chat`, Enter, and Prompt did not start a new turn from that state until a
  hard reload

User impact: the app accepts a request but gives neither an answer nor a usable
recovery path.

Required correction: make one component own durable command acceptance. Either
MoonClaw accepts and idempotently drains the queue after reconnect, or MoonDesk
rejects submission immediately with a visible retry action. Do not persist a
queue that no runtime owns.

### MC-E2E-004 - P1: Valid Code Lab read ends without an assistant answer

The timed read request selected two legitimate files. Real work appeared, but
the first read used the wrong root and terminated the whole turn. The folded
copy said `Work interrupted`; expanded copy incorrectly included `Preparing
changes to README.md` for a read tool and `Finished a work step` for a failed
result. No assistant failure explanation was appended.

Required correction: after fixing workspace binding, classify read as context,
retain the actual error cause in user-safe detail, and append an owned assistant
failure/recovery message or actionable failed-turn control.

## Major UX And Accessibility Defects

| ID | Severity | Finding |
|---|---|---|
| MC-E2E-005 | P2 | Completed and queued sessions can retain the submitted composer text; accidental Enter can duplicate intent. |
| MC-E2E-006 | P2 | Work disclosure does not toggle with Enter or Space and exposes no `aria-expanded`. |
| MC-E2E-007 | P2 | Active mode and active session rely on CSS class without `aria-current`, `aria-pressed`, or `aria-selected`. |
| MC-E2E-008 | P2 | Mobile places the composer below the first viewport and uses 34px primary controls. |
| MC-E2E-009 | P2 | `FAILED`, `Show details`, and equivalent 10-11px text use `rgb(148,163,184)`, only 2.45:1 on the main background. |
| MC-E2E-010 | P2 | Runtime-control steer evidence is rendered as an ordinary user turn by the live boundary smoke. |
| MC-E2E-011 | P3 | One exact-output assistant response omitted its requested final period. |

## Architectural Diagnosis

The visible problems share three ownership failures.

1. **Workspace identity is not immutable end to end.** MoonDesk creates the
   command with Code Lab metadata, but MoonClaw stores and executes the native
   session using the suite daemon root. UI correctness cannot compensate for a
   runtime session that has already lost its selected root.
2. **The rail and the conversation do not consume one record shape.** The rail
   first renders listing/summary data. Full-session hydration later supplies a
   different workspace and status, and the UI derives grouping again. That is
   a rebuild, so moving rows and mismatched headers are expected outcomes.
3. **Queue ownership is split.** MoonDesk can persist a queued request while
   MoonClaw is absent, but a restarted MoonClaw does not drain that host queue.
   The UI therefore has durable intent without a durable executor.

The canonical `moonsuite-conversation.v2` transcript itself behaved well in the
healthy three-turn case. The next correction should preserve that append-only
transcript and remove the inconsistent workspace/list/queue inputs around it,
not add another projection or merge path.

## Recommended Fix Order

1. Fix and lock MoonClaw's native session workspace root; add real read/write
   containment E2E tests.
2. Replace summary/detail regrouping with one canonical rail contract and stable
   selection hydration.
3. Give the offline queue one owner and an idempotent reconnect/retry contract.
4. Guarantee optimistic user append and composer clear for every accepted
   prompt, including unavailable and resumed states.
5. Add explicit failed-turn copy and retry behavior without synthetic work.
6. Repair disclosure keyboard semantics, selected-state ARIA, contrast, touch
   targets, and mobile composer placement.
7. Re-run this exact fixture and require all P0/P1 scenarios to pass before
   evaluating visual polish.

## Visual Evidence

- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/desktop-1440x900-final.png`
- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/tablet-1024x768.png`
- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/mobile-390x844.png`
- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/small-phone-320x568.png`
- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/landscape-844x390.png`
- `_build/e2e/mooncode-user-journey-20260710-1827/screenshots/failure-work-interrupted-viewport.png`

Use viewport screenshots for fixed desktop layouts. Full-page desktop captures
were not used for the failure verdict because the browser compositor produced
an inconsistent fixed-layer capture; DOM bounds and the viewport capture agree.

## Exit State

One MoonDesk server remains available on port `4643` and one MoonClaw daemon
remains attached to the isolated fixture. The app is left in Code mode with the
failed Code Lab session selected so the release-blocking behavior is directly
inspectable.
