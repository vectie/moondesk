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
moon run cmd/main -- desktop --root ~/Workspace
```

Implemented as a browser-compatible launch alias over the same pure MoonBit
host. It does not package a native `.app` yet.

### Packaged Mode

```text
moon run cmd/main -- bundle --target local
```

Planned. Packaging can be added later without introducing Rust into this
repository.

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
GET  /api/search?query=...
GET  /api/town/state
GET  /api/town/messages
GET  /api/town/requests
POST /api/town/requests
GET  /api/moonclaw/runs?workspace=...
GET  /api/moonclaw/runs/:id/artifacts
```

Implemented behavior:

- `GET /api/workspaces` discovers MoonBooks under `.moontown/books`, or returns
  the configured root as a loose folder.
- `entries`, `preview`, and `raw` scope all paths under the selected workspace
  root and reject traversal.
- `preview` returns a `DeskPreview`; image previews point to the `raw` route.
- `POST /api/workspaces/:id/inbox` writes a markdown note into `inbox/`; when a
  `path` field is provided it edits only scoped `inbox/*` paths.
- `GET /api/search?query=...` searches readable text-like files across
  discovered workspaces with bounded results.
- `GET /api/town/state` returns the town state JSON when present.
- `GET /api/town/messages` lists recent `.moontown/book-results/*.json`
  records.
- `GET /api/town/requests` lists staged request records under
  `.moontown/moondesk-requests/`.
- `POST /api/town/requests` stages a request under
  `.moontown/moondesk-requests/`. It does not yet dispatch work to the daemon.
- MoonClaw run routes list run workspaces and visible `report.md`,
  `result.json`, and `outputs/*.md|*.json` artifacts.

## Persistence

Moondesk should keep only desktop preferences and cache:

- known roots
- opened tabs
- layout state
- recent files
- preview cache
- UI preferences

Canonical content remains in MoonBook, Moontown, or MoonClaw.
