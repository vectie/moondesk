///|
test "mooncode capability contract names the split packages" {
  let payload = capabilities_json().stringify()
  assert_true(payload.contains("\"component\":\"mooncode\""))
  assert_true(payload.contains("MoonWiki"))
  assert_true(payload.contains("MoonCode"))
  assert_true(payload.contains("MoonClaw daemon"))
  assert_true(payload.contains("package_app_tool"))
  assert_true(payload.contains("\"tool_specs\""))
  assert_true(payload.contains("\"command_specs\""))
  assert_true(payload.contains("\"dispatch\":\"steer\""))
  assert_true(payload.contains("\"approval\":\"operator\""))
  assert_true(payload.contains("\"action\":\"run_build\""))
  assert_true(payload.contains("\"action\":\"approve_tool\""))
  assert_true(payload.contains("\"action\":\"commit\""))
  assert_true(payload.contains("\"runtime_contract\""))
  assert_true(payload.contains("\"moonclaw_adapter_contract\""))
  assert_true(
    payload.contains("\"kind\":\"mooncode-moonclaw-adapter-contract\""),
  )
  assert_true(payload.contains("\"tool_contract\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-contract\""))
  assert_true(payload.contains("\"tool_call_wire\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-call-wire-contract\""))
  assert_true(payload.contains("\"native_runtime_loop_options\""))
  assert_true(payload.contains("\"live_wait_ms\""))
  assert_true(payload.contains("\"poll_ms\""))
  assert_true(payload.contains("\"extraction_boundary\""))
  assert_true(payload.contains("\"kind\":\"mooncode-extraction-boundary\""))
  assert_true(
    payload.contains(
      "\"portable_core_package\":\"vectie/moondesk/mooncode/core\"",
    ),
  )
  assert_true(
    payload.contains(
      "\"moondesk_projection_package\":\"vectie/moondesk/internal/mooncode\"",
    ),
  )
  assert_true(
    payload.contains(
      "\"moonwiki_host_package\":\"vectie/moondesk/internal/moonwiki\"",
    ),
  )
  assert_true(payload.contains("\"core_package\":\"mooncode/core\""))
  assert_true(payload.contains("\"projection_package\":\"internal/mooncode\""))
  assert_true(payload.contains("\"host_package\":\"internal/moonwiki\""))
  assert_true(payload.contains("openseek/agent_runtime"))
  assert_true(payload.contains("\"command\":\"prompt\""))
  assert_true(payload.contains("\"agent_finished\""))
  assert_true(payload.contains("\"required_harnesses\""))
  assert_true(payload.contains("\"harness_contract_endpoint\""))
  assert_true(payload.contains("/api/mooncode/eval-harness"))
  assert_true(payload.contains("\"extraction_boundary_endpoint\""))
  assert_true(payload.contains("/api/mooncode/extraction-boundary"))
  assert_true(payload.contains("\"production_rubric_endpoint\""))
  assert_true(payload.contains("/api/mooncode/production-rubric"))
  assert_true(payload.contains("\"production_rubric\""))
  assert_true(payload.contains("\"kind\":\"mooncode-production-grade-rubric\""))
  assert_true(payload.contains("\"native_eval_report\""))
  assert_true(payload.contains("\"native_session_listing_endpoint\""))
  assert_true(
    payload.contains("/v1/mooncode/sessions?book_root=<path>&format=json"),
  )
  assert_true(
    payload.contains(
      "/v1/mooncode/sessions/<session-id>/serve-scheduler?book_root=<path>",
    ),
  )
  assert_true(
    payload.contains("/v1/mooncode/sessions/<id>/eval-report?book_root=<path>"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/action-plan"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/production-readiness"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-events"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/package-result"),
  )
  assert_true(
    payload.contains(
      "/v1/mooncode/sessions/<session-id>/package-result?book_root=<path>",
    ),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/serve-jsonl"),
  )
}

///|
test "mooncode engine status projection is extractable from http probing" {
  let missing = engine_status_projection_json(
    daemon={ "running": false, "message": "daemon stopped" },
    moonclaw_root="",
    checkout_ready=false,
    running=false,
    models_ready=false,
    tasks_ready=false,
    runtime_contract_ready=false,
    model_evidence="MoonClaw daemon is not running",
    task_evidence="MoonClaw daemon is not running",
    runtime_evidence="MoonClaw daemon is not running",
  )
  assert_eq(json_string(missing, "status", default=""), "moonclaw-missing")
  assert_eq(
    json_string(missing, "adapter_status", default=""),
    "missing-runtime",
  )
  assert_false(json_bool(missing, "ok", default=true))
  assert_false(json_bool(missing, "native_runtime_ready", default=true))
  assert_false(json_bool(missing, "legacy_task_bridge_ready", default=true))
  assert_eq(json_array_items(missing, "checks").length(), 10)
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(missing, "moonclaw_adapter"),
      "status",
      default="",
    ),
    "missing-runtime",
  )
  let endpoints = json_array_items(missing, "supported_endpoints")
  assert_true(
    endpoints
    .map(endpoint => endpoint.stringify())
    .contains("\"/v1/mooncode/sessions/<id>/commands\""),
  )
  assert_true(
    endpoints
    .map(endpoint => endpoint.stringify())
    .contains("\"/api/mooncode/sessions/<id>/production-readiness\""),
  )
  let ready = engine_status_projection_json(
    daemon={ "running": true, "message": "running" },
    moonclaw_root="/tmp/moonclaw",
    checkout_ready=true,
    running=true,
    models_ready=true,
    tasks_ready=true,
    runtime_contract_ready=true,
    model_evidence="/v1/models responded",
    task_evidence="/v1/tasks responded",
    runtime_evidence="/v1/mooncode/capabilities responded",
  )
  assert_eq(json_string(ready, "status", default=""), "production-ready")
  assert_eq(json_string(ready, "adapter_status", default=""), "native-ready")
  assert_true(json_bool(ready, "ok", default=false))
  assert_true(json_bool(ready, "production_ready", default=false))
  assert_true(json_bool(ready, "native_runtime_ready", default=false))
  assert_true(json_bool(ready, "legacy_task_bridge_ready", default=false))
  let ready_payload = ready.stringify()
  assert_true(ready_payload.contains("patch_review"))
  assert_true(ready_payload.contains("command_execution"))
  assert_true(ready_payload.contains("package_output"))
  assert_false(ready_payload.contains("tool_harness/file_edit eval slice"))
}

///|
test "mooncode runtime contract mirrors openseek serve/tool boundaries" {
  let contract = runtime_contract_json()
  assert_eq(json_string(contract, "reference", default=""), "../openseek")
  assert_eq(json_string(contract, "target_component", default=""), "moonclaw")
  let namespace_roles = json_array_items(contract, "namespace_roles")
  assert_eq(namespace_roles.length(), 4)
  let namespace_ids = namespace_roles.map(role => {
    json_string(role, "id", default="")
  })
  assert_true(namespace_ids.contains("workspace_mode"))
  assert_true(namespace_ids.contains("extractable_protocol"))
  assert_true(namespace_ids.contains("runtime_owner"))
  assert_true(namespace_ids.contains("artifact_owner"))
  assert_true(contract.stringify().contains("\"MoonClaw\""))
  let components = json_array_items(contract, "components")
  assert_eq(components.length(), 5)
  let ids = components.map(component => json_string(component, "id", default=""))
  assert_true(ids.contains("agent_runtime"))
  assert_true(ids.contains("agent_session"))
  assert_true(ids.contains("agent_tool"))
  assert_true(ids.contains("agent_loop"))
  assert_true(ids.contains("eval_harness"))
  let wire = summary_json_object_field_or_empty(contract, "wire_protocol")
  let commands = json_array_items(wire, "input_commands")
  assert_eq(commands.length(), 3)
  assert_eq(json_string(commands[0], "command", default=""), "prompt")
  assert_eq(json_string(commands[1], "command", default=""), "steer")
  assert_eq(json_string(commands[2], "command", default=""), "cancel")
  assert_true(
    json_array_items(wire, "output_events")
    .map(item => item.stringify())
    .contains("\"tool_result\""),
  )
  assert_true(
    json_array_items(wire, "output_events")
    .map(item => item.stringify())
    .contains("\"steer_deferred\""),
  )
  assert_true(
    json_array_items(wire, "output_events")
    .map(item => item.stringify())
    .contains("\"steer_dropped\""),
  )
  let eval = summary_json_object_field_or_empty(contract, "eval_contract")
  assert_true(
    json_array_items(eval, "required_harnesses")
    .map(item => item.stringify())
    .contains("\"file_edit\""),
  )
  let required_harnesses = json_array_items(eval, "required_harnesses").map(item => {
    item.stringify()
  })
  assert_true(required_harnesses.contains("\"patch_review\""))
  assert_true(required_harnesses.contains("\"command_execution\""))
  assert_true(required_harnesses.contains("\"package_output\""))
  assert_eq(
    json_string(eval, "harness_contract_endpoint", default=""),
    "/api/mooncode/eval-harness",
  )
  assert_true(
    json_array_items(eval, "reference_paths")
    .map(item => item.stringify())
    .contains("\"../openseek/eval/tool_harness\""),
  )
  let references = json_array_items(eval, "reference_paths").map(item => {
    item.stringify()
  })
  assert_true(references.contains("\"../openseek/eval/patch_review\""))
  assert_true(references.contains("\"../openseek/eval/command_execution\""))
  assert_true(references.contains("\"../openseek/eval/package_output\""))
  assert_true(contract.stringify().contains("\"moon_ide\""))
  assert_true(contract.stringify().contains("\"moon_cmd\""))
  let native_eval_report = summary_json_object_field_or_empty(
    eval, "native_eval_report",
  )
  assert_eq(json_string(native_eval_report, "owner", default=""), "moonclaw")
  assert_eq(
    json_string(native_eval_report, "endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
  )
  assert_true(
    json_array_items(native_eval_report, "required_fields")
    .map(item => item.stringify())
    .contains("\"file_edit\""),
  )
  let tool_contract = summary_json_object_field_or_empty(
    contract, "tool_contract",
  )
  assert_eq(
    json_string(tool_contract, "kind", default=""),
    "mooncode-tool-contract",
  )
  assert_true(tool_contract_tool_ids(tool_contract).contains("moon_check"))
  assert_true(tool_contract_tool_ids(tool_contract).contains("moon_ide"))
  assert_true(tool_contract_tool_ids(tool_contract).contains("moon_cmd"))
}

///|
test "mooncode eval harness contract names openseek cases and evidence" {
  let contract = eval_harness_contract_json()
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-eval-harness-contract",
  )
  assert_eq(json_string(contract, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(contract, "reference", default=""), "../openseek/eval")
  assert_eq(
    json_string(contract, "moonclaw_result_endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
  )
  let harnesses = json_array_items(contract, "required_harnesses")
  assert_eq(harnesses.length(), 5)
  let ids = harnesses.map(harness => json_string(harness, "id", default=""))
  assert_true(ids.contains("tool_harness"))
  assert_true(ids.contains("file_edit"))
  assert_true(ids.contains("patch_review"))
  assert_true(ids.contains("command_execution"))
  assert_true(ids.contains("package_output"))
  let payload = contract.stringify()
  assert_true(payload.contains("../openseek/eval/tool_harness"))
  assert_true(payload.contains("../openseek/eval/file_edit"))
  assert_true(payload.contains("../openseek/eval/patch_review"))
  assert_true(payload.contains("../openseek/eval/command_execution"))
  assert_true(payload.contains("../openseek/eval/package_output"))
  assert_true(payload.contains("\"moon_check\""))
  assert_true(payload.contains("\"moon_ide\""))
  assert_true(payload.contains("\"moon_cmd\""))
  assert_true(payload.contains("\"compile_fix\""))
  assert_true(payload.contains("file-edit-eval:<case>"))
  assert_true(payload.contains("\"future_package\":\"mooncode/eval\""))
}
