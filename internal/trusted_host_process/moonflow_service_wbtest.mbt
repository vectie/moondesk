///|
test "native Flow operations keep fixed command shapes and literal arguments" {
  assert_eq(
    moonflow_service_arguments(
      "/workspace",
      Control(
        run_id="run-1",
        action="pause",
        evaluated_at="2026-10-22T12:00:00Z",
        detail="pause; $(echo ignored)",
      ),
    ),
    Ok([
      "control", "/workspace", "run-1", "pause", "2026-10-22T12:00:00Z", "pause; $(echo ignored)",
    ]),
  )
  assert_eq(
    moonflow_service_arguments(
      "/workspace",
      InspectCollaboration(workspace_id="book-check"),
    ),
    Ok(["collaboration", "inspect", "/workspace", "book-check"]),
  )
  assert_true(
    moonflow_service_arguments(
      "/workspace",
      Control(
        run_id="run-1",
        action="execute",
        evaluated_at="2026-10-22T12:00:00Z",
        detail="",
      ),
    )
    is Err(_),
  )
  assert_true(
    moonflow_service_arguments(
      "/workspace",
      InspectCollaboration(workspace_id="../other"),
    )
    is Err(_),
  )
}

///|
async test "installed Flow owner can validate its native service contract" {
  if @env.get_env_var("MOONDESK_MOONFLOW_BIN") is Some(_) {
    assert_true(moonflow_service_runtime() is Ok(_))
    assert_true(moonflow_planning_runtime() is Ok(_))
    assert_true(moonflow_review_runtime() is Ok(_))
  }
}
