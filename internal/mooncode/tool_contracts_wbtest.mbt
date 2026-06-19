///|
test "mooncode tool contract covers mooncode builtins" {
  let contract = tool_contract_json()
  assert_eq(json_string(contract, "kind", default=""), "mooncode-tool-contract")
  assert_eq(json_string(contract, "owner", default=""), "moonclaw")
  let ids = tool_contract_tool_ids(contract)
  for required in runtime_tool_names() {
    assert_true(ids.contains(required))
  }
  assert_true(ids.contains("moon_ide"))
  assert_true(ids.contains("moon_cmd"))
  assert_eq(json_string(contract, "execution_owner", default=""), "moonclaw")
  let constraints = match contract {
    Object(object) => object.get("constraints").unwrap_or({})
    _ => {}
  }
  assert_true(
    json_string(constraints, "path_rule", default="").contains(
      "validates paths",
    ),
  )
}

///|
test "mooncode tool contract distinguishes moon ide and moon command safety" {
  let contract = tool_contract_json()
  let mut found_ide = false
  let mut found_cmd = false
  for tool in json_array_items(contract, "tools") {
    match json_string(tool, "id", default="") {
      "moon_ide" => {
        found_ide = true
        assert_eq(json_string(tool, "approval", default=""), "auto")
        assert_false(json_bool(tool, "mutates_files", default=true))
        assert_false(json_bool(tool, "requires_review", default=true))
        assert_true(
          json_string(tool, "safety_policy", default="").contains("read-only"),
        )
      }
      "moon_cmd" => {
        found_cmd = true
        assert_eq(json_string(tool, "approval", default=""), "policy")
        assert_true(json_bool(tool, "mutates_files", default=false))
        assert_true(json_bool(tool, "requires_review", default=false))
        assert_true(
          json_string(tool, "safety_policy", default="").contains(
            "test --update",
          ),
        )
      }
      _ => ()
    }
  }
  assert_true(found_ide)
  assert_true(found_cmd)
}

///|
test "mooncode tool contract marks mutating tools for diff review" {
  let contract = tool_contract_json()
  for tool in json_array_items(contract, "tools") {
    if json_bool(tool, "mutates_files", default=false) {
      assert_true(json_bool(tool, "requires_review", default=false))
      let outputs = [
        for event in json_array_items(tool, "output_events") => {
          json_string({ "value": event }, "value", default="")
        }
      ]
      assert_true(outputs.contains("diff"))
    }
  }
}
