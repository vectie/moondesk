# UI consistency pass

Date: 2026-10-22

## Cross-workspace interaction and clutter scan

The follow-up covered Book's document picker, attachment chips, Review / Sources /
History / Checks; Code's Files / Changes / Preview / Compare panels, all seven
settings categories, scheduled tasks and task history; Flow's empty/loading state,
file picker and task handoff; and Pack details, Studio and Collaboration.

Corrections:

- Book's default task/document headings, picker headings, attachment actions and
  Flow's loading copy now follow the selected language. Authored headings,
  filenames, search results, snippets and attached context keep their content.
- Document and workflow pickers concentrate on files. Secondary import,
  organization and synthesis actions are under a labelled More icon; the action
  that opens Desk explicitly names its destination.
- Pack inspector controls sharing the same drawer no longer trigger outside
  dismissal when switching between them. Transient focus changes during rendering
  do not close this attached panel. The inspector starts below the workspace
  toolbar so it cannot cover the controls used to switch it. Escape/outside
  dismissal is retained.
- Pack details offer the app action and local setup. The former composition
  action was unrelated to the selected pack and jumped to an empty Flow canvas.
  Integration information is under Technical details. Studio uses compact
  single-column steps and concise copy without a duplicate heading.
- Code reply utilities use Copy / Compare icons with accessible names, hover
  labels and copied-state feedback. Successful task-history diagnostics are
  under Technical details; status, turn counts and failures remain visible.
  Schedule utilities already used icons and were verified without running tasks.
- Context handoff into Code and the narrow-screen Start task control now use
  stable identifiers instead of English title/label selectors. Model reasoning
  labels agree between the composer and settings.
- Utility icons, disclosure controls and Pack setup rows use the shared control
  height, spacing, font and corner tokens. File-picker secondary controls remain
  inside a compact popover. Focused pickers use a flexible column layout instead
  of reserving a large grid row for their removed mode selector.
- Book action hover help, attachment drop guidance and Terminal field help now
  follow the selected language too.

The audit exercised navigation and editing forms without submitting requests,
running jobs, changing schedules, importing files or renaming user content.

Checks: all 2,286 frontend MoonBit tests and 73 focused JavaScript tests passed.
`moon info --target js`, `moon fmt`, `moon check --target js` and the production
build completed. There are no tracked public interface changes.

Final packaged verification: installed the rebuilt UI in
`/Applications/MoonDesk.app`, verified its code signature and exact match to the
production assets, then reopened the app. Native Book displays localized default
headings and hover help. Pack Studio → Collaboration → app details → local setup
was exercised against the packaged backend; toolbar controls stay visible and
the inspector switches correctly. Escape and outside-click dismissal both work.
The focused Book picker shows a Chinese placeholder, compact drop area and
collapsed secondary actions. The original browser tab was restored to Code.

The existing MoonFlow service-unavailable state was inspected, but successful
Flow execution and collaboration were not exercised while that service was
unavailable. No claim of an end-to-end execution test is made for those paths.

Evidence: [Packaged Packs](design/ui-cross-workspaces-20261022/after-packaged-packs.png),
[Packaged Book](design/ui-cross-workspaces-20261022/after-packaged-book.png),
[Book picker](design/ui-cross-workspaces-20261022/after-book-picker.png), and
[Code history](design/ui-cross-workspaces-20261022/after-code-history.png).

## Desk system section labels

Desk's root rows use 15 named sections supplied by the MoonBook adapter. These
labels were incorrectly grouped with authored filenames and excluded from
localization. They now have explicit catalog keys, matched by directory kind,
canonical path, source layer and original adapter label. This includes Inbox,
Skills, Tools, Review Queue, Journal, Raw Evidence, generated sites and run
history. The directory outline and selected-item heading use the same mapping;
the root breadcrumb marker is also localized.

The same scan corrected Quick Access's empty state, the selected-path status,
and Desk's selection-detail action labels. Type and access values are rendered
as interface text; actual paths and source identifiers remain technical text.

Actual file/folder names, paths, hover paths, breadcrumbs below the root and
rename values/placeholders are preserved. A user-created `Skills` or `Inbox`
does not become a system label just because its name matches. Search matches
the displayed localized system label as well as its original label and path.
No filesystem rename or backend section change is involved.

Regression checks: 19 localization tests and 2,286 frontend MoonBit tests passed,
including canonical-vs-authored identities, rendered label scopes, both locales,
and unchanged path/rename text. `moon info --target js` and `moon fmt` completed
without tracked public interface changes.

Packaged verification: rebuilt the production UI, installed it in
`/Applications/MoonDesk.app`, and verified its signature and exact asset match.
The reopened native app displays the localized section names; `book.json` and
all section paths/hover paths remain unchanged. Searching for `收件箱` returns
the Inbox section. The selection drawer shows `收件箱`, `文件夹`, `可写` and
localized actions while its rename value and preview paths retain `inbox`.
The original Code preview was refreshed and the temporary audit tab closed.

Evidence: `docs/design/ui-secondary-20261022/after-packaged-desk-system-labels.png`
and `docs/design/ui-secondary-20261022/after-desk-localized-details.png`.

## Secondary surfaces follow-up

The second scan included Book tools (recent tasks, Results, Schedules, room,
calendar, Inbox, Learning and Preferences), Review / Sources / History / Checks,
Find & Add, Synthesis, all seven coding settings categories, a new skill draft,
the connection dialog, Pack Studio / Collaboration inspectors, and Desk's New,
Import, View, Add MoonBook and Storage & services disclosures. Forms were
inspected without submitting tasks, messages, imports, or schedule changes.

### Corrections

- Added 515 English/Chinese catalog entries, bringing each catalog to 1,639.
  This covers nested forms, accessible labels, placeholders, import inspection,
  library and folder loading, preview states, saved views, and secondary drawer
  empty/error/status copy. Runtime dates and composite kind/scope labels follow
  the selected language. Authored names, notes, source URLs, messages and
  artifact contents remain unchanged.
- Preferences and Learning now use 14px section headings, 13px form text,
  12px metadata, 32px controls, 6px field corners and 8px cards. Learning's
  former 9px/800 status badges use readable 12px/400 text. Drawer forms share
  8/12/16px spacing and full-width textareas; narrow layouts stack fields.
- Calendar, room, connection, search and synthesis surfaces share those same
  roles. Dialogs use 12px corners; attached drawers retain square outer edges.
  Desk's New popover now contains its filename field without horizontal spill.
  Package-import sections use the shared heading and control scale.
- The default empty MoonBook switcher label can translate; actual book names
  are explicitly marked as content. Source kinds, artifact kinds and the
  discussion filter have context-appropriate labels rather than raw IDs or an
  ambiguous action-style “Open.”
- Calendar and room display their initial loading state and wait for a
  successful response before showing an empty result. Preferences shows load
  progress, retains a failure message, and retries through an explicit Refresh
  action instead of entering an automatic request/render loop.

### Checks

- 74 focused JavaScript tests passed, including the new deferred-response
  loading/error/retry checks, user-content boundaries, translation of inserted
  controls, captured Learning forms, calendar behavior, Results and connections.
- All 2,284 frontend MoonBit tests passed. `moon info --target js` and
  `moon fmt` completed with no tracked public interface changes.
- Built the production frontend and updated `/Applications/MoonDesk.app`.
  Signature verification and byte-for-byte asset comparison passed. The
  previous complete app is in `_build/ui-secondary-20261022/MoonDesk-before.app`.
- Reopened the installed app and checked startup, the empty/default book label,
  Preferences and Calendar. Browser checks against that same packaged backend
  covered Chinese Preferences / Calendar / Learning / package import / folder
  loading, English Preferences / Book room, and the connection dialog.
  Restored the original language preferences and refreshed the existing preview.
- Live computed styles confirmed 14px/500 section headings; 13px/400 controls;
  32px input/select/button heights; 6px field corners; an 80px textarea with
  8×12px padding. The New menu's 212px input fits its 230px popover, which has
  8px padding and 10px corners. The connection dialog uses 24px padding and
  12px corners with the same 13px/32px controls.
- Before/after screenshots are saved in `docs/design/ui-secondary-20261022/`.
  This scan covers the shared MoonDesk interface and the stated secondary
  surfaces. It does not claim execution of every backend failure, package
  import, or independent UI inside installed Pack apps.

## Scope and evidence

Inspected the running Desk, Book, Code, Flow and Packs destinations, plus the
specialist builder, coding settings, task picker, command palette and Results
drawer. Screenshots are in `docs/design/ui-consistency-20261022/`. The audit used
rendered styles as well as source inspection; document headings and code fonts
are content, and are deliberately separate from interface typography.

The local preview initially contained a build with the `/moondesk/` deployment
prefix. Rebuilding with `MOONDESK_BASE_PATH=/` restored its root-served assets.

## Inconsistencies found and corrected

| Area | Before | Applied standard |
| --- | --- | --- |
| Fonts | Shared system font, but an undefined `--font-sans` alias in the transcript | Alias resolves to the shared system family; source text remains monospace |
| Control typography | 11, 11.5, 12, 13 and 14px across buttons and selectors | 13px / 20px for controls; 12px metadata |
| Weight | Composer inherited 650; command headings 700; secondary tabs 760 | Regular controls, 500 for titles and selected tabs |
| Specialist headings | Browser-derived 21px title and 16.38px sections, bold | 17px title, 14px sections, weight 500 |
| Corners | 4–9px controls; 14px floating settings; 8/10/12px dialogs | 6px controls, 8px cards, 10px popovers, 12px dialogs; attached drawers are square |
| Spacing | Component-specific 5/6/7/9/10/11/14/18/20/22px conventions | Shared 4/8/12/16/24px spacing tokens and role rules |
| Settings | Floating sheet with a 60px header and 18×20px content padding | Attached right drawer, 48px header, 16px content padding |
| Commands | List extended below the viewport; boxed repeated arrows | Compact rows and internally scrolling dialog capped at 640px |
| Results | Repeated text buttons wrapped across multiple lines | Visible primary action and file names; labelled utility icons |
| Packs | Neighbouring cards had different heights and action baselines | Flowing grid with aligned cards and centered action groups |
| Specialist setup | Import explanation occupied the top half of the form | Optional import and task-form disclosures; focused introduction |

## Source ownership

`ui/rabbita-desk/styles/type-hierarchy.css` is the final shared visual layer,
including tokens for typography, spacing, radii and control heights. It is
imported after feature styles in `bootstrap.js`. New surfaces should use these
tokens rather than adding another local scale. The specialist builder's own
layout uses the same tokens.

Desktop controls default to 32px; dense row utilities may use 28px inside a
30px row. Touch controls retain a minimum 44px target. The main shell is 44px;
single-line pane headers are 40px. Context headers with two lines can be taller.
Reading text remains 14px with 1.6 line height. Document heading structure is
preserved. Status pills retain their semantic rounded shape.

## Verification

- Focused specialist DOM, import, task-form and workspace-result suites: 61
  tests passed. These exercise the runtime surfaces changed in this pass.
- Production frontend built with the native root URL prefix.
- `moon info --target js` and `moon fmt` completed. No tracked public interface
  changes; formatting adjusted one existing image-call layout. The frontend
  MoonBit suite passed all 2,284 tests.
- Checked all five main destinations and the affected secondary surfaces in
  the browser, including opening an optional specialist disclosure and Escape
  dismissal. Result utilities retain accessible names and hover labels.
- This is a visual consistency pass, not a claim to have exercised every
  execution state or every installed Pack's independent embedded UI. The
  long-running preview server on port 4199 reports unavailable Code/setup
  endpoints; the packaged app provides the native verification surface.
- Updated `/Applications/MoonDesk.app` with the final production UI, verified
  its signature and byte-for-byte asset parity, then reopened it. Checked native
  Packs, populated coding settings, Code's model/session list, and schedules.
  The previous complete app is backed up under
  `_build/ui-consistency-20261022/MoonDesk-before.app`.
- The native check found a nine-day-old MoonClaw daemon that accepted TCP
  connections but did not answer health requests or stop on SIGTERM. Restarted
  that stalled process through the existing local service configuration; the
  status API then reported `ready`, and the app showed the configured model and
  both existing session groups. Both verification schedules remain paused.

The MoonVis guide records the same reusable rules. Existing task data and
schedules are outside this presentation change.

## Language consistency follow-up

The mixed-language UI had several concrete causes:

- Newer workspace surfaces were missing from the translation catalogs.
- The separately generated public script had drifted from its source catalogs.
- Several Code panel keys were absent, causing internal key names to appear.
- Dynamic attributes, icon tooltips, and empty legacy translation keys were
  not handled consistently.
- Chinese mode replaced the body font independently of the shared controls.
- Dates used the browser language even when a different interface language
  was selected. A locale in the URL also overrode subsequent selector changes.

### Implementation

`interface-locale.js` imports the English and Simplified Chinese JSON catalogs
directly into the frontend build. The obsolete generated public script is
removed. The catalogs grew from 557 to 1,124 entries, including task creation,
Results, scheduling, specialist setup, coding settings, files, terminal,
preview, comparison, shell navigation and command descriptions.

Icon titles, accessible labels, placeholders and tooltips follow the same
locale. Dynamic messages use whole phrases; generic partial “Open …” matching
is replaced with an explicit Pack action key. Dropdown labels retain their
underlying values. Empty legacy keys can use the phrase translation, while a
missing key preserves its authored fallback instead of exposing the key.

Book names, task titles, file paths, model IDs, documents, chat content and
terminal output retain their original text. Composite status rows translate
their labels separately from identities. New runtime views can use
`ui-locale.js` for these boundaries and for locale-aware dates.

The language selector lives under **Book tools / 知识库工具** in the workspace
header. It survives shell rerenders and remembers System, English or Simplified
Chinese. Both languages use the shared font family, including CJK fallbacks,
with the same size, weight, padding and radius tokens. Long fallback Pack names
now use the standard package glyph instead of being clipped into a 24px badge.

Native verification exposed an observer feedback loop: the editor rewrote its
cursor status in English, then localization rewrote it in Chinese. The editor
now produces the selected-language text before comparing or updating the DOM.
The source editor's compiler status uses the same helper. A regression test
checks that observing and translating the status settles instead of looping.
Code's default headings are marked separately from user-written task titles,
and comparison options and suggested actions follow the selected language.

### Verification and scope

- 82 focused JavaScript tests passed; one optional live service integration
  test was skipped. Coverage includes language changes, newly inserted and
  rerendered labels, icon accessibility, user-content preservation, selector
  remounting, dropdown values, settings, task results and scheduling.
- A source inventory checks every explicit interface key and the computed
  Code panel / Git status key families against both catalogs.
- All 2,284 frontend MoonBit tests passed. `moon info --target js` and
  `moon fmt` completed without tracked interface changes.
- The final catalog/editor checks passed all 18 tests; all four suggestion
  model tests also passed after completing the comparison and suggestion labels.
- Rebuilt the production frontend and installed it in
  `/Applications/MoonDesk.app`. Signature verification and a recursive asset
  comparison both passed. The complete previous app is preserved in
  `_build/ui-locale-20261022/MoonDesk-before.app`.
- Verified English → system Chinese in the native app and English → Chinese
  in the browser. Code opens, native navigation responds, and the default chat
  heading, comparison controls and suggested actions use the selected language.
  The native preference remains System; the browser remains Simplified Chinese.
- Final native screenshots: `docs/design/ui-locale-20261022/after-packaged-code.png`
  and `docs/design/ui-locale-20261022/after-packaged-packs.png`.
- Visual scope is MoonDesk's main workspace and the inspected local drawers.
  Installed apps embedded inside Packs own their own interface strings;
  app names, source documents and user-authored English are not UI defects.
