///|
async test "Desk actual HTTP UI request crosses Flow Gate native Mold then reloads Review" {
  guard @env.get_env_var("MOONDESK_FLOW_STEP_UI_REQUEST") is Some(request_path) &&
    @env.get_env_var("MOONDESK_FLOW_STEP_FIXTURE") is Some(fixture) else {
    println(
      "FLOW_STEP_NATIVE_HTTP_NOT_CONFIGURED: actual HTTP crossing was not exercised",
    )
    return
  }
  let root = @fs.realpath(fixture)
  let payload = @json.parse(@fs.read_file(request_path).text())
  let workspace_id = json_string(payload, "workspace_id", default="")
  let run_id = json_string(payload, "run_id", default="")
  let item_id = json_string(payload, "work_item_id", default="")
  assert_eq(workspace_id, @desk.stable_id("book", "single-step-book"))
  let relative = ".moonsuite/products/moonflow/runs/" + run_id
  let ui_root = @env.get_env_var("MOONDESK_FLOW_STEP_UI_DIST").unwrap_or(root)
  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(ui_root, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let workspaces = test_http_get_json(base + "/api/workspaces", 200)
    assert_true(workspaces.stringify().contains(workspace_id))
    let run_url = base + "/api/moonflow/runs/" + run_id
    let before = test_http_get_json(run_url, 200)
    for item in moonflow_graph_items(before) {
      assert_eq(json_int(item, "attempt_count", default=-1), 0)
    }
    // Hide only this synthetic fixture's configuration, then repair setup.
    let config = root + "/trusted/single-step.json"
    let held = config + ".http-test-held"
    @fs.rename(config, held, replace=false)
    let blocked_response = Ok(
      test_http_post_json(base + "/api/moonflow/single-step", payload, 200),
    ) catch {
      error => Err(error.to_string())
    }
    @fs.rename(held, config, replace=false)
    let blocked = blocked_response.unwrap()
    assert_eq(json_string(blocked, "status", default=""), "blocked")
    assert_false(
      @fs.exists(
        root + "/" + relative + "/single-step/" + item_id + ".action.json",
      ),
    )
    let result = test_http_post_json(
      base + "/api/moonflow/single-step",
      payload,
      200,
    )
    assert_eq(json_string(result, "status", default=""), "review")
    // The actual response is recorded for evidence but intentionally omitted
    // from the UI. Its test receives Err, then reconciles this original ID.
    let events_path = root + "/" + relative + "/events.json"
    let events = @fs.read_file(events_path).binary()
    let projection = test_http_get_json(run_url, 200)
    let selected = moonflow_graph_items(projection).filter(item => {
        json_string(item, "work_item_id", default="") == item_id
      })[0]
    assert_eq(json_string(selected, "status", default=""), "review")
    assert_eq(json_int(selected, "attempt_count", default=-1), 1)
    assert_eq(
      json_string(selected, "acceptance_review_id", default="missing"),
      "",
    )
    for item in moonflow_graph_items(projection) {
      if json_string(item, "work_item_id", default="") != item_id {
        assert_eq(json_int(item, "attempt_count", default=-1), 0)
      }
    }
    let actions = json_object_field(projection, "single_step_actions").unwrap_or(
      Json::null(),
    )
    assert_true(
      actions
      .stringify()
      .contains(json_string(payload, "request_id", default="")),
    )
    assert_false(actions.stringify().contains("adapter_request"))
    let reconcile = @json.parse(payload.stringify())
    if reconcile is Object(fields) {
      fields["action"] = "reconcile"
    }
    let reconciled = test_http_post_json(
      base + "/api/moonflow/single-step",
      reconcile,
      200,
    )
    assert_eq(json_string(reconciled, "status", default=""), "review")
    assert_eq(@fs.read_file(events_path).binary(), events)
    let repeated = test_http_post_json(
      base + "/api/moonflow/single-step",
      payload,
      200,
    )
    assert_eq(json_string(repeated, "status", default=""), "review")
    assert_eq(@fs.read_file(events_path).binary(), events)
    let injected = @json.parse(payload.stringify())
    if injected is Object(fields) {
      fields["executable"] = "/bin/echo"
    }
    let refused = test_http_post_json(
      base + "/api/moonflow/single-step",
      injected,
      200,
    )
    assert_eq(json_string(refused, "status", default=""), "blocked")
    assert_eq(@fs.read_file(events_path).binary(), events)
    assert_false(execution_sandbox_client_available())
    let evidence : Json = {
      "request": payload,
      "blocked": blocked,
      "result": result,
      "repeated": repeated,
      "reconciled": reconciled,
      "projection": projection,
      "safe_actions": actions,
      "http_boundary": true,
      "selected_only": true,
      "generic_executor_denied": true,
      "fault": "browser-response-discarded-after-real-HTTP-execution",
    }
    if @env.get_env_var("MOONDESK_FLOW_STEP_EVIDENCE") is Some(path) {
      @fs.write_file(
        path,
        evidence.stringify(indent=2),
        create_mode=CreateOrTruncate,
      )
    }
    println(
      "FLOW_STEP_NATIVE_HTTP: compiled UI payload through actual HTTP router/body/Book lookup to trusted host Flow Gate native Mold; setup repair same ID, selected-only Review, reload duplicate and reconcile passed",
    )
  })
}
