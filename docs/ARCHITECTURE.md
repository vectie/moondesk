# Moondesk Architecture

## Boundary

Moondesk is a desktop shell over existing Moon workspaces. It should not absorb
the responsibilities of the other projects.

```text
Moondesk
  human desktop, file browsing, preview, editing, inbox, submissions

MoonBook
  durable book/wiki/site/history/review workspace

Moontown
  Mayor, daemon, standing goals, scheduling, dispatch, town state

MoonClaw
  job runtime, workers, tools, artifacts, logs, ACP execution
```

## Package Plan

### `core`

MoonBit domain model for the desk:

- workspace registry
- file entries
- pane/tab/window model
- preview descriptors
- inbox records
- task submission records
- adapter capability model

### `adapters/moonbook`

Reads and writes through MoonBook-owned workspace semantics:

- discover book roots
- load book metadata and health summaries
- list `wiki/`, `raw/`, `site/`, `book/`, and `reviews/`
- stage user files into book inbox
- open generated site/report/course paths
- request MoonBook build/projection commands later

### `adapters/moontown`

Talks to Moontown surfaces:

- read `.moontown/town.json`
- read `.moontown/daemon.json`
- read `.moontown/standing-goals.json`
- submit operator requests
- read watcher messages
- link desk selections to town requests

### `adapters/moonclaw`

Run/artifact projection plus a narrow interactive agent bridge:

- list run workspaces
- inspect `events.jsonl`, `meta.json`, `result.json`, `report.md`
- expose artifact preview entries
- map worker/run status back to the UI
- inspect `~/.moonclaw/daemon.json`
- proxy to MoonClaw daemon `GET /v1/models`, `GET /v1/tasks`,
  `POST /v1/task`, `POST /v1/task/:id/message`, and
  `POST /v1/task/:id/cancel`
- persist Moondesk-owned session metadata without owning MoonClaw
  conversation/runtime state

### `ui/rabbita-desk`

Rabbita desktop application:

- activity rail
- explorer tree
- tabbed preview center
- inspector panel
- bottom artifact/log drawer
- command palette
- request composer
- file drop surface
- Agents activity for book-scoped MoonClaw chat sessions

### `cmd/main`

Local development command:

- serve the Rabbita UI
- expose JSON APIs for configured roots
- run doctor checks
- run read-only indexing later

### `host`

Pure MoonBit local host APIs:

- configured workspace roots
- scoped file reads/writes
- inbox imports
- preview endpoints
- operator request endpoints
- optional OS helper commands behind explicit allowlists

## Tauri Reference Strategy

Use `../tauri` only as a design reference:

- split frontend UI from local host capabilities
- keep host APIs explicit and narrow
- avoid broad filesystem access
- keep desktop concerns outside domain logic

Do not import Tauri, write Rust, create Cargo files, or add `src-tauri`.
Moondesk should be executable as a MoonBit-hosted Rabbita application first.

## Runtime Modes

### Browser Dev Mode

```text
moon run cmd/main -- serve [root] [--ui ui/rabbita-desk/dist] \
  [--host 127.0.0.1] [--port 4188]
```

Uses a local HTTP server and built Rabbita bundle. This is the implemented
development mode.

Example:

```text
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- serve ../moontown --ui ui/rabbita-desk/dist --port 4199
```

### MoonBit Desktop Host Mode

```text
moon run cmd/main -- desktop [root] [--ui ui/rabbita-desk/dist] \
  [--host 127.0.0.1] [--port 4188]
```

Implemented as a browser-compatible launch alias over the same pure MoonBit
host. Unlike `serve`, `desktop` opens the browser after the server binds. This
mode remains useful for development and fallback debugging, while packaged
daily use is owned by the native-window bundle.

### Packaged Mode

```text
moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist]
```

Implemented as a MoonBit-generated macOS `.app` distribution. The bundle command
builds the native MoonBit executable, copies it to
`Contents/MacOS/moondesk-host`, compiles a small AppKit/WebKit launcher as
`Contents/MacOS/moondesk`, copies the built Rabbita UI into
`Contents/Resources/ui`, writes `Contents/Resources/moondesk-config.json`,
records version/channel/native-window metadata, signs the app with `codesign`
using ad-hoc identity `-` by default, and creates `Moondesk.app.zip` unless
`--no-archive` is supplied. The packaged executable opens a foreground macOS
window and loads the bundled UI through the internal host. `bundle --shell
browser` preserves the older browser-shell bundle shape when needed. The native
launcher is compiled with the system `/usr/bin/clang` against AppKit and WebKit;
there is no Rust, Tauri, or vendored desktop runtime. `cmd/main release` wraps
the bundle output with `release-manifest.json`, `updates.json`, signing
verification, DMG creation, and optional
`xcrun notarytool submit --keychain-profile ... --wait` plus stapling, without
introducing Rust into this repository.

### Launch Agents

```text
moon run cmd/main -- launch-agent [root] [--service desk|town] \
  [--out dist/app.vectie.moondesk.plist]
moon run cmd/main -- install-agent [root] [--service desk|town]
moon run cmd/main -- uninstall-agent [--service desk|town]
moon run cmd/main -- agent-status [--service desk|town]
```

`launch-agent` writes a macOS LaunchAgent template. `install-agent`,
`uninstall-agent`, and `agent-status` manage the corresponding plist through
`launchctl` for either the desk host or the Moontown daemon. The UI also exposes
Moontown daemon agent status plus install/remove controls through
`GET|POST /api/town/daemon/agent`.

## Adapter Rules

- Adapters should expose explicit methods, not generic "run anything" methods.
- Moondesk should call `MoonBookAdapter.list_entries`, not parse arbitrary
  workspace internals everywhere.
- Moondesk should call `MoontownAdapter.submit_request`, not write daemon files
  directly except through an approved local dev API.
- Moondesk should call `MoonClawAdapter.list_runs` for artifacts and proxy
  interactive chat through the MoonClaw daemon; it should not own MoonClaw job
  execution internals.

## Initial API Surface

```text
GET  /api/workspaces
GET  /api/workspaces/:id/entries?path=...
GET  /api/workspaces/:id/preview?path=...
GET  /api/workspaces/:id/raw?path=...
POST /api/workspaces/:id/inbox
POST /api/workspaces/:id/import
GET  /api/workspaces/:id/review-diff?path=...
GET  /api/search?query=...
GET  /api/town/state
GET  /api/town/daemon
GET  /api/town/daemon/status
GET  /api/town/daemon/supervision
POST /api/town/daemon/supervision
POST /api/town/daemon/start
POST /api/town/daemon/stop
POST /api/town/daemon/restart
GET  /api/town/daemon/agent
POST /api/town/daemon/agent
GET  /api/town/analytics
GET  /api/town/events
GET  /api/town/progress
GET  /api/town/calendar.ics
GET  /api/town/messages
GET  /api/town/requests
POST /api/town/requests
GET  /api/town/standing-goals
POST /api/town/standing-goals
POST /api/town/dispatch
GET  /api/moonclaw/events?workspace=...
GET  /api/moonclaw/runs?workspace=...
GET  /api/moonclaw/progress?workspace=...
GET  /api/moonclaw/runs/:id/artifacts
GET  /api/agents/daemon
GET  /api/agents/models
GET  /api/agents/tasks
GET  /api/agents/sessions?workspace=...
POST /api/agents/sessions
POST /api/agents/sessions/:id/message
POST /api/agents/sessions/:id/cancel
GET  /api/review/items?workspace=...
POST /api/workspaces/:id/reveal
GET  /api/preferences/views
POST /api/preferences/views
GET  /api/preferences/tags
POST /api/preferences/tags
```

Implemented behavior:

- `GET /api/workspaces` discovers MoonBooks under `.moontown/books`, or returns
  the configured root as a loose folder.
- `entries`, `preview`, and `raw` scope all paths under the selected workspace
  root and reject traversal.
- `preview` returns a `DeskPreview`; image previews point to the `raw` route.
- `POST /api/workspaces/:id/inbox` writes a markdown note into `inbox/`; when a
  `path` field is provided it edits only scoped `inbox/*` paths.
- `POST /api/workspaces/:id/import` stages URL/file/data-url metadata into
  `inbox/imports/` and keeps all writes scoped under the selected workspace.
- `GET /api/workspaces/:id/review-diff?path=...` compares a selected review file
  to the nearest wiki/base/orig/previous file and returns a bounded line-level
  summary.
- `GET /api/search?query=...` searches readable text-like files across
  discovered workspaces with bounded results.
- `GET /api/town/state` returns the town state JSON when present.
- `GET /api/town/daemon` returns `.moontown/daemon.json` when present.
- `GET /api/town/daemon/status` reports the Moondesk-managed background daemon
  PID, running state, command, supervision policy, restart count, and log paths.
- `GET|POST /api/town/daemon/supervision` reads or updates the desired-state
  supervision policy. When enabled with desired state `running`, status checks
  reconcile a stopped managed daemon by starting it again.
- `POST /api/town/daemon/start` starts `moon run cmd/main -- daemon run` as a
  managed background process under the configured Moontown root.
- `POST /api/town/daemon/stop` sends the managed process `SIGTERM` and persists
  the lifecycle state.
- `POST /api/town/daemon/restart` stops then starts the managed daemon loop.
- `GET|POST /api/town/daemon/agent` reports, installs, or removes the Moontown
  daemon LaunchAgent.
- `GET /api/town/analytics` returns a flat operating summary: daemon tick,
  standing-goal counts, due/active goals, watcher decision counts, request
  count, town message count, visible MoonClaw run count, event counts, failure
  counts, review counts, latest failure, and review queue size.
- `GET /api/town/events` returns recent Moontown watcher/request/dispatch
  events with normalized severities.
- `GET /api/town/progress` returns the current daemon tick/status, supervision
  state, queued request/dispatch/message counts, and latest visible run.
- `GET /api/town/calendar.ics` exports enabled standing goals as VTODO records.
- `GET /api/town/messages` lists recent `.moontown/book-results/*.json`
  records.
- `GET /api/town/requests` lists staged request records under
  `.moontown/moondesk-requests/`.
- `POST /api/town/requests` stages a request under
  `.moontown/moondesk-requests/`.
- `GET /api/town/standing-goals` reads `.moontown/standing-goals.json`.
- `POST /api/town/standing-goals` validates/upserts a standing-watch record in
  `.moontown/standing-goals.json`.
- `POST /api/town/dispatch` runs one Moontown daemon tick when the configured
  root is a runnable Moontown checkout, then records stdout/stderr/status under
  `.moontown/moondesk-dispatches/`.
- MoonClaw run routes list run workspaces and visible `report.md`,
  `result.json`, and `outputs/*.md|*.json` artifacts.
- `GET /api/moonclaw/events` projects visible MoonClaw event/result files into
  normalized live events.
- `GET /api/moonclaw/progress` returns aggregate run/ready/artifact counts and
  latest run status for a selected workspace or all workspaces.
- `GET /api/agents/daemon` reports the local MoonClaw daemon pid/port/root from
  `~/.moonclaw/daemon.json`.
- `GET /api/agents/models` lists daemon models when MoonClaw is running.
- `GET /api/agents/tasks` lists active MoonClaw daemon tasks when available.
- `GET /api/agents/sessions?workspace=...` lists persisted Moondesk agent
  sessions, enriched with live MoonClaw task status when the daemon is running
  and saved MoonClaw conversation events when a task transcript exists, with a
  bounded workspace `.moonclaw/log.jsonl` progress fallback for in-flight or
  incomplete task output.
- `POST /api/agents/sessions` validates the target workspace, starts MoonClaw
  from a native `cmd/main` executable when a runnable checkout is found,
  creating that executable when necessary, creates or reuses the workspace-root
  task, sends an initial selected-context message, and persists a session
  record.
- `POST /api/agents/sessions/:id/message` sends a follow-up contextual user
  message to the attached MoonClaw task and appends local transcript/status
  records.
- `POST /api/agents/sessions/:id/cancel` forwards cancellation to MoonClaw and
  records the result in the local session transcript.
- `GET /api/review/items` lists review/failure items from review folders and
  Moontown event signals.
- `POST /api/workspaces/:id/reveal` reveals a scoped workspace path in Finder
  on macOS or opens the containing folder on Linux.
- `GET|POST /api/preferences/views` persists saved view records under
  `.moontown/moondesk-preferences/views.json`.
- `GET|POST /api/preferences/tags` persists selected path tags under
  `.moontown/moondesk-preferences/tags.json`.

## Persistence

Moondesk should keep only desktop preferences and cache:

- known roots
- opened tabs
- layout state
- recent files
- preview cache
- UI preferences
- agent session metadata and desk-visible transcripts under
  `.moontown/moondesk-agent-sessions/`

Canonical content remains in MoonBook, Moontown, or MoonClaw.
