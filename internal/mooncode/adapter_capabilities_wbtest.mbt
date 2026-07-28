///|
fn supported_runtime_capability_subset(protocol : String) -> Json {
  let required_endpoints = [
    "/v1/code/capabilities", "/v1/code/sessions?book_root=<path>", "/v1/code/sessions/<id>/turns",
    "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<canonical-decimal>&wait_ms=<ms>&poll_ms=<ms>",
  ]
  let required_tools = ["read", "edit", "write", "shell"]
  {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": protocol,
    "capability_contract_id": "mooncode-native-capability-surface.v2",
    "capability_surface_fingerprint": "subset-fingerprint",
    "capability_surface": {
      "component": "mooncode",
      "protocol": protocol,
      "capability_contract_id": "mooncode-native-capability-surface.v2",
      "capability_surface_fingerprint": "subset-fingerprint",
      "required_endpoints": required_endpoints,
      "required_tools": required_tools,
      "conversation_contract_id": "moonsuite-conversation.v2",
      "journal_contract_id": "moonsuite-conversation-journal.v2",
    },
    "native_runtime_ready": true,
    "runtime_mode": "native",
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
    "endpoints": required_endpoints,
    "tools": required_tools,
    "conversation_contract_id": "moonsuite-conversation.v2",
    "session_contract_id": "mooncode-session.v2",
  }
}

///|
test "adapter serializes current v1 capability with transport parity" {
  let payload = capabilities_json()
  assert_true(
    @mooncode_core.decode_mooncode_capability(payload) is Supported(value) &&
    value.protocol == "mooncode.v1" &&
    value.session_owner == "moonclaw",
  )
  assert_eq(json_int(payload, "version", default=0), 3)
}

///|
test "adapter negotiates the deliberate v1 and v2 consumer subset" {
  for protocol in ["mooncode.v1", "mooncode.v2"] {
    let negotiated = negotiate_capabilities_json(
      supported_runtime_capability_subset(protocol),
    )
    assert_true(json_bool(negotiated, "native_runtime_ready", default=false))
    assert_eq(json_string(negotiated, "protocol", default=""), protocol)
    assert_eq(
      json_string(negotiated, "capability_surface_fingerprint", default=""),
      "subset-fingerprint",
    )
    assert_eq(
      json_string(negotiated, "session_contract_id", default=""),
      "mooncode-session.v2",
    )
  }
}

///|
test "adapter rejects semantic incompatibility without calling it malformed" {
  let base = supported_runtime_capability_subset("mooncode.v1")
  for
    field in [
      "native_runtime_ready", "runtime_owner", "session_owner", "provider", "component",
      "capability_surface_fingerprint", "capability_surface", "endpoints", "tools",
    ] {
    let incompatible = json_without_field(base, field)
    let negotiated = negotiate_capabilities_json(incompatible)
    assert_eq(
      json_string(negotiated, "capability_status", default=""),
      if field == "native_runtime_ready" ||
        field == "runtime_owner" ||
        field == "session_owner" ||
        field == "provider" ||
        field == "component" {
        "malformed"
      } else {
        "unavailable"
      },
    )
  }
  let not_ready = session_with_field(
    base,
    "native_runtime_ready",
    false.to_json(),
  )
  assert_eq(
    json_string(
      negotiate_capabilities_json(not_ready),
      "capability_status",
      default="",
    ),
    "unavailable",
  )
  let wrong_owner = session_with_field(
    base,
    "runtime_owner",
    "moondesk".to_json(),
  )
  assert_eq(
    json_string(
      negotiate_capabilities_json(wrong_owner),
      "capability_status",
      default="",
    ),
    "unavailable",
  )
  let mismatched_surface = session_with_field(
    json_object_field_or_empty(base, "capability_surface"),
    "capability_surface_fingerprint",
    "different-fingerprint".to_json(),
  )
  let mismatch = session_with_field(
    base, "capability_surface", mismatched_surface,
  )
  assert_eq(
    json_string(
      negotiate_capabilities_json(mismatch),
      "capability_status",
      default="",
    ),
    "unavailable",
  )
}

///|
test "adapter keeps explicit version incompatibility distinct" {
  let incompatible_payload = session_with_field(
    supported_runtime_capability_subset("mooncode.v1"),
    "capability_contract_id",
    "mooncode-native-capability-surface.v8".to_json(),
  )
  let incompatible = negotiate_capabilities_json(incompatible_payload)
  assert_eq(
    json_string(incompatible, "capability_status", default=""),
    "unsupported-version",
  )
}
