///|
fn adapter_capability_surface(
  capability : @mooncode_core.MoonCodeCapability,
) -> Json {
  match capability.extensions.get("capability_surface") {
    Some(surface) => surface
    None => Json::empty_object()
  }
}

///|
fn adapter_surface_field(surface : Json, field : String) -> Json {
  @mooncore.json_object_field(surface, field).unwrap_or(Json::empty_object())
}

///|
fn adapter_surface_strings(surface : Json, field : String) -> Array[String] {
  json_string_array_items(surface, field)
}

///|
fn adapter_surface_command_actions(surface : Json) -> Array[Json] {
  json_array_items(
    adapter_surface_field(surface, "command_action_contract"),
    "actions",
  ).map(spec => {
    "action": json_string(spec, "action", default=""),
    "control": json_string(spec, "control", default=""),
    "approval": json_string(spec, "approval", default=""),
  })
}

///|
fn adapter_surface_advertised_actions(surface : Json) -> Array[String] {
  json_string_array_items(
    adapter_surface_field(surface, "command_action_contract"),
    "advertised_actions",
  )
}

///|
fn adapter_surface_tool_contract(surface : Json) -> Json {
  adapter_surface_field(surface, "runtime_tool_contract")
}

///|
fn adapter_surface_tool_call_contract(surface : Json) -> Json {
  adapter_surface_field(surface, "runtime_tool_call_contract")
}

///|
fn adapter_surface_tool_specs(surface : Json) -> Array[Json] {
  json_array_items(surface, "runtime_tool_capability_specs")
}

///|
fn adapter_surface_endpoint(surface : Json, fragment : String) -> String {
  for endpoint in adapter_surface_strings(surface, "required_endpoints") {
    if endpoint.contains(fragment) {
      return endpoint
    }
  }
  ""
}

///|
fn adapter_journal_contract_id(surface : Json) -> String {
  json_string(surface, "journal_write_contract_id", default="")
}

///|
pub fn capabilities_json() -> Json {
  capabilities_json_for(@mooncode_core.mooncode_capability())
}

///|
fn capabilities_json_for(
  capability : @mooncode_core.MoonCodeCapability,
) -> Json {
  let surface = adapter_capability_surface(capability)
  let generated : Json = {
    "ok": true,
    "version": 3,
    "session_protocol": {
      "mutation_endpoint": desktop_session_commands_endpoint(),
      "canonical_watch_endpoint": desktop_session_watch_endpoint(),
      "canonical_watch_contract": adapter_surface_field(
        surface, "conversation_watch_write_contract",
      ),
      "native_submit_turn_endpoint": adapter_surface_endpoint(surface, "/turns"),
      "native_session_listing_endpoint": adapter_surface_endpoint(
        surface, "format=listing",
      ),
      "native_session_show_endpoint": adapter_surface_endpoint(
        surface, "/sessions/<id>?",
      ),
      "native_stream_endpoint": adapter_surface_endpoint(surface, "/stream?"),
      "transport": "submit one durable turn, then watch the selected canonical session",
      "durability": "MoonClaw is the sole durable command, journal, session, and conversation owner.",
      "rendering": "MoonDesk renders canonical turns and never rebuilds chat from runtime logs.",
      "commands": adapter_surface_advertised_actions(surface),
    },
    "runtime_contract": {
      "owner": "moonclaw",
      "journal_contract_id": adapter_journal_contract_id(surface),
      "session_store": {
        "owner": "moonclaw",
        "journal_contract_id": adapter_journal_contract_id(surface),
        "shape": "replaceable session.json checkpoint plus authoritative journal.jsonl",
      },
    },
    "desktop_route_contracts": Json::array(desktop_projection_route_contracts()),
    "tool_contract": adapter_surface_tool_contract(surface),
    "tool_call_contract": adapter_surface_tool_call_contract(surface),
    "commands": adapter_surface_command_actions(surface),
    "tools": adapter_surface_tool_specs(surface).map(spec => {
      json_string(spec, "id", default="")
    }),
    "tool_specs": adapter_surface_tool_specs(surface),
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
  let endpoints = json_string_array_items(surface, "required_endpoints")
  let tools = json_string_array_items(surface, "required_tools")
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
    Ok(capability) => {
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
    Err(UnsupportedVersion(version)) =>
      {
        "ok": false,
        "status": "unsupported-version",
        "capability_version": version,
      }
    Err(Malformed(reason)) =>
      { "ok": false, "status": "malformed", "capability_error": reason }
    Err(Absent) => abort("capability decoder does not return an absent result")
    Err(UnsupportedProtocol(_)) =>
      abort("capability decoder does not return UnsupportedProtocol")
    Err(UnsupportedContract(_)) =>
      abort("capability decoder does not return UnsupportedContract")
    Err(Stale(_)) => abort("capability decoder does not return Stale")
  }
}

///|
pub fn negotiate_capabilities_json(payload : Json) -> Json {
  match @mooncode_core.decode_mooncode_capability(payload) {
    Ok(capability) =>
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
    Err(UnsupportedVersion(version)) =>
      {
        "ok": false,
        "capability_status": "unsupported-version",
        "capability_version": version,
      }
    Err(Malformed(reason)) =>
      {
        "ok": false,
        "capability_status": "malformed",
        "capability_error": reason,
      }
    Err(Absent) => abort("capability decoder does not return an absent result")
    Err(UnsupportedProtocol(_)) =>
      abort("capability decoder does not return UnsupportedProtocol")
    Err(UnsupportedContract(_)) =>
      abort("capability decoder does not return UnsupportedContract")
    Err(Stale(_)) => abort("capability decoder does not return Stale")
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
  let capability = @mooncode_core.mooncode_capability()
  let surface = adapter_capability_surface(capability)
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "capability_contract_id": capability.capability_contract_id,
    "capability_contract_ok": false,
    "expected_capability_surface": surface,
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
  let surface = adapter_capability_surface(@mooncode_core.mooncode_capability())
  json_string_array_items(
    adapter_surface_tool_contract(surface),
    "supported_tools",
  )
}

///|
pub fn tool_contract_json() -> Json {
  adapter_surface_tool_contract(
    adapter_capability_surface(@mooncode_core.mooncode_capability()),
  )
}

///|
pub fn tool_contract_tool_ids(contract : Json) -> Array[String] {
  let ids : Array[String] = []
  for tool in json_array_items(contract, "tools") {
    let id = json_string(tool, "id", default="")
    if id != "" {
      ids.push(id)
    }
  }
  ids
}
