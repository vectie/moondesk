///|
async fn human_revision_fixture(root? : String) -> WorkContinuationFixture {
  if root is Some(value) && !@fs.exists(value) {
    @fs.mkdir(value, recursive=true)
  }
  let fixture = work_continuation_fixture(root?)
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Original 书\n",
    ),
  )
  fixture
}

///|
fn human_revision_request(fixture : WorkContinuationFixture) -> Json {
  {
    "operation": "save",
    "revision_id": "human-K",
    "source": mooncode_output_field(fixture.request, "source"),
    "output": {
      "command_id": "C0",
      "path": "result.md",
      "evidence_id": "event-C0",
    },
    "expected_content": "Original 书\n",
    "content": "Human revision 人工\n  retain spaces  \n",
  }
}

///|
async fn human_revision_call(
  fixture : WorkContinuationFixture,
  request? : Json,
  capture~ : async (String, String, String) -> Result[Unit, String] = mooncode_human_revision_capture,
) -> (Int32, Json) {
  mooncode_edit_work_output(
    fixture.workspace.root_path,
    [fixture.workspace],
    request.unwrap_or(human_revision_request(fixture)),
    path => fixture.read(path),
    capture~,
  )
}

///|
async test "human revision open reads exact bounded current output without mutation" {
  let fixture = human_revision_fixture()
  let request = mooncode_session_with_field(
    human_revision_request(fixture),
    "operation",
    "open".to_json(),
  )
  let result = human_revision_call(fixture, request~)
  assert_eq(result.0, 200)
  assert_eq(mooncode_output_text(result.1, "state"), "ready")
  assert_eq(
    mooncode_output_text(result.1, "capture_scope"),
    "immutable_human_revision",
  )
  assert_eq(mooncode_output_text(result.1, "content"), "Original 书\n")
  assert_eq(
    mooncode_output_text(result.1, "base_digest"),
    mooncode_continuation_hash("Original 书\n"),
  )
  assert_eq(
    mooncode_output_field(result.1, "source"),
    mooncode_output_field(request, "source"),
  )
  assert_eq(
    mooncode_output_field(result.1, "output"),
    mooncode_output_field(request, "output"),
  )
  assert_false(
    @fs.exists(
      fixture.workspace.root_path +
      "/.moonsuite/products/moonproj/human-revisions",
    ),
  )
  assert_eq(fixture.posts.length(), 0)
}

///|
async test "human revision captures exact UTF8 manifest and replay preserves newer live bytes" {
  let fixture = human_revision_fixture()
  let request = human_revision_request(fixture)
  let result = human_revision_call(fixture)
  assert_eq(result.0, 200)
  assert_eq(mooncode_output_text(result.1, "state"), "saved")
  assert_eq(
    mooncode_output_text(result.1, "capture_scope"),
    "immutable_human_revision",
  )
  let manifest = mooncode_output_field(result.1, "revision")
  assert_eq(
    manifest,
    mooncode_human_revision_manifest(
      mooncode_human_revision_request(request, fixture.workspace.root_path),
      fixture.workspace.id,
      mooncode_output_text(manifest, "created_at"),
    ),
  )
  let content = mooncode_output_text(request, "content")
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
  assert_eq(
    @fsx.read_confined_text(
      fixture.workspace.root_path,
      mooncode_human_revision_path("human-K", "content.txt"),
    ),
    Some(content),
  )
  assert_eq(
    mooncode_human_revision_read_json(
      fixture.workspace.root_path,
      "human-K",
      "revision.json",
    ),
    Ok(Some(manifest)),
  )
  let metadata = mooncode_output_field(manifest, "content")
  assert_eq(
    json_int(metadata, "size_bytes", default=-1),
    @encoding/utf8.encode(content).length(),
  )
  assert_eq(mooncode_output_text(metadata, "sha256").length(), 64)
  assert_true(
    mooncode_output_text(metadata, "sha256")
    .iter()
    .all(c => c.is_ascii_digit() || (c >= 'a' && c <= 'f')),
  )
  for key in ["receipt", "model", "promotion", "command"] {
    assert_eq(mooncode_output_field(manifest, key), Json::null())
  }
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Newer agent bytes",
    ),
  )
  assert_eq(human_revision_call(fixture), result)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Newer agent bytes"),
  )
  assert_eq(fixture.posts.length(), 0)
}

///|
async test "human revision definitive conflict survives same-ID retry and requires explicit new revision" {
  let fixture = human_revision_fixture()
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "External edit",
    ),
  )
  let result = human_revision_call(fixture)
  assert_eq(result.0, 409)
  assert_eq(mooncode_output_text(result.1, "state"), "conflict")
  assert_eq(mooncode_output_text(result.1, "current_content"), "External edit")
  assert_false(
    @fs.exists(
      fixture.workspace.root_path +
      "/" +
      mooncode_human_revision_path("human-K", "revision.json"),
    ),
  )
  assert_false(
    @fs.exists(
      fixture.workspace.root_path +
      "/" +
      mooncode_human_revision_path("human-K", "base.json"),
    ),
  )
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Original 书\n",
    ),
  )
  assert_eq(human_revision_call(fixture), result)
  let next = mooncode_session_with_field(
    human_revision_request(fixture),
    "revision_id",
    "new-revision".to_json(),
  )
  assert_eq(human_revision_call(fixture, request=next).0, 200)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
}

///|
async test "human revision conflict replay retries durability before returning definitive conflict" {
  let fixture = human_revision_fixture()
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Observed conflict",
    ),
  )
  let failed_flushes = Ref(0)
  let fail_conflict : async (String, String, String) -> Result[Unit, String] = (
    root,
    path,
    content,
  ) => {
    let result = mooncode_human_revision_capture(root, path, content)
    if path.has_suffix("/conflict.json") {
      failed_flushes.val += 1
      Err("injected uncertain conflict publication")
    } else {
      result
    }
  }
  assert_eq(human_revision_call(fixture, capture=fail_conflict).0, 503)
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Original 书\n",
    ),
  )
  assert_eq(human_revision_call(fixture, capture=fail_conflict).0, 503)
  assert_eq(failed_flushes.val, 2)
  let result = human_revision_call(fixture)
  assert_eq(result.0, 409)
  assert_eq(mooncode_output_text(result.1, "state"), "conflict")
  assert_eq(
    mooncode_output_text(result.1, "current_content"),
    "Observed conflict",
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
  assert_false(
    @fs.exists(
      fixture.workspace.root_path +
      "/" +
      mooncode_human_revision_path("human-K", "revision.json"),
    ),
  )
}

///|
async test "human revision rejects reuse with changed content baseline task or run" {
  let fixture = human_revision_fixture()
  assert_eq(human_revision_call(fixture).0, 200)
  let original = human_revision_request(fixture)
  let changed : Array[Json] = [
    mooncode_session_with_field(original, "content", "replacement".to_json()),
    mooncode_session_with_field(
      original,
      "expected_content",
      "replacement".to_json(),
    ),
    mooncode_session_with_field(
      original,
      "source",
      mooncode_session_with_field(
        mooncode_output_field(original, "source"),
        "task_id",
        "other-task".to_json(),
      ),
    ),
    mooncode_session_with_field(
      original,
      "source",
      mooncode_session_with_field(
        mooncode_output_field(original, "source"),
        "run_id",
        "other-run".to_json(),
      ),
    ),
  ]
  for request in changed {
    let result = human_revision_call(fixture, request~)
    assert_eq(result.0, 409)
    assert_eq(mooncode_output_text(result.1, "state"), "idempotency_conflict")
  }
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
}

///|
async test "human revision capture failure at every stage leaves source untouched and retries exact operation" {
  for
    failed_stage in [
      "operation.json", "base.json", "content.txt", "revision.json",
    ] {
    let fixture = human_revision_fixture()
    let result = human_revision_call(fixture, capture=(root, path, content) => {
      if path.has_suffix("/" + failed_stage) {
        Err("injected capture failure")
      } else {
        mooncode_human_revision_capture(root, path, content)
      }
    })
    assert_eq(result.0, 503)
    assert_eq(mooncode_output_text(result.1, "state"), "capture_unavailable")
    assert_eq(
      @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
      Some("Original 书\n"),
    )
    assert_false(
      @fs.exists(
        fixture.workspace.root_path +
        "/" +
        mooncode_human_revision_path("human-K", "revision.json"),
      ),
    )
    assert_eq(human_revision_call(fixture).0, 200)
    assert_eq(
      @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
      Some("Original 书\n"),
    )
  }
}

///|
async test "human revision durable base observation permits capture retry after source changes or disappears" {
  for remove_source in [false, true] {
    let fixture = human_revision_fixture()
    let result = human_revision_call(fixture, capture=(root, path, content) => {
      if path.has_suffix("/revision.json") {
        Err("injected publication failure")
      } else {
        mooncode_human_revision_capture(root, path, content)
      }
    })
    assert_eq(result.0, 503)
    if remove_source {
      @fs.rename(
        fixture.workspace.root_path + "/result.md",
        fixture.workspace.root_path + "/moved.md",
      )
    } else {
      assert_true(
        @fsx.write_confined_text(
          fixture.workspace.root_path,
          "result.md",
          "Later agent edit",
        ),
      )
    }
    assert_eq(human_revision_call(fixture).0, 200)
    if remove_source {
      assert_false(@fs.exists(fixture.workspace.root_path + "/result.md"))
      assert_eq(
        @fsx.read_confined_text(fixture.workspace.root_path, "moved.md"),
        Some("Original 书\n"),
      )
    } else {
      assert_eq(
        @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
        Some("Later agent edit"),
      )
    }
  }
}

///|
async test "human revision concurrent change between observation and capture never overwrites live output" {
  let fixture = human_revision_fixture()
  let result = human_revision_call(fixture, capture=(root, path, content) => {
    let captured = mooncode_human_revision_capture(root, path, content)
    if path.has_suffix("/base.json") {
      assert_true(
        @fsx.write_confined_text(
          root, "result.md", "Concurrent agent edit 人工\n",
        ),
      )
    }
    captured
  })
  assert_eq(result.0, 200)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Concurrent agent edit 人工\n"),
  )
  assert_eq(
    mooncode_output_text(result.1, "content"),
    mooncode_output_text(human_revision_request(fixture), "content"),
  )
  assert_eq(human_revision_call(fixture), result)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Concurrent agent edit 人工\n"),
  )
}

///|
async test "human revision uncertain base-marker sync retries immutable capture after live source change" {
  let fixture = human_revision_fixture()
  let result = human_revision_call(fixture, capture=(root, path, content) => {
    let captured = mooncode_human_revision_capture(root, path, content)
    if path.has_suffix("/base.json") {
      Err("injected response loss after durable observation")
    } else {
      captured
    }
  })
  assert_eq(result.0, 503)
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "After restart",
    ),
  )
  assert_eq(human_revision_call(fixture).0, 200)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("After restart"),
  )
}

///|
async test "human revision rejects forged output evidence traversal own storage and runtime outage" {
  let fixture = human_revision_fixture()
  let request = human_revision_request(fixture)
  let outputs : Array[Json] = [
    { "command_id": "C0", "path": "result.md", "evidence_id": "event-other" },
    {
      "command_id": "unrelated-C2",
      "path": "result.md",
      "evidence_id": "event-C0",
    },
    { "command_id": "C0", "path": "other.md", "evidence_id": "event-C0" },
    { "command_id": "C0", "path": "../result.md", "evidence_id": "event-C0" },
    {
      "command_id": "C0",
      "path": ".moonsuite/products/moonproj/human-revisions/another/content.txt",
      "evidence_id": "event-C0",
    },
  ]
  for output in outputs {
    assert_true(
      human_revision_call(
        fixture,
        request=mooncode_session_with_field(request, "output", output),
      ).0 !=
      200,
    )
  }
  fixture.unavailable.val = true
  assert_eq(human_revision_call(fixture).0, 503)
  assert_false(
    @fs.exists(
      fixture.workspace.root_path +
      "/.moonsuite/products/moonproj/human-revisions",
    ),
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
}

///|
async test "human revision UTF8 byte bound rejects binary and accepts exact empty edited text" {
  let fixture = human_revision_fixture()
  let request = human_revision_request(fixture)
  for text in ["书".repeat(90000), "binary\u0000bytes"] {
    assert_eq(
      human_revision_call(
        fixture,
        request=mooncode_session_with_field(request, "content", text.to_json()),
      ).0,
      400,
    )
  }
  let open = mooncode_session_with_field(request, "operation", "open".to_json())
  @fs.write_file(
    fixture.workspace.root_path + "/result.md",
    b"\xff\xfe",
    create_mode=CreateOrTruncate,
  )
  assert_eq(human_revision_call(fixture, request=open).0, 409)
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "x".repeat(256 * 1024 + 1),
    ),
  )
  assert_eq(human_revision_call(fixture, request=open).0, 409)
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      "result.md",
      "Original 书\n",
    ),
  )
  let result = human_revision_call(
    fixture,
    request=mooncode_session_with_field(request, "content", "".to_json()),
  )
  assert_eq(result.0, 200)
  assert_eq(mooncode_output_text(result.1, "content"), "")
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
}

///|
async test "human revision preserves confined symlink source policy without changing target bytes" {
  let fixture = human_revision_fixture()
  @fs.rename(
    fixture.workspace.root_path + "/result.md",
    fixture.workspace.root_path + "/actual.md",
  )
  @fs.symlink(
    fixture.workspace.root_path + "/result.md",
    target=fixture.workspace.root_path + "/actual.md",
  )
  assert_eq(human_revision_call(fixture).0, 200)
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "actual.md"),
    Some("Original 书\n"),
  )
}

///|
async test "human revision raw percent and plus path remains exact in retained lineage" {
  let fixture = human_revision_fixture()
  let path = "literal%20+书.md"
  let events : Json = [
    {
      "id": "event-C0",
      "session_id": "S",
      "command_id": "C0",
      "kind": "tool_result",
      "event": "tool_result",
      "tool": "write",
      "path": path,
      "tool_result": { "ok": true },
    },
  ]
  fixture.events.val = mooncode_session_with_field(
    fixture.events.val,
    "events",
    events,
  )
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      path,
      "Original 书\n",
    ),
  )
  let request = mooncode_session_with_field(
    human_revision_request(fixture),
    "output",
    { "command_id": "C0", "path": path, "evidence_id": "event-C0" },
  )
  let result = human_revision_call(fixture, request~)
  assert_eq(result.0, 200)
  assert_eq(
    mooncode_output_field(mooncode_output_field(result.1, "revision"), "output"),
    mooncode_output_field(request, "output"),
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, path),
    Some("Original 书\n"),
  )
}

///|
async test "human revision continuation output preserves exact command evidence and task lineage" {
  let fixture = human_revision_fixture()
  let continuation = fixture.submit()
  assert_eq(continuation.0, 200)
  let command = mooncode_output_text(continuation.1, "command_id")
  let event : Json = {
    "id": "event-C1",
    "session_id": "S",
    "command_id": command,
    "kind": "tool_result",
    "event": "tool_result",
    "tool": "edit",
    "path": "result.md",
    "tool_result": { "ok": true },
  }
  let events = mooncode_output_items(fixture.events.val, "events")
  events.push(event)
  fixture.events.val = mooncode_session_with_field(
    fixture.events.val,
    "events",
    events.to_json(),
  )
  let request = mooncode_session_with_field(
    human_revision_request(fixture),
    "output",
    { "command_id": command, "path": "result.md", "evidence_id": "event-C1" },
  )
  let wrong = mooncode_session_with_field(
    request,
    "source",
    mooncode_session_with_field(
      mooncode_output_field(request, "source"),
      "task_id",
      "other-task".to_json(),
    ),
  )
  assert_eq(
    mooncode_output_text(human_revision_call(fixture, request=wrong).1, "state"),
    "identity_mismatch",
  )
  let result = human_revision_call(fixture, request~)
  assert_eq(result.0, 200)
  let revision = mooncode_output_field(result.1, "revision")
  assert_eq(mooncode_output_text(revision, "original_command_id"), "C0")
  assert_eq(
    mooncode_output_field(revision, "output"),
    mooncode_output_field(request, "output"),
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
  assert_eq(fixture.posts.length(), 1)
}

///|
async test "human revision exact 256KiB control-text boundary survives JSON roundtrip with source untouched" {
  let fixture = human_revision_fixture()
  let baseline = "b".repeat(256 * 1024)
  let content = "\u0001\"\\\n".repeat(65536)
  assert_eq(@encoding/utf8.encode(content).length(), 256 * 1024)
  assert_true(
    @fsx.write_confined_text(fixture.workspace.root_path, "result.md", baseline),
  )
  let request = human_revision_request(fixture)
    |> mooncode_session_with_field("expected_content", baseline.to_json())
    |> mooncode_session_with_field("content", content.to_json())
  let request = @json.parse(request.stringify())
  let opened = human_revision_call(
    fixture,
    request=mooncode_session_with_field(request, "operation", "open".to_json()),
  )
  assert_eq(opened.0, 200)
  assert_eq(mooncode_output_text(opened.1, "content"), baseline)
  let result = human_revision_call(fixture, request~)
  assert_eq(result.0, 200)
  assert_eq(
    mooncode_output_text(@json.parse(result.1.stringify()), "content"),
    content,
  )
  assert_eq(
    @fsx.read_confined_text(
      fixture.workspace.root_path,
      mooncode_human_revision_path("human-K", "content.txt"),
    ),
    Some(content),
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some(baseline),
  )
}

///|
async test "human revision producer retains a real handler fixture for Proj consumer verification" {
  let fixture = human_revision_fixture(
    root?=@env.get_env_var("MOONDESK_HUMAN_REVISION_FIXTURE_ROOT"),
  )
  let result = human_revision_call(fixture)
  assert_eq(result.0, 200)
  let revision = mooncode_output_field(result.1, "revision")
  assert_eq(
    mooncode_output_text(revision, "capture_scope"),
    "immutable_human_revision",
  )
  assert_eq(
    mooncode_human_revision_read_json(
      fixture.workspace.root_path,
      "human-K",
      "revision.json",
    ),
    Ok(Some(revision)),
  )
  assert_eq(
    @fsx.read_confined_text(fixture.workspace.root_path, "result.md"),
    Some("Original 书\n"),
  )
  assert_eq(fixture.posts.length(), 0)
}
