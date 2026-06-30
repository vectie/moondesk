# Wiki Mode Test Plan

Moondesk currently exposes three workspace modes:

- `Desk`: scoped virtual filesystem navigation.
- `Wiki`: human-language MoonBook knowledge work.
- `Code`: MoonCode sessions, command queues, diffs, tests, and runtime evidence.

This plan focuses on `Wiki`. Desk and Code appear only as boundary checks:
Wiki must preserve selected workspace/path when the operator switches modes, but
Wiki tests must not become general Desk browsing tests or MoonCode runtime tests.

## Goal

Prove that Wiki mode can run a selected MoonBook forward and backward.

Forward run:

```text
inbox/source/method/wiki input
  -> Wiki request or book-pattern action
  -> Moontown/MoonClaw bounded run when execution is needed
  -> raw evidence, progress, events, generated pages, review rows, receipts
  -> accepted wiki update
```

Backward run:

```text
generated page, run artifact, review row, or finding
  -> inspect source evidence and provenance
  -> compare against existing wiki state
  -> accept, reject, revise, or send back through a new run
  -> durable wiki/history/review record
```

The strongest coverage should be end-to-end: a seeded MoonBook, the native
Moondesk host, the built Rabbita UI, browser interaction, route assertions, and
filesystem assertions all running together.

## Non-Goals

Wiki tests should not validate:

- Desk-only filesystem metadata beyond selected context and handoff behavior.
- MoonCode command execution, patch application, package creation, or eval
  evidence except where Wiki displays MoonBook review artifacts.
- Real external crawling, scraping, model calls, or network-dependent source
  discovery.
- Domain-specific research packs in Moondesk core.
- Destructive file operations such as delete, rename, or move unless Wiki gains
  those operations deliberately.

## Test Layers

### Contract Unit Tests

These are fast `moon test` checks over pure helpers, reducers, and projections.

Primary files:

- `core/types_test.mbt`
- `adapters/moonbook/adapter_test.mbt`
- `internal/moonwiki/moonwiki_request_wbtest.mbt`
- `internal/moonwiki/event_feed_handlers_wbtest.mbt`
- `internal/moonwiki/review_diff_handlers_wbtest.mbt`
- `internal/moonwiki/pdf_watch_patterns_wbtest.mbt`
- `ui/rabbita-desk/main/app_markdown_edit_wbtest.mbt`
- `ui/rabbita-desk/main/app_desk_navigation_wbtest.mbt`
- `ui/rabbita-desk/main/app_command_palette_wbtest.mbt`
- `ui/rabbita-desk/main/app_bootstrap_wbtest.mbt`

Coverage:

- MoonBook canonical sections project Wiki-owned roots consistently:
  `wiki`, `wiki/sources`, `wiki/findings`, `wiki/methods`, `wiki/reviews`,
  `wiki/history`, `raw`, `raw/analysis-runs`, `inbox`, `book/site/generated`.
- Source layer inference distinguishes Wiki, Raw Evidence, Review, Generated,
  Skill, Schema, Tool, App, and runtime artifact paths.
- Editable Markdown path checks allow only `wiki/*.md`, `wiki/*.markdown`,
  `wiki/*.mbt.md`, `inbox/*.md`, `inbox/*.markdown`, and `inbox/*.mbt.md`.
- Markdown editor reducer starts from selected preview, preserves same-path
  drafts, clears on path changes, saves successful writes, and preserves draft
  state on failed writes.
- Search reducer handles query changes, empty query, result selection, workspace
  filters, loading status, failed search, and path focus.
- Inbox reducer handles note draft, save success, save failure, import success,
  local browser import staging, and context-link actions.
- Review diff helpers classify unchanged, added-only, removed-only, mixed
  changed, missing base, missing head, and bounded long diff body cases.
- Run/event projection normalizes Moontown and MoonClaw progress records without
  leaking runtime-only terminology into the main Wiki user flow.
- Command palette in Wiki keeps operating actions visible but does not start
  Code sessions implicitly.

### Workspace And Wiki Route Tests

These tests run handler-level or server-level checks against temporary fixture
workspaces and assert JSON/file responses.

Primary routes:

```text
GET  /api/workspaces
GET  /api/workspaces/<workspace-id>/entries?path=<relative-path>
GET  /api/workspaces/<workspace-id>/preview?path=<relative-path>
GET  /api/workspaces/<workspace-id>/raw?path=<relative-path>
GET  /api/workspaces/<workspace-id>/file/<relative-path>
GET  /api/workspaces/<workspace-id>/site/<relative-path>
POST /api/workspaces/<workspace-id>/markdown
POST /api/workspaces/<workspace-id>/inbox
POST /api/workspaces/<workspace-id>/import
GET  /api/search?query=<query>&workspace=<workspace-id>
GET  /api/workspaces/<workspace-id>/review-diff?base=<path>&head=<path>
POST /api/review/items/decision
GET  /api/town/progress
GET  /api/town/events
GET  /api/town/messages
GET  /api/town/requests
GET  /api/town/standing-goals
POST /api/town/requests
POST /api/town/standing-goals
GET  /api/moonclaw/runs
GET  /api/moonclaw/progress
GET  /api/moonclaw/events
GET  /api/moonclaw/runs/<run-id>/artifacts
POST /api/books/from-pattern
```

Coverage:

- Unknown workspace returns `404`.
- Wrong method returns `405`.
- Invalid JSON body returns `400`.
- Encoded traversal and absolute paths are rejected.
- Markdown writes create missing parent directories under `wiki/` and `inbox/`.
- Markdown writes reject raw evidence, generated output, directories, and
  non-Markdown paths.
- Inbox note creation writes a titled Markdown note and returns the clean path.
- Inbox explicit-path edits stay under `inbox/`.
- Imports create Markdown notes, preserve URL/file/content metadata, and write
  data-url sidecars only when supplied.
- Search finds path matches and body matches, excludes hidden/system files,
  excludes binary-only entries, bounds snippets, and honors workspace filters.
- Preview reads current saved Markdown after an edit without requiring a server
  restart.
- Generated-site preview and asset routes are scoped to the selected book.
- Review diff compares two scoped paths and reports additions, removals,
  changed state, and bounded body.
- Review decisions accept or reject scoped `wiki/reviews` items, write durable
  receipts under `wiki/reviews/decisions`, and reject traversal attempts.
- Town request and standing-goal endpoints persist book-scoped records that Wiki
  can display in the request ledger.
- MoonClaw run projection reads existing run artifacts without requiring the
  daemon to be running.
- Book-pattern creation rejects unsupported pattern ids and creates expected
  MoonBook paths for supported generic patterns.

### Browser End-to-End Tests

These are the main Wiki confidence tests. They should start the real server
against a seeded workspace, load the built UI in a browser, interact with Wiki
mode, and verify both DOM state and filesystem effects.

Recommended harness:

- Seed fixture under `/private/tmp/moondesk-wiki-e2e/<run-id>`.
- Build UI with `npm --prefix ui/rabbita-desk run build`.
- Start server with:

```sh
moon run cmd/main -- serve /private/tmp/moondesk-wiki-e2e/<run-id> --ui ui/rabbita-desk/dist --host 127.0.0.1 --port <free-port>
```

- Drive browser with Playwright or the in-app browser controller.
- Use unique ports and temp directories for parallel-safe runs.
- Tear down the server process at the end of each run.
- Assert filesystem state after each mutating journey.

Browser assertions should prefer stable text, roles, URLs, and data attributes
when available. If the UI lacks stable selectors, add lightweight semantic test
hooks only where they improve maintainability.

## Canonical Fixture

Create one broad fixture and several small edge fixtures.

```text
wiki-fixture/
  book.json
  wiki/
    index.md
    sources/
      seed-source.md
      extracted-quote.markdown
    findings/
      open-finding.md
      accepted-finding.md
    methods/
      baseline-method.md
      pdf-evidence-watch.md
    reviews/
      pending-review.md
      accepted-review.md
    history/
      2026-06-30-baseline.md
  raw/
    evidence.txt
    sources/
      source-a.txt
      source-b.json
    analysis-runs/
      run-forward-001/
        result.json
        events.jsonl
        artifacts/
          generated-summary.md
  inbox/
    seed-note.md
    imports/
      imported-url.md
      imported-url.data-url.txt
  book/
    site/
      generated/
        index.html
        findings.html
        assets/
          site.css
  .moontown/
    requests/
      request-forward-001.json
    standing-goals/
      goal-weekly-review.json
    town.json
  moonclaw-jobs/
    run-forward-001/
      result.json
      events.jsonl
      artifacts/
        generated-summary.md
  skills/
    wiki-method/
      SKILL.md
  schemas/
    review.schema.md
```

Edge fixtures:

- Empty MoonBook with only `book.json`.
- Wiki-only book with no `raw` or generated site files.
- Generated-output-only book with stale `wiki/index.md`.
- Review-heavy book with many pending and accepted review rows.
- Large Wiki directory with at least 300 Markdown files.
- Filename stress book containing spaces, brackets, `#`, `%`, `?`, unicode
  characters, and long names.
- Security fixture with sibling `outside.md` next to the book root to test
  traversal rejection.

## End-to-End Journeys

### E2E 1: Wiki Mode Boot And Context

Steps:

1. Start server against the canonical fixture.
2. Open `/`.
3. Select `Wiki`.
4. Select the seeded MoonBook.
5. Open `wiki/index.md`.

Assert:

- Mode toggle has exactly `Desk`, `Wiki`, and `Code`.
- `Wiki` is active.
- Workspace name is visible.
- `wiki/index.md` preview is visible as Markdown.
- Activity rail shows Files, Search, Inbox, Town, Runs, and Settings.
- Switching to `Desk` and back to `Wiki` preserves selected workspace/path.
- Switching to `Code` and back does not start a MoonCode session unless the
  operator explicitly asks for one.

### E2E 2: Forward Run From Inbox To Wiki Review

Steps:

1. Open Wiki Inbox.
2. Create a note titled `Forward seed`.
3. Verify the note lands under `inbox/`.
4. Open the saved inbox note.
5. Promote or copy its content into a new `wiki/findings/forward-seed.md`
   through the Markdown editor path available in the UI.
6. Search for a phrase from the new finding.
7. Open the search result.
8. Open review diff against `wiki/index.md` or another baseline page.

Assert:

- The inbox note file exists on disk and contains the submitted content.
- The promoted Wiki Markdown file exists on disk and is scoped under `wiki/`.
- Preview refreshes to the saved content.
- Search finds the new page by body text.
- Review diff shows additions and a changed state.
- No files are written outside the selected book root.

### E2E 3: Forward Run Through Town Request

Steps:

1. Open Wiki Town/request pane.
2. Submit a request targeting the selected book with a Wiki-oriented prompt.
3. Refresh request ledger and town messages.
4. Open Runs/progress pane.
5. Load existing seeded progress and events for `run-forward-001`.
6. Open the generated run artifact preview.

Assert:

- Request record is persisted under the fixture's town request storage.
- Request row identifies the selected book/workspace.
- Town messages/progress render without requiring a live daemon.
- Run artifact links stay scoped to the selected MoonBook.
- The generated artifact can be inspected from Wiki without switching to Code.

### E2E 4: Forward Run Through Book Pattern Builder

Steps:

1. Open the Wiki book-pattern builder surface.
2. Select the supported generic PDF Evidence Watch pattern.
3. Fill book id, source URLs, cadence, method page, and notification rule.
4. Create the book.
5. Open the created book workspace.
6. Inspect generated `wiki/methods`, `wiki/sources`, `raw/analysis-runs`,
   `schemas`, `skills`, and `book/site/generated` paths.

Assert:

- Unsupported pattern ids are rejected with a visible error.
- Supported pattern creation produces the expected MoonBook structure.
- The created method page is editable as Wiki Markdown.
- Generated site placeholders preview through the scoped site route.
- Standing-watch metadata appears in the appropriate Wiki/Town surfaces.

### E2E 5: Backward Run From Generated Page To Source Evidence

Steps:

1. Open `book/site/generated/findings.html` in Wiki preview.
2. Navigate from generated output context back to the source Wiki finding.
3. Open the linked raw evidence under `raw/sources`.
4. Open the matching run artifact under `raw/analysis-runs` or
   `moonclaw-jobs`.
5. Open review diff between the accepted finding and pending finding.

Assert:

- Generated page is served only through the selected workspace route.
- Source Wiki page opens in Wiki mode with the same selected workspace.
- Raw evidence is previewed read-only.
- Run artifact metadata is visible in Runs or preview.
- Diff explains what changed between generated/proposed and accepted content.

### E2E 6: Backward Run Review Acceptance And Rejection

Steps:

1. Open pending review rows.
2. Inspect a pending finding, its evidence path, and its generated artifact.
3. Accept one review item into a Wiki page or accepted review receipt.
4. Reject another review item with a note.
5. Refresh reviews, history, and search.

Assert:

- Accepted review writes a durable receipt under `wiki/reviews` or the current
  Bookkeeper-owned review path.
- Accepted content is visible in the target Wiki page or accepted finding.
- Rejected review remains auditable and does not mutate accepted Wiki content.
- History or review status changes are searchable.
- Refreshing the browser does not lose review state.

### E2E 7: Markdown Edit Recovery

Steps:

1. Open `wiki/sources/seed-source.md`.
2. Start editing.
3. Type unsaved content.
4. Reload the same path.
5. Navigate to another Wiki path.
6. Return and save a new edit.

Assert:

- Same-path reload preserves draft content.
- Navigating to a different path clears the editor state deliberately.
- Save writes exactly the current draft content.
- Failed save keeps the draft visible and reports failure.

### E2E 8: Search Across Forward And Backward Artifacts

Steps:

1. Search for text that appears in `wiki/findings`.
2. Search for text that appears only in `raw/sources`.
3. Search for text that appears only in `raw/analysis-runs`.
4. Filter search to the selected workspace.
5. Select each result.

Assert:

- Search hits include workspace id, workspace name, path, title, kind, source
  layer, and bounded snippet.
- Result selection opens the containing path in Wiki context.
- Binary and hidden files are excluded.
- Large result sets stop at the documented limit.

### E2E 9: Path Safety In The Browser

Steps:

1. Try quick-open or URL-crafted preview paths containing `../outside.md`.
2. Try encoded traversal such as `%2E%2E%2Foutside.md`.
3. Try Markdown save to `raw/escaped.md`.
4. Try Markdown save to `wiki/../raw/escaped.md`.

Assert:

- Traversal previews fail with a scoped error.
- Invalid Markdown saves fail without creating files.
- No sibling fixture files are read or written.
- The UI remains usable after each failure.

### E2E 10: Wiki Mode Resilience

Steps:

1. Start with no live Moontown daemon.
2. Start with no live MoonClaw daemon.
3. Open Wiki Files, Inbox, Search, Town, Runs, Settings, and generated site
   preview.
4. Submit local-only actions such as Markdown save and inbox note creation.

Assert:

- Local Wiki editing, preview, inbox, search, and generated-site inspection work
  without live daemons.
- Daemon-dependent panels show unavailable/empty states instead of failing the
  shell.
- No Code mode runtime state is required for Wiki mode.

## Integration Matrix

| Area | Forward Run Checks | Backward Run Checks |
| --- | --- | --- |
| Workspace | Select book, open Wiki paths, create new Wiki files | Return from generated/review/run context to accepted Wiki paths |
| Inbox | Stage notes/imports before promotion | Trace accepted content back to originating inbox/import item |
| Markdown | Write new findings, methods, and source pages | Revise accepted pages from review evidence |
| Search | Find newly created pages and source text | Find history, reviews, and evidence for existing pages |
| Town | Submit requests and standing goals | Inspect request results and route follow-up work |
| MoonClaw Runs | Display bounded run progress and artifacts | Trace artifact provenance to raw evidence and review records |
| Reviews | Create pending review rows from proposed output | Accept/reject and persist receipts/history |
| Generated Site | Publish or inspect generated output | Navigate back from output to source Wiki/evidence |
| Security | Reject escapes during writes and previews | Reject crafted links from generated/review artifacts |
| Mode Boundary | Stay in Wiki during knowledge work | Preserve context when checking Desk/Code and returning |

## Automation Commands

Use these checks before handing off Wiki-mode work:

```sh
moon check --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test internal/moonwiki --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test core --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test adapters/moonbook --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test ui/rabbita-desk/main --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000
npm --prefix ui/rabbita-desk run build
moon run cmd/main --target native -- lepusa live-smoke macos --strict --serve-port <free-port> --workspace-root /Users/kq/Workspace/moondesk --ui ui/rabbita-desk/dist --out _build/lepusa/<run-id>
moon info --target native
moon info --target js
moon fmt
git diff --check
scripts/validate-core-boundaries.sh
```

Run browser E2E after the UI build:

```sh
moon run cmd/main -- serve /private/tmp/moondesk-wiki-e2e/<run-id> --ui ui/rabbita-desk/dist --host 127.0.0.1 --port <free-port>
```

The E2E runner should fail if it leaves the server process running, writes
outside the fixture root, or depends on network access.

## Latest Manual E2E Evidence

- Dedicated fixture:
  `/var/folders/_j/kcn3f7817s71gymnv_nnn1bm0000gn/T/moondesk-wiki-review-ui-8ucuuf`.
- Dedicated server: `http://127.0.0.1:49243/`, stopped after the run.
- Browser flow: selected Wiki mode, opened Settings, filled the Review decision
  note, accepted `wiki/reviews/pending-ui.md`, rejected
  `wiki/reviews/reject-ui.md`, and verified both receipts appeared in the
  review queue.
- Filesystem checks verified both receipt JSON files and confirmed
  `wiki/index.md` remained unchanged after rejection.
- Browser console warning/error logs were empty.
- Lepusa live smoke against the rebuilt UI passed with
  `lepusa live-smoke macos: ok`; release-readiness still reports the known
  missing signing configuration.

## Acceptance Criteria

Wiki mode is sufficiently tested when:

- At least one forward run journey creates durable Wiki content from inbox or
  request input.
- At least one forward run journey displays generated run output and review
  state from seeded artifacts.
- At least one backward run journey traces generated output back to Wiki source,
  raw evidence, run artifact, and review receipt.
- Markdown editing is covered at reducer, route, and browser levels.
- Search, inbox, town request, run projection, review diff, generated-site
  preview, and path-security behavior are covered end to end.
- Tests prove Wiki mode works without live MoonClaw or Moontown daemons for
  local book editing and inspection.
- Mode-boundary tests prove Wiki preserves context across Desk and Code without
  accidentally starting Code execution.
- `moon info` diffs are empty unless a deliberate public API change was made.
