# MoonCode User-Journey End-to-End Test Plan

Status: baselined before execution on 2026-07-10

This plan tests MoonCode as a user-facing coding assistant, not only as a set of
backend contracts. It defines what a user should see, why it is necessary, what
the user can do, what a realistic user will do, the expected outcome, and the
evidence required to claim that the outcome is achievable.

The plan focuses on the primary Code-mode workflow:

```text
choose General or a MoonBook
-> start or resume a chat
-> send a request
-> see immediate acknowledgement
-> see real MoonClaw-backed work
-> receive one answer
-> continue the conversation
-> recover the same state after navigation or restart
```

## Product Acceptance Contract

The user should experience MoonCode as one stable conversation surface. The
session rail answers "where am I and which chat is selected?" The conversation
answers "what did I ask, what is MoonCode doing, and what did it conclude?" The
composer answers "what can I ask next?"

The following rules are release-blocking:

1. A submitted user message appears immediately and never moves upward,
   disappears, or duplicates.
2. Visible work appears only after command-scoped MoonClaw evidence exists.
3. Each turn has at most one top-level user row, one work disclosure, and one
   assistant row, in that order.
4. The assistant answer is committed once and belongs to the correct request.
5. Prior turns are an immutable prefix while a later turn is added or updated.
6. General chats are clearly separate from chats attached to a MoonBook.
7. Session selection, idle polling, reload, and runtime restart do not replace
   the selected conversation with listing-only or stale state.
8. A runtime failure is factual, visible, owned by the request, and recoverable.
   The UI must not pretend that work is happening.
9. User-facing work copy explains progress in ordinary language and does not
   expose raw command ids, event names, tool JSON, internal paths, or model
   reasoning tokens.
10. The complete primary workflow is operable with keyboard and pointer at
    desktop and narrow/mobile widths without overlap or horizontal scrolling.

## What The User Should See

| Surface or state | What the user should see | Why the user needs it |
|---|---|---|
| Code-mode entry | Stable `Desk`, `Wiki`, and `Code` navigation with `Code` selected | Establishes location and prevents mode ambiguity |
| Session rail | `MoonCode`, current scope name, total session count, `New chat`, grouped sessions, and visible selected state | Lets the user know which project and conversation are active |
| General scope | A `General` group for chats not attached to a MoonBook | Supports idea gathering before the user chooses a project |
| MoonBook scope | A group labeled with the MoonBook name and only that book's sessions | Prevents work from being attached to the wrong project |
| Empty conversation | `Ask MoonCode`, one concise scope-aware sentence, composer, and `Start` | Gives one obvious first action without internal setup copy |
| Submitted request | The user's exact text at the bottom of the conversation immediately | Confirms Enter worked before network or model latency |
| Accepted but not working | Only the acknowledged user row; no fabricated spinner or work claim | Avoids false confidence when MoonClaw has not started |
| Active work | One live work row between the request and answer, backed by MoonClaw evidence | Shows that real work began and identifies the owning turn |
| Completed work | One folded `Work` disclosure with a short summary and optional details | Preserves inspectability without filling the chat with logs |
| Assistant result | One readable answer directly below the owning work row | Completes the request in normal conversation order |
| Later turns | Earlier rows unchanged, with the new request appended at the bottom | Supports multi-turn trust and scanning |
| Runtime failure | One clear failed turn or nearby actionable error, without an endless working state | Explains what failed and enables retry/recovery |
| Reload/restart | The same selected session, scope, turns, order, and stable work ids | Proves the conversation is durable rather than browser memory |

## What The User Can Do

The visible interface must support these actions without hidden APIs:

- enter Code mode
- select `General` or a MoonBook group
- start a new chat in the selected scope
- type a request and send it with Enter
- send a later request in the same session
- select an older session and return to the latest session
- expand and collapse completed work details with pointer and keyboard
- reload the app and continue the selected conversation
- continue after MoonClaw restarts

Backend and integration gates additionally prove that a selected MoonBook coding
turn can execute typed file/tool work and persist its result under that
MoonBook. The ordinary chat UI must not expose the operational logs used to
prove this.

## Representative User Journeys

### Journey A: Explore An Idea In General

User intent: ask a coding question before deciding which MoonBook owns it.

User actions:

1. Open Code mode.
2. Select `General`.
3. Click `New chat`.
4. Type a question and press Enter.
5. Read work status and the final answer.
6. Ask two follow-up questions.

Expected outcome:

- the chat is stored under `General`, not under a MoonBook
- each message appears immediately
- three turns resolve into exactly nine ordered rows
- no previous content flashes, reorders, duplicates, or disappears
- the rail shows one selected General session with stable title and status

### Journey B: Perform Work In A MoonBook

User intent: make a concrete, verifiable change in a chosen project.

User actions:

1. Select the test MoonBook group.
2. Click `New chat`.
3. Ask MoonCode to create or update a small test artifact.
4. Wait for one real work disclosure and one answer.
5. Inspect the artifact outside the chat through filesystem/API evidence.

Expected outcome:

- the context bar and rail identify the MoonBook
- the session is grouped under that MoonBook, not General
- real MoonClaw tool/file evidence is owned by the command
- the requested artifact exists under the selected MoonBook only
- the assistant reports the result once

### Journey C: Resume And Navigate

User intent: move between conversations without losing context.

User actions:

1. Start a second chat.
2. Select the first chat in the rail.
3. Return to the second chat.
4. Reload the page.
5. Restart MoonClaw and reload again.

Expected outcome:

- the selected style and center conversation always agree
- each session retains its own turns
- session ordering is stable except for a documented recent-activity update
- selecting or polling never clears a hydrated conversation
- durable replay returns identical turn order and item ids

### Journey D: Failure And Recovery

User intent: understand why no answer arrived and continue safely.

User actions:

1. Submit a prompt while MoonClaw is unavailable.
2. Observe the resulting state.
3. Restore MoonClaw.
4. retry in a new turn or resume according to the visible recovery control

Expected outcome:

- the user message remains visible
- no work row appears without evidence
- the UI does not remain indefinitely in `Working`
- the failure is attached to the correct command and uses user-facing copy
- after recovery, the user can submit another prompt and receive an answer

## Methodology

### 1. Isolated Environment

Use one fresh test root under:

```text
<moondesk>/_build/e2e/mooncode-user-journey-<run-id>/
```

The fixture contains:

```text
books/code-lab/book.json
books/code-lab/wiki/index.md
.moonsuite/products/moonclaw/
.tmp/
```

Start exactly one MoonClaw daemon and one Moondesk server. Before and after the
run, inspect processes to ensure stale Lepusa, MoonClaw, or Moondesk instances
cannot influence results.

### 2. Test Layers

Run the layers in this order:

1. **Static contract checks**: source validators and warning-enabled MoonBit
   checks catch duplicated ownership and route drift.
2. **Deterministic unit/integration suites**: MoonLib/MoonClaw/Moondesk tests
   prove exact JSON, reducer, storage, and host behavior without UI timing.
3. **Live HTTP integration**: start real MoonClaw and Moondesk processes and
   prove multi-turn canonical state, runtime control, and storage boundaries.
4. **Real UI journeys**: use the visible app with mouse clicks and keyboard
   typing. Do not inject chat messages into browser state.
5. **Recovery and visual validation**: poll, switch sessions, reload, restart
   MoonClaw, and inspect desktop/mobile layouts.

### 3. Evidence Sources

Every claim must be backed by one or more of:

- visible DOM state and accessible names
- ordered top-level transcript row samples
- `data-command-id`, `data-client-turn-id`, and work `data-item-id`
- elapsed time from Enter to the first ordered DOM sample
- browser console/runtime error collection
- screenshots at defined viewports
- host API responses
- MoonClaw canonical conversation JSON
- JSONL and requested MoonBook artifact files on disk
- process list before and after execution

Backend state alone cannot prove usability. A screenshot alone cannot prove
ownership or durability. The report must connect both.

### 4. Append-Only Sampling Oracle

After every meaningful state change, record the direct children of
`[data-testid="mooncode-chat-surface"] .mooncode-transcript-list` as:

```text
row type, command id, client turn id, item id, status, bounded visible text
```

For every later sample:

- committed prior row ids must remain a prefix
- a new user row may append
- work and assistant slots may appear only inside that new turn position
- content/status may update in place
- no committed row may move or be reinserted

The final three-turn shape must be:

```text
user-1, work-1, assistant-1,
user-2, work-2, assistant-2,
user-3, work-3, assistant-3
```

### 5. Timing Method

Measure:

- `T0`: Enter key action starts
- `T1`: exact user text is present as the final visible user row
- `T2`: first command-scoped work evidence is visible
- `T3`: first assistant content is visible
- `T4`: turn reaches terminal state

Acceptance targets:

- `T1 - T0`: p95 <= 50 ms in local browser automation
- no work claim before the producer evidence exists
- evidence-to-screen and assistant-to-screen: <= 500 ms after the corresponding
  canonical revision becomes observable at the host boundary

Model execution time is recorded separately from rendering latency.

### 6. Visual And Responsive Method

Validate these viewports:

- desktop: 1440 x 900
- compact desktop/tablet: 1024 x 768
- mobile: 390 x 844

For each viewport, assert:

- no horizontal page scroll
- header, rail, transcript, and composer do not overlap
- composer and current answer remain reachable
- long session titles and messages wrap or ellipsize within bounds
- active/selected state remains visible without color as the only cue
- primary pointer targets are at least 44 x 44 CSS pixels on mobile
- focus indicators are visible
- reduced-motion mode removes continuous pulse and disclosure animation

### 7. Accessibility Method

Use keyboard-only checks for:

- reaching Code mode, New chat, scope groups, sessions, composer, send, and
  completed work disclosure in logical order
- Enter sends from the composer
- Enter/Space toggles a focused disclosure
- focus is not lost after a poll or canonical refresh
- dynamic error/work/answer changes have an appropriate live announcement or
  alert mechanism
- headings are sequential and controls have stable accessible names

### 8. Error And Recovery Method

The unavailable-runtime test is controlled:

1. stop the single MoonClaw process after a healthy session is durable
2. submit one uniquely identifiable prompt
3. sample the UI before any restart
4. verify no fabricated work row and no endless working state
5. restart MoonClaw using the same test root
6. verify old turns remain and a new prompt can complete

Do not delete or rewrite conversation files to manufacture the result.

## Scenario Matrix

| ID | Scenario | User action | Required evidence | Pass condition |
|---|---|---|---|---|
| UJ-01 | First entry | Open `?activity=code` | DOM + screenshot | Code selected; scope, rail, empty state, composer visible |
| UJ-02 | General scope | Click General | rail/context DOM | Context says General; no MoonBook path implied |
| UJ-03 | MoonBook scope | Click Code Lab | rail/context DOM | Context says Code Lab; group active |
| UJ-04 | New chat | Click New chat | DOM sample | Empty conversation remains in chosen scope |
| UJ-05 | First send | Type and press Enter | timing + row trace | Exact user row appears <= 50 ms |
| UJ-06 | Real work | Observe turn | canonical API + DOM | One work row appears only after evidence |
| UJ-07 | Final answer | Wait for completion | canonical API + DOM | One assistant row below work; terminal status |
| UJ-08 | Multi-turn | Send second and third prompts | row trace | Nine final rows; previous prefix never changes |
| UJ-09 | Disclosure | Click and keyboard-toggle work | DOM open state | Real expand/collapse; state survives poll |
| UJ-10 | Session rail | Create second session | rail trace | Correct group/count/title/selected state; no flash |
| UJ-11 | Switch sessions | Select A, B, A | rail + transcript | Selected rail and center always match |
| UJ-12 | Idle polling | Wait two poll intervals | row trace | No DOM reorder/removal; open disclosure preserved |
| UJ-13 | Hard reload | Reload selected session | row trace | Same turns, ids, scope, and selection return |
| UJ-14 | MoonClaw restart | Restart same root | API + row trace | Durable conversation returns identically |
| UJ-15 | Runtime unavailable | Stop daemon and submit | DOM + API error | No fake work; visible owned failure/recovery path |
| UJ-16 | Recovery | Restart and send prompt | DOM + API | New turn completes without damaging old turns |
| UJ-17 | MoonBook work | Request small file change | filesystem + canonical turn | Artifact exists only in Code Lab; answer commits once |
| UJ-18 | Keyboard | Tab/Enter/Space workflow | focused element trace | No traps; all primary actions operable |
| UJ-19 | Responsive | 1440, 1024, 390 widths | screenshots + bounds | No overlap/overflow; mobile controls >= 44 px |
| UJ-20 | Reduced motion | Emulate reduce | computed styles | Pulse/disclosure motion disabled |
| UJ-21 | Browser health | Complete all journeys | console/runtime logs | No uncaught exception or console error |
| UJ-22 | Storage boundary | Inspect test root | filesystem scan | Canonical `.moonsuite`; no legacy `.moonclaw` or repo pollution |

## Severity And Verdict Rules

- **P0 Blocker**: data loss, cross-project write, unrecoverable corruption.
- **P1 Blocker**: missing/duplicated/reordered turn, fabricated work, no reply,
  session mismatch, or primary journey cannot complete.
- **P2 Major**: confusing recovery, inaccessible primary action, mobile overlap,
  or internal diagnostics leak into normal chat.
- **P3 Minor**: wording, spacing, visual hierarchy, or non-blocking polish issue.

Overall verdict:

- **Pass**: no P0/P1/P2 findings and every core journey is achievable.
- **Conditional pass**: core journeys are achievable, no P0/P1 findings, but one
  or more P2 issues require scheduled correction.
- **Fail**: any P0/P1 finding or a core journey cannot be completed.

## Deliverables

Execution produces:

- this baselined plan
- `docs/MOONCODE_USER_JOURNEY_E2E_REPORT_2026-07-10.md`
- desktop, compact, and mobile screenshots under the isolated test root
- exact automated test counts and command outcomes
- a defect table with severity, reproduction, evidence, and user impact
- a final answer to: "Can the user achieve the intended MoonCode workflow?"
