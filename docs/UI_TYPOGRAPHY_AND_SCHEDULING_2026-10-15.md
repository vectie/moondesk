# MoonDesk typography and main workspace scheduling

Date: 2026-10-15

## What OpenSeek gets right

Reviewed the current sibling checkout's `desktop/styles/tokens.css`,
`base.css`, `main_header.css`, `sidebar.css`, `composer.css` and
`transcript.css`, alongside MoonDesk's running packaged interface. OpenSeek's
checked-in editor screenshot was also inspected; this was a source comparison,
not a claim to have tested its entire running product.

OpenSeek separates content from controls with a small type scale. Its base is
14px; secondary controls use 13px, metadata 12px and larger titles 17px.
Regular weight dominates. Selection uses a quiet background, dividers recede,
and sidebar rows stay on one line. A panel has one clear heading and a few
contextual actions. This makes the content easier to scan.

MoonDesk's earlier passes reduced dimensions but retained heavy typography
from older styles. Navigation used weight 760, several secondary controls
looked primary, book names wrapped beside persistent actions, and Desk placed
counts and selection messages above the file list. The Book editor also put
an injected formatting toolbar into a two-row grid, causing overlap.

## Applied hierarchy

| Element | Standard |
| --- | --- |
| Reading and conversation | 14px, regular, line height 1.6 |
| Navigation, rows and controls | 13px, regular; 500 for selection/title |
| Dates, counts and secondary context | 12px, muted |
| Empty-state title | 17px, weight 500 |
| App header | 44px desktop |
| Pane header | 40px |
| Book/file/session row | 30px, one line |
| Header icon | 16px in a 30–32px control |
| Touch controls | At least 44px |

`styles/type-hierarchy.css` owns these cross-destination decisions. Existing
components retain their behavior and document content retains its own heading
structure. Changes include:

- The same system font for navigation, menus, inputs and document controls.
- Quieter header shortcuts, file rows and dividers.
- A 240px book/session rail; book actions appear on hover, focus or selection.
- The current book stays in the top header; its duplicate Desk heading is hidden.
- File counts move below the file list; empty selection/access messages disappear.
- Book's format toolbar uses conventional glyphs with accessible names and
  tooltips, and occupies a full row above source and preview.
- Empty background-work status disappears; existing work and scheduled tasks
  retain their indicator.
- Packs, Flow, task drawers and schedule forms share the same control hierarchy.
- The schedule drawer has one heading, a compact week strip and flat task rows.
  Prompt text and timing help expand locally. Edit, run, pause/resume, remove
  and conversation actions use named icons; empty days do not repeat text.

## Main workspace scheduling

Two issues prevented the previous integration from being complete:

1. MoonTown's desktop HTTP service stored schedules but did not advance them.
2. MoonDesk uses workspace ids such as `book-coding`; MoonTown's registered
   book is `coding`. Schedule creation and dispatch now resolve that alias,
   while preserving exact matches for existing catalog entries.

The desktop service now has an opt-in five-second schedule clock. It uses the
existing MoonTown reservations, outbox and MoonClaw private control. It runs
explicit user schedules without starting the town simulation. Its heartbeat
is written to `code-schedules/runner.json` in MoonTown's product state.

`scripts/connect-moontown-desktop.mbtx` installs the built owner service,
its UI and policy into the app's control directory, connects the local pack
runtime, and installs `com.vectie.moontown.moondesk.desktop` as a user launch
agent. It starts at login and stays running when MoonDesk closes. Existing
MoonClaw credentials are referenced by path; they are not copied into the
launch agent. `register-desktop-schedule-books.mbtx` registers existing books
through MoonTown's API. Newly created books already use that registration API.
The 44 existing main-workspace books were registered. Legacy book folders
without an identity manifest received a minimal `book.json`; existing
manifests, documents and skills were preserved.

The local service listens on `127.0.0.1:17842`. The packaged MoonDesk uses its
existing `/api/mooncode/schedules` proxy to reach it. Recurrence runs while
the Mac is awake and the user session is available; due work resumes after
wake/login.

## Verification

To use it: select a MoonBook, open **Code → calendar → New scheduled task**,
enter the task and start time, choose the recurrence, and save. Open the
schedule's conversation icon to inspect its outputs. Pause/resume and editing
stay in the same drawer. MoonTown is also available from **Packs**.

- Created a 60-second repeating schedule through the actual packaged app's
  `127.0.0.1:4201/api/mooncode/schedules` route, targeting `book-coding`.
  No Run now action or manual scheduler tick was used.
- Two distinct command ids completed automatically. The app was closed after
  the first completion, and port 4201 was confirmed closed before the second
  run. MoonTown remained running and completed the second run independently.
  Completion times were 14:28:47 and 14:29:52 CST on 2026-10-15.
- The dedicated file tools appended one line per run to
  `books/coding/inbox/desktop-recurring-check-1792045714.txt`; the resulting
  file contains exactly two `Schedule verification completed` lines.
  Evidence: `_build/desktop-typography-20261015/recurring-evidence.json`.
- The first attempted test selected an arbitrary shell command and waited for
  approval because no ExecutionSandbox route is configured in this workspace.
  That command was cancelled and its schedule paused. The successful test
  explicitly used existing read/write tools. Shell-based tasks still require
  their normal execution setup; this change does not claim otherwise.
- Both test schedules are paused, with no pending command. The background
  service remains installed for user-created schedules.
- 104 focused MoonBit navigation/journey/editor tests passed; 44 JavaScript
  tests passed with one optional live-proxy test skipped. The direct packaged
  recurrence check above covers the live path. MoonTown's 13 schedule tests
  passed, including workspace-id alias resolution.
  After the schedule drawer cleanup, the 12 calendar/task-schedule regression
  tests also passed (the optional live-proxy test remained skipped).
- MoonBit interface generation/formatting and the frontend production build
  passed. Desktop visual checks cover Desk, Code, Book editing, Flow and Packs;
  Book's formatting toolbar no longer overlaps its source/preview columns.
- The final UI is installed in `/Applications/MoonDesk.app`. Its embedded
  assets are compared with the build and its ad-hoc signature is verified.

### Visual evidence

- [Installed Desk](design/moondesk-icons/typography-packaged-desk-20261015.png)
- [Installed schedules](design/moondesk-icons/typography-packaged-schedules-20261015.png)
- [Narrow Packs view](design/moondesk-icons/typography-packs-mobile-20261015.png)
- [Narrow schedule drawer](design/moondesk-icons/typography-schedules-mobile-20261015.png)

The 390px viewport has no horizontal page overflow. Its destination menu opens
and retains access to all five destinations. The native macOS app was also
inspected directly; its completed/paused schedule is visible in Code's calendar.
MoonTown's embedded interface loads from the main workspace's Packs surface.
