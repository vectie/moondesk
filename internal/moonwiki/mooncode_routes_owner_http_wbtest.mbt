///|
// This fixture is supplied by the owner-side native HTTP test. It contains only
// temporary Book paths and synthetic identifiers; no ambient control config or
// saved provider credentials are loaded by these consumer tests.
fn mooncode_routes_owner_http_fixture() -> Json raise {
  guard @env.get_env_var("MOONDESK_CLAW_ROUTES_FIXTURE") is Some(raw) else {
    fail("Run through the isolated native Claw route/provider fixture")
  }
  let fixture = @json.parse(raw)
  assert_eq(
    json_string(fixture, "contract", default=""),
    "moondesk-claw-routes.loopback.v1",
  )
  assert_true(json_bool(fixture, "synthetic", default=false))
  let port = json_int(fixture, "port", default=0)
  assert_true(port > 0 && port <= 65535)
  for
    field in [
      "workspace_root", "book_root", "trusted_other_book_root", "untrusted_book_root",
      "session_id", "tool_name", "query", "knowledge_text", "ephemeral_value", "realtime_model",
    ] {
    assert_true(json_string(fixture, field, default="") != "", msg=field)
  }
  fixture
}

///|
fn mooncode_routes_owner_http_daemon(fixture : Json) -> Json {
  {
    "running": true,
    "port": json_int(fixture, "port", default=0),
    "info_path": moonclaw_daemon_info_path(
      json_string(fixture, "workspace_root", default=""),
    ),
  }
}

///|
async fn mooncode_routes_owner_http_post(
  fixture : Json,
  path : String,
  payload : Json,
) -> Json {
  let config = moonclaw_control_test_config(
    workspace_root=json_string(fixture, "workspace_root", default=""),
  )
  guard moonclaw_post_json_with_control_config(
      mooncode_routes_owner_http_daemon(fixture),
      path,
      payload,
      config,
    )
    is Ok(result) else {
    fail(
      "Actual Claw route did not return an authenticated successful response",
    )
  }
  // Long-lived synthetic provider and control credentials must stay server-side.
  let encoded = result.stringify()
  assert_false(encoded.contains(config.auth_token))
  assert_false(encoded.contains("provider-fixture-long-lived-token"))
  result
}

///|
#skip("Run through the isolated actual Claw route and local provider fixture")
async test "Desk control transport discovers tools embeds retrieves and creates realtime through actual Claw" {
  let fixture = mooncode_routes_owner_http_fixture()
  let book_root = json_string(fixture, "book_root", default="")
  let discovered = mooncode_routes_owner_http_post(fixture, "/v1/code/mcp", {
    "book_root": book_root,
  })
  assert_true(json_bool(discovered, "ok", default=false))
  assert_false(json_bool(discovered, "is_error", default=true))
  assert_eq(json_string(discovered, "tool", default=""), "mcp_list_tools")
  let expected_tool = json_string(fixture, "tool_name", default="")
  assert_true(
    json_array_items(discovered, "servers").any(server => {
      match json_object_field(server, "result") {
        Some(result) =>
          json_array_items(result, "tools").any(tool => {
            json_string(tool, "name", default="") == expected_tool
          })
        None => false
      }
    }),
  )
  let embedded = mooncode_routes_owner_http_post(
    fixture,
    "/v1/code/knowledge",
    {
      "book_root": book_root,
      "action": "embed",
      "texts": ["fixture apple", "fixture banana"],
    },
  )
  assert_true(json_bool(embedded, "ok", default=false))
  assert_true(json_string(embedded, "embedding_key", default="") != "")
  let vectors = json_array_items(embedded, "vectors")
  assert_eq(vectors.length(), 2)
  assert_true(vectors[0] is Array(values) && !values.is_empty())
  assert_true(vectors[1] is Array(values) && !values.is_empty())
  let knowledge = mooncode_routes_owner_http_post(
    fixture,
    "/v1/code/knowledge",
    {
      "book_root": book_root,
      "query": json_string(fixture, "query", default=""),
    },
  )
  assert_true(json_bool(knowledge, "ok", default=false))
  assert_eq(json_string(knowledge, "retrieval", default=""), "hybrid")
  assert_eq(json_string(knowledge, "semantic_error", default=""), "")
  let hits = json_array_items(knowledge, "hits")
  assert_true(hits.length() > 0 && hits.length() <= 12)
  assert_true(
    hits.any(hit => {
      json_string(hit, "text", default="") ==
      json_string(fixture, "knowledge_text", default="") &&
      json_string(hit, "source_id", default="") != "" &&
      json_int(hit, "start_line", default=0) > 0 &&
      json_int(hit, "end_line", default=0) >=
      json_int(hit, "start_line", default=0) &&
      json_string(hit, "citation", default="") != ""
    }),
  )
  let realtime = mooncode_routes_owner_http_post(
    fixture,
    "/v1/code/realtime-session",
    {
      "book_root": book_root,
      "session_id": json_string(fixture, "session_id", default=""),
    },
  )
  assert_eq(
    json_string(realtime, "value", default=""),
    json_string(fixture, "ephemeral_value", default=""),
  )
  assert_eq(
    json_string(realtime, "model", default=""),
    json_string(fixture, "realtime_model", default=""),
  )
  assert_true(json_int(realtime, "expires_at", default=0) > 0)
  let endpoint = json_string(realtime, "endpoint", default="")
  assert_true(endpoint.has_prefix("http://127.0.0.1:"))
  assert_true(endpoint.has_suffix("/realtime/calls"))
  println("DESK_ACTUAL_CLAW_CAPABILITIES_PASSED")
}

///|
#skip("Run through the isolated actual Claw route and local provider fixture")
async test "Desk control transport enforces actual Claw authentication and Book admission" {
  let fixture = mooncode_routes_owner_http_fixture()
  let config = moonclaw_control_test_config(
    workspace_root=json_string(fixture, "workspace_root", default=""),
  )
  let daemon = mooncode_routes_owner_http_daemon(fixture)
  let book_root = json_string(fixture, "book_root", default="")
  let port = json_int(fixture, "port", default=0)
  for
    path in ["/v1/code/mcp", "/v1/code/knowledge", "/v1/code/realtime-session"] {
    let payload : Json = { "book_root": book_root }
    let (missing, _) = @http.post("http://127.0.0.1:\{port}\{path}", payload, headers={
      "X-MoonClaw-Instance-ID": config.instance_id,
    })
    assert_eq(missing.code, 401)
    assert_eq(missing.headers.get("cache-control"), Some("no-store"))
    for
      invalid in [
        { ..config, auth_token: "b".repeat(64), },
        { ..config, instance_id: "fedcba9876543210fedcba9876543210", },
      ] {
      let denied = moonclaw_post_json_with_control_config(
        daemon, path, payload, invalid,
      )
      guard denied is Err(message) else {
        fail("Invalid control authentication must be rejected")
      }
      assert_false(message.contains(invalid.auth_token))
    }
    let denied = moonclaw_post_json_with_control_config(
      daemon,
      path,
      { "book_root": json_string(fixture, "untrusted_book_root", default="") },
      config,
    )
    guard denied is Err(message) else {
      fail("A real but unlisted Book must not be admitted")
    }
    assert_true(message.contains("HTTP 403"))
  }
  let rebound = moonclaw_post_json_with_control_config(
    daemon,
    "/v1/code/realtime-session",
    {
      "book_root": json_string(fixture, "trusted_other_book_root", default=""),
      "session_id": json_string(fixture, "session_id", default=""),
    },
    config,
  )
  guard rebound is Err(message) else {
    fail("An existing session must not move to another admitted Book")
  }
  assert_true(message.contains("HTTP 403") || message.contains("HTTP 409"))
  println("DESK_ACTUAL_CLAW_BOUNDARIES_PASSED")
}
