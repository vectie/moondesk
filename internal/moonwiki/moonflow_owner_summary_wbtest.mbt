///|
test "owner host verifies seven real CLI heads without rewriting their summaries" {
  for
    (projection, events) in [
      (owner_cli_ready_projection(), owner_cli_ready_events()),
      (owner_cli_waiting_projection(), owner_cli_waiting_events()),
      (owner_cli_review_projection(), owner_cli_review_events()),
      (owner_cli_failed_projection(), owner_cli_failed_events()),
      (owner_cli_unknown_projection(), owner_cli_unknown_events()),
      (owner_cli_accepted_projection(), owner_cli_accepted_events()),
      (owner_cli_child_projection(), owner_cli_child_events()),
    ] {
    let before = projection.stringify()
    assert_eq(
      moonflow_owner_summary_observation(projection, Some(events)),
      "event-head-matched",
    )
    assert_eq(projection.stringify(), before)
  }
}

///|
test "owner host refuses unavailable truncated older different and malformed event observations" {
  let accepted = owner_cli_accepted_projection()
  assert_eq(
    moonflow_owner_summary_observation(accepted, None),
    "events-unavailable",
  )
  assert_eq(
    moonflow_owner_summary_observation(accepted, Some([])),
    "events-unavailable",
  )
  assert_eq(
    moonflow_owner_summary_observation(accepted, Some(owner_cli_ready_events())),
    "event-head-mismatch",
  )
  assert_eq(
    moonflow_owner_summary_observation(accepted, Some(owner_cli_child_events())),
    "event-head-mismatch",
  )
  let changed = owner_cli_accepted_events()
  guard changed is Array(events) && events[1] is Object(fields) else {
    fail("fixture")
  }
  fields["sequence"] = 99
  assert_eq(
    moonflow_owner_summary_observation(accepted, Some(changed)),
    "event-head-mismatch",
  )
  let duplicate = owner_cli_accepted_events()
  guard duplicate is Array(events) else { fail("fixture") }
  events.push(events[0])
  assert_eq(
    moonflow_owner_summary_observation(accepted, Some(duplicate)),
    "event-head-mismatch",
  )
  let copied = owner_cli_child_projection()
  guard copied is Object(child) && accepted is { "owner_summary": summary, .. } else {
    fail("fixture")
  }
  child["owner_summary"] = summary
  assert_eq(
    moonflow_owner_summary_observation(copied, Some(owner_cli_child_events())),
    "summary-mismatch",
  )
}
