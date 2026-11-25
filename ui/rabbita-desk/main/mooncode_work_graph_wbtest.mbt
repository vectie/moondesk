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
    reasoning: "",
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

///|
test "activity body renders live thinking card and typed search/web/read tool badges" {
  let search_row = {
    ..mooncode_tool_detail_test_row("recorded"),
    item_id: "op-search",
    kind: "search",
    title: "Found files",
    path: "**/*.mbt",
  }
  let web_row = {
    ..mooncode_tool_detail_test_row("recorded"),
    item_id: "op-web",
    kind: "web",
    title: "Searched web",
    path: "moonbit release",
  }
  let row : MoonCodeActivityRow = {
    item_id: "work-live",
    tone: "thinking",
    label: "Work",
    title: "Thinking",
    detail: "",
    reasoning: "First inspect the workspace files, then verify online docs.",
    status: "running",
    folded: false,
    command_id: "c-live",
    client_turn_id: "client-live",
    session_id: "s-live",
    retry_prompt: "",
    evidence: [search_row, web_row],
    graph: Json::null(),
  }
  let markup = render_test_dom(
    @rabbita.static_cell(
      render_mooncode_activity_body(code_mode_test_dispatch, init_model(), row),
    ),
  )
  assert_true(markup.contains("data-testid=\"mooncode-thinking\""))
  assert_true(markup.contains("data-running=\"true\""))
  assert_true(
    markup.contains(
      "First inspect the workspace files, then verify online docs.",
    ),
  )
  assert_true(markup.contains("data-i18n=\"code.evidence_search\""))
  assert_true(markup.contains("data-i18n=\"code.evidence_web\""))
  assert_true(markup.contains("data-icon=\"search\""))
  assert_true(markup.contains("data-icon=\"browser\""))
}

///|
test "composer hides internal draft and lifecycle strings while keeping actionable errors" {
  assert_true(mooncode_composer_status_hidden("new session draft"))
  assert_true(mooncode_composer_status_hidden("draft"))
  assert_true(mooncode_composer_status_hidden("retrying"))
  assert_true(mooncode_composer_status_hidden("MoonClaw control route located"))
  assert_true(
    mooncode_composer_status_hidden("Model set to moongate/glm-5.3.flash"),
  )
  assert_false(
    mooncode_composer_status_hidden("Attach at most four images totaling 16 MB"),
  )
}

///|
test "long conversation window progressively slices recent tail and expands upward" {
  let base = init_model()
  assert_eq(mooncode_transcript_visible_start(base, "s-long", 12), 0)
  assert_eq(mooncode_transcript_visible_start(base, "s-long", 40), 16)
  let expanded = {
    ..base,
    mooncode_visible_window_session_id: "s-long",
    mooncode_visible_item_limit: 48,
  }
  assert_eq(mooncode_transcript_visible_start(expanded, "s-long", 40), 0)
  assert_eq(mooncode_transcript_visible_start(expanded, "s-other", 40), 16)
}
