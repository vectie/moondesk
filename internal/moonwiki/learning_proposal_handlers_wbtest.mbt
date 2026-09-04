///|
test "learning proposals require a deliberate valid candidate" {
  let invalid = learning_proposal_create(
    { "workspace_id": "book-one", "kind": "secret", "detail": "Remember this" },
    "2026-09-04T12:00:00Z",
  )
  assert_true(invalid is Err("invalid_learning_proposal"))
  let valid = learning_proposal_create(
    {
      "workspace_id": "book-one",
      "kind": "knowledge",
      "detail": "Use net revenue in board reports",
      "source": "Earlier answer used gross revenue",
    },
    "2026-09-04T12:00:00Z",
  )
  guard valid is Ok(record) else { fail("expected valid learning proposal") }
  assert_eq(json_string(record, "status", default=""), "proposed")
  assert_eq(json_string(record, "kind", default=""), "knowledge")
}

///|
test "learning decisions are explicit and one way" {
  let proposal = learning_proposal_create(
    {
      "workspace_id": "book-one",
      "kind": "procedure",
      "detail": "Always validate totals before writing the summary",
    },
    "2026-09-04T12:00:00Z",
  ).unwrap()
  let accepted = learning_proposal_decide(
    [proposal],
    { "id": json_string(proposal, "id", default=""), "action": "accept" },
    "2026-09-04T12:10:00Z",
  ).unwrap()
  assert_eq(json_string(accepted, "status", default=""), "accepted")
  assert_true(
    learning_proposal_decide(
      [proposal],
      {
        "id": json_string(proposal, "id", default=""),
        "workspace_id": "another-book",
        "action": "accept",
      },
      "2026-09-04T12:11:00Z",
    )
    is Err("learning_proposal_not_found"),
  )
  assert_true(
    learning_proposal_decide(
      [accepted],
      { "id": json_string(proposal, "id", default=""), "action": "reject" },
      "2026-09-04T12:11:00Z",
    )
    is Err("learning_proposal_already_decided"),
  )
}

///|
async test "accepted learning enters MoonClaw context only after review" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-learning-proposal-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/research-learning")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"book_id\":\"research-learning\",\"title\":\"Learning Book\"}\n",
    create=0o644,
  )
  let workspace_id = @desk.stable_id("book", "research-learning")
  let proposed = apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "propose",
      "kind": "preference",
      "detail": "Prefer concise executive summaries",
      "source": "A long draft answer",
    },
    "2026-09-04T12:00:00Z",
  ).unwrap()
  assert_true(accepted_learning_for_prompt(root, workspace_id).is_empty())
  ignore(
    apply_learning_proposal(
      root,
      {
        "workspace_id": workspace_id,
        "action": "accept",
        "id": json_string(proposed, "id", default=""),
      },
      "2026-09-04T12:10:00Z",
    ).unwrap(),
  )
  let learned = accepted_learning_for_prompt(root, workspace_id)
  assert_eq(learned.length(), 1)
  assert_true(learned[0].contains("Prefer concise executive summaries"))
  let prompt = moonclaw_preferences_for_prompt(root, workspace_id)
  assert_true(
    json_string(prompt, "context", default="").contains("Learned preference"),
  )
}
