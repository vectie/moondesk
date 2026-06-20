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
async fn handle_mooncode_standalone_boundary_contract(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, @mooncode.standalone_boundary_json())
}

///|
async fn handle_mooncode_readiness_contract(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, @mooncode.readiness_contract_json())
}

///|
async fn mooncode_capabilities_response_json(workspace_root : String) -> Json {
  mooncode_session_with_field(
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
  let checkout_ready = json_bool(daemon, "service_configured", default=false)
  let models_probe = if running {
    moonclaw_get_json(daemon, "/v1/models")
  } else {
    Err("MoonClaw daemon is not running")
  }
  let runtime_probe = if running {
    moonclaw_get_json(daemon, "/v1/code/capabilities")
  } else {
    Err("MoonClaw daemon is not running")
  }
  let native_readiness : Json = match runtime_probe {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_readiness(capabilities)
    Err(error) => @mooncode.moonclaw_native_capabilities_unavailable(error)
  }
  let models_ready = models_probe is Ok(_)
  let runtime_contract_ready = json_bool(native_readiness, "ok", default=false)
  mooncode_session_with_field(
    @mooncode.engine_status_projection_json(
      daemon~,
      moonclaw_root=root,
      checkout_ready~,
      running~,
      models_ready~,
      runtime_contract_ready~,
      model_evidence=match models_probe {
        Ok(_) => "/v1/models responded"
        Err(error) => error
      },
      runtime_evidence=match runtime_probe {
        Ok(_) =>
          if runtime_contract_ready {
            "/v1/code/capabilities passed MoonCode native contract check"
          } else {
            "/v1/code/capabilities failed MoonCode native contract check: " +
            json_string(native_readiness, "status", default="unavailable")
          }
        Err(error) => error
      },
    ),
    "native_capabilities_readiness",
    native_readiness,
  )
}
