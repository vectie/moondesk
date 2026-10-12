# Navigate the current code draft

The code editor's **Local code declaration outline** lists bounded declaration
hints for MoonBit, JavaScript, TypeScript and Python. Open a supported source file
in MoonDesk's normal source editor, type part of a declaration name in **Filter
declarations**, then select its kind/name/line button. Selection moves to that
identifier in the current draft. **Back to location** restores the previous
selection and scroll; **Forward to location** returns to the declaration.

This closes a different workflow from the existing Markdown section outline,
which edits/moves document sections, and from F12, which starts with an already
known identifier. The operator can discover code declarations in an unfamiliar
file before choosing a place to inspect or edit (MOONDESK-UC01/UC02).

- Results refresh as the draft changes, including unsaved edits. The filter is
  case-insensitive; a file/workspace change clears it.
- Results preserve exact UTF-16 identifier offsets, including CRLF and earlier
  astral characters. Selecting does not edit, save, dispatch input or call a
  provider. Existing draft/save/conflict ownership remains unchanged.
- Empty results say zero matching. At most 100 buttons are rendered; the full
  matching count is shown, and filtering can find declarations beyond that page.
- Editors that are temporarily disabled also disable filtering and selection.
  A stale result cannot navigate using offsets from a different draft/file.
- Drafts above 120,000 UTF-16 characters show an explicit unavailable message.
  Unsupported languages hide this outline; their existing editor remains usable.

## Honest syntax scope

These are local lexical hints, not compiler symbols, a complete parser, symbol
resolution, or evidence that a file compiles. Supported declarations must begin
a line (optional indentation/modifiers). Ordinary named functions, classes,
MoonBit structs/enums/traits/types/suberrors and selected variable/type forms
are recognized. MoonBit `Type::method` and Python `async def` are recognized.
ASCII identifiers only; multiline declarations, destructuring, JS generator
syntax, object/class method shorthand, decorators as declarations, and other
advanced syntax are not enumerated. Comments and ordinary/multiline strings
are masked. JS/TS regular-expression literals in expression-start contexts
(assignments, arguments, returns, ternaries and similar operators) are masked
with escaped slashes, character classes and flags preserved as offsets. Ordinary
division is distinguished using the preceding token. This bounded lexer does
not resolve every grammar-dependent slash ambiguity, such as regex statements
immediately after a control-condition closing parenthesis. Template interpolation
is masked with the template. Unterminated JS strings and regexes recover at the
next physical line; unterminated multiline strings/templates hide later hints
until corrected. The status label always says these are not compiler
symbols; use configured semantic tools for compiler-backed operations.

## Verification scope

`node --test ui/rabbita-desk/source-code-outline*.test.mjs ui/rabbita-desk/source-navigation*.test.mjs ui/rabbita-desk/source-editor-runtime.test.mjs`

Tests execute the production lexer and installed runtime through a minimal DOM
shim, including button/filter handlers and back navigation. This is not a real
browser, native app, Rabbita rebuild, MoonBit compiler or full-product check.
No dependencies, network or Moon commands are required. The existing runtime
imports this module directly, so no separate helper or new application is needed.
