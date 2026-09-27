///|
#warnings("-alert_unstable")
test "Code export appears only for a canonical selected conversation" {
  let session = {
    ..code_mode_test_session("session-export", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-export", [
        code_mode_test_turn("command-export", "Request", assistant="Answer"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_center(code_mode_test_dispatch, model)),
  )
  assert_true(markup.contains("data-testid=\"mooncode-export-conversation\""))
  assert_true(markup.contains("/api/mooncode/sessions/session-export/export"))
  assert_true(markup.contains("data-i18n=\"code.export_conversation\""))
  let empty = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_center(code_mode_test_dispatch, init_model()),
    ),
  )
  assert_false(empty.contains("mooncode-export-conversation"))
}
