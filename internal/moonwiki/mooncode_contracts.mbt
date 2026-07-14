///|
async fn handle_mooncode_capabilities(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, mooncode_capabilities_response_json(workspace_root))
}

///|
async fn handle_mooncode_status(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let engine = mooncode_engine_status_json(workspace_root)
  let ready = json_bool(engine, "ready", default=false)
  let native_ready = json_bool(engine, "native_runtime_ready", default=false)
  let status = if ready {
    "ready"
  } else if native_ready {
    "model_unavailable"
  } else {
    "runtime_unavailable"
  }
  send_json(
    conn,
    method_,
    api_contract_response(
      {
        "engine_status": engine,
        "session_count": moonclaw_runtime_session_listing_rows(workspace_root).length(),
      },
      ok=ready,
      status~,
      message=if ready {
        "MoonCode runtime is ready"
      } else if native_ready {
        "MoonCode model is not available"
      } else {
        "MoonCode runtime is not available"
      },
      next_action=if ready {
        "send_mooncode_prompt"
      } else if native_ready {
        "configure_or_start_model_provider"
      } else {
        "inspect_moonclaw_status"
      },
    ),
  )
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
  let models_ready = match models_probe {
    Ok(payload) => moonclaw_models_response_ready(payload)
    Err(_) => false
  }
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
        Ok(payload) =>
          if models_ready {
            "/v1/models advertised executable default `\{json_string(payload, "default_model", default="")}`"
          } else {
            "/v1/models returned no executable default model"
          }
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

///|
fn moonclaw_models_response_ready(payload : Json) -> Bool {
  let default_model = json_string(payload, "default_model", default="")
  default_model != "" &&
  json_bool(payload, "ready", default=false) &&
  json_array_items(payload, "models").any(model => {
    json_string(model, "name", default="") == default_model
  })
}
