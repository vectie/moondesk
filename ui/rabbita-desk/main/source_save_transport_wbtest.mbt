///|
extern "js" fn source_save_http_fixture() -> @js.Value =
  #| () => ({ requests: [] })

///|
extern "js" fn source_save_http_activate(fixture : @js.Value) -> @js.Value =
  #| fixture => {
  #|   const previous = globalThis.fetch;
  #|   globalThis.fetch = (url, options = {}) => new Promise((resolve, reject) => fixture.requests.push({ url, options, resolve, reject }));
  #|   return previous;
  #| }

///|
extern "js" fn source_save_http_restore(previous : @js.Value) =
  #| previous => { globalThis.fetch = previous; }

///|
extern "js" fn source_save_http_requests(fixture : @js.Value) -> String =
  #| fixture => JSON.stringify(fixture.requests.map(r => ({ url: r.url, method: r.options.method, body: r.options.body ? JSON.parse(r.options.body) : null })))

///|
extern "js" fn source_save_http_resolve(
  fixture : @js.Value,
  index : Int32,
  status : Int32,
  payload : String,
) -> @js.Promise =
  #| (fixture, index, status, payload) => {
  #|   fixture.requests[index].resolve({ ok: status >= 200 && status < 300, status, text: () => Promise.resolve(payload) });
  #|   return new Promise(resolve => setTimeout(resolve, 0));
  #| }

///|
extern "js" fn source_save_http_reject(
  fixture : @js.Value,
  index : Int32,
) -> @js.Promise =
  #| (fixture, index) => {
  #|   fixture.requests[index].reject(new Error('connection unavailable'));
  #|   return new Promise(resolve => setTimeout(resolve, 0));
  #| }

///|
fn source_save_test_state(draft~ : String = "human edit") -> SourcePaneState {
  let loading = update_source_pane(
    init_source_pane("book-demo", "session"),
    RequestSource("src/main.mbt"),
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(source_pane_test_preview())),
  )
  update_source_pane(ready, EditDraft(draft))
}

///|
fn source_save_test_send(
  fixture : @js.Value,
  cell : Ref[SourcePaneState],
  action : SourcePaneMsg,
) -> Unit raise {
  let previous = source_save_http_activate(fixture)
  defer source_save_http_restore(previous)
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  let dispatch : Dispatch[Msg] = fn(message) {
    if message is SourcePane(result) {
      cell.val = update_source_pane(cell.val, result)
    }
    @rabbita.none
  }
  cell.val = update_source_pane(cell.val, action)
  assert_true(cell.val.saving)
  @cmd.Scheduler::add(scheduler, save_source_pane_cmd(dispatch, cell.val))
}

///|
fn source_save_test_success(content : String) -> Json {
  {
    "ok": true,
    "workspace_id": "book-demo",
    "path": "src/main.mbt",
    "content": content,
  }
}

///|
test "source save transport rejects host errors and preserves the retry draft" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let failures : Array[(Int32, Json)] = [
      (
        400,
        {
          "code": 400,
          "reason": "Bad Request",
          "error": "Source path is missing or outside the selected workspace",
        },
      ),
      (404, { "ok": false, "status": "error", "error": "Unknown workspace" }),
      (
        415,
        {
          "code": 415,
          "reason": "Unsupported Media Type",
          "error": "Source editor supports UTF-8 text files only",
        },
      ),
      (
        500,
        {
          "code": 500,
          "reason": "Internal Server Error",
          "error": "Could not save source file; the draft is preserved",
        },
      ),
    ]
    for index, failure in failures {
      let (status, payload) = failure
      let cell = Ref(source_save_test_state())
      source_save_test_send(fixture, cell, Save)
      ignore(
        source_save_http_resolve(fixture, index, status, payload.stringify()).wait(),
      )
      assert_eq(cell.val.draft, "human edit")
      assert_eq(cell.val.baseline, "fn main {}")
      assert_true(source_pane_dirty(cell.val))
      assert_false(cell.val.saving)
      assert_eq(
        cell.val.status,
        json_field_string(payload, "error", default=""),
      )
      assert_true(cell.val.server_content is None)
    }
    let retry = Ref(source_save_test_state())
    source_save_test_send(fixture, retry, Save)
    ignore(
      source_save_http_resolve(fixture, 4, 500, failures[3].1.stringify()).wait(),
    )
    source_save_test_send(fixture, retry, Save)
    guard @json.parse(source_save_http_requests(fixture)) is Array(requests) else {
      fail("Expected recorded source requests")
    }
    assert_eq(
      handoff_field(requests[4], "body"),
      handoff_field(requests[5], "body"),
    )
    assert_eq(
      handoff_text(requests[5], "url"),
      @desk.workspace_endpoint_url("book-demo", "source"),
    )
    assert_eq(handoff_text(requests[5], "method"), "POST")
    ignore(
      source_save_http_resolve(
        fixture,
        5,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_eq(retry.val.status, "Saved")
    assert_eq(retry.val.baseline, "human edit")
    assert_false(source_pane_dirty(retry.val))
  })
}

///|
test "source save empty external conflict preserves the edit and supports deliberate replace" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref(source_save_test_state())
    let conflict : Json = {
      "code": 409,
      "reason": "Conflict",
      "error": "File changed after this draft was opened",
      "path": "src/main.mbt",
      "current_content": "",
    }
    for index in 0..<2 {
      source_save_test_send(fixture, cell, Save)
      ignore(
        source_save_http_resolve(fixture, index, 409, conflict.stringify()).wait(),
      )
      assert_eq(cell.val.draft, "human edit")
      assert_eq(cell.val.baseline, "fn main {}")
      assert_true(cell.val.server_content is Some(""))
      assert_true(source_pane_dirty(cell.val))
      assert_false(cell.val.saving)
      assert_eq(cell.val.status, "File changed after this draft was opened")
    }
    source_save_test_send(fixture, cell, ReplaceServer)
    guard @json.parse(source_save_http_requests(fixture)) is Array(requests) else {
      fail("Expected source requests")
    }
    assert_eq(
      handoff_field(requests[2], "body"),
      (
        {
          "path": "src/main.mbt",
          "content": "human edit",
          "expected_content": "",
        } : Json),
    )
    ignore(
      source_save_http_resolve(
        fixture,
        2,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_eq(cell.val.status, "Saved")
    assert_eq(cell.val.draft, "human edit")
    assert_false(source_pane_dirty(cell.val))
  })
}

///|
test "source save external conflicts reload both empty and nonempty versions" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    for index, current in ["", "agent replacement"] {
      let cell = Ref(source_save_test_state())
      let conflict : Json = {
        "code": 409,
        "reason": "Conflict",
        "error": "File changed after this draft was opened",
        "path": "src/main.mbt",
        "current_content": current,
      }
      source_save_test_send(fixture, cell, Save)
      ignore(
        source_save_http_resolve(fixture, index, 409, conflict.stringify()).wait(),
      )
      assert_eq(cell.val.server_content, Some(current))
      cell.val = update_source_pane(cell.val, ReloadServer)
      assert_eq(cell.val.draft, current)
      assert_eq(cell.val.baseline, current)
      assert_false(source_pane_dirty(cell.val))
      assert_eq(cell.val.status, "Reloaded external version")
    }
  })
}

///|
test "source save successful empty and nonempty contents stay supported" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    for index, content in ["", "human edit"] {
      let cell = Ref(source_save_test_state(draft=content))
      source_save_test_send(fixture, cell, Save)
      ignore(
        source_save_http_resolve(
          fixture,
          index,
          200,
          source_save_test_success(content).stringify(),
        ).wait(),
      )
      assert_eq(cell.val.draft, content)
      assert_eq(cell.val.baseline, content)
      assert_false(source_pane_dirty(cell.val))
      assert_false(cell.val.saving)
      assert_eq(cell.val.status, "Saved")
    }
  })
}

///|
test "source save incomplete and malformed responses never retire the draft" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    for
      index, body in [
        "", "{}", "{\"ok\":true}", "{\"ok\":false,\"content\":\"wrong\"}", "null",
        "not json",
      ] {
      let cell = Ref(source_save_test_state())
      source_save_test_send(fixture, cell, Save)
      ignore(source_save_http_resolve(fixture, index, 200, body).wait())
      assert_eq(cell.val.draft, "human edit")
      assert_eq(cell.val.baseline, "fn main {}")
      assert_true(source_pane_dirty(cell.val))
      assert_false(cell.val.saving)
      assert_true(cell.val.status.contains("Could not save source file"))
    }
  })
}

///|
test "source save network failure keeps the edit available to retry" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref(source_save_test_state())
    source_save_test_send(fixture, cell, Save)
    ignore(source_save_http_reject(fixture, 0).wait())
    assert_eq(cell.val.draft, "human edit")
    assert_eq(cell.val.baseline, "fn main {}")
    assert_true(source_pane_dirty(cell.val))
    assert_false(cell.val.saving)
    source_save_test_send(fixture, cell, Save)
    ignore(
      source_save_http_resolve(
        fixture,
        1,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_eq(cell.val.status, "Saved")
    assert_false(source_pane_dirty(cell.val))
  })
}
