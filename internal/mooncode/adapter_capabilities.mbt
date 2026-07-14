///|
fn command_specs_json() -> Array[Json] {
  @mooncode_core.command_advertised_actions().map(action => {
    "action": action,
    "control": @mooncode_core.command_action_control(action),
    "approval": @mooncode_core.command_action_approval(action),
  })
}

///|
pub fn capabilities_json() -> Json {
  let native = @mooncode_core.native_capability_endpoints()
  {
    "ok": true,
    "component": "mooncode",
    "version": 3,
    "ownership": {
      "sessions": "moonclaw",
      "canonical_conversation": "moonclaw",
      "optimistic_rows": "moondesk",
      "artifacts": "moonbook",
    },
    "session_protocol": {
      "mutation_endpoint": desktop_session_commands_endpoint(),
      "canonical_watch_endpoint": desktop_session_watch_endpoint(),
      "canonical_watch_contract": @mooncode_core.conversation_watch_contract_json(),
      "native_submit_turn_endpoint": native.session_turns,
      "native_session_listing_endpoint": native.session_listing,
      "native_session_show_endpoint": native.session_show,
      "native_stream_endpoint": native.stream,
      "transport": "submit one durable turn, then watch the selected canonical session",
      "durability": "MoonClaw is the sole durable command, journal, session, and conversation owner.",
      "rendering": "MoonDesk renders canonical turns and never rebuilds chat from runtime logs.",
      "commands": @mooncode_core.command_advertised_actions(),
    },
    "runtime_contract": {
      "owner": "moonclaw",
      "journal_contract_id": @mooncode_core.journal_contract_id(),
      "session_store": {
        "owner": "moonclaw",
        "journal_contract_id": @mooncode_core.journal_contract_id(),
        "shape": "replaceable session.json checkpoint plus authoritative journal.jsonl",
      },
    },
    "desktop_route_contracts": Json::array(desktop_projection_route_contracts()),
    "tool_contract": tool_contract_json(),
    "tool_call_contract": @mooncode_core.runtime_tool_call_contract_json(),
    "commands": command_specs_json(),
    "tools": @mooncode_core.runtime_tool_capability_names(),
    "tool_specs": @mooncode_core.runtime_tool_capability_specs(),
  }
}

///|
fn missing_strings(
  required : Array[String],
  actual : Array[String],
) -> Array[String] {
  required.filter(item => !actual.contains(item))
}

///|
pub fn moonclaw_native_capabilities_readiness(capabilities : Json) -> Json {
  let required_endpoints = @mooncode_core.native_capability_required_endpoints()
  let required_tools = @mooncode_core.native_capability_required_tools()
  let endpoints = json_string_array_items(capabilities, "endpoints")
  let tools = json_string_array_items(capabilities, "tools")
  let missing_endpoints = missing_strings(required_endpoints, endpoints)
  let missing_tools = missing_strings(required_tools, tools)
  let expected_contract_id = @mooncode_core.native_capability_contract_id()
  let daemon_contract_id = json_string(
    capabilities,
    "capability_contract_id",
    default="",
  )
  let surface = json_object_field_or_empty(capabilities, "capability_surface")
  let surface_present = @mooncore.json_object_field(
      capabilities, "capability_surface",
    )
    is Some(Object(_))
  let expected_fingerprint = @mooncode_core.native_capability_surface_fingerprint()
  let surface_missing_endpoints = missing_strings(
    required_endpoints,
    json_string_array_items(surface, "required_endpoints"),
  )
  let surface_missing_tools = missing_strings(
    required_tools,
    json_string_array_items(surface, "required_tools"),
  )
  let component_ok = json_string(capabilities, "component", default="") ==
    "mooncode"
  let protocol_ok = json_string(capabilities, "protocol", default="") ==
    protocol_version()
  let contract_ok = daemon_contract_id == expected_contract_id
  let surface_ok = surface_present &&
    json_string(surface, "component", default="") == "mooncode" &&
    json_string(surface, "protocol", default="") == protocol_version() &&
    json_string(surface, "capability_contract_id", default="") ==
    expected_contract_id &&
    json_string(surface, "capability_surface_fingerprint", default="") ==
    expected_fingerprint &&
    surface_missing_endpoints.is_empty() &&
    surface_missing_tools.is_empty()
  let runtime_ready = json_bool(
    capabilities,
    "native_runtime_ready",
    default=false,
  )
  let ok = component_ok &&
    protocol_ok &&
    contract_ok &&
    surface_ok &&
    runtime_ready &&
    missing_endpoints.is_empty() &&
    missing_tools.is_empty()
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "ok": ok,
    "status": if ok {
      "native-runtime-ready"
    } else {
      "native-runtime-unavailable"
    },
    "component_ok": component_ok,
    "protocol_ok": protocol_ok,
    "capability_contract_id": expected_contract_id,
    "daemon_capability_contract_id": daemon_contract_id,
    "capability_contract_ok": contract_ok,
    "expected_capability_surface": @mooncode_core.native_capability_surface_json(),
    "daemon_capability_surface": surface,
    "capability_surface_present": surface_present,
    "capability_surface_ok": surface_ok,
    "capability_surface_fingerprint": expected_fingerprint,
    "native_runtime_ready": runtime_ready,
    "missing_endpoints": string_array_json(missing_endpoints),
    "missing_tools": string_array_json(missing_tools),
  }
}

///|
pub fn moonclaw_native_capabilities_unavailable(error : String) -> Json {
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "capability_contract_id": @mooncode_core.native_capability_contract_id(),
    "capability_contract_ok": false,
    "expected_capability_surface": @mooncode_core.native_capability_surface_json(),
    "capability_surface_present": false,
    "capability_surface_ok": false,
    "ok": false,
    "status": "native-runtime-unavailable",
    "error": error,
  }
}

///|
pub fn moonclaw_native_capabilities_ready(capabilities : Json) -> Bool {
  json_bool(
    moonclaw_native_capabilities_readiness(capabilities),
    "ok",
    default=false,
  )
}

///|
fn engine_check(
  id : String,
  label : String,
  status : String,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "status": status, "evidence": evidence }
}

///|
pub fn engine_status_projection_json(
  daemon~ : Json,
  moonclaw_root~ : String,
  checkout_ready~ : Bool,
  running~ : Bool,
  models_ready~ : Bool,
  runtime_contract_ready~ : Bool,
  model_evidence~ : String,
  runtime_evidence~ : String,
) -> Json {
  let native_ready = running && runtime_contract_ready
  let ready = native_ready && models_ready
  let runtime_status = if native_ready {
    "native-ready"
  } else {
    "missing-runtime"
  }
  let status = if ready {
    "native-ready"
  } else if native_ready {
    "model-unavailable"
  } else if running {
    "native-runtime-missing"
  } else if checkout_ready {
    "daemon-not-running"
  } else {
    "moonclaw-service-missing"
  }
  {
    "ok": ready,
    "status": status,
    "ready": ready,
    "runtime_mode": if native_ready {
      "native-mooncode-runtime"
    } else {
      "runtime-unavailable"
    },
    "native_runtime_ready": native_ready,
    "model_runtime_ready": ready,
    "runtime_status": runtime_status,
    "moonclaw_root": moonclaw_root,
    "message": json_string(daemon, "message", default=""),
    "daemon": daemon,
    "supported_endpoints": string_array_json(supported_engine_endpoints()),
    "checks": [
      engine_check(
        "moonclaw_service",
        "MoonClaw service",
        if checkout_ready {
          "ready"
        } else {
          "missing"
        },
        if checkout_ready {
          moonclaw_root
        } else {
          "MoonClaw service is not configured"
        },
      ),
      engine_check(
        "daemon_running",
        "MoonClaw daemon",
        if running {
          "ready"
        } else {
          "missing"
        },
        json_string(daemon, "message", default="MoonClaw daemon is not running"),
      ),
      engine_check(
        "model_api",
        "Model API",
        if models_ready {
          "ready"
        } else if running {
          "missing"
        } else {
          "blocked"
        },
        model_evidence,
      ),
      engine_check(
        "typed_runtime_contract",
        "Typed MoonCode runtime contract",
        if runtime_contract_ready {
          "ready"
        } else {
          "missing"
        },
        runtime_evidence,
      ),
      engine_check(
        "transactional_session_journal", "Transactional session journal", "ready",
        "MoonClaw owns one authoritative journal.jsonl under moonsuite-conversation-journal.v1; MoonDesk stores no replay logs.",
      ),
    ],
  }
}

///|
pub fn runtime_tool_names() -> Array[String] {
  @mooncode_core.runtime_tool_names()
}

///|
pub fn tool_contract_json() -> Json {
  @mooncode_core.runtime_tool_contract_json()
}

///|
pub fn tool_contract_tool_ids(contract : Json) -> Array[String] {
  @mooncode_core.runtime_tool_contract_tool_ids(contract)
}
