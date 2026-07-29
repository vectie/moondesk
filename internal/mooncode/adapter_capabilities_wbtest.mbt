///|
fn supported_runtime_capability_subset(protocol : String) -> Json {
  let native = @mooncode_core.native_capability_endpoints()
  let required_endpoints = [
    native.capabilities,
    native.session_list,
    native.session_turns,
    native.stream,
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
      "conversation_contract": {
        "contract_id": "moonsuite-conversation.v3",
        "sequence_encoding": "canonical nonnegative decimal JSON string",
      },
      "conversation_watch_write_contract": {
        "contract_id": "moonsuite-conversation-watch.v2",
      },
      "conversation_watch_read_contract_ids": [
        "moonsuite-conversation-watch.v1", "moonsuite-conversation-watch.v2",
      ],
      "journal_write_contract_id": "moonsuite-conversation-journal.v2",
      "journal_read_contract_ids": [
        "moonsuite-conversation-journal.v1", "moonsuite-conversation-journal.v2",
      ],
      "session_contracts": {
        "snapshot": "mooncode-session-snapshot.v2",
        "record": "mooncode-session-record.v2",
        "listing": "mooncode-session-listing.v2",
      },
    },
    "executable_book_lifecycle_contract_id": "mooncode-executable-book-lifecycle.v2",
    "executable_book_lifecycle_contract": {
      "contract_id": "mooncode-executable-book-lifecycle.v2",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "acceptance_owner": "bookkeeper",
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
test "adapter negotiates only the canonical v1 wire protocol" {
  let negotiated = negotiate_capabilities_json(
    supported_runtime_capability_subset("mooncode.v1"),
  )
  assert_true(json_bool(negotiated, "native_runtime_ready", default=false))
  assert_eq(json_string(negotiated, "protocol", default=""), "mooncode.v1")
  let unsupported = negotiate_capabilities_json(
    supported_runtime_capability_subset("mooncode.v2"),
  )
  assert_false(json_bool(unsupported, "native_runtime_ready", default=false))
  assert_eq(
    json_string(unsupported, "capability_status", default=""),
    "unsupported-version",
  )
}

///|
test "adapter rejects semantic incompatibility without calling it malformed" {
  let base = supported_runtime_capability_subset("mooncode.v1")
  for
    field in [
      "native_runtime_ready", "runtime_owner", "session_owner", "provider", "component",
      "capability_surface_fingerprint", "capability_surface",
    ] {
    let incompatible = json_without_field(base, field)
    let negotiated = negotiate_capabilities_json(incompatible)
    assert_eq(
      json_string(negotiated, "capability_status", default=""),
      if field == "capability_surface_fingerprint" {
        "unavailable"
      } else {
        "malformed"
      },
    )
  }
  for field in ["required_endpoints", "required_tools"] {
    let capability_surface = json_without_field(
      json_object_field_or_empty(base, "capability_surface"),
      field,
    )
    let incompatible = session_with_field(
      base, "capability_surface", capability_surface,
    )
    assert_eq(
      json_string(
        negotiate_capabilities_json(incompatible),
        "capability_status",
        default="",
      ),
      "unavailable",
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
