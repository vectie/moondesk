# MoonDesk icon family · round two

The production family now contains **72 SVGs**: the original 24 plus the 48 additions below. Files live in `ui/rabbita-desk/assets/ui-icons/`; identifiers are registered in `ui-icons.js` and masked through `styles/ui-icons.css`.

## Vector source and geometry

These 48 additions are hand-authored SVG geometry extending the existing MoonDesk family. They use a `0 0 24 24` view box, 1.65-unit black strokes, round caps and joins, and transparent fills. CSS masks supply the product theme color. They are source vector assets, not generated bitmaps or traced output from the earlier generated board. The original generated exploration and its provenance remain documented separately in [GENERATION.md](GENERATION.md). Any companion round-two image exploration is a design reference, not the source of these vectors.

## Catalog

| Category | Names | Intended use |
| --- | --- | --- |
| Destinations and objects | `home`, `folder`, `book`, `code`, `workflow`, `package` | Desktop, directories, Books, Code, workflows, app packages |
| Basic actions | `plus`, `close`, `check`, `edit`, `copy`, `trash` | Create, dismiss, accept, edit, copy, remove |
| Editing and transfer | `refresh`, `undo`, `redo`, `save`, `upload`, `download` | Reload, reverse/reapply an edit, save, transfer a file |
| Organization and links | `external-link`, `link`, `pin`, `unpin`, `filter`, `history` | Open elsewhere, link, pin/unpin, filter, inspect history |
| Workspace layout | `panel-left`, `panel-right`, `panel-bottom`, `expand`, `collapse` | Toggle a named pane or expand/restore a working surface |
| Directional controls | `chevron-left`, `chevron-right`, `chevron-up`, `chevron-down` | Previous/next or open/close a disclosure, with contextual labels |
| Visibility and review | `eye`, `eye-off`, `review` | Reveal/hide content and open a review surface |
| Playback and capture | `play`, `volume`, `volume-off`, `image`, `camera` | Start playback, output audio, muted output, image object, camera capture |
| Connections and support | `plug`, `unplug`, `help`, `info`, `offline` | Connect/disconnect, help, explanatory details, unavailable network |
| Version control | `branch`, `commit` | Git branch selection and commit records/actions |

## Action and state distinctions

- Button labels describe the action: **Mute output**, **Unmute output**, **Hide preview**, **Show preview**, **Pin chat**, **Unpin chat**. Toggle state also uses `aria-pressed`; the glyph alone does not establish it.
- `check` accepts an action; the existing enclosed `complete` denotes a reported completion. `close` dismisses a surface; the existing solid `stop` ends an active operation. `trash` removes an item and needs its actual removal label.
- `play` starts media or a named task. The existing `running` reports work already underway. A circular arrow is `refresh`, not progress. `offline` is a reported connection state, not a disconnect button.
- `mic`/`mic-off` refer to microphone input. `volume`/`volume-off` refer to audio output. `camera` starts or represents camera capture; `image` identifies an existing image; `attach` adds an attachment.
- `branch` identifies Git branching; the original `fork` continues to denote conversation forking. `commit` is a revision node, not a generic save icon. Keep labels when both contexts are nearby.
- `panel-left`/`panel-right`/`panel-bottom` identify a particular pane; the short interior mark identifies the target pane. Existing `split` changes the working layout. `expand`/`collapse` resize a surface; chevrons disclose content or navigate.
- `help` uses a life ring, while `waiting` uses a question circle. Keep **Help** distinct from **Needs your input** in label and placement; never infer task status from a help button. `info` opens explanatory details.
- `external-link` opens another destination; `link` copies or edits a link and needs that verb in its label. `upload` transfers a file; the existing `send` submits a message.

All icon-only controls retain an accessible action name, keyboard focus styling, and an explicit tooltip. Status-only uses include accessible status text and derive their symbol from actual runtime state. These additions do not change the shared button, tooltip, animation, or responsive behavior.
