///|
test "captured context path grants only the exact immutable Proj directory" {
  let capture = "a".repeat(64)
  assert_true(
    mooncode_work_context_path_supported(
      ".moonsuite/products/moonproj/execution-context/" +
      capture +
      "/context.md",
    ),
  )
  for
    path in [
      ".moonsuite/secrets.json",
      "../context.md",
      "/outside/context.md",
      ".moonsuite/products/moonproj/execution-context/../context.md",
      ".moonsuite/products/moonproj/execution-context/" + capture + "/other.md",
      ".moonsuite/products/moonproj/execution-context/" +
      capture +
      "/../context.md",
    ] {
    assert_false(mooncode_work_context_path_supported(path), msg=path)
  }
}

///|
async test "legacy captures have no context and unrelated internal paths are not read" {
  let absent = mooncode_work_read_context(work_handoff_test_workspace(), {
    "original_command": { "context_path": "" },
  })
  assert_eq(json_string(absent, "state", default=""), "absent")
  let unsupported = mooncode_work_read_context(work_handoff_test_workspace(), {
    "original_command": { "context_path": ".moonsuite/secrets.json" },
  })
  assert_eq(json_string(unsupported, "state", default=""), "unsupported_path")
  assert_eq(json_object_field(unsupported, "text"), Some(Json::null()))
}

///|
async test "compiled context boundary verifies unchanged changed and missing generated capture bytes" {
  let root = "/tmp/moondesk-work-context-" + @async.now().to_int().to_string()
  let text = "# Captured product context\n\nOriginal requirements 书\n"
  let capture = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(text)),
  )
  let path = ".moonsuite/products/moonproj/execution-context/" +
    capture +
    "/context.md"
  @moonlib/fsx.make_directory(
    @pathx.dirname(root + "/" + path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fs.write_file(root + "/" + path, text, create_mode=CreateNew)
  let workspace = @desk.workspace(
    id="actual",
    name="Book",
    root_path=root,
    kind=MoonBook,
  )
  let claims = work_handoff_test_claims()
  guard claims is Object(claim_fields) else { fail("claims") }
  claim_fields["book_root"] = root.to_json()
  for item in json_array_items(claims, "delivered_commands") {
    guard json_object_field(item, "command") is Some(Object(command)) else {
      fail("command")
    }
    command["book_root"] = root.to_json()
    if json_string(item, "command_id", default="") == "C0" {
      command["context_path"] = path.to_json()
    }
  }
  let target : MoonCodeWorkTarget = {
    session_id: "S",
    command_id: "C0",
    book_root: root,
  }
  let read : async (String) -> Result[Json, String] = endpoint => {
    if endpoint.contains("format=listing") {
      Ok({ "sessions": [{ "id": "S", "book_root": root }] })
    } else if endpoint.contains("runtime-claim") {
      Ok(claims)
    } else {
      Err("Unexpected read")
    }
  }
  let (status, response) = mooncode_resolve_work_handoff(
    root,
    [workspace],
    target,
    read,
    include_context=true,
  )
  assert_eq(status, 200)
  let context = json_object_field_or_empty(response, "context")
  assert_eq(json_string(context, "state", default=""), "ready")
  assert_eq(json_string(context, "text", default=""), text)
  let actual = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(text)),
  )
  assert_eq(json_string(context, "actual_sha256", default=""), actual)
  assert_eq(actual, capture)
  assert_eq(json_string(context, "expected_sha256", default=""), capture)
  assert_eq(json_string(context, "integrity", default=""), "verified")
  @fs.write_file(
    root + "/" + path,
    "changed requirements",
    create_mode=TruncateExisting,
  )
  let (_, changed) = mooncode_resolve_work_handoff(
    root,
    [workspace],
    target,
    read,
    include_context=true,
  )
  assert_eq(json_string(changed, "state", default=""), "ready")
  let changed_context = json_object_field_or_empty(changed, "context")
  assert_eq(json_string(changed_context, "state", default=""), "mismatch")
  assert_eq(json_string(changed_context, "integrity", default=""), "mismatch")
  assert_eq(
    json_string(changed_context, "expected_sha256", default=""),
    capture,
  )
  assert_true(
    json_string(changed_context, "actual_sha256", default="") != capture,
  )
  assert_eq(json_object_field(changed_context, "text"), Some(Json::null()))
  let missing = mooncode_work_read_context(workspace, {
    "original_command": {
      "context_path": ".moonsuite/products/moonproj/execution-context/" +
      "b".repeat(64) +
      "/context.md",
    },
  })
  assert_eq(json_string(missing, "state", default=""), "missing")
  assert_eq(json_string(missing, "expected_sha256", default=""), "b".repeat(64))
  assert_eq(json_string(missing, "integrity", default=""), "not_checked")
}

///|
async test "captured context refuses a symlink out of the verified MoonBook" {
  let root = "/tmp/moondesk-work-context-symlink-" +
    @async.now().to_int().to_string()
  let path = ".moonsuite/products/moonproj/execution-context/" +
    "c".repeat(64) +
    "/context.md"
  @moonlib/fsx.make_directory(
    @pathx.dirname(root + "/" + path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let outside = root + "-outside.md"
  @fs.write_file(outside, "outside private bytes", create_mode=CreateNew)
  @fs.symlink(root + "/" + path, target=outside)
  let workspace = @desk.workspace(
    id="actual",
    name="Book",
    root_path=root,
    kind=MoonBook,
  )
  let context = mooncode_work_read_context(workspace, {
    "original_command": { "context_path": path },
  })
  assert_eq(json_string(context, "state", default=""), "unavailable")
  assert_eq(json_object_field(context, "text"), Some(Json::null()))
}
