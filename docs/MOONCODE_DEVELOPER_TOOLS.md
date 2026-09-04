# MoonCode developer tools

MoonCode has an optional developer-tools disclosure containing a terminal-like
command evidence view, an isolated browser preview, and a fork-and-compare
trial composer. These tools belong only
to MoonCode; they are not part of MoonDesk's ordinary chat-and-document
experience.

The same lazy runtime renders the MoonCode model/reasoning selectors and
enhances typed tool evidence into structured, state-aware disclosure cards.
Reasoning content itself is never shown. Keeping this presentation layer in a
bounded lazy chunk avoids adding developer chrome to the generated Rabbita
route or the document workspace.

## Terminal boundary

The terminal view is not a browser shell and does not call MoonClaw's native
tool-execution endpoint directly. It displays command and output fields from
the selected chat's typed `MoonCodeEvidenceRow` records. A command entered by a
user is converted into an explicit MoonCode request and sent through the normal
MoonCode composer. Existing composer drafts are never overwritten.

This preserves MoonCode's normal approval, sandboxing, streaming, cancellation,
and evidence lifecycle. Empty edit or artifact records are not presented as
terminal output.

## Browser boundary

The browser accepts HTTP and HTTPS preview addresses, provides local
back/forward history, reload, and an explicit open-external action. Its frame
uses `sandbox="allow-scripts allow-forms"`: scripts and form interactions work,
but same-origin access and top navigation are not granted. Active and local-file
schemes are rejected.

For generated workspace sites, **Prepare evidence** requests a bounded snapshot
from the isolated frame and persists accessibility, resource, console and
runtime observations through the host. Only a receipt containing both a host
receipt ID and a durable `book/evidence/browser/` reference can mark evidence
persisted. The control remains disabled until its lazy runtime is attached.

## Fork-and-compare boundary

The Compare tab creates one explicit MoonCode request for two trials from the
same workspace baseline. It requires MoonFort isolation, requests output,
diff, checks, warnings, latency, tokens, and cost evidence for both branches,
and forbids promotion until the user chooses. The request travels through the
normal MoonCode composer, so routing, approvals, sandboxing, and transcript
evidence remain authoritative. MoonWiki does not expose branch graphs or route
controls.

The coordinator itself is durable: `GET/POST /api/mooncode/comparisons` stores
one revisioned record for the shared digest, two branch session identities,
evidence counters and explicit selection. A browser-local copy is recovery
only. Selecting a branch records a `moongate.comparison_evaluation_candidate.v1`
without claiming that its outcome has already been verified.

## Integration

Render `render_mooncode_developer_tools(model)` inside the MoonCode center,
preferably before the chat surface. Load `styles/mooncode-controls.css`,
`styles/mooncode-tool-transcript.css`, and
`styles/mooncode-developer-tools.css`, then lazily import
`mooncode-developer-tools-runtime.js`. MoonBit owns the stable terminal,
browser and comparison shells; lazy runtimes attach behavior and evidence so a
Rabbita reconciliation cannot delete an active control tree. Controls that
depend on a lazy runtime stay disabled until attachment completes.
