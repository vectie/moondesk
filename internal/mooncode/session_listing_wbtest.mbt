///|
test "mooncode session listing row follows machine session picker shape" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book-a",
    "workspace_name": "Book A",
    "cwd": "/tmp/book-a",
    "title": "Fallback title",
    "updated_at": "2026-06-16T10:00:00Z",
    "status": "running",
    "model": "deepseek-v4-pro",
    "last_message": "  build a miniapp\nwith tests",
  }
  let row = session_listing_row(session, Json::number(1781580000000.0))
  assert_eq(json_string(row, "id", default=""), "s1")
  assert_eq(json_string(row, "title", default=""), "build a miniapp")
  assert_eq(json_string(row, "workspace_root", default=""), "/tmp/book-a")
  assert_eq(json_string(row, "cwd", default=""), "/tmp/book-a")
  assert_eq(json_string(row, "status", default=""), "running")
  assert_eq(json_string(row, "protocol", default=""), "mooncode.v1")
  assert_true(summary_json_object_field(row, "transcript") is None)
  assert_true(summary_json_object_field(row, "mooncode_events") is None)
  let summary = summary_json_object_field_or_empty(row, "mooncode_summary")
  assert_eq(summary_json_int(summary, "event_count", default=-1), 0)
  assert_true(row.stringify().contains("\"updated_at_ms\":1781580000000"))
  assert_true(
    json_string(row, "stream_url", default="").contains(
      "/api/mooncode/sessions/s1/stream",
    ),
  )
}

///|
test "mooncode session listing title falls back without first prompt" {
  let session : Json = {
    "id": "s2",
    "title": "Fallback title",
    "last_message": "  last message\twith spaces\nextra",
  }
  assert_eq(session_listing_title(session), "last message with spaces")
  let title_only : Json = {
    "id": "s3",
    "title": "Title only",
    "last_message": "",
  }
  assert_eq(session_listing_title(title_only), "Title only")
}

///|
test "mooncode session listing title prefers stored first prompt fields" {
  let direct : Json = {
    "id": "s4",
    "first_user_prompt": "  create a tiny tool\nwith tests",
    "last_message": "later follow-up",
  }
  assert_eq(session_listing_title(direct), "create a tiny tool")
  let from_snapshot : Json = {
    "id": "s5",
    "snapshot": { "first_prompt": "  resume package work\tcarefully\nnotes" },
    "title": "Fallback",
    "last_message": "latest",
  }
  assert_eq(
    session_listing_title(from_snapshot),
    "resume package work carefully",
  )
}

///|
test "mooncode session listing merge keeps local identity and runtime freshness" {
  let runtime_rows : Array[Json] = [
    {
      "id": "session-a",
      "title": "Native session A",
      "source": "moonclaw",
      "status": "durable",
      "workspace_id": "wrong-runtime-id",
      "workspace_name": "Wrong runtime name",
      "updated_at_ms": Json::number(42.0, repr="42"),
    },
    { "title": "Diagnostic row without id", "source": "moonclaw" },
  ]
  let local_sessions : Array[Json] = [
    {
      "id": "session-a",
      "title": "Local duplicate A",
      "workspace_id": "book",
      "workspace_root": "/tmp/book",
    },
    {
      "id": "session-b",
      "title": "Local session B",
      "workspace_id": "book",
      "workspace_root": "/tmp/book",
    },
  ]
  let rows = merge_session_listing_rows(runtime_rows, local_sessions)
  assert_eq(rows.length(), 2)
  assert_eq(json_string(rows[0], "id", default=""), "session-a")
  assert_eq(json_string(rows[0], "title", default=""), "Local duplicate A")
  assert_eq(json_string(rows[0], "workspace_id", default=""), "book")
  assert_eq(json_string(rows[0], "workspace_root", default=""), "/tmp/book")
  assert_eq(
    json_string(rows[0], "source", default=""),
    "mooncode-session-listing",
  )
  assert_eq(json_string(rows[0], "runtime_source", default=""), "moonclaw")
  assert_true(rows[0].stringify().contains("\"updated_at_ms\":42"))
  assert_eq(json_string(rows[1], "id", default=""), "session-b")
  assert_eq(json_string(rows[1], "title", default=""), "Local session B")
  assert_eq(
    json_string(rows[1], "source", default=""),
    "mooncode-session-listing",
  )
}

///|
test "mooncode session listing merge sorts runtime and local rows newest first" {
  let runtime_rows : Array[Json] = [
    {
      "id": "native-old",
      "title": "Native old",
      "updated_at_ms": Json::number(10.0, repr="10"),
    },
    {
      "id": "native-new",
      "title": "Native new",
      "updated_at_ms": Json::number(200.0, repr="200"),
    },
  ]
  let local_sessions : Array[Json] = [
    {
      "id": "local-mid",
      "title": "Local mid",
      "workspace_id": "book",
      "updated_at": "2026-06-17T00:00:00Z",
    },
  ]
  let rows = merge_session_listing_rows(runtime_rows, local_sessions)
  assert_eq(rows.length(), 3)
  assert_eq(json_string(rows[0], "id", default=""), "native-new")
  assert_eq(json_string(rows[1], "id", default=""), "native-old")
  assert_eq(json_string(rows[2], "id", default=""), "local-mid")
}

///|
test "mooncode runtime session listing accepts mooncode array and moonclaw envelope" {
  let row_a : Json = {
    "id": "a",
    "title": "A",
    "updated_at_ms": Json::number(20.0, repr="20"),
  }
  let row_b : Json = {
    "id": "b",
    "title": "B",
    "updated_at_ms": Json::number(10.0, repr="10"),
  }
  let raw = runtime_session_listing_rows(Json::array([row_a]))
  assert_eq(raw.length(), 1)
  assert_eq(json_string(raw[0], "id", default=""), "a")
  assert_eq(
    json_string(raw[0], "source", default=""),
    "mooncode-runtime-session-listing",
  )
  assert_eq(json_string(raw[0], "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(raw[0], "component", default=""), "mooncode")
  assert_eq(json_string(raw[0], "workspace_id", default="<missing>"), "")
  assert_eq(json_string(raw[0], "workspace_name", default="<missing>"), "")
  assert_eq(json_string(raw[0], "workspace_root", default="<missing>"), "")
  assert_eq(json_string(raw[0], "cwd", default="<missing>"), "")
  assert_eq(json_string(raw[0], "status", default="<missing>"), "")
  assert_eq(json_string(raw[0], "model", default="<missing>"), "")
  assert_eq(json_string(raw[0], "updated_at", default="<missing>"), "")
  assert_eq(summary_json_int(raw[0], "queued_count", default=-1), 0)
  assert_true(summary_json_object_field(raw[0], "transcript") is None)
  assert_true(summary_json_object_field(raw[0], "mooncode_events") is None)
  let enveloped = runtime_session_listing_rows({ "sessions": [row_b] })
  assert_eq(enveloped.length(), 1)
  assert_eq(json_string(enveloped[0], "id", default=""), "b")
  assert_eq(runtime_session_listing_rows({ "sessions": "bad" }).length(), 0)
  let mixed = runtime_session_listing_rows({
    "sessions": [
      "not an object",
      { "title": "missing id", "updated_at_ms": 99 },
      row_b,
    ],
  })
  assert_eq(mixed.length(), 1)
  assert_eq(json_string(mixed[0], "id", default=""), "b")
}

///|
test "mooncode runtime session listing normalizes source and preserves provenance" {
  let rows = runtime_session_listing_rows({
    "sessions": [
      {
        "id": "native-a",
        "title": "Native A",
        "source": "moonclaw",
        "protocol": protocol_version(),
        "component": "mooncode",
        "status": "durable",
      },
    ],
  })
  assert_eq(rows.length(), 1)
  assert_eq(
    json_string(rows[0], "source", default=""),
    "mooncode-runtime-session-listing",
  )
  assert_eq(json_string(rows[0], "runtime_source", default=""), "moonclaw")
  assert_eq(json_string(rows[0], "status", default=""), "durable")
  assert_true(rows[0].stringify().contains("\"updated_at_ms\":null"))
}
