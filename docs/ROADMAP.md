# Moondesk Roadmap

## M0: Plan And Skeleton

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
