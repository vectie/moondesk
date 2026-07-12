///|
fn flow_test_item(status : String) -> MoonFlowItemProjection {
  {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    acceptance_criteria: ["sources are reviewed"],
    depends_on: [],
    status,
    attempt_count: 1,
    attempt_status: "completed",
    operation: "research",
    input_digest: "input-digest",
    output_digest: "output-digest",
    error_kind: "",
    compensable: false,
    blocker: "",
    acceptance_review_id: "review-1",
    acceptance_review_artifact: "evidence/review.json",
    acceptance_reviewer_id: "reviewer-1",
    artifacts: ["evidence/research.json"],
    approvals: ["reviewer-1"],
  }
}

///|
test "Flow explains governed readiness and acceptance" {
  assert_eq(
    moonflow_item_explanation(flow_test_item("ready")),
    "Dependencies are accepted; the declared product may execute now",
  )
  assert_eq(
    moonflow_item_explanation(flow_test_item("accepted")),
    "Accepted by explicit review with bound output evidence",
  )
}

///|
test "Flow exposes failure reasons instead of a status-only dead end" {
  let blocked = { ..flow_test_item("blocked"), blocker: "source missing" }
  assert_eq(moonflow_item_explanation(blocked), "source missing")
  let failed = {
    ..flow_test_item("failed"),
    acceptance_review_id: "",
    blocker: "",
    error_kind: "tool-timeout",
  }
  assert_eq(
    moonflow_item_explanation(failed),
    "Execution reported tool-timeout",
  )
}
