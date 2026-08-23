///|
fn sandbox_promotion_test_request() -> @mooncode_core.MoonCodeSandboxPromotionRequest {
  {
    retention_id: "retention-1",
    approval_digest: "a".repeat(64),
    command_digest: "b".repeat(64),
    items: [
      { source_relative: "src/main.mbt", destination_relative: "src/main.mbt" },
    ],
  }
}

///|
fn sandbox_promotion_test_payload(
  request : @mooncode_core.MoonCodeSandboxPromotionRequest,
  config : SourceSemanticsSandboxClientConfig,
  request_id : String,
  destination_outcome : String,
  completed : Bool,
  promoted_paths : Array[String],
  uncertain_paths : Array[String],
  recovery_required : Bool,
  error_code : String,
  bound_evidence? : Bool = true,
) -> Json {
  {
    "protocol_version": 1,
    "instance_id": config.instance_id,
    "request_id": request_id,
    "workspace_id": config.workspace_id,
    "retention_id": request.retention_id,
    "approval_digest": request.approval_digest,
    "command_digest": request.command_digest,
    "completed": completed,
    "promoted_paths": promoted_paths,
    "destination_outcome": destination_outcome,
    "uncertain_paths": uncertain_paths,
    "recovery_required": recovery_required,
    "error_code": error_code,
    "evidence": {
      "moonfort_protocol_version": 4,
      "retention_id": request.retention_id,
      "workspace_id": if bound_evidence {
        config.workspace_id
      } else {
        ""
      },
      "approval_digest": if bound_evidence {
        request.approval_digest
      } else {
        ""
      },
      "command_digest": if bound_evidence {
        request.command_digest
      } else {
        ""
      },
      "completed": completed,
      "promoted_paths": promoted_paths,
      "destination_outcome": destination_outcome,
      "uncertain_paths": uncertain_paths,
      "recovery_required": recovery_required,
      "error_code": error_code,
    },
  }
}

///|
test "promotion broker preserves five exact v4 destination outcomes" {
  let request = sandbox_promotion_test_request()
  let config = source_semantics_test_client_config()
  let request_id = "desk-0123456789abcdef0123456789abcdef"
  let destination = request.items[0].destination_relative
  let payloads : Array[Json] = [
    sandbox_promotion_test_payload(
      request,
      config,
      request_id,
      "applied-durable",
      true,
      [destination],
      [],
      false,
      "",
    ),
    sandbox_promotion_test_payload(
      request,
      config,
      request_id,
      "applied-durable",
      false,
      [destination],
      [],
      false,
      "promotion-cleanup-unverified",
    ),
    sandbox_promotion_test_payload(
      request,
      config,
      request_id,
      "not-applied",
      false,
      [],
      [],
      false,
      "promotion-refused",
      bound_evidence=false,
    ),
    sandbox_promotion_test_payload(
      request,
      config,
      request_id,
      "not-applied",
      false,
      [],
      [],
      true,
      "promotion-recovery-required",
    ),
    sandbox_promotion_test_payload(
      request,
      config,
      request_id,
      "recovery-required",
      false,
      [],
      [destination],
      true,
      "promotion-recovery-required",
    ),
  ]
  for payload in payloads {
    let result = validate_moonclaw_sandbox_promotion_response(
      payload, request, config, request_id,
    ).unwrap()
    assert_false(result.to_json().stringify().contains("/private/"))
  }
}

///|
test "promotion broker rejects stale, contradictory, and host-path outcomes" {
  let request = sandbox_promotion_test_request()
  let config = source_semantics_test_client_config()
  let request_id = "desk-0123456789abcdef0123456789abcdef"
  let destination = request.items[0].destination_relative
  let stale = sandbox_promotion_test_payload(
    request,
    config,
    "desk-stale-request-id",
    "applied-durable",
    true,
    [destination],
    [],
    false,
    "",
  )
  let contradictory = sandbox_promotion_test_payload(
    request,
    config,
    request_id,
    "not-applied",
    true,
    [destination],
    [],
    false,
    "promotion-refused",
    bound_evidence=false,
  )
  let host_path = sandbox_promotion_test_payload(
    request,
    config,
    request_id,
    "recovery-required",
    false,
    [],
    ["/private/secret"],
    true,
    "promotion-recovery-required",
  )
  let unreviewed_path = sandbox_promotion_test_payload(
    request,
    config,
    request_id,
    "recovery-required",
    false,
    [],
    ["other/path"],
    true,
    "promotion-recovery-required",
  )
  let wrong_evidence = sandbox_promotion_test_payload(
    request,
    config,
    request_id,
    "applied-durable",
    true,
    [destination],
    [],
    false,
    "",
    bound_evidence=false,
  )
  for
    payload in [
      stale, contradictory, host_path, unreviewed_path, wrong_evidence,
    ] {
    assert_true(
      validate_moonclaw_sandbox_promotion_response(
        payload, request, config, request_id,
      )
      is Err(_),
    )
  }
}

///|
test "browser promotion contract requires one safe mapping" {
  let request = sandbox_promotion_test_request()
  assert_true(
    @mooncode_core.validate_mooncode_sandbox_promotion_request({
      ..request,
      items: [
        { source_relative: "../outside", destination_relative: "src/main.mbt" },
      ],
    })
    is Err(_),
  )
  assert_true(
    @mooncode_core.validate_mooncode_sandbox_promotion_request({
      ..request,
      items: [
        { source_relative: "a", destination_relative: "a" },
        { source_relative: "b", destination_relative: "b" },
      ],
    })
    is Err(_),
  )
}
