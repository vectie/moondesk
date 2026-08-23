///|
fn moonclaw_control_test_config(
  workspace_root? : String = "/registered/book",
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
    @sys.get_env_var("TMPDIR").unwrap_or("/tmp"),
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
