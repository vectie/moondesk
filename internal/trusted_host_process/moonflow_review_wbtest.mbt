///|
test "fixed collaboration review bridge has no caller-controlled argv or membership action" {
  assert_eq(
    moonflow_review_arguments(
      "/suite/book",
      InspectReviewWorkspace(workspace_id="book"),
    ),
    Ok(["collaboration", "inspect", "/suite/book", "book"]),
  )
  let ref_ = ".moonsuite/products/moondesk/review-mutations/decision-1/mutation.json"
  assert_eq(
    moonflow_review_arguments(
      "/suite/book",
      BeginExistingReview(workspace_id="book", mutation_ref=ref_),
    ),
    Ok(["collaboration", "apply", "/suite/book", "book", "/suite/book/" + ref_]),
  )
  for
    path in [
      "/tmp/mutation.json", ".moonsuite/products/moondesk/review-mutations/../evil/mutation.json",
      ".moonsuite/products/moondesk/flow-plans/other.json",
    ] {
    assert_true(
      moonflow_review_arguments(
        "/suite/book",
        DecideExistingReview(workspace_id="book", mutation_ref=path),
      )
      is Err(_),
    )
  }
}
