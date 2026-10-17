///|
test "return receipt recovery remains available after acknowledged return and reload" {
  let receipt = sandbox_ui_test_receipt()
  let key = receipt.review_key()
  let base = {
    ..init_model(),
    mooncode_sandbox_review_key: key,
    mooncode_sandbox_selected_paths: ["src/main.mbt"],
  }
  let result = sandbox_ui_promotion_result(
    receipt,
    "applied-durable",
    true,
    ["src/main.mbt"],
    [],
    false,
    "",
  )
  let (_, saved) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(key, 0, Ok(result)),
    base,
  )
  assert_true(saved.mooncode_sandbox_locked_review_keys.contains(key))
  assert_eq(saved.mooncode_sandbox_selected_paths, ["src/main.mbt"])
  assert_true(saved.mooncode_sandbox_promotion_status.contains("src/main.mbt"))
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_sandbox_receipt(code_mode_test_dispatch, saved, receipt),
    ),
  )
  assert_true(markup.contains("sandbox-recover-receipt"))
  assert_true(markup.contains("Promotion locked"))
  assert_true(markup.contains("copies the file again"))
  let (_, recovering) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(receipt),
    saved,
  )
  assert_true(recovering.mooncode_sandbox_promotion_pending)
  assert_true(
    recovering.mooncode_sandbox_promotion_status.contains(
      "No execution or promotion",
    ),
  )
  let (_, reloaded) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(receipt, "src/main.mbt"),
    init_model(),
  )
  let (_, after_reload) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(receipt),
    reloaded,
  )
  assert_true(after_reload.mooncode_sandbox_promotion_pending)
  assert_eq(after_reload.mooncode_sandbox_selected_paths, ["src/main.mbt"])
}

///|
test "return receipt recovery ignores repeat clicks and changed selection while pending" {
  let receipt = sandbox_ui_test_receipt()
  let key = receipt.review_key()
  let base = {
    ..init_model(),
    mooncode_sandbox_review_key: key,
    mooncode_sandbox_selected_paths: ["src/main.mbt"],
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(receipt),
    base,
  )
  for
    message in [
      RecoverMoonCodeSandboxReceipt(receipt),
      PromoteMoonCodeSandboxReceipt(receipt),
      ToggleMoonCodeSandboxFile(receipt, "notes.txt"),
    ] {
    let (_, unchanged) = update_mooncode_session_actions(
      code_mode_test_dispatch, message, pending,
    )
    assert_eq(unchanged.mooncode_sandbox_selected_paths, ["src/main.mbt"])
    assert_eq(
      unchanged.mooncode_sandbox_promotion_status,
      pending.mooncode_sandbox_promotion_status,
    )
    assert_true(unchanged.mooncode_sandbox_promotion_pending)
  }
  let (_, stale) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion("other-receipt", 0, Err("wrong response")),
    pending,
  )
  assert_true(stale.mooncode_sandbox_promotion_pending)
  let (_, missing) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(receipt),
    init_model(),
  )
  assert_false(missing.mooncode_sandbox_promotion_pending)
  assert_true(
    missing.mooncode_sandbox_promotion_status.contains("Select exactly one"),
  )
}

///|
test "return receipt recovery failures retain selection without claiming a destination" {
  let receipt = sandbox_ui_test_receipt()
  let key = receipt.review_key()
  let base = {
    ..init_model(),
    mooncode_sandbox_review_key: key,
    mooncode_sandbox_selected_paths: ["src/main.mbt"],
    mooncode_sandbox_promotion_pending: true,
  }
  let (_, failed) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(
      key,
      0,
      Err("No matching saved return receipt; destination unresolved"),
    ),
    base,
  )
  assert_false(failed.mooncode_sandbox_promotion_pending)
  assert_eq(failed.mooncode_sandbox_selected_paths, ["src/main.mbt"])
  assert_false(failed.mooncode_sandbox_locked_review_keys.contains(key))
  assert_true(failed.mooncode_sandbox_promotion_status.contains("unresolved"))
}

///|
extern "js" fn return_http_install() =
  #| () => {
  #|   const state = { previous: globalThis.fetch, requests: [] };
  #|   globalThis.__returnReceiptHttp = state;
  #|   globalThis.fetch = (url, options = {}) => new Promise((resolve, reject) => state.requests.push({ url, options, resolve, reject }));
  #| }

///|
test "newer receipt selection remains usable while an older response arrives late" {
  let old = sandbox_ui_test_receipt()
  let newer = sandbox_ui_test_receipt(retention_id="retention-newer")
  let pending = {
    ..init_model(),
    mooncode_sandbox_review_key: old.review_key(),
    mooncode_sandbox_selected_paths: ["src/main.mbt"],
    mooncode_sandbox_promotion_pending: true,
  }
  let (_, selected) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(newer, "notes.txt"),
    pending,
  )
  assert_eq(selected.mooncode_sandbox_review_key, newer.review_key())
  assert_false(selected.mooncode_sandbox_promotion_pending)
  assert_eq(selected.mooncode_sandbox_selected_paths, ["notes.txt"])
  let (_, late) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(
      old.review_key(),
      0,
      Err("late old error"),
    ),
    selected,
  )
  assert_eq(late.mooncode_sandbox_review_key, newer.review_key())
  assert_eq(late.mooncode_sandbox_promotion_status, "")
  let (_, recovering) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(newer),
    late,
  )
  assert_true(recovering.mooncode_sandbox_promotion_pending)
  assert_eq(recovering.mooncode_sandbox_selected_paths, ["notes.txt"])
  let (_, returned) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSandboxFile(old, "src/main.mbt"),
    recovering,
  )
  let (_, again) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RecoverMoonCodeSandboxReceipt(old),
    returned,
  )
  let (_, outdated_same_receipt) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CompletedMoonCodeSandboxPromotion(old.review_key(), 0, Err("older visit")),
    again,
  )
  assert_true(outdated_same_receipt.mooncode_sandbox_promotion_pending)
  assert_eq(
    outdated_same_receipt.mooncode_sandbox_request_generation,
    again.mooncode_sandbox_request_generation,
  )
  assert_false(
    outdated_same_receipt.mooncode_sandbox_promotion_status.contains(
      "older visit",
    ),
  )
}

///|
extern "js" fn return_http_restore() =
  #| () => { globalThis.fetch = globalThis.__returnReceiptHttp.previous; delete globalThis.__returnReceiptHttp; }

///|
extern "js" fn return_http_requests() -> String =
  #| () => JSON.stringify(globalThis.__returnReceiptHttp.requests.map(r => ({ url: r.url, method: r.options.method, body: JSON.parse(r.options.body) })))

///|
extern "js" fn return_http_resolve(
  index : Int32,
  payload : String,
) -> @js.Promise =
  #| (index, payload) => {
  #|   globalThis.__returnReceiptHttp.requests[index].resolve({ ok: true, status: 200, text: () => Promise.resolve(payload) });
  #|   return new Promise(resolve => setTimeout(resolve, 0));
  #| }

///|
test "actual recovery effect uses only the receipt endpoint and rejects mismatched readback" {
  @js.async_test(async fn() {
    return_http_install()
    defer return_http_restore()
    let scheduler : RequestedSelectionTestScheduler = {
      hooks: { url_request: None, url_changed: None, },
    }
    let receipt = sandbox_ui_test_receipt()
    let key = receipt.review_key()
    let base = {
      ..init_model(),
      mooncode_sandbox_review_key: key,
      mooncode_sandbox_selected_paths: ["src/main.mbt"],
    }
    let cell = Ref(base)
    fn dispatch(message : Msg) -> @rabbita.Cmd {
      let (command, next) = update_mooncode_session_actions(
        dispatch,
        message,
        cell.val,
      )
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
      @rabbita.none
    }
    ignore(dispatch(RecoverMoonCodeSandboxReceipt(receipt)))
    ignore(dispatch(PromoteMoonCodeSandboxReceipt(receipt)))
    guard @json.parse(return_http_requests()) is [Object(request)] else {
      fail("Expected exactly one recovery request")
    }
    assert_eq(
      request.get("url"),
      Some("/api/mooncode/execution-sandbox/promotion-receipt"),
    )
    assert_eq(request.get("method"), Some("POST"))
    assert_eq(
      request.get("body"),
      Some(
        mooncode_sandbox_promotion_request(receipt, ["src/main.mbt"])
        .unwrap()
        .to_json(),
      ),
    )
    let applied = sandbox_ui_promotion_result(
      receipt,
      "applied-durable",
      true,
      ["src/main.mbt"],
      [],
      false,
      "",
    )
    ignore(return_http_resolve(0, applied.to_json().stringify()).wait())
    assert_false(cell.val.mooncode_sandbox_promotion_pending)
    assert_true(cell.val.mooncode_sandbox_locked_review_keys.contains(key))
    assert_true(
      cell.val.mooncode_sandbox_promotion_status.contains("src/main.mbt"),
    )
    cell.val = base
    ignore(dispatch(RecoverMoonCodeSandboxReceipt(receipt)))
    let wrong = { ..applied, command_digest: "f".repeat(64), }
    ignore(return_http_resolve(1, wrong.to_json().stringify()).wait())
    assert_false(cell.val.mooncode_sandbox_promotion_pending)
    assert_false(cell.val.mooncode_sandbox_locked_review_keys.contains(key))
    assert_true(
      cell.val.mooncode_sandbox_promotion_status.contains("did not match"),
    )
  })
}
