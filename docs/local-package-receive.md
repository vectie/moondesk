# Receive a local Book package

In **Home → Add MoonBook → Import a Book package**:

1. Choose one `.moonbook-agent` file
2. Review all included files, sensitivity labels, exclusions and package policies
3. Enter a new folder name in the active library
4. Select **Import into this library**
5. Select **Open Book** after every included file has been verified

Folder and `.zip` imports keep their existing behavior. A package selection only
stages and inspects bytes; it does not create a Book. Importing does not start
agents, run packaged apps, request providers or create a Town binding.

## Recovery

An interrupted response shows **Check import**. This rereads the saved operation
and verifies current destination members. It never repeats the import command.
A partial destination remains in place and is not opened or overwritten.

**Keep this attempt and start another** retains the failed attempt and its
destination, then lets the user explicitly select another package. Earlier
attempts remain available for read-only recovery in the same library. Changing
libraries or navigating invalidates pending callbacks. Minimal operation handles
and the reviewed package digest are retained in browser storage for reload
recovery; package contents and member lists are not stored there.

Browser storage availability is required to rediscover those handles after a
reload. Server-side staged files and import reservations are retained even when
browser storage is unavailable. Nothing is automatically deleted or retried.

## Local API

- `POST /api/agent-import`: stage `{operation_id, expected_library, filename, data_url}`
- `GET /api/agent-import/{operation_id}?expected_library=...`: inspect or recover
- `POST /api/agent-import/{operation_id}`: explicit import `{operation_id, expected_library, destination_folder, package_sha256}`

The active server-owned library, operation ID, immutable package identity and
destination reservation are checked before the single import invocation. The
MoonBook executable is selected by the trusted host and must support
`agent import <bundle> <new-book> [source.json]` and
`agent verify-import <bundle> <book>`. The existing exporter remains compatible
with older export-only executables.

The importer validates one package snapshot against the reviewed PortableSource
before creating the destination. It preserves included metadata and member bytes;
when a package contains no Book metadata, ordinary Book initialization supplies
local metadata. The imported workspace ID comes from its destination folder;
the reviewed source identity is retained separately. No imported Book is renamed.

Only a matching ordinary import receipt, canonical member paths and a successful
current `verify-import` result produce an `imported` response and enable opening.
Technical receipt identifiers and digests are collapsed in the UI; contents,
privacy information, errors and the next action remain visible.
