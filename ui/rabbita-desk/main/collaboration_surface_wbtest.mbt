///|
test "owner handover catalog projects valid and quarantined records" {
  let snapshot : MoonFlowCollaborationSnapshot = {
    contract_id: "moonflow.collaboration-snapshot.v1",
    payload: {
      workspace_ref: {
        contract_id: "moonsuite.workspace-ref.v1",
        workspace_id: "book-a",
        revision: "1",
        digest: "sha256:" + "a".repeat(64),
      },
      memberships: [],
      assignments: [],
      claims: [],
      comments: [],
      reviews: [],
      events: [],
      head_digest: "sha256:" + "b".repeat(64),
    },
    content_digest: "sha256:" + "c".repeat(64),
  }
  let surface = collaboration_surface_from_snapshot(
    snapshot,
    Some({
      contract_id: "moonflow.handover-catalog.v1",
      handovers: [
        {
          handover_id: "ready-handover",
          state: "offered",
          head_digest: Some("sha256:" + "d".repeat(64)),
          envelope_digest: Some("sha256:" + "e".repeat(64)),
          valid: true,
        },
        {
          handover_id: "tampered-handover",
          state: "quarantined",
          head_digest: None,
          envelope_digest: None,
          valid: false,
        },
      ],
    }),
  )
  assert_eq(surface.handovers.length(), 2)
  assert_true(surface.handovers[0].valid)
  assert_false(surface.handovers[1].valid)
  assert_eq(surface.handovers[1].state, "quarantined")
}

///|
test "owner collaboration recovery reply decodes without a snapshot" {
  let reply : MoonFlowCollaborationReply = @json.from_json({
    "workspace_id": "book-a",
    "source_contract": "moonflow.collaboration-snapshot.v1",
    "ok": false,
    "status": "not_initialized",
    "message": "Collaboration has not been initialized for this MoonBook",
    "next_action": "initialize_in_moonflow",
  })
  assert_false(reply.ok)
  assert_eq(reply.status, "not_initialized")
  assert_true(reply.snapshot is None)
  assert_true(reply.handover_catalog is None)
}
