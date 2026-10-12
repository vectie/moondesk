# Existing exact-result collaboration review

Open a supported retained single-step Mold artifact in Desk, then choose
**Open existing exact-result review**. Desk asks the native Flow collaboration
reader for existing reviews whose subject is precisely the selected artifact's
file-byte SHA-256. Choose a matching review, begin it, and record **Approved**
or **Changes requested** with notes. Reopening reads the durable Flow decision
and verifies the content-addressed notes again.

This is a collaboration decision only. It does not produce `FlowItemAccepted`,
customer acceptance, a new authority grant, or execution of any dependent item.
The generic `review-outcome` operator action is not used. Existing Flow policy
and its process-locked atomic collaboration snapshot writer remain authoritative.

## Identity and deployment prerequisite

Desk reuses its existing host-configured identity verification seam:
`MOONDESK_IDENTITY_ENDPOINT` / `MOONDESK_IDENTITY_HOST`, cookie session lookup,
then `/v1/auth/self`. Ordinary public access retains the existing active
PlatformOperator check. Reviews also require an active account identity and a
host-owned `MOONDESK_REVIEW_PRINCIPAL_MAP` file. Nothing in a browser request
can supply a principal, role, membership, command or grant.

The mapping file uses contract `moondesk.review-principal-map.v1`, the exact
`identity_endpoint`, and `bindings` containing `account_id`, `subject_ref`,
`workspace_id`, and the complete existing MoonLib `principal` reference.
Only one exact account/subject/Book binding may match. The mapped principal
must be human, the active existing Reviewer, the assigned reviewer, and
different from the submitter. Mapping does not create or promote a member.

No production principal mapping is supplied or claimed by this change.
Gateway-only deployments that do not expose a verified account identity to
Desk remain explicitly unavailable for decisions. A gateway flag, loopback
Host, browser actor field or claimed role is not an authenticated human.
Verification uses a loopback synthetic identity service and synthetic
collaboration memberships only. No live identity request or credential setup
is needed to run those fixtures. Cookies and session tokens are never written
to decision evidence or verification output.

## Bounded routes and persistence

- `GET` / `HEAD` on the existing retained identity route plus `/review`
- `POST /api/moonflow/review` accepts only retained `identity`, `sha256`,
  `record_digest`, `review_id`, `expected_head`, `mutation_id`, `action`, `notes`
- Actions are `begin`, `approved`, or `changes-requested`; decisions require
  nonempty notes, at most 16 Ki UTF-16 code units

Submit rechecks the retained result protocol, all companion artifact bytes,
the selected file-byte digest, the observation-record seal, existing review
subject, independently authenticated reviewer membership, and current head.
Flow checks the expected head again under its own cross-process writer lock.
Desk's trusted host bridge only exposes inspection, begin-review and
decision variants, with fixed CLI argument vectors and a stamped executable.

Notes are immutable, content-addressed JSON beneath the selected Book's
`.moonsuite/products/moondesk/review-evidence/`. The original bounded request,
host actor, timestamp, expected head and typed mutation are retained once per
mutation ID. Reusing an ID with different contents is refused. Retries use the
original envelope and timestamp, so Flow can recognize its exact replay.
After submission, Desk makes a fresh validated Flow read and checks the
mutation's canonical payload digest and exact decision evidence. An action
response string is never sufficient proof of a decision.

The UI persists an in-flight mutation before sending HTTP. Duplicate clicks
are disabled; lost acknowledgments can retry the original identity. Selection,
Book, run refresh, close, timeout and newer request generations prevent late
callbacks from replacing the current selection. Notes render as escaped text.
Inspection requests also have a bounded UI timeout. A confirmed stale-head
rejection retires only the exact echoed original request: Flow's validated
append-only head must have advanced and contain no event for that mutation ID.
It therefore cannot apply later at the old expected head. Reopen preserves the
authored notes, reads the new head, and allows a new explicit decision. Other
errors and uncertain acknowledgments never discard the in-flight request.

## Evidence boundary

Artifact review retains R34's `fixture-reference-only`, digital-only boundary.
The byte identity of a Mold artifact differs from its embedded semantic digest.
An existing review must match the former. This does not establish production
Mold/Blender qualification or physical authority. External review evidence is
identified explicitly rather than interpreted as Desk notes.
