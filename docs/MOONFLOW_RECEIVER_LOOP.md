# MoonFlow Receiver Loop In MoonDesk

MoonDesk is the local transport and visible operator projection for MoonFlow’s
generic pack receiver loop. It does not execute product logic and does not own
an agent runtime.

For a `moonflow.operator-actions.v2` action, MoonDesk:

1. validates the opaque token, digest, run, Work-item, operation, evidence,
   authority, review, and handoff-file correlation;
2. resolves the published `pack_id` through the installed pack manifest and
   safe local app-runtime record;
3. enables the app link only when that entrypoint resolves exactly;
4. serves same-origin intake, status, and receipt endpoints;
5. invokes MoonFlow’s existing CLI to reconcile a returned receipt;
6. projects `pending`, `accepted`, or `denied` in the Flow action queue;
7. restores the projection from durable handoff and receipt records after
   reload or restart.

The receiver endpoints are:

```text
GET  /api/moonflow/runs/<run-id>/handoffs/<token>
GET  /api/moonflow/runs/<run-id>/handoffs/<token>/status
POST /api/moonflow/runs/<run-id>/handoffs/<token>/receipt
```

The browser launch URL contains only `moonflow_run` and the opaque
`moonflow_handoff` token. It never contains host configuration, authority
secrets, arbitrary filesystem paths, or a receiver-supplied callback URL.

The canonical handoff and receipt schemas, reconciliation rules, replay
behavior, and receiver implementation checklist live in MoonFlow’s
`docs/OPERATOR_RECEIVER_LOOP.md`.

Missing manifests, unsafe runtimes, changed payload digests, identity
mismatches, different receipt bytes for an existing token, received-journal
recovery failures, and workspace-escaping artifact paths remain disabled or
return an explicit error. MoonDesk never falls back to the Packs screen and
never marks the Work item complete itself.
