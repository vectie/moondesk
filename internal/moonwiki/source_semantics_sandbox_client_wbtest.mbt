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
