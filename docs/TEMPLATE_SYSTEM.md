# MoonSuite template system

MoonDesk presents templates but does not own their domain meaning. An owning
pack publishes a catalog, MoonDesk verifies and renders its generic envelope,
and the owner confirms inputs before it creates an instance. This keeps
Moonfish finance policy, MoonCast production policy, MoonTown civic policy,
and MoonFind research policy out of MoonDesk.

## Frozen wire contracts

- `moonsuite.template-envelope.v1` describes one reusable outcome and pins its
  owner, version, source path, and SHA-256 digest.
- `moonsuite.template-catalog.v1` is an owner-authored list of envelopes.
- `moonsuite.template-instance.v1` pins the chosen envelope and input digest,
  while leaving `owner_payload` opaque to MoonDesk.

The normative JSON Schemas live in `schemas/moonsuite-template-*.schema.json`.
An envelope exposes only generic presentation and control facts: class,
maturity, user outcome, typed operation/schema requirements, authority and
external-effect ceilings, cost status, licensing status, review gates, and a
recoverable blocker. `owner_payload` is never interpreted by the host.

Maturity is evidence-based and independent of execution readiness:

1. `fixture` — deterministic sample evidence only;
2. `local-qualified` — the owner has passed its bounded local qualification;
3. `live-qualified` — real adapters/providers have passed owner acceptance;
4. `production` — the owner has passed its published operational gate.

`recovery.blocked` says whether this particular template can proceed now. A
locally qualified template can therefore remain correctly blocked on a missing
cross-product capability.

## Discovery and launch

An installed pack declares one or more `template_catalogs` in `pack.json`.
MoonDesk accepts an envelope only when:

- the catalog and envelope contract IDs and declared owner match;
- catalog, template, version, path, and digest fields are safe;
- the source path resolves below the installed pack root; and
- the SHA-256 of that exact source equals `source_digest`.

The catalog digest binds the complete catalog, including titles and ceilings:
hash the exact UTF-8 catalog file after replacing its single
`catalog_digest` value with `sha256:` plus 64 zeroes. MoonDesk rejects a
catalog whose declared digest does not match that canonicalized byte stream.
The v1 template definition identity is deliberately composite rather than an
ambiguous second digest: `catalog_id + catalog_version + catalog_digest +
template_id + template version`. `source_digest` is separate and binds only the
owner workflow/source bytes. Owners must match the complete composite and the
source digest before selecting a preview or creating an instance.

The **New from template** surface shows the completion boundary and ceilings
before launch. Its action opens the owning pack with `template`,
`template_version`, `template_catalog`, `template_catalog_version`,
`template_catalog_digest`, and `template_source_digest`. The catalog digest
binds the full template definition; the source digest independently binds the
owner workflow or source bytes. If the owner runtime is not safely configured
or is offline, the action is disabled and MoonDesk gives one
recovery: start/configure the owner and refresh. MoonDesk does not synthesize a
success receipt.

Pack entrypoint paths remain query-free. Optional launch context is declared in
the generic `moonsuite.pack-presentation.v1` metadata as strict key/value
tokens; MoonDesk appends it only to its same-origin launch URL. It never weakens
route or upstream URL validation.

## Instance boundary

Opening an owner is not instance creation. The owner must validate its opaque
payload and user inputs, then persist a `moonsuite.template-instance.v1` with:

- immutable template ID, owner, version, catalog identity/digest, and source
  digest;
- a digest of accepted inputs;
- lifecycle status and owner launch coordinates;
- explicit authority grants, evidence references, and review references.

No pack may infer authority from template selection. Publication, spend,
trading, physical actions, and other external effects remain separately
authorized.

The current MoonTown and MoonFind integrations stop at a pinned owner preview.
They do not yet persist `moonsuite.template-instance.v1` or start the owner
workflow from that preview. MoonDesk therefore labels the action **Review in
owner**, never **Start**, and the missing owner-confirm/create transition is a
known implementation boundary rather than an implied success.

## Current honest catalog

The first slice exposes six MoonTown-owned civic scenarios and MoonFind's
locally qualified Lunar Habitat Decision Series. The Lunar series remains
blocked on its documented missing MoonCast operation and MoonFlow binding
seams; selection opens inspection and makes no execution claim.

Moonfish and MoonCast templates are intentionally absent until those owners
publish catalogs. MoonTown and MoonDesk must not author substitute finance or
AIGC semantics.

## Town ownership boundary

MoonDesk verifies `moontown.api.v1` before reading or mutating Town state. The
exercised request and automation paths call MoonTown's
`/api/operator-requests` and `/api/standing-goals` endpoints. If the owner is
unavailable, MoonDesk returns a recoverable service error. It no longer writes
a second Town request or standing-goal ledger in those paths.

## Collaboration and handover seam

The Packs home includes a generic, read-only collaboration surface. It accepts
only adapter-validated MoonLib references such as
`moonsuite.principal-ref.v1`, `moonsuite.workspace-ref.v1`,
`moonsuite.operation-ref.v1`, and `moonsuite.handover-control.v1`. It does not
infer collaborators from a pack's domain records and it does not mutate shared
work.

The implemented MoonFlow adapter projects validated people, assignments,
anchored comments, and independent reviews. It also asks the owner CLI for the
discoverable `moonflow.handover-catalog.v1` and shows each handover ID, state,
head digest, envelope digest, and validity. A damaged handover remains visible
as `quarantined`; MoonDesk never turns it into a valid or empty record.
Delegation, detailed handover inspection, fresh authority, conflict resolution,
mutation, and continuation remain owned by MoonFlow and the domain product.

MoonDesk obtains collaboration only through MoonFlow's owner decoder:
`moonflow collaboration inspect <workspace> <workspace-id>`. The host endpoint
never parses an unvalidated snapshot fallback. A missing snapshot is shown as
not initialized, an owner validation failure is quarantined, and an unavailable
MoonFlow runtime remains a recoverable unavailable state. After collaboration
validation succeeds, MoonDesk obtains handover discovery through
`moonflow handover list <workspace>`; full handover state is intentionally not
duplicated into the MoonDesk contract. Mutations stay in MoonFlow.
