///|
fn receive_test_id() -> String {
  "0123456789abcdef0123456789abcdef"
}

///|
async test "receive JSON body bounds exact EOF and rejects overflow and invalid UTF-8" {
  let exact = @io.MemoryReader(writer => writer.write("{\"a\":1}"))
  defer exact.close()
  assert_eq(agent_import_read_body(exact, 7), Some({ "a": 1 }))
  let excess = @io.MemoryReader(writer => writer.write("{\"a\":1} "))
  defer excess.close()
  assert_eq(agent_import_read_body(excess, 7), None)
  let invalid = @io.MemoryReader(writer => writer.write(b"\xff"))
  defer invalid.close()
  assert_eq(agent_import_read_body(invalid, 7), None)
}

///|
fn receive_test_stage(
  context : WorkspaceContext,
  id? : String = receive_test_id(),
) -> AgentImportStage {
  {
    operation_id: id,
    expected_library: context.books_root,
    filename: "experienced.moonbook-agent",
    bytes: b"synthetic reviewed package",
    town_binding: None,
  }
}

///|
fn receive_test_request(
  context : WorkspaceContext,
  folder? : String = "received",
) -> AgentImportRequest {
  {
    operation_id: receive_test_id(),
    expected_library: context.books_root,
    destination_folder: folder,
    package_sha256: agent_import_hash(b"synthetic reviewed package"),
    binding_digest: None,
  }
}

///|
async fn receive_test_context() -> WorkspaceContext {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-receive-"))
  @fs.mkdir(root + "/books")
  workspace_context(root)
}

///|
fn receive_test_runner(
  calls : Array[String],
  outcome? : String = "complete",
) -> AgentExportRun {
  (command, args) => {
    calls.push(command)
    let members : Array[(String, String)] = [
      ("USER.md", "Private preferences"),
      (
        "book.toml", "[book]\nid = \"original-id\"\ntitle = \"Original title\"\n",
      ),
    ]
    let source : Json = {
      "contract": "moonbook.portable_source.v1",
      "bundle_contract": "moonbook.agent.v1",
      "agent_id": "original-id",
      "agent_version": "1.0.0",
      "book_revision": "revision",
      "bundle_digest": "sha256:bundle",
      "package_filename": "package.moonbook-agent",
      "package_sha256": agent_import_hash(b"synthetic reviewed package"),
      "package_size_bytes": b"synthetic reviewed package".length(),
      "file_count": 2,
    }
    match command {
      "source" => Ok(source.stringify())
      "inspect" =>
        Ok(
          (
            {
              "contract": "moonbook.agent.v1",
              "agent_id": "original-id",
              "version": "1.0.0",
              "book_revision": "revision",
              "bundle_digest": "sha256:bundle",
              "file_count": 2,
              "files": members.map(entry => {
                (
                  {
                    "path": entry.0,
                    "role": "preference",
                    "digest": agent_import_hash(@encoding/utf8.encode(entry.1)),
                    "size_bytes": @encoding/utf8.encode(entry.1).length(),
                    "review_status": "accepted",
                    "sensitivity": "user-private",
                  } : Json)
              }),
              "exclusions": [
                { "path": "candidate.md", "reason": "not accepted" },
              ],
            } : Json).stringify(),
        )
      "verify" =>
        Ok(
          (
            {
              "ok": true,
              "agent_id": "original-id",
              "version": "1.0.0",
              "bundle_digest": "sha256:bundle",
              "checked_file_count": 2,
            } : Json).stringify(),
        )
      "import" => {
        if outcome == "absent" {
          return Err("uncertain")
        }
        @fs.mkdir(args[0])
        for (path, content) in members {
          @fs.write_file(args[0] + "/" + path, content, create_mode=CreateNew)
        }
        if outcome == "partial" {
          return Err("interrupted")
        }
        @fsx.make_directory(
          args[0] + "/.moonbook/agent/receipts",
          recursive=true,
          exists_ok=true,
        )
        @fs.mkdir(args[0] + "/state")
        @fs.write_file(
          args[0] + "/state/agent-installation.json",
          (
            {
              "contract": "moonbook.agent_installation.v1",
              "agent_id": "original-id",
              "version": "1.0.0",
              "bundle_digest": "sha256:bundle",
              "receipt_path": ".moonbook/agent/receipts/local.json",
            } : Json).stringify(),
          create_mode=CreateNew,
        )
        @fs.write_file(
          args[0] + "/.moonbook/agent/receipts/local.json",
          (
            {
              "contract": "moonbook.agent_installation_receipt.v1",
              "action": "import",
              "target_root": args[0],
              "bundle_digest": "sha256:bundle",
              "agent_id": "original-id",
              "version": "1.0.0",
              "applied_files": members.map(entry => entry.0),
            } : Json).stringify(),
          create_mode=CreateNew,
        )
        if outcome == "lost-response" {
          Err("connection lost")
        } else {
          Ok("{}")
        }
      }
      "verify-import" => {
        for (path, content) in members {
          if (@fs.read_file(args[0] + "/" + path).text() catch { _ => "" }) !=
            content {
            return Err("drift")
          }
        }
        Ok("{\"ok\":true,\"changed_members\":[]}")
      }
      _ => Err("unexpected operation")
    }
  }
}

///|
test "receive request rejects traversal aliases extra authority and malformed bytes" {
  let payload : Json = {
    "operation_id": receive_test_id(),
    "expected_library": "/suite/books",
    "filename": "chosen.moonbook-agent",
    "data_url": "data:application/octet-stream;base64,YQ==",
  }
  assert_eq(agent_import_stage_request(payload).unwrap().bytes, b"a")
  guard payload is Object(fields) else { fail("missing fields") }
  for
    (key, invalid) in [
      ("operation_id", "not-an-id"),
      ("expected_library", "/suite/../books"),
      ("filename", "../chosen.moonbook-agent"),
      ("filename", "a.moonbook-agent\n"),
      ("data_url", "data:text/plain,not bytes"),
      ("data_url", "data:;base64,YQ==junk"),
      ("data_url", "data:;base64,"),
      ("data_url", "data:;base64,YQ"),
    ] {
    let changed = fields.copy()
    changed[key] = invalid.to_json()
    assert_true(agent_import_stage_request(Json::object(changed)) is Err(_))
  }
  fields["executable"] = "/tmp/tool".to_json()
  assert_true(agent_import_stage_request(Json::object(fields)) is Err(_))
  for
    folder in [
      "../x",
      ".hidden",
      "a/b",
      "a\\b",
      "a b",
      "a;echo",
      "",
      "a".repeat(81),
    ] {
    assert_false(agent_import_folder_valid(folder))
  }
}

///|
async test "receive stages outside Books exposes real privacy and imports only once preserving identity" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_test_runner(calls, outcome="lost-response")
  let stage = agent_import_stage_with(context, receive_test_stage(context), run)
  assert_eq(json_string(stage, "status", default=""), "inspected")
  assert_eq(@fs.readdir(context.books_root).length(), 0)
  assert_true(
    stage
    is {
      "inspection": { "files": [{ "sensitivity": "user-private", .. }, _], .. },
      ..
    },
  )
  assert_eq(calls.filter(c => c == "import").length(), 0)
  let request = receive_test_request(context)
  let imported = agent_import_apply_with(context, request, run)
  assert_eq(json_string(imported, "status", default=""), "imported")
  assert_true(
    imported
    is {
      "created": { "book_id": "original-id", "name": "Original title", .. },
      "import_verification": { "ok": True, "changed_members": Array([]), .. },
      ..
    },
  )
  assert_false(@fs.exists(context.books_root + "/received/book.json"))
  assert_eq(agent_import_apply_with(context, request, run), imported)
  assert_eq(
    agent_import_inspect_with(
      context,
      receive_test_id(),
      context.books_root,
      run,
    ),
    imported,
  )
  assert_eq(calls.filter(c => c == "import").length(), 1)
  assert_true(
    try {
      ignore(
        agent_import_apply_with(
          context,
          receive_test_request(context, folder="different"),
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(
    context.books_root + "/received/USER.md",
    "changed",
    create_mode=TruncateExisting,
  )
  let drifted = agent_import_inspect_with(
    context,
    receive_test_id(),
    context.books_root,
    run,
  )
  assert_eq(json_string(drifted, "status", default=""), "partial")
  assert_true(drifted is { "created": Null, .. })
  assert_eq(calls.filter(c => c == "import").length(), 1)
}

///|
async test "uncertain and partial receive operations recover without replay" {
  for outcome in ["absent", "partial"] {
    let context = receive_test_context()
    defer @fs.rmdir(context.suite_root, recursive=true)
    let calls : Array[String] = []
    let run = receive_test_runner(calls, outcome~)
    ignore(agent_import_stage_with(context, receive_test_stage(context), run))
    let request = receive_test_request(context)
    let first = agent_import_apply_with(context, request, run)
    let expected = if outcome == "absent" { "uncertain" } else { "partial" }
    assert_eq(json_string(first, "status", default=""), expected)
    assert_eq(agent_import_apply_with(context, request, run), first)
    assert_eq(
      agent_import_inspect_with(
        context,
        receive_test_id(),
        context.books_root,
        run,
      ),
      first,
    )
    assert_eq(calls.filter(c => c == "import").length(), 1)
  }
}

///|
async test "receive rejects changed library reviewed digest existing target and staged bytes" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_test_runner(calls)
  let stage = receive_test_stage(context)
  assert_true(
    try {
      ignore(
        agent_import_stage_with(
          context,
          { ..stage, expected_library: "/other/books", },
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(calls.is_empty())
  ignore(agent_import_stage_with(context, stage, run))
  let request = receive_test_request(context)
  assert_true(
    try {
      ignore(
        agent_import_apply_with(
          context,
          { ..request, package_sha256: "sha256:" + "0".repeat(64), },
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.mkdir(context.books_root + "/existing")
  let conflict = agent_import_apply_with(
    context,
    receive_test_request(context, folder="existing"),
    run,
  )
  assert_eq(json_string(conflict, "status", default=""), "inspected")
  assert_eq(json_string(conflict, "destination_folder", default="x"), "")
  assert_true(
    json_string(conflict, "message", default="").contains("already exists"),
  )
  assert_false(
    @fs.exists(
      agent_import_root(context) +
      "/" +
      receive_test_id() +
      "/import-request.json",
    ),
  )
  assert_true(
    try {
      ignore(
        agent_import_stage_with(context, { ..stage, bytes: b"changed", }, run),
      )
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(
    agent_import_root(context) +
    "/" +
    receive_test_id() +
    "/package.moonbook-agent",
    b"changed",
    create_mode=TruncateExisting,
  )
  assert_true(
    try {
      ignore(agent_import_apply_with(context, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(c => c == "import").length(), 0)
}

///|
async test "receive rejects symlink destinations and staged member aliases" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_test_runner(calls)
  ignore(agent_import_stage_with(context, receive_test_stage(context), run))
  @fs.symlink(
    context.books_root + "/dangling",
    target=context.suite_root + "/missing",
  )
  assert_eq(
    json_string(
      agent_import_apply_with(
        context,
        receive_test_request(context, folder="dangling"),
        run,
      ),
      "status",
      default="",
    ),
    "inspected",
  )
  let original = agent_import_root(context) +
    "/" +
    receive_test_id() +
    "/package.moonbook-agent"
  @fs.rename(original, original + ".actual", replace=false)
  @fs.symlink(original, target=original + ".actual")
  assert_true(
    try {
      ignore(
        agent_import_inspect_with(
          context,
          receive_test_id(),
          context.books_root,
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(c => c == "import").length(), 0)
}

///|
async test "concurrent duplicate receive imports share one durable reservation" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_test_runner(calls)
  ignore(agent_import_stage_with(context, receive_test_stage(context), run))
  @async.with_task_group() <| group => {
    let one = group.spawn(() => {
      agent_import_apply_with(context, receive_test_request(context), run)
    })
    let two = group.spawn(() => {
      agent_import_apply_with(context, receive_test_request(context), run)
    })
    assert_eq(one.wait(), two.wait())
  }
  assert_eq(calls.filter(c => c == "import").length(), 1)
}

///|
async test "library changes during preflight cannot consume or launch import" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let ordinary = receive_test_runner(calls)
  ignore(
    agent_import_stage_with(context, receive_test_stage(context), ordinary),
  )
  let current = Ref(true)
  let switching : AgentExportRun = (command, args) => {
    let result = ordinary(command, args)
    if command == "inspect" {
      current.val = false
    }
    result
  }
  assert_true(
    try {
      ignore(
        agent_import_apply_with(
          context,
          receive_test_request(context),
          switching,
          is_current=() => current.val,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(c => c == "import").length(), 0)
  assert_false(
    @fs.exists(
      agent_import_root(context) +
      "/" +
      receive_test_id() +
      "/import-request.json",
    ),
  )
  assert_eq(@fs.readdir(context.books_root).length(), 0)
}

///|
async test "imported member symlink remains partial even when bytes match" {
  let context = receive_test_context()
  defer @fs.rmdir(context.suite_root, recursive=true)
  let calls : Array[String] = []
  let run = receive_test_runner(calls)
  ignore(agent_import_stage_with(context, receive_test_stage(context), run))
  ignore(agent_import_apply_with(context, receive_test_request(context), run))
  let entry_path = context.books_root + "/received/USER.md"
  @fs.rename(entry_path, entry_path + ".actual", replace=false)
  @fs.symlink(entry_path, target=entry_path + ".actual")
  let result = agent_import_inspect_with(
    context,
    receive_test_id(),
    context.books_root,
    run,
  )
  assert_eq(json_string(result, "status", default=""), "partial")
  assert_true(result is { "created": Null, .. })
  assert_eq(calls.filter(c => c == "import").length(), 1)
}

///|
async test "receive rejects stable workspace identifier collisions before import and on recovery" {
  for (existing, requested) in [("a_b", "a-b"), ("Foo", "foo")] {
    let context = receive_test_context()
    defer @fs.rmdir(context.suite_root, recursive=true)
    let calls : Array[String] = []
    let run = receive_test_runner(calls)
    ignore(agent_import_stage_with(context, receive_test_stage(context), run))
    @fs.mkdir(context.books_root + "/" + existing)
    assert_eq(
      @desk.stable_id("book", existing),
      @desk.stable_id("book", requested),
    )
    let conflict = agent_import_apply_with(
      context,
      receive_test_request(context, folder=requested),
      run,
    )
    assert_eq(json_string(conflict, "status", default=""), "inspected")
    assert_true(
      json_string(conflict, "message", default="").contains("identifier"),
    )
    assert_false(
      @fs.exists(
        agent_import_root(context) +
        "/" +
        receive_test_id() +
        "/import-request.json",
      ),
    )
    assert_eq(calls.filter(c => c == "import").length(), 0)
    let imported = agent_import_apply_with(
      context,
      receive_test_request(context),
      run,
    )
    assert_eq(json_string(imported, "status", default=""), "imported")
    // Case-insensitive filesystems already resolve Received to received.
    if !@fs.exists(context.books_root + "/Received") {
      @fs.mkdir(context.books_root + "/Received")
      let ambiguous = agent_import_inspect_with(
        context,
        receive_test_id(),
        context.books_root,
        run,
      )
      assert_eq(json_string(ambiguous, "status", default=""), "partial")
      assert_true(ambiguous is { "created": Null, .. })
    }
  }
}

///|
async test "actual retained package receive imports and opens original Book identity without execution" {
  guard @env.get_env_var("MOONDESK_AGENT_IMPORT_PACKAGE") is Some(package_path) &&
    @env.get_env_var("MOONDESK_AGENT_IMPORT_ACCEPTANCE") is Some(evidence) else {
    return
  }
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-actual-receive-"))
  @fs.mkdir(root + "/books")
  let context = workspace_context(root)
  agent_import_regular_file(package_path, agent_import_package_limit)
  let bytes = @fs.read_file(package_path).binary()
  let runtime = @trusted_host.moonbook_import_runtime().unwrap()
  let run = agent_import_runtime_runner(runtime, context.suite_root)
  let request : AgentImportStage = {
    operation_id: receive_test_id(),
    expected_library: context.books_root,
    filename: "reviewed-local.moonbook-agent",
    bytes,
    town_binding: None,
  }
  let staged = agent_import_stage_with(context, request, run)
  assert_eq(json_string(staged, "status", default=""), "inspected")
  assert_eq(@fs.readdir(context.books_root).length(), 0)
  let source = match staged {
    { "source": source, .. } => source
    _ => fail("Missing actual source")
  }
  let imported = agent_import_apply_with(
    context,
    {
      operation_id: request.operation_id,
      expected_library: context.books_root,
      destination_folder: "local-received",
      package_sha256: agent_import_hash(bytes),
      binding_digest: None,
    },
    run,
  )
  assert_eq(json_string(imported, "status", default=""), "imported")
  assert_eq(
    agent_import_inspect_with(
      context,
      request.operation_id,
      context.books_root,
      run,
    ),
    imported,
  )
  guard imported
    is { "created": created, "inspection": { "files": Array(files), .. }, .. } else {
    fail("No verified imported Book")
  }
  let workspace = find_workspace(
    root,
    json_string(created, "workspace_id", default=""),
  ).unwrap()
  assert_eq(workspace.root_path, context.books_root + "/local-received")
  assert_eq(workspace.kind, @desk.MoonBook)
  let declared_id = json_string(
    agent_import_book_metadata(workspace.root_path),
    "id",
    default="",
  )
  assert_eq(
    json_string(created, "book_id", default=""),
    if declared_id == "" {
      json_string(source, "agent_id", default="")
    } else {
      declared_id
    },
  )
  assert_false(@fs.exists(workspace.root_path + "/book.json"))
  assert_true(files.length() > 0)
  let staged_path = agent_import_root(context) +
    "/" +
    request.operation_id +
    "/package.moonbook-agent"
  assert_eq(
    agent_export_file_identity(staged_path),
    (agent_import_hash(bytes), bytes.length().to_int64()),
  )
  @fsx.make_directory(evidence, recursive=true, exists_ok=true)
  @fs.write_file(
    evidence + "/actual-receive-proof.json",
    (
      {
        "staged": staged,
        "imported": imported,
        "source": source,
        "workspace_root": root,
        "package_size_bytes": bytes.length(),
        "package_sha256": agent_import_hash(bytes),
        "exact_staged_bytes": true,
        "original_book_identity": true,
        "no_provider": true,
        "no_socket": true,
        "no_agent_or_app_execution": true,
      } : Json).stringify(indent=2),
    create_mode=CreateNew,
  )
}
