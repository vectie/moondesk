///|
test "daemon readiness probes retain authenticated workspace binding" {
  let config = moonclaw_control_test_config()
  let probe = moonclaw_status_probe(
    4444,
    true,
    moonclaw_daemon_info_path(config.workspace_root),
  )
  assert_true(moonclaw_control_config_for_daemon(probe, Some(config)) is Ok(_))
  assert_true(
    moonclaw_control_config_for_daemon(
      moonclaw_status_probe(
        4444,
        false,
        moonclaw_daemon_info_path(config.workspace_root),
      ),
      Some(config),
    )
    is Err(_),
  )
  assert_true(
    moonclaw_control_config_for_daemon(
      moonclaw_status_probe(4444, true, "/another/daemon-info.json"),
      Some(config),
    )
    is Err(_),
  )
}

///|
fn moonclaw_control_test_config(
  workspace_root~ : String = "/registered/book",
) -> SourceSemanticsSandboxClientConfig {
  {
    protocol_version: 1,
    instance_id: "0123456789abcdef0123456789abcdef",
    auth_token: "a".repeat(64),
    workspace_id: "book",
    workspace_root,
  }
}

///|
test "MoonClaw control config fails closed when missing or malformed" {
  let config = moonclaw_control_test_config()
  let daemon : Json = {
    "running": true,
    "port": 4444,
    "info_path": moonclaw_daemon_info_path(config.workspace_root),
  }
  assert_true(moonclaw_control_config_for_daemon(daemon, None) is Err(_))
  let malformed = SourceSemanticsSandboxClientConfig::{
    ..config,
    auth_token: "caller-token",
  }
  assert_true(
    moonclaw_control_config_for_daemon(daemon, Some(malformed)) is Err(_),
  )
  let wrong_instance = SourceSemanticsSandboxClientConfig::{
    ..config,
    instance_id: "short",
  }
  assert_true(
    moonclaw_control_config_for_daemon(daemon, Some(wrong_instance)) is Err(_),
  )
  assert_true(moonclaw_control_config_for_daemon(daemon, Some(config)) is Ok(_))
}

///|
async test "MoonClaw control transport authenticates a fake localhost service" {
  let workspace_root = @pathx.join(
    @env.get_env_var("TMPDIR").unwrap_or("/tmp"),
    "moondesk-control-transport-" + @async.now().to_string(),
  )
  @fsx.make_directory(workspace_root, recursive=true, exists_ok=true)
  let config = moonclaw_control_test_config(workspace_root~)
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let daemon : Json = {
    "running": true,
    "port": server.addr.port(),
    "info_path": moonclaw_daemon_info_path(config.workspace_root),
  }
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, _, conn) => {
            assert_eq(request.path, "/v1/models")
            assert_eq(
              request.headers.get("x-moonclaw-execution-token"),
              Some(config.auth_token),
            )
            assert_eq(
              request.headers.get("x-moonclaw-instance-id"),
              Some(config.instance_id),
            )
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
              "X-MoonClaw-Instance-ID": config.instance_id,
            })
            conn.write_string("{\"models\":[]}")
            conn.end_response()
          },
          allow_failure=false,
          max_connections=1,
        )
      },
      no_wait=true,
    )
    let response = moonclaw_get_json_with_control_config(
      daemon, "/v1/models", config,
    )
    assert_true(response is Ok(_))
  })
  @fs.remove(workspace_root) catch {
    _ => ()
  }
}

///|
test "MoonClaw control transport never reflects its credential" {
  let config = moonclaw_control_test_config()
  let unauthorized : @http.Response = {
    code: 401,
    reason: "Unauthorized",
    headers: { "x-moonclaw-instance-id": config.instance_id },
    cookies: [],
  }
  let hostile_body : &@io.Data = "reflected=" + config.auth_token
  let error = moonclaw_control_response_text(
    unauthorized, hostile_body, config, "GET /v1/models",
  )
  assert_true(error is Err(_))
  match error {
    Err(message) => assert_false(message.contains(config.auth_token))
    Ok(_) => fail("expected reflected credential to be rejected")
  }
}

///|
async fn moonclaw_code_route_transport_fixture(
  path : String,
  payload : Json,
  expected : Json,
  response_instance~ : String = "0123456789abcdef0123456789abcdef",
) -> Result[Json, String] {
  let config = moonclaw_control_test_config()
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let daemon : Json = {
    "running": true,
    "port": server.addr.port(),
    "info_path": moonclaw_daemon_info_path(config.workspace_root),
  }
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, body, conn) => {
            assert_true(request.meth is Post)
            assert_eq(request.path, path)
            assert_eq(
              request.headers.get("x-moonclaw-execution-token"),
              Some(config.auth_token),
            )
            assert_eq(
              request.headers.get("x-moonclaw-instance-id"),
              Some(config.instance_id),
            )
            assert_eq(
              request.headers.get("content-type"),
              Some("application/json"),
            )
            assert_eq(@json.parse(body.read_all().text()), payload)
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
              "X-MoonClaw-Instance-ID": response_instance,
              "Cache-Control": "no-store",
            })
            conn.write_string(expected.stringify())
            conn.end_response()
          },
          allow_failure=false,
          max_connections=1,
        )
      },
      no_wait=true,
    )
    moonclaw_post_json_with_control_config(daemon, path, payload, config)
  })
}

///|
async test "canonical MCP discovery forwards control headers and preserves server results" {
  let payload : Json = { "book_root": "/registered/book", "server": "fixture" }
  let expected : Json = {
    "tool": "mcp_list_tools",
    "ok": true,
    "is_error": false,
    "servers": [
      { "id": "fixture", "result": { "tools": [{ "name": "fixture-tool" }] } },
    ],
    "output": "fixture tools",
  }
  assert_eq(
    moonclaw_code_route_transport_fixture("/v1/code/mcp", payload, expected),
    Ok(expected),
  )
}

///|
async test "canonical knowledge forwards retrieval and embedding payloads without reshaping" {
  let cases : Array[(Json, Json)] = [
    (
      { "book_root": "/registered/book", "query": "fixture query" },
      {
        "ok": true,
        "retrieval": "hybrid",
        "semantic_error": "",
        "hits": [
          {
            "path": "note.md",
            "title": "Fixture note",
            "text": "fixture",
            "source_id": "source-1",
            "start_line": 1,
            "end_line": 2,
            "score": 0.9,
            "similarity": 0.8,
            "citation": "note.md:1",
          },
        ],
      },
    ),
    (
      {
        "book_root": "/registered/book",
        "action": "embed",
        "texts": ["fixture"],
      },
      { "ok": true, "embedding_key": "fixture-model", "vectors": [[0.5, 0.25]] },
    ),
    (
      {
        "book_root": "/registered/book",
        "action": "embed",
        "texts": ["fixture"],
      },
      { "ok": false, "message": "Embedding provider is not configured" },
    ),
  ]
  for (payload, expected) in cases {
    assert_eq(
      moonclaw_code_route_transport_fixture(
        "/v1/code/knowledge", payload, expected,
      ),
      Ok(expected),
    )
  }
}

///|
async test "canonical realtime forwards session binding and preserves ephemeral response" {
  let payload : Json = {
    "book_root": "/registered/book",
    "session_id": "fixture-session",
    "model": "configured-model",
    "voice": "marin",
    "context": "fixture context",
  }
  let expected : Json = {
    "value": "ephemeral-fixture-only",
    "expires_at": 1234567890,
    "endpoint": "http://127.0.0.1/realtime/calls",
    "model": "gpt-realtime",
  }
  assert_eq(
    moonclaw_code_route_transport_fixture(
      "/v1/code/realtime-session", payload, expected,
    ),
    Ok(expected),
  )
}

///|
async test "canonical code routes reject stale instance responses and reflected credentials" {
  let config = moonclaw_control_test_config()
  for
    path in ["/v1/code/mcp", "/v1/code/knowledge", "/v1/code/realtime-session"] {
    let payload : Json = { "book_root": "/registered/book" }
    let wrong_instance = moonclaw_code_route_transport_fixture(
      path,
      payload,
      { "ok": true },
      response_instance="fedcba9876543210fedcba9876543210",
    )
    assert_true(wrong_instance is Err(_))
    let reflected = moonclaw_code_route_transport_fixture(path, payload, {
      "message": config.auth_token,
    })
    guard reflected is Err(message) else {
      fail("private control token must never reach a consumer")
    }
    assert_false(message.contains(config.auth_token))
  }
}
