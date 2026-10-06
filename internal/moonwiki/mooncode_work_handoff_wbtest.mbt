///|
fn work_handoff_test_target() -> MoonCodeWorkTarget {
  {
    session_id: "S",
    command_id: "C0",
    book_root: "/suite/books/书 with spaces/",
  }
}

///|
fn work_handoff_test_workspace() -> @desk.DeskWorkspace {
  @desk.workspace(
    id="actual-desk-id",
    name="Captured book",
    root_path="/suite/books/书 with spaces",
    kind=MoonBook,
  )
}

///|
fn work_handoff_test_item(id : String, status? : String = "delivered") -> Json {
  {
    "command_id": id,
    "session_id": "S",
    "action": "prompt",
    "claim_status": status,
    "command": {
      "protocol": "mooncode.v1",
      "command": "prompt",
      "session_id": "S",
      "book_root": "/suite/books/书 with spaces",
      "packet": { "command_id": id },
      "model": "moongate/" + id,
      "context_path": "captured/" + id + ".md",
      "text": "Private original requirements",
      "payload": { "private": "not projected" },
    },
    "receipt": if status == "delivered" {
      { "session_id": "S", "command_id": id, "status": "runtime-completed" }
    } else {
      Json::null()
    },
  }
}

///|
fn work_handoff_test_claims() -> Json {
  {
    "kind": "mooncode-runtime-claim-state",
    "protocol": "mooncode.v1",
    "session_id": "S",
    "book_root": "/suite/books/书 with spaces/",
    "claimable_commands": [],
    "claimed_commands": [],
    "order_blocked_commands": [],
    "invalid_commands": [],
    "delivered_commands": [
      work_handoff_test_item("C0"),
      work_handoff_test_item("C1"),
    ],
  }
}

///|
fn work_handoff_test_listing() -> Json {
  {
    "protocol": "mooncode.v1",
    "sessions": [
      { "id": "unrelated-first", "book_root": "/suite/other", "status": "live" },
      {
        "id": "S",
        "book_root": "/suite/books/书 with spaces/",
        "status": "durable",
        "model": "later/session/model",
      },
    ],
  }
}

///|
test "work handoff takes C0 raw captured body rather than later C1 or session defaults" {
  let (status, response) = mooncode_work_command_projection(
    work_handoff_test_target(),
    work_handoff_test_workspace(),
    work_handoff_test_claims(),
  )
  assert_eq(status, 200)
  assert_eq(json_string(response, "state", default=""), "ready")
  let original = json_object_field_or_empty(response, "original_command")
  assert_eq(json_string(original, "command_id", default=""), "C0")
  assert_eq(json_string(original, "model", default=""), "moongate/C0")
  assert_eq(json_string(original, "context_path", default=""), "captured/C0.md")
  assert_eq(
    json_string(original, "receipt_status", default=""),
    "runtime-completed",
  )
  assert_false(response.stringify().contains("Private"))
  assert_false(response.stringify().contains("C1"))
}

///|
test "work handoff inspects every canonical claim bucket with absent receipt and context" {
  for
    (key, status) in [
      ("claimable_commands", "claimable"),
      ("claimed_commands", "claimed"),
      ("order_blocked_commands", "order-blocked"),
      ("invalid_commands", "invalid"),
      ("delivered_commands", "delivered"),
    ] {
    let claims = work_handoff_test_claims()
    guard claims is Object(fields) else { fail("claims") }
    fields["delivered_commands"] = Json::array([])
    let item = work_handoff_test_item("C0", status~)
    guard json_object_field(item, "command") is Some(Object(command)) else {
      fail("command")
    }
    command.remove("context_path")
    command.remove("model")
    fields[key] = Json::array([item])
    let (code, response) = mooncode_work_command_projection(
      work_handoff_test_target(),
      work_handoff_test_workspace(),
      claims,
    )
    assert_eq(code, 200, msg=key)
    let original = json_object_field_or_empty(response, "original_command")
    assert_eq(json_string(original, "claim_status", default=""), status)
    assert_eq(json_string(original, "context_path", default="unexpected"), "")
    assert_eq(json_string(original, "model", default="unexpected"), "")
    if status != "delivered" {
      assert_eq(
        json_string(original, "receipt_status", default="unexpected"),
        "",
      )
    }
  }
}

///|
test "work handoff rejects unknown and duplicate root identities without first-row fallback" {
  let target = work_handoff_test_target()
  let unrelated = @desk.workspace(
    id="first",
    name="Wrong",
    root_path="/other",
    kind=MoonBook,
  )
  guard mooncode_work_workspace(target, [
      unrelated,
      work_handoff_test_workspace(),
    ])
    is Ok(exact) else {
    fail("exact root")
  }
  assert_eq(exact.id, "actual-desk-id")
  guard mooncode_work_workspace(target, [unrelated]) is Err((code, missing)) else {
    fail("unknown root")
  }
  assert_eq(code, 409)
  assert_eq(json_string(missing, "state", default=""), "unknown_workspace")
  assert_eq(json_string(missing, "book_root", default=""), target.book_root)
  guard mooncode_work_workspace(target, [
      work_handoff_test_workspace(),
      work_handoff_test_workspace(),
    ])
    is Err((_, duplicate)) else {
    fail("ambiguous root")
  }
  assert_eq(json_string(duplicate, "state", default=""), "ambiguous_workspace")
}

///|
test "work handoff rejects mismatched runtime envelope body and receipt identity" {
  for field in ["session_id", "book_root"] {
    let claims = work_handoff_test_claims()
    guard claims is Object(fields) else { fail("claims") }
    fields[field] = "wrong".to_json()
    let (code, result) = mooncode_work_command_projection(
      work_handoff_test_target(),
      work_handoff_test_workspace(),
      claims,
    )
    assert_eq(code, 409)
    assert_eq(json_string(result, "state", default=""), "identity_mismatch")
  }
  for location in ["command", "receipt"] {
    let claims = work_handoff_test_claims()
    let item = json_array_items(claims, "delivered_commands")[0]
    guard json_object_field(item, location) is Some(Object(fields)) else {
      fail("nested")
    }
    fields["session_id"] = "different-session".to_json()
    assert_eq(
      mooncode_work_command_projection(
        work_handoff_test_target(),
        work_handoff_test_workspace(),
        claims,
      ).0,
      409,
    )
  }
}

///|
test "work handoff distinguishes a missing command from partial native data" {
  let claims = work_handoff_test_claims()
  guard claims is Object(fields) else { fail("claims") }
  fields["delivered_commands"] = Json::array([work_handoff_test_item("C1")])
  let (missing_code, missing) = mooncode_work_command_projection(
    work_handoff_test_target(),
    work_handoff_test_workspace(),
    claims,
  )
  assert_eq(missing_code, 404)
  assert_eq(json_string(missing, "state", default=""), "command_not_found")
  fields.remove("claimed_commands")
  let (partial_code, partial) = mooncode_work_command_projection(
    work_handoff_test_target(),
    work_handoff_test_workspace(),
    claims,
  )
  assert_eq(partial_code, 503)
  assert_eq(
    json_string(partial, "state", default=""),
    "invalid_native_response",
  )
}

///|
async test "work handoff compiled boundary reads exact encoded listing and C0 claim only" {
  let calls : Array[String] = []
  let (status, result) = mooncode_resolve_work_handoff(
    "/suite",
    [work_handoff_test_workspace()],
    work_handoff_test_target(),
    path => {
      calls.push(path)
      if path ==
        "/v1/code/sessions?book_root=%2Fsuite&format=listing&include_books=true" {
        Ok(work_handoff_test_listing())
      } else if path ==
        "/v1/code/sessions/S/runtime-claim?book_root=%2Fsuite%2Fbooks%2F%E4%B9%A6%20with%20spaces" {
        Ok(work_handoff_test_claims())
      } else {
        Err("Unexpected read: " + path)
      }
    },
  )
  assert_eq(status, 200)
  assert_eq(calls.length(), 2)
  assert_eq(
    json_string(
      json_object_field_or_empty(result, "workspace"),
      "id",
      default="",
    ),
    "actual-desk-id",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(result, "original_command"),
      "model",
      default="",
    ),
    "moongate/C0",
  )
}

///|
async test "work handoff compiled boundary keeps runtime failures distinct from absence" {
  for fail_at in [0, 1] {
    let count = Ref(0)
    let (status, result) = mooncode_resolve_work_handoff(
      "/suite",
      [work_handoff_test_workspace()],
      work_handoff_test_target(),
      _ => {
        let index = count.val
        count.val += 1
        if index == fail_at {
          Err("Native runtime unavailable")
        } else {
          Ok(work_handoff_test_listing())
        }
      },
    )
    assert_eq(status, 503)
    assert_eq(json_string(result, "state", default=""), "runtime_unavailable")
    assert_eq(json_string(result, "original_command_id", default=""), "C0")
  }
}

///|
async test "work handoff compiled boundary resolves archived and missing sessions without restoring" {
  for archived in [true, false] {
    let calls : Array[String] = []
    let (status, result) = mooncode_resolve_work_handoff(
      "/suite",
      [work_handoff_test_workspace()],
      work_handoff_test_target(),
      path => {
        calls.push(path)
        if path.contains("scope=archived") && archived {
          Ok(work_handoff_test_listing())
        } else {
          Ok({ "sessions": [] })
        }
      },
    )
    assert_eq(status, if archived { 409 } else { 404 })
    assert_eq(
      json_string(result, "state", default=""),
      if archived {
        "session_archived"
      } else {
        "session_not_found"
      },
    )
    assert_eq(calls.length(), 2)
    assert_true(calls[1].contains("scope=archived"))
  }
}

///|
async test "work handoff compiled boundary rejects mismatched or ambiguous session scope" {
  let other = @desk.workspace(
    id="other",
    name="Other",
    root_path="/other",
    kind=MoonBook,
  )
  for ambiguous in [true, false] {
    let calls = Ref(0)
    let rows : Array[Json] = [{ "id": "S", "book_root": "/other" }]
    if ambiguous {
      rows.push({
        "id": "S",
        "book_root": work_handoff_test_workspace().root_path,
      })
    }
    let (status, result) = mooncode_resolve_work_handoff(
      "/suite",
      [work_handoff_test_workspace(), other],
      work_handoff_test_target(),
      _ => {
        calls.val += 1
        Ok({ "sessions": rows })
      },
    )
    assert_eq(status, 409)
    assert_eq(
      json_string(result, "state", default=""),
      if ambiguous {
        "ambiguous_session"
      } else {
        "workspace_mismatch"
      },
    )
    assert_eq(calls.val, 1)
  }
}

///|
test "work handoff has a GET-only route while ordinary chat commands remain POST" {
  let route = @mooncode.desktop_work_handoff_endpoint()
  assert_true(mooncode_route_accepts_read(route, Get))
  assert_true(mooncode_route_accepts_read(route, Head))
  assert_false(mooncode_route_accepts_post(route, Post))
  assert_true(
    mooncode_route_accepts_post(
      @mooncode.desktop_session_commands_endpoint(),
      Post,
    ),
  )
}

///|
async test "work handoff performs no native read for unavailable workspace and keeps hints" {
  let calls = Ref(0)
  let (status, result) = mooncode_resolve_work_handoff(
    "/suite",
    [],
    work_handoff_test_target(),
    _ => {
      calls.val += 1
      Err("unexpected read")
    },
  )
  assert_eq(calls.val, 0)
  assert_eq(status, 409)
  assert_eq(json_string(result, "state", default=""), "unknown_workspace")
  assert_eq(json_string(result, "session_id", default=""), "S")
  assert_eq(
    json_string(result, "book_root", default=""),
    work_handoff_test_target().book_root,
  )
}

///|
test "work handoff query preserves encoded spaces Unicode and command identity" {
  let path = "/api/mooncode/work-handoff?session_id=S&command_id=C0&book_root=%2Fsuite%2Fbooks%2F%E4%B9%A6%20with%20spaces%2F"
  let target = mooncode_work_target_from_query(path)
  assert_eq(target.session_id, "S")
  assert_eq(target.command_id, "C0")
  assert_eq(target.book_root, "/suite/books/书 with spaces/")
  let plus = mooncode_work_target_from_query(
    "/api/mooncode/work-handoff?session_id=S%2B1&command_id=C%2F0&book_root=%2Fbooks%2Fwith+spaces%2Band%2Bliteral",
  )
  assert_eq(plus.session_id, "S+1")
  assert_eq(plus.command_id, "C/0")
  assert_eq(plus.book_root, "/books/with spaces+and+literal")
  assert_eq(mooncode_work_normalized_root("/"), "/")
}
