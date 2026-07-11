# MoonDesk Desk Mode Design

## Decision

MoonDesk should have a first-class `Desk` mode. This mode is the real desktop
surface: a Finder/File Explorer style view over MoonBook projects and their
virtual filesystem.

The initial `Desk` mode is read-only. It does not edit files, run agents,
advance workflows, mutate books, or execute background tasks. It only lets the
operator navigate MoonBook projects and inspect file/directory metadata.

```text
MoonDesk
  Desk mode  = browse MoonBooks and virtual files
  Wiki mode  = read/write durable book knowledge
  Code mode  = run MoonCode sessions for selected book/path
```

## Why

The current product has two strong activity lanes: Wiki and Code. That makes
MoonDesk feel like a switch between two specialized tools, but not yet like the
operator's desk.

The missing neutral layer is a filesystem-style browser:

- select a MoonBook project
- browse folders and files
- see file type, size, modified time, source layer, and path
- choose a file or directory as context
- then open Wiki or Code activity for that same selected context

This makes MoonDesk the shell, not merely a Wiki/Code toggle.

## Product Boundary

`Desk` mode owns navigation and inspection only.

It may show:

- MoonBook/project list
- directory tree
- file list
- breadcrumbs
- selected path
- file kind/type
- source layer
- size when available
- last modified time when available
- preview availability
- virtual path versus host path when useful

It must not:

- edit file contents
- create, rename, move, or delete files
- dispatch MoonClaw work
- submit MoonTown requests
- start MoonCode sessions automatically
- imply that the virtual filesystem is the host filesystem

Those actions belong to other activities:

- `MoonWiki`: book/wiki editing, inbox, source review, accepted knowledge
- `MoonCode`: coding sessions, diffs, tests, packages, runtime evidence
- `Town`: scheduling, standing goals, requests, daemon state
- `Runs`: execution artifacts and progress

## Virtual Filesystem Model

Desk mode is a view over MoonDesk's virtual filesystem, not a raw host file
explorer.

The virtual filesystem can project multiple layers into one navigable tree:

- book wiki files
- inbox files
- raw evidence
- generated site files
- generated app-tool files
- MoonClaw run artifacts
- review artifacts
- durable MoonCode receipts
- MoonTown sidecar state when exposed as project context

The UI should make this feel like ordinary folder navigation while preserving
the underlying source layer in metadata.

## UI Shape

The title-bar mode switch should become:

```text
Desk | Wiki | Code
```

Recommended first screen for `Desk`:

```text
┌──────────────────────────────────────────────────────────────┐
│ Desk | Wiki | Code       MoonDesk / Selected MoonBook         │
├───────────────┬──────────────────────────────┬───────────────┤
│ MoonBooks     │ Name       Kind   Modified   │ Details       │
│ Favorites     │ wiki/      dir    ...        │ selected path │
│ Recent        │ raw/       dir    ...        │ kind          │
│               │ book.json  json   ...        │ source layer  │
│               │ app/       dir    ...        │ virtual path  │
└───────────────┴──────────────────────────────┴───────────────┘
```

The first implementation can reuse the existing workspace list and
`DeskFileEntry` entries. A deeper tree can come later; the first version only
needs to make directory navigation and metadata inspection obvious.

## Navigation Semantics

Selecting a workspace in Desk mode:

- sets `selected_workspace_id`
- loads the root directory
- clears edit-specific state
- keeps the user in `Desk`

Selecting a directory:

- updates `current_directory`
- loads child entries
- updates `selected_path`
- remains in `Desk`

Selecting a file:

- updates `selected_path`
- loads preview metadata if available
- remains in `Desk`
- enables explicit handoff buttons such as `Open in Wiki` or `Ask Code`

Switching from Desk to Wiki or Code should preserve the selected workspace and
path. This is the main reason Desk mode exists: it gives the other modes a
clear context.

## Implementation Notes

Use the existing MoonDesk API first:

- `GET /api/workspaces`
- `GET /api/workspaces/:id/entries?path=...`
- `GET /api/workspaces/:id/preview?path=...`

If the current entry records do not expose enough metadata, extend the
host-side DTOs deliberately rather than reaching around the virtual filesystem
from the UI.

The initial Desk mode should be implemented in `ui/rabbita-desk/main` as a
third `WorkspaceMode`, not as a separate application and not as a backend lane.

## Success Criteria

Desk mode is successful when a user can:

- see all MoonBook projects
- navigate folders like Finder/File Explorer
- understand what kind of item each row is
- see basic file metadata
- select a path as context
- intentionally move from that context into Wiki or Code

At that point MoonDesk has a clear hierarchy:

```text
MoonDesk is the desk.
MoonWiki and MoonCode are activities on the selected desk context.
MoonClaw, MoonTown, and Lepusa are supporting execution/coordination/runtime layers.
```
