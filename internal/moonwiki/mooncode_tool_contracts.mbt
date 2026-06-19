///|
test "mooncode tool contract covers MoonCode-style builtins" {
  let contract = @mooncode.tool_contract_json()
  assert_eq(json_string(contract, "kind", default=""), "mooncode-tool-contract")
  assert_eq(json_string(contract, "owner", default=""), "moonclaw")
  let ids = @mooncode.tool_contract_tool_ids(contract)
  for required in @mooncode.runtime_tool_names() {
    assert_true(ids.contains(required))
  }
  assert_eq(json_string(contract, "execution_owner", default=""), "moonclaw")
  let constraints = json_object_field_or_empty(contract, "constraints")
  assert_true(
    json_string(constraints, "path_rule", default="").contains(
      "validates paths",
    ),
  )
}

///|
test "mooncode mutating tools require diff-producing review" {
  let contract = @mooncode.tool_contract_json()
  for tool in json_array_items(contract, "tools") {
    if json_bool(tool, "mutates_files", default=false) {
      assert_true(json_bool(tool, "requires_review", default=false))
      assert_true(
        json_string_array_items(tool, "output_events").contains("diff"),
      )
    }
  }
}
