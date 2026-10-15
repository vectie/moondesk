# Workspace product features — October 13, 2026

This document records the document, data, artifact, shared-work and calendar implementation from the feature comparison program. It complements `PRODUCT_FEATURE_PROGRAM_2026-10-13.md`. These changes extend the existing MoonBook, Office editing, review, conversation and MoonTown execution paths.

## User journeys

### Return to a complete result

Open **Document tools → Results**. A result groups its run, output files and originating conversation. Background document results are loaded across the selected MoonBook, and the latest completed run of each Code schedule appears alongside ordinary work.

- Filter by **All results**, **Unread**, or **Needs attention**; search a title, summary or output filename.
- Open an output file in the current workspace or return to its document/Code conversation.
- **Add to task** adds the result summary and output paths to the shared contextual composer.
- **Export result** creates a readable HTML work package.
- **Mark read** records the viewed result revision in this browser. A changed result becomes unread again.

The Code schedule owner currently retains its latest result, so this inbox does not claim to reconstruct the complete historical Code run archive. Read receipts are local to the browser; the underlying work and document results are server-owned.

### Edit and discuss a spreadsheet

Open an XLSX in the document workspace. Its populated cells now appear in a labelled grid with sheet tabs, sticky row/column headings, selected-cell highlighting and a formula/value toggle. Selecting a cell invokes the existing Office item editor and its existing save/review flow.

**Export visible grid as CSV** exports the displayed populated-row/populated-column projection with CSV quoting. The preview preserves cell addresses and sheet identity; it does not invent missing cells or claim Excel layout/chart/pivot fidelity. The original Office package export remains available through the existing editor.

### Write and revise a note

Open the existing Markdown editor. Its formatting toolbar provides headings, bold, italic, links, bullets, numbered lists, checklists, quotations, inline code and tables. Command/Control+B, I and K format the selection. The existing live preview and save behavior remain the authoritative document editing path.

Select a passage, then choose **Rewrite selection → Make clearer / Make shorter / Make more formal / Explain selection**. MoonDesk stages a document conversation request with the exact passage and document path. The user sends that request through the existing document agent workflow. Rewriting does not silently replace the document.

This is rich Markdown authoring, not a new WYSIWYG engine or full Office editor.

### Reuse an artifact

Open **Document tools → Artifacts**.

- **Open beside chat** returns to the persisted artifact.
- **Reuse as template** creates an independent artifact in the same MoonBook, preserving its item labels, values and sources while resetting checklist completion.
- **Export standalone copy** downloads a self-contained HTML artifact. It works without MoonDesk, allows item/value edits and additions, and offers **Download updated copy** to retain edits.

The exported copy is independent of the book and explicitly says so. This work does not replace the existing hosted pack-app/portable tool export mechanisms or add arbitrary application bundling.

### Finish a document review discussion

Open **Document tools → Review**. In addition to existing create/reply/pin/resolve actions, the room supports:

- Open/resolved/assigned filters.
- Reopening resolved discussions.
- Changing or clearing a person/agent assignment.
- Explicit refresh and a 15-second refresh while the review panel is visible.
- Retained discussion/reply drafts during refresh and failed submission.
- Display names shared with the Book room profile.

Discussion records and decisions remain on the server. Existing document anchors, revision handling, review packages and agent requests remain in use.

### Work with other people in a Book room

Open **Document tools → Book room**, enter a display name and start in **General**, or create a named channel.

- Post human updates, questions and decisions.
- Reply under a discussion and toggle Agree/Thanks/Question reactions.
- See connected participants and typing activity.
- Attach the selected document and navigate back to it.
- **Add to task** sends a discussion into the shared task context.

Messages, channels, replies and reactions persist in MoonDesk. Presence expires after 45 seconds; the visible room refreshes every five seconds. Drafts remain in the current browser session when switching channels or retrying a message.

The room connects people using the same MoonDesk server and MoonBook. It does not create external invitations, hosted public share links, live collaborative document cursors, or independently executing multi-user agent chats. A display name is a collaboration label, not an account identity system.

### Schedule Code work in a calendar

Open Code's scheduled-work panel. The enhanced interface offers a seven-day calendar, previous/next week navigation and named task creation/editing.

- Pick a start date/time and the task/model.
- Run once, daily, on weekdays, weekly, hourly, or at a custom interval.
- Edit, pause/resume, **Run now**, remove future runs, or open the resulting Code conversation.
- See the latest completion status and time.

MoonTown owns these schedules, including dispatch and persistence; MoonClaw remains the Code execution owner. Daily/weekday/weekly schedules use their saved IANA timezone and OS timezone data to retain wall-clock time across daylight-saving changes. Weekly tasks repeat on the start date's weekday. A manual run preserves the original calendar anchor. Interval schedules retain their existing behavior of measuring from the prior run's completion.

Removing a schedule leaves its conversation available. A running schedule can be paused, and editing/removal becomes available after the active run finishes. The calendar is a projection of upcoming work; runtime availability and execution duration still affect actual completion.

### Keep review dates and reminders with the book

Open **Document tools → Calendar**. Create an event with title, notes, start/end, related file and reminder. Choose once/daily/weekdays/weekly recurrence. The agenda shows the next two weeks and allows editing/removing events or opening their related work.

MoonDesk displays an inline reminder while that book calendar is open. **Enable desktop reminders** requests the browser's notification permission. **Export to calendar** downloads an `.ics` event with recurrence and a `VALARM`; importing that event into a calendar app provides its reminders when MoonDesk is closed. Exporting does not claim to install a calendar event automatically or provide closed-app MoonDesk delivery.

## Implementation map

| Area | Source |
|---|---|
| Results | `ui/rabbita-desk/workspace-results-runtime.js`; workspace-wide `document_automation_result_handlers.mbt` query |
| Spreadsheet preview | `ui/rabbita-desk/document-table-runtime.js` |
| Note editing | `ui/rabbita-desk/document-editing-runtime.js` |
| Artifact template/export | `internal/moonwiki/living_artifact_handlers.mbt`; `ui/rabbita-desk/workspace-artifact-export.js` |
| Review | `document_review_thread_handlers.mbt`; `workspace-features-runtime.js` |
| Shared room | `document_room_handlers.mbt`; `workspace-room-runtime.js`; `/api/document-room` GET/POST |
| Book events | `document_calendar_handlers.mbt`; `book-calendar-runtime.js`; `/api/document-calendar` GET/POST |
| Code calendar | `mooncode_schedules_views.mbt`; `mooncode-calendar-runtime.js`; existing `/api/mooncode/schedules` proxy |
| Schedule owner | `../moontown/src/code_schedules/{schedule,calendar,edit,store}.mbt`; `../moontown/src/cmd/desktop_server/code_schedule_api.mbt` |
| Styling | `ui/rabbita-desk/styles/workspace-results.css` |

## Verification

- 50 JavaScript tests pass across `workspace-features-runtime.test.mjs`, `workspace-results-runtime.test.mjs`, and `living-artifacts-runtime.test.mjs`.
- New tests cover result grouping/read revisions, scheduled Code results, calendar intervals/one-off behavior, timezone/DST weekday projection, Markdown selection formatting, standalone artifact escaping, calendar recurrence/reminder export, spreadsheet addresses/CSV, and room replies/reaction counts.
- MoonTown `code_schedules` native tests pass: 12/12, including durable edit/one-off/run-now/delete behavior, weekday weekend skipping, DST wall-clock preservation and manual-run anchor preservation.
- MoonTown targeted native typecheck and interface generation succeed. The public interface changes are the new calendar/edit APIs and optional backward-compatible schedule fields.
- New MoonDesk native tests cover room projection/presence, reaction toggling, calendar event fields and artifact template semantics. The parent integration pass owns their final execution and formatting. Earlier native package checks found no errors in the room/review/artifact implementation but were blocked by unrelated/in-progress package test errors.
- Full integrated browser interaction and visual verification are still required in the parent task; these test results are not a claim that every new surface has been exercised in a running application.

### Local running-server verification

On the isolated loopback server `http://127.0.0.1:4397`, only the `Coding-demo` fixture (`book-coding-demo`) was changed. Requests used the normal matching Origin header and the display name **Product check**. No external messages or notification permission requests were made.

- Created a **Product check** room channel, posted a document-linked message, posted a reply to that message, and added an Agree reaction. A fresh GET retained both messages, the reply parent and the reaction actor.
- Posted typing/presence and confirmed the active participant in the room response.
- Created **Product check: review the result bundle**, a weekday event in `Asia/Shanghai` with a 15-minute reminder and `README.md` context. A fresh GET retained the event fields.
- Confirmed the workspace-wide automation result endpoint responds for this fixture. Its empty state did not provide live populated-result evidence.
- The real server returned timestamps as numeric millisecond strings. Room/result date display now normalizes that representation; a regression test also covers second timestamps and ISO strings.

These checks establish live API behavior and read-after-write persistence, not restart recovery or browser interaction. The fixture data remains available for the parent's visual verification.

## Remaining comparison scope

Within these document/shared-work areas, the largest remaining capabilities are full Office fidelity, true WYSIWYG note editing, external/public sharing and invitations, live collaborative document editing, cross-device result read receipts, historical Code schedule run retention, and closed-app MoonDesk event notifications. The delivered features intentionally describe their actual behavior in the interface rather than claiming those broader capabilities.
