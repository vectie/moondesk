# Moondesk Roadmap

For the current implementation/readiness summary, see
[Moondesk Status](STATUS.md). In brief: Moondesk is usable as a local
single-user alpha. M0-M4 are functionally complete for local use, M5-M6 have
working first slices, and production native distribution still needs
credentialed notarization/installer policy, a native window shell if browser
launch is not enough, and product hardening.

## M0: Plan And Skeleton

Status: complete.

Deliverables:

- product plan
- architecture
- UI design
- reuse map
- MoonBit package skeleton
- browser-dev Rabbita shell stub

Acceptance:

- `moon check` works after skeleton exists
- `npm run build` works for the UI package after it exists

## M1: Read-Only Workspace Browser

Status: complete for browser-hosted use. The host API discovers books, lists
entries, previews files, serves raw files, and lists MoonClaw runs/artifacts.
The Rabbita UI is bound to those APIs.

Deliverables:

- workspace registry
- MoonBook discovery
- explorer tree
- markdown/html/json/image preview
- generated site links
- MoonClaw run/artifact listing

Acceptance:

- user can browse an existing MoonBook without terminal commands
- user can open `wiki/index.md`, `book/site/generated/index.html`, and run
  artifacts from the UI

## M2: Human Inbox And Editing

Status: complete for markdown inbox notes and URL import staging. The host can
create new inbox notes, edit existing `inbox/*` paths through
`POST /api/workspaces/:id/inbox`, and stage URL/data-url imports through
`POST /api/workspaces/:id/import`. The UI provides note title/content editing,
preview, selection loading, safe link-to-inbox staging, and a URL importer.

Deliverables:

- create note
- import file into book-local inbox
- edit markdown note
- preview before submit
- metadata/privacy scope

Acceptance:

- user can add files to a book safely without modifying durable wiki pages
- MoonBook can later ingest/promote staged files

## M3: Submit To Moontown

Status: first desktop slice complete. The UI can submit selected context to the
host, the host stages request records under `.moontown/moondesk-requests/`, the
UI can read the request ledger and town messages, and operators can create
standing-watch records in `.moontown/standing-goals.json`. A host-backed daemon
tick dispatch endpoint runs `moon run cmd/main -- daemon tick` when the
configured root is a Moontown checkout and records the attempt under
`.moontown/moondesk-dispatches/`.

Deliverables:

- request composer
- selected-context submission
- standing-goal creation
- request ledger
- town message stream
- one-shot daemon tick dispatch

Acceptance:

- user can select files/pages, submit a request, and see Moontown accept it
- standing-watch requests can be created from the desktop
- operator can run one Moontown daemon tick from the desktop host

## M4: Pure MoonBit Desktop Host

Status: desktop packaging slice complete. `cmd/main serve` and
`cmd/main desktop` run a pure MoonBit local host and serve the built Rabbita
shell; `desktop` opens the browser explicitly. Browser notification permission
can be requested from the UI. Scoped Finder reveal is available through
`POST /api/workspaces/:id/reveal`, and `cmd/main bundle` creates a
self-contained macOS `.app` distribution with the native MoonBit host
executable, bundled UI resources, ad-hoc signing by default, browser launch on
bundle start, and an optional zip archive. `cmd/main release` writes a release
manifest and can submit the zip through `xcrun notarytool` when a keychain
profile is provided. `cmd/main launch-agent` writes a LaunchAgent template for
supervised login startup.

Deliverables:

- MoonBit host package
- scoped file APIs
- browser-compatible desktop shell launch command
- host-backed import/open flows
- reveal in Finder
- optional desktop notifications through allowlisted host commands
- scoped filesystem roots
- local macOS app-shell bundle command
- self-contained native executable distribution
- ad-hoc or identity-based app signing

Acceptance:

- app runs through a MoonBit command or bundled native `.app`
- app can import local files through scoped host APIs
- no Rust, Cargo, Tauri, or `src-tauri` files exist
- no broad arbitrary filesystem access is required
- scoped reveal works only for paths under the selected workspace
- app bundle does not depend on `moon run` at launch

## M5: Search And Cross-Book Workflows

Status: first workflow slice complete. The host exposes
`GET /api/search?query=...` across discovered MoonBooks plus preference routes
for saved views and path tags. The UI can search, open hits, favorite paths,
save the current view, tag selected context, and copy selected context into
inbox notes.

Deliverables:

- cross-book search
- saved views
- tags/favorites
- copy/link between books through inbox semantics
- generated output library

Acceptance:

- user can find documents across multiple MoonBooks
- user can assemble context from multiple books and submit a task safely

## M6: Daily Human Operating System

Status: first operating slice complete. The UI has a daily operating surface
with request/run/message/standing-goal counts, browser notification trigger,
recent/favorite context, saved views, tags, a text export snapshot, a cadence
list and calendar-like due-tick view for standing goals, host-backed analytics,
live Moontown/MoonClaw progress summaries, and ICS calendar export. Rich trend
charts and polished external calendar subscription flows remain future work.

Deliverables:

- notifications
- recent tasks
- watch summaries
- calendar-like cadence view
- lightweight activity analytics
- export/share workflows

Acceptance:

- user can run Moondesk as the daily control surface for all personal Moon
  workspaces
