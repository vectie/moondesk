///|
priv struct WorkContinuationFixture {
  workspace : @desk.DeskWorkspace
  request : Json
  claims : Ref[Json]
  events : Ref[Json]
  posts : Array[String]
  unavailable : Ref[Bool]
  lose_response : Ref[Bool]
  admit : Ref[Bool]
  context_path : String
}

///|
async fn work_continuation_fixture(
  status~ : String = "runtime-completed",
  root? : String,
) -> WorkContinuationFixture {
  let root = match root {
    Some(value) => value
    None => @fs.tmpdir(prefix="desk-work-continuation-")
  }
  let context = "# Captured PRD\nOriginal full requirements, Unicode 书 and no current catalog replacement.\n"
  let context_path = ".moonsuite/products/moonproj/execution-context/" +
    mooncode_continuation_hash(context) +
    "/context.md"
  assert_true(@fsx.write_confined_text(root, context_path, context))
  let original : Json = {
    "command_id": "C0",
    "session_id": "S",
    "action": "prompt",
    "claim_status": "delivered",
    "command": {
      "protocol": "mooncode.v1",
      "command": "prompt",
      "session_id": "S",
      "book_root": root,
      "packet": { "command_id": "C0", "client_turn_id": "original-U" },
      "model": "moongate/captured-model",
      "context_path": context_path,
      "text": "Original requirements",
      "horizon_id": "old-horizon",
      "horizon_checkpoint": { "next_action": "obsolete" },
      "payload": {
        "task_intent": "old-intent",
        "approval_id": "old-approval",
        "runtime_tool_calls": [{ "name": "do-not-copy" }],
      },
    },
    "receipt": {
      "session_id": "S",
      "command_id": "C0",
      "status": status,
      "id": "receipt-C0",
      "execution": {
        "tool_results": [
          {
            "tool": "finish",
            "accepted": true,
            "result": { "output": "Original result" },
          },
        ],
        "planner_continuation": "do-not-copy",
      },
    },
  }
  let claims : Json = {
    "kind": "mooncode-runtime-claim-state",
    "protocol": "mooncode.v1",
    "session_id": "S",
    "book_root": root,
    "claimable_commands": [],
    "claimed_commands": [],
    "order_blocked_commands": [],
    "invalid_commands": [],
    "delivered_commands": [original],
  }
  let events : Json = {
    "session_id": "S",
    "book_root": root,
    "events": [
      {
        "id": "event-C0",
        "session_id": "S",
        "command_id": "C0",
        "kind": "tool_result",
        "event": "tool_result",
        "tool": "write",
        "path": "result.md",
        "tool_result": { "ok": true },
      },
      {
        "id": "event-other",
        "session_id": "S",
        "command_id": "unrelated-C2",
        "kind": "tool_result",
        "path": "unrelated.md",
      },
      {
        "id": "steer-event",
        "session_id": "S",
        "command_id": "steer-1",
        "kind": "steer_deferred",
        "steering_text": "Pending human steering",
      },
    ],
  }
  {
    workspace: @desk.workspace(
      id="book",
      name="Book",
      root_path=root,
      kind=MoonBook,
    ),
    request: {
      "schema": "moondesk.work-continuation-request.v1",
      "operation": "submit",
      "continuation_id": "K",
      "client_turn_id": "U",
      "source": {
        "task_id": "T",
        "run_id": "R",
        "session_id": "S",
        "original_command_id": "C0",
        "book_root": root,
      },
      "prior_result_command_id": "C0",
      "instruction": "  Improve this result exactly\n保持格式  ",
    },
    claims: Ref(claims),
    events: Ref(events),
    posts: [],
    unavailable: Ref(false),
    lose_response: Ref(false),
    admit: Ref(true),
    context_path,
  }
}

///|
fn WorkContinuationFixture::read(
  self : WorkContinuationFixture,
  path : String,
) -> Result[Json, String] {
  if self.unavailable.val {
    return Err("fixture unavailable")
  }
  if path.contains("/runtime-claim?") {
    return Ok(self.claims.val)
  }
  if path.contains("/runtime-events?") {
    return Ok(self.events.val)
  }
  if path.contains("/runtime-service?") {
    return Ok({
      "session_id": "S",
      "book_root": self.workspace.root_path,
      "status": "running",
    })
  }
  Ok({
    "protocol": "mooncode.v1",
    "sessions": [
      {
        "id": "S",
        "book_root": self.workspace.root_path,
        "status": "durable",
        "model": "later-global-model",
      },
    ],
  })
}

///|
async fn WorkContinuationFixture::post(
  self : WorkContinuationFixture,
  _path : String,
  body : String,
) -> Result[Json, String] {
  let native = @json.parse(body)
  let lineage = json_object_field_or_empty(
    json_object_field_or_empty(native, "payload"),
    "moonproj_continuation",
  )
  let id = json_string(lineage, "continuation_id", default="")
  let saved = mooncode_continuation_load(
    self.workspace.root_path,
    id,
    mooncode_continuation_request_target(self.request),
  )
  guard saved is Ok(Some(snapshot)) else {
    fail("Snapshot must be fully durable before native POST")
  }
  assert_eq(json_string(snapshot, "request_body", default=""), body)
  self.posts.push(body)
  let command_id = json_string(
    json_object_field_or_empty(native, "packet"),
    "command_id",
    default="",
  )
  if self.admit.val {
    let accepted : Json = {
      "command_id": command_id,
      "session_id": "S",
      "action": "prompt",
      "claim_status": "claimed",
      "command": native,
      "receipt": {
        "session_id": "S",
        "command_id": command_id,
        "status": "runtime-claimed",
      },
    }
    self.claims.val = self.claims.val
      |> mooncode_session_with_field(
        "claimed_commands",
        ToJson::to_json([accepted]),
      )
  }
  if self.lose_response.val {
    return Err("response lost after send")
  }
  Ok({
    "accepted": true,
    "session_id": "S",
    "command_id": command_id,
    "book_root": self.workspace.root_path,
  })
}

///|
async fn WorkContinuationFixture::submit(
  self : WorkContinuationFixture,
  request? : Json,
  ready~ : Bool = true,
) -> (Int32, Json) {
  mooncode_continue_work(
    self.workspace.root_path,
    [self.workspace],
    request.unwrap_or(self.request),
    path => self.read(path),
    (path, body) => self.post(path, body),
    () => ready,
  )
}

///|
fn WorkContinuationFixture::resume_request(
  self : WorkContinuationFixture,
) -> Json {
  {
    "schema": "moondesk.work-continuation-request.v1",
    "operation": "resume",
    "continuation_id": "K",
    "source": {
      "session_id": "S",
      "original_command_id": "C0",
      "book_root": self.workspace.root_path,
    },
  }
}

///|
async test "bound continuation terminal C0 gets fresh default horizon and immutable complete input" {
  for status in ["runtime-completed", "runtime-failed", "runtime-cancelled"] {
    let fixture = work_continuation_fixture(status~)
    let original = json_array_items(fixture.claims.val, "delivered_commands")[0]
    let (code, response) = fixture.submit()
    assert_eq(code, 200)
    assert_eq(json_string(response, "admission", default=""), "accepted")
    assert_eq(fixture.posts.length(), 1)
    assert_eq(
      json_array_items(fixture.claims.val, "delivered_commands")[0],
      original,
    )
    let body = @json.parse(fixture.posts[0])
    let payload = json_object_field_or_empty(body, "payload")
    assert_eq(
      json_string(body, "text", default=""),
      json_string(fixture.request, "instruction", default=""),
    )
    assert_eq(json_string(body, "model", default=""), "moongate/captured-model")
    assert_eq(json_string(body, "session_id", default=""), "S")
    assert_eq(
      json_string(body, "book_root", default=""),
      fixture.workspace.root_path,
    )
    assert_true(json_object_field(body, "horizon_id") is None)
    assert_true(json_object_field(payload, "task_intent") is None)
    assert_false(fixture.posts[0].contains("old-horizon"))
    assert_false(fixture.posts[0].contains("old-approval"))
    assert_false(fixture.posts[0].contains("do-not-copy"))
    let input = @fsx.read_confined_text(
      fixture.workspace.root_path,
      mooncode_continuation_path("K", "input.md"),
    ).unwrap()
    assert_true(
      input.has_prefix("  Improve this result exactly\n保持格式  "),
    )
    assert_true(input.contains("Original full requirements"))
    assert_true(input.contains(fixture.context_path))
    assert_true(input.contains("receipt-C0"))
    assert_true(input.contains("event-C0"))
    assert_true(input.contains("result.md"))
    assert_false(input.contains("event-other"))
    assert_false(input.contains("Pending human steering"))
    assert_false(input.contains("planner_continuation"))
  }
}

///|
async test "bound continuation duplicate lost response and explicit resume use exact captured C1" {
  let fixture = work_continuation_fixture()
  fixture.lose_response.val = true
  let first = fixture.submit()
  assert_eq(json_string(first.1, "admission", default=""), "accepted")
  let exact = fixture.posts[0]
  assert_true(
    @fsx.write_confined_text(
      fixture.workspace.root_path,
      fixture.context_path,
      "Today's modified context must never replace captured C1 input",
    ),
  )
  let duplicate = fixture.submit()
  assert_eq(duplicate.0, 200)
  assert_eq(fixture.posts.length(), 1)
  let resumed = fixture.submit(request=fixture.resume_request())
  assert_eq(resumed.0, 200)
  assert_eq(fixture.posts.length(), 2)
  assert_eq(fixture.posts[1], exact)
  let command = json_array_items(fixture.claims.val, "claimed_commands")[0]
  let completed = command
    |> mooncode_session_with_field("claim_status", ToJson::to_json("delivered"))
    |> mooncode_session_with_field("receipt", {
      "session_id": "S",
      "command_id": json_string(command, "command_id", default=""),
      "status": "runtime-completed",
    })
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field("claimed_commands", Json::array([]))
    |> mooncode_session_with_field(
      "delivered_commands",
      ToJson::to_json([
        json_array_items(fixture.claims.val, "delivered_commands")[0],
        completed,
      ]),
    )
  let settled = fixture.submit(request=fixture.resume_request())
  assert_eq(json_string(settled.1, "state", default=""), "completed")
  assert_eq(fixture.posts.length(), 2)
}

///|
async test "bound continuation changed instruction lineage or reused client id conflicts" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit(ready=false).0, 503)
  for
    request in [
      fixture.request
      |> mooncode_session_with_field("instruction", ToJson::to_json("changed")),
      fixture.request
      |> mooncode_session_with_field(
        "client_turn_id",
        ToJson::to_json("changed-U"),
      ),
      fixture.request
      |> mooncode_session_with_field(
        "source",
        json_object_field_or_empty(fixture.request, "source")
        |> mooncode_session_with_field(
          "task_id",
          ToJson::to_json("different-T"),
        ),
      ),
      fixture.request
      |> mooncode_session_with_field(
        "continuation_id",
        ToJson::to_json("different-K"),
      ),
    ] {
    assert_eq(fixture.submit(request~).0, 409)
  }
  assert_eq(fixture.posts.length(), 0)
}

///|
async test "bound continuation unconfirmed admission retains K and recovery resends same request" {
  let fixture = work_continuation_fixture()
  fixture.admit.val = false
  fixture.lose_response.val = true
  let first = fixture.submit()
  assert_eq(first.0, 503)
  assert_eq(json_string(first.1, "admission", default=""), "unconfirmed")
  assert_eq(json_string(first.1, "continuation_id", default=""), "K")
  let recovered = mooncode_work_with_continuations(
    mooncode_continuation_request_target(fixture.request),
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(recovered, "continuation"),
      "admission",
      default="",
    ),
    "unconfirmed",
  )
  let exact = fixture.posts[0]
  fixture.admit.val = true
  fixture.lose_response.val = false
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 200)
  assert_eq(fixture.posts.length(), 2)
  assert_eq(fixture.posts[1], exact)
}

///|
async test "bound continuation unavailable runtime retains snapshot while changed old context blocks first capture" {
  let fixture = work_continuation_fixture()
  let first = fixture.submit(ready=false)
  assert_eq(json_string(first.1, "admission", default=""), "not_sent")
  assert_eq(fixture.posts.length(), 0)
  fixture.unavailable.val = true
  let failed_read = fixture.submit(request=fixture.resume_request())
  assert_eq(json_string(failed_read.1, "continuation_id", default=""), "K")
  assert_eq(json_string(failed_read.1, "admission", default=""), "unconfirmed")
  fixture.unavailable.val = false
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 200)
  let changed = work_continuation_fixture()
  assert_true(
    @fsx.write_confined_text(
      changed.workspace.root_path,
      changed.context_path,
      "wrong bytes",
    ),
  )
  assert_eq(changed.submit().0, 409)
  assert_eq(changed.posts.length(), 0)
  assert_false(
    @fs.exists(
      @pathx.join(
        changed.workspace.root_path,
        mooncode_continuation_path("K", "submission.json"),
      ),
    ),
  )
}

///|
async test "bound continuation persisted input can be restored only when missing and rejects corruption" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit(ready=false).0, 503)
  let input = @pathx.join(
    fixture.workspace.root_path,
    mooncode_continuation_path("K", "input.md"),
  )
  let original = @fs.read_file(input).text()
  @fs.remove(input)
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 200)
  assert_eq(@fs.read_file(input).text(), original)
  @fs.write_file(input, "corrupt", create_mode=TruncateExisting)
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 409)
  assert_eq(@fs.read_file(input).text(), "corrupt")
  assert_eq(fixture.posts.length(), 1)
}

///|
async test "bound continuation unrelated C2 cannot become prior result and C1 picker preserves C0" {
  let fixture = work_continuation_fixture()
  let original = json_array_items(fixture.claims.val, "delivered_commands")[0]
  let unrelated = original
    |> mooncode_session_with_field("command_id", ToJson::to_json("C2"))
    |> mooncode_session_with_field(
      "command",
      json_object_field_or_empty(original, "command")
      |> mooncode_session_with_field("packet", { "command_id": "C2" }),
    )
    |> mooncode_session_with_field("receipt", {
      "session_id": "S",
      "command_id": "C2",
      "status": "runtime-completed",
    })
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field(
      "delivered_commands",
      ToJson::to_json([original, unrelated]),
    )
  let bad = fixture.request
    |> mooncode_session_with_field(
      "prior_result_command_id",
      ToJson::to_json("C2"),
    )
  assert_eq(fixture.submit(request=bad).0, 409)
  assert_eq(fixture.posts.length(), 0)
  let first = fixture.submit()
  assert_eq(first.0, 200)
  let second = fixture.request
    |> mooncode_session_with_field("continuation_id", ToJson::to_json("K2"))
    |> mooncode_session_with_field("client_turn_id", ToJson::to_json("U2"))
    |> mooncode_session_with_field(
      "prior_result_command_id",
      json_object_field(first.1, "command_id").unwrap(),
    )
  assert_eq(fixture.submit(request=second).0, 200)
  assert_eq(fixture.posts.length(), 2)
  assert_eq(
    json_array_items(fixture.claims.val, "delivered_commands")[0],
    original,
  )
}

///|
async test "bound continuation recovery is read only and pending steering remains separate" {
  let fixture = work_continuation_fixture()
  let target = mooncode_continuation_request_target(fixture.request)
  let absent = mooncode_work_with_continuations(
    target,
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(json_string(absent, "continuation_state", default=""), "not_found")
  assert_false(
    @fs.exists(
      @pathx.join(fixture.workspace.root_path, mooncode_continuation_base()),
    ),
  )
  assert_eq(json_array_items(absent, "pending_guidance").length(), 1)
  assert_eq(fixture.submit().0, 200)
  let recovered = mooncode_work_with_continuations(
    target,
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(json_string(recovered, "continuation_state", default=""), "ready")
  assert_eq(json_array_items(recovered, "continuations").length(), 1)
  assert_eq(
    json_string(
      json_object_field_or_empty(recovered, "continuation"),
      "instruction",
      default="",
    ),
    json_string(fixture.request, "instruction", default=""),
  )
  assert_eq(fixture.posts.length(), 1)
  fixture.events.val = fixture.events.val
    |> mooncode_session_with_field(
      "events",
      ToJson::to_json([
        {
          "session_id": "S",
          "command_id": "steer-1",
          "kind": "steer_deferred",
          "steering_text": "Pending human steering",
        },
        { "session_id": "S", "command_id": "steer-1", "kind": "steer_applied" },
      ]),
    )
  assert_eq(
    mooncode_continuation_pending_guidance(
      target,
      fixture.claims.val,
      fixture.events.val,
    ).length(),
    0,
  )
}

///|
async test "bound continuation missing input projection permits exact repair and rejects symlink substitution" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit(ready=false).0, 503)
  let target = mooncode_continuation_request_target(fixture.request)
  let input = @pathx.join(
    fixture.workspace.root_path,
    mooncode_continuation_path("K", "input.md"),
  )
  let exact = @fs.read_file(input).text()
  @fs.remove(input)
  let projection = mooncode_work_with_continuations(
    target,
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(json_string(projection, "continuation_state", default=""), "ready")
  assert_eq(
    json_string(
      json_object_field_or_empty(projection, "continuation"),
      "input_status",
      default="",
    ),
    "missing",
  )
  assert_false(@fs.exists(input))
  let outside = @fs.tmpdir(prefix="desk-continuation-outside-") + "/input.md"
  @fs.write_file(outside, exact, create_mode=CreateNew)
  @fs.symlink(target=outside, input)
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 409)
  assert_eq(fixture.posts.length(), 0)
  assert_eq(@fs.read_file(outside).text(), exact)
}

///|
async test "bound continuation digest-consistent injected executable state cannot be resumed" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit(ready=false).0, 503)
  let path = @pathx.join(
    fixture.workspace.root_path,
    mooncode_continuation_path("K", "submission.json"),
  )
  let snapshot = @json.parse(@fs.read_file(path).text())
  let body = @json.parse(json_string(snapshot, "request_body", default=""))
    |> mooncode_session_with_field(
      "unexpected_execution_option",
      ToJson::to_json(true),
    )
  let changed = snapshot
    |> mooncode_session_with_field(
      "request_body",
      ToJson::to_json(body.stringify()),
    )
    |> mooncode_session_with_field(
      "request_sha256",
      ToJson::to_json(mooncode_continuation_hash(body.stringify())),
    )
  @fs.write_file(path, changed.stringify(), create_mode=TruncateExisting)
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 409)
  assert_eq(fixture.posts.length(), 0)
}

///|
test "bound continuation UTF8 and full JSON byte bounds do not silently truncate" {
  let unicode = "书".repeat(1398101) + "x"
  assert_eq(@encoding/utf8.encode(unicode).length(), 4 * 1024 * 1024)
  assert_true(
    mooncode_continuation_limits({ "input_text": unicode, "request_body": "{}" })
    is Ok(_),
  )
  assert_true(
    mooncode_continuation_limits({
      "input_text": unicode + "x",
      "request_body": "{}",
    })
    is Err(_),
  )
  // JSON escaping can make a valid input exceed the complete snapshot bound.
  let escaped = "\n".repeat(4 * 1024 * 1024)
  assert_true(
    mooncode_continuation_limits({ "input_text": escaped, "request_body": "{}" })
    is Err(_),
  )
  assert_true(
    mooncode_continuation_limits({
      "input_text": "",
      "request_body": "x".repeat(1024 * 1024 + 1),
    })
    is Err(_),
  )
  assert_false(mooncode_continuation_native_id("U with spaces"))
  assert_false(mooncode_continuation_native_id("x".repeat(129)))
  assert_true(mooncode_continuation_native_id("desk:follow-up_123.abc"))
}

///|
async test "bound continuation complete captured context and prior result together enforce input bound before admission" {
  let fixture = work_continuation_fixture()
  let context_text = "书".repeat(1000000)
  let context : Json = {
    "state": "ready",
    "actual_sha256": mooncode_continuation_hash(context_text),
    "text": context_text,
  }
  let original = json_array_items(fixture.claims.val, "delivered_commands")[0]
  let prepared = mooncode_continuation_prepare(
    fixture.request,
    fixture.workspace,
    original,
    original,
    context,
    fixture.events.val,
    "fixed-time",
  )
  assert_true(prepared is Ok(_))
  let prior = original
    |> mooncode_session_with_field("receipt", {
      "id": "large-prior-result",
      "session_id": "S",
      "command_id": "C0",
      "status": "runtime-completed",
      "execution": {
        "tool_results": [
          {
            "tool": "finish",
            "accepted": true,
            "result": { "output": "x".repeat(2 * 1024 * 1024) },
          },
        ],
      },
    })
  assert_true(
    mooncode_continuation_prepare(
      fixture.request,
      fixture.workspace,
      original,
      prior,
      context,
      fixture.events.val,
      "fixed-time",
    )
    is Err(_),
  )
  assert_eq(fixture.posts.length(), 0)
}

///|
async test "bound continuation publishes an opt-in Desk producer fixture for Proj import validation" {
  let output = @env.get_env_var("MOONPROJ_CONTINUATION_FIXTURE_OUTPUT").unwrap_or(
    "",
  )
  if output.is_empty() {
    return
  }
  let root = output + "/book"
  if !@fs.exists(root) {
    @fs.mkdir(root, recursive=true)
  }
  let fixture = work_continuation_fixture(root~)
  let first = fixture.submit()
  assert_eq(first.0, 200)
  let accepted = json_array_items(fixture.claims.val, "claimed_commands")[0]
  let command_id = json_string(accepted, "command_id", default="")
  let completed = accepted
    |> mooncode_session_with_field("claim_status", ToJson::to_json("delivered"))
    |> mooncode_session_with_field("receipt", {
      "id": "fixture-receipt-C1",
      "session_id": "S",
      "command_id": command_id,
      "status": "runtime-completed",
      "claim_id": "fixture-claim-C1",
      "journal_sequence": "4",
      "execution": {
        "tool_results": [
          {
            "tool": "finish",
            "accepted": true,
            "result": {
              "metadata": { "answer": "Injected Desk producer fixture result" },
            },
          },
        ],
      },
    })
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field("claimed_commands", Json::array([]))
    |> mooncode_session_with_field(
      "delivered_commands",
      ToJson::to_json([
        json_array_items(fixture.claims.val, "delivered_commands")[0],
        completed,
      ]),
    )
  fixture.events.val = fixture.events.val
    |> mooncode_session_with_field(
      "events",
      Json::array([
        {
          "id": "fixture-event-C1",
          "session_id": "S",
          "command_id": command_id,
          "kind": "tool_result",
          "event": "tool_result",
          "tool": "write",
          "path": "fixture-result.md",
          "tool_result": { "ok": true },
        },
      ]),
    )
  let files : Array[(String, Json)] = [
    ("claims.json", fixture.claims.val),
    ("events.json", fixture.events.val),
    ("service.json", { "session_id": "S", "book_root": root, "status": "done" }),
    ("submit-request.json", fixture.request),
    ("accepted-command.json", @json.parse(fixture.posts[0])),
    (
      "continuation-response.json",
      fixture.submit(request=fixture.resume_request()).1,
    ),
    (
      "fixture.json",
      {
        "kind": "injected-native-io-fixture",
        "task_id": "T",
        "run_id": "R",
        "session_id": "S",
        "original_command_id": "C0",
        "command_id": command_id,
        "continuation_id": "K",
        "client_turn_id": "U",
        "book_root": root,
        "submission_path": mooncode_continuation_path("K", "submission.json"),
        "provider_called": false,
      },
    ),
  ]
  for (name, content) in files {
    @fs.write_file(
      output + "/" + name,
      content.stringify(),
      create_mode=CreateNew,
    )
  }
}

///|
async test "bound continuation native accepted identity with missing capture never advertises safe discard" {
  let fixture = work_continuation_fixture()
  let submitted = fixture.submit()
  assert_eq(submitted.0, 200)
  @fs.remove(
    @pathx.join(
      fixture.workspace.root_path,
      mooncode_continuation_path("K", "submission.json"),
    ),
  )
  let target = mooncode_continuation_request_target(fixture.request)
  let recovered = mooncode_work_with_continuations(
    target,
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(
    json_string(recovered, "continuation_state", default=""),
    "conflict",
  )
  let known = json_object_field_or_empty(recovered, "continuation")
  assert_eq(
    json_string(known, "command_id", default=""),
    json_string(submitted.1, "command_id", default=""),
  )
  assert_eq(json_string(known, "admission", default=""), "accepted")
  assert_eq(
    fixture.submit(
      request=fixture.request
        |> mooncode_session_with_field(
          "client_turn_id",
          ToJson::to_json("replacement-U"),
        ),
    ).0,
    409,
  )
  assert_eq(fixture.posts.length(), 1)
  // Even if native readback temporarily loses that row, dispatch possibility
  // survives locally and cannot be mistaken for never-sent work.
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field("claimed_commands", Json::array([]))
  let unavailable = mooncode_work_with_continuations(
    target,
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(
    json_string(unavailable, "continuation_state", default=""),
    "conflict",
  )
}

///|
test "bound continuation exact checkpoint and service state are not borrowed from C2" {
  let item : Json = {
    "command_id": "C1",
    "session_id": "S",
    "claim_status": "claimed",
    "receipt": {
      "command_id": "C1",
      "session_id": "S",
      "status": "runtime-claimed",
    },
  }
  let checkpoint : Json = {
    "session_id": "S",
    "command_id": "C1",
    "kind": "runtime.turn_checkpointed",
    "state": "awaiting-approval",
    "approval_id": "A1",
  }
  let unrelated : Json = {
    "session_id": "S",
    "command_id": "C2",
    "kind": "runtime.turn_checkpointed",
    "state": "planner-quantum-paused",
  }
  let events : Json = {
    "events": [checkpoint, unrelated],
    "runtime_service": { "status": "running" },
  }
  assert_eq(
    json_string(mooncode_continuation_result(item, events), "state", default=""),
    "waiting_approval",
  )
  let approved = events
    |> mooncode_session_with_field(
      "events",
      Json::array([
        checkpoint,
        {
          "session_id": "S",
          "command_id": "C1",
          "kind": "tool.approval_approved",
          "approval_id": "A1",
        },
        unrelated,
      ]),
    )
  assert_eq(
    json_string(
      mooncode_continuation_result(item, approved),
      "state",
      default="",
    ),
    "running",
  )
  let paused = events
    |> mooncode_session_with_field(
      "events",
      Json::array([
        checkpoint
        |> mooncode_session_with_field(
          "state",
          ToJson::to_json("planner-replan-paused"),
        ),
      ]),
    )
  assert_eq(
    json_string(mooncode_continuation_result(item, paused), "state", default=""),
    "interrupted",
  )
  let stopped : Json = {
    "events": [],
    "runtime_service": { "status": "stopped" },
  }
  assert_eq(
    json_string(
      mooncode_continuation_result(item, stopped),
      "state",
      default="",
    ),
    "interrupted",
  )
  assert_eq(
    json_string(
      mooncode_continuation_result(item, { "events": [] }),
      "state",
      default="",
    ),
    "unknown",
  )
}

///|
async test "bound continuation missing capture never relabels another original command lineage" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit().0, 200)
  @fs.remove(
    @pathx.join(
      fixture.workspace.root_path,
      mooncode_continuation_path("K", "submission.json"),
    ),
  )
  let item = json_array_items(fixture.claims.val, "claimed_commands")[0]
  let command = json_object_field_or_empty(item, "command")
  let payload = json_object_field_or_empty(command, "payload")
  let lineage = json_object_field_or_empty(payload, "moonproj_continuation")
    |> mooncode_session_with_field(
      "original_command_id",
      ToJson::to_json("other-C0"),
    )
  let changed = item
    |> mooncode_session_with_field(
      "command",
      command
      |> mooncode_session_with_field(
        "payload",
        payload |> mooncode_session_with_field("moonproj_continuation", lineage),
      ),
    )
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field("claimed_commands", Json::array([changed]))
  let recovered = mooncode_work_with_continuations(
    mooncode_continuation_request_target(fixture.request),
    fixture.workspace,
    { "state": "ready" },
    fixture.claims.val,
    "K",
    path => fixture.read(path),
  )
  assert_eq(
    json_string(recovered, "continuation_state", default=""),
    "conflict",
  )
  assert_eq(json_object_field(recovered, "continuation"), Some(Json::null()))
}

///|
async test "bound continuation resume rejects client identity reused by ordinary chat after capture" {
  let fixture = work_continuation_fixture()
  assert_eq(fixture.submit(ready=false).0, 503)
  let original = json_array_items(fixture.claims.val, "delivered_commands")[0]
  let other : Json = {
    "command_id": "ordinary-C2",
    "session_id": "S",
    "action": "prompt",
    "claim_status": "claimable",
    "command": {
      "packet": { "command_id": "ordinary-C2", "client_turn_id": "U" },
    },
  }
  fixture.claims.val = fixture.claims.val
    |> mooncode_session_with_field("claimable_commands", Json::array([other]))
    |> mooncode_session_with_field(
      "delivered_commands",
      Json::array([original]),
    )
  assert_eq(fixture.submit(request=fixture.resume_request()).0, 409)
  assert_eq(fixture.posts.length(), 0)
}
