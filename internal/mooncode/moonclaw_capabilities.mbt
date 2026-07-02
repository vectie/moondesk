///|
pub fn moonclaw_runtime_contract_json() -> Json {
  {
    "kind": "mooncode-moonclaw-runtime-contract",
    "protocol": protocol_version(),
    "owner": "mooncode",
    "runtime_owner": "moonclaw",
    "reference": "moonclaw:/v1/code",
    "daemon": {
      "native_target": "/v1/code/capabilities plus /v1/code/sessions?book_root=<path>, /v1/code/sessions?book_root=<path>&format=json, /v1/code/sessions/<id>?book_root=<path>, /v1/code/sessions/<id>/runtime-control?book_root=<path>, /v1/code/sessions/<id>/runtime-claim?book_root=<path>, /v1/code/sessions/<id>/runtime-turn?book_root=<path>, /v1/code/sessions/<id>/runtime-loop?book_root=<path>, /v1/code/sessions/<id>/runtime-service?book_root=<path>, /v1/code/sessions/<id>/runtime-events?book_root=<path>, /v1/code/sessions/<id>/tool-exec?book_root=<path>, /v1/code/sessions/<id>/commands, /v1/code/sessions/<id>/eval-report?book_root=<path>, and /v1/code/sessions/<id>/package-result?book_root=<path>",
    },
    "event_mapping": moonclaw_event_mapping_json(),
    "tool_mapping": Json::array(moonclaw_tool_mapping_rows()),
    "runtime_gap": "Current MoonClaw daemon routes now expose native MoonCode capabilities, cold product-home sidecar list/show, native runtime-control projection, native runtime-claim receipts, native runtime-turn execution receipts for explicit, deterministic, or bounded model-planned tool calls with tool-result feedback plus planner reasoning/assistant/tool-call events, native runtime-loop queue supervision, a daemon runtime-service supervisor, native runtime-events evidence ingress, native read/edit/write/apply_patch/revert_patch/shell/moon_ide/moon_cmd/moon_check/finish tool execution, command ingestion, session stream snapshots, native tool_harness/file_edit/patch_review/command_execution/package_output eval-report evidence, prompt/steer/cancel controls, package-result acknowledgement, and MoonSuite product-home durable MoonCode sidecars. Remaining native gap is readiness long-running service lifecycle UX, diff-aware review polish, richer resume/cancel orchestration, and broader model-backed coding eval cases.",
    "boundary": {
      "moondesk": "records MoonCode command/session/review state and consumes native MoonClaw MoonCode runtime events",
      "moonclaw": "executes tools, streams events, enforces approvals, and reports proof",
      "mooncode": "defines the reusable protocol and runtime mapping",
    },
  }
}

///|
pub fn moonclaw_native_required_endpoints() -> Array[String] {
  native_capability_required_endpoints()
}

///|
pub fn moonclaw_native_required_tools() -> Array[String] {
  native_capability_required_tools()
}

///|
pub fn moonclaw_native_capability_contract_id() -> String {
  native_capability_contract_id()
}

///|
fn moonclaw_native_capability_surface_present(capabilities : Json) -> Bool {
  match rq_json_object_field(capabilities, "capability_surface") {
    Some(Object(_)) => true
    _ => false
  }
}

///|
pub fn moonclaw_native_capabilities_readiness(capabilities : Json) -> Json {
  let required_endpoints = moonclaw_native_required_endpoints()
  let required_tools = moonclaw_native_required_tools()
  let expected_contract_id = moonclaw_native_capability_contract_id()
  let endpoints = rq_json_string_array_items(capabilities, "endpoints")
  let tools = rq_json_string_array_items(capabilities, "tools")
  let missing_endpoints = moonclaw_missing_strings(
    required_endpoints, endpoints,
  )
  let missing_tools = moonclaw_missing_strings(required_tools, tools)
  let component_ok = moonclaw_json_string(capabilities, "component", default="") ==
    "mooncode"
  let protocol_ok = moonclaw_json_string(capabilities, "protocol", default="") ==
    protocol_version()
  let daemon_contract_id = moonclaw_json_string(
    capabilities,
    "capability_contract_id",
    default="",
  )
  let capability_contract_ok = daemon_contract_id == expected_contract_id
  let capability_surface = rq_json_object_field_or_empty(
    capabilities, "capability_surface",
  )
  let capability_surface_present = moonclaw_native_capability_surface_present(
    capabilities,
  )
  let surface_component_ok = moonclaw_json_string(
      capability_surface,
      "component",
      default="",
    ) ==
    "mooncode"
  let surface_protocol_ok = moonclaw_json_string(
      capability_surface,
      "protocol",
      default="",
    ) ==
    protocol_version()
  let surface_contract_id = moonclaw_json_string(
    capability_surface,
    "capability_contract_id",
    default="",
  )
  let surface_contract_ok = surface_contract_id == expected_contract_id
  let expected_surface_fingerprint = native_capability_surface_fingerprint()
  let surface_fingerprint = moonclaw_json_string(
    capability_surface,
    "capability_surface_fingerprint",
    default="",
  )
  let surface_fingerprint_ok = surface_fingerprint ==
    expected_surface_fingerprint
  let surface_missing_endpoints = moonclaw_missing_strings(
    required_endpoints,
    rq_json_string_array_items(capability_surface, "required_endpoints"),
  )
  let surface_missing_tools = moonclaw_missing_strings(
    required_tools,
    rq_json_string_array_items(capability_surface, "required_tools"),
  )
  let capability_surface_ok = capability_surface_present &&
    surface_component_ok &&
    surface_protocol_ok &&
    surface_contract_ok &&
    surface_fingerprint_ok &&
    surface_missing_endpoints.length() == 0 &&
    surface_missing_tools.length() == 0
  let runtime_ready = rq_json_bool(
    capabilities,
    "native_runtime_ready",
    default=false,
  )
  let ok = component_ok &&
    protocol_ok &&
    capability_contract_ok &&
    capability_surface_ok &&
    runtime_ready &&
    missing_endpoints.length() == 0 &&
    missing_tools.length() == 0
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
    "capability_contract_ok": capability_contract_ok,
    "expected_capability_surface": native_capability_surface_json(),
    "daemon_capability_surface": capability_surface,
    "capability_surface_present": capability_surface_present,
    "capability_surface_fingerprint": expected_surface_fingerprint,
    "daemon_capability_surface_fingerprint": surface_fingerprint,
    "capability_surface_fingerprint_ok": surface_fingerprint_ok,
    "daemon_capability_surface_contract_id": surface_contract_id,
    "capability_surface_ok": capability_surface_ok,
    "capability_surface_component_ok": surface_component_ok,
    "capability_surface_protocol_ok": surface_protocol_ok,
    "capability_surface_contract_ok": surface_contract_ok,
    "capability_surface_missing_endpoint_count": surface_missing_endpoints.length(),
    "capability_surface_missing_endpoints": Json::array(
      [
        for item in surface_missing_endpoints => Json::string(item)
      ],
    ),
    "capability_surface_missing_tool_count": surface_missing_tools.length(),
    "capability_surface_missing_tools": Json::array(
      [
        for item in surface_missing_tools => Json::string(item)
      ],
    ),
    "native_runtime_ready": runtime_ready,
    "required_endpoint_count": required_endpoints.length(),
    "missing_endpoint_count": missing_endpoints.length(),
    "missing_endpoints": Json::array(
      [
        for item in missing_endpoints => Json::string(item)
      ],
    ),
    "required_tool_count": required_tools.length(),
    "missing_tool_count": missing_tools.length(),
    "missing_tools": Json::array(
      [
        for item in missing_tools => Json::string(item)
      ],
    ),
    "rule": "Moondesk may use MoonClaw native MoonCode runtime only when the daemon advertises the current protocol, capability surface object, endpoint set, and tool-execution set owned by the MoonCode boundary.",
  }
}

///|
pub fn moonclaw_native_capabilities_unavailable(error : String) -> Json {
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "capability_contract_id": moonclaw_native_capability_contract_id(),
    "capability_contract_ok": false,
    "expected_capability_surface": native_capability_surface_json(),
    "capability_surface_present": false,
    "capability_surface_ok": false,
    "ok": false,
    "status": "native-runtime-unavailable",
    "error": error,
    "rule": "Moondesk may use MoonClaw native MoonCode runtime only when the daemon advertises the current protocol, capability surface object, endpoint set, and tool-execution set owned by the MoonCode boundary.",
  }
}

///|
pub fn moonclaw_native_capabilities_ready(capabilities : Json) -> Bool {
  rq_json_bool(
    moonclaw_native_capabilities_readiness(capabilities),
    "ok",
    default=false,
  )
}
