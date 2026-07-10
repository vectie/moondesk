# Desk Mode UX Plan

## Purpose

Desk should feel like a familiar file explorer for people organizing MoonBooks.
Its default screen should answer two questions quickly:

1. Where am I?
2. What can I do with the selected file or folder?

The previous layout gave storage paths, product registry state, service health,
source layers, virtual-path terminology, and many simultaneous controls the same
visual weight as files. That information is useful for diagnosis, but it makes
ordinary browsing feel like system administration.

## Design Direction

Desk uses a user-first hierarchy with progressive disclosure:

| Default surface | On-demand surface |
| --- | --- |
| MoonBook names and issue-only status | Suite and library storage paths |
| Folder name, breadcrumbs, search, and navigation | Editable path navigation |
| Name, type, modified time, and size | Source area and raw access flags |
| Common create/import entry points | Server-local path import |
| File preview and common selection actions | Product registry and service health |

Technical information is not deleted. It remains available through explicit
`Storage & services`, `Technical details`, `Go to folder`, and advanced import
disclosures. These disclosures are closed by default.

## Interaction Rules

- Use file-manager language: `Home`, `Folder`, `Type`, `Access`, and
  `Move to Trash`.
- Do not show absolute host paths, `books/` storage layout, source layers,
  renderer names, daemon names, or product-registry state in the primary scan
  path.
- Show status beside a MoonBook only when the user needs to act. A ready
  MoonBook needs no badge.
- Keep the file table focused on four broadly understood columns: Name, Type,
  Modified, and Size.
- Keep breadcrumbs visible. Place typed path navigation behind `Go to folder`
  because it is powerful but secondary.
- Group creation, import, and view preferences so the toolbar presents choices
  by intent instead of exposing every control at once.
- Preserve keyboard commands and stable test IDs when changing visual hierarchy.
- Empty states must name the situation and expose the next useful action without
  presenting diagnostics.

## Delivery Plan

### Phase 1: Information Hierarchy

- Replace the path-heavy library card with `My MoonBooks` and its count.
- Keep exact suite/library paths, service health, and installed products under
  `Storage & services`.
- Remove storage labels and ready-state metadata from MoonBook rows.
- Hide empty Favorites and Recent groups until they contain an item.

### Phase 2: Browsing Focus

- Keep Back, Forward, Up, Home, folder search, and Refresh immediately visible.
- Group New, Import, View, and typed location controls by intent.
- Remove Source Layer from the default file table while retaining it in
  technical details and internal sorting contracts.

### Phase 3: Selection Focus

- Lead the inspector with filename, type, modified time, size, access, and
  preview.
- Move raw path, source area, storage root, and access flags into closed
  technical disclosures.
- Consolidate low-frequency single-selection commands into a closed
  `More actions` disclosure while keeping Rename, Reveal, and Open in Wiki
  immediately available.
- Apply the same command-priority review to multi-selection after its keyboard
  and batch-operation coverage is expanded.

### Phase 4: Validation And Refinement

- Exercise full and empty MoonBook libraries through the real MoonBit host and
  built Rabbita UI.
- Validate desktop, compact desktop, tablet, and phone widths.
- Check closed/open disclosures, long filenames, long storage paths, missing
  metadata, empty folders, loading, errors, and selected/multi-selected states.
- Add visual regression baselines after the hierarchy settles.

## Acceptance Criteria

- The first viewport contains no absolute storage path, `books/` path, source
  layer, service/daemon name, product registry, or scoped-file-manager wording.
- Ready MoonBook rows show the MoonBook name without redundant type, path, or
  status labels. Recoverable problems still show `Needs setup`.
- The default file table has Name, Type, Modified, and Size columns.
- Advanced details are reachable with keyboard-focusable native disclosures and
  are closed by default.
- Opening `Storage & services` reveals the exact library and suite paths plus
  service state needed for support and diagnosis.
- Existing create, import, navigation, selection, preview, clipboard, trash,
  reveal, Wiki, and Code handoff workflows remain functional.
- Browser integration tests fail when internal terminology leaks back into the
  primary Desk surface.

## Non-Goals

- Changing workspace, filesystem, preview, or security contracts.
- Removing diagnostic information from the application.
- Redesigning Wiki or Code mode.
- Replacing established keyboard workflows with pointer-only controls.
