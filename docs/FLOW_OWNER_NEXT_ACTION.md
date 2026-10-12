# Flow owner next action

The existing Flow run card consumes the engine's `moonflow.owner-summary.v1`
payload. The title says what needs doing next. Item disclosures retain ordered
reasons, unknown owners, exact artifacts and existing item diagnostics. Existing
actions and controls remain in an adjacent disclosure; no execution permissions
or mutation route is added.

This requires the paired MoonFlow producer update. Older producers still load,
but the compact owner card says that a matching summary is unavailable and
retains detailed run evidence. A producer's next actor remains unknown unless
the versioned contract actually records one. The current v1 producer never
invents a person from product IDs, approval authorities or earlier reviewers.

The host checks the retained summary's revision and event head when it reads a
run. The UI verifies summary/run/item identity and requires that host observation.
Loading, failed refresh, mismatched event heads, missing/future summaries and
child revisions cannot show the old owner-level completion claim. Refresh
responses are generation/workspace-bound and lower event heads are rejected.

Internal acceptance is not customer approval, delivery acceptance or payment.
An unknown attempt says to reconcile before retry; a failure asks for a governed
recovery decision. Recorded roles are descriptive, not assignments or authority.

Artifact references remain exact text because the run store uses suite-relative
references and the existing workspace artifact URL is a different namespace.
No unverified links or new artifact-access permissions are generated. The card
is an observation of a known event head, not a wall-clock/live-status guarantee.

Validation includes real native CLI-generated fixtures decoded and rendered by
the JS UI, host event-head mismatch checks, read-only CLI filesystem checks and
out-of-order refresh/workspace tests. Browser interaction, Mac integration and
provider effects remain unqualified by this cloud-only change.
