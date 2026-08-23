///|
fn sandbox_promotion_core_test_request() -> MoonCodeSandboxPromotionRequest {
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
fn sandbox_promotion_core_applied(
  request : MoonCodeSandboxPromotionRequest,
) -> MoonCodeSandboxPromotionResult {
  {
    completed: true,
    retention_id: request.retention_id,
    approval_digest: request.approval_digest,
    command_digest: request.command_digest,
    promoted_paths: [request.items[0].destination_relative],
    destination_outcome: "applied-durable",
    uncertain_paths: [],
    recovery_required: false,
    error_code: "",
  }
}

///|
test "sandbox promotion core accepts five truthful v4 outcomes" {
  let request = sandbox_promotion_core_test_request()
  let applied = sandbox_promotion_core_applied(request)
  let cleanup_unverified : MoonCodeSandboxPromotionResult = {
    ..applied,
    completed: false,
    error_code: "promotion-cleanup-unverified",
  }
  let not_applied : MoonCodeSandboxPromotionResult = {
    ..applied,
    completed: false,
    promoted_paths: [],
    destination_outcome: "not-applied",
    error_code: "promotion-refused",
  }
  let claim_recovery : MoonCodeSandboxPromotionResult = {
    ..not_applied,
    recovery_required: true,
    error_code: "promotion-recovery-required",
  }
  let destination_recovery : MoonCodeSandboxPromotionResult = {
    ..claim_recovery,
    destination_outcome: "recovery-required",
    uncertain_paths: [request.items[0].destination_relative],
  }
  for
    result in [
      applied, cleanup_unverified, not_applied, claim_recovery, destination_recovery,
    ] {
    assert_eq(
      validate_mooncode_sandbox_promotion_result(result, request),
      Ok(result),
    )
  }
  assert_true(applied.locks_receipt())
  assert_true(cleanup_unverified.locks_receipt())
  assert_false(not_applied.locks_receipt())
  assert_true(claim_recovery.locks_receipt())
  assert_true(destination_recovery.locks_receipt())
}

///|
test "sandbox promotion core rejects multiple items and contradictory paths" {
  let request = sandbox_promotion_core_test_request()
  assert_true(
    validate_mooncode_sandbox_promotion_request({
      ..request,
      items: request.items +
      [{ source_relative: "other", destination_relative: "other" }],
    })
    is Err(_),
  )
  let applied = sandbox_promotion_core_applied(request)
  let invalid : Array[MoonCodeSandboxPromotionResult] = [
    { ..applied, destination_outcome: "not-applied" },
    {
      ..applied,
      completed: false,
      promoted_paths: [],
      destination_outcome: "recovery-required",
      uncertain_paths: ["/private/host-secret"],
      recovery_required: true,
      error_code: "promotion-recovery-required",
    },
    {
      ..applied,
      completed: false,
      promoted_paths: [],
      destination_outcome: "recovery-required",
      uncertain_paths: ["other/path"],
      recovery_required: true,
      error_code: "promotion-recovery-required",
    },
  ]
  for result in invalid {
    assert_true(
      validate_mooncode_sandbox_promotion_result(result, request) is Err(_),
    )
  }
}
