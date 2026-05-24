# Moondesk UI Design

## Visual Goal

Moondesk should feel like a focused desktop workbench:

- Codex-like professional shell
- Finder-like file navigation
- research-studio previews
- agent activity visible but not dominant

It should not look like the Wenyu Valley game viewport. The town viewport is a
linked visualization, while Moondesk is the practical human workspace.

## Shell Layout

```text
┌────────────────────────────────────────────────────────────────────┐
│ title bar / command palette / active workspace / sync status        │
├────┬──────────────────────┬──────────────────────────────┬─────────┤
│rail│ explorer             │ editor / preview tabs         │inspector│
│    │ books/files/inbox    │ markdown/html/json/images     │agents   │
│    │                      │ generated outputs             │metadata │
├────┴──────────────────────┴──────────────────────────────┴─────────┤
│ bottom drawer: logs, artifacts, requests, search results            │
└────────────────────────────────────────────────────────────────────┘
```

## Main Surfaces

### Activity Rail

- Explorer
- Search
- Inbox
- Town
- Runs
- Settings

### Explorer

Book-first navigation:

- All Books
- Favorites
- Recent
- Inbox
- Generated Outputs
- Run Artifacts

Each book expands into:

- Wiki
- Raw Evidence
- Reviews
- Generated Site
- Journal
- Course
- MoonClaw Runs

### Preview Tabs

The central area should support:

- Markdown source/preview split
- HTML preview
- JSON tree inspector
- image preview
- report reader
- generated site iframe
- artifact summary
- diff/review view

### Right Inspector

Context for the selected file or workspace:

- file metadata
- citations/source info
- owning book
- current standing goal
- related runs
- keeper decisions
- available actions

### Bottom Drawer

Operational visibility:

- request ledger
- town messages
- MoonClaw run events
- build output
- validation warnings
- latest daemon and standing-watch summary

## Command Palette

Required commands:

- Open Book
- Create Book Inbox Note
- Import Files
- Submit to Town
- Run Daemon Tick
- View Cadence Calendar
- Review Outcome Analytics
- Build Book Site
- Open Generated Site
- Show Run Artifacts
- Reveal in Finder
- Search All Books
- Toggle Inspector

## Request Composer

The composer should support:

- selected files/pages as context
- free-form prompt
- target book
- one-shot or standing-watch cadence
- quality threshold
- source policy
- submit to Moontown
- create or update standing-watch records in `.moontown/standing-goals.json`
- run a single daemon tick through the scoped host action

## Desktop Interactions

Phase 1 browser mode:

- drag files into inbox using browser APIs where available
- click previews
- local API writes staged inbox files

Phase 2 MoonBit host mode:

- host-backed open/import flows
- scoped reveal in Finder
- open with external app
- drag/drop from Finder
- clipboard images
- desktop notifications
- local `.app` shell bundle launched through `cmd/main bundle`

## Codex Outlook Matching

Use these visual principles:

- dense split-pane shell
- subdued neutral background
- blue/teal accent for active states
- small caps/status pills for state
- high-contrast active tab
- monospace for paths/logs
- clear empty states
- keyboard-first navigation

Avoid:

- game-style map as primary UI
- random gradients
- generic dashboard cards only
- hiding files behind marketing copy
