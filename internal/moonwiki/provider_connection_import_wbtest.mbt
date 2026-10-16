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
async test "import activates and binds MoonDesk through the published gateway contract" {
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let requests : Array[String] = []
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, body, conn) => {
            assert_eq(
              request.headers.get("x-moongate-control-token"),
              Some("synthetic-control"),
            )
            requests.push(request.path)
            let response : Json = if request.path ==
              "/providers?appType=openclaw" {
              { "providers": [] }
            } else {
              let payload = @json.parse(body.read_all().text())
              match request.path {
                "/providers" =>
                  assert_true(
                    payload
                    is { "appType": "openclaw", "apiFormat": "openai_chat", .. },
                  )
                "/providers/switch" =>
                  assert_true(
                    payload is { "appType": "openclaw", "id": String(_), .. },
                  )
                "/bindings" =>
                  assert_true(
                    payload
                    is { "appType": "moondesk", "providerId": String(_), .. },
                  )
                _ => fail("unexpected gateway route")
              }
              { "ok": true }
            }
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write_string(response.stringify())
            conn.end_response()
          },
          allow_failure=true,
        )
      },
      no_wait=true,
    )
    assert_true(
      configure_imported_connection(
        "http://127.0.0.1:" + server.addr.port().to_string(),
        "",
        { "x-moongate-control-token": "synthetic-control" },
        test_connection_import(),
      )
      is Ok(_),
    )
    assert_eq(requests, [
      "/providers?appType=openclaw", "/providers", "/providers/switch", "/bindings",
    ])
  })
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
test "imported provider identity is stable without secrets and maps into MoonGate's provider contract" {
  let value = test_connection_import()
  let id = imported_connection_provider_id(value)
  assert_eq(
    id,
    imported_connection_provider_id({ ..value, api_key: "different-test-key", }),
  )
  assert_false(
    id == imported_connection_provider_id({ ..value, model: "other", }),
  )
  let provider = imported_connection_provider(value)
  guard provider is Object(fields) else { fail("expected provider") }
  assert_eq(fields["apiFormat"], Json::string("openai_chat"))
  assert_eq(fields["baseUrl"], Json::string(value.base_url))
  assert_eq(fields["apiKey"], Json::string(value.api_key))
  assert_eq(fields["defaultModel"], Json::string(value.model))
  assert_true(connection_provider_exists({ "providers": [provider] }, id))
  assert_false(
    connection_provider_exists({ "providers": [provider] }, "missing"),
  )
}

///|
async test "connection discovery sends bearer auth and never reflects upstream errors" {
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let key = "test-only-private-key"
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, _, conn) => {
            assert_eq(
              request.headers.get("authorization"),
              Some("Bearer " + key),
            )
            if request.path == "/v1/models" {
              conn.send_response(200, "OK", extra_headers={
                "Content-Type": "application/json",
              })
              conn.write_string("{\"data\":[{\"id\":\"glm-5.3.flash\"}]}")
            } else {
              conn.send_response(401, "Unauthorized", extra_headers={
                "Content-Type": "application/json",
              })
              conn.write_string("{\"error\":\"reflected " + key + "\"}")
            }
            conn.end_response()
          },
          allow_failure=true,
        )
      },
      no_wait=true,
    )
    let origin = "http://127.0.0.1:" + server.addr.port().to_string()
    let headers : @http.Headers = { "Authorization": "Bearer " + key }
    let models = connection_request_json(origin, "/v1/models", headers, None)
    assert_true(models is { "data": [{ "id": "glm-5.3.flash", .. }], .. })
    let error = try {
      let _ = connection_request_json(origin, "/fail", headers, None)
      "unexpected success"
    } catch {
      error => error.to_string()
    }
    assert_true(error.contains("rejected"))
    assert_false(error.contains(key))
  })
}

///|
async test "local control bootstrap preserves the gateway's authority checks and never contacts a remote service" {
  let server = @http.Server::Server(
    @socket.Addr::parse("127.0.0.1:0"),
    reuse_addr=true,
  )
  defer server.close()
  let origin = "http://127.0.0.1:" + server.addr.port().to_string()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, _, conn) => {
            assert_eq(request.path, "/control/bootstrap")
            assert_eq(request.headers.get("origin"), Some(origin))
            assert_eq(
              request.headers.get("sec-fetch-site"),
              Some("same-origin"),
            )
            conn.send_response(200, "OK", extra_headers={
              "Content-Type": "application/json",
            })
            conn.write_string("{\"token\":\"synthetic-local-control-token\"}")
            conn.end_response()
          },
          allow_failure=true,
        )
      },
      no_wait=true,
    )
    assert_eq(
      connection_local_control_token(origin, ""),
      "synthetic-local-control-token",
    )
    try {
      let _ = connection_local_control_token("https://example.invalid", "")
      fail("remote bootstrap bypass")
    } catch {
      Failure(_) => ()
      other => raise other
    }
  })
}
