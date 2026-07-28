///|
fn moonflow_capability_evidence_from_values(
  platform_evidence : Json,
  command_available : Bool,
  root_configured : Bool,
  root_valid : Bool,
  root : String,
) -> Json {
  let platform_supported = json_bool(
    platform_evidence,
    "supported",
    default=false,
  )
  let configuration_valid = root_configured && root_valid
  let available = platform_supported && command_available && configuration_valid
  {
    "available": available,
    "reason": if !platform_supported {
      "unsupported-platform"
    } else if !command_available {
      "runtime-command-unavailable"
    } else if !root_configured {
      "runtime-root-not-configured"
    } else if !root_valid {
      "runtime-root-unavailable"
    } else {
      "capability-ready"
    },
    "root": root,
    "platform_evidence": platform_evidence,
    "installation_evidence": {
      "installed": command_available,
      "source": if command_available {
        "moon-command"
      } else {
        "none"
      },
      "reason": if command_available {
        "runtime-command-available"
      } else {
        "runtime-command-unavailable"
      },
    },
    "configuration_evidence": {
      "configured": root_configured,
      "valid": configuration_valid,
      "reason": if !root_configured {
        "runtime-root-not-configured"
      } else if !root_valid {
        "runtime-root-unavailable"
      } else {
        "configuration-valid"
      },
    },
  }
}

///|
async fn moonflow_capability_evidence() -> Json {
  let root = @sys.get_env_var("MOONFLOW_ROOT").unwrap_or("")
  let moon = moonclaw_default_moon_command()
  let platform = town_platform_evidence()
  moonflow_capability_evidence_from_values(
    platform,
    service_command_available(moon, if root == "" { "." } else { root }),
    root != "",
    root != "" &&
    is_directory(root) &&
    @fsx.exists(@pathx.join(root, "moon.mod")),
    root,
  )
}

///|
async fn handle_moonflow_capability(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let evidence = moonflow_capability_evidence()
  let available = json_bool(evidence, "available", default=false)
  send_json(
    conn,
    method_,
    api_contract_response(
      evidence,
      ok=true,
      status=if available { "ready" } else { "unavailable" },
      message=if available {
        "Flow preparation is available"
      } else {
        "Flow preparation is not available in the current setup"
      },
      next_action=if available { "prepare_flow" } else { "review_flow_setup" },
    ),
  )
}
