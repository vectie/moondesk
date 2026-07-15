# MoonCode Session Lifecycle E2E Evidence

Date: 2026-07-15

## Purpose

This gate verifies the user-facing session lifecycle against a real Moondesk
host, a real MoonClaw daemon, and the production Rabbita bundle. Browser
acceptance uses visible keyboard and mouse actions. Direct HTTP mutation is not
accepted as UI evidence.

The gate answers five questions for every step:

1. What should the user see?
2. Why should it be visible?
3. What action can the user take?
4. What durable state should that action create?
5. Does reload and storage inspection prove the outcome?

## Architecture Under Test

MoonClaw owns session metadata, custom titles, archive state, deletion, journal
order, and canonical conversation. Moondesk owns only transport adaptation and
UI state. The rail reads active and archived metadata catalogs; it does not
hydrate or rebuild conversations. The selected transcript reads one canonical
session and watches one monotonic revision.

Lifecycle mutations use:

```text
POST /api/mooncode/sessions/<session-id>/lifecycle
```

Supported actions are `rename`, `archive`, `restore`, and `delete`.

## Acceptance Journey

| Step | User sees | User action | Expected outcome |
| --- | --- | --- | --- |
| Fresh Code view | Existing sessions grouped by MoonBook, with unbound sessions in General | Click New Chat | Blank draft remains selected; no old transcript flashes |
| First submit | User text appears immediately | Type with keyboard and press Enter | One optimistic user row is appended before the network reply |
| Real work starts | One factual Work disclosure below that user row | Wait | Work appears only after MoonClaw emits turn-owned progress |
| Completion | Assistant answer below Work | Wait | Work folds in place and canonical order is user, work, assistant |
| Search | Compact search field in the rail | Type part of the title | Matching metadata rows remain; selected transcript is not rebuilt |
| Rename | Row action menu and inline title input | Enter a title and confirm | Row changes in place and title survives hard reload |
| Archive | Archive action | Click Archive | Active row disappears, selection clears if needed, archived count increases |
| Restore | Archived disclosure and row action | Expand and click Restore | Row returns to its durable active group and order |
| Delete | Explicit confirmation controls | Confirm permanent delete | Session disappears from both catalogs; MoonBook content remains |
| Narrow layout | Rail above chat and a visible composer | Repeat navigation at 390 x 844 | No horizontal overflow, overlap, hidden action, or unreachable composer |

## Assertions

- No user, work, or assistant row changes position after first insertion.
- No synthetic Working text is shown before a MoonClaw signal.
- A compact listing response cannot overwrite the selected conversation.
- Active and archived rows are disjoint.
- Search changes visibility, not source order or selection identity.
- Rename updates the durable snapshot and emits a unique journal event id.
- Archive and restore are atomic directory moves owned by MoonClaw.
- Delete is rejected while a session is running and removes only session data.
- Listing transport failure preserves the last good rail.
- Browser console has no errors or warnings during the journey.

## Result

Passed with the production bundle and real local processes.

- A new session accepted keyboard submission and showed the local user row plus
  real Work within the first 180 ms browser sample.
- The canonical answer arrived once; completed Work stayed folded between the
  user and assistant rows.
- Search returned exactly the matching row.
- Rename survived a hard reload.
- Archive moved the session out of active storage and into archived storage.
- Restore reversed that move.
- Permanent delete removed both active and archived session storage while the
  containing MoonBook remained intact.
- The desktop and 390 x 844 layouts had no horizontal overflow; the rail,
  transcript, and composer remained reachable.
- Browser error and warning logs were empty.

## Defects Found And Closed

1. Numeric listing timestamps failed an all-or-nothing UI decode. The adapter
   now normalizes scalar timestamps to text.
2. Compact create/watch responses omitted the required archive field. The
   projection now always supplies `archived: false` when absent.
3. The archived disclosure rendered a literal count interpolation token. The
   label now evaluates the count.
4. Archived row menus opened outside the reachable rail area. Their popovers
   now open upward.
5. Delete confirmation remained underneath the original menu, so hit testing
   could activate Archive. Confirmation now replaces the menu.
6. The narrow rail left a clipped list sliver. Its mobile grid track now has a
   stable responsive height.
7. Rename journal ids contained a literal interpolation token. MoonClaw now
   emits a generated id and has a regression assertion.

## Repeatable Gates

Run from the repository roots:

```sh
# MoonClaw
moon info
moon fmt
moon test --target native

# Moondesk
moon info
moon fmt
moon test --target native

# Rabbita UI
moon test --target js
npm run build
```

Then repeat the visible journey with a freshly started MoonClaw daemon and
Moondesk host. Keep the browser test on disposable sessions and verify storage
after archive, restore, and delete.

## Remaining Release Work

This gate closes ordinary session lifecycle behavior. It does not close
large-history virtualization, measured large-catalog latency, automated
accessibility checks, long-soak reconnect fault injection, or the single local
release-gate command. Those remain Milestone G work.
