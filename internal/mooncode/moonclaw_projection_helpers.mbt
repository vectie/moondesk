///|
fn moonclaw_tool_mapping_row(
  moonclaw_tool : String,
  mooncode_tool : String,
  mapping_status : String,
) -> Json {
  {
    "moonclaw_tool": moonclaw_tool,
    "mooncode_tool": mooncode_tool,
    "mapping_status": mapping_status,
  }
}

///|
fn moonclaw_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(String(value)) => value
        Some(Number(value, ..)) => value.to_string()
        _ => default
      }
    _ => default
  }
}

///|
fn moonclaw_missing_strings(
  required : Array[String],
  available : Array[String],
) -> Array[String] {
  let missing : Array[String] = []
  for item in required {
    if !runtime_string_array_contains(available, item) {
      missing.push(item)
    }
  }
  missing
}

///|
