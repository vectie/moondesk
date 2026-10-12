# Declared plan preparation in Desk

Desk's Flow editor now has a direct, non-executing preparation and import path:

1. Select a Book with `flow/work-graph.json` and a conformant capability catalog
2. Edit input artifact paths, dependency IDs, acceptance criteria, and timeout
3. Save incomplete fields locally, or select **Prepare child plan**
4. Review field changes, the child/source identities, input-capture limits, and checkpoint migration decisions
5. Explicitly select **Import this child plan** or **Import this reviewed revision**
6. Desk reloads the retained result and refreshes the Flow run projection, prioritizing the imported child in this view

No form download, manual CLI invocation, product dispatch, or execution approval is part of this journey.

## Host boundary

The POST-only `/api/moonflow/plans` endpoint accepts `prepare`, `inspect`, or `apply`, the selected `workspace_id`, a bounded `request_id`, and (for preparation) the portable form. The host resolves the selected Book and catalog, compares the full source graph, and supplies the canonical source reference itself. Sources must be inside the suite's Flow workspace. Client paths never choose the executable, catalog, source path, or command.

`internal/trusted_host_process/moonflow_planning.mbt` exposes only two fixed native operations:

- `plan prepare-form <workspace> <form-ref> <catalog-ref> <draft-id> <recorded-at>`
- `plan apply-prepared <workspace> <preparation-id> <catalog-ref> <evaluated-at>`

The host selects `MOONDESK_MOONFLOW_BIN`, or the fixed release binary below `MOONFLOW_ROOT`, from its own configuration. It checks canonical regular executable identity and advertised command compatibility. Execution has closed stdin, no inherited environment, no credential/config search paths, a 60-second deadline, concurrently drained bounded output, and hard cancellation. There is no shell, runtime compilation, arbitrary argv, or generic executor fallback. `execution_sandbox_client` remains deny-only.

The host retains request, form, catalog, native preparation receipt, and apply receipt under `.moonsuite/products/moondesk/flow-plans/desk-<request-id>/`. Existing evidence is never overwritten with different content. Same-request transport retries are idempotent. A fresh preparation receives a new request identity.

Flow's native preparation/apply implementation owns input capture, immutable child graph/proposal, capability health validation, parent/checkpoint consistency, supported import/revision persistence, and writer locking. The selected Book graph and parent events/projection remain unchanged. Neither preparation nor import submits an attempt.

## Input capture limits

The receipt reports exact captured input bytes and supported spatial reference captures. Runtime/product state is not frozen. Opaque contracts retain their original bindings and are revalidated at apply; unknown nested dependencies are not captured. Desk shows these limitations next to the review actions and does not promise reproducible execution. Raw native evidence is inside a collapsed technical-details disclosure.

## Recovery and stale state

- Source graph or catalog drift blocks import while retaining the prepared packet
- Expired health, missing/changed evidence, or changed checkpoint eligibility is rejected by Flow before import
- Failed source refresh retains edited fields and blocks prepare/import until the source is confirmed again
- Book switches, closed views, edits, and request generations fence stale responses
- Duplicate button clicks cannot launch a second in-flight request
- Request identity is saved locally before submission; reopening requires **Reload prepared result** before import
- A failed result refresh disables import, preserves the draft/evidence, and offers reload
- Closing while an import is in flight does not claim to cancel the import; the user is directed to reload its result before retrying
- Failed run-list refresh retains the successful import receipt without pretending the independent observation succeeded

## Tests

The JS suite exercises the actual form builder, controller, rendered controls, local draft persistence, stale Book/source/save paths, cycles, field errors, duplicate clicks, late responses, close/reopen, timeout, explicit import, and failed refresh. A captured production-controller request is used by `moonflow_plan_native_wbtest.mbt` against the actual configured native Flow executable and the production Desk host implementation.

The native crossing is opt-in through `MOONDESK_FLOW_PLAN_UI_REQUEST`, `MOONDESK_FLOW_PLAN_FIXTURE`, and `MOONDESK_MOONFLOW_BIN`; it prints an explicit not-configured marker when those fixtures are absent. `MOONDESK_FLOW_PLAN_EVALUATED_AT` supplies the synthetic catalog evaluation time. The crossing covers preparation, new import, parent revision, repeated import, result reload, exact parent/source preservation, and zero attempts. It performs only local synthetic operations, with no live browser, provider, credentials, hardware, or user-computer access.
