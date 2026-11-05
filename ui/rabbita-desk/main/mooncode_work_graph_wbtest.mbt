///|
test "work graph reuses evidence once, retains failed output and links resources" {
  let evidence = {
    ..mooncode_tool_detail_test_row("failed"),
    item_id: "operation-one",
    path: "src/main.mbt",
  }
  let row : MoonCodeActivityRow = {
    item_id: "work",
    tone: "failed",
    label: "Work",
    title: "Work interrupted",
    detail: "duplicate detail",
    status: "failed",
    folded: true,
    command_id: "c",
    client_turn_id: "client",
    session_id: "s",
    retry_prompt: "",
    evidence: [evidence],
    graph: {
      "nodes": [
        { "id": "batch", "kind": "batch", "step": 1 },
        {
          "id": "operation-one",
          "kind": "operation",
          "batch_id": "batch",
          "tool": "shell",
        },
        {
          "id": "read-call",
          "kind": "operation",
          "batch_id": "batch",
          "tool": "read",
          "status": "running",
        },
        {
          "id": "file",
          "kind": "resource",
          "operation_id": "operation-one",
          "path": "src/main.mbt",
          "fingerprint": "sha256:input-version",
        },
      ],
      "edges": [
        { "from": "earlier-result", "to": "operation-one", "kind": "recalls" },
      ],
    },
  }
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_mooncode_activity_body(code_mode_test_dispatch, init_model(), row),
    ),
  )
  assert_true(markup.has_prefix("<details"))
  assert_true(markup.contains("mooncode-work-graph"))
  assert_eq(markup.split("data-testid=\"mooncode-evidence\"").count(), 2)
  assert_true(markup.contains("data-state=\"failed\""))
  assert_true(markup.contains("data-i18n=\"code.work_status_running\""))
  assert_true(markup.contains("Output · exit 1"))
  assert_true(markup.contains("data-resource-version=\"sha256:input-version\""))
  assert_true(markup.contains("href=\"#earlier-result\""))
  assert_false(markup.contains("duplicate detail"))
}
