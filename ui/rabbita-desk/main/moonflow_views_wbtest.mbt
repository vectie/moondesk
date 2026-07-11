///|
fn flow_test_item(status : String) -> MoonFlowItemProjection {
  {
    work_item_id: "work-research",
    declaration_id: "research",
    product_id: "moonwiki",
    requested_authority: "observe",
    acceptance_criteria: ["reviewed evidence is attached"],
    depends_on: [],
    status,
    attempt_count: if status == "ready" {
      0
    } else {
      1
    },
    request_id: if status == "ready" {
      ""
    } else {
      "request-r1"
    },
    result_id: if status == "review" {
      "result-r1"
    } else {
      ""
    },
    active_attempt_id: if status == "ready" {
      ""
    } else {
      "attempt-r1"
    },
    idempotency_key: if status == "ready" {
      ""
    } else {
      "key-r1"
    },
    external_job_id: if status == "review" {
      "wiki-job-r1"
    } else {
      ""
    },
    attempt_status: if status == "review" {
      "succeeded"
    } else {
      status
    },
    input_digest: if status == "ready" {
      ""
    } else {
      "sha256:input"
    },
    output_digest: if status == "review" {
      "sha256:output"
    } else {
      ""
    },
    error_kind: "",
    compensable: status == "review",
    blocker: if status == "blocked" {
      "reconciliation required"
    } else {
      ""
    },
    artifacts: if status == "review" {
      ["artifact://research"]
    } else {
      []
    },
    approvals: [],
  }
}

///|
fn flow_test_run(
  outcome : String,
  item_status : String,
) -> MoonFlowRunProjection {
  {
    protocol: "moonflow.run-projection.v2",
    run_id: "flow-r1",
    book_id: "book-r1",
    declaration_revision: "r1",
    source_digest: "sha256:source",
    last_sequence: 5,
    outcome,
    runnable_item_ids: if item_status == "ready" {
      ["work-research"]
    } else {
      []
    },
    items: [flow_test_item(item_status)],
  }
}

///|
test "MoonFlow state does not present active outcome as complete" {
  assert_eq(
    moonflow_run_state(flow_test_run("active", "active")),
    "in-progress",
  )
  assert_eq(
    moonflow_run_state(flow_test_run("accepted", "accepted")),
    "complete",
  )
}

///|
test "MoonFlow next action distinguishes execution success from acceptance" {
  assert_true(
    moonflow_next_action_label(flow_test_run("review", "review")).contains(
      "acceptance criterion",
    ),
  )
  assert_true(
    moonflow_next_action_label(flow_test_run("ready", "ready")).contains(
      "governed product adapter",
    ),
  )
  assert_true(
    moonflow_next_action_label(flow_test_run("blocked", "blocked")).contains(
      "without weakening",
    ),
  )
}
