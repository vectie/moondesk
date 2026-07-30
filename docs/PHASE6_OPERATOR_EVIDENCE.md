# Phase 6 operator-evidence closure

Phase 6 is complete locally at commit `568ec7c3`. This record summarizes the
bounded exit-gate audit; it does not introduce another evidence store or a new
runtime abstraction.

## Exact audit result

Five exit criteria were already proven by their owning UI tests. One gap
remained: a completed approval showed its decision but did not tell an ordinary
user which command and tool call owned it or expose the durable receipt. Commit
`568ec7c3` corrects that copy in `mooncode_activity_views.mbt` and adds one
focused regression test. No duplicate test or generic helper was added.

## Exit-gate ownership

- **Ordinary users can explain current work without diagnostics:**
  `code mode transcript keeps canonical progress with existing command` and
  `code mode canonical work exposes typed edit and test evidence in its turn`.
- **Every displayed progress claim has runtime evidence:**
  `canonical work evidence preserves public strings and approval fallback` and
  `code mode canonical work exposes typed edit and test evidence in its turn`.
- **Approvals and mutations have durable receipts:**
  mutation evidence remains owned by
  `code mode canonical work exposes typed edit and test evidence in its turn`;
  completed approval ownership and receipt copy is closed by
  `code mode approval copy identifies ownership and durable decisions`.
- **Reload and reconnect preserve canonical ordering:**
  `code mode transcript appends local optimistic turn after three backend turns`,
  `code mode command result keeps optimistic prompt until canonical turn arrives`,
  and `code mode stale listing preserves selected settled session`.
- **Stale events cannot overwrite newer state:**
  `code mode delayed command response cannot replace a newer turn` and
  `code mode stale session listing preserves selected in-flight session`.
- **Diagnostic detail remains progressively disclosed:**
  `failed MoonCode session keeps failure copy inside the transcript`,
  `Desk loading empty state offers a visible retry without diagnostics`, and
  `code mode approval copy identifies ownership and durable decisions`.

## User-visible correction

Pending approvals say that the operation cannot run before approval. Completed
allow and deny decisions say `Approval recorded` or `Denial recorded`. Their
collapsed `Technical details` disclose the owning command, tool call, durable
receipt, and runtime arguments; pending controls remain attached to the
canonical work turn.

## Validation retained at `568ec7c3`

The preceding implementation turn proved the focused regression test, the
owning Rabbita Desk UI suite, MoonBit checks, `moon info`, canonical formatting,
and the repository clean-tree validator. The committed change is limited to:

- `ui/rabbita-desk/main/mooncode_activity_views.mbt`
- `ui/rabbita-desk/main/app_code_mode_session_wbtest.mbt`

Primary navigation remains exactly **Desk, Wiki, Code, Flow, Packs**. Phase 7
is not started by this closure.
