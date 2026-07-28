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
  capabilities_json_for(@mooncode_core.mooncode_capability())
}

///|
fn capabilities_json_for(
  capability : @mooncode_core.MoonCodeCapability,
) -> Json {
  let native = @mooncode_core.native_capability_endpoints()
  let generated : Json = {
    "ok": true,
    "version": 3,
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
  let extra = capability.extensions.copy()
  guard generated is Object(generated_fields) else {
    return Json::empty_object()
  }
  for key, value in generated_fields {
    extra[key] = value
  }
  let ownership_extensions = capability.ownership_extensions.copy()
  ownership_extensions["sessions"] = capability.session_owner.to_json()
  ownership_extensions["canonical_conversation"] = capability.session_owner.to_json()
  ownership_extensions["optimistic_rows"] = "moondesk".to_json()
  ownership_extensions["artifacts"] = "moonbook".to_json()
  let enriched = { ..capability, extensions: extra, ownership_extensions }
  @mooncode_core.encode_mooncode_capability(enriched)
}

///|
fn mooncode_v2_consumer_readiness(payload : Json) -> Bool {
  let surface = json_object_field_or_empty(payload, "capability_surface")
  let endpoints = json_string_array_items(payload, "endpoints")
  let tools = json_string_array_items(payload, "tools")
  let required_endpoints = [
    "/v1/code/capabilities", "/v1/code/sessions?book_root=<path>", "/v1/code/sessions/<id>/turns",
    "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<canonical-decimal>&wait_ms=<ms>&poll_ms=<ms>",
  ]
  let required_tools = ["read", "edit", "write", "shell"]
  let outer_fingerprint = json_string(
    payload,
    "capability_surface_fingerprint",
    default="",
  )
  let surface_fingerprint = json_string(
    surface,
    "capability_surface_fingerprint",
    default="",
  )
  outer_fingerprint != "" &&
  outer_fingerprint == surface_fingerprint &&
  @mooncore.json_object_field(payload, "capability_surface") is Some(Object(_)) &&
  json_string(surface, "component", default="") == "mooncode" &&
  json_string(surface, "capability_contract_id", default="") ==
  json_string(payload, "capability_contract_id", default="") &&
  missing_strings(required_endpoints, endpoints).is_empty() &&
  missing_strings(required_tools, tools).is_empty()
}

///|
pub fn mooncode_negotiated_runtime_readiness(payload : Json) -> Json {
  match @mooncode_core.decode_mooncode_capability(payload) {
    Supported(capability) => {
      let owners_ok = capability.component == "mooncode" &&
        capability.provider == "moonclaw" &&
        capability.runtime_owner == "moonclaw" &&
        capability.session_owner == "moonclaw" &&
        capability.native_runtime_ready
      {
        "ok": owners_ok && mooncode_v2_consumer_readiness(payload),
        "status": if owners_ok && mooncode_v2_consumer_readiness(payload) {
          "native-runtime-ready"
        } else {
          "native-runtime-unavailable"
        },
      }
    }
    UnsupportedVersion(version) =>
      {
        "ok": false,
        "status": "unsupported-version",
        "capability_version": version,
      }
    Malformed(reason) =>
      { "ok": false, "status": "malformed", "capability_error": reason }
  }
}

///|
pub fn negotiate_capabilities_json(payload : Json) -> Json {
  match @mooncode_core.decode_mooncode_capability(payload) {
    Supported(capability) =>
      if json_bool(
          mooncode_negotiated_runtime_readiness(payload),
          "ok",
          default=false,
        ) {
        capabilities_json_for(capability)
      } else {
        {
          "ok": false,
          "capability_status": "unavailable",
          "capability_error": "MoonClaw native capability surface is not ready or compatible",
        }
      }
    UnsupportedVersion(version) =>
      {
        "ok": false,
        "capability_status": "unsupported-version",
        "capability_version": version,
      }
    Malformed(reason) =>
      {
        "ok": false,
        "capability_status": "malformed",
        "capability_error": reason,
      }
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
    mooncode_negotiated_runtime_readiness(capabilities),
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
