///|
fn native_work_fixture_id() -> String {
  "town-work-0123456789abcdef0123456789abcdef"
}

///|
fn native_work_fixture_contract() -> Json {
  let endpoints : Array[Json] = []
  for
    (method_, path) in [
      ("GET", "/api/native-work"),
      ("GET", "/api/native-work/{id}"),
      ("POST", "/api/native-work/{id}/refresh"),
      ("POST", "/api/native-work/{id}/cancel"),
      ("POST", "/api/native-work/{id}/sync"),
    ] {
    endpoints.push({ "method": method_, "path": path })
  }
  {
    "schema": "moontown.api.v1",
    "nativeWorkStatusSchema": town_native_work_schema(),
    "endpoints": endpoints.to_json(),
  }
}

///|
fn native_work_fixture_item() -> Json {
  {
    "id": native_work_fixture_id(),
    "kind": "book",
    "book_id": "book-a",
    "criterion_id": "criterion-a",
    "state": "blocked",
    "control_state": "cancel_unknown",
    "blocked_reason": "ordinary_diagnostic",
    "blocker_help": "Inspect saved status before retrying",
    "session_id": "session-a",
    "command_id": "command-a",
    "engineering_status": "verified",
    "output": "Ordinary result\nNo rewriting: token, config, prompt are words too.\n",
    "generation": 2,
    "observed_at_ms": 1790986000123UL.to_json(),
    "retry_after_ms": 1790986060123UL.to_json(),
    "prompt": "PRIVATE-PROMPT",
    "raw_request": { "body": "PRIVATE-REQUEST" },
    "credential": "PRIVATE-CREDENTIAL",
    "config_path": "/PRIVATE/CONFIG",
    "baseline": "PRIVATE-BASELINE",
  }
}

///|
fn native_work_fixture_list() -> Json {
  {
    "schema": town_native_work_schema(),
    "revision": 7,
    "items": [native_work_fixture_item()],
    "owner_root": "/PRIVATE/ROOT",
    "receipt": "PRIVATE-RECEIPT",
  }
}

///|
test "native work exact route identity and method policy" {
  let id = native_work_fixture_id()
  assert_true(town_native_work_id_valid(id))
  assert_true(town_native_work_route("/api/town/native-work") is Ok(SavedList))
  assert_true(
    town_native_work_route("/api/town/native-work/" + id)
    is Ok(SavedDetail(actual)) &&
    actual == id,
  )
  for action in ["refresh", "cancel", "sync"] {
    assert_true(
      town_native_work_route("/api/town/native-work/" + id + "/" + action)
      is Ok(Mutation(actual_id, actual_action)) &&
      actual_id == id &&
      actual_action == action,
    )
    assert_eq(town_native_work_allowed_methods(Mutation(id, action)), ["POST"])
  }
  assert_eq(town_native_work_allowed_methods(SavedList), ["GET"])
  assert_eq(town_native_work_allowed_methods(SavedDetail(id)), ["GET"])
  for
    invalid in [
      "",
      "town-work-a",
      id + "0",
      "town-work-0123456789ABCDEF0123456789abcdef",
      id + "/",
      "%74own-work-0123456789abcdef0123456789abcdef",
      "..",
    ] {
    assert_false(town_native_work_id_valid(invalid))
  }
  for
    path in [
      "/api/town/native-work/",
      "/api/town//native-work/" + id,
      "/api/town/native-work//" + id,
      "/api/town/native-work/" + id + "/pause",
      "/api/town/native-work/" + id + "/cancel/",
      "/api/town/native-work/" + id + "%2Fcancel",
    ] {
    assert_true(town_native_work_route(path) is Err(_))
  }
}

///|
test "native work body is bounded and only carries exact revision" {
  assert_eq(
    town_native_work_revision_body(b"{\"expected_revision\":0}"),
    Ok({ "expected_revision": 0 }),
  )
  for
    raw in [
      "", "{}", "[]", "null", "{\"expected_revision\":-1}", "{\"expected_revision\":1.5}",
      "{\"expected_revision\":2147483648}", "{\"expected_revision\":\"7\"}", "{\"expected_revision\":true}",
      "{\"expected_revision\":7,\"root\":\"/tmp\"}", "{\"expected_revision\":7,\"session_id\":\"other\"}",
      "{\"expected_revision\":7,\"expected_revision\":8}",
    ] {
    assert_true(
      town_native_work_revision_body(@encoding/utf8.encode(raw))
      is Err((400, _)),
    )
  }
  assert_true(town_native_work_revision_body(b"\xff") is Err((400, _)))
  let valid = "{\"expected_revision\":7}"
  let boundary = valid + String::make(4096 - valid.length(), ' ')
  assert_true(
    town_native_work_revision_body(@encoding/utf8.encode(boundary)) is Ok(_),
  )
  assert_true(
    town_native_work_revision_body(@encoding/utf8.encode(boundary + " "))
    is Err((413, _)),
  )
}

///|
test "native work capability remains specific to complete owner surface" {
  assert_true(town_native_work_capability(native_work_fixture_contract()))
  assert_false(town_native_work_capability({ "schema": "moontown.api.v1" }))
  assert_false(
    town_native_work_capability(
      @mooncore.session_with_field(
        native_work_fixture_contract(),
        "nativeWorkStatusSchema",
        "wrong".to_json(),
      ),
    ),
  )
  assert_false(
    town_native_work_capability(
      @mooncore.session_with_field(
        native_work_fixture_contract(),
        "endpoints",
        Json::array([]),
      ),
    ),
  )
}

///|
test "native work typed projection excludes private owner fields without rewriting output" {
  let projected = town_native_work_project(
    native_work_fixture_list(),
    SavedList,
  ).unwrap()
  let text = projected.stringify()
  assert_false(text.contains("PRIVATE"))
  guard projected is { "items": Array([item]), "revision": Number(7, ..), .. } else {
    fail("missing saved projection")
  }
  assert_eq(
    json_string(item, "output", default=""),
    json_string(native_work_fixture_item(), "output", default=""),
  )
  assert_eq(
    json_string(item, "blocker_help", default=""),
    "Inspect saved status before retrying",
  )
  assert_eq(json_string(item, "control_state", default=""), "cancel_unknown")
  guard item is Object(fields) else { fail("not an item") }
  assert_eq(fields.length(), 15)
  let detail : Json = {
    "schema": town_native_work_schema(),
    "revision": 7,
    "item": native_work_fixture_item(),
    "prompt": "PRIVATE-PROMPT",
  }
  assert_false(
    town_native_work_project(detail, SavedDetail(native_work_fixture_id()))
    .unwrap()
    .stringify()
    .contains("PRIVATE"),
  )
  assert_true(
    town_native_work_project(
      detail,
      SavedDetail("town-work-ffffffffffffffffffffffffffffffff"),
    )
    is Err((503, _)),
  )
}

///|
test "native work rejects malformed and incoherent owner projections" {
  for
    payload in [
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "schema",
        "wrong".to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "revision",
        (-1).to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "revision",
        "7".to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "revision",
        7.5.to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "items",
        [native_work_fixture_item(), native_work_fixture_item()].to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "items",
        [
          @mooncore.session_with_field(
            native_work_fixture_item(),
            "observed_at_ms",
            (-1).to_json(),
          ),
        ].to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "items",
        [
          @mooncore.session_with_field(
            native_work_fixture_item(),
            "generation",
            "2".to_json(),
          ),
        ].to_json(),
      ),
      @mooncore.session_with_field(
        native_work_fixture_list(),
        "items",
        [
          @mooncore.session_with_field(
            native_work_fixture_item(),
            "generation",
            2.5.to_json(),
          ),
        ].to_json(),
      ),
    ] {
    assert_true(town_native_work_project(payload, SavedList) is Err((503, _)))
  }
}

///|
async test "native work injected read never dispatches and strips owner data" {
  let calls : Array[String] = []
  let result = town_native_work_request_with(
    "/api/town/native-work",
    Get,
    b"",
    (method_, path, body) => {
      calls.push(method_ + " " + path)
      assert_eq(body, None)
      Ok(
        (
          200,
          if path == "/api/contract" {
            native_work_fixture_contract()
          } else {
            native_work_fixture_list()
          },
        ),
      )
    },
  )
  assert_eq(calls, ["GET /api/contract", "GET /api/native-work"])
  assert_false(result.unwrap().stringify().contains("PRIVATE"))
}

///|
async test "native work injected mutations forward once with exact revision and target" {
  let id = native_work_fixture_id()
  for action in ["refresh", "cancel", "sync"] {
    let calls : Array[String] = []
    let result = town_native_work_request_with(
      "/api/town/native-work/" + id + "/" + action,
      Post,
      b"{\"expected_revision\":7}",
      (method_, path, body) => {
        calls.push(method_ + " " + path)
        if path == "/api/contract" {
          assert_eq(body, None)
          Ok((200, native_work_fixture_contract()))
        } else {
          assert_eq(body, Some({ "expected_revision": 7 }))
          Ok((200, native_work_fixture_list()))
        }
      },
    )
    assert_eq(calls, [
      "GET /api/contract",
      "POST /api/native-work/" + id + "/" + action,
    ])
    assert_false(result.unwrap().stringify().contains("PRIVATE"))
  }
}

///|
async test "native work injected failures preserve status hide private error and never retry" {
  for code in [400, 404, 409, 413, 500, 503] {
    let calls : Array[String] = []
    let result = town_native_work_request_with(
      "/api/town/native-work/" + native_work_fixture_id() + "/cancel",
      Post,
      b"{\"expected_revision\":7}",
      (_, path, _) => {
        calls.push(path)
        Ok(
          (
            if path == "/api/contract" {
              200
            } else {
              code
            },
            if path == "/api/contract" {
              native_work_fixture_contract()
            } else {
              { "error": "PRIVATE-NATIVE-ERROR" }
            },
          ),
        )
      },
    )
    guard result is Err((returned, message)) else { fail("expected failure") }
    assert_eq(returned, if code == 500 { 503 } else { code })
    assert_false(message.contains("PRIVATE"))
    assert_eq(calls.length(), 2)
  }
  let calls : Array[String] = []
  let lost = town_native_work_request_with(
    "/api/town/native-work/" + native_work_fixture_id() + "/sync",
    Post,
    b"{\"expected_revision\":7}",
    (_, path, _) => {
      calls.push(path)
      if path == "/api/contract" {
        Ok((200, native_work_fixture_contract()))
      } else {
        Err("PRIVATE-TRANSPORT")
      }
    },
  )
  assert_true(lost is Err((503, _)))
  assert_eq(calls.length(), 2)
}

///|
async test "native work validation and missing capability cannot contact mutation transport" {
  let calls : Array[String] = []
  let exchange : async (String, String, Json?) -> Result[(Int32, Json), String] = (
    _,
    path,
    _,
  ) => {
    calls.push(path)
    Ok((200, { "schema": "moontown.api.v1" }))
  }
  let invalid : Array[(String, @http.RequestMethod, Bytes, Int32)] = [
    ("/api/town/native-work", Post, b"{}", 405),
    ("/api/town/native-work", Head, b"", 405),
    ("/api/town/native-work/bad/cancel", Post, b"{}", 400),
    (
      "/api/town/native-work/" + native_work_fixture_id() + "/cancel",
      Post,
      b"{\"expected_revision\":7,\"prompt\":\"private\"}",
      400,
    ),
  ]
  for (path, method_, bytes, expected) in invalid {
    guard town_native_work_request_with(path, method_, bytes, exchange)
      is Err((code, _)) else {
      fail("expected rejection")
    }
    assert_eq(code, expected)
  }
  assert_eq(calls.length(), 0)
  assert_true(
    town_native_work_request_with("/api/town/native-work", Get, b"", exchange)
    is Err((503, _)),
  )
  assert_eq(calls, ["/api/contract"])
}

///|
async test "native work bounded reader rejects oversized body without reading all" {
  let valid = "{\"expected_revision\":7}"
  let body = @io.MemoryReader(writer => writer.write(valid))
  defer body.close()
  assert_eq(town_native_work_read_body(body), Ok(@encoding/utf8.encode(valid)))
  let oversized = @io.MemoryReader(writer => {
    writer.write(String::make(9000, 'a'))
  })
  defer oversized.close()
  assert_true(town_native_work_read_body(oversized) is Err((413, _)))
}

///|
test "native work success and error response helpers are never cacheable" {
  let success = native_work_fixture_list()
  assert_eq(
    town_native_work_response_payload(Ok(success)),
    (200, "OK", success),
  )
  assert_eq(
    town_native_work_response_headers().get("Cache-Control"),
    Some("no-store"),
  )
  assert_eq(town_native_work_response_headers().get("Allow"), None)
  for
    (code, reason) in [
      (400, "Bad Request"),
      (404, "Not Found"),
      (405, "Method Not Allowed"),
      (409, "Conflict"),
      (413, "Payload Too Large"),
      (503, "Service Unavailable"),
    ] {
    let (actual, phrase, payload) = town_native_work_response_payload(
      Err((code, "Inspect saved status")),
    )
    assert_eq(actual, code)
    assert_eq(phrase, reason)
    assert_eq(json_string(payload, "error", default=""), "Inspect saved status")
    assert_false(json_bool(payload, "ok", default=true))
    let headers = town_native_work_response_headers(
      allowed=if code == 405 { ["GET"] } else { [] },
    )
    assert_eq(headers.get("Cache-Control"), Some("no-store"))
    if code == 405 {
      assert_eq(headers.get("Allow"), Some("GET"))
    }
  }
}

///|
async test "native work owner deadline cancels stalled operation without retry" {
  let calls = @ref.new(0)
  let completed = @ref.new(false)
  let cleaned = @ref.new(false)
  let result = town_native_work_with_deadline(
    () => {
      calls.val += 1
      defer {
        cleaned.val = true
      }
      @async.sleep(1000)
      completed.val = true
      Ok(native_work_fixture_list())
    },
    timeout_ms=1,
  )
  guard result is Err((503, message)) else { fail("expected deadline failure") }
  assert_true(message.contains("may have taken effect"))
  assert_eq(calls.val, 1)
  assert_false(completed.val)
  assert_true(cleaned.val)
  assert_eq(
    town_native_work_with_deadline(() => Ok(native_work_fixture_list())),
    Ok(native_work_fixture_list()),
  )
}
