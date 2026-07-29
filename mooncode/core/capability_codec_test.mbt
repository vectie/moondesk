///|
fn supported_capability_codec_fixture(protocol : String) -> Json {
  {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": protocol,
    "capability_contract_id": "mooncode-native-capability-surface.v2",
    "capability_surface_fingerprint": "sha256:fixture",
    "capability_surface": {
      "capability_contract_id": "mooncode-native-capability-surface.v2",
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
      "commands": ["session.create"],
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
    "endpoints": ["/v1/code/sessions"],
    "tools": ["read"],
  }
}

///|
test "capability codec rejects an incomplete capability surface contract" {
  let payload = supported_capability_codec_fixture("mooncode.v1")
  guard payload is Object(fields) else { fail("fixture") }
  fields["capability_surface"] = {
    "capability_contract_id": "mooncode-native-capability-surface.v2",
  }
  assert_true(@core.decode_mooncode_capability(payload) is Malformed(_))
}

///|
test "capability codec rejects a non-moonclaw lifecycle runtime owner" {
  let payload = supported_capability_codec_fixture("mooncode.v1")
  guard payload is Object(fields) else { fail("fixture") }
  guard fields["executable_book_lifecycle_contract"] is Object(contract) else {
    fail("fixture")
  }
  contract["runtime_owner"] = "moondesk"
  assert_true(@core.decode_mooncode_capability(payload) is Malformed(_))
}

///|
test "capability codec accepts only the canonical v1 wire protocol" {
  assert_true(
    @core.decode_mooncode_capability(
      supported_capability_codec_fixture("mooncode.v1"),
    )
    is Supported(value) &&
    value.protocol == "mooncode.v1" &&
    value.native_runtime_ready,
  )
  assert_true(
    @core.decode_mooncode_capability(
      supported_capability_codec_fixture("mooncode.v2"),
    )
    is UnsupportedVersion(2),
  )
}

///|
test "capability codec reports explicit incompatible runtime versions" {
  assert_true(
    @core.decode_mooncode_capability(
      supported_capability_codec_fixture("mooncode.v9"),
    )
    is UnsupportedVersion(9),
  )
  let incompatible : Json = {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": "mooncode.v1",
    "capability_contract_id": "mooncode-native-capability-surface.v7",
    "native_runtime_ready": true,
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
  }
  assert_true(
    @core.decode_mooncode_capability(incompatible) is UnsupportedVersion(7),
  )
  assert_true(
    @core.decode_mooncode_capability({ "component": "mooncode" })
    is Malformed(_),
  )
}

///|
test "capability codec preserves root and optional ownership extensions" {
  let future = supported_capability_codec_fixture("mooncode.v1")
  guard future is Object(fields) else { fail("fixture") }
  fields["future_root"] = { "enabled": true }
  fields["ownership"] = { "future_owner": "future-product" }
  guard @core.decode_mooncode_capability(future) is Supported(capability) else {
    fail("expected supported capability")
  }
  let encoded = @core.encode_mooncode_capability(capability)
  guard encoded
    is {
      "future_root": { "enabled": true },
      "ownership": { "future_owner": "future-product", .. },
      "capability_surface_fingerprint": "sha256:fixture",
      ..
    } else {
    fail("extensions were not preserved")
  }
}
