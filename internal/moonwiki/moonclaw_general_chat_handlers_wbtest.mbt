///|
test "Wiki chat prompt assigns general MoonClaw ownership and hides workflow" {
  let prompt = moonclaw_general_chat_prompt(
    "documents/brief.docx",
    ["documents/brief.docx"],
    "Check the figures and improve the summary.",
  )
  assert_true(prompt.contains("MoonClaw's general agent"))
  assert_true(prompt.contains("not a MoonCode coding session"))
  assert_true(prompt.contains("five-stage"))
  assert_true(prompt.contains("documents/brief.docx"))
  assert_true(prompt.contains("Check the figures"))
  assert_true(prompt.contains("<file path=\"documents/brief.docx\"/>"))
}

///|
test "Wiki chat includes only explicit user-approved preference context" {
  let prompt = moonclaw_general_chat_prompt(
    "documents/brief.docx",
    [],
    "Rewrite the summary.",
    preference_context="- ARR: annual recurring revenue",
  )
  assert_true(prompt.contains("<user-approved-preferences>"))
  assert_true(prompt.contains("ARR: annual recurring revenue"))
}

///|
test "Wiki chat accepts only bounded opaque general task identifiers" {
  assert_true(moonclaw_general_task_id_valid("task_A-123"))
  assert_false(moonclaw_general_task_id_valid("../code/session"))
  assert_false(moonclaw_general_task_id_valid("task/id"))
  assert_false(moonclaw_general_task_id_valid(""))
}

///|
test "Wiki chat keeps user mentions structural and bounded" {
  assert_eq(moonclaw_general_xml_attr("a&b\"<c>"), "a&amp;b&quot;&lt;c&gt;")
  assert_true(MoonClawGeneralMaxAttachedFiles > 0)
  assert_true(MoonClawGeneralMaxAttachedPathChars > 0)
  assert_true(
    MoonClawGeneralMaxMessageChars > MoonClawGeneralMaxAttachedPathChars,
  )
}

///|
test "Wiki chat pins new and resumed tasks to MoonGate routes" {
  let request = moonclaw_general_new_task_request(
    "/tmp/book", "Review the document", "moongate/kimi-k3",
  )
  assert_eq(json_string(request, "model", default=""), "moongate/kimi-k3")
  assert_eq(json_string(request, "source_kind", default=""), "moondesk.general")
  assert_true(
    moonclaw_general_existing_task_is_routed({
      "task": { "model": "moongate/kimi-k3" },
    }),
  )
  assert_false(
    moonclaw_general_existing_task_is_routed({
      "task": { "model": "codex/gpt-5.6-sol" },
    }),
  )
}

///|
async test "general chat resolves earlier conversation context on the server" {
  let root = "/tmp/moondesk-chat-context-" + @async.now().to_int().to_string()
  @moonlib/fsx.make_directory(root, recursive=true, exists_ok=true)
  write_document_conversations(root, [
    {
      "id": "conversation-1",
      "conversation_id": "conversation-1",
      "workspace_id": "book-demo",
      "entries": [
        { "role": "user", "content": "What changed?" },
        { "role": "assistant", "content": "Revenue increased." },
      ],
    },
  ])
  let items = moonclaw_general_context_items(root, "book-demo", root, "", {
    "context_items": [
      {
        "id": "conversation:conversation-1",
        "kind": "conversation",
        "label": "Revenue review",
        "value": "conversation-1",
        "detail": "browser text must not win",
      },
    ],
  }).unwrap()
  assert_eq(items.length(), 1)
  assert_true(
    json_string(items[0], "detail", default="").contains(
      "MoonDesk: Revenue increased.",
    ),
  )
  assert_false(
    json_string(items[0], "detail", default="").contains("browser text"),
  )
  let prompt = moonclaw_general_chat_prompt(
    "",
    [],
    "Compare the result",
    context_items=items,
  )
  assert_true(prompt.contains("<user-approved-context>"))
  assert_true(prompt.contains("Revenue increased."))
}

///|
test "Wiki chat proxy accepts only opaque resumable stream cursors" {
  assert_eq(
    moonclaw_general_resume_cursor("/api/moonclaw/tasks/t/events"),
    Some("start"),
  )
  assert_eq(
    moonclaw_general_resume_cursor(
      "/api/moonclaw/tasks/t/events?cursor=mct2.42.abcdef",
    ),
    Some("mct2.42.abcdef"),
  )
  assert_eq(
    moonclaw_general_resume_cursor(
      "/api/moonclaw/tasks/t/events?cursor=../../private",
    ),
    None,
  )
  assert_eq(
    moonclaw_general_resume_cursor(
      "/api/moonclaw/tasks/t/events?cursor=mct2.1.%2Ftmp",
    ),
    None,
  )
}
