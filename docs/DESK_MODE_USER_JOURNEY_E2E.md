# Desk Mode User-Journey End-to-End Test Charter

## Purpose

This charter validates Desk as a user-facing file explorer. It asks six
questions for every journey:

1. What should the user see?
2. Why should the user see it?
3. What can the user do from that state?
4. What will a likely user do next?
5. What outcome should follow?
6. Can the user complete the job without internal product knowledge?

Passing an API request is necessary but insufficient. A journey passes only
when the visible interface, interaction, persisted filesystem result, and
recovery behavior agree.

## User And Product Assumptions

Primary user: a person who understands files, folders, and common desktop file
managers but does not know MoonDesk's storage layout, virtual source layers,
daemon names, product registry, or route contracts.

Primary job: find, inspect, add, organize, and recover MoonBook material without
leaving Desk or risking another MoonBook.

The first screen must answer:

- Which MoonBook am I using?
- Which folder am I viewing?
- What files are here?
- What can I safely do next?

## Methodology

### 1. Journey-Based Given/When/Then Tests

Each journey starts from a named fixture and a clean browser profile. Record:

- **Given:** library, MoonBook, directory, selection, viewport, and service state.
- **When:** user-visible actions only, except explicit setup or fault injection.
- **Then:** visible state, filesystem/API state, retained context, and errors.
- **Evidence:** DOM assertion, screenshot, HTTP result, filesystem assertion,
  browser console, server log, and elapsed time as applicable.

### 2. Four Proof Layers

1. **Contract:** MoonBit tests prove state transitions, path scoping, labels,
   keyboard mappings, and error handling.
2. **API:** the real server proves discovery, mutation, preview, security, and
   source-root isolation against temporary fixtures.
3. **Browser:** the built UI and real server prove complete pointer and keyboard
   workflows plus persisted filesystem effects.
4. **Observed UX:** screenshots and semantic inspection prove hierarchy,
   understandable language, progressive disclosure, focus, wrapping, and
   responsive composition.

No layer substitutes for another. In particular, source inspection cannot pass
a visual claim, and a screenshot cannot pass a persistence claim.

### 3. Achievability Rating

Rate each journey after execution:

- **Achieved:** the user can discover and complete it, sees confirmation, and
  the persisted result is correct.
- **Achieved with friction:** completion is possible, but discovery, language,
  focus, feedback, or recovery creates avoidable uncertainty.
- **Blocked:** the user cannot complete it or the result is unsafe/incorrect.
- **Not exercised:** required environment or automation is unavailable; state
  the missing evidence explicitly.

Any blocked P0/P1 journey fails the Desk release gate. “Achieved with friction”
requires a recorded issue and severity even when automation passes.

### 4. Observation Heuristics

For each state, inspect:

- **Hierarchy:** MoonBook, location, files, and primary action appear before
  diagnostics and advanced controls.
- **Language:** labels use file-manager terms and avoid implementation details.
- **Affordance:** controls look interactive, disabled actions explain state, and
  native disclosures remain keyboard reachable.
- **Feedback:** loading, success, empty, and error states appear near the action
  and provide a next step.
- **Recovery:** invalid input, service loss, conflicts, and cancellation preserve
  context and allow retry.
- **Accessibility:** visual order matches keyboard order; focus is visible; the
  file list works without a pointer; errors are not communicated by color alone.
- **Responsive quality:** no overlap, clipping, hidden final content, document
  overflow, or unusably small controls at target widths.
- **Trust:** no action writes outside the active MoonBook or exposes unrelated
  host paths in the ordinary workflow.

### 5. Fixtures And Viewports

Use disposable roots under `/private/tmp` and unique ports. Required fixtures:

- empty library
- four-MoonBook populated library, including one recoverable setup state
- nested folders, long names, spaces, URL-significant characters, binary files,
  generated site files, and hidden/system artifacts
- 300-entry folder and ten-level deep folder
- duplicate-name, traversal, missing-path, and cross-MoonBook attempts
- fake source checkout with a separate dedicated user-data root

Required viewports: `1440x900`, `1280x720`, `1024x768`, and `390x844`.

## Journey Matrix

### J01: First Orientation In A Populated Library - P0

- **User sees:** `My MoonBooks`, a count, readable MoonBook names, the selected
  MoonBook, breadcrumbs, search, a four-column file list, and a quiet inspector.
- **Why:** these establish object, location, contents, and next action without
  requiring system knowledge.
- **User can do:** switch MoonBooks, navigate, search, select, create, import,
  refresh, or open secondary controls.
- **Likely action:** select the relevant MoonBook and scan/open a folder.
- **Expected outcome:** selected workspace and directory are unambiguous; ready
  rows do not show redundant status or storage paths.
- **Pass evidence:** first-viewport DOM assertions and desktop screenshot contain
  no absolute root, `books/`, source layer, daemon/service, product registry, or
  “scoped file manager” language.

### J02: Empty Library To First MoonBook - P0

- **User sees:** zero MoonBooks, an understandable empty state, and `Add
  MoonBook`; diagnostics remain closed.
- **Why:** a first-time user needs one clear setup path, not service internals.
- **User can do:** create a named MoonBook or import an existing one.
- **Likely action:** create a MoonBook, optionally choosing a folder name.
- **Expected outcome:** the new MoonBook appears, is selected, opens its starter
  content, and is stored under the dedicated library rather than the source root.
- **Pass evidence:** browser DOM, API listing, filesystem assertions, and empty
  and post-create screenshots.

### J03: Navigate And Find A File - P0

- **User sees:** Back, Forward, Up, Home, breadcrumbs, folder outline, filename
  search, Name/Type/Modified/Size, and visible selection.
- **Why:** these match common file-manager orientation and retrieval patterns.
- **User can do:** single-click select, double-click open, use breadcrumbs,
  history, typed `Go to folder`, search, sort, density, mouse, or keyboard.
- **Likely action:** open folders, filter a long list, then select a file.
- **Expected outcome:** directory, breadcrumb, outline, row set, and history stay
  synchronized; no action silently changes MoonBooks.
- **Pass evidence:** browser actions and DOM assertions plus state-transition
  tests for keyboard and history behavior.

### J04: Inspect A File And Continue Work - P0

- **User sees:** filename, type, modified time, size, access, preview, Rename,
  Reveal, and Open in Wiki; raw path and source area are closed by default.
- **Why:** content and common actions matter more than implementation metadata.
- **User can do:** preview supported content, reveal it, rename it, open it in
  Wiki, or expand technical details and more actions.
- **Likely action:** confirm the file in preview and open it in Wiki or rename it.
- **Expected outcome:** preview matches the selected file, actions preserve
  location, and mode handoff retains MoonBook/path context.
- **Pass evidence:** rendered preview, disclosure state, navigation state, and
  focused MoonBit transition tests.

### J05: Create And Import Content - P0

- **User sees:** grouped `New` and `Import` choices; server-local path import is
  advanced rather than primary.
- **Why:** users think in files/folders, not host route or storage mechanics.
- **User can do:** create a folder/note, pick files/folders/archives, or use an
  advanced path when appropriate.
- **Likely action:** create a folder or import material into the open folder.
- **Expected outcome:** new content appears in the current scoped directory,
  becomes selected, preserves bytes, and resolves conflicts predictably.
- **Pass evidence:** browser-originated import, DOM refresh, API result, and exact
  filesystem bytes; cancellation and invalid input preserve context.

### J06: Rename, Duplicate, Move, Copy, And Paste - P0

- **User sees:** immediate Rename plus lower-frequency organization commands
  under `More actions`; status appears near the operation.
- **Why:** common work remains accessible without making the inspector a command
  wall.
- **User can do:** F2 rename, duplicate, move, copy, cut, and paste one or many
  scoped items.
- **Likely action:** rename an item, duplicate a template, or move/copy it into a
  destination folder.
- **Expected outcome:** list and selection refresh coherently; extensions and
  bytes are preserved; conflicts use safe names or actionable errors.
- **Pass evidence:** browser workflow, filesystem source/destination checks, and
  API rejection tests for invalid/overlapping targets.

### J07: Multi-Select And Batch Work - P1

- **User sees:** a stable multi-selection summary with count and total known
  size; focused and selected rows remain distinguishable.
- **Why:** batch work needs confidence about scope before mutation.
- **User can do:** Shift range selection, Command/Ctrl toggle/select-all, then
  copy, move, duplicate, trash, or copy paths.
- **Likely action:** select related files and apply one operation.
- **Expected outcome:** every intended item and no unintended item changes; the
  summary and final selection match the result.
- **Pass evidence:** pointer and keyboard state tests plus multi-path API and
  filesystem assertions.

### J08: Quick Access And Workspace Isolation - P1

- **User sees:** Favorites/Recent only when populated and clear active MoonBook
  state when switching libraries.
- **Why:** shortcuts should reduce retrieval time without adding empty clutter or
  leaking another MoonBook's context.
- **User can do:** favorite a path, reopen it, switch MoonBooks, and return.
- **Likely action:** pin a frequently used file/folder and revisit it later.
- **Expected outcome:** Quick Access opens the right containing folder; switching
  MoonBooks never displays or mutates another MoonBook's entries.
- **Pass evidence:** state tests, browser switch assertions, and cross-workspace
  API isolation checks.

### J09: Trash And Restore - P0

- **User sees:** `Move to Trash`, operation feedback, and a restorable Trash
  list under secondary actions rather than permanent-delete language.
- **Why:** destructive work must be reversible and clearly scoped.
- **User can do:** trash selected items and restore the correct receipt.
- **Likely action:** remove an obsolete file, then recover it after reconsidering.
- **Expected outcome:** item leaves the normal listing, remains in MoonBook-scoped
  trash, restores to its original path, and conflicts do not overwrite data.
- **Pass evidence:** browser list changes, trash/restore API, receipt, and exact
  filesystem assertions.

### J10: Error, Conflict, And Security Recovery - P0

- **User sees:** plain-language, local feedback with a retry or corrective next
  step; current MoonBook, directory, and selection remain stable.
- **Why:** a file manager must protect trust when paths, names, services, or
  permissions fail.
- **User can do:** correct invalid input, choose another name/destination, refresh,
  or retry after service recovery.
- **Likely action:** fix the named problem and repeat the operation.
- **Expected outcome:** traversal, generated/system paths, duplicate targets,
  cross-book access, and source-root writes are rejected without partial change.
- **Pass evidence:** negative contract/API cases, filesystem non-effects, visible
  feedback inspection, and server/browser error capture.

### J11: Responsive And Keyboard-Only Use - P1

- **User sees:** the same information priority at all target widths, visible
  focus, readable labels, and no overlap or document-level horizontal overflow.
- **Why:** narrow windows and keyboard navigation are normal desktop workflows,
  not edge cases.
- **User can do:** complete navigation, selection, create, rename, clipboard,
  trash, disclosures, and recovery without a pointer.
- **Likely action:** use Arrow keys, Enter, Backspace, shortcuts, Tab, and narrow
  split-window layouts.
- **Expected outcome:** focus order follows visual order; no keyboard trap; native
  disclosures and every critical command are reachable.
- **Pass evidence:** keyboard automation, focus inspection, target-viewport
  screenshots, overflow/overlap assertions, and semantic HTML checks.

### J12: Scale, Restart, And Native Shell - P1

- **User sees:** a responsive 300-entry folder, understandable connection failure,
  successful refresh recovery, and the same Desk experience in the desktop shell.
- **Why:** reliability and environment parity determine whether users can trust
  Desk for repeated work.
- **User can do:** filter/navigate a large folder, recover after host restart, and
  use Desk outside browser development mode.
- **Likely action:** continue browsing after transient failure or in the packaged
  application.
- **Expected outcome:** canonical lists appear within 2 seconds on the development
  machine, no duplicate/stale UI remains after recovery, and native content is
  nonblank and functional.
- **Pass evidence:** elapsed-time capture, fault injection, browser console/server
  logs, and native launch smoke. Record unavailable native evidence separately.

## Execution Order

1. Record Git revision, OS, browser, MoonBit/Node versions, and fixture roots.
2. Run syntax/build and focused contract tests.
3. Run the API smoke, including source-root isolation and security negatives.
4. Run populated and empty browser journeys through the real built UI.
5. Inspect every captured viewport screenshot; automation alone does not pass
   visual hierarchy or legibility.
6. Run explicit keyboard/focus and error-recovery checks not covered by the
   canonical browser path.
7. Run performance/reliability and native checks where the environment supports
   them.
8. Produce a journey result table with rating, evidence, defect, and residual
   risk. Fix Desk-owned P0/P1 blockers, then rerun the affected layer and the
   canonical browser gate.

## Release Gate

Desk passes this charter when all P0 journeys are Achieved, no P1 journey is
Blocked, API/security non-effects are proven, every target viewport is visually
inspected, browser console errors are absent, and any unexercised native or
assistive-technology evidence is explicitly documented rather than inferred.
