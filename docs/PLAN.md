# Moondesk Product Plan

The canonical model is in
[Executable Book Architecture](EXECUTABLE_BOOK_ARCHITECTURE.md). Moondesk is a
native human workspace for one selected executable MoonBook at a time.

```text
MoonBook = durable executable book
MoonWiki = edit what the book says
MoonCode = edit what the book can do
Moontown = coordinate books and scheduled work
MoonClaw = execute bounded runs and code sessions
Bookkeeper = accept or reject proposed truth
```

## Thesis

Moondesk should feel like a local research/coding studio: book files on the
left, active work in the center, run/context state on the right, and durable
outputs at the bottom. It is a shell and projection layer, not another runtime.

## Core User Flow

1. Select or create a MoonBook.
2. Work in MoonWiki for prose, evidence, methods, reviews, and generated pages.
3. Switch to MoonCode for interactive coding/chat on the same book.
4. Route scheduled or cross-book work through Moontown.
5. Let MoonClaw execute bounded work and emit evidence.
6. Review proposals through Bookkeeper before they become durable book truth.
7. Publish generated pages, reports, tools, miniapps, or portable app-tools.

## Non-Goals

- Do not hardcode domain-specific research workflows into Moondesk.
- Do not make Moondesk own the MoonClaw runtime or model loop.
- Do not hide MoonBook, Moontown, MoonClaw, and Bookkeeper ownership.
- Do not keep obsolete routes after the current contract replaces them.
- Do not expose platform concepts as the primary navigation when Book, Wiki,
  Code, Run, Review, and Publish are clearer.

## Product Surfaces

### Explorer

- discover configured roots and `.moontown/books/*`
- show `wiki/`, `raw/`, `skills/`, `schemas/`, `tools/`, `apps/`,
  `site/generated/`, `book/site/generated/`, and review/output paths
- keep file operations scoped to the selected workspace

### Preview

- preview markdown, HTML, JSON, images, text, directories, and generated sites
- serve raw files and generated assets through scoped local routes
- keep markdown/source views recoverable after opening sites or tool apps

### Inbox

- create notes
- import dropped, pasted, selected, URL, or data-url files
- stage user-provided inputs into book-local paths before promotion

### MoonWiki

- edit human-language book material
- manage methods, sources, findings, reviews, and generated pages
- create reusable book patterns such as PDF Evidence Watch without embedding a
  domain-specific pack

### MoonCode

- start and resume book-scoped coding sessions
- send typed prompt, steer, cancel, test, build, eval, package, accept, and
  reject commands
- show transcript, runtime stream, tool calls, diffs, test results, packages,
  readiness, and review controls
- package accepted outputs as MoonBook-owned tools, miniapps, generated sites,
  or portable app-tools

### Town

- show standing goals, request ledger, town messages, progress, review queue,
  and notifications
- submit recurring or one-shot book work to Moontown
- keep book-to-book communication and idea routing visible

### Daemon And Native Shell

- run as a native window app
- supervise the local Moondesk host and configured MoonClaw/Moontown daemons
- expose LaunchAgent/install/status controls where appropriate
- keep browser development in `serve`/`desktop`; app packaging is Lepusa-only

## Data Contracts

Keep Moondesk-facing records small and stable:

```text
DeskWorkspace
  id, name, root_path, kind, status

DeskFileEntry
  workspace_id, path, display_name, kind, source_layer, readable, writable

DeskPreview
  renderer, title, body, metadata, warnings

DeskRunProjection
  run_id, book_id, goal_id, status, phase, summary, artifacts

MoonCodeSessionProjection
  id, workspace_id, title, status, events, summary, readiness, artifact paths
```

Detailed protocol contracts belong in [MoonCode Workspace](MOONCODE.md) and
package-generated `.mbti` files.

## Permission Model

- reads stay under configured roots
- writes stay under selected book/workspace roots
- imports land in inbox/staging first
- execution is delegated to MoonClaw or Moontown
- accepted durable truth requires Bookkeeper review
- destructive actions require explicit operator intent

## Engineering Bar

Moondesk is good when it is boring to operate:

- boundaries are visible and hard to confuse
- stale domain packs live outside the desktop core
- generated app-tools can leave Moondesk as standalone artifacts
- native app startup, preview, routing, and daemon controls are reliable
- MoonCode can be extracted without dragging MoonWiki or desktop code with it
- tests cover protocol contracts, routing, packaging, preview, and runtime
  handoff behavior

Use [STATUS.md](STATUS.md) for current implementation state and
[ROADMAP.md](ROADMAP.md) for milestone tracking.
