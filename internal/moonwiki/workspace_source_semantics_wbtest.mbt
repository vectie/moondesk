///|
test "source semantics keeps compiler diagnostics structured and confined" {
  let output = "{\"$message_type\":\"diagnostic\",\"level\":\"warning\",\"path\":\"/work/book/src/main.mbt\",\"start_line\":2,\"start_col\":3,\"message\":\"unused\"}\n" +
    "{\"$message_type\":\"diagnostic\",\"path\":\"/private/tmp/sandbox/workspace/secret.mbt\",\"message\":\"must not leak\"}\n" +
    "{\"$message_type\":\"summary\",\"diagnostics\":1}\nnot-json"
  let diagnostics = source_semantics_diagnostics(output, "/work/book")
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    json_string(diagnostics[0], "$message_type", default=""),
    "diagnostic",
  )
  assert_eq(
    json_string(diagnostics[0], "relative_path", default=""),
    "src/main.mbt",
  )
  assert_eq(
    json_string(diagnostics[0], "path", default=""),
    "/work/book/src/main.mbt",
  )
}

///|
test "source semantics builds compiler IDE commands from server paths" {
  assert_eq(
    source_semantics_ide_args("definition", "Widget", "src/main.mbt", 8, 13),
    Ok(["ide", "peek-def", "Widget", "--loc", "src/main.mbt:8:13"]),
  )
  assert_eq(
    source_semantics_ide_args("references", "Widget", "src/main.mbt", 8, 13),
    Ok(["ide", "find-references", "Widget", "--loc", "src/main.mbt:8:13"]),
  )
  assert_true(
    source_semantics_ide_args("definition", " ", "src/main.mbt", 1, 1) is Err(_),
  )
  assert_true(
    source_semantics_ide_args("rename", "Widget", "src/main.mbt", 1, 1)
    is Err(_),
  )
}

///|
test "source semantics normalizes workspace paths in navigation output" {
  assert_eq(
    source_semantics_normalize_output(
      "/work/book/src/main.mbt:2:3\n/work/book/src/lib.mbt:4:5\n", "/work/book",
    ),
    "src/main.mbt:2:3\nsrc/lib.mbt:4:5\n",
  )
  assert_eq(
    source_semantics_module_path("/work/book", "/work/book/src/main.mbt"),
    Some("src/main.mbt"),
  )
  assert_true(
    source_semantics_module_path("/work/book", "/work/other/main.mbt") is None,
  )
  assert_eq(
    source_semantics_module_prefix("/work/book", "/work/book/packages/app"),
    Some("packages/app/"),
  )
  assert_eq(
    source_semantics_module_prefix("/work/book", "/work/book"),
    Some(""),
  )
}

///|
async test "source semantics refuses host fallback before package pre-build can execute" {
  @moonlib/fsx.with_temporary_directory(
    "moondesk-source-semantics-sandbox-wbtest-",
    root => {
      let marker = @pathx.join(root, "host-prebuild-marker")
      @fsx.write_to_file(
        @pathx.join(root, "moon.mod"),
        "name = \"sandbox/refusal\"\npreferred_target = \"native\"\n",
        create=0o600,
      )
      @fsx.write_to_file(
        @pathx.join(root, "moon.pkg"),
        "options(\n  \"pre-build\": [{ \"command\": \"touch " +
        marker +
        "\", \"input\": [], \"output\": \"generated.mbt\" }],\n)\n",
        create=0o600,
      )
      @fsx.write_to_file(
        @pathx.join(root, "main.mbt"),
        "fn value() -> Int { 1 }\n",
        create=0o600,
      )
      let workspace = @desk.workspace(
        id="sandbox-refusal",
        name="Sandbox Refusal",
        root_path=root,
        kind=MoonBook,
      )
      let result = source_semantics_result(workspace, {
        "action": "diagnostics",
        "path": "main.mbt",
      })
      guard result is Err(SandboxUnavailable) else {
        fail(
          "source semantics must refuse when the sandbox adapter is unavailable",
        )
      }
      assert_eq(
        source_semantics_sandbox_error_message(SandboxUnavailable),
        "Source semantics sandbox is unavailable; host execution was refused",
      )
      assert_false(@fsx.exists(marker))
      assert_false(@fsx.exists(@pathx.join(root, "generated.mbt")))
    },
  )
}
