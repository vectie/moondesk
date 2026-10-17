///|
fn export_test_request(
  id~ : String = "0123456789abcdef0123456789abcdef",
  version~ : String = "1.0.0",
  paths~ : Array[String] = [],
  workspace? : @desk.DeskWorkspace,
) -> AgentExportRequest {
  agent_export_request({
    "operation_id": id,
    "version": version,
    "paths": paths,
    "expected_library": export_test_expected_library(workspace),
  }).unwrap()
}

///|
fn export_test_library() -> String {
  @env.get_env_var("MOONDESK_AGENT_EXPORT_ACCEPTANCE")
  .map(path => path + "/books")
  .unwrap_or("/tmp")
}

///|
fn export_test_expected_library(workspace : @desk.DeskWorkspace?) -> String {
  match workspace {
    Some(workspace) => @pathx.dirname(workspace.root_path).to_owned()
    None => export_test_library()
  }
}

///|
async fn export_test_workspace(
  library~ : String = export_test_library(),
) -> @desk.DeskWorkspace {
  let temporary = @fs.realpath(@fs.tmpdir(prefix="moondesk-agent-export-"))
  @fsx.make_directory(library, recursive=true, exists_ok=true)
  let library = @fs.realpath(library)
  let root = if @pathx.dirname(temporary).to_owned() == library {
    temporary
  } else {
    let destination = library +
      "/" +
      temporary.split("/").last().unwrap().to_owned()
    @fs.rename(temporary, destination, replace=false)
    // A library such as /tmp may itself be a symlink on the host.
    // Preparation requires the canonical root, including after relocation.
    @fs.realpath(destination)
  }
  @desk.workspace(
    id="book-export-fixture",
    name="Export fixture",
    root_path=root,
    kind=MoonBook,
  )
}

///|
async test "export fixture canonicalizes aliased libraries without relaxing preparation identity" {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-export-library-alias-"))
  defer @fs.rmdir(root, recursive=true)
  let library = root + "/books"
  let library_alias = root + "/library-alias"
  @fs.mkdir(library)
  @fs.symlink(target=library, library_alias)
  let workspace = export_test_workspace(library=library_alias)
  let request = export_test_request(workspace~)
  assert_eq(workspace.root_path, @fs.realpath(workspace.root_path))
  assert_eq(request.expected_library, library)
  let calls : Array[String] = []
  let run = export_test_runner(calls)
  let aliased_request = { ..request, expected_library: library_alias, }
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, aliased_request, run))
      false
    } catch {
      _ => true
    },
  )
  let aliased_workspace = @desk.workspace(
    id=workspace.id,
    name=workspace.name,
    kind=MoonBook,
    root_path=library_alias +
      "/" +
      workspace.root_path.split("/").last().unwrap().to_owned(),
  )
  assert_true(
    try {
      ignore(agent_export_prepare_with(aliased_workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_true(calls.is_empty())
  assert_false(@fs.exists(workspace.root_path + "/book"))
  let prepared = agent_export_prepare_with(workspace, request, run)
  assert_eq(calls.filter(command => command == "pack").length(), 1)
  assert_eq(json_string(prepared, "expected_library", default=""), library)
}

///|
fn export_test_runner(calls : Array[String]) -> AgentExportRun {
  (command, args) => {
    calls.push(command)
    let bytes = b"retained synthetic package bytes"
    let hash = "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
    let entry : Json = {
      "path": "USER.md",
      "role": "preference",
      "digest": "sha256:member",
      "size_bytes": 12,
      "review_status": "accepted",
      "sensitivity": "user-private",
    }
    let source : Json = {
      "contract": "moonbook.portable_source.v1",
      "bundle_contract": "moonbook.agent.v1",
      "agent_id": "experienced",
      "agent_version": "1.0.0",
      "book_revision": "revision",
      "bundle_digest": "sha256:bundle",
      "package_filename": "package.moonbook-agent",
      "package_sha256": hash,
      "package_size_bytes": bytes.length(),
      "file_count": 1,
      "included_output_count": 0,
      "reference_only_count": 0,
    }
    let inspection : Json = {
      "contract": "moonbook.agent.v1",
      "agent_id": "experienced",
      "version": "1.0.0",
      "book_revision": "revision",
      "bundle_digest": "sha256:bundle",
      "file_count": 1,
      "files": [entry],
      "exclusions": [{ "path": "candidate.md", "reason": "not accepted" }],
    }
    let verification : Json = {
      "ok": true,
      "agent_id": "experienced",
      "version": "1.0.0",
      "bundle_digest": "sha256:bundle",
      "checked_file_count": 1,
    }
    match command {
      "pack" => {
        @fs.write_file(args[1], bytes, create_mode=CreateNew)
        Ok("created")
      }
      "source" => Ok(source.stringify())
      "inspect" => Ok(inspection.stringify())
      "verify" => Ok(verification.stringify())
      _ => Err("unexpected operation")
    }
  }
}

///|
test "local export request accepts only exact bounded relative file selection" {
  assert_eq(
    export_test_request(paths=["outputs/z.csv", "outputs/a.pdf"]).paths,
    ["outputs/a.pdf", "outputs/z.csv"],
  )
  for
    path in [
      "../outside", "/tmp/out", "a/../b", "book/agents/old/package", "a\\b", "a\u0000b",
      "a\nb", "a/",
    ] {
    assert_true(
      agent_export_request({
        "operation_id": "0123456789abcdef0123456789abcdef",
        "version": "1",
        "paths": [path],
        "expected_library": export_test_library(),
      })
      is Err(_),
    )
  }
  assert_true(
    agent_export_request({
      "operation_id": "bad",
      "version": "1",
      "paths": [],
      "expected_library": export_test_library(),
    })
    is Err(_),
  )
  assert_true(
    agent_export_request({
      "operation_id": "0123456789abcdef0123456789abcdef",
      "version": "1",
      "paths": ["a", "a"],
      "expected_library": export_test_library(),
    })
    is Err(_),
  )
  assert_true(
    agent_export_request({
      "operation_id": "0123456789abcdef0123456789abcdef",
      "version": "1",
      "paths": [],
      "expected_library": export_test_library(),
      "root": "/tmp",
    })
    is Err(_),
  )
  for version in ["-flag", "x".repeat(65)] {
    assert_true(
      agent_export_request({
        "operation_id": "0123456789abcdef0123456789abcdef",
        "version": version,
        "paths": [],
        "expected_library": export_test_library(),
      })
      is Err(_),
    )
  }
  guard agent_export_selection(export_test_request(paths=["result.bin"]))
    is Array([Object(fields)]) else {
    fail("Missing output selection")
  }
  assert_eq(fields.get("reference"), None)
  assert_eq(fields.get("preview_path"), None)
}

///|
async test "local export read discovery and inspection never pack and retries retain exact bytes" {
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let calls : Array[String] = []
  let run = export_test_runner(calls)
  assert_true(agent_export_retained(workspace).is_empty())
  assert_true(calls.is_empty())
  let request = export_test_request(workspace~)
  let prepared = agent_export_prepare_with(workspace, request, run)
  assert_eq(calls.filter(v => v == "pack").length(), 1)
  assert_true(
    prepared
    is {
      "inspection": {
        "files": [{ "sensitivity": "user-private", .. }],
        "exclusions": [_],
        ..
      },
      ..
    },
  )
  let retained = agent_export_retained(workspace)
  assert_eq(retained.length(), 1)
  let broken = workspace.root_path +
    "/" +
    agent_export_relative("1123456789abcdef0123456789abcdef")
  @fs.mkdir(broken)
  @fs.write_file(broken + "/source.json", "{}", create_mode=CreateNew)
  assert_eq(agent_export_retained(workspace).length(), 1)
  let repeated = agent_export_prepare_with(workspace, request, run)
  assert_eq(prepared, repeated)
  assert_eq(calls.filter(v => v == "pack").length(), 1)
  let read = agent_export_inspection_with(
    workspace,
    request.operation_id,
    agent_export_relative(request.operation_id),
    run,
    retained=true,
  )
  assert_eq(read, prepared)
  assert_eq(calls.filter(v => v == "pack").length(), 1)
  let mismatch = try {
    ignore(
      agent_export_prepare_with(
        workspace,
        export_test_request(version="2.0", workspace~),
        run,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(mismatch)
  assert_eq(calls.filter(v => v == "pack").length(), 1)
  let path = workspace.root_path +
    "/" +
    json_string(prepared, "path", default="")
  let (hash, _) = agent_export_file_identity(path)
  assert_true(workspace_artifact_digest_matches(hash, hash))
  @fs.write_file(path, b"changed", create_mode=TruncateExisting)
  assert_false(
    workspace_artifact_digest_matches(hash, agent_export_file_identity(path).0),
  )
  assert_true(
    try {
      ignore(
        agent_export_inspection_with(
          workspace,
          request.operation_id,
          agent_export_relative(request.operation_id),
          run,
          retained=true,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(v => v == "pack").length(), 1)
}

///|
async test "local export rejects same Book identity in a changed library before writes" {
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let calls : Array[String] = []
  let request = {
    ..export_test_request(workspace~),
    expected_library: "/different/books",
  }
  assert_true(
    try {
      ignore(
        agent_export_prepare_with(workspace, request, export_test_runner(calls)),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(calls.is_empty())
  assert_false(@fs.exists(workspace.root_path + "/book"))
}

///|
async test "local export refuses incomplete claims and in-Book symlink selections" {
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let calls = Ref(0)
  let run : AgentExportRun = (command, _) => {
    if command == "pack" {
      calls.val += 1
    }
    Err("synthetic failure")
  }
  let request = export_test_request(workspace~)
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.val, 1)
  @fs.write_file(
    workspace.root_path + "/actual.txt",
    "actual",
    create_mode=CreateNew,
  )
  @fs.symlink(
    target=workspace.root_path + "/actual.txt",
    workspace.root_path + "/alias.txt",
  )
  assert_true(
    try {
      ignore(
        agent_export_prepare_with(
          workspace,
          export_test_request(
            id="1123456789abcdef0123456789abcdef",
            paths=["alias.txt"],
            workspace~,
          ),
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.val, 1)
}

///|
async fn export_test_tree(
  root : String,
  relative : String,
  records : Map[String, String],
) -> Unit {
  let path = if relative == "" { root } else { root + "/" + relative }
  for name in @fs.readdir(path) {
    let child = if relative == "" { name } else { relative + "/" + name }
    if child.has_prefix("book/agents") {
      continue
    }
    match @fs.kind(root + "/" + child, follow_symlink=false) {
      Directory => export_test_tree(root, child, records)
      Regular =>
        records[child] = agent_export_file_identity(root + "/" + child).0
      _ => ()
    }
  }
}

///|
async test "local export actual compatible Book CLI prepares selected half MiB without sockets" {
  guard @env.get_env_var("MOONDESK_AGENT_EXPORT_ACCEPTANCE") is Some(evidence) else {
    return
  }
  let workspace = export_test_workspace()
  let root = workspace.root_path
  @fsx.make_directory(evidence, recursive=true, exists_ok=true)
  for
    directory in [
      "wiki/concepts", "wiki/sources", "wiki/history", "wiki/synthesis", "wiki/reviews",
      "memory/procedures", "outputs",
    ] {
    @fsx.make_directory(root + "/" + directory, recursive=true, exists_ok=true)
  }
  @fs.write_file(
    root + "/book.toml",
    "[book]\nid = \"experienced-fixture\"\ntitle = \"Experienced fixture\"\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/wiki.toml",
    "[wiki]\nsource = \"wiki\"\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/wiki/SUMMARY.md",
    "# Summary\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/wiki/index.md",
    "# Synthetic experienced Book\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/IDENTITY.md",
    "# Synthetic identity\n\nPortable fixture assistant.\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/USER.md",
    "# Synthetic preferences\n\nPrefer complete evidence.\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/wiki/concepts/accepted.md",
    "---\nreview_status: accepted\n---\n\n# Accepted concept\n\nKeep the complete meaning.\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/wiki/sources/example.md",
    "---\nreview_status: accepted\n---\n\n# Example source\n\nSynthetic source body.\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/memory/procedures/accepted.md",
    "---\nstatus: accepted\n---\n\n# Accepted procedure\n\nCheck the retained exact bytes.\n",
    create_mode=CreateNew,
  )
  @fs.write_file(
    root + "/memory/procedures/candidate.md",
    "---\nstatus: proposed\n---\n\n# Candidate\n\nDo not export yet.\n",
    create_mode=CreateNew,
  )
  let output = Bytes::from_array(Array::make(524288, b'B'))
  @fs.write_file(root + "/outputs/result.bin", output, create_mode=CreateNew)
  let before : Map[String, String] = Map([])
  export_test_tree(root, "", before)
  let runtime = @trusted_host.moonbook_export_runtime().unwrap()
  let run = agent_export_runtime_runner(runtime, root)
  let request = export_test_request(paths=["outputs/result.bin"], workspace~)
  let prepared = agent_export_prepare_with(workspace, request, run)
  let after : Map[String, String] = Map([])
  export_test_tree(root, "", after)
  guard prepared
    is {
      "inspection": {
        "files": Array(files),
        "exclusions": Array(exclusions),
        ..
      },
      "source": source,
      ..
    } else {
    fail("Missing actual complete inspection")
  }
  assert_true(
    files.any(file => {
      json_string(file, "path", default="") == "USER.md" &&
      json_string(file, "sensitivity", default="") == "user-private"
    }),
  )
  assert_true(
    files.any(file => {
      json_string(file, "path", default="") == "memory/procedures/accepted.md"
    }),
  )
  assert_true(
    exclusions.any(file => {
      json_string(file, "path", default="") == "memory/procedures/candidate.md"
    }),
  )
  let selected = files.filter(file => {
      json_string(file, "path", default="") ==
      "portable/outputs/output-0/result.bin"
    })[0]
  assert_eq(json_int(selected, "size_bytes", default=0), output.length())
  assert_eq(
    json_string(selected, "digest", default=""),
    "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(output)),
  )
  assert_eq(json_int(source, "included_output_count", default=0), 1)
  let reopened = agent_export_inspection_with(
    workspace,
    request.operation_id,
    agent_export_relative(request.operation_id),
    run,
    retained=true,
  )
  assert_eq(prepared, reopened)
  let path = root + "/" + json_string(prepared, "path", default="")
  let (digest, size) = agent_export_file_identity(path)
  assert_eq(digest, json_string(source, "package_sha256", default=""))
  assert_eq(size, json_int(source, "package_size_bytes", default=0).to_int64())
  let proof : Json = {
    "prepared": prepared,
    "workspace_root": root,
    "before": before,
    "after": after,
    "selected_bytes": output.length(),
    "package_sha256": digest,
    "no_provider": true,
    "no_socket": true,
  }
  @fs.write_file(
    evidence + "/actual-proof.json",
    proof.stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
}
