# One imported digital Mold step

Desk provides a separate, bounded path from an imported Flow item to native
digital Mold execution. Select a Book, open its imported run, select an item,
then choose **Run this digital step**. Only a ready item with the exact
`moonmold-pack-local-v1` adapter, `moonmold/spatial.operation.execute@0.2.0`
operation, `workspace-mutation` authority and `digital-artifact` claim is eligible.

The normal result stops at **Review**. Review remains a separate explicit
decision; this path never dispatches a reviewer, observer or dependent item.
Native Mold evidence is displayed as **fixture-reference-only**, with
`production_qualified=false` and `physical_authority=false`. This does not qualify
Blender, production work, physical equipment, or any robot.

## Trusted host setup

The Desk host administrator configures:

- `MOONDESK_MOONFLOW_BIN`: canonical absolute native Flow executable
- `MOONDESK_MOONFLOW_SINGLE_STEP_CONFIG`: workspace-relative, host-owned
  `moonflow.single-step-config.v1` configuration

The configuration contains `capability_ref`, `envelope_ref`, `usage_ref`,
`gate_executable`, `gate_sha256`, `mold_executable` and `mold_sha256`.
Executable identities and paths are checked by Flow. The existing Gate authority
must match the workspace, run source, exact operation and bounded paths, and
remain unexpired and unrevoked. Fresh conformant catalog and hashed health
evidence are required. No authority grant is created by Desk.

Desk's dedicated typed process bridge verifies/stamps the configured Flow
executable and allows only `execute-one` and `reconcile-one` argument shapes.
It uses the existing bounded process capture with a stripped environment. It
does not change the generic deny-only executor or declared-plan preparation.

## Request and recovery

`POST /api/moonflow/single-step` accepts exactly `workspace_id`, `run_id`,
`work_item_id`, `request_id` and `action` (`execute` or `reconcile`). The host
resolves the Book from its registry, derives the suite workspace, confines the
Book and run paths, and verifies the imported run's Book before invoking Flow.
The browser cannot supply an executable, configuration, authority, envelope,
arbitrary path or argument vector.

The browser persists an action identity before sending. Repeated clicks remain
disabled while pending. Flow persists its own action record before submission,
serializes workspace mutations and deduplicates the action. Desk run responses
expose only the record's item ID, browser action ID, status and message, never
the adapter request body. Records can restore an action on reload or another
browser, even without local storage.

A timeout or lost response shows **Reconcile same attempt**. Book/item changes
and older replies cannot overwrite the newly selected action. Reconciliation
retains the original ID and never reruns Mold; even `not-applied` is terminal for
this route. A host setup error is shown with its specific configuration blocker.
Local storage failure blocks initial dispatch rather than allowing an untracked
request.

A setup failure can be retried with the same ID only when Flow returns a
correlated `moonflow.single-step-blocker.v1` and proves under its lock that no
action or attempt was created. Other errors are outcome-unknown. A persisted
server action supersedes a losing tab's local ID only for reconciliation of
that exact Book/run/item.

## Qualification evidence

`moonflow_single_step_wbtest.mbt` covers fixed arguments, rejected browser
configuration, Book/run correlation, safe action projection, lost/malformed
results, saved identity, duplicate clicks, reload, item/Book changes, stale
responses, cross-tab recovery and storage failure.

The opt-in native HTTP test consumes a payload emitted by the compiled
production UI (`MOONDESK_FLOW_STEP_UI_REQUEST`) and an imported fixture workspace
(`MOONDESK_FLOW_STEP_FIXTURE`). It starts the production Desk server and exercises
POST body parsing, Book discovery, the typed bridge and a GET run reload. It
checks missing configuration followed by repair and same-ID execution. The
compiled UI then receives a simulated lost browser response and the actual
HTTP reconciliation result. One selected item reaches Review, all other items
have zero attempts, and duplicate/reconcile calls leave events unchanged.
`MOONDESK_FLOW_STEP_EVIDENCE` optionally records the result for UI rendering tests.
Without these variables the crossing is explicitly reported as unconfigured.
