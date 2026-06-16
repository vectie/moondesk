///|
fn moonclaw_tool_call_with_name(tool_call : Json, tool_name : String) -> Json {
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  let next_function = moonclaw_json_with_string(function, "name", tool_name)
  moonclaw_json_with_json(tool_call, "function", next_function)
}

///|
fn moonclaw_tool_call_arguments(tool_call : Json) -> String {
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  moonclaw_json_string(function, "arguments", default="")
}

///|
fn moonclaw_tool_mapping_row(
  moonclaw_tool : String,
  mooncode_tool : String,
  compatibility : String,
) -> Json {
  {
    "moonclaw_tool": moonclaw_tool,
    "mooncode_tool": mooncode_tool,
    "compatibility": compatibility,
  }
}

///|
fn moonclaw_json_object_field_or_empty(json : Json, key : String) -> Json {
  match moonclaw_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn moonclaw_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn moonclaw_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        Some(Json::Number(value, ..)) => value.to_string()
        _ => default
      }
    _ => default
  }
}

///|
fn moonclaw_json_field_text(
  json : Json,
  key : String,
  default~ : String,
) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        Some(Json::Null) | None => default
        Some(value) => value.stringify()
      }
    _ => default
  }
}

///|
fn moonclaw_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Number(value, ..)) => value.to_int()
        Some(Json::String(value)) =>
          @string.parse_int(value) catch {
            _ => default
          }
        _ => default
      }
    _ => default
  }
}

///|
fn moonclaw_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = moonclaw_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn moonclaw_json_with_string(json : Json, key : String, value : String) -> Json {
  let object : Map[String, Json] = {}
  match json {
    Json::Object(fields) =>
      for k, v in fields {
        object[k] = v
      }
    _ => ()
  }
  object[key] = value.to_json()
  Json::object(object)
}

///|
fn moonclaw_json_with_json(json : Json, key : String, value : Json) -> Json {
  let object : Map[String, Json] = {}
  match json {
    Json::Object(fields) =>
      for k, v in fields {
        object[k] = v
      }
    _ => ()
  }
  object[key] = value
  Json::object(object)
}
