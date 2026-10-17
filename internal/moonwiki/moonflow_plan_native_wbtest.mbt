///|
async test "Desk production UI request crosses native host Flow prepare import and revision" {
  guard @env.get_env_var("MOONDESK_FLOW_PLAN_UI_REQUEST") is Some(request_path) &&
    @env.get_env_var("MOONDESK_FLOW_PLAN_FIXTURE") is Some(fixture) &&
    @env.get_env_var("MOONDESK_MOONFLOW_BIN") is Some(executable) else {
    println(
      "FLOW_PLAN_NATIVE_FIXTURE_NOT_CONFIGURED: real native crossing was not exercised",
    )
    return
  }
  let evaluated_at = @env.get_env_var("MOONDESK_FLOW_PLAN_EVALUATED_AT").unwrap_or(
    "2026-07-31T00:00:00Z",
  )
  let original_payload = @json.parse(@fs.read_file(request_path).text())
  let form = json_object_field(original_payload, "form").unwrap_or(Json::null())
  let source = json_object_field(form, "source_graph").unwrap_or(Json::null())
  let workspace_id = json_string(original_payload, "workspace_id", default="")
  let request_id = json_string(original_payload, "request_id", default="")
  let runtime = @trusted_host.moonflow_planning_runtime().unwrap()
  let evidence : Array[Json] = []
  for revision in [false, true] {
    let root = @fs.realpath(@fs.tmpdir(prefix="desk-flow-native-"))
    let book = root + "/books/" + workspace_id
    @fs.mkdir(book + "/flow", recursive=true)
    @fs.mkdir(root + "/requests")
    let source_path = book + "/flow/work-graph.json"
    @fs.write_file(source_path, source.stringify(), create_mode=CreateNew)
    @fs.write_file(
      book + "/flow/capability-catalog.json",
      @fs.read_file(fixture + "/catalog.json").binary(),
      create_mode=CreateNew,
    )
    for name in @fs.readdir(fixture + "/requests") {
      @fs.write_file(
        root + "/requests/" + name,
        @fs.read_file(fixture + "/requests/" + name).binary(),
        create_mode=CreateNew,
      )
    }
    let workspace = @desk.workspace(
      id=workspace_id,
      name="Native planning fixture",
      root_path=book,
      kind=MoonBook,
    )
    let parent_events_path = root +
      "/.moonsuite/products/moonflow/runs/" +
      moonflow_graph_run_id(source) +
      "/events.json"
    let parent_projection_path = root +
      "/.moonsuite/products/moonflow/runs/" +
      moonflow_graph_run_id(source) +
      "/projection.json"
    if revision {
      let status = @process.collect_output(
        executable,
        [
          "import-conformant-graph",
          root,
          source_path,
          book + "/flow/capability-catalog.json",
          evaluated_at,
        ],
        inherit_env=false,
        extra_env={ "HOME": "/dev/null", "PATH": "/dev/null" },
      )
      guard status.0 == 0 else {
        fail("Native fixture parent import failed: " + status.2.text())
      }
    }
    let parent_events = if revision {
      Some(@fs.read_file(parent_events_path).binary())
    } else {
      None
    }
    let parent_projection = if revision {
      Some(@fs.read_file(parent_projection_path).binary())
    } else {
      None
    }
    let original_source = @fs.read_file(source_path).binary()
    let run : MoonFlowPlanningRun = operation => {
      @trusted_host.run_moonflow_planning(runtime, root, operation)
    }
    let prepared = moonflow_plan_handle_with(
      root, workspace, original_payload, evaluated_at, run,
    )
    let repeated = moonflow_plan_handle_with(
      root, workspace, original_payload, evaluated_at, run,
    )
    assert_eq(prepared, repeated)
    let receipt = json_object_field(prepared, "receipt").unwrap_or(Json::null())
    let prepared_value = json_object_field(receipt, "prepared").unwrap_or(
      Json::null(),
    )
    let child_id = json_string(prepared_value, "preparation_id", default="")
    let child_directory = root +
      "/.moonsuite/products/moonflow/runs/" +
      child_id
    assert_false(@fs.exists(child_directory + "/events.json"))
    assert_true(
      json_object_field(receipt, "input_captures") is Some(Array([_, ..])),
    )
    assert_eq(
      json_object_field(receipt, "migration_preview") != Some(Json::null()),
      revision,
    )
    let applied = moonflow_plan_handle_with(
      root,
      workspace,
      desk_plan_action(original_payload, "apply"),
      evaluated_at,
      run,
    )
    let events = @fs.read_file(child_directory + "/events.json").binary()
    let projection = @json.parse(
      @fs.read_file(child_directory + "/projection.json").text(),
    )
    assert_eq(json_string(projection, "run_id", default=""), child_id)
    for item in moonflow_graph_items(projection) {
      assert_eq(json_int(item, "attempt_count", default=-1), 0)
      assert_eq(json_string(item, "active_attempt_id", default="missing"), "")
      assert_eq(json_string_array_items(item, "approvals"), [])
    }
    assert_false(@encoding/utf8.decode(events).contains("attempt-submitted"))
    let reapplied = moonflow_plan_handle_with(
      root,
      workspace,
      desk_plan_action(original_payload, "apply"),
      evaluated_at,
      run,
    )
    assert_eq(reapplied, applied)
    assert_eq(@fs.read_file(child_directory + "/events.json").binary(), events)
    let reopened = moonflow_plan_handle_with(
      root,
      workspace,
      desk_plan_action(original_payload, "inspect"),
      evaluated_at,
      run,
    )
    assert_eq(reopened, applied)
    assert_eq(@fs.read_file(source_path).binary(), original_source)
    if parent_events is Some(bytes) {
      assert_eq(@fs.read_file(parent_events_path).binary(), bytes)
    }
    if parent_projection is Some(bytes) {
      assert_eq(@fs.read_file(parent_projection_path).binary(), bytes)
    }
    assert_false(execution_sandbox_client_available())
    evidence.push({
      "revision": revision,
      "workspace": root,
      "ui_request_id": request_id,
      "prepared": prepared,
      "applied": applied,
      "source_unchanged": true,
      "parent_unchanged": true,
      "attempt_count": 0,
    })
  }
  if @env.get_env_var("MOONDESK_FLOW_PLAN_EVIDENCE") is Some(path) {
    @fs.write_file(
      path,
      ToJson::to_json(evidence).stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  }
  println(
    "FLOW_PLAN_NATIVE_CROSSING: prepare/import/revise/reload/retry passed, source and parent retained, zero attempts",
  )
}
