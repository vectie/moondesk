///|
fn sandbox_ui_test_receipt(
  retention_id? : String = "retention-1",
  enforcement? : String = "Enforced",
  cleanup_verified? : Bool = true,
) -> @mooncode_core.MoonCodeSandboxReceipt {
  {
    backend: "MicroVm",
    enforcement,
    cleanup_verified,
    network: "Deny",
    limits: {
      wall_clock_ms: 60000,
      cpu_seconds: 20,
      memory_mib: 512,
      disk_mib: 256,
      processes: 32,
      output_bytes: 1000000,
    },
    unverified_limits: [],
    approval_digest: "a".repeat(64),
    command_digest: "b".repeat(64),
    profile_digest: "c".repeat(64),
    changed_paths: ["src/main.mbt", "notes.txt", "old.txt"],
    changes: [
      {
        relative_path: "notes.txt",
        change: "Added",
        before_fingerprint: None,
        after_fingerprint: Some("9".repeat(64)),
        after_size_bytes: Some(64L),
        promotable: true,
      },
      {
        relative_path: "src/main.mbt",
        change: "Modified",
        before_fingerprint: Some("d".repeat(64)),
        after_fingerprint: Some("e".repeat(64)),
        after_size_bytes: Some(512L),
        promotable: true,
      },
      {
        relative_path: "old.txt",
        change: "Removed",
        before_fingerprint: Some("f".repeat(64)),
        after_fingerprint: None,
        after_size_bytes: None,
        promotable: false,
      },
    ],
    artifacts: ["reports/check.json"],
    retention_id: if retention_id == "" {
      None
    } else {
      Some(retention_id)
    },
  }
}

///|
fn sandbox_ui_promotion_result(
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
  destination_outcome : String,
  completed : Bool,
  promoted_paths : Array[String],
  uncertain_paths : Array[String],
  recovery_required : Bool,
  error_code : String,
) -> @mooncode_core.MoonCodeSandboxPromotionResult {
  let retention_id = match receipt.retention_id {
    Some(value) => value
    None => ""
  }
  {
    completed,
    retention_id,
    approval_digest: receipt.approval_digest,
    command_digest: receipt.command_digest,
    promoted_paths,
    destination_outcome,
    uncertain_paths,
    recovery_required,
    error_code,
  }
}

///|
#warnings("-alert_unstable")
test "sandbox receipt renders bounded evidence and explicit per-file review" {
  let receipt = sandbox_ui_test_receipt()
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_sandbox_receipt(
        code_mode_test_dispatch,
        init_model(),
        receipt,
      ),
    ),
  )
  assert_true(markup.contains("ExecutionSandbox receipt"))
  assert_true(markup.contains("MicroVm"))
  assert_true(markup.contains("Enforced · cleanup verified"))
  assert_true(markup.contains("Deny"))
  assert_true(markup.contains("60000 ms wall"))
  assert_true(markup.contains("c".repeat(64)))
  assert_true(markup.contains("src/main.mbt"))
  assert_true(markup.contains("old.txt"))
  assert_true(markup.contains("reports/check.json"))
  assert_true(markup.contains("aria-pressed=\"false\""))
  assert_true(markup.contains("data-testid=\"sandbox-promote\""))
  assert_true(markup.contains("disabled"))
  assert_false(markup.contains("/private/"))
  assert_false(markup.contains("audit_path"))
  assert_false(markup.contains("auth_token"))
}

///|
test "sandbox review selection is receipt-bound and only promotes chosen files" {
  let receipt = sandbox_ui_test_receipt()
  let (_, selected) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(receipt, "src/main.mbt"),
    init_model(),
  )
  assert_eq(selected.mooncode_sandbox_review_key, receipt.review_key())
  assert_eq(selected.mooncode_sandbox_selected_paths, ["src/main.mbt"])
  let request = mooncode_sandbox_promotion_request(
    receipt,
    selected.mooncode_sandbox_selected_paths,
  ).unwrap()
  assert_eq(request.items, [
    { source_relative: "src/main.mbt", destination_relative: "src/main.mbt" },
  ])
  let (_, replaced) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(receipt, "notes.txt"),
    selected,
  )
  assert_eq(replaced.mooncode_sandbox_selected_paths, ["notes.txt"])
  assert_true(
    mooncode_sandbox_promotion_request(receipt, ["src/main.mbt", "notes.txt"])
    is Err(_),
  )
  let (_, removed_refused) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(receipt, "old.txt"),
    replaced,
  )
  assert_eq(removed_refused.mooncode_sandbox_selected_paths, ["notes.txt"])

  let other = sandbox_ui_test_receipt(retention_id="retention-2")
  let (_, rebound) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(other, "src/main.mbt"),
    removed_refused,
  )
  assert_eq(rebound.mooncode_sandbox_review_key, other.review_key())
  assert_eq(rebound.mooncode_sandbox_selected_paths, ["src/main.mbt"])
}

///|
#warnings("-alert_unstable")
test "sandbox promotion locks applied and recovery outcomes but not safe refusal" {
  let receipt = sandbox_ui_test_receipt()
  let key = receipt.review_key()
  let base = {
    ..init_model(),
    mooncode_sandbox_review_key: key,
    mooncode_sandbox_selected_paths: ["src/main.mbt"],
    mooncode_sandbox_promotion_pending: true,
  }
  let safe_refusal = sandbox_ui_promotion_result(
    receipt,
    "not-applied",
    false,
    [],
    [],
    false,
    "promotion-refused",
  )
  let (_, retryable) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(key, Ok(safe_refusal)),
    base,
  )
  assert_false(retryable.mooncode_sandbox_locked_review_keys.contains(key))
  assert_eq(retryable.mooncode_sandbox_selected_paths, ["src/main.mbt"])
  assert_true(
    retryable.mooncode_sandbox_promotion_status.contains("destination parent"),
  )

  let cleanup = sandbox_ui_promotion_result(
    receipt,
    "applied-durable",
    false,
    ["src/main.mbt"],
    [],
    false,
    "promotion-cleanup-unverified",
  )
  let (_, cleanup_locked) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(key, Ok(cleanup)),
    base,
  )
  assert_true(cleanup_locked.mooncode_sandbox_locked_review_keys.contains(key))
  assert_true(cleanup_locked.mooncode_sandbox_selected_paths.is_empty())
  assert_true(
    cleanup_locked.mooncode_sandbox_promotion_status.contains("was promoted"),
  )

  let recovery = sandbox_ui_promotion_result(
    receipt,
    "recovery-required",
    false,
    [],
    ["src/main.mbt"],
    true,
    "promotion-recovery-required",
  )
  let (_, recovery_locked) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(key, Ok(recovery)),
    base,
  )
  assert_true(recovery_locked.mooncode_sandbox_locked_review_keys.contains(key))
  assert_true(
    recovery_locked.mooncode_sandbox_promotion_status.contains(
      "outcome is uncertain for src/main.mbt",
    ),
  )
  assert_false(
    recovery_locked.mooncode_sandbox_promotion_status.contains("/private/"),
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_sandbox_receipt(
        code_mode_test_dispatch, recovery_locked, receipt,
      ),
    ),
  )
  assert_true(markup.contains("Promotion locked"))
  assert_true(markup.contains("role=\"alert\""))
  assert_false(markup.contains("native status"))
  assert_false(markup.contains("/private/"))
}

///|
test "sandbox promotion fails closed for degraded, unclean, stale, or empty receipts" {
  for
    receipt in [
      sandbox_ui_test_receipt(enforcement="Degraded"),
      sandbox_ui_test_receipt(cleanup_verified=false),
      sandbox_ui_test_receipt(retention_id=""),
    ] {
    assert_false(receipt.promotion_ready())
    assert_true(
      mooncode_sandbox_promotion_request(receipt, ["src/main.mbt"]) is Err(_),
    )
  }
  let model = {
    ..init_model(),
    mooncode_sandbox_review_key: "current",
    mooncode_sandbox_promotion_pending: true,
    mooncode_sandbox_promotion_status: "current request",
  }
  let (_, stale) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(
      "stale",
      Err("stale response should be ignored"),
    ),
    model,
  )
  assert_true(stale.mooncode_sandbox_promotion_pending)
  assert_eq(stale.mooncode_sandbox_promotion_status, "current request")
}

///|
#warnings("-alert_unstable")
test "malformed sandbox evidence renders a non-promotable alert" {
  let row : MoonCodeEvidenceRow = {
    item_id: "sandbox-invalid",
    kind: "tool",
    state: "recorded",
    title: "Sandbox evidence",
    path: "",
    detail: "",
    diff: "",
    command: "",
    output: "",
    exit_code: 0,
    truncated: false,
    approval: None,
    sandbox_receipt: None,
    sandbox_receipt_invalid: true,
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_evidence(
        code_mode_test_dispatch,
        init_model(),
        "session",
        row,
      ),
    ),
  )
  assert_true(markup.contains("sandbox-receipt-invalid"))
  assert_true(markup.contains("Sandbox receipt could not be verified"))
  assert_false(markup.contains("sandbox-promote"))
}
