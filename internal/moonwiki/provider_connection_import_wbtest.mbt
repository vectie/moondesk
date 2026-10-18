///|
fn test_connection_import() -> OpenAiConnectionImport {
  {
    version: "openai.connection.v1",
    api: "chat.completions",
    base_url: "https://example.invalid/user/v1",
    api_key: "test-only-not-a-live-key",
    model: "glm-5.3.flash",
    max_output_tokens: 16384,
  }
}

///|
test "connection import validates complete generic settings before any network call" {
  let valid = test_connection_import()
  assert_true(valid_openai_connection_import(valid))
  for
    invalid in [
      { ..valid, version: "other", },
      { ..valid, api: "responses", },
      { ..valid, api_key: "api-key-record", },
      { ..valid, api_key: "token\r\nheader", },
      { ..valid, api_key: "", },
      { ..valid, api_key: "x".repeat(513), },
      { ..valid, model: "", },
      { ..valid, max_output_tokens: 0, },
      { ..valid, max_output_tokens: 131073, },
      { ..valid, base_url: "http://example.com/v1", },
      { ..valid, base_url: "https://user:secret@example.com/v1", },
      { ..valid, base_url: "https://example.com/v1?api_key=secret", },
      { ..valid, base_url: "https://example.com/v1#secret", },
      { ..valid, base_url: "https://example.com/v1/chat/completions", },
    ] {
    assert_false(valid_openai_connection_import(invalid))
  }
  assert_eq(
    connection_url_parts("https://example.com:8443/user/v1/"),
    Some(("https://example.com:8443", "/user/v1")),
  )
  assert_true(connection_url_parts("http://127.0.0.1:9999/v1") is Some(_))
  assert_true(connection_url_parts("http://127.0.0.1.evil/v1") is None)
}

///|
test "imported provider identity remains stable and Claw receives the complete descriptor" {
  let value = test_connection_import()
  let id = imported_connection_provider_id(value)
  assert_eq(
    id,
    imported_connection_provider_id({ ..value, api_key: "different-test-key", }),
  )
  assert_false(
    id == imported_connection_provider_id({ ..value, model: "other", }),
  )
  assert_eq(openai_connection_import_json(value), {
    "version": "openai.connection.v1",
    "api": "chat.completions",
    "base_url": value.base_url,
    "api_key": value.api_key,
    "model": value.model,
    "max_output_tokens": value.max_output_tokens,
  })
}

///|
fn test_imported_connection_response(value : OpenAiConnectionImport) -> Json {
  {
    "ok": true,
    "status": "connected",
    "model": value.model,
    "provider_id": imported_connection_provider_id(value),
  }
}

///|
async test "import uses authenticated Claw control and rejects failed unbound or mismatched confirmation" {
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let config = moonclaw_control_test_config()
  let daemon = moonclaw_status_probe(
    server.addr.port(),
    true,
    moonclaw_daemon_info_path(config.workspace_root),
  )
  let value = test_connection_import()
  let good = test_imported_connection_response(value)
  let reflected : Json = {
    "error": value.api_key + " /fixture/private/server/path",
  }
  let fixtures : Array[(Int32, String, String)] = [
    (200, config.instance_id, good.stringify()),
    (401, config.instance_id, reflected.stringify()),
    (502, config.instance_id, reflected.stringify()),
    (200, "f".repeat(32), good.stringify()),
    (200, config.instance_id, "{}"),
    (
      200,
      config.instance_id,
      test_imported_connection_response({ ..value, model: "other", }).stringify(),
    ),
    (
      200,
      config.instance_id,
      (
        {
          "ok": true,
          "status": "connected",
          "model": value.model,
          "provider_id": "wrong-provider",
        } : Json).stringify(),
    ),
    (
      200,
      config.instance_id,
      (
        {
          "ok": false,
          "status": "connected",
          "model": value.model,
          "provider_id": imported_connection_provider_id(value),
        } : Json).stringify(),
    ),
    (200, config.instance_id, "not-json"),
    (
      200,
      config.instance_id,
      (
        {
          "ok": true,
          "status": "connected",
          "model": value.model,
          "provider_id": imported_connection_provider_id(value),
          "reflected": config.auth_token,
        } : Json).stringify(),
    ),
  ]
  let requests : Array[Json] = []
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, body, conn) => {
            let index = requests.length()
            requests.push({
              "path": request.path,
              "token": request.headers
              .get("x-moonclaw-execution-token")
              .unwrap_or(""),
              "instance": request.headers
              .get("x-moonclaw-instance-id")
              .unwrap_or(""),
              "content_type": request.headers.get("content-type").unwrap_or(""),
              "body": @json.parse(body.read_all().text()),
            })
            guard fixtures.get(index) is Some((status, instance, response)) else {
              fail("Unexpected import control request")
            }
            conn.send_response(status, "Fixture Response", extra_headers={
              "Content-Type": "application/json",
              "X-MoonClaw-Instance-ID": instance,
              "Cache-Control": "no-store",
            })
            conn.write_string(response)
            conn.end_response()
          },
          allow_failure=true,
        )
      },
      no_wait=true,
    )
    assert_true(
      install_openai_connection_import_with_control_config(
        daemon,
        { ..value, api_key: "", },
        config,
      )
      is Err(_),
    )
    assert_true(requests.is_empty())
    for index in 0..<fixtures.length() {
      let result = install_openai_connection_import_with_control_config(
        daemon, value, config,
      )
      if index == 0 {
        assert_true(result is Ok(_))
      } else {
        guard result is Err(message) else {
          fail("Invalid Claw import confirmation was accepted")
        }
        for
          secret in [
            value.api_key,
            config.auth_token,
            "/fixture/private/server/path",
          ] {
          assert_false(message.contains(secret))
        }
      }
    }
    assert_eq(requests.length(), fixtures.length())
    for request in requests {
      assert_eq(request, {
        "path": "/v1/provider-connections/import",
        "token": config.auth_token,
        "instance": config.instance_id,
        "content_type": "application/json",
        "body": openai_connection_import_json(value),
      })
    }
  })
}

///|
#skip("Run through the actual Claw dispatcher and transient MoonGate provider fixture")
async test "Desk imports through actual Claw and Gate after rejecting an invalid transient candidate" {
  guard @env.get_env_var("MOONDESK_CLAW_PROVIDER_IMPORT_FIXTURE") is Some(raw) else {
    fail("Run through the isolated actual Claw and MoonGate provider fixture")
  }
  let fixture = @json.parse(raw)
  assert_eq(
    json_string(fixture, "contract", default=""),
    "moondesk-claw-provider-import.loopback.v1",
  )
  assert_true(json_bool(fixture, "synthetic", default=false))
  let port = json_int(fixture, "port", default=0)
  assert_true(port > 0 && port <= 65535)
  let workspace_root = json_string(fixture, "workspace_root", default="")
  assert_true(workspace_root != "")
  let config = {
    ..moonclaw_control_test_config(workspace_root~),
    instance_id: json_string(fixture, "instance_id", default=""),
    auth_token: json_string(fixture, "auth_token", default=""),
  }
  assert_true(source_semantics_safe_hex(config.instance_id, 32))
  assert_true(source_semantics_safe_hex(config.auth_token, 64))
  let daemon = moonclaw_status_probe(
    port,
    true,
    moonclaw_daemon_info_path(workspace_root),
  )
  let value = {
    ..test_connection_import(),
    base_url: json_string(fixture, "base_url", default=""),
    api_key: json_string(fixture, "api_key", default=""),
    model: json_string(fixture, "model", default=""),
  }
  assert_true(value.base_url.has_prefix("http://127.0.0.1:"))
  assert_true(valid_openai_connection_import(value))
  let rejected_model = json_string(fixture, "rejected_model", default="")
  assert_true(rejected_model != "" && rejected_model != value.model)
  match
    install_openai_connection_import_with_control_config(
      daemon,
      { ..value, model: rejected_model, },
      config,
    ) {
    Err(message) => {
      assert_false(message.contains(value.api_key))
      assert_false(message.contains(config.auth_token))
      assert_false(message.contains(workspace_root))
    }
    Ok(_) => fail("Rejected transient candidate was accepted")
  }
  for _ in 0..<2 {
    let result = install_openai_connection_import_with_control_config(
      daemon, value, config,
    )
    guard result is Ok(_) else {
      fail("Actual Claw and Gate did not confirm provider creation or update")
    }
  }
  println("DESK_ACTUAL_PROVIDER_IMPORT_VALIDATION_CREATE_UPDATE_PASSED")
}
