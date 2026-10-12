# Retained single-step result inspection

Desk can inspect and download the already retained result of the existing native
Flow single-step Mold operation. Click a retained artifact in the next-action
evidence card or selected digital-step panel. The inspection shows the selected
Book, run, item, attempt, result, user action and adapter request before the
bounded escaped preview and exact download.

This route never edits a file, appends an event, decides a review, executes an
operation, reconciles an attempt, or starts dependent work. Inspection state is
not restored from browser storage. Reopening after refresh checks the host
again. Book/item changes, run refresh, Close and newer selections invalidate
earlier callbacks and download controls.

## Identity boundary

The read-only GET/HEAD route is:

`/api/moonflow/retained/{workspace}/{run}/{item}/{attempt}/{result}/{action}/{ordinal}`

The host resolves the registered Book and suite root. All output locations come
from the correlated persisted Flow result, never a browser path or an operator
projection locator. The host compares the projection and event head, the selected
item, single-step action, exact retained adapter request, request index, result,
terminal event and per-file evidence manifest. Only the exact operation
`moonmold/spatial.operation.execute@0.2.0` with its existing single-step contracts
is supported. Other locator/protocol families remain explicitly unavailable.

The adapter `output_digest` hashes ONLY `operation-receipt.json`. Desk labels
that verification **Adapter receipt byte identity**. Other result files are
checked against `single-step/{item}.evidence.json` reference, SHA-256 and byte
length observations and labeled **Flow-recorded artifact byte identity**.
An embedded Mold artifact JSON `digest` represents semantic content and is not
used as a file-byte checksum. These observations are not signatures: the
existing protocol does not independently authenticate a coherently rewritten
set of trusted host records.

Every output is checked, not only the clicked output. The host uses anchored
descriptor-relative no-follow opens, rejects symlinks, FIFOs and nonregular
files, and checks the opened inode, size and timestamps around the read. Reads
use the POSIX host implementation; other native platforms fail closed as
unsupported. Linux is the verified platform for this change. Reads
are limited to 4 MiB per file, 64 outputs and 16 MiB total output bytes. Each
record is bounded at 4 MiB. Missing, changed, unsafe, unsupported or oversized
evidence has an explicit unavailable response.

The preview contains at most 32,768 UTF-16 code units of escaped text/JSON.
Non-UTF-8 or NUL-containing data receives a binary-content notice. Download is
`application/octet-stream`, `attachment`, `no-store`, and `nosniff`; it returns
the original bytes without decoding, pretty-printing or newline conversion.
Its URL appends `/download/{file-sha256-hex}-{record-observation-sha256-hex}`.
The host rechecks all correlations and bytes, then requires both the selected
file digest and the exact inspection-record digest to match. A stale download
receives HTTP 409 without artifact bytes.

## Qualification

The supported native adapter remains `fixture-reference-only`, with
`production_qualified=false`, `blender_evidence=false` and
`physical_authority=false`. A successful digital operation still stops at Review.
Reading or downloading evidence never changes that boundary.

Focused native tests exercise the actual native Flow/Gate/Mold export fixture,
both identity labels, artifact semantic-digest separation, real local HTTP and
ordinary served compiled Desk assets, byte-exact downloads, record pinning,
binary transfer, missing/tampered files, evidence-manifest mismatch, wrong
identities, unsupported operation versions, symlinks, FIFOs and bounds. A
before/after snapshot checks all canonical Flow and Mold files, including
events, actions, request/result/evidence records, review fields and attempts.
Compiled UI tests consume the actual HTTP evidence and verify selection,
escaping, download identities, Close/reload/refresh/late callback handling.

Native fixture tests require `MOONDESK_RETAINED_FIXTURE`,
`MOONDESK_RETAINED_HTTP_EVIDENCE`, and `MOONDESK_RETAINED_UI_DIST`.
The compiled UI crossing uses `MOONDESK_RETAINED_HTTP_EVIDENCE`.
Without these, the tests print an explicit `NOT_CONFIGURED` marker; that is not
native protocol or HTTP qualification.
