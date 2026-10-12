# Import a Book received through Town

In Desk's **Library → Import a Book package**, choose **Choose a package received
through Town**. Select the unchanged `.moonbook-agent` file, then explicitly
choose its original `.binding.json` file. The `.receipt.json` transfer receipt is
a different file and cannot replace the binding. If you have only an ordinary
local export, use the existing **Choose package** path instead.

The binding comes from the existing Town package handoff/download. Desk does not
generate a listing, fabricate a publisher identity, upload a package, or obtain
the binding from a service. Obtaining a Town download and binding remains a
separate existing workflow; this feature removes the recipient's manual
`moonbook agent import-exact` and `verify-import` commands only.

Before import, inspect all included members and exclusions, private-content
labels, package identity, and the original listing/publisher/tenant binding.
The binding digest records a publisher-declared source expectation. It is not a
signature, factual review, execution permission, or new source-trust policy.
File selection sends the two files only to the configured Desk host for local
inspection. It does not import, run, or share the Book.

Choose a new folder in the active library and explicitly import. The configured
MoonBook executable must support `agent import-exact` and `agent verify-import`.
Older compatible executables can still use ordinary import. Exact import never
falls back to ordinary import, overwrites a destination, or replaces the binding.
The native Book importer checks the original package and binding again before
initializing a new Book.

Desk verifies current imported member bytes, the completed installation receipt,
and the exact portable-source receipt before enabling **Open Book**. Open checks
them again. Opening never starts packaged apps or agent work. In Town, refresh
**Imported outputs** using the same Books folder or a catalog containing the
imported Book; no upload or publication occurs automatically.

## Recovery

- Cancelling either selection starts no import. Before inspection, selected file
  bytes live only in this tab; navigation/reload asks for a fresh selection
- A destination collision leaves the inspected package available so another
  folder can be chosen
- After the explicit import starts, its durable reservation prevents repeated
  clicks, lost responses, or reload from launching the same import twice
- **Check import** rereads retained evidence and current files without importing
  again. A complete import whose response was lost can be opened after checking
- Missing/changed package, binding, members, or receipts remain unavailable or
  partial. An incomplete folder stays in place and is never silently replaced
- A different attempt can be started explicitly while retaining the earlier
  attempt for inspection. Browser recovery stores handles/digests, never package
  bytes, binding contents, or included private files

Qualification must distinguish pure state tests, fake-runner recovery tests,
actual MoonBook CLI pairing, browser interaction, and Town discovery. Passing
local tests does not qualify a deployed service or cross-machine sharing.
