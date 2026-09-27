///|
fn source_semantics_test_client_config() -> SourceSemanticsSandboxClientConfig {
  {
    protocol_version: 1,
    instance_id: "0123456789abcdef0123456789abcdef",
    auth_token: "a".repeat(64),
    workspace_id: "book",
    workspace_root: "/registered/book",
  }
}

///|
test "source semantics accepts only a matching enforced receipt" {
  let config = source_semantics_test_client_config()
  let request_id = "desk-0123456789abcdef0123456789abcdef"
  let payload : Json = {
    "protocol_version": 1,
    "instance_id": config.instance_id,
    "request_id": request_id,
    "workspace_id": config.workspace_id,
    "operation": "moon_diagnostics",
    "exit_code": 0,
    "output": "{\"$message_type\":\"summary\"}\n",
    "output_truncated": false,
    "receipt": {
      "approval_digest": "a".repeat(64),
      "command_digest": "b".repeat(64),
      "profile_digest": "c".repeat(64),
      "enforcement": "Enforced",
      "cleanup_verified": true,
    },
  }
  assert_true(
    source_semantics_validate_sandbox_response(payload, config, request_id)
    is Ok(_),
  )
  let ide = match payload {
    Object(fields) => {
      let fields = fields.copy()
      fields["operation"] = "moon_ide".to_json()
      fields["action"] = "definition".to_json()
      Json::object(fields)
    }
    _ => fail("expected object")
  }
  assert_true(
    source_semantics_validate_sandbox_response(
      ide,
      config,
      request_id,
      operation="moon_ide",
    )
    is Ok(_),
  )
  assert_true(
    source_semantics_validate_sandbox_response(ide, config, request_id)
    is Err(InvalidReceipt),
  )
  let truncated = match payload {
    Object(fields) => {
      let fields = fields.copy()
      fields["output_truncated"] = true
      Json::object(fields)
    }
    _ => fail("expected object")
  }
  assert_true(
    source_semantics_validate_sandbox_response(truncated, config, request_id)
    is Err(InvalidReceipt),
  )
  let degraded_receipt : Json = {
    "approval_digest": "a".repeat(64),
    "command_digest": "b".repeat(64),
    "profile_digest": "c".repeat(64),
    "enforcement": "Degraded",
    "cleanup_verified": true,
  }
  let degraded = match payload {
    Object(fields) => {
      let fields = fields.copy()
      fields["receipt"] = degraded_receipt
      Json::object(fields)
    }
    _ => fail("expected object")
  }
  assert_true(
    source_semantics_validate_sandbox_response(degraded, config, request_id)
    is Err(InvalidReceipt),
  )
}

///|
test "source semantics private control path never uses a MoonBook root" {
  assert_eq(
    source_semantics_control_root("/private/app-data", "/Users/demo"),
    "/private/app-data/control/execution-sandbox",
  )
}

///|
async test "Moon IDE JSON locations stay inside the selected MoonBook" {
  @moonlib/fsx.with_temporary_directory("moondesk-moon-ide-", root => {
    @fsx.write_to_file(
      @pathx.join(root, "code.mbt"),
      "pub fn example() {}\n",
      create=0o600,
    )
    let input : Json = [
      {
        "path": @pathx.join(root, "code.mbt"),
        "range": "3:5-3:12",
        "is_test": false,
      },
      { "path": "/outside/private.mbt", "range": "1:1-1:2" },
      { "path": @pathx.join(root, "code.mbt"), "range": "bad" },
    ]
    let locations = source_semantics_ide_locations(input.stringify(), root)
    assert_eq(locations.length(), 1)
    assert_eq(json_string(locations[0], "path", default=""), "code.mbt")
    assert_eq(json_int(locations[0], "line", default=0), 3)
    assert_eq(json_int(locations[0], "column", default=0), 5)
    assert_eq(source_semantics_ide_locations("null", root).length(), 0)
  })
}
