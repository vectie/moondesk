# Phase 5 security evidence

Phase 5 remains inside MoonDesk's existing product boundary and preserves the
primary navigation **Desk / Wiki / Code / Flow / Packs**.

## Enforced boundaries

- `internal/fsx/confined_io.mbt` is the narrow native confinement API. Reads
  canonicalize root and target and perform IO on the canonical target. Writes
  reject absolute/parent traversal, canonicalize the nearest existing parent,
  create descendants only below that ancestor, and refuse final symlinks.
- Workspace read and write handlers use the confined resolver at actual route
  boundaries. The special MoonClaw projection retains its separate product-home
  authority root.
- Archive extraction is intentionally unsupported. The actual workspace import
  boundary rejects `archive_entries` before any write and returns
  `moondesk.archive-import-receipt.v1`, including accepted/rejected/quarantined
  entries, staging requirement, refusal-to-overwrite policy, and promotion
  policy. Thus no archive entry is extracted outside staging—or at all.
- Generated HTML, SVG, and JavaScript use an opaque sandbox without
  `allow-same-origin`; CSP denies network, forms, objects, base URLs, and
  ambient application-origin authority. Cache, referrer, MIME-sniffing, and
  permissions policies remain restrictive.
- The canonical desktop route table publishes `authority_scope` for every
  route. The owning test fails if a route with POST/PUT/PATCH/DELETE is left
  `read-only` or empty.
- MoonFlow operator actions preserve the existing typed runtime receipt payload
  and persist its sanitized JSON beneath the run root through confined IO
  before returning it. Existing lifecycle controls retain their durable status
  and policy records.

## Gate commands

The Phase 5 security job in `.github/workflows/ci.yml` runs confined IO,
preview, archive/import, browser-origin, route-authority, and desktop-receipt
tests before the existing full repository validation. Local closure also uses
`moon check`, owning tests, `moon info` interface review, `moon fmt`,
`git diff --check`, and `scripts/validate.sh full`.
