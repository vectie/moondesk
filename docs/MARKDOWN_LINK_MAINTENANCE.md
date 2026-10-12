# Inspect and retarget Markdown links

When a guide or image moves, update its supported Markdown destinations without
replacing similar text in prose, code examples or reference definitions.

Open a `.md` or `.markdown` file in **Code → Workspace editors → Source editor**,
then expand **Inspect and retarget Markdown links**. This works on the current
unsaved draft, without an agent, provider, network request or additional package.

## Complete a guide migration

Open `docs/samples/markdown-links/guide-before.md`:

1. Choose **Inspect current draft links**. The inventory shows four supported
   inline destinations with link/image labels and one-based line/UTF-16 columns.
   Use Previous/Next links for more than 25 occurrences.
2. Choose **Select destination in editor** to inspect its exact token. This
   uses existing source navigation; it does not change the draft.
3. Choose **Edit destination** on `docs/old-guide.md`. The complete existing
   token is copied into the **New Markdown destination token** field.
4. Enter `docs/new-guide.md`. Choose **Preview this occurrence** to change only
   that row, or **Preview all exact matching destinations** for both guide links.
5. Review the before/after token, count and every affected line/column. Exact
   matching includes both links and images and is case-sensitive, with no URL
   decoding or normalization. `a(b).md`, `a\(b\).md` and `<a(b).md>` are different
   tokens. Titles and labels never participate in matching.
6. Choose **Apply reviewed destinations to draft**. The all-match result equals
   `guide-after.md`. Prose, code examples, the FAQ, image and reference definition
   remain unchanged. The changed span stays selected.
7. Use existing Undo/Redo and Save when ready. Apply emits one ordinary source
   input; it does not independently save a file or change conflict handling.

Cancel closes the edit form without changing the source. An identical token
is a no-op with Apply disabled. A malformed destination reports a recoverable
error; fix it and preview again. Inspection and proposals are not persisted.

## Destination syntax and scope

Enter one destination token, such as `docs/guide.md`, `#part`,
`images/chart(v2).svg`, `images/chart\(v2\).svg` or `<docs/user guide.md>`.
Parentheses in an unbracketed destination must be balanced or escaped. Angle
brackets permit spaces. An empty token is allowed without a title; use `<>`
for an empty destination when a title is present to avoid ambiguous parsing. Do not include a
label, title, surrounding whitespace or a newline. Escapes and entities are
kept as source text, never decoded. URLs are never opened, fetched, validated
or checked for reachability; choosing a token is not an endorsement of it.

The scanner covers single-line inline links and images with bracketed labels,
balanced/escaped destination parentheses, angle destinations, and optional
single-line quoted or parenthesized titles. It is deliberately bounded rather
than a full Markdown/CommonMark/MDX renderer:

- Reference-style links/definitions, autolinks, multiline links/titles and outer
  links with nested link/image labels are not inventoried. Reference definitions
  and title continuations are conservatively excluded through the next blank
  line; put a blank line after definitions before inspecting ordinary prose.
- Inline code, backtick/tilde fences (including conservative container-fence
  recognition), indented code, and blockquote lines are excluded.
- Leading `---`/`+++` blocks are treated as front matter. Raw HTML-like blocks
  are conservatively excluded through the next blank line, including text
  following their closing tag. HTML-like code examples can exclude extra text.
- Unclosed front matter/fences/code spans conservatively exclude following
  text. Labels containing code spans and unsupported or malformed constructs
  may be omitted. A count of zero does not mean the document has no links.
- `.mdx` is not enabled. Link interpretation inside extensions, complex lists
  or other container syntax is not qualified. Inspect the resulting source
  and your normal Markdown preview before saving.

Limits: 120,000 UTF-16 units in the input and output, 1,000 supported occurrences,
and 32 nested label brackets/destination parentheses. Exceeding document or
occurrence limits fails inspection without a partial actionable inventory.
Previews show up to 4,000 units per token and clearly disclose shortening; the
input field and editor retain complete tokens. Application uses the whole
reviewed token and rejects results that change the inspected link structure.
Exactness is relative to textarea text, not original encoding or line endings
that the browser may already have normalized.

## Interrupted work and qualification

Any draft or observed editor-availability change invalidates the inventory and
review. Inspect again before editing. File/workspace switches clear the edit
field. Replacement input changes require a new preview, including silent field
changes checked at Apply. Stale page controls and disconnected editor controls
cannot act on a replacement context. Apply consumes its review, so repeated
clicks cannot duplicate the edit. Failed insertion restores the original draft
and selection and requires another preview.

From the repository root, run:

```sh
node --test ui/rabbita-desk/source-*.test.mjs
```

Focused parser tests and minimal DOM adapters execute the installed production
source-runtime handlers, exact sample output, navigation, one/all edits,
Unicode/CRLF, growth/shrinkage, pagination, cancellation, no-op, invalid input,
stale review and context changes, limits and insertion recovery. These are Node
functional tests, not browser tests. Existing source inspection connects the
emitted input to `SourcePane(EditDraft(value))`, which owns dirty state/history.
The compiled reducer, actual Undo/Redo, Save/conflict/reload, graphical layout,
accessibility, native host and full product were not run for this change.

The lazy source-runtime import includes the UI. The checked-in production
bundle is not rebuilt; use the normal UI build in a provisioned environment
before packaged use. The broader UI Node suite's production-minification test
requires the absent `terser` dependency. No dependency install/substitution,
network, browser launch or Moon command was attempted. R50 remains the last
fully verified cumulative baseline; R51–55 and this source change are separate.
