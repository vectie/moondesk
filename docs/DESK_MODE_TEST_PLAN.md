# Desk Mode Test Plan

Moondesk currently exposes three workspace modes:

- `Desk`: file explorer and directory browser.
- `Wiki`: book/wiki editing and knowledge workflows.
- `Code`: MoonCode sessions and runtime evidence.

This plan focuses on `Desk`. `Wiki` and `Code` appear only as boundary checks:
Desk must preserve selected workspace/path when the user switches modes, but
Desk tests must not become Wiki or Code workflow tests.

## Goal

Prove that Desk behaves like a scoped Finder/File Explorer over Moondesk's
virtual filesystem:

- discover workspaces
- list directories
- select files and directories
- preview supported content
- serve raw and generated assets through scoped routes
- reject path escapes
- preserve Desk context across reloads and mode switches
- keep navigation stable on empty, large, deep, and unusual workspaces

Desk must use a dedicated user-data workspace root by default. The default root
is `MOONDESK_WORKSPACE_ROOT` when configured, otherwise a per-user
`moondesk-workspace` directory. MoonBooks live under
`<workspace-root>/books/<book-id>`. The code checkout is never the
default place for user MoonBooks, inbox notes, daemon state, MoonCode sessions,
or MoonClaw artifacts.

The most important coverage is end-to-end: a seeded workspace, the MoonBit host
server, the built Rabbita UI, browser interaction, and filesystem assertions all
running together.

## Production Quality Bar

Desk is a user-facing file manager, not a developer fixture browser. Production
quality requires:

- Default storage is isolated from the source repository and explained as a
  MoonBook library.
- Desk visibly shows the user data root, the `books` library path,
  and the current MoonBook count so users can tell where their files are stored.
- Starting the host against a directory that looks like a source checkout
  redirects to the dedicated `MOONDESK_WORKSPACE_ROOT` or default
  `moondesk-workspace` directory before preparing `books`, and emits
  a warning that names the effective user-data root.
- The sidebar lists every MoonBook under `books`, with stable order,
  clear empty state, user-facing `book.json` `title`/`name` labels when
  present, a visible `Needs setup` status for folders that are missing
  `book.json`, and no implication that only one book is valid.
- Desk can create a plain MoonBook directly into
  `<workspace-root>/books/<book-id>` and open its starter
  `wiki/index.md` without writing into the source checkout.
- Desk can import an existing MoonBook folder by copying it into
  `<workspace-root>/books/<book-id>`, preserving the source folder,
  rejecting duplicates, and avoiding host build/VCS metadata such as `.git`,
  `node_modules`, `_build`, and `.DS_Store`.
- Desk can import an existing MoonBook folder from the browser folder picker by
  uploading the selected folder files into temporary storage first, validating
  `book.json`, and then copying only the MoonBook into the dedicated library.
- Desk can import a zipped MoonBook archive by extracting it into temporary
  storage first, validating that it contains a `book.json`, copying it into
  `<workspace-root>/books/<book-id>`, and skipping archive/build
  metadata such as `__MACOSX`, `.git`, `node_modules`, `_build`, and `.DS_Store`.
- Desk can import a zipped MoonBook archive from the browser archive picker so
  users do not need to paste a server-local filesystem path for common archive
  import.
- Navigation matches common Finder/File Explorer expectations: sidebar library,
  quick access/favorites, folder outline, breadcrumbs, editable
  location/address bar, sortable-looking details table, selection details,
  refresh, back/forward history, up/root navigation, reveal-in-file-manager
  actions, and clear current directory.
- Details-table columns sort by Name, Kind, Layer, Modified, and Size, with a
  visible direction indicator and folders kept before files.
- Desk offers comfortable and compact details-list density so users can switch
  between readable rows and large-folder scanning without changing location,
  selection, preview, sort, or filter state.
- Desk can filter the current directory listing by filename or visible path
  without leaving Desk, changing the current directory, or using the global
  cross-book search workflow.
- The file list is keyboard-focusable: Arrow keys, Home/End, Enter, Backspace,
  Escape, single-character type-ahead, Shift+Arrow range selection,
  Command/Ctrl+A, Command/Ctrl+C, Command/Ctrl+X, Command/Ctrl+V,
  Command/Ctrl+Shift+N new folder, F2 inline rename, F5 refresh, and Delete work without leaving Desk context. Empty folders still
  expose the focusable file-list surface so keyboard paste works into an empty
  target.
- Mouse selection follows file-manager expectations: single click selects
  without opening folders, double click opens, Shift-click extends a contiguous
  range, and Command/Ctrl-click toggles selected rows.
- Multi-selection details summarize the selected set with focused item,
  current directory, selected paths, folder/file counts, and total known size.
- Desk can copy selected scoped virtual paths, multiple selected paths, or the
  current folder path as text without copying absolute user-data root paths or
  modifying the internal Desk copy/cut clipboard.
- Desk can favorite selected paths and show favorites/recent paths in a
  sidebar Quick Access area; opening a quick path selects it and opens its
  containing directory in Desk.
- Desk can create folders and Markdown notes in the current scoped MoonBook
  directory, refresh the listing, select the created item, and reject traversal,
  duplicate names, and generated/system paths.
- Desk can import dropped, pasted, or picked local files into the current
  scoped MoonBook directory, preserving text bytes and decoded data-URL bytes,
  resolving filename conflicts with Finder-style ` copy` names, refreshing the
  current listing, selecting the first imported file, and rejecting traversal,
  hidden/reserved filenames, and generated/system paths.
- Desk can rename a single selected scoped file or folder in place, preserving a
  Markdown file extension when the user enters a bare basename, refreshing the
  parent listing, selecting the renamed item, and rejecting traversal,
  duplicate targets, MoonBook section roots, and generated/system paths.
- Desk can move one or more selected scoped files or folders into a target
  directory, including materializing writable virtual MoonBook sections when
  needed, refreshing the target listing, selecting the first moved item, and
  rejecting traversal, duplicate sources, duplicate targets, overlapping source
  paths, MoonBook section roots, generated/system paths, and moving folders
  into themselves.
- Desk can duplicate one or more selected scoped files or folders beside the
  source item using Finder-style ` copy` names, preserving file bytes and folder
  children, selecting the first duplicate, and rejecting traversal, overlapping
  source paths, MoonBook section roots, and generated/system paths.
- Desk can copy one or more selected scoped files or folders into the Desk
  clipboard and paste them into the current directory of the same MoonBook,
  preserving source items, using conflict-safe Finder-style names, refreshing
  the target listing, and selecting the first pasted item.
- Desk can cut one or more selected scoped files or folders into the Desk
  clipboard and paste-move them into the current directory of the same MoonBook,
  removing the original paths, refreshing the target listing, selecting the
  first moved item, and clearing the clipboard after a successful move.
- Desk can move one or more selected scoped files or folders to MoonBook trash
  under `.moontown/trash`, preserve receipts, hide trash internals from normal
  browsing, list restorable trash entries, and restore a selected trashed item
  back to its original path when the path is still free.
- Unsupported write operations are not implied. Desk remains explicit about the
  currently supported create/import/rename/move/trash/restore/edit surfaces.
- Desk can reveal the selected item, focused item in a multi-selection, or the
  current directory in the system file manager through the scoped reveal route;
  path escapes remain rejected by the API.
- Large color fields use neutral operating-system-style chrome. Brown,
  espresso, cream, and other warm brand colors are restricted to small accents
  or removed from Desk surfaces. Desk runtime entrypoints must not import
  `moonsuite-theme.css` or expose `--ms-*` warm theme tokens.
- Long paths, long filenames, empty libraries, empty folders, and narrow
  windows remain legible without overlapping text.
- Empty folders use normal file-manager language such as `This folder is empty`
  and still keep the file-list surface focusable for paste/keyboard commands;
  Desk must not show developer loading text for a successfully loaded empty
  directory.

Open production gaps to close after the current baseline:

- Add batch rename where it can remain clear and reversible, plus richer trash
  metadata views if users need filtering, preview, or permanent delete.
- Extend stable browser test hooks beyond the current workspace rows, file
  rows, details panel, creation controls, and preview pane as new Desk controls
  become browser-tested.
- Add pixel-diff baseline comparison once Desk visual design settles enough for
  intentional screenshot updates to be reviewed cleanly.

## Non-Goals

Desk tests should not validate:

- Markdown authoring semantics beyond read-only preview and explicit Desk
  context handoff.
- MoonCode command execution, patch review, test runs, or package approval.
- Moontown daemon scheduling, town messages, or standing-goal execution.
- Permanent destructive delete unless Desk gains that feature deliberately.

## Test Layers

### Contract Unit Tests

These are fast `moon test` checks over pure data contracts and helpers.

Primary files:

- `core/types_test.mbt`
- `ui/rabbita-desk/main/app_desk_navigation_wbtest.mbt`
- `ui/rabbita-desk/main/app_command_palette_wbtest.mbt`
- `ui/rabbita-desk/main/app_workspace_state.mbt` via white-box tests
- `internal/pathx/*_wbtest.mbt` when path helper tests are added
- `internal/moonwiki/*workspace*_wbtest.mbt` for route helper contracts

Coverage:

- File kind inference for directories, Markdown, HTML, JSON, text, images,
  PDFs, unknown extensions, `.mbt.md`, and generated site files.
- Source layer inference for `wiki`, `raw`, `inbox`, `skills`, `schemas`,
  `tools`, `apps`, `app`, `site/generated`, `book/site/generated`,
  `wiki/reviews`, `reviews`, `portable/app-tool`, `.moontown`, and MoonClaw
  artifact paths.
- Stable IDs and display names for mixed case, spaces, duplicate separators,
  punctuation, root paths, and trailing slashes.
- Breadcrumbs for root, one-level, deeply nested, generated-site, and path names
  containing URL-significant characters.
- Parent-path and current-directory helpers.
- Folder outline for root, nested directory, selected file parent, empty
  directory, and current child directories.
- Entry counts, size labels, readable/writable labels, and source-layer labels.
- Desk command palette remains navigation-only.

### Workspace Route Tests

These tests run handler-level or server-level checks without a browser. They
should use temporary fixture workspaces and assert JSON/file responses.

Primary routes:

```text
GET  /api/workspaces
GET  /api/workspaces/metadata
POST /api/workspaces
POST /api/workspaces/import
GET  /api/workspaces/<workspace-id>/entries?path=<relative-path>
POST /api/workspaces/<workspace-id>/entries
POST /api/workspaces/<workspace-id>/entries/import
POST /api/workspaces/<workspace-id>/rename
POST /api/workspaces/<workspace-id>/move
POST /api/workspaces/<workspace-id>/copy
GET  /api/workspaces/<workspace-id>/trash
POST /api/workspaces/<workspace-id>/trash
POST /api/workspaces/<workspace-id>/restore
GET  /api/workspaces/<workspace-id>/preview?path=<relative-path>
GET  /api/workspaces/<workspace-id>/raw?path=<relative-path>
GET  /api/workspaces/<workspace-id>/file/<relative-path>
GET  /api/workspaces/<workspace-id>/site/<relative-path>
POST /api/workspaces/<workspace-id>/reveal
```

Coverage:

- Workspace metadata returns the effective user-data root and the
  `<workspace-root>/books` library path, even when no MoonBooks
  exist yet, so Desk can explain where create/import actions will write.
- Workspace discovery returns stable IDs, normalized roots, names, kinds, and
  status, including `NeedsAttention` for recoverable MoonBook folders that are
  present under `books` but do not yet contain `book.json`.
- Creating a plain MoonBook writes `book.json`, starter `wiki/index.md`, and
  canonical folders under `books/<book-id>`, then returns a workspace
  ID that appears in the next discovery response.
- Importing an existing MoonBook copies a folder or `.zip` archive with
  `book.json` into `books/<book-id>`, leaves the source folder or
  archive in place, skips local build/VCS/archive metadata, rejects duplicate
  target IDs, and returns a workspace ID that appears in the next discovery
  response.
- Importing a picked folder sends browser-captured file bytes and
  `webkitRelativePath` values to `/api/workspaces/import`; the server stages
  those files in temporary storage, validates a single MoonBook root with
  `book.json`, rejects traversal/duplicate upload paths, and then copies the
  MoonBook into `books/<book-id>`.
- Importing a picked `.zip` archive sends browser-captured archive bytes to
  `/api/workspaces/import`; the server stages those bytes in temporary storage,
  validates and extracts the archive, copies only the MoonBook into
  `books/<book-id>`, and never writes the archive into the source
  checkout.
- Unknown workspace returns `404`.
- Root entries prefer virtual MoonBook sections before raw host-only folders.
- Entries are sorted with directories before files and stable lexical order
  within groups.
- Creating a folder or Markdown note through `POST /entries` writes inside the
  selected MoonBook, returns the created path, rejects duplicates, rejects
  traversal, and refuses generated/system paths.
- Importing files through `POST /entries/import` writes picked or dropped files
  into the selected MoonBook directory, preserves optional browser
  `relative_path` folder hierarchy, returns `imported_count`, the first imported
  path, and item details, decodes data URLs to bytes, resolves conflicts with
  ` copy` names, rejects invalid filenames, invalid path segments, traversal,
  and generated/system paths, and never writes outside the selected MoonBook.
- Renaming through `POST /rename` moves exactly one existing file or folder
  within its current parent, returns the renamed path, preserves Markdown
  extensions for bare basenames, rejects duplicates, rejects traversal, and
  refuses canonical MoonBook sections and generated/system paths.
- Moving through `POST /move` accepts either `path` or `paths`, moves every
  selected existing file or folder into an existing target directory or
  materialized virtual MoonBook section, returns `moved_count`, the first moved
  path, and item details, rejects duplicate sources, duplicate targets,
  traversal, conflicts, and overlapping batch sources, refuses canonical
  MoonBook sections and generated/system paths, and prevents moving a folder
  into itself.
- Copying through `POST /copy` accepts either `path` or `paths` and optional
  `directory`. Without `directory`, it duplicates every selected existing file
  or folder beside its source with a unique ` copy` or ` copy N` name. With
  `directory`, it pastes every selected source into that target directory using
  the original basename when free and Finder-style conflict names otherwise. It
  returns `copied_count`, the first copied path, and item details, preserves
  file bytes and folder children, rejects duplicate sources, traversal,
  conflicts, and overlapping batch sources, and refuses canonical MoonBook
  sections and generated/system paths.
- Trashing through `POST /trash` accepts either `path` or `paths`, moves every
  selected existing file or folder into scoped MoonBook trash, records receipts,
  returns `trashed_count` and the latest `trash_path`, hides `.moontown` from
  normal root listings, rejects duplicates/traversal, and refuses canonical
  MoonBook sections and generated/system paths.
- Listing through `GET /trash` returns restorable scoped receipts with
  `original_path`, `trash_path`, `receipt_path`, and `trashed_at`, excludes
  restored or missing trash files, and never exposes another MoonBook's trash.
- Restoring through `POST /restore` accepts a returned or listed `trash_path`,
  validates the receipt, restores the item to its original path, and rejects
  restore when the original path now exists.
- Hidden/system entries are excluded or included according to the virtual
  filesystem contract; `.git` and `.DS_Store` must not pollute normal browsing.
- Directory entries include expected `workspace_id`, `path`, `display_name`,
  `kind`, `source_layer`, `readable`, `writable`, `size_bytes`, and
  `modified_at` fields.
- A file path passed to `entries` returns the file entry or the documented
  error shape.
- Missing path returns `404`.
- Directory preview returns child paths in display order.
- Markdown/text preview returns content and text renderer metadata.
- HTML preview routes generated-site content through the site/file asset path.
- Image/PDF/binary preview returns a raw/file route instead of decoded garbage.
- Raw/file/site routes serve existing files and reject directories.
- Reveal accepts a scoped path, rejects an escape, and reports platform failure
  without crashing if the local reveal command is unavailable.

### Browser End-to-End Tests

These are the main Desk confidence tests. They should start the real server
against a seeded workspace, load the built UI in a browser, interact with the
Desk mode, and verify both DOM state and backend/file effects.

Recommended harness:

- Seed fixture under `/private/tmp/moondesk-desk-e2e/<run-id>`.
- Build UI with `npm --prefix ui/rabbita-desk run build`.
- Start server with:

```sh
moon run cmd/main -- serve /private/tmp/moondesk-desk-e2e/<run-id> --ui ui/rabbita-desk/dist --host 127.0.0.1 --port <free-port>
```

- Drive browser with the current Chrome DevTools Protocol smoke, Playwright, or
  the in-app browser controller.
- Use unique ports and temp directories for parallel-safe runs.
- Tear down the server process at the end of each run.

Current automated browser smoke:

```sh
scripts/desk_mode_browser_smoke.sh
scripts/desk_mode_empty_browser_smoke.sh
```

This harness uses a local Chrome DevTools Protocol session without adding a
network-installed browser dependency. It seeds multiple MoonBooks, opens the
built Desk UI in Chrome, verifies the MoonBook list and neutral large-surface
colors, creates a MoonBook from the Desk library panel and proves it lands under
`books` without a root-level book directory, imports an existing
MoonBook folder from the Desk library panel and proves the source was copied
into `books` without VCS metadata, navigates folders by double-clicking
rows, previews Markdown in the Desk details pane, exercises Back/Forward
directory history, creates a folder and notes, refreshes an out-of-band
filesystem change into the current directory, imports a dropped file into the
current directory, renames a note with F2 inline rename, duplicates the selected
note, switches the original note into the Desk clipboard, pastes it into another
folder, moves a note to scoped MoonBook trash, restores it from the Trash panel,
switches workspaces, and asserts the corresponding filesystem effects under
`books`. It also
checks desktop, small-desktop, tablet, and narrow mobile viewports for
horizontal document overflow, overlapping Desk panes, and large brown/chocolate
surface fills. Before opening the browser it also statically checks the Desk
runtime entrypoints and CSS files for accidental MoonSuite warm-theme imports or
`--ms-*` token use. It also verifies that the long user-data root path stays
contained and readable inside the MoonBook library card, then writes validated
PNG screenshots under the smoke fixture root for review.

The empty-library browser smoke starts a real server with an empty dedicated
`books` library, verifies the zero-MoonBook empty state and dedicated
library path, creates a MoonBook through the Desk sidebar, and proves the new
book appears under `books` without a root-level book directory.

Browser assertions should prefer stable text, roles, URLs, and data attributes
when available. If the UI lacks stable selectors, add lightweight semantic test
hooks only where they improve maintainability.

## Canonical Fixture

Create one broad fixture and several small edge fixtures.

```text
desk-fixture/
  book.json
  README.md
  wiki/
    index.md
    notes/
      alpha.md
      beta.markdown
    reviews/
      review-001.md
  raw/
    evidence.txt
    data.json
    nested/
      source.csv
  inbox/
    seed-note.md
  skills/
    pdf-watch/
      SKILL.md
  schemas/
    report.schema.md
  tools/
    demo/
      main.mbt
      moon.pkg
  apps/
    demo/
      index.html
      app.js
  app/
    index.html
  site/
    generated/
      index.html
      assets/
        site.css
  book/
    site/
      generated/
        index.html
  portable/
    app-tool/
      demo/
        index.html
  images/
    logo.png
  docs with spaces/
    encoded # name.md
  .git/
    config
  .DS_Store
```

Edge fixtures:

- Empty workspace with only `book.json`.
- Plain folder workspace with no MoonBook sections.
- Deep workspace with at least ten nested directories.
- Large directory with at least 300 entries.
- Filename stress workspace containing spaces, brackets, `#`, `%`, `?`, unicode
  characters, and long names.
- Security workspace with sibling `outside.txt` next to the root to test
  traversal rejection.

## End-to-End Journeys

### E2E 1: First Desk Load

Steps:

1. Start server against the canonical fixture.
2. Open `/`.
3. Select `Desk` if not already selected.
4. Wait for workspace list and root entries.

Assert:

- Mode toggle has exactly `Desk`, `Wiki`, and `Code`.
- `Desk` is active.
- Workspace name is visible.
- Root entries include virtual sections such as `wiki`, `raw`, `inbox`,
  `skills`, `schemas`, `tools`, `apps`, and generated-site paths as designed.
- Hidden `.git` and `.DS_Store` are not visible.
- Details panel shows selected workspace/root context without leaking unrelated
  host paths.

### E2E 1A: Create MoonBook From Desk

Steps:

1. Start server against an empty dedicated workspace root.
2. Enter a MoonBook name and optional book id in the Desk library panel.
3. Click `Create MoonBook`.
4. Wait for the library and file browser to refresh.

Assert:

- The new book is written under `books/<book-id>`, not the source
  checkout or workspace root.
- The Desk sidebar shows the corresponding user data root and
  `books` library path.
- `/api/workspaces` lists the new MoonBook after creation.
- Desk selects the new workspace and opens `wiki/index.md`.
- The create form clears after success so repeating the click does not
  immediately attempt the same duplicate book id; unavailable create/import
  actions are disabled until their required inputs are present.
- Path-based MoonBook import enables only when a source path is present, clears
  after success, preserves the source folder, skips VCS/build metadata, and
  writes only under `books/<book-id>`.
- Starter folders such as `wiki`, `raw`, `inbox`, and `book/site/generated`
  appear in the file browser.
- Duplicate book ids produce a clear error and do not overwrite the existing
  book.

### E2E 2: Directory Navigation

Steps:

1. Click `wiki`.
2. Click `notes`.
3. Click Back.
4. Click Forward.
5. Click breadcrumb `wiki`.
6. Click root breadcrumb.
7. Use toolbar `Up` from a child directory and toolbar `Root` from a non-root
   directory.

Assert:

- Current directory updates after each click.
- Back and Forward traverse previous directories without changing MoonBooks.
- Up and Root are disabled at root and enabled in child directories.
- Up opens the parent directory; Root opens the MoonBook root.
- Breadcrumb active segment matches the selected directory.
- File list contents match the selected directory.
- Folder outline keeps ancestor chain.
- Browser URL/activity state remains Desk.
- No Wiki or Code side effects are triggered.

### E2E 3: File Selection And Preview

Steps:

1. Open `wiki/index.md`.
2. Open `raw/evidence.txt`.
3. Open `raw/data.json`.

Assert:

- Selected path changes to the clicked file.
- Current directory remains the containing directory.
- Preview title/body matches file content.
- Renderer labels are correct.
- Details panel shows kind, layer, size, modified time when available, and
  access state.
- Details panel exposes a reveal action for the selected item without changing
  directory, selection, or preview state.
- Re-selecting a file does not reload the directory unnecessarily.

### E2E 4: Details Table Sorting

Steps:

1. Open a directory containing at least two files with different names, layers,
   modified timestamps, and sizes.
2. Click each sortable header: Name, Kind, Layer, Modified, and Size.
3. Click the same header again to reverse the active direction.
4. Repeat from a directory containing both folders and files.

Assert:

- Active header shows the selected column and direction.
- Repeat click reverses the direction without changing the selected path.
- Switching to another header resets to ascending order.
- Folders remain before files in both ascending and descending directions.
- Size sorting uses server-provided byte values, not formatted label text.
- Row order remains stable for equal values.

### E2E 4.1: Editable Location Bar

Steps:

1. Open a MoonBook root.
2. Type `raw` into the Desk location field and click `Go`.
3. Type `/wiki/` into the Desk location field and press Enter.
4. Repeat once with `root` or `/`.

Assert:

- Desk fetches and renders the typed directory listing.
- Clicking `Go` and pressing Enter both open the typed location.
- Leading and trailing slashes are normalized to scoped MoonBook paths.
- `root`, `(root)`, `/`, and an empty input open the MoonBook root.
- Back/forward history records typed navigation like toolbar navigation.
- The location field updates after typed navigation, sidebar navigation,
  breadcrumb navigation, keyboard parent navigation, create/import/move results,
  and workspace switches.

### E2E 4.2: Current Folder Filter

Steps:

1. Open a directory containing multiple rows such as `wiki`.
2. Type a partial name such as `notes` into the Desk filter field.
3. Use ArrowDown while the filter is active.
4. Click `Clear Filter`.
5. Navigate to a different directory while a filter is active.

Assert:

- Only matching file or folder rows remain visible.
- Matching checks both display name and visible scoped path, case-insensitively.
- Keyboard navigation and type-ahead operate on the filtered row set.
- The location, selected workspace, and current directory do not change merely
  because a filter is typed.
- If the current selection is hidden by the filter, Desk clears the selection,
  inline rename state, move target, and stale preview/details instead of
  showing metadata for an invisible row.
- When no row is selected, the details panel exposes a reveal action for the
  current directory rather than a stale hidden row.
- If a multi-selection is filtered, Desk keeps only selected rows that still
  match and moves focus to a visible retained row.
- Clearing the filter restores all rows in the current directory.
- Opening another directory clears the filter so the new location is not
  accidentally hidden by the previous query.

### E2E 4.3: Details List Density

Steps:

1. Open a MoonBook directory with several visible rows.
2. Confirm the default details list density is comfortable.
3. Click `Compact`.
4. Click `Comfort`.

Assert:

- Compact mode applies a compact table class and active segmented-control state.
- Compact rows are no taller than comfortable rows.
- Switching density does not change current directory, selected workspace,
  selected path, sort column, sort direction, filter query, or preview content.
- The control uses neutral chrome and does not introduce large brown/warm color
  blocks.

### E2E 4A: Keyboard File List Navigation

Steps:

1. Focus the Desk file list.
2. Press ArrowDown, ArrowUp, Home, and End.
3. Press a letter key that matches a visible file or folder.
4. Press Shift+ArrowDown from a selected row.
5. Press Enter on a selected folder, then Backspace from the child directory.
6. Press Command/Ctrl+A in a non-empty directory.
7. Press Command/Ctrl+C, Command/Ctrl+X, and Command/Ctrl+V with a selected row.
8. Press F2 on a single selected row, edit the inline name, and press Enter.
9. Press F2 again and press Escape.
10. Type a folder name and press Command/Ctrl+Shift+N.
11. Press F5 after an out-of-band file appears in the current directory.
12. Press Delete with a selected row.
13. Press Escape with a selection active.

Assert:

- Arrow keys move the focused selection without opening folders.
- Type-ahead selects the next matching visible row.
- Shift+Arrow selects a contiguous range and the summary shows the count.
- Command/Ctrl+A selects every visible row and the summary shows the selected
  count.
- Multi-selection details show folder/file counts and total known selected
  bytes without changing the focused item.
- Copy Path copies the visible scoped virtual path text and reports status
  without changing the Desk copy/cut clipboard.
- Favorite toggles the selected path in Quick Access, and clicking a favorite
  or recent path opens the containing directory with the item selected.
- Enter opens the selected folder and Backspace returns to the parent.
- Command/Ctrl+C copies the selection, Command/Ctrl+X cuts the selection,
  Command/Ctrl+V pastes into the current directory, and Delete moves the
  selection to MoonBook trash.
- Command/Ctrl+Shift+N creates a new folder in the current directory and selects
  it after the file list refreshes.
- F2 starts inline rename for one selected item, Enter commits the rename,
  Escape cancels editing, and F2 is blocked for multi-selection.
- F5 refreshes the current directory listing and selected preview without
  switching MoonBooks.
- Escape clears selection without losing the current directory.

### E2E 4B: Mouse File List Selection

Steps:

1. Single-click a visible folder row.
2. Double-click that folder row.
3. Single-click the first file in a directory.
4. Shift-click a later file.
5. Command-click or Ctrl-click a selected row.
6. Click `Clear Selection` in the details panel.

Assert:

- Single-click selects and previews the folder without changing directory.
- Double-click opens the selected folder.
- Shift-click selects a contiguous range and the details panel shows the count.
- Command/Ctrl-click toggles the row without clearing the rest of the range.
- Clear Selection removes selection, focused path, and preview state.

### E2E 4C: Create Folder And Note

Steps:

1. Open `wiki`.
2. Enter a folder name in the Desk toolbar.
3. Click `New Folder`.
4. Open the created folder.
5. Enter a note name.
6. Click `New Note`.

Assert:

- The new folder appears under the current MoonBook directory.
- The new note is written as Markdown under that folder.
- Desk refreshes the containing directory and selects the created item.
- Duplicate names show an error and do not overwrite the existing item.
- Names containing path traversal or separators are rejected.

### E2E 4C.1: Import Local Files And Folders Into Current Directory

Steps:

1. Open a writable MoonBook directory such as `wiki/browser-created`.
2. Drop or pick a local text file while Desk is the active mode.
3. Drop or pick a binary file that arrives as a browser data URL.
4. Click `Import Folder` or drop a folder-shaped browser payload with a nested
   `relative_path`.
5. Repeat the text-file import with the same filename.

Assert:

- The imported files are written under the current MoonBook directory, not
  `inbox/imports` and not the source repository.
- Text imports preserve text bytes.
- Data-URL imports are decoded to file bytes.
- Folder imports preserve nested child directories and show the top-level folder
  in the current Desk listing.
- The current listing refreshes and shows the imported rows.
- The first imported file is selected and previewed when supported.
- Repeated filenames use ` copy` names rather than overwriting.
- Generated/system target directories, invalid filenames, hidden/reserved path
  segments, and traversal are rejected before any files are written.

### E2E 4D: Rename, Move, Copy/Cut/Paste, Trash, And Restore

Steps:

1. Open `wiki`.
2. Select a Markdown file.
3. Press F2, enter a bare basename in the inline rename field, and press Enter.
4. Select another Markdown file, enter a bare basename in the details-panel
   rename field, and click `Rename`.
5. Select a normal child folder.
6. Enter a new folder name and click `Rename`.
7. Enter an existing target directory in the details-panel move field.
8. Click `Move`.
9. Move a folder into a virtual MoonBook section such as `raw`.
10. Select multiple files, enter an existing target directory, and click
    `Move`.
11. Click `Duplicate` for a selected file and for a selected folder.
12. Select multiple files and click `Duplicate`.
13. Select one or more files and click `Copy`.
14. Open another writable directory in the same MoonBook and click `Paste Here`.
15. Select one or more files and click `Cut`.
16. Open another writable directory in the same MoonBook and click `Paste Here`.
17. Click `Move to Trash` for a selected file.
18. Wait for the file to appear in the Trash panel.
19. Click that Trash row to restore the selected trashed item.
20. Select multiple files and click `Move to Trash`.

Assert:

- Markdown rename keeps the original Markdown extension when the user omits it.
- Folder rename moves the existing folder in place without changing parent
  directory.
- Move changes the parent directory without changing the basename.
- Desk refreshes the containing or target directory and selects the renamed or
  moved item.
- Batch move changes every selected item's parent directory, reports the moved
  count, removes moved paths from the source directory, and shows them in the
  target directory.
- Duplicate creates unique sibling copies, keeps the original selected sources
  in place, reports the copied count for multi-selection, and preserves nested
  folder contents.
- Paste writes copied files or folders into the current directory, keeps the
  original sources in place, resolves basename conflicts with ` copy` names, and
  reports the pasted count for multi-selection. Pasting after switching to a
  different MoonBook is rejected unless cross-MoonBook copy becomes an explicit
  feature.
- Paste after Cut moves files or folders into the current directory, removes
  the original source paths, reports the moved count for multi-selection, clears
  the Desk clipboard, and rejects after switching to a different MoonBook.
- Duplicate names show an error and do not overwrite the existing item.
- MoonBook section roots, generated/system paths, and names containing path
  traversal or separators are rejected.
- Moving a folder into itself is rejected.
- Trash moves the item under `.moontown/trash`, removes it from the visible file
  list, appears in the Trash panel, and keeps `.moontown` hidden from root
  browsing.
- Batch trash removes all selected files from the visible file list and reports
  the number of trashed items.
- Restore from a Trash panel row returns the item to the original path, removes
  it from the Trash panel, and selects it.
- Restore conflict shows an error and does not overwrite the existing item.

### E2E 5: Generated Site Preview

Steps:

1. Navigate to `site/generated/index.html`.
2. Open the generated-site preview.
3. Follow any in-preview asset load for `assets/site.css`.

Assert:

- Preview uses the generated-site route, not raw filesystem access.
- Iframe or preview surface loads without a blank page.
- CSS/JS assets resolve under the same workspace scope.
- Opening generated-site content does not replace the primary Desk directory
  context.

### E2E 6: Binary And Image Preview

Steps:

1. Open `images/logo.png`.
2. Request the raw/file URL used by the preview.

Assert:

- Preview renders an image element or binary-safe asset link.
- Raw/file response has non-empty bytes and an image content type when exposed.
- Preview body does not contain mojibake decoded binary text.
- Browser console has no fetch error for the image route.

### E2E 7: Search Hit Into Desk Context

Steps:

1. Search for `alpha`.
2. Click result for `wiki/notes/alpha.md`.

Assert:

- Mode switches or remains on `Desk`.
- Selected path is `wiki/notes/alpha.md`.
- Current directory is `wiki/notes`.
- Breadcrumbs show `root / wiki / notes`.
- Preview loads the file.

### E2E 8: Mode Switch Boundary

Steps:

1. In Desk, select `tools/demo/main.mbt`.
2. Switch to `Wiki`.
3. Switch back to `Desk`.
4. Switch to `Code`.
5. Switch back to `Desk`.

Assert:

- Selected workspace and selected path survive each switch.
- Desk restores the containing directory or selected directory.
- Wiki/Code-specific panels may update, but Desk does not start sessions or
  mutate files automatically.
- Returning to Desk does not lose preview context.

### E2E 9: Reload And Recent Context

Steps:

1. Select `raw/nested/source.csv`.
2. Reload the browser.
3. Reopen Desk.

Assert:

- App boots without stale loading state.
- Recent path list or selected path reflects the last Desk context if that is
  part of the current contract.
- If persistence is intentionally absent, app returns to root predictably and
  does not show a broken preview.

### E2E 10: Empty Workspace

Steps:

1. Serve empty fixture.
2. Open Desk root.

Assert:

- Workspace loads.
- Empty state is visible, non-error, and uses file-manager copy rather than
  `No virtual files loaded`.
- The empty file-list surface remains focusable so paste can target the current
  directory.
- Breadcrumb root is active.
- Details panel does not show stale entries from another workspace.
- No console errors.

### E2E 11: Large Directory

Steps:

1. Serve large fixture.
2. Open directory with at least 300 entries.
3. Select entries near top, middle, and bottom.

Assert:

- Directory loads within the agreed threshold.
- Scroll remains usable.
- Header, breadcrumbs, and details panel do not shift unexpectedly.
- Selection remains visible.
- Preview requests are scoped to the selected item only.

### E2E 12: Deep Directory

Steps:

1. Navigate through ten nested directories.
2. Use breadcrumbs to jump back to levels 7, 3, and root.

Assert:

- Breadcrumb overflow remains usable.
- Parent path calculation is correct at every level.
- Folder outline indentation is correct.
- No path segment is dropped or double-encoded.

### E2E 13: Filename Encoding

Steps:

1. Open `docs with spaces/encoded # name.md`.
2. Open paths containing `%`, `?`, brackets, and unicode names.

Assert:

- UI display name is human-readable.
- API requests encode paths correctly.
- Preview route decodes exactly once.
- Breadcrumb clicks preserve the original path.
- Raw/file/site routes do not confuse query strings with filename characters.

### E2E 14: Path Escape Rejection

Steps:

1. Directly request entries/preview/raw/file/site routes with `../outside.txt`.
2. Try encoded variants such as `%2e%2e/outside.txt`,
   `wiki/%2e%2e/%2e%2e/outside.txt`, and absolute paths.
3. Try reveal with the same escapes.

Assert:

- Every request returns `400` or `404` according to the route contract.
- No outside file content appears in the response.
- No outside file is created or modified.
- Server logs may show rejection, but the server keeps running.

### E2E 15: Workspace Switch

Steps:

1. Serve two fixtures.
2. Select workspace A and open `wiki/index.md`.
3. Switch to workspace B.
4. Switch back to workspace A.

Assert:

- Entries, selected path, preview, details, and breadcrumbs belong to the
  active workspace.
- No entry from workspace A appears while workspace B is active.
- If per-workspace context is preserved, it restores correctly; otherwise the
  reset behavior is consistent and documented.

### E2E 16: Server Restart

Steps:

1. Open Desk and select `wiki/index.md`.
2. Stop the server.
3. Observe UI error/loading state.
4. Restart the server on the same port.
5. Trigger refresh.

Assert:

- UI reports connection failure without corrupting selected context.
- Refresh recovers entries and preview.
- No duplicate workspace rows or stale loading overlays remain.

### E2E 17: Native/Desktop Smoke

Steps:

1. Build the UI.
2. Launch `desktop` or the Lepusa live smoke path against the canonical fixture.
3. Open the Desk window.
4. Navigate root, nested directory, Markdown file, generated site, and image.

Assert:

- Native shell starts the same host routes used by browser dev mode.
- Window renders nonblank content.
- Desk navigation and preview work without browser-dev-only assumptions.
- Quitting the window stops or releases the sidecar according to the lifecycle
  contract.

## API Smoke Script

Keep a non-browser script as the fastest end-to-end gate. It should start the
server and use `curl` against a fixture.

The current executable API gate is:

```sh
scripts/desk_mode_api_smoke.sh
```

The current executable browser gate is:

```sh
scripts/desk_mode_browser_smoke.sh
```

Required checks:

```text
/api/workspaces
/api/workspaces/import
/api/workspaces/<id>/entries?path=
/api/workspaces/<id>/entries (POST folder)
/api/workspaces/<id>/entries (POST markdown)
/api/workspaces/<id>/entries/import (POST files/folders)
/api/workspaces/<id>/rename (POST)
/api/workspaces/<id>/move (POST)
/api/workspaces/<id>/copy (POST)
/api/workspaces/<id>/trash (GET)
/api/workspaces/<id>/trash (POST)
/api/workspaces/<id>/restore (POST)
/api/workspaces/<id>/entries?path=wiki
/api/workspaces/<id>/preview?path=wiki/index.md
/api/workspaces/<id>/preview?path=site/generated/index.html
/api/workspaces/<id>/raw?path=raw/evidence.txt
/api/workspaces/<id>/file/images/logo.png
/api/workspaces/<id>/site/assets/site.css
/api/workspaces/<id>/entries?path=../outside.txt
/api/workspaces/<id>/preview?path=%2e%2e/outside.txt
```

Assert response status, JSON shape, selected field values, and absence of
outside-file content. Before the main fixture, the script also launches the
server against a fake source checkout and asserts that the effective health
workspace root is the dedicated user workspace, no `.moontown` directory is
created in the source checkout, the process log prints a warning naming the
dedicated root and `MOONDESK_WORKSPACE_ROOT`, and created MoonBooks land under
the dedicated workspace. It then repeats the launch with
`MOONDESK_WORKSPACE_ROOT` also pointed at the fake source checkout and asserts
the server falls back to a home-based `moondesk-workspace` outside the checkout
before creating any MoonBooks. The main fixture seeds multiple workspaces so one run covers the
canonical MoonBook, empty workspace, large directory, deep directory,
encoded-name paths, workspace isolation, hidden-file filtering, generated-site
assets, binary preview routing, and traversal rejection. It should be suitable
for CI and local debugging.

## Browser Visual Checks

Run these at desktop and narrow widths:

- `1440x900`
- `1280x720`
- `1024x768`
- `390x844`

The current browser smoke captures validated PNG artifacts for every viewport in
this matrix.

Assert:

- No overlapping text in mode toggle, breadcrumbs, file rows, and details panel.
- Long user-data root paths remain inside the MoonBook library card and wrap
  safely at narrow widths.
- Long file names truncate or wrap according to the design.
- Preview surface stays visible when details are populated.
- Empty, loading, error, and populated states have stable dimensions.
- Generated-site iframe/image previews are nonblank.

## Performance And Reliability Targets

Initial targets:

- Root workspace list visible within 2 seconds for the canonical fixture.
- Directory with 300 entries visible within 2 seconds on a development machine.
- Selecting ten files in sequence should not leak duplicate preview requests.
- Server should survive 100 sequential entries/preview/raw route requests.
- Browser console should have no uncaught errors during the canonical E2E suite.

These are guardrails, not benchmarks. If a target is flaky, record machine and
fixture details before treating it as a product regression.

## Regression Gates

For a normal Desk-facing change:

```sh
moon check
moon test
moon info
moon fmt
npm --prefix ui/rabbita-desk run build
```

For route or filesystem changes, also run:

```sh
moon test internal/moonwiki
moon test internal/fsx
```

For UI navigation changes, also run:

```sh
moon test ui/rabbita-desk/main
```

For release candidates or changes touching path routing, preview, workspace
discovery, or native shell behavior, run the full API smoke and browser E2E
suite against all fixtures.

The current browser smoke covers one canonical UI path while the broader
journey suite is still being expanded.

## Implementation Order

1. Add reusable fixture creation for canonical, empty, large, deep, encoding,
   and security workspaces.
2. Add the API smoke script and make it the default Desk integration gate.
3. Expand browser E2E beyond the current smoke into journeys 1 through 7 for
   the canonical fixture.
4. Add security and encoding E2Es before shipping any route rewrite.
5. Broaden visual checks to include the intermediate widths in the visual
   matrix.
6. Add native/Desktop smoke after browser E2E is stable.
7. Keep unit tests close to changed helpers and route contracts as regressions
   are found.

## Done Definition

Desk mode is thoroughly covered when:

- Unit tests cover all path, kind, source-layer, and navigation helpers.
- API smoke proves workspace discovery, entries, preview, raw/file/site assets,
  and traversal rejection through the real server.
- Browser E2E proves the main file-explorer journeys through the real UI.
- Fixture coverage includes empty, plain, large, deep, encoded-name, generated
  site, binary asset, and security workspaces.
- Native/Desktop smoke proves the same Desk flows outside browser dev mode.
- Regression commands and E2E commands are documented and runnable by a new
  contributor without special local state.
