///|
test "Flow planning has fixed argv and rejects arbitrary commands or paths" {
  let relative = ".moonsuite/products/moondesk/flow-plans/desk-fixture1234"
  let operation = PrepareForm(
    form_ref=relative + "/form.json",
    catalog_ref=relative + "/catalog.json",
    draft_id="desk-fixture1234",
    recorded_at="2026-10-07T00:00:00Z",
  )
  assert_eq(
    moonflow_planning_arguments("/tmp/flow-space", operation).unwrap(),
    [
      "plan",
      "prepare-form",
      "/tmp/flow-space",
      relative + "/form.json",
      relative + "/catalog.json",
      "desk-fixture1234",
      "2026-10-07T00:00:00Z",
    ],
  )
  assert_true(
    moonflow_planning_arguments("/tmp/../escape", operation) is Err(_),
  )
  assert_false(moonflow_planning_ref("../../private.json"))
  assert_false(moonflow_planning_ref(relative + "/$(execute).json"))
  assert_false(moonflow_planning_ref(relative + "/../secret"))
  assert_false(moonflow_planning_identifier("--execute"))
  assert_false(moonflow_planning_identifier("x;run"))
  let apply = ApplyPrepared(
    preparation_id="plan-1234",
    catalog_ref=relative + "/catalog.json",
    evaluated_at="2026-10-07T00:00:00Z",
  )
  assert_eq(
    moonflow_planning_arguments("/tmp/flow-space", apply).unwrap()[1],
    "apply-prepared",
  )
  assert_eq(moonbook_export_environment()["PATH"], "/dev/null")
  assert_eq(moonbook_export_environment()["HOME"], "/dev/null")
  assert_false(
    moonflow_planning_help_compatible(
      "moonflow plan prepare <workspace> <draft-id>",
    ),
  )
  assert_true(
    moonflow_planning_help_compatible(
      "MoonFlow usage:\n  moonflow plan prepare-form <workspace> <form-ref> <catalog-ref> <draft-id> <recorded-at>\n  moonflow plan apply-prepared <workspace> <preparation-id> <catalog-ref> <evaluated-at>\n",
    ),
  )
}
