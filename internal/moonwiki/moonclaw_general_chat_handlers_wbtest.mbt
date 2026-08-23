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
