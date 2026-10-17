///|
fn export_group_fixture(id~ : String = "group-1") -> Json {
  {
    "artifact_id": id,
    "label": "Demo app",
    "mime_type": "text/html",
    "files": [
      { "source_path": "outputs/demo/index.html", "path": "index.html" },
      { "source_path": "outputs/demo/css/main.css", "path": "css/main.css" },
      {
        "source_path": "outputs/demo/images/logo.svg",
        "path": "images/logo.svg",
      },
    ],
    "preview_path": "index.html",
    "app_entrypoint": "index.html",
  }
}

///|
fn export_group_request(
  groups : Array[Json],
  paths~ : Array[String] = [],
  workspace? : @desk.DeskWorkspace,
) -> Result[AgentExportRequest, String] {
  agent_export_request({
    "operation_id": "0123456789abcdef0123456789abcdef",
    "version": "1.0.0",
    "paths": paths,
    "output_groups": groups,
    "expected_library": export_test_expected_library(workspace),
  })
}

///|
fn export_group_human_source() -> Bytes {
  let content = @encoding/utf8.encode(
    "Synthetic accepted human revision: keep the complete result. 学习\n",
  )
  let record : Json = {
    "record_id": "synthetic-task",
    "record_version": "1",
    "record_digest": "sha256:" + "1".repeat(64),
  }
  let value : Json = {
    "contract_version": "moonproj.accepted-human-result.v1",
    "source_product": "moonproj",
    "provenance_scope": "captured_accepted_human_revision",
    "authenticity": "unsigned_source_observation",
    "authorizing": false,
    "task": record,
    "report": record,
    "revision": {
      "revision_id": "synthetic-revision",
      "original_run_id": "synthetic-run",
      "session_id": "synthetic-session",
      "original_command_id": "synthetic-command",
      "output_command_id": "synthetic-output",
      "output_evidence_id": "synthetic:evidence",
      "revision_snapshot_digest": "sha256:" + "2".repeat(64),
    },
    "content": {
      "encoding": "base64",
      "media_type": "text/plain;charset=utf-8",
      "size_bytes": content.length(),
      "sha256": agent_human_result_hash(content),
      "data": @base64.encode(content, padding=true),
    },
  }
  @encoding/utf8.encode(value.stringify())
}

///|
test "grouped request keeps accepted human source separate and exact" {
  let bytes = export_group_human_source()
  let request = agent_export_request({
    "operation_id": "0123456789abcdef0123456789abcdef",
    "version": "1",
    "paths": ["plain.txt"],
    "output_groups": [export_group_fixture()],
    "expected_library": export_test_library(),
    "accepted_human_result_base64": @base64.encode(bytes, padding=true),
  }).unwrap()
  assert_eq(request.accepted_human_result.unwrap().source, bytes)
  guard agent_export_selection(request) is Array([flat, grouped, human]) else {
    fail("Missing mixed selections")
  }
  assert_true(flat is { "artifact_id": "output-0", .. })
  assert_true(grouped is { "artifact_id": "group-1", .. })
  assert_eq(
    json_string(human, "artifact_id", default=""),
    agent_human_result_artifact_id(request.accepted_human_result.unwrap()),
  )
}

///|
test "grouped export uses existing Book grouped output contract alongside ordinary files" {
  let request = export_group_request([export_group_fixture()], paths=[
    "plain.txt",
  ]).unwrap()
  assert_eq(agent_export_all_paths(request), [
    "plain.txt", "outputs/demo/index.html", "outputs/demo/css/main.css", "outputs/demo/images/logo.svg",
  ])
  guard agent_export_selection(request) is Array([flat, group]) else {
    fail("Expected flat and grouped selections")
  }
  assert_true(flat is { "artifact_id": "output-0", .. })
  assert_true(
    group
    is {
      "artifact_id": "group-1",
      "included": true,
      "files": [
        _,
        { "path": "css/main.css", .. },
        { "path": "images/logo.svg", .. },
      ],
      "preview_path": "index.html",
      "app_entrypoint": "index.html",
      ..
    },
  )
  assert_true(export_group_request([]).unwrap().output_groups.is_empty())
}

///|
test "grouped export rejects empty selections dangling links and reserved identifiers" {
  let base = export_group_fixture()
  for
    id in [
      "output-0", "accepted-human-result", "group-../x", "Group-1", "group-",
    ] {
    assert_true(export_group_request([export_group_fixture(id~)]) is Err(_))
  }
  assert_true(export_group_request([base, base]) is Err(_))
  for
    value in [
      human_result_test_field(base, "files", []),
      human_result_test_field(base, "preview_path", "missing.html"),
      human_result_test_field(base, "app_entrypoint", "missing.html"),
      human_result_test_field(base, "label", "  "),
      human_result_test_field(base, "extra", true),
      human_result_test_field(base, "included", false),
    ] {
    assert_true(export_group_request([value]) is Err(_))
  }
}

///|
test "grouped export rejects unsafe or colliding member layout and bounds total selection" {
  let base = export_group_fixture()
  for
    path in [
      "../outside", "/absolute", "a/../b", "a\\b", "a\nb", "", "index.html", "INDEX.HTML",
      "index.html/nested",
    ] {
    let files : Json = [
      { "source_path": "outputs/a", "path": "index.html" },
      { "source_path": "outputs/b", "path": path },
    ]
    assert_true(
      export_group_request([human_result_test_field(base, "files", files)])
      is Err(_),
    )
  }
  for
    source in ["../outside", "book/agents/old/package", "/absolute", "a\u0000b"] {
    let files : Json = [{ "source_path": source, "path": "index.html" }]
    assert_true(
      export_group_request([human_result_test_field(base, "files", files)])
      is Err(_),
    )
  }
  assert_true(
    export_group_request(
      [base],
      paths=Array::makei(126, i => "plain-" + i.to_string()),
    )
    is Err(_),
  )
  assert_true(
    export_group_request(
      Array::makei(17, i => export_group_fixture(id="group-" + i.to_string())),
    )
    is Err(_),
  )
}

///|
async test "grouped export validates every selected file before pack and retries only exact inputs" {
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let request = export_group_request([export_group_fixture()], workspace~).unwrap()
  let calls : Array[String] = []
  let run = export_test_runner(calls)
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_true(calls.is_empty())
  for path in agent_export_all_paths(request) {
    @fs.mkdir(
      @pathx.dirname(workspace.root_path + "/" + path).to_owned(),
      recursive=true,
    )
    @fs.write_file(
      workspace.root_path + "/" + path,
      "synthetic",
      create_mode=CreateNew,
    )
  }
  let prepared = agent_export_prepare_with(workspace, request, run)
  let again = agent_export_prepare_with(workspace, request, run)
  assert_eq(prepared, again)
  assert_eq(calls.filter(command => command == "pack").length(), 1)
  let changed = export_group_request(
    [
      human_result_test_field(
        export_group_fixture(),
        "label",
        "Different report",
      ),
    ],
    workspace~,
  ).unwrap()
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, changed, run))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(command => command == "pack").length(), 1)
}

///|
async test "grouped export actual Book CLI retains named app and report layouts" {
  guard @env.get_env_var("MOONDESK_GROUPED_EXPORT_ACCEPTANCE") is Some(evidence) else {
    return
  }
  let workspace = export_test_workspace()
  let root = workspace.root_path
  for
    directory in [
      "wiki/concepts", "wiki/sources", "wiki/history", "wiki/synthesis", "wiki/reviews",
      "outputs/demo/css", "outputs/demo/images", "outputs/report/images",
    ] {
    @fs.mkdir(root + "/" + directory, recursive=true)
  }
  for
    (path, content) in [
      (
        "book.toml", "[book]\nid = \"grouped-fixture\"\ntitle = \"Grouped deliverable fixture\"\n",
      ),
      ("wiki.toml", "[wiki]\nsource = \"wiki\"\n"),
      ("wiki/SUMMARY.md", "# Summary\n"),
      ("wiki/index.md", "# Synthetic grouped delivery Book\n"),
      (
        "outputs/demo/index.html", "<!doctype html><title>Demo app</title><link rel=\"stylesheet\" href=\"css/main.css\"><img src=\"images/logo.svg\" alt=\"Demo\"><p>Demo app</p><button onclick=\"this.textContent='Done'\">Try locally</button>\n",
      ),
      ("outputs/demo/css/main.css", "body { color: navy; }\n"),
      (
        "outputs/demo/images/logo.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"40\"><circle cx=\"20\" cy=\"20\" r=\"18\" fill=\"navy\"/></svg>\n",
      ),
      (
        "outputs/report/report.md", "# Customer report\n![Chart](images/chart.svg)\n",
      ),
      (
        "outputs/report/images/chart.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\"><text x=\"0\" y=\"20\">Synthetic report chart</text></svg>\n",
      ),
      ("plain.txt", "Standalone output remains available.\n"),
    ] {
    @fs.write_file(root + "/" + path, content, create_mode=CreateNew)
  }
  let report : Json = {
    "artifact_id": "group-2",
    "label": "Customer report",
    "mime_type": "application/octet-stream",
    "files": [
      { "source_path": "outputs/report/report.md", "path": "report.md" },
      {
        "source_path": "outputs/report/images/chart.svg",
        "path": "images/chart.svg",
      },
    ],
    "preview_path": "report.md",
  }
  let human_bytes = export_group_human_source()
  let request = agent_export_request({
    "operation_id": "0123456789abcdef0123456789abcdef",
    "version": "1.0.0",
    "paths": ["plain.txt"],
    "output_groups": [export_group_fixture(), report],
    "expected_library": export_test_expected_library(Some(workspace)),
    "accepted_human_result_base64": @base64.encode(human_bytes, padding=true),
  }).unwrap()
  let runtime = @trusted_host.moonbook_export_runtime().unwrap()
  let calls : Array[String] = []
  let actual = agent_export_runtime_runner(runtime, root)
  let run : AgentExportRun = (command, args) => {
    calls.push(command)
    actual(command, args)
  }
  let prepared = agent_export_prepare_with(workspace, request, run)
  assert_eq(prepared, agent_export_prepare_with(workspace, request, run))
  assert_eq(calls.filter(command => command == "pack").length(), 1)
  guard prepared is { "inspection": { "files": Array(inspection), .. }, .. } else {
    fail("Missing prepared file inspection")
  }
  for
    (source, target) in [
      ("outputs/demo/index.html", "portable/outputs/group-1/index.html"),
      ("outputs/demo/css/main.css", "portable/outputs/group-1/css/main.css"),
      (
        "outputs/demo/images/logo.svg", "portable/outputs/group-1/images/logo.svg",
      ),
      ("outputs/report/report.md", "portable/outputs/group-2/report.md"),
      (
        "outputs/report/images/chart.svg", "portable/outputs/group-2/images/chart.svg",
      ),
      ("plain.txt", "portable/outputs/output-0/plain.txt"),
    ] {
    let bytes = @fs.read_file(root + "/" + source).binary()
    let digest = "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
    assert_true(
      inspection.any(file => {
        json_string(file, "path", default="") == target &&
        json_string(file, "digest", default="") == digest
      }),
    )
  }
  @fsx.make_directory(evidence, recursive=true, exists_ok=true)
  @fs.write_file(
    evidence + "/human-result-source.json",
    human_bytes,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    evidence + "/human-result-content.txt",
    request.accepted_human_result.unwrap().content,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    evidence + "/prepared.json",
    (
      {
        "prepared": prepared,
        "workspace_root": root,
        "request": {
          "output_groups": ToJson::to_json(request.output_groups),
          "paths": request.paths,
        },
        "pack_calls": 1,
        "synthetic": true,
        "no_socket": true,
      } : Json).stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
}
