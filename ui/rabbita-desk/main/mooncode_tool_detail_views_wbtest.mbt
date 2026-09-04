///|
fn mooncode_tool_detail_test_row(state : String) -> MoonCodeEvidenceRow {
  {
    item_id: "tool-detail",
    kind: "tool",
    state,
    title: "Run project checks",
    path: "scripts/check.sh",
    detail: "{\"scope\":\"workspace\"}",
    diff: "--- a/src/main.mbt\n+++ b/src/main.mbt\n@@ -1 +1 @@\n-old\n+new",
    command: "moon check --target js",
    output: "Check failed at src/main.mbt:4",
    exit_code: 1,
    truncated: true,
    approval: None,
    sandbox_receipt: None,
    sandbox_receipt_invalid: false,
  }
}

///|
#warnings("-alert_unstable")
test "MoonCode tool evidence exposes stable hooks for lazy detail enhancement" {
  let failed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_evidence(
        fn(_msg) { @rabbita.none },
        init_model(),
        "session",
        mooncode_tool_detail_test_row("failed"),
      ),
    ),
  )
  assert_true(failed_markup.has_prefix("<details"))
  assert_true(failed_markup.contains("data-testid=\"mooncode-evidence\""))
  assert_true(failed_markup.contains("data-state=\"failed\""))
  assert_true(failed_markup.contains("mooncode-evidence-detail"))
  assert_true(failed_markup.contains("mooncode-evidence-text"))
  assert_true(failed_markup.contains("mooncode-diff-shell"))
  assert_true(failed_markup.contains("Output · exit 1"))
  assert_true(failed_markup.contains("[output truncated]"))
  assert_false(failed_markup.to_lower().contains("reasoning"))
}

///|
#warnings("-alert_unstable")
test "MoonCode approval exposes actionable content for lazy card enhancement" {
  let row = {
    ..mooncode_tool_detail_test_row("pending"),
    kind: "approval",
    title: "Approval needed",
    path: "",
    detail: "Review shell execution before MoonClaw continues.",
    diff: "",
    command: "",
    output: "",
    exit_code: -1,
    truncated: false,
    approval: Some(
      Pending(
        session_id="session",
        approval_id="approval-one",
        target_command_id="command-one",
        tool_call_id="tool-one",
        arguments="{\"command\":\"moon test\"}",
      ),
    ),
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_approval(fn(_msg) { @rabbita.none }, row),
    ),
  )
  assert_true(markup.contains("data-testid=\"mooncode-approval\""))
  assert_true(markup.contains("data-state=\"pending\""))
  assert_true(markup.contains("Approval needed before this operation can run"))
  assert_true(markup.contains("Command command-one"))
  assert_true(markup.contains("Tool call tool-one"))
  assert_true(markup.contains("mooncode-approve-tool"))
  assert_true(markup.contains("mooncode-reject-tool"))
  assert_false(markup.to_lower().contains("reasoning"))
}
