///|
test "mooncode http contract delegates static capability shape to mooncode package" {
  let payload = @mooncode.capabilities_json().stringify()
  assert_true(payload.contains("\"component\":\"mooncode\""))
  assert_true(payload.contains("\"runtime_contract\""))
  assert_true(payload.contains("\"moonclaw_runtime_contract\""))
  assert_true(payload.contains("\"tool_contract\""))
  assert_true(payload.contains("/api/mooncode/eval-harness"))
  assert_true(payload.contains("/api/mooncode/standalone-boundary"))
  assert_true(payload.contains("/api/mooncode/readiness-contract"))
  assert_true(payload.contains("\"desktop_route_contracts\""))
  assert_true(payload.contains("\"readiness_contract\""))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-evidence"),
  )
  assert_true(payload.contains("/api/mooncode/sessions/<session-id>/readiness"))
  assert_true(
    payload.contains("/v1/code/sessions/<id>/eval-report?book_root=<path>"),
  )
  assert_eq(
    json_string(
      @mooncode.runtime_contract_json(),
      "target_component",
      default="",
    ),
    "moonclaw",
  )
  assert_eq(
    json_string(@mooncode.eval_harness_contract_json(), "kind", default=""),
    "mooncode-eval-harness-contract",
  )
  assert_eq(
    json_string(@mooncode.standalone_boundary_json(), "kind", default=""),
    "mooncode-standalone-boundary",
  )
  assert_eq(
    json_string(@mooncode.readiness_contract_json(), "kind", default=""),
    "mooncode-readiness-contract",
  )
  assert_eq(
    json_string(
      @mooncode.native_eval_report_contract_json(),
      "owner",
      default="",
    ),
    "moonclaw",
  )
}

///|
test "mooncode model readiness requires a listed executable default" {
  assert_true(
    moonclaw_models_response_ready({
      "ready": true,
      "default_model": "codex/gpt-5.4",
      "models": [
        { "name": "codex/gpt-5.4", "default": true },
        { "name": "gpt-5.6-sol", "default": false },
      ],
    }),
  )
  assert_false(
    moonclaw_models_response_ready({
      "ready": true,
      "default_model": "phantom",
      "models": [{ "name": "codex/gpt-5.4" }],
    }),
  )
  assert_false(
    moonclaw_models_response_ready({
      "ready": false,
      "default_model": "",
      "models": [],
    }),
  )
}

///|
async test "mooncode engine status requires native runtime readiness" {
  let status = mooncode_engine_status_json(
    "/tmp/moondesk-mooncode-engine-status-wbtest",
  )
  assert_eq(
    json_string(status, "runtime_mode", default=""),
    "runtime-unavailable",
  )
  assert_false(json_bool(status, "ready", default=true))
  assert_eq(
    json_string(status, "runtime_status", default=""),
    "missing-runtime",
  )
  let native_readiness = json_object_field_or_empty(
    status, "native_capabilities_readiness",
  )
  assert_false(json_bool(native_readiness, "ok", default=true))
  assert_eq(
    json_string(native_readiness, "status", default=""),
    "native-runtime-unavailable",
  )
  let checks = json_array_items(status, "checks")
  assert_eq(checks.length(), 9)
  let ids = checks.map(check => json_string(check, "id", default=""))
  assert_true(ids.contains("daemon_running"))
  assert_true(ids.contains("prompt_message_cancel"))
  assert_true(ids.contains("append_only_session_log"))
  assert_true(ids.contains("append_only_command_queue"))
  assert_true(ids.contains("typed_runtime_contract"))
  assert_true(ids.contains("moonclaw_runtime"))
  assert_true(ids.contains("eval_harness_evidence"))
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/eval-harness",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/standalone-boundary",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/readiness-contract",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/sessions",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/v1/code/sessions/<id>/commands",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      @mooncode.desktop_session_readiness_endpoint(),
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/v1/code/sessions/<id>/eval-report?book_root=<path>",
    ),
  )
}
