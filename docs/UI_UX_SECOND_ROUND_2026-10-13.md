# Second UI round: icons and interaction structure

The first 24 icons covered a small part of the coding workflow. This round
extends the production family to 72 and applies a common interaction language
to navigation, file actions, tabs, setup, schedules, and local disclosures.

## Product changes

- **Shared navigation:** recognizable destination glyphs beside short labels,
  a compact desktop header, and a labeled destination disclosure on mobile.
- **Desk:** compact Back/Forward/Up/Home/Refresh controls, a clearer search
  field, labeled New/Import/View menus, and consistent selection/hover/focus.
- **Coding tabs:** real tab semantics, selected underline, Arrow/Home/End
  navigation, and scrolling overflow. Source filenames and modified markers
  remain visible; closing a file returns focus to the remaining selected tab.
- **Source editing:** file path, Open and Save stay visible. Find/replace and
  Edit tools open on demand. The latter retains the full labels for Markdown,
  line operations, JSON and table conversion. Cmd/Ctrl+F opens search; Escape
  returns to the editor. Discard/reload remain labeled local menu actions.
- **Drawers:** coding setup, schedules and job history have bounded geometry,
  explicit Close actions, and predictable Escape/outside dismissal. Only one
  contextual overlay remains open. Outside dismissal leaves focus where the
  user clicked; explicit Close and Escape return to the trigger.
- **Setup:** icon-and-label tabs, compact counts, progressively disclosed
  imports/catalog/technical detail, and retained in-memory drafts per book.
  Closing the drawer or switching its tabs does not save or discard edits.
  Refresh retains edited instructions. Draft retention lasts for this page
  session; a browser reload is not persistence.
- **Hover and keyboard focus:** one viewport-aware tooltip layer avoids panel
  clipping. Controls have stable geometry, selected/expanded/disabled feedback,
  visible focus and larger touch targets. Meaningful text remains available.

These drawers are nonmodal. Moving keyboard focus back to the work area closes
the overlay so it does not cover the focused control. The MoonVis workbench
also demonstrates a separate native modal drawer; it is a design specimen,
not a claim that the app's setup drawer is modal.

## Icon source and visual guide

- [72-icon family record](design/moondesk-icons/ROUND_TWO.md)
- [MoonVis interaction guide](../../moonvis/docs/ICON_LANGUAGE.md)
- [Interactive icon and control workbench](../../moonvis/docs/icon-workbench.html)

The original board is generated design exploration. The 48 additions are
editable SVGs extending that established family. Help uses a life ring to
distinguish it from a task requiring input. The catalog contains exact copies
of the production SVGs and offers search, light/dark views, tab, panel, drawer,
menu and focus examples. A catalog entry does not mean every screen already
uses that glyph.

## Verification

- 19 focused JavaScript checks cover tabs, popup focus, tooltip placement,
  setup draft retention and localization.
- Four existing MoonBit composer checks pass.
- Targeted MoonBit interface generation and formatting pass; the frontend's
  generated public interface is unchanged.
- All 72 SVGs parse; MoonVis reference copies match production assets.
- The catalog renders all 72 assets without missing images, supports both
  themes, and fits a 375px viewport. Its tab selection, modal Escape/focus
  return, and icon filtering have been exercised in the browser.
- The final frontend bundle builds successfully with Vite and esbuild
  minification. The repository's default Terser configuration is unchanged.
- App browser checks cover source-file opening, Cmd/Ctrl+F and Escape, file
  tab closing, setup draft close/reopen, outside-click focus, explicit Escape
  focus return, and Desk View menu dismissal. At 375 × 740, the page has no
  horizontal overflow, the setup drawer stays inside the viewport, and the
  selected end tab scrolls fully into view.
- [Desktop result](design/moondesk-icons/round-two-desktop.jpg) and
  [mobile setup drawer](design/moondesk-icons/round-two-mobile.jpg) are real
  captures of the isolated demo preview. Its missing Code-assistance banner
  describes that demo environment.

The app changes are frontend presentation and interaction changes. This round
does not install or update the packaged desktop app. Detailed forms in Wiki,
Flow, Packs and other deeper surfaces still need their own content-hierarchy
review; the new shared vocabulary is available to them.
