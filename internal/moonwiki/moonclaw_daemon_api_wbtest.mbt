///|
test "MoonClaw model readiness distinguishes setup from unknown routes" {
  let ready = moonclaw_model_readiness_from_probe(
    Ok({
      "ready": true,
      "default_model": "codex/gpt-5.6-sol",
      "models": [{ "name": "codex/gpt-5.6-sol", "default": true }],
    }),
  )
  assert_true(json_bool(ready, "known", default=false))
  assert_true(json_bool(ready, "ready", default=false))
  assert_eq(json_string(ready, "status", default=""), "ready")

  let missing = moonclaw_model_readiness_from_probe(
    Ok({ "ready": false, "default_model": "", "models": [] }),
  )
  assert_true(json_bool(missing, "known", default=false))
  assert_false(json_bool(missing, "ready", default=true))
  assert_eq(json_string(missing, "status", default=""), "needs_configuration")

  let exact_error = "MoonClaw GET /v1/models returned 404: legacy route missing"
  let unknown = moonclaw_model_readiness_from_probe(Err(exact_error))
  assert_false(json_bool(unknown, "known", default=true))
  assert_eq(json_string(unknown, "status", default=""), "unknown")
  assert_eq(json_string(unknown, "error", default=""), exact_error)
}

///|
test "MoonClaw auth readiness preserves provider evidence" {
  let payload : Json = {
    "codex": {
      "authenticated": true,
      "email": "developer@example.com",
      "plan": "team",
    },
    "copilot": { "authenticated": false },
  }
  let readiness = moonclaw_auth_readiness_from_probe(Ok(payload))
  assert_true(json_bool(readiness, "known", default=false))
  assert_true(json_bool(readiness, "ready", default=false))
  assert_eq(json_string(readiness, "status", default=""), "ready")
  let codex = json_object_field(readiness, "codex").unwrap()
  assert_true(json_bool(codex, "known", default=false))
  assert_true(json_bool(codex, "authenticated", default=false))
  assert_eq(json_string(codex, "email", default=""), "developer@example.com")
  let copilot = json_object_field(readiness, "copilot").unwrap()
  assert_true(json_bool(copilot, "known", default=false))
  assert_false(json_bool(copilot, "authenticated", default=true))
}

///|
test "MoonDesk auth status proxy keeps raw provider fields and exact errors" {
  let daemon : Json = { "running": true, "port": 49152 }
  let payload : Json = {
    "codex": { "authenticated": false },
    "copilot": { "authenticated": false },
  }
  let response = moonclaw_auth_status_response_from_probe(daemon, Ok(payload))
  assert_false(json_bool(response, "ok", default=true))
  assert_eq(
    json_string(response, "status", default=""),
    "authentication_required",
  )
  assert_true(json_object_field(response, "codex") is Some(_))
  assert_true(json_object_field(response, "copilot") is Some(_))
  assert_eq(
    json_string(response, "next_action", default=""),
    "authenticate_model_provider",
  )
  let openrouter_ready = moonclaw_auth_status_response_from_probe(
    { "running": true, "model_readiness": { "known": true, "ready": true } },
    Ok(payload),
  )
  assert_true(json_bool(openrouter_ready, "ok", default=false))
  assert_true(json_bool(openrouter_ready, "model_ready", default=false))
  assert_eq(json_string(openrouter_ready, "status", default=""), "ready")

  let exact_error = "MoonClaw GET /v1/auth/status returned 404: upgrade required"
  let failed = moonclaw_auth_status_response_from_probe(
    daemon,
    Err(exact_error),
  )
  assert_eq(json_string(failed, "message", default=""), exact_error)
  assert_eq(json_string(failed, "upstream_error", default=""), exact_error)
  assert_eq(json_string(failed, "status", default=""), "auth_status_unknown")
}

///|
test "MoonDesk auth start proxy preserves provider payloads and exact errors" {
  let daemon : Json = { "running": true, "port": 49152 }
  let codex = moonclaw_auth_start_response_from_probe(
    daemon,
    "codex",
    Ok({
      "auth_url": "https://auth.openai.com/oauth/authorize?client_id=test",
      "state": "opaque-state",
    }),
  )
  assert_true(json_bool(codex, "ok", default=false))
  assert_eq(
    json_string(codex, "auth_url", default=""),
    "https://auth.openai.com/oauth/authorize?client_id=test",
  )
  assert_eq(json_string(codex, "state", default=""), "opaque-state")
  assert_eq(
    json_string(codex, "next_action", default=""),
    "open_authorization_url",
  )

  let copilot = moonclaw_auth_start_response_from_probe(
    daemon,
    "copilot",
    Ok({
      "user_code": "ABCD-EFGH",
      "verification_uri": "https://github.com/login/device",
      "expires_in": 900,
      "interval": 5,
    }),
  )
  assert_eq(json_string(copilot, "user_code", default=""), "ABCD-EFGH")
  assert_eq(
    json_string(copilot, "next_action", default=""),
    "complete_device_authorization",
  )

  let exact_error = "MoonClaw POST /v1/auth/copilot/start returned 500: device flow unavailable"
  let failed = moonclaw_auth_start_response_from_probe(
    daemon,
    "copilot",
    Err(exact_error),
  )
  assert_false(json_bool(failed, "ok", default=true))
  assert_eq(json_string(failed, "message", default=""), exact_error)
  assert_eq(json_string(failed, "upstream_error", default=""), exact_error)

  let incomplete_codex = moonclaw_auth_start_response_from_probe(
    daemon,
    "codex",
    Ok({ "state": "opaque-state" }),
  )
  assert_false(json_bool(incomplete_codex, "ok", default=true))
  assert_eq(
    json_string(incomplete_codex, "status", default=""),
    "auth_start_failed",
  )
  assert_true(
    json_string(incomplete_codex, "message", default="").contains(
      "auth_url and state",
    ),
  )

  let incomplete_copilot = moonclaw_auth_start_response_from_probe(
    daemon,
    "copilot",
    Ok({ "user_code": "ABCD-EFGH" }),
  )
  assert_false(json_bool(incomplete_copilot, "ok", default=true))
  assert_true(
    json_string(incomplete_copilot, "message", default="").contains(
      "user_code and verification_uri",
    ),
  )

  let untrusted_codex = moonclaw_auth_start_response_from_probe(
    daemon,
    "codex",
    Ok({ "auth_url": "javascript:alert(1)", "state": "opaque-state" }),
  )
  assert_false(json_bool(untrusted_codex, "ok", default=true))
  assert_true(
    json_string(untrusted_codex, "message", default="").contains(
      "untrusted authorization destination",
    ),
  )
  let untrusted_copilot = moonclaw_auth_start_response_from_probe(
    daemon,
    "copilot",
    Ok({
      "user_code": "ABCD-EFGH",
      "verification_uri": "https://github.com.evil.test/login/device",
    }),
  )
  assert_false(json_bool(untrusted_copilot, "ok", default=true))
  assert_true(
    json_string(untrusted_copilot, "message", default="").contains(
      "untrusted verification destination",
    ),
  )
}

///|
test "OpenRouter key validation and merge are narrow" {
  assert_true(
    moonclaw_openrouter_key_from_payload({ "api_key": "  sk-test  " })
    is Ok("sk-test"),
  )
  assert_true(moonclaw_openrouter_key_from_payload({ "api_key": "" }) is Err(_))
  assert_true(
    moonclaw_openrouter_key_from_payload({ "api_key": "x".repeat(4097) })
    is Err(_),
  )
  assert_true(moonclaw_openrouter_key_from_payload({}) is Err(_))

  let merged = moonclaw_config_with_openrouter_key(
    {
      "api_key": "old-secret",
      "primary": "codex/gpt-5.6-sol",
      "models": { "providers": { "local": { "base_url": "http://127.0.0.1" } } },
    },
    "new-secret",
  )
  assert_eq(json_string(merged, "api_key", default=""), "new-secret")
  assert_eq(json_string(merged, "primary", default=""), "codex/gpt-5.6-sol")
  assert_true(json_object_field(merged, "models") is Some(_))

  let failure = moonclaw_openrouter_key_failure_response(
    "invalid_api_key", "api_key must not be empty", "enter_openrouter_api_key",
  )
  assert_false(json_bool(failure, "ok", default=true))
  assert_false(json_bool(failure, "model_ready", default=true))
  assert_eq(
    json_string(failure, "message", default=""),
    "api_key must not be empty",
  )
}

///|
async test "OpenRouter key writer preserves config and enforces private mode" {
  let root = "/tmp/moondesk-openrouter-key-wbtest-" +
    @desk.stable_id("openrouter-key", @async.now().to_string())
  let product_dir = moonsuite_product_dir(root, "moonclaw")
  @fsx.make_directory(product_dir, recursive=true, exists_ok=true)
  let config_path = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "moonclaw.json",
  )
  @fsx.write_to_file(
    config_path,
    ({ "primary": "codex/gpt-5.6-sol", "models": { "providers": {} } } : Json).stringify(
      indent=2,
    ) +
    "\n",
    create=0o644,
  )
  let written = moonclaw_write_openrouter_key(root, "sk-secret-for-test")
  guard written is Ok(path) else {
    fail("expected OpenRouter key write to succeed")
  }
  assert_eq(path, config_path)
  let stored = read_json_file_or_object(path)
  assert_eq(json_string(stored, "api_key", default=""), "sk-secret-for-test")
  assert_eq(json_string(stored, "primary", default=""), "codex/gpt-5.6-sol")
  assert_true(json_object_field(stored, "models") is Some(_))
  let (mode_code, mode_text, _) = run_process_capture("ls", ["-l", path])
  assert_eq(mode_code, 0)
  assert_true(mode_text.has_prefix("-rw-------"))

  let response = moonclaw_openrouter_key_success_response(
    path,
    { "running": true },
    { "known": true, "ready": true },
  )
  assert_true(json_bool(response, "model_ready", default=false))
  assert_eq(
    json_string(response, "status", default=""),
    "openrouter_key_configured",
  )
  assert_false(response.stringify().contains("sk-secret-for-test"))
}

///|
async test "OpenRouter key writer rejects redirected config paths" {
  let root = "/tmp/moondesk-openrouter-symlink-wbtest-" +
    @desk.stable_id("openrouter-symlink", @async.now().to_string())
  let product_dir = moonsuite_product_dir(root, "moonclaw")
  @fsx.make_directory(product_dir, recursive=true, exists_ok=true)
  let target_path = @pathx.join(root, "tracked-config.json")
  @fsx.write_to_file(target_path, "{\"safe\":true}\n", create=0o644)
  let config_path = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "moonclaw.json",
  )
  @fs.symlink(config_path, target=target_path)
  let result = moonclaw_write_openrouter_key(root, "sk-must-not-escape")
  assert_true(result is Err(_))
  assert_eq(@fs.read_file(target_path).text(), "{\"safe\":true}\n")
  assert_false(@fs.read_file(target_path).text().contains("sk-must-not-escape"))
}

///|
async test "OpenRouter key writer rejects redirected product directories" {
  let root = "/tmp/moondesk-openrouter-dir-symlink-wbtest-" +
    @desk.stable_id("openrouter-dir-symlink", @async.now().to_string())
  let product_dir = moonsuite_product_dir(root, "moonclaw")
  let product_parent = @pathx.dirname(product_dir)
  @fsx.make_directory(product_parent, recursive=true, exists_ok=true)
  let redirected = root + "-redirected"
  @fsx.make_directory(redirected, recursive=true, exists_ok=true)
  @fs.symlink(product_dir, target=redirected)
  let result = moonclaw_write_openrouter_key(root, "sk-must-not-escape")
  assert_true(result is Err(_))
  assert_false(@fsx.exists(@pathx.join(redirected, "moonclaw.json")))
}
