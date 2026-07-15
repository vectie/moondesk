# MoonDesk Rabbita UI

Browser-mode desktop shell for MoonDesk. The shell includes Explorer, Search,
Inbox, MoonCode, Town, Runs, and Settings activities. MoonCode talks to
`/api/mooncode/*` for book-scoped coding sessions, while daemon/model inspection
uses the host `/api/moonclaw/*` routes.

## Source Layout

- `main/app_model.mbt` and `main/app_initial_model.mbt`: top-level model,
  messages, and initial state.
- `main/app_update*.mbt`: reducer routing for shell, workspace, MoonCode,
  MoonTown, inbox, daemon, and result messages.
- `main/commands*.mbt`: non-MoonCode browser effects and host requests.
- `main/mooncode_model.mbt`: compact session metadata and canonical
  conversation DTOs.
- `main/mooncode_canonical_transcript.mbt` and
  `main/mooncode_optimistic_state.mbt`: append-ordered canonical projection and
  unacknowledged local user rows.
- `main/mooncode_bootstrap_commands.mbt`,
  `main/mooncode_session_fetch_commands.mbt`,
  `main/mooncode_session_mutation_commands.mbt`, and
  `main/mooncode_session_watch_commands.mbt`: status, listing, mutation, and
  one selected-session watch generation.
- `main/mooncode_session_management_commands.mbt` and
  `main/mooncode_session_management_state.mbt`: search plus durable rename,
  archive, restore, and guarded delete behavior.
- `main/mooncode_session_effects.mbt`: selected-session effect ownership and
  retry timing.
- `main/mooncode_views.mbt`, `main/mooncode_transcript_views.mbt`, and
  `main/mooncode_markdown_views.mbt`: grouped session rail, canonical chat,
  folded work, safe Markdown, evidence, and composer.
- `main/moonwiki_*_views.mbt`: Desk and MoonWiki workspace surfaces.
- `main/*_wbtest.mbt`: reducer, transcript, effect, navigation, Markdown, and
  session lifecycle regression coverage.

MoonCode UI code must consume only the host's compact listing and canonical
selected-session contracts. It must not add an event merger, replay reducer,
runtime supervisor, local conversation store, or rail-row chat hydration.

The warning baseline is intentionally clean:

- `moon check --target native` from the repository root.
- `moon check --target js` from `ui/rabbita-desk`.
- `npm run build` from `ui/rabbita-desk`.

```bash
npm run dev
npm run build
```
