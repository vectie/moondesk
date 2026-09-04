///|
test "document conversation contracts reject unsafe ids and oversized entries" {
  assert_true(document_conversation_id_valid("task-123_ok"))
  assert_false(document_conversation_id_valid("../task"))
  assert_eq(document_conversation_title(""), "Document conversation")
  assert_eq(document_conversation_title("a".repeat(100)).length(), 72)
  let valid : Json = {
    "entries": [
      { "role": "user", "content": "Question" },
      {
        "role": "source_ref",
        "content": "{\"workspace_path\":\"documents/report.docx\"}",
      },
    ],
  }
  assert_eq(document_conversation_entries(valid).unwrap().length(), 2)
  assert_true(
    document_conversation_entries({
      "entries": [{ "role": "reasoning", "content": "hidden" }],
    })
    is None,
  )
}

///|
test "new conversation records can start at optimistic revision zero" {
  let previous : Json? = None
  let previous_revision = match previous {
    Some(record) => json_int(record, "revision", default=0)
    None => 0
  }
  assert_eq(previous_revision, 0)
}

///|
async test "document conversations persist atomically in the product home" {
  let root = "/tmp/moondesk-document-conversations-" +
    @async.now().to_int().to_string()
  write_document_conversations(root, [
    {
      "id": "conversation-1",
      "conversation_id": "conversation-1",
      "workspace_id": "book-demo",
      "entries": [],
    },
  ])
  let path = document_conversations_path(root)
  assert_true(@fsx.exists(path))
  assert_true(@fsx.read_file(path).contains("conversation-1"))
}

///|
test "natural recurrence becomes confirmation data without scheduling" {
  let suggestion = moonclaw_general_automation_suggestion(
    "Check this workbook every Monday and warn me if revenue drops.",
    "documents/revenue.xlsx",
    [],
  )
  assert_eq(
    json_string(suggestion, "kind", default=""),
    "automation_suggestion",
  )
  assert_eq(json_int(suggestion, "cadence_ticks", default=0), 10080)
  assert_eq(
    json_string(suggestion, "source_policy", default=""),
    "workspace-only",
  )
  assert_true(
    moonclaw_general_automation_suggestion(
      "Check this once.",
      "documents/revenue.xlsx",
      [],
    )
    is Null,
  )
}

///|
async test "enabled scoped preferences enter general-agent context" {
  let root = "/tmp/moondesk-agent-preferences-" +
    @async.now().to_int().to_string()
  @moonlib/fsx.make_directory(root, recursive=true, exists_ok=true)
  let path = agent_preferences_path(root)
  write_preference_records(path, [
    {
      "id": "global",
      "scope": "global",
      "workspace_id": "other",
      "label": "Tone",
      "detail": "Be concise",
      "enabled": true,
    },
    {
      "id": "workspace",
      "scope": "workspace",
      "workspace_id": "book",
      "label": "ARR",
      "detail": "Annual recurring revenue",
      "enabled": true,
    },
    {
      "id": "disabled",
      "scope": "workspace",
      "workspace_id": "book",
      "label": "Old",
      "detail": "Do not use",
      "enabled": false,
    },
  ])
  let preference = moonclaw_preferences_for_prompt(root, "book")
  let context = json_string(preference, "context", default="")
  assert_eq(json_int(preference, "count", default=0), 2)
  assert_eq(json_string_array_items(preference, "ids"), ["global", "workspace"])
  assert_true(context.contains("Tone: Be concise"))
  assert_true(context.contains("ARR: Annual recurring revenue"))
  assert_false(context.contains("Do not use"))
}
