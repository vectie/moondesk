///|
async fn handle_mooncode_capabilities(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, mooncode_capabilities_response_json(workspace_root))
}

///|
async fn handle_mooncode_eval_harness_contract(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, @mooncode.eval_harness_contract_json())
}

///|
async fn mooncode_capabilities_response_json(workspace_root : String) -> Json {
  agent_session_with_field(
    @mooncode.capabilities_json(),
    "engine_status",
    mooncode_engine_status_json(workspace_root),
  )
}

///|
async fn mooncode_engine_status_json(workspace_root : String) -> Json {
  let daemon = moonclaw_daemon_status(workspace_root)
  let running = json_bool(daemon, "running", default=false)
  let root = json_string(daemon, "moonclaw_root", default="")
  let checkout_ready = is_runnable_moonclaw(root)
  let models_probe = if running {
    moonclaw_get_json(daemon, "/v1/models")
  } else {
    Err("MoonClaw daemon is not running")
  }
  let tasks_probe = if running {
    moonclaw_get_json(daemon, "/v1/tasks")
  } else {
    Err("MoonClaw daemon is not running")
  }
  let runtime_probe = if running {
    moonclaw_get_json(daemon, "/v1/mooncode/capabilities")
  } else {
    Err("MoonClaw daemon is not running")
  }
  let native_readiness : Json = match runtime_probe {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_readiness(capabilities)
    Err(error) => @mooncode.moonclaw_native_capabilities_unavailable(error)
  }
  let models_ready = models_probe is Ok(_)
  let tasks_ready = tasks_probe is Ok(_)
  let runtime_contract_ready = json_bool(native_readiness, "ok", default=false)
  agent_session_with_field(
    @mooncode.engine_status_projection_json(
      daemon~,
      moonclaw_root=root,
      checkout_ready~,
      running~,
      models_ready~,
      tasks_ready~,
      runtime_contract_ready~,
      model_evidence=match models_probe {
        Ok(_) => "/v1/models responded"
        Err(error) => error
      },
      task_evidence=match tasks_probe {
        Ok(_) => "/v1/tasks responded"
        Err(error) => error
      },
      runtime_evidence=match runtime_probe {
        Ok(_) =>
          if runtime_contract_ready {
            "/v1/mooncode/capabilities passed MoonCode compatibility check"
          } else {
            "/v1/mooncode/capabilities failed MoonCode compatibility check: " +
            json_string(native_readiness, "status", default="incompatible")
          }
        Err(error) => error
      },
    ),
    "native_capabilities_readiness",
    native_readiness,
  )
}

///|
test "mooncode http contract delegates static capability shape to mooncode package" {
  let payload = @mooncode.capabilities_json().stringify()
  assert_true(payload.contains("\"component\":\"mooncode\""))
  assert_true(payload.contains("\"runtime_contract\""))
  assert_true(payload.contains("\"moonclaw_adapter_contract\""))
  assert_true(payload.contains("\"tool_contract\""))
  assert_true(payload.contains("/api/mooncode/eval-harness"))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-evidence"),
  )
  assert_true(
    payload.contains("/v1/mooncode/sessions/<id>/eval-report?book_root=<path>"),
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
    json_string(
      @mooncode.native_eval_report_contract_json(),
      "owner",
      default="",
    ),
    "moonclaw",
  )
}

///|
async test "mooncode engine status distinguishes bridge readiness from production readiness" {
  let status = mooncode_engine_status_json(
    "/tmp/moondesk-mooncode-engine-status-wbtest",
  )
  assert_eq(
    json_string(status, "bridge_mode", default=""),
    "moonclaw-daemon-v1-task-bridge",
  )
  assert_false(json_bool(status, "production_ready", default=true))
  assert_eq(
    json_string(status, "adapter_status", default=""),
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
  assert_eq(checks.length(), 10)
  let ids = checks.map(check => json_string(check, "id", default=""))
  assert_true(ids.contains("daemon_running"))
  assert_true(ids.contains("task_api"))
  assert_true(ids.contains("prompt_message_cancel"))
  assert_true(ids.contains("append_only_session_log"))
  assert_true(ids.contains("append_only_command_queue"))
  assert_true(ids.contains("typed_runtime_contract"))
  assert_true(ids.contains("moonclaw_adapter"))
  assert_true(ids.contains("eval_harness_evidence"))
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/eval-harness",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/v1/task/<id>/message",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/api/mooncode/sessions",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/v1/mooncode/sessions/<id>/commands",
    ),
  )
  assert_true(
    json_string_array_items(status, "supported_endpoints").contains(
      "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
    ),
  )
}
