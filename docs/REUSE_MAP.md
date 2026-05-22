# Reuse Map

## From Moontown

Use:

- Rabbita/Vite development pattern from `ui/rabbita-town`
- operator request API shape
- town snapshot reading
- daemon/standing-goal projection concepts
- Wenyu viewport link-out pattern

Do not copy:

- town simulation/game viewport as the main Moondesk UI
- Mayor reasoning logic
- scheduler ownership

## From MoonBook

Use:

- workspace layout semantics
- wiki/raw/site/book/review/history conventions
- generated site/report/course locations
- skill inventory concepts
- build/projection commands
- standing-watch history concepts

Do not copy:

- durable wiki promotion logic into Moondesk
- research-specific procedures into the desktop UI

## From MoonClaw

Use:

- file/workspace helper patterns
- run workspace conventions
- event/log/artifact projection concepts
- ACP/job artifact viewing patterns

Do not copy:

- worker execution loop
- generic tool runtime
- memory ownership

## From `../tauri` As Reference Only

Use as design reference:

- thin shell versus product-core separation
- explicit frontend-to-host message boundary
- narrow permission model
- security-conscious local file access

Do not copy or add:

- Rust source files
- Cargo files
- `src-tauri`
- Tauri runtime dependencies
- broad filesystem permissions

## From Rabbita

Use:

- MoonBit-authored UI model/update/view style
- Vite build workflow
- compact static bundle output

Need to adapt:

- desktop pane layout
- file tree interactions
- tabbed editor model
- drag/drop events
- command palette
- larger persistent app state
