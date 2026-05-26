# Moondesk Roadmap

For the current implementation/readiness summary, see
[Moondesk Status](STATUS.md). In brief: Moondesk is usable as a local
single-user alpha. It is roughly 95% complete for native-window daily use,
95% complete for a self-contained local `.app` bundle, and 85% complete for a
production native-window desktop app. M0-M4 are functionally complete for local
use, M5-M7 have working first slices with review/event/analytics and agent-chat
coverage, and production distribution now mainly needs credentialed
notarization, update hosting policy, clean-machine validation, and long-running
hardening.

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

Status: complete for local desk use. The host API discovers books, lists
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

Status: complete for markdown inbox notes and import staging. The host can
create new inbox notes, edit existing `inbox/*` paths through
`POST /api/workspaces/:id/inbox`, and stage URL/data-url imports through
`POST /api/workspaces/:id/import`. The UI provides note title/content editing,
preview, selection loading, safe link-to-inbox staging, URL import, local file
picker import, drag/drop import, and pasted file/image import.

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

Status: desktop packaging slice complete for the native-window target.
`cmd/main serve` and `cmd/main desktop` run a pure MoonBit local host and serve
the built Rabbita shell; `desktop` opens the browser explicitly for development
and fallback use. Browser notification permission can be requested from the UI.
Scoped Finder reveal is available through `POST /api/workspaces/:id/reveal`,
and `cmd/main bundle` creates a self-contained macOS `.app` distribution with an
AppKit/WebKit launcher, internal native MoonBit host executable, bundled UI
resources, ad-hoc or identity-based signing, version/channel metadata,
native-window metadata, and an optional zip archive. `cmd/main release` writes
release/update manifests, creates a DMG, verifies signing, and can submit the
zip through `xcrun notarytool` when a keychain profile is provided. `cmd/main
launch-agent`, `install-agent`, `uninstall-agent`, and `agent-status` cover
LaunchAgent templates and install state for the desk host or Moontown daemon.

Deliverables:

- MoonBit host package
- scoped file APIs
- browser-compatible desktop shell launch command
- native AppKit/WebKit packaged shell
- host-backed import/open flows
- reveal in Finder
- optional desktop notifications through allowlisted host commands
- scoped filesystem roots
- local macOS app-shell bundle command
- self-contained native executable distribution
- ad-hoc or identity-based app signing
- explicit native-window metadata plus browser-shell fallback
- DMG/release/update manifest generation
- LaunchAgent install/remove/status flow

Acceptance:

- app runs through a MoonBit command or bundled native `.app`
- app can import local files through scoped host APIs
- no Rust, Cargo, Tauri, or `src-tauri` files exist
- no broad arbitrary filesystem access is required
- scoped reveal works only for paths under the selected workspace
- app bundle does not depend on `moon run` at launch
- release output contains enough metadata for install/update hosting

## M5: Search And Cross-Book Workflows

Status: first workflow slice complete. The host exposes
`GET /api/search?query=...` across discovered MoonBooks plus preference routes
for saved views and path tags. The UI can search, open hits, favorite paths,
save the current view, tag selected context, copy selected context into inbox
notes, inspect review queues, and view line-level review diffs.

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
live Moontown/MoonClaw progress summaries, event/failure/review projections,
review queue, and ICS calendar export. Rich trend charts and polished external
calendar subscription flows remain refinement work.

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

## M7: Interactive MoonClaw Agent Console

Status: local native-window slice complete. The UI has an Agents activity and
bottom-drawer summary. The host exposes a narrow `/api/agents/*` bridge that
reads `~/.moonclaw/daemon.json`, starts a runnable sibling/configured MoonClaw
daemon from a native executable when needed, lists models/tasks, creates or
reuses the selected book/workspace task, sends contextual messages, folds saved
MoonClaw assistant/tool/failure events plus bounded workspace-log progress rows
into the visible transcript, cancels active work, and stores Moondesk session
records under
`.moontown/moondesk-agent-sessions/`.

Deliverables:

- dedicated Agents rail activity
- book-scoped session list
- selected-path contextual prompt composer
- MoonClaw daemon status and best-effort startup
- model and web-search controls
- create session, send follow-up message, cancel work
- persisted local session transcript/status records
- saved MoonClaw conversation event projection for assistant/tool/failure turns
- bounded workspace `.moonclaw/log.jsonl` fallback for live/progress rows
- command palette entry for agent chat

Acceptance:

- user can select a book, open Agents, and start a MoonClaw coding/help session
  without leaving Moondesk
- each MoonBook can keep separate Moondesk-visible agent sessions
- messages carry the selected workspace root and selected path to MoonClaw
- failed daemon/model/task operations surface as visible session/status errors
