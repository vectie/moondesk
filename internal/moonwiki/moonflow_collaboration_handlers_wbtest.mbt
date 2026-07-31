///|
test "collaboration inspection delegates validation to the MoonFlow owner CLI" {
  assert_eq(
    moonflow_collaboration_inspect_arguments(
      "/suite/moonflow",
      "/suite/books/research",
      "book-research",
    ),
    [
      "-C",
      "/suite/moonflow",
      "run",
      "cmd/main",
      "--",
      "collaboration",
      "inspect",
      "/suite/books/research",
      "book-research",
    ],
  )
  assert_eq(
    moonflow_collaboration_snapshot_path(
      "/suite/books/research",
      "book-research",
    ),
    "/suite/books/research/.moonsuite/products/moonflow/collaboration/book-research.json",
  )
  assert_eq(
    moonflow_handover_list_arguments(
      "/suite/moonflow",
      "/suite/books/research",
    ),
    [
      "-C",
      "/suite/moonflow",
      "run",
      "cmd/main",
      "--",
      "handover",
      "list",
      "/suite/books/research",
    ],
  )
}

///|
test "handover catalog rejects missing digests and preserves quarantine" {
  let digest = "sha256:" + "a".repeat(64)
  assert_true(
    moonflow_handover_catalog_valid({
      "contract_id": "moonflow.handover-catalog.v1",
      "handovers": [
        {
          "handover_id": "handover-ready",
          "state": "offered",
          "head_digest": digest,
          "envelope_digest": digest,
          "valid": true,
        },
        {
          "handover_id": "handover-tampered",
          "state": "quarantined",
          "valid": false,
        },
      ],
    }),
  )
  assert_false(
    moonflow_handover_catalog_valid({
      "contract_id": "moonflow.handover-catalog.v1",
      "handovers": [
        {
          "handover_id": "handover-missing-digest",
          "state": "offered",
          "valid": true,
        },
      ],
    }),
  )
}

///|
test "collaboration recovery reply omits unavailable typed projections" {
  let reply = moonflow_collaboration_reply(
    "book-research",
    None,
    false,
    "not_initialized",
    "Collaboration has not been initialized",
    "initialize_in_moonflow",
  )
  assert_true(json_object_field(reply, "snapshot") is None)
  assert_true(json_object_field(reply, "handover_catalog") is None)
  assert_eq(json_string(reply, "status", default=""), "not_initialized")
}
