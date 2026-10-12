# Clean up a list in the source editor

Select the lines of a supported text file, then choose **Sort ascending**,
**Sort descending**, or **Keep unique lines** in the Selected lines tools.
Each action is one Undo step. The resulting block remains selected so that you
can deduplicate and then sort without selecting again. Use the ordinary Save
action when the draft is ready.

- Sort is literal and case-sensitive: `10`, `2`, `Alpha`, `alpha`, `z` is
  ascending order. It compares UTF-16 code units, not numbers or locale-aware
  alphabetic order.
- Keep unique lines retains the first exact occurrence in its original order.
  It does not sort. Spaces, case and Unicode normalization matter. Empty lines
  can also be duplicates.
- Selection endpoints affect whole lines. If the selection ends at the next
  line's beginning, that next line is excluded. A caret alone changes nothing.
- Header, footer and all other unselected text remain untouched. Sorting leaves
  LF/CRLF separators in their original slots. Removing lines keeps the first
  N-1 separators and the old final separator for N remaining lines, retaining
  the block's final-newline presence. No global newline conversion occurs.
- Undo and Redo restore both text and selection, including backward selections.
  An already sorted or unique block makes no history entry and preserves Redo.

These controls edit literal source. They do not understand list numbering,
Markdown fences or code syntax. Select only a block where reordering or removing
repeated lines is intended, and inspect the result before saving. Unavailable,
loading and saving sources have disabled controls; invalid stored selections
ask you to select again without changing the draft.

## Try the included inventory

Open `inventory-before.txt`. Select the four lines between `Inventory 😀` and
`Footer`: beta, alpha, beta, Zebra. Choose **Keep unique lines**, then
**Sort ascending**. Compare with `inventory-actual.txt`: Zebra, alpha, beta.
Both files retain CRLF line endings. Undo twice restores the input; Redo twice
restores the output. `inventory-rendered.html` is actual compiled editor markup
from the synthetic test journey, not a screenshot or a separately deployed app.

Core tests exercise exact text, mixed separators, Unicode, backward selection,
one transaction, stale revisions and no-op history. Compiled controller/render
tests exercise textarea selection capture, both actions, undo/redo, buffer
switching and disabled states. No graphical browser, desktop launch, save/reopen,
accessibility, large-file performance or deployed UI qualification is claimed.
Build the updated source UI before deployment.
