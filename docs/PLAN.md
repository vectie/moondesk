# Moondesk Product Plan

## Thesis

Moondesk is a human-facing desktop workspace for the Moon ecosystem.

Moontown is built for AI agents. Moondesk is built for real human users. It
should feel like a combination of Finder, Codex, and a local research studio:
files on the left, active work in the center, agent/progress context on the
right, and durable output/artifact history at the bottom.

## Core Problem

The Moon system can already create useful artifacts across multiple projects:

- Moontown schedules goals and keeps the 24/7 loop alive.
- MoonBook stores durable wiki, raw evidence, generated sites, journals, and
  standing-watch history.
- MoonClaw executes jobs and emits run workspaces, artifacts, logs, and memory
  candidates.

The missing product layer is a convenient human workspace:

- browse all books without terminal commands
- inspect files, pages, artifacts, and generated websites
- drag files into a book inbox
- edit or annotate documents before promotion
- submit requests to Moontown from selected files/context
- watch agent progress without reading raw JSON or logs

## Product Positioning

Moondesk should not replace MoonBook, Moontown, or MoonClaw.

It should sit beside Moontown as a desktop surface:

```text
human user
  -> Moondesk
      -> MoonBook workspaces for files/wiki/site/memory
      -> Moontown for standing goals and dispatch
      -> MoonClaw for runs, artifacts, and execution traces
```

## First Use Case

A user wants a 24/7 research workspace for "one person company".

Moondesk should let the user:

1. Open the `research-opc` MoonBook.
2. See `wiki/`, `raw/`, `site/generated/`, and `history/`.
3. Read the latest standing-watch messages.
4. Drop PDFs, links, or notes into an inbox.
5. Submit "analyze these files and update the OPC book" to Moontown.
6. Watch the assigned worker activity and MoonClaw artifacts.
7. Open the generated report/site/course output.

## Non-Goals

- Do not make Moondesk another autonomous agent brain.
- Do not let Moondesk own durable wiki semantics.
- Do not let Moondesk execute arbitrary tools directly.
- Do not hard-code domain-specific research procedures into Moondesk.
- Do not hide MoonBook/Moontown/MoonClaw boundaries behind ambiguous generic
  calls.

## Product Modules

### Workspace Explorer

Shows all known MoonBooks and their important folders:

- `wiki/`
- `raw/`
- `site/`
- `book/`
- `wiki/history/`
- `reviews/`
- `.moonclaw/jobs/runs/`
- `moonclaw-jobs/`

### Preview Center

Tabbed preview/edit area:

- markdown preview and source
- HTML preview
- JSON inspector
- image preview
- artifact viewer
- generated site preview
- diff/review panel

### Human Inbox

Book-local staging area for user-provided files:

- drag and drop
- create note
- paste URL
- attach screenshot/image
- mark privacy scope
- submit to MoonBook/Moontown

### Operator Console

Human request composer:

- choose target book
- select files/pages as context
- write request
- choose cadence or one-shot
- submit to Moontown
- watch accepted request id and progress

### Agent Activity

Read-only projection of Moontown and MoonClaw state:

- Mayor messages
- standing goals
- book keeper decisions
- worker runs
- run artifacts
- recent failures/retries

### Output Library

Convenient access to generated outputs:

- final reports
- generated marketing sites
- course pages
- journal timelines
- approved wiki pages
- exported bundles

## Data Contracts

### DeskWorkspace

```text
id
name
root_path
kind: moonbook | loose-folder | town-root
status
last_seen_at
```

### DeskFileEntry

```text
id
workspace_id
path
display_name
kind: markdown | html | json | image | directory | artifact | unknown
source_layer: wiki | raw | generated-site | run-artifact | inbox | config
readable
writable
size_bytes
modified_at
```

### DeskPreview

```text
entry_id
renderer: markdown | html | json | image | text | artifact-summary
title
body
metadata
warnings
```

### DeskTaskSubmission

```text
id
target_book_id
title
prompt
context_entries
cadence
quality_threshold
source_policy
created_at
```

### DeskRunProjection

```text
run_id
book_id
goal_id
status
phase
summary
artifacts
started_at
updated_at
```

## Permission Model

Moondesk should treat local files as user-owned and agent execution as
permissioned.

- Read operations are allowed only under configured roots.
- Writes go to a book-local inbox/staging area first.
- Durable wiki promotion belongs to MoonBook.
- Execution belongs to Moontown/MoonClaw.
- Filesystem operations go through explicit MoonBit host APIs with scoped roots.
- Destructive operations require explicit confirmation.

## Visual Direction

Match Codex's outlook more than a game UI:

- left activity rail
- left explorer tree
- tabbed central workspace
- right agent/context inspector
- bottom logs/artifacts drawer
- command palette
- calm dark/light neutral palette
- dense but readable typography
- strong keyboard navigation

Moondesk can link out to the Wenyu Valley town viewport, but it should not embed
the game map as the main desktop surface.
