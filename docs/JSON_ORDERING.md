# Order a JSON record array in the editable draft

Open a JSON source in MoonDesk, expand **Explore JSON values**, and inspect the
array you want to order (empty pointer means the document root). Choose **Order
displayed record array**. Enter all four settings explicitly:

- Relative field JSON Pointer, for example `/priority` or `/details/a~1b~0`.
- Field type: `number`, `string`, or `boolean`.
- Direction: `asc` or `desc`.
- Missing field: `error`, `first`, or `last`.

Choose **Preview ordering**. Review the before/after array and the original
zero-based item indexes in output order. **Order in draft** applies once through
the ordinary source-editor input event. Inspect and use the existing Save controls
when ready. Cancel leaves the draft untouched. Empty, singleton and already
ordered arrays preview successfully but do not create a spurious edit.

For example, `[ {"priority":2,"id":9007199254740993}, {"priority":1,"id":"\u0061"} ]`
with `/priority`, `number`, `asc`, `error` becomes
`[ {"priority":1,"id":"\u0061"}, {"priority":2,"id":9007199254740993} ]`.
The record text, including large numbers and escape spelling, is preserved.
Whitespace and commas between records stay in their original slots; all text
outside the selected array is unchanged. This is ordering, not pretty-printing.

## Exact semantics and refusal

Every item must be an object. The field pointer is relative to each record and
must be nonempty. Missing means an absent member or array index, not `null`, an
empty string, or scalar traversal. `first`/`last` placement is independent of sort
direction. Present fields must all match the chosen type; null and mixed types
refuse. Duplicate keys along the selected pointer are ambiguous and refuse.
Unselected duplicate keys stay untouched inside their raw record.

Numbers compare as exact decimal values without JavaScript number coercion or
exponent expansion. Equivalent values such as `1`, `1.00` and `10e-1` tie; `-0`
and `0` tie. Number exponent spellings are bounded to 256 digits. Strings compare
their decoded, case-sensitive UTF-16 code units. Boolean order is false then true.
There is no locale, date, case folding, Unicode normalization or string-to-number
coercion. Equal values always retain their original relative order, even descending.

The existing parser's 120,000 UTF-16-unit, 10,000-value, 64-container bounds apply.
Invalid input cannot be ordered. The operation preserves total source length and
node/depth counts. Before and after previews are capped at 4,000 units each; the
index listing shows at most 100 indexes, with shortening disclosed. Apply uses the
complete bounded draft. Source, displayed array, document/workspace identity,
settings and editor availability must still match the preview. Changed settings
or source require a new preview; failed editor replacement restores source and
selection without emitting an input event.

## Verification boundary

`node --test ui/rabbita-desk/source-json-*.test.mjs` exercises the actual parser,
ordering module and installed production source-runtime event handlers through
minimal DOM adapters. The broader `source-*.test.mjs` suite checks affected source
workflows. These are not browser layout, native host, Undo/Redo, Save/reopen or
full-release qualification. MoonBit source and public interfaces are unchanged.
This extends the direct source-editing intent of MOONDESK-B02; its authored
save/reload and Office acceptance criteria remain unchanged and unclaimed here.
