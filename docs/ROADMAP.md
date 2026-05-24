# Moondesk Roadmap

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

Status: complete for markdown inbox notes. The host can create new inbox notes
and edit existing `inbox/*` paths through `POST /api/workspaces/:id/inbox`.
The UI provides note title/content editing, preview, selection loading, and
safe link-to-inbox staging.

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

Status: partially complete. The UI can submit selected context to the host, the
host stages request records under `.moontown/moondesk-requests/`, and the UI can
read the request ledger and town messages. Direct daemon dispatch and standing
goal creation remain future work.

Deliverables:

- request composer
- selected-context submission
- standing-goal creation
- request ledger
- town message stream

Acceptance:

- user can select files/pages, submit a request, and see Moontown accept it
- standing-watch requests can be created from the desktop

## M4: Pure MoonBit Desktop Host

Status: partially complete. `cmd/main serve` and `cmd/main desktop` run a pure
MoonBit local host and serve the built Rabbita shell. Browser notification
permission can be requested from the UI. Packaged native launch, Finder reveal,
and OS helper allowlists remain future work.

Deliverables:

- MoonBit host package
- scoped file APIs
- browser-compatible desktop shell launch command
- host-backed import/open flows
- reveal in Finder
- optional desktop notifications through allowlisted host commands
- scoped filesystem roots

Acceptance:

- app runs through a MoonBit command
- app can import local files through scoped host APIs
- no Rust, Cargo, Tauri, or `src-tauri` files exist
- no broad arbitrary filesystem access is required

## M5: Search And Cross-Book Workflows

Status: started. The host exposes `GET /api/search?query=...` across discovered
MoonBooks. The UI can search, open hits, favorite paths, and copy selected
context into inbox notes.

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

Status: started. The UI has a daily operating surface with request/run/message
counts, browser notification trigger, recent/favorite context, and a text export
snapshot. Calendar cadence views and richer analytics remain future work.

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
