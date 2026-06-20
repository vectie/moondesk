///|
test "event severity maps watcher decisions" {
  assert_eq(severity_for_decision("Failed"), "failure")
  assert_eq(severity_for_decision("NeedsReview"), "review")
  assert_eq(severity_for_decision("Update"), "success")
}
