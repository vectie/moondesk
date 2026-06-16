///|
test "mooncode tool contract covers openseek builtins" {
  let contract = tool_contract_json()
  assert_eq(json_string(contract, "kind", default=""), "mooncode-tool-contract")
  assert_eq(json_string(contract, "owner", default=""), "moonclaw")
  let ids = tool_contract_tool_ids(contract)
  for required in runtime_tool_names() {
    assert_true(ids.contains(required))
  }
  assert_true(
    json_string(contract, "execution_owner", default="").contains("mooncode"),
  )
  let constraints = match contract {
    Json::Object(object) => object.get("constraints").unwrap_or({})
    _ => {}
  }
  assert_true(
    json_string(constraints, "path_rule", default="").contains(
      "validates paths",
    ),
  )
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
