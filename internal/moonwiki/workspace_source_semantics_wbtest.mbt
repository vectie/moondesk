///|
test "source semantics keeps compiler diagnostics structured and confined" {
  let output = "{\"$message_type\":\"diagnostic\",\"level\":\"warning\",\"path\":\"/work/book/src/main.mbt\",\"start_line\":2,\"start_col\":3,\"message\":\"unused\"}\n" +
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
