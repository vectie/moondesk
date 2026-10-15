# MoonDesk: quieter coding controls

Follow-up: [second UI round — 72 icons, tabs, drawers and quieter editing](UI_UX_SECOND_ROUND_2026-10-13.md).

## Diagnosis

The previous UI accumulated every feature as another heading, explanation, button or tab row. The coding toolbar and developer panel repeated the same destinations. The composer showed captions alongside self-describing selected values. Terminal actions wrapped into several equally prominent rows. Sidebar branding, book name and counts repeated nearby information. These are hierarchy and disclosure problems as well as text density problems.

The user asked for generated icons and a Codex reference. Native Codex capture was attempted but the computer-use tool denied access to that application. No Codex screenshot was captured, and this document does not claim a direct visual comparison. Decisions were checked against the actual MoonDesk browser preview.

## Design rules

1. Content, selected files and conversation titles carry the page. Controls occupy a quieter layer.
2. Familiar repeated actions use icons. The active desktop pane retains a short label.
3. Keep text for task intent, ambiguous actions, destructive menu items, errors, questions, model names and document names.
4. Each standalone icon has an accessible name and tooltip. Toggles expose their actual pressed or expanded state. Tooltip text is supplementary; it does not supply the only accessible name.
5. Use one 24px geometry and 1.65px outline family, rendered at 18px. Filled stop is the explicit action exception. Icons inherit the current foreground color.
6. Status uses distinct shapes and real runtime state. Color alone never carries meaning. Unknown states retain their text.
7. Use 36px desktop action targets and 44px on small/touch screens. Selection and keyboard focus must remain visible.
8. Put occasional actions in a nearby menu, avoiding a page-wide collection of unlabeled symbols.

## Implemented in this pass

| Surface | Change |
| --- | --- |
| Workbench | Files, changes, preview, terminal and compare glyphs; active desktop label; selection action; one visible layout action |
| Pane hierarchy | Hide the duplicate developer heading and terminal/browser/compare tabs when embedded in the workbench |
| Context bar | Coding setup and schedules become icon controls; remove empty path placeholder |
| Composer | Attachment and send/queue glyphs; compact model/reasoning controls; preserve task caption and selected values |
| Sidebar | Remove redundant MoonCode eyebrow and repeated total; quieter New chat action with recognizable chat glyph |
| Empty chat | Keep a short heading; remove repeated explanatory paragraph |
| Terminal | Compact new/interrupt/selection/search controls; Rename and Close in a labeled overflow menu; one empty-state sentence |
| Media | Compact disclosure and action glyphs; preserve descriptions needed to distinguish voice capabilities and real connection state |
| Activity | Stop action glyph; worker/image/turn status shapes beside readable status text |
| Localization | English/Chinese pane names and toolbar accessible names; icon children survive text translation |

## State vocabulary

| Meaning | Shape | Behavior |
| --- | --- | --- |
| Queued | Clock | Waiting to begin; also represents queue-message action when work is running |
| Running | Open ring | Only animate actual ongoing work; static under reduced motion |
| Needs input | Question circle | Retain the question and answer choices |
| Complete | Check circle | Finished outcome |
| Failed | Exclamation diamond | Retain the error and recovery action |
| Paused/stopped | Pause circle | Preserve the exact text so stopped/cancelled/paused are distinguishable |

Microphone and muted microphone are separate glyphs. Disclosure state is shown by the control's expanded styling. Compare uses opposing arrows; Split view uses a divided window so the two controls cannot be confused.

## Assets and reuse

The [generated review board](design/moondesk-icons/generated-review-board.png) and [prompt record](design/moondesk-icons/GENERATION.md) accompany 24 hand-adapted SVGs in `ui/rabbita-desk/assets/ui-icons/`. These SVGs are the production implementation of the generated direction. `ui-icons.js`, `main/ui_icons.mbt` and `styles/ui-icons.css` share the vocabulary across runtime and typed views. The bitmap is retained as design source; the app uses SVG masks for small-size clarity, light/dark theme inheritance and base-path-safe bundling.

## Scope

This is the coding workspace cleanup. Desk, Wiki, Flow, Packs, and deep setup/review forms still need their own content-hierarchy pass. Do not replace every word with a glyph: navigation destinations and unfamiliar product concepts often benefit from text. The next useful work is consolidating repeated settings, shortening empty-state copy and moving secondary actions into consistent local menus across those surfaces. Screenshot evidence uses the isolated Coding-demo preview; its Code-assistance installation notice describes that demo environment.

## Verification

- Production JavaScript typecheck and Vite build passed; `moon info` and `moon fmt` completed with no public interface diff. Existing repository warnings remain.
- Four existing MoonBit composer tests passed. Eleven workbench/developer runtime checks, seven localization checks, and six media behavior checks passed (28 focused checks in total).
- Browser: icon assets render, selected pane keeps its desktop label, setup disclosure changes accessible name without losing the glyph, and duplicate developer tabs are absent.
- Browser: a real terminal opens; its actions menu reveals Rename/Close; Escape closes it; Close removes the created test terminal. Disabled controls correctly represent the empty terminal state.
- Mobile at 375 × 740: document width remains 375px, composer controls fit, voice popover stays inside the viewport width, and Escape closes it and restores focus to its disclosure. The temporary viewport was reset.
- Fixed a rendered localization issue discovered during the pass: General/book headings use distinct child keys so translated text nodes are not reused for a different book title.
- [Desktop screenshot](design/moondesk-icons/desktop-workbench.jpg) and [mobile voice popover](design/moondesk-icons/mobile-voice-popover.jpg) record the rendered UI.
- Visual checks used the light theme. Dark theme icons inherit existing foreground tokens; an independent dark-mode visual check was not performed. No actual voice/provider/camera calls were made during this presentation pass.
