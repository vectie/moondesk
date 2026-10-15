///|
fn human_result_test_field(
  value : Json,
  key : String,
  replacement : Json,
) -> Json {
  guard value is Object(fields) else { return value }
  let copy = fields.copy()
  copy[key] = replacement
  Json::object(copy)
}

///|
fn human_result_test_request(
  source : Bytes,
  id? : String = "0123456789abcdef0123456789abcdef",
  workspace? : @desk.DeskWorkspace,
) -> AgentExportRequest {
  agent_export_request({
    "operation_id": id,
    "version": "1.0.0",
    "paths": [],
    "expected_library": export_test_expected_library(workspace),
    "accepted_human_result_base64": @base64.encode(source, padding=true),
  }).unwrap()
}

///|
async fn human_result_test_fixture(name : String) -> Bytes? {
  match @env.get_env_var("MOONDESK_HUMAN_RESULT_PROJ_FIXTURES") {
    Some(root) => Some(@fs.read_file(root + "/" + name + ".json").binary())
    None => None
  }
}

///|
fn human_result_test_runner(
  calls : Array[String],
  source : AgentAcceptedHumanResult,
) -> AgentExportRun {
  let base = export_test_runner(calls)
  (command, args) => {
    let response = match base(command, args) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if command == "pack" {
      return Ok(response)
    }
    let value = @json.parse(response)
    let extra = [
      ("source.json", source.source),
      ("content.txt", source.content),
    ].map(pair => {
      let (name, bytes) = pair
      (
        {
          "path": "portable/outputs/" +
          agent_human_result_artifact_id(source) +
          "/" +
          name,
          "role": "artifact",
          "digest": agent_human_result_hash(bytes),
          "size_bytes": bytes.length(),
          "review_status": "accepted",
          "sensitivity": "book-exportable",
        } : Json)
    })
    if command == "inspect" {
      guard value is { "files": Array(files), .. } else {
        fail("Invalid synthetic test inspection")
      }
      files.append(extra)
      Ok(human_result_test_field(value, "file_count", 3).stringify())
    } else if command == "source" {
      Ok(human_result_test_field(value, "file_count", 3).stringify())
    } else {
      Ok(human_result_test_field(value, "checked_file_count", 3).stringify())
    }
  }
}

///|
test "human result bounded IDs versions and opaque evidence preserve owner rules" {
  assert_true(agent_human_result_id("run:abc.123-def_4"))
  assert_true(agent_human_result_id("human-K", revision=true))
  assert_false(agent_human_result_id("human:K", revision=true))
  for invalid in ["", ".", "..", "a/b", "x".repeat(129), "💥"] {
    assert_false(agent_human_result_id(invalid))
  }
  for valid in ["1", "2147483647"] {
    assert_true(agent_human_result_version(valid))
  }
  for invalid in ["", "0", "01", "-1", "1.0", "2147483648", "99999999999"] {
    assert_false(agent_human_result_version(invalid))
  }
  assert_true(agent_human_result_evidence("native:evidence/sub-result 书"))
  assert_true(agent_human_result_evidence(".moonsuite/opaque/../evidence"))
  for
    invalid in [
      " ",
      "/private/root",
      "C:/private/root",
      "FiLe:///tmp/body",
      "evidence\\x",
      "evidence\n",
      "书".repeat(1366),
    ] {
    assert_false(agent_human_result_evidence(invalid))
  }
}

///|
test "human result source transport rejects malformed oversized and noncanonical bytes" {
  for encoded in ["", "e30", " e30=", "e30=\n", "////", "A".repeat(699056)] {
    assert_true(agent_human_result_decode(encoded) is Err(_))
  }
  assert_true(
    agent_human_result_decode(@base64.encode(b"{}", padding=true)) is Err(_),
  )
  assert_eq(
    agent_human_result_key_count("{\"x:\":\"a\\\":\",\"y\":{\"z\":1}}"),
    3,
  )
}

///|
async test "human result preparation transport bounds one MiB and reads the maximum real source" {
  let limit = 1024 * 1024
  let exact = @io.MemoryReader(writer => {
    writer.write("{}" + " ".repeat(limit - 2))
  })
  defer exact.close()
  assert_eq(agent_export_read_body(exact), Some({}))
  let excess = @io.MemoryReader(writer => {
    writer.write("{}" + " ".repeat(limit - 1))
  })
  defer excess.close()
  assert_eq(agent_export_read_body(excess), None)
  let invalid = @io.MemoryReader(writer => writer.write(b"\xff"))
  defer invalid.close()
  assert_eq(agent_export_read_body(invalid), None)
  guard human_result_test_fixture("max") is Some(original) else { return }
  let payload : Json = {
    "operation_id": "0123456789abcdef0123456789abcdef",
    "version": "1",
    "paths": [],
    "expected_library": export_test_library(),
    "accepted_human_result_base64": @base64.encode(original, padding=true),
  }
  let reader = @io.MemoryReader(writer => writer.write(payload.stringify()))
  defer reader.close()
  guard agent_export_read_body(reader) is Some(decoded) else {
    fail("Maximum source transport was truncated")
  }
  assert_true(agent_export_request(decoded) is Ok(_))
}

///|
async test "human result actual producer fixtures preserve original JSON and full UTF8 bytes" {
  for name in ["unicode", "empty", "max", "unicode-v2"] {
    guard human_result_test_fixture(name) is Some(original) else { return }
    let source = agent_human_result_decode(
      @base64.encode(original, padding=true),
    ).unwrap()
    assert_eq(source.source, original)
    let parsed = @json.parse(@encoding/utf8.decode(original))
    guard parsed
      is {
        "content": { "data": String(data), "size_bytes": Number(size, ..), .. },
        ..
      } else {
      fail("Producer fixture missing content")
    }
    assert_eq(source.content, @base64.decode(data, ignore_whitespace=false))
    assert_eq(source.content.length(), size.to_int())
    assert_eq(source.source_sha256, agent_human_result_hash(original))
    if name == "empty" {
      assert_eq(source.content.length(), 0)
    }
    if name == "max" {
      assert_eq(source.content.length(), 262144)
    }
    let request = human_result_test_request(original)
    guard agent_export_selection(request) is Array([selection]) else {
      fail("Missing exact selection")
    }
    assert_true(selection.stringify().contains("source.json"))
    assert_false(selection.stringify().contains(".moonsuite"))
  }
}

///|
async test "human result source raw bytes may include whitespace up to exact bound" {
  guard human_result_test_fixture("unicode") is Some(original) else { return }
  let text = @encoding/utf8.decode(original)
  let exact = @encoding/utf8.encode(
    text + " ".repeat(524288 - original.length()),
  )
  let source = agent_human_result_decode(@base64.encode(exact, padding=true)).unwrap()
  assert_eq(source.source, exact)
  let overflow = @encoding/utf8.encode(
    text + " ".repeat(524289 - original.length()),
  )
  assert_true(
    agent_human_result_decode(@base64.encode(overflow, padding=true)) is Err(_),
  )
  assert_true(
    agent_human_result_decode(
      @base64.encode(@encoding/utf8.encode("\uFEFF" + text), padding=true),
    )
    is Err(_),
  )
}

///|
async test "human result rejects altered schema provenance size hash base64 IDs and binary" {
  guard human_result_test_fixture("unicode") is Some(original) else { return }
  let valid = @json.parse(@encoding/utf8.decode(original))
  guard valid is { "content": content, "task": task, "revision": revision, .. } else {
    fail("Missing producer fields")
  }
  let invalid : Array[Json] = [
    human_result_test_field(
      valid, "contract_version", "moonproj.accepted-human-result.v2",
    ),
    human_result_test_field(valid, "source_product", "other"),
    human_result_test_field(valid, "provenance_scope", "live_accepted"),
    human_result_test_field(valid, "authenticity", "signed"),
    human_result_test_field(valid, "authorizing", true),
    human_result_test_field(valid, "workspace", "/private/workspace"),
    human_result_test_field(
      valid,
      "content",
      human_result_test_field(content, "size_bytes", -1),
    ),
    human_result_test_field(
      valid,
      "content",
      human_result_test_field(content, "size_bytes", 0.5),
    ),
    human_result_test_field(
      valid,
      "content",
      human_result_test_field(content, "size_bytes", 262145),
    ),
    human_result_test_field(
      valid,
      "content",
      human_result_test_field(
        content,
        "sha256",
        Json::string("sha256:" + "0".repeat(64)),
      ),
    ),
    human_result_test_field(
      valid,
      "content",
      human_result_test_field(content, "data", "?"),
    ),
    human_result_test_field(
      valid,
      "task",
      human_result_test_field(task, "record_version", 1),
    ),
    human_result_test_field(
      valid,
      "task",
      human_result_test_field(task, "record_id", "../outside"),
    ),
    human_result_test_field(
      valid,
      "revision",
      human_result_test_field(
        revision, "output_evidence_id", "/private/absolute",
      ),
    ),
  ]
  for bytes in [b"\x00", b"\xff", Bytes::from_array(Array::make(262145, b'A'))] {
    invalid.push(
      human_result_test_field(valid, "content", {
        "encoding": "base64",
        "media_type": "text/plain;charset=utf-8",
        "size_bytes": bytes.length(),
        "sha256": agent_human_result_hash(bytes),
        "data": @base64.encode(bytes, padding=true),
      }),
    )
  }
  for value in invalid {
    assert_true(
      agent_human_result_decode(
        @base64.encode(@encoding/utf8.encode(value.stringify()), padding=true),
      )
      is Err(_),
    )
  }
  let text = @encoding/utf8.decode(original)
  let duplicated = "{\"authorizing\":false," +
    text.trim().to_owned()[1:].to_owned()
  assert_true(
    agent_human_result_decode(
      @base64.encode(@encoding/utf8.encode(duplicated), padding=true),
    )
    is Err(_),
  )
}

///|
async test "human result retained retries match exact captured identity and never repack" {
  guard human_result_test_fixture("unicode") is Some(original) &&
    human_result_test_fixture("unicode-v2") is Some(newer) else {
    return
  }
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let request = human_result_test_request(original, workspace~)
  let imported = request.accepted_human_result.unwrap()
  let calls : Array[String] = []
  let run = human_result_test_runner(calls, imported)
  let first = agent_export_prepare_with(workspace, request, run)
  let second = agent_export_prepare_with(workspace, request, run)
  assert_eq(first, second)
  assert_eq(calls.filter(call => call == "pack").length(), 1)
  for
    mismatch in [
      human_result_test_request(newer, workspace~),
      export_test_request(workspace~),
    ] {
    assert_true(
      try {
        ignore(agent_export_prepare_with(workspace, mismatch, run))
        false
      } catch {
        _ => true
      },
    )
  }
  let changed_format = @encoding/utf8.encode(
    @encoding/utf8.decode(original) + "\n",
  )
  assert_true(
    try {
      ignore(
        agent_export_prepare_with(
          workspace,
          human_result_test_request(changed_format, workspace~),
          run,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  let captured = workspace.root_path +
    "/" +
    agent_export_relative(request.operation_id) +
    "/accepted-human-result/source.json"
  assert_eq(@fs.read_file(captured).binary(), original)
  @fs.write_file(captured, newer, create_mode=TruncateExisting)
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(call => call == "pack").length(), 1)
}

///|
async test "human result absent package members fail preparation truthfully without retained commit" {
  guard human_result_test_fixture("unicode") is Some(original) else { return }
  let workspace = export_test_workspace()
  defer @fs.rmdir(workspace.root_path, recursive=true)
  let request = human_result_test_request(original, workspace~)
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
  assert_false(
    @fs.exists(
      workspace.root_path + "/" + agent_export_relative(request.operation_id),
    ),
  )
  assert_true(agent_export_retained(workspace).is_empty())
  assert_true(
    try {
      ignore(agent_export_prepare_with(workspace, request, run))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(calls.filter(call => call == "pack").length(), 1)
}

///|
async test "human result fixture emitter uses actual Desk request and staging for paired Book tests" {
  guard @env.get_env_var("MOONDESK_HUMAN_RESULT_FIXTURE_ROOT") is Some(output) else {
    return
  }
  let records : Array[Json] = []
  for name in ["unicode", "empty", "max", "unicode-v2"] {
    guard human_result_test_fixture(name) is Some(original) else {
      fail("Producer fixtures are required for paired staging")
    }
    let directory = output + "/" + name
    let root = directory + "/book"
    @fs.mkdir(root, recursive=true)
    let root = @fs.realpath(root)
    let directory = @pathx.dirname(root).to_owned()
    let workspace = @desk.workspace(
      id="human-result-fixture",
      name="Human result fixture",
      root_path=root,
      kind=MoonBook,
    )
    // Simulate the explicitly chosen external file changing after the request
    // captured its bytes. The preparation must never reopen that source path.
    let chosen_path = directory + "/chosen-source.json"
    @fs.write_file(chosen_path, original, create_mode=CreateNew)
    let request = {
      ..human_result_test_request(@fs.read_file(chosen_path).binary()),
      expected_library: directory,
    }
    @fs.write_file(
      chosen_path,
      "Changed after the user selected the source",
      create_mode=TruncateExisting,
    )
    let calls = Ref(0)
    let run : AgentExportRun = (command, args) => {
      assert_eq(command, "pack")
      calls.val += 1
      let selection = @fs.read_file(args[2]).binary()
      @fs.write_file(
        directory + "/outputs-selection.json",
        selection,
        create_mode=CreateNew,
      )
      Err(
        "Paired qualification intentionally stops at the exact Book pack boundary",
      )
    }
    assert_true(
      try {
        ignore(agent_export_prepare_with(workspace, request, run))
        false
      } catch {
        _ => true
      },
    )
    assert_eq(calls.val, 1)
    let staged = root +
      "/" +
      agent_human_result_staging_relative(request.operation_id)
    assert_eq(@fs.read_file(staged + "/source.json").binary(), original)
    assert_eq(
      @fs.read_file(staged + "/content.txt").binary(),
      request.accepted_human_result.unwrap().content,
    )
    records.push({
      "case": name,
      "book_root": root,
      "selection": directory + "/outputs-selection.json",
      "source_sha256": agent_human_result_hash(original),
    })
  }
  @fs.write_file(
    output + "/DESK_STAGING.json",
    (
      {
        "contract": "accepted-human-result-desk-qualification.v1",
        "actual_producer_fixtures": true,
        "real_desk_parser_and_staging": true,
        "pack_boundary_only": true,
        "cases": records,
      } : Json).stringify(indent=2),
    create_mode=CreateNew,
  )
}
