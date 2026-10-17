///|
async test "accepted Desk lesson is a portable Book memory record" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-portable-learning-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/portable-learning")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  let identity = "{\"book_id\":\"original-book-id\",\"title\":\"Learning Book\",\"version\":\"3.2.1\"}\n"
  @fsx.write_to_file(@pathx.join(book, "book.json"), identity, create=0o644)
  let workspace_id = @desk.stable_id("book", "portable-learning")
  let proposed = apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "propose",
      "kind": "procedure",
      "detail": "Run the focused test before delivery.\nKeep the exact output and evidence.",
      "source": "The previous answer omitted the test result. report: work-123/revision-7",
    },
    "2026-10-02T12:00:00Z",
  ).unwrap()
  let accepted = apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "accept",
      "id": json_string(proposed, "id", default=""),
    },
    "2026-10-02T12:01:00Z",
  ).unwrap()
  let receipt = json_object_field_or_empty(accepted, "book_learning")
  assert_eq(json_string(receipt, "status", default=""), "persisted")
  let path = json_string(receipt, "path", default="")
  assert_true(path.has_prefix("memory/procedures/desk-"))
  let content = @fsx.read_file(@pathx.join(book, path))
  assert_true(content.has_prefix("---\nstatus: accepted\n"))
  assert_true(content.contains("lesson_kind: \"procedure\""))
  assert_true(content.contains("work-123/revision-7"))
  assert_true(content.contains("2026-10-02T12:01:00Z"))
  assert_eq(@fsx.read_file(@pathx.join(book, "book.json")), identity)
}

///|
async fn portable_learning_fixture(label : String) -> (String, String, String) {
  let root = @pathx.join(
    "/tmp",
    "moondesk-learning-" + label + "-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/portable-learning")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"book_id\":\"source-agent\",\"version\":\"3.2.1\",\"title\":\"Portable Learning\"}\n",
  )
  for dir in ["keeper", "state", "memory/beliefs"] {
    @fsx.make_directory(@pathx.join(book, dir), recursive=true, exists_ok=true)
  }
  @fsx.write_to_file(
    @pathx.join(book, "keeper/USER.md"),
    "# Existing preferences\n\n- Keep this exact preference.\n",
  )
  @fsx.write_to_file(
    @pathx.join(book, "memory/beliefs/unrelated.md"),
    "---\nstatus: accepted\n---\n\nUnrelated accepted memory.\n",
  )
  @fsx.write_to_file(
    @pathx.join(book, "state/agent-installation.json"),
    "{\"agent_id\":\"upstream-agent\",\"version\":\"2.4.0\",\"bundle_digest\":\"sha256:upstream\"}\n",
  )
  (root, book, @desk.stable_id("book", "portable-learning"))
}

///|
async fn portable_learning_propose(
  root : String,
  workspace_id : String,
  kind : String,
) -> Json {
  let detail = StringBuilder()
  detail.write_string(
    "Keep the full " + kind + " lesson.\nSecond line: evidence → decision.",
  )
  if kind == "knowledge" {
    for _ in 0..<40 {
      detail.write_string(" Long Unicode evidence 你好. ")
    }
  }
  apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "propose",
      "kind": kind,
      "detail": detail.to_string(),
      "source": "Original answer; work_id=work-123; report_revision=7; artifact=report.md#sha256-demo",
    },
    "2026-10-02T12:00:00Z",
  ).unwrap()
}

///|
fn portable_learning_action(record : Json, action : String) -> Json {
  {
    "workspace_id": json_string(record, "workspace_id", default=""),
    "action": action,
    "id": json_string(record, "id", default=""),
  }
}

///|
fn portable_learning_status(record : Json) -> String {
  json_string(
    json_object_field_or_empty(record, "book_learning"),
    "status",
    default="",
  )
}

///|
async test "all accepted lesson kinds preserve provenance and produce actual export fixture" {
  let (root, book, workspace_id) = portable_learning_fixture("producer")
  let preserved = [
    "book.json", "keeper/USER.md", "state/agent-installation.json", "memory/beliefs/unrelated.md",
  ]
  let before : Map[String, String] = Map([])
  for path in preserved {
    before[path] = @fsx.read_file(@pathx.join(book, path))
  }
  let accepted : Array[Json] = []
  for kind in ["knowledge", "preference", "procedure", "capability"] {
    let proposed = portable_learning_propose(root, workspace_id, kind)
    if kind == "knowledge" {
      assert_true(json_string(proposed, "id", default="").length() > 255)
    }
    let saved = apply_learning_proposal(
      root,
      portable_learning_action(proposed, "accept"),
      "2026-10-02T12:01:00Z",
    ).unwrap()
    assert_eq(portable_learning_status(saved), "persisted")
    let (path, content) = learning_book_content(saved).unwrap()
    assert_true(path.length() < 120)
    assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
    assert_true(
      content.contains("lesson_kind: " + ToJson::to_json(kind).stringify()),
    )
    assert_true(content.contains(json_string(proposed, "detail", default="")))
    assert_true(content.contains(json_string(proposed, "source", default="")))
    if kind == "capability" {
      assert_true(content.contains("Capability idea (not activated)"))
    }
    let retried = apply_learning_proposal(
      root,
      portable_learning_action(saved, "accept"),
      "2099-01-01T00:00:00Z",
    ).unwrap()
    assert_eq(retried, saved)
    assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
    accepted.push(saved)
  }
  let pending = apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "propose",
      "kind": "knowledge",
      "detail": "Never accepted",
    },
    "2026-10-02T12:02:00Z",
  ).unwrap()
  let rejected_proposal = apply_learning_proposal(
    root,
    {
      "workspace_id": workspace_id,
      "action": "propose",
      "kind": "procedure",
      "detail": "Explicitly rejected",
    },
    "2026-10-02T12:03:00Z",
  ).unwrap()
  let rejected = apply_learning_proposal(
    root,
    portable_learning_action(rejected_proposal, "reject"),
    "2026-10-02T12:04:00Z",
  ).unwrap()
  for record in [pending, rejected] {
    assert_true(
      apply_learning_proposal(
        root,
        portable_learning_action(record, "persist"),
        "2099",
      )
      is Err(_),
    )
    assert_true(learning_book_content(record) is Err(_))
  }
  assert_eq(accepted_learning_for_prompt(root, workspace_id).length(), 4)
  for path in preserved {
    assert_eq(@fsx.read_file(@pathx.join(book, path)), before[path])
  }
  // The Book test consumes this exact producer output, not a recreated example.
  if @env.get_env_var("MOONBOOK_DESK_LEARNING_FIXTURE") is Some(output) {
    @fsx.make_directory(output, recursive=true, exists_ok=true)
    @fsx.write_to_file(
      @pathx.join(output, "fixture.json"),
      (
        {
          "book_root": book,
          "accepted": Json::array(accepted),
          "proposed": pending,
          "rejected": rejected,
          "protected": ToJson::to_json(before),
        } : Json).stringify(indent=2),
    )
  }
}

///|
async test "failed Book save preserves the decision and explicit retry recovers" {
  let (root, book, workspace_id) = portable_learning_fixture("failure")
  // A regular file where the procedure directory belongs is a real IO failure.
  @fsx.write_to_file(@pathx.join(book, "memory/procedures"), "Do not overwrite")
  let proposal = portable_learning_propose(root, workspace_id, "procedure")
  let failed = apply_learning_proposal(
    root,
    portable_learning_action(proposal, "accept"),
    "2026-10-02T12:01:00Z",
  ).unwrap()
  assert_eq(json_string(failed, "status", default=""), "accepted")
  assert_eq(portable_learning_status(failed), "failed")
  assert_eq(
    @fsx.read_file(@pathx.join(book, "memory/procedures")),
    "Do not overwrite",
  )
  assert_eq(accepted_learning_for_prompt(root, workspace_id).length(), 1)
  @fs.remove(@pathx.join(book, "memory/procedures"))
  let retry = apply_learning_proposal(
    root,
    portable_learning_action(failed, "persist"),
    "2099",
  ).unwrap()
  assert_eq(portable_learning_status(retry), "persisted")
  assert_eq(
    json_string(retry, "decided_at", default=""),
    "2026-10-02T12:01:00Z",
  )
  let (path, content) = learning_book_content(failed).unwrap()
  assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
  assert_eq(
    read_directory_names(
      @pathx.join(book, "memory/procedures"),
      include_hidden=true,
    ).length(),
    1,
  )
}

///|
async test "same proposal conflicting Book bytes are never replaced" {
  let (root, book, workspace_id) = portable_learning_fixture("conflict")
  let proposal = portable_learning_propose(root, workspace_id, "knowledge")
  let accepted = apply_learning_proposal(
    root,
    portable_learning_action(proposal, "accept"),
    "2026-10-02T12:01:00Z",
  ).unwrap()
  let (path, _) = learning_book_content(accepted).unwrap()
  @fsx.write_to_file(@pathx.join(book, path), "Edited Book memory; preserve me")
  let retry = apply_learning_proposal(
    root,
    portable_learning_action(accepted, "persist"),
    "2099",
  ).unwrap()
  assert_eq(portable_learning_status(retry), "failed")
  assert_eq(
    json_string(
      json_object_field_or_empty(retry, "book_learning"),
      "error",
      default="",
    ),
    "learning_book_content_conflict",
  )
  assert_eq(
    @fsx.read_file(@pathx.join(book, path)),
    "Edited Book memory; preserve me",
  )
  assert_eq(
    json_string(retry, "decided_at", default=""),
    "2026-10-02T12:01:00Z",
  )
}

///|
async test "historical lessons migrate only individually and interrupted phases recover" {
  let (root, book, workspace_id) = portable_learning_fixture("recovery")
  let historical_proposal = portable_learning_propose(
    root, workspace_id, "knowledge",
  )
  let historical = learning_proposal_decide(
    [historical_proposal],
    portable_learning_action(historical_proposal, "accept"),
    "2026-09-01T12:01:00Z",
  ).unwrap()
  let other_proposal = portable_learning_propose(
    root, workspace_id, "preference",
  )
  let other = learning_proposal_decide(
    [other_proposal],
    portable_learning_action(other_proposal, "accept"),
    "2026-09-01T12:01:00Z",
  ).unwrap()
  write_learning_proposals(root, [historical, other])
  assert_eq(accepted_learning_for_prompt(root, workspace_id).length(), 2)
  let (other_path, _) = learning_book_content(other).unwrap()
  assert_false(@fsx.exists(@pathx.join(book, other_path)))
  let migrated = apply_learning_proposal(
    root,
    portable_learning_action(historical, "persist"),
    "2099",
  ).unwrap()
  assert_eq(portable_learning_status(migrated), "persisted")
  assert_eq(
    json_string(migrated, "decided_at", default=""),
    "2026-09-01T12:01:00Z",
  )
  assert_false(@fsx.exists(@pathx.join(book, other_path)))
  for after_book_write in [false, true] {
    let kind = if after_book_write { "procedure" } else { "capability" }
    let proposal = portable_learning_propose(root, workspace_id, kind)
    let accepted = learning_proposal_decide(
      [proposal],
      portable_learning_action(proposal, "accept"),
      "2026-10-02T12:01:00Z",
    ).unwrap()
    let records = read_learning_proposals(root).unwrap()
    assert_true(
      save_learning_record(
        root,
        records,
        learning_book_receipt(accepted, "pending", ""),
      ),
    )
    if after_book_write {
      persist_learning_in_book(book, accepted).unwrap()
    }
    // Represents a restart before materialization or before its receipt commit.
    let retry = apply_learning_proposal(
      root,
      portable_learning_action(accepted, "persist"),
      "2099",
    ).unwrap()
    assert_eq(portable_learning_status(retry), "persisted")
    let (path, content) = learning_book_content(accepted).unwrap()
    assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
    assert_eq(
      json_string(retry, "decided_at", default=""),
      "2026-10-02T12:01:00Z",
    )
  }
}

///|
async test "corrupt journal and symlink memory targets fail without losing data" {
  let (root, book, workspace_id) = portable_learning_fixture("unsafe")
  let proposal = portable_learning_propose(root, workspace_id, "procedure")
  let outside = @pathx.join(root, "outside")
  @fsx.make_directory(outside, recursive=true, exists_ok=true)
  @fs.symlink(target=outside, @pathx.join(book, "memory/procedures"))
  let failed = apply_learning_proposal(
    root,
    portable_learning_action(proposal, "accept"),
    "2026-10-02T12:01:00Z",
  ).unwrap()
  assert_eq(portable_learning_status(failed), "failed")
  assert_true(read_directory_names(outside, include_hidden=true).is_empty())
  @fsx.write_to_file(learning_proposals_path(root), "{unfinished")
  assert_true(
    apply_learning_proposal(
      root,
      portable_learning_action(proposal, "accept"),
      "2099",
    )
    is Err("learning_journal_invalid"),
  )
  assert_eq(@fsx.read_file(learning_proposals_path(root)), "{unfinished")
}

///|
async test "SuiteRoot retains ordinary local learning without a portable destination" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-suite-learning-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  @fs.rmdir(moonsuite_books_root(root))
  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 1)
  assert_true(workspaces[0].kind is SuiteRoot)
  let proposal = portable_learning_propose(root, workspaces[0].id, "preference")
  let accepted = apply_learning_proposal(
    root,
    portable_learning_action(proposal, "accept"),
    "2026-10-02T12:01:00Z",
  ).unwrap()
  assert_eq(json_string(accepted, "status", default=""), "accepted")
  assert_eq(portable_learning_status(accepted), "unsupported")
  assert_eq(accepted_learning_for_prompt(root, workspaces[0].id).length(), 1)
  assert_false(@fsx.exists(@pathx.join(root, "memory")))
  let other = portable_learning_propose(root, workspaces[0].id, "procedure")
  let rejected = apply_learning_proposal(
    root,
    portable_learning_action(other, "reject"),
    "2026-10-02T12:02:00Z",
  ).unwrap()
  assert_eq(json_string(rejected, "status", default=""), "rejected")
  assert_eq(accepted_learning_for_prompt(root, workspaces[0].id).length(), 1)
}

///|
async test "real journal commit IO failures do not report success and remain retryable" {
  for failed_phase in ["pending", "persisted"] {
    let (root, book, workspace_id) = portable_learning_fixture(
      "journal-" + failed_phase,
    )
    let proposal = portable_learning_propose(root, workspace_id, "procedure")
    let save : async (String, Array[Json], Json) -> Bool = (
      workspace_root,
      records,
      record,
    ) => {
      if portable_learning_status(record) != failed_phase {
        return save_learning_record(workspace_root, records, record)
      }
      // Inject a real filesystem error precisely at the chosen journal commit.
      // Retain the previous file bytes and restore them after the failed call.
      let path = learning_proposals_path(workspace_root)
      let backup = path + ".interruption-test"
      @fs.rename(path, backup, replace=false)
      @fs.mkdir(path)
      let result = save_learning_record(workspace_root, records, record)
      @fs.rmdir(path)
      @fs.rename(backup, path, replace=false)
      result
    }
    let result = apply_learning_proposal(
      root,
      portable_learning_action(proposal, "accept"),
      "2026-10-02T12:01:00Z",
      save~,
    )
    assert_true(result is Err("learning_journal_write_failed"))
    let journal = learning_proposal_find(
      read_learning_proposals(root).unwrap(),
      json_string(proposal, "id", default=""),
    ).unwrap()
    let accepted = learning_proposal_decide(
      [proposal],
      portable_learning_action(proposal, "accept"),
      "2026-10-02T12:01:00Z",
    ).unwrap()
    let (path, content) = learning_book_content(accepted).unwrap()
    if failed_phase == "pending" {
      assert_eq(json_string(journal, "status", default=""), "proposed")
      assert_false(@fsx.exists(@pathx.join(book, path)))
    } else {
      assert_eq(portable_learning_status(journal), "pending")
      assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
      let retry = apply_learning_proposal(
        root,
        portable_learning_action(journal, "persist"),
        "2099",
      ).unwrap()
      assert_eq(portable_learning_status(retry), "persisted")
      assert_eq(
        json_string(retry, "decided_at", default=""),
        "2026-10-02T12:01:00Z",
      )
      assert_eq(@fsx.read_file(@pathx.join(book, path)), content)
    }
  }
}
