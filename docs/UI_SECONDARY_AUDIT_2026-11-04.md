# Secondary UI audit — 2026-11-04

Continued the AGENTS.md audit through the remaining drawers, settings and
dialogs. Actual filenames, document text and book names remain content.

| Surface | Change |
| --- | --- |
| Preferences | One drawer heading; visible field labels, compact Save/Cancel, icon utilities. Empty submissions disabled; unsaved edits survive redraw and book changes. |
| Learning | Removed duplicate headings, introductions and zero counts. Consequential acceptance guidance remains in a disclosure. Drafts survive redraw; empty submissions disabled. |
| Check packs | Compact disclosure rows with enable/run icons. Descriptions and read/warning details expand locally. Run requires a selected document. |
| Inbox | One heading, actual path retained, Finder icon, import actions and optional behavior disclosure. |
| Command palette | One-row commands, localized search and empty state, icon close. Chinese search matches translated commands. Settings and Search Books now open their actual local tools; obsolete Inbox-note command removed. |
| Coding setup | Save/add actions enable independently for their corresponding required fields. Clearing instructions remains permitted. |
| Specialist dialog | Icon close, name on its own row, purpose/example in matching columns; empty saved-list heading omitted. |
| Collaboration | One heading, refresh icon, channel creation behind disclosure, concise empty state, aligned composer actions. Empty display names, messages and channel names cannot submit. |
| Calendar | One heading, refresh icon, optional reminder explanation, aligned Save/Cancel. Empty titles and non-increasing times cannot save. |
| Header tools | Desktop menu omits Recent tasks/Results already in the header; mobile retains those routes. Language control remains on one line. |

## Validation

- 117 JavaScript tests passed, covering draft preservation, action prerequisites,
  loading/error/retry/empty states, localization, dialog controls and results.
- 49 focused MoonBit tests passed. `moon info --target js`, `moon fmt` and
  `moon check --target js` completed; no new public API changes.
- Preview inspection covered preferences, learning, check packs, Inbox, setup,
  specialist creation, command search/settings, collaboration and calendar.
- No real collaboration message, preference, calendar event, model request,
  check execution or specialist was submitted during this inspection.

## Packaged application

- Installed the production frontend in `/Applications/MoonDesk.app`; verified
  its ad hoc signature and matched the installed entry HTML to the build.
  Previous assets are in `_build/ui-secondary-20261104/previous-assets`.
- In the actual app, Settings opens the preferences drawer; its empty Save
  action is disabled. Calendar New stays open and its empty Save is disabled;
  Cancel returns to the calendar list.
- Native inspection exposed WebKit's shorter default select appearance.
  Secondary forms now share an explicit control height and chevron treatment.
- Native screenshots are under `docs/design/ui-secondary-20261104/`.
