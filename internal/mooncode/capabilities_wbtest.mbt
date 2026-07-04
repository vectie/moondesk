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
  assert_true(payload.contains("\"control\":\"steer\""))
  assert_true(payload.contains("\"approval\":\"operator\""))
  assert_true(payload.contains("\"action\":\"run_build\""))
  assert_true(payload.contains("\"action\":\"approve_tool\""))
  assert_true(payload.contains("\"action\":\"commit\""))
  assert_true(payload.contains("\"runtime_contract\""))
  assert_true(payload.contains("\"moonclaw_runtime_contract\""))
  assert_true(
    payload.contains("\"kind\":\"mooncode-moonclaw-runtime-contract\""),
  )
  assert_true(payload.contains("\"tool_contract\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-contract\""))
  assert_true(payload.contains("\"tool_call_contract\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-call-contract\""))
  assert_true(payload.contains("\"native_runtime_loop_options\""))
  assert_true(payload.contains("\"live_wait_ms\""))
  assert_true(payload.contains("\"poll_ms\""))
  assert_true(payload.contains("\"standalone_boundary\""))
  assert_true(payload.contains("\"kind\":\"mooncode-standalone-boundary\""))
  assert_true(payload.contains("\"executable_book_lifecycle\""))
  assert_true(
    payload.contains("\"kind\":\"mooncode-executable-book-lifecycle\""),
  )
  assert_true(payload.contains("\"acceptance_owner\":\"bookkeeper\""))
  assert_true(payload.contains("\"id\":\"package_output\""))
  assert_true(payload.contains("\"core_package\":\"mooncode/core\""))
  assert_true(
    payload.contains("\"projection_component\":\"mooncode.projection\""),
  )
  assert_true(payload.contains("\"host_component\":\"moonwiki.host\""))
  assert_true(
    payload.contains("\"runtime_component\":\"moonclaw.standalone-runtime\""),
  )
  assert_true(
    payload.contains("\"runtime_substrate\":\"moonclaw.shared-runtime\""),
  )
  assert_true(payload.contains("\"id\":\"moonclaw-standalone-runtime\""))
  assert_true(payload.contains("\"core_package\":\"mooncode/core\""))
  assert_true(payload.contains("\"projection_package\":\"internal/mooncode\""))
  assert_true(payload.contains("\"host_package\":\"internal/moonwiki\""))
  assert_true(payload.contains("mooncode/runtime"))
  assert_true(payload.contains("\"command\":\"prompt\""))
  assert_true(payload.contains("\"runtime_finished\""))
  assert_true(payload.contains("\"required_harnesses\""))
  assert_true(payload.contains("\"harness_contract_endpoint\""))
  assert_true(payload.contains("/api/mooncode/eval-harness"))
  assert_true(payload.contains("\"standalone_boundary_endpoint\""))
  assert_true(payload.contains("/api/mooncode/standalone-boundary"))
  assert_true(payload.contains("\"readiness_contract_endpoint\""))
  assert_true(payload.contains("/api/mooncode/readiness-contract"))
  assert_true(payload.contains("\"readiness_contract\""))
  assert_true(payload.contains("\"kind\":\"mooncode-readiness-contract\""))
  assert_true(payload.contains("\"native_eval_report\""))
  assert_true(payload.contains("\"native_session_listing_endpoint\""))
  assert_true(payload.contains(native_code_session_listing_endpoint()))
  assert_true(payload.contains(native_code_session_runtime_control_endpoint()))
  assert_true(payload.contains(native_code_session_runtime_service_endpoint()))
  assert_true(payload.contains(native_code_session_eval_report_endpoint()))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/action-plan"),
  )
  assert_true(payload.contains("/api/mooncode/sessions/<session-id>/readiness"))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-events"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/package-result"),
  )
  assert_true(payload.contains(native_code_session_package_result_endpoint()))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/command-jsonl"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-service"),
  )
}

///|
test "mooncode capability lifecycle contract is backend portable" {
  let capability = capabilities_json()
  let lifecycle = summary_json_object_field_or_empty(
    capability, "executable_book_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "contract_id", default=""),
    executable_book_lifecycle_contract_id(),
  )
  let required = command_json_string_array_items(lifecycle, "required_steps")
  assert_eq(required.length(), executable_book_lifecycle_steps().length())
  for step in executable_book_lifecycle_steps() {
    assert_true(required.contains(step))
  }
  let steps = json_array_items(lifecycle, "steps")
  assert_eq(steps.length(), required.length())
  for step in steps {
    assert_true(required.contains(json_string(step, "id", default="")))
    assert_true(json_array_items(step, "required_evidence").length() > 0)
  }
  let payload = lifecycle.stringify()
  assert_false(payload.contains("Rabbita"))
  assert_false(payload.contains("rabbita"))
  assert_false(payload.contains("internal/mooncode"))
  assert_false(payload.contains("internal/moonwiki"))
}

///|
test "mooncode capability native endpoints mirror the core surface" {
  let capability = capabilities_json()
  let protocol = summary_json_object_field_or_empty(
    capability, "session_protocol",
  )
  let fields = [
    "native_session_list_endpoint", "native_session_listing_endpoint", "native_session_show_endpoint",
    "native_package_result_endpoint", "native_runtime_control_endpoint", "native_eval_report_endpoint",
    "native_runtime_claim_endpoint", "native_runtime_turn_endpoint", "native_runtime_loop_endpoint",
    "native_runtime_service_endpoint",
  ]
  let endpoints = [
    native_code_session_list_endpoint(),
    native_code_session_listing_endpoint(),
    native_code_session_show_endpoint(),
    native_code_session_package_result_endpoint(),
    native_code_session_runtime_control_endpoint(),
    native_code_session_eval_report_endpoint(),
    native_code_session_runtime_claim_endpoint(),
    native_code_session_runtime_turn_endpoint(),
    native_code_session_runtime_loop_endpoint(),
    native_code_session_runtime_service_endpoint(),
  ]
  assert_eq(fields.length(), endpoints.length())
  for i, field in fields {
    let endpoint = endpoints[i]
    assert_eq(json_string(protocol, field, default=""), endpoint)
    assert_true(native_capability_required_endpoints().contains(endpoint))
    assert_false(endpoint.contains("<session-id>"))
  }
}

///|
test "mooncode capability publishes desktop route contracts" {
  let capability = capabilities_json()
  let published = json_array_items(capability, "desktop_route_contracts")
  let expected = desktop_projection_route_contracts()
  assert_eq(published.length(), expected.length())
  for contract in expected {
    let path = json_string(contract, "path", default="")
    let matches : Array[Json] = []
    for item in published {
      if json_string(item, "path", default="") == path {
        matches.push(item)
      }
    }
    assert_eq(matches.length(), 1)
    assert_route_methods(
      route_contract_methods(matches[0]),
      route_contract_methods(contract),
    )
  }
}

///|
test "mooncode capability commands derive from advertised command contract" {
  let capability = capabilities_json()
  let protocol = summary_json_object_field_or_empty(
    capability, "session_protocol",
  )
  let commands = command_json_string_array_items(protocol, "commands")
  assert_eq(commands.length(), command_advertised_actions().length())
  for action in command_advertised_actions() {
    assert_true(commands.contains(action))
  }
  assert_false(commands.contains("note"))
  let specs = json_array_items(capability, "command_specs")
  assert_eq(specs.length(), command_advertised_actions().length())
  for spec in specs {
    let action = json_string(spec, "action", default="")
    assert_true(command_advertised_actions().contains(action))
    assert_eq(json_string(spec, "control", default=""), command_control(action))
    assert_eq(
      json_string(spec, "approval", default=""),
      command_approval(action),
    )
  }
}

///|
test "mooncode capability tools cover command hints and runtime contract" {
  let capability = capabilities_json()
  let tools = command_json_string_array_items(capability, "tools")
  let expected_tools = capability_tool_names()
  assert_eq(tools.length(), expected_tools.length())
  assert_eq(expected_tools.length(), runtime_tool_names().length() + 1)
  assert_true(expected_tools.contains("eval_harness"))
  for tool in expected_tools {
    assert_true(tools.contains(tool))
  }
  for runtime_tool in runtime_tool_names() {
    assert_true(tools.contains(runtime_tool))
  }
  for required_tool in native_capability_required_tools() {
    assert_true(tools.contains(required_tool))
  }
  for action in command_advertised_actions() {
    for hint in command_tool_hints(action) {
      assert_true(tools.contains(hint))
    }
  }
  let specs = json_array_items(capability, "tool_specs")
  let expected_specs = capability_tool_specs()
  assert_eq(specs.length(), tools.length())
  assert_eq(expected_specs.length(), tools.length())
  let spec_ids = specs.map(spec => json_string(spec, "id", default=""))
  for tool in tools {
    assert_true(spec_ids.contains(tool))
  }
  for spec in specs {
    assert_true(tools.contains(json_string(spec, "id", default="")))
  }
  for i, id in spec_ids {
    for j = i + 1; j < spec_ids.length(); j = j + 1 {
      if id == spec_ids[j] {
        fail("duplicate capability tool spec: \{id}")
      }
    }
  }
  for i, tool in tools {
    for j = i + 1; j < tools.length(); j = j + 1 {
      if tool == tools[j] {
        fail("duplicate capability tool: \{tool}")
      }
    }
  }
}

///|
test "mooncode engine status projection is standalone from http probing" {
  let missing = engine_status_projection_json(
    daemon={ "running": false, "message": "daemon stopped" },
    moonclaw_root="",
    checkout_ready=false,
    running=false,
    models_ready=false,
    runtime_contract_ready=false,
    model_evidence="MoonClaw daemon is not running",
    runtime_evidence="MoonClaw daemon is not running",
  )
  assert_eq(
    json_string(missing, "status", default=""),
    "moonclaw-service-missing",
  )
  assert_eq(
    json_string(missing, "runtime_status", default=""),
    "missing-runtime",
  )
  assert_false(json_bool(missing, "ok", default=true))
  assert_false(json_bool(missing, "native_runtime_ready", default=true))
  assert_eq(json_array_items(missing, "checks").length(), 9)
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(missing, "moonclaw_runtime"),
      "status",
      default="",
    ),
    "missing-runtime",
  )
  let endpoints = json_array_items(missing, "supported_endpoints")
  assert_true(
    endpoints
    .map(endpoint => endpoint.stringify())
    .contains("\"/v1/code/sessions/<id>/commands\""),
  )
  assert_true(
    endpoints
    .map(endpoint => endpoint.stringify())
    .contains("\"\{desktop_session_readiness_endpoint()}\""),
  )
  let ready = engine_status_projection_json(
    daemon={ "running": true, "message": "running" },
    moonclaw_root="/tmp/moonclaw",
    checkout_ready=true,
    running=true,
    models_ready=true,
    runtime_contract_ready=true,
    model_evidence="/v1/models responded",
    runtime_evidence="/v1/code/capabilities responded",
  )
  assert_eq(json_string(ready, "status", default=""), "native-ready")
  assert_eq(json_string(ready, "runtime_status", default=""), "native-ready")
  assert_true(json_bool(ready, "ok", default=false))
  assert_true(json_bool(ready, "ready", default=false))
  assert_true(json_bool(ready, "native_runtime_ready", default=false))
  let ready_payload = ready.stringify()
  assert_true(ready_payload.contains("patch_review"))
  assert_true(ready_payload.contains("command_execution"))
  assert_true(ready_payload.contains("package_output"))
  assert_false(ready_payload.contains("tool_harness/file_edit eval slice"))
}

///|
test "mooncode runtime contract mirrors mooncode runtime/tool boundaries" {
  let contract = runtime_contract_json()
  assert_eq(json_string(contract, "reference", default=""), "mooncode")
  assert_eq(json_string(contract, "target_component", default=""), "moonclaw")
  let namespace_roles = json_array_items(contract, "namespace_roles")
  assert_eq(namespace_roles.length(), 4)
  let namespace_ids = namespace_roles.map(role => {
    json_string(role, "id", default="")
  })
  assert_true(namespace_ids.contains("workspace_mode"))
  assert_true(namespace_ids.contains("standalone_protocol"))
  assert_true(namespace_ids.contains("runtime_owner"))
  assert_true(namespace_ids.contains("artifact_owner"))
  assert_true(contract.stringify().contains("\"MoonClaw\""))
  let components = json_array_items(contract, "components")
  assert_eq(components.length(), 5)
  let ids = components.map(component => json_string(component, "id", default=""))
  assert_true(ids.contains("mooncode_runtime"))
  assert_true(ids.contains("mooncode_session"))
  assert_true(ids.contains("mooncode_tool"))
  assert_true(ids.contains("mooncode_turn_loop"))
  assert_true(ids.contains("eval_harness"))
  let mut found_tool_component = false
  for component in components {
    if json_string(component, "id", default="") == "mooncode_tool" {
      found_tool_component = true
      let purpose = json_string(component, "purpose", default="")
      for tool in runtime_tool_names() {
        assert_true(purpose.contains(tool))
      }
    }
  }
  assert_true(found_tool_component)
  let command_protocol = summary_json_object_field_or_empty(
    contract, "command_protocol",
  )
  let commands = json_array_items(command_protocol, "input_commands")
  assert_eq(commands.length(), 3)
  assert_eq(json_string(commands[0], "command", default=""), "prompt")
  assert_eq(json_string(commands[1], "command", default=""), "steer")
  assert_eq(json_string(commands[2], "command", default=""), "cancel")
  assert_true(
    json_array_items(command_protocol, "output_events")
    .map(item => item.stringify())
    .contains("\"tool_result\""),
  )
  assert_true(
    json_array_items(command_protocol, "output_events")
    .map(item => item.stringify())
    .contains("\"steer_deferred\""),
  )
  assert_true(
    json_array_items(command_protocol, "output_events")
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
    .contains("\"mooncode/eval/tool_harness\""),
  )
  let references = json_array_items(eval, "reference_paths").map(item => {
    item.stringify()
  })
  assert_true(references.contains("\"mooncode/eval/patch_review\""))
  assert_true(references.contains("\"mooncode/eval/command_execution\""))
  assert_true(references.contains("\"mooncode/eval/package_output\""))
  assert_true(contract.stringify().contains("\"moon_ide\""))
  assert_true(contract.stringify().contains("\"moon_cmd\""))
  let native_eval_report = summary_json_object_field_or_empty(
    eval, "native_eval_report",
  )
  assert_eq(json_string(native_eval_report, "owner", default=""), "moonclaw")
  assert_eq(
    json_string(native_eval_report, "endpoint", default=""),
    "/v1/code/sessions/<id>/eval-report?book_root=<path>",
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
test "mooncode eval harness contract names mooncode cases and evidence" {
  let contract = eval_harness_contract_json()
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-eval-harness-contract",
  )
  assert_eq(json_string(contract, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(contract, "reference", default=""), "mooncode/eval")
  assert_eq(
    json_string(contract, "moonclaw_result_endpoint", default=""),
    "/v1/code/sessions/<id>/eval-report?book_root=<path>",
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
  assert_true(payload.contains("mooncode/eval/tool_harness"))
  assert_true(payload.contains("mooncode/eval/file_edit"))
  assert_true(payload.contains("mooncode/eval/patch_review"))
  assert_true(payload.contains("mooncode/eval/command_execution"))
  assert_true(payload.contains("mooncode/eval/package_output"))
  assert_true(payload.contains("\"moon_check\""))
  assert_true(payload.contains("\"moon_ide\""))
  assert_true(payload.contains("\"moon_cmd\""))
  assert_true(payload.contains("\"revert_patch\""))
  assert_true(payload.contains("\"package_app_tool\""))
  assert_true(payload.contains("\"compile_fix\""))
  assert_true(payload.contains("file-edit-eval:<case>"))
  assert_true(payload.contains("\"future_package\":\"mooncode/eval\""))
  for harness in harnesses {
    if json_string(harness, "id", default="") == "tool_harness" {
      let required_tools = command_json_string_array_items(
        harness, "required_tools",
      )
      assert_eq(required_tools.length(), runtime_tool_names().length())
      for tool in runtime_tool_names() {
        assert_true(required_tools.contains(tool))
      }
    }
  }
}
