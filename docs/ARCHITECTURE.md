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

Read-only run/artifact projection at first:

- list run workspaces
- inspect `events.jsonl`, `meta.json`, `result.json`, `report.md`
- expose artifact preview entries
- map worker/run status back to the UI

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
host. Unlike `serve`, `desktop` opens the browser after the server binds.

### Packaged Mode

```text
moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist]
```

Implemented as a MoonBit-generated macOS `.app` distribution. The bundle command
builds the native MoonBit executable, copies it to `Contents/MacOS/moondesk`,
copies the built Rabbita UI into `Contents/Resources/ui`, writes
`Contents/Resources/moondesk-config.json`, signs the app with `codesign` using
ad-hoc identity `-` by default, and creates `Moondesk.app.zip` unless
`--no-archive` is supplied. The packaged executable also opens the browser after
binding. `cmd/main release` wraps the bundle output with a release manifest and
optional `xcrun notarytool submit --keychain-profile ... --wait` plus stapling,
without introducing Rust into this repository.

### Launch Agent Template

```text
moon run cmd/main -- launch-agent [root] [--out dist/app.vectie.moondesk.plist]
```

Writes a macOS LaunchAgent template for login startup. The command does not
install or load the agent automatically; a user-facing install/uninstall flow
can be added once the daemon policy is finalized.

## Adapter Rules

- Adapters should expose explicit methods, not generic "run anything" methods.
- Moondesk should call `MoonBookAdapter.list_entries`, not parse arbitrary
  workspace internals everywhere.
- Moondesk should call `MoontownAdapter.submit_request`, not write daemon files
  directly except through an approved local dev API.
- Moondesk should call `MoonClawAdapter.list_runs`, not own job execution.

## Initial API Surface

```text
GET  /api/workspaces
GET  /api/workspaces/:id/entries?path=...
GET  /api/workspaces/:id/preview?path=...
GET  /api/workspaces/:id/raw?path=...
POST /api/workspaces/:id/inbox
POST /api/workspaces/:id/import
GET  /api/search?query=...
GET  /api/town/state
GET  /api/town/daemon
GET  /api/town/daemon/status
GET  /api/town/daemon/supervision
POST /api/town/daemon/supervision
POST /api/town/daemon/start
POST /api/town/daemon/stop
POST /api/town/daemon/restart
GET  /api/town/analytics
GET  /api/town/progress
GET  /api/town/calendar.ics
GET  /api/town/messages
GET  /api/town/requests
POST /api/town/requests
GET  /api/town/standing-goals
POST /api/town/standing-goals
POST /api/town/dispatch
GET  /api/moonclaw/runs?workspace=...
GET  /api/moonclaw/progress?workspace=...
GET  /api/moonclaw/runs/:id/artifacts
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
- `GET /api/town/analytics` returns a flat operating summary: daemon tick,
  standing-goal counts, due/active goals, watcher decision counts, request
  count, town message count, and visible MoonClaw run count.
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
- `GET /api/moonclaw/progress` returns aggregate run/ready/artifact counts and
  latest run status for a selected workspace or all workspaces.
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

Canonical content remains in MoonBook, Moontown, or MoonClaw.
