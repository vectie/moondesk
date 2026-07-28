///|
fn supported_capability_codec_fixture(protocol : String) -> Json {
  {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": protocol,
    "capability_contract_id": "mooncode-native-capability-surface.v2",
    "capability_surface_fingerprint": "sha256:fixture",
    "capability_surface": { "commands": ["session.create"] },
    "native_runtime_ready": true,
    "runtime_mode": "native",
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
    "endpoints": ["/v1/code/sessions"],
    "tools": ["read"],
  }
}

///|
test "capability codec accepts supported v1 and compatible v2 shapes" {
  for protocol in ["mooncode.v1", "mooncode.v2"] {
    assert_true(
      @core.decode_mooncode_capability(
        supported_capability_codec_fixture(protocol),
      )
      is Supported(value) &&
      value.protocol == protocol &&
      value.native_runtime_ready,
    )
  }
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
  let future : Json = {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": "mooncode.v1",
    "capability_contract_id": "mooncode-native-capability-surface.v2",
    "native_runtime_ready": true,
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
    "capability_surface_fingerprint": "sha256:fixture",
    "future_root": { "enabled": true },
    "ownership": { "future_owner": "future-product" },
  }
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
