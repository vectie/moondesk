///|
pub fn tool_contract_json() -> Json {
  @mooncode_core.runtime_tool_contract_json()
}

///|
pub fn tool_contract_tool_ids(contract : Json) -> Array[String] {
  @mooncode_core.runtime_tool_contract_tool_ids(contract)
}
