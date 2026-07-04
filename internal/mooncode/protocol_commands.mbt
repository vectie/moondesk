///|
priv enum CodeCommand {
  Prompt(String)
  Steer(String)
  Cancel
}

///|
pub fn runtime_tool_names() -> Array[String] {
  @mooncode_core.runtime_tool_names()
}

///|
pub fn runtime_tool_alias_rows() -> Array[Json] {
  @mooncode_core.runtime_tool_alias_rows()
}

///|
pub fn code_command_names() -> Array[String] {
  @mooncode_core.command_turn_actions()
}

///|
pub fn tool_call_contract_json() -> Json {
  @mooncode_core.runtime_tool_call_contract_json()
}

///|
pub fn decode_tool_call(json : Json) -> Result[Json, String] {
  let payload = tool_call_payload(json)
  let tool_call_id = tool_call_id(json, payload)
  let raw_tool_name = tool_call_name(json, payload)
  let tool_name = @mooncode_core.runtime_tool_canonical_name(raw_tool_name)
  if tool_name == "" {
    return Err("expected tool_name or function.name")
  }
  if !@mooncode_core.runtime_tool_is_supported(tool_name) {
    return Err("unknown tool: \{tool_name}")
  }
  let arguments = tool_call_arguments(json, payload)
  Ok({
    "kind": kind_tool_call(),
    "protocol": protocol_version(),
    "tool_call_id": tool_call_id,
    "tool_name": tool_name,
    "raw_tool_name": raw_tool_name,
    "arguments": arguments,
    "parsed_arguments": tool_call_arguments_json(arguments),
    "mutates_files": @mooncode_core.runtime_tool_mutates_files(tool_name),
    "requires_review": @mooncode_core.runtime_tool_requires_review(tool_name),
  })
}

///|
pub fn tool_call_contract_valid(json : Json) -> Bool {
  decode_tool_call(json) is Ok(_)
}

///|
pub fn tool_call_decode_report(json : Json) -> Json {
  match decode_tool_call(json) {
    Ok(decoded) =>
      {
        "ok": true,
        "protocol": protocol_version(),
        "tool_call": decoded,
        "tool_name": protocol_json_string(decoded, "tool_name", default=""),
        "raw_tool_name": protocol_json_string(
          decoded,
          "raw_tool_name",
          default="",
        ),
        "tool_call_id": protocol_json_string(
          decoded,
          "tool_call_id",
          default="",
        ),
      }
    Err(message) =>
      {
        "ok": false,
        "protocol": protocol_version(),
        "error": message,
        "tool_call": Json::object({}),
      }
  }
}

///|
pub fn decode_code_command(json : Json) -> Result[Json, String] {
  match decode_code_command_enum(json) {
    Ok(command) => Ok(code_command_to_json(command))
    Err(message) => Err(message)
  }
}

///|
pub fn protocol_command_valid(json : Json) -> Bool {
  decode_code_command_enum(json) is Ok(_)
}

///|
fn decode_code_command_enum(json : Json) -> Result[CodeCommand, String] {
  match json {
    { "command": String(command), "text": String(text), .. } =>
      if command == command_prompt() {
        Ok(Prompt(text))
      } else if command == command_steer() {
        Ok(Steer(text))
      } else if command == command_cancel() {
        Ok(Cancel)
      } else {
        Err("unknown command: \{command}")
      }
    { "command": String(command), .. } =>
      if command == command_prompt() || command == command_steer() {
        Err("expected a string \"text\" field")
      } else if command == command_cancel() {
        Ok(Cancel)
      } else {
        Err("unknown command: \{command}")
      }
    _ => Err("expected a {\"command\": ...} object")
  }
}

///|
fn code_command_to_json(command : CodeCommand) -> Json {
  match command {
    Prompt(text) => { "command": command_prompt(), "text": text }
    Steer(text) => { "command": command_steer(), "text": text }
    Cancel => { "command": command_cancel() }
  }
}

///|
fn tool_call_payload(json : Json) -> Json {
  match protocol_json_object_field(json, "tool_call") {
    Some(nested) =>
      match nested {
        Object(_) => nested
        _ => json
      }
    _ => json
  }
}

///|
fn tool_call_id(json : Json, payload : Json) -> String {
  let direct = protocol_first_string(
    json,
    ["tool_call_id", "call_id", "id"],
    default="",
  )
  if direct != "" {
    direct
  } else {
    protocol_json_string(payload, "id", default="")
  }
}

///|
fn tool_call_name(json : Json, payload : Json) -> String {
  let direct = protocol_first_string(json, ["tool_name", "name"], default="")
  if direct != "" {
    return direct
  }
  let function = protocol_json_object_field_or_empty(payload, "function")
  protocol_json_string(function, "name", default="")
}

///|
fn tool_call_arguments(json : Json, payload : Json) -> String {
  let direct = protocol_first_json(json, ["arguments", "args", "input"])
  match direct {
    Some(value) => protocol_json_argument_text(value)
    None => {
      let function = protocol_json_object_field_or_empty(payload, "function")
      match protocol_json_object_field(function, "arguments") {
        Some(value) => protocol_json_argument_text(value)
        None => ""
      }
    }
  }
}

///|
fn tool_call_arguments_json(arguments : String) -> Json {
  @json.parse(arguments) catch {
    _ => Json::object({})
  }
}

///|
fn protocol_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = protocol_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn protocol_first_json(json : Json, keys : Array[String]) -> Json? {
  for key in keys {
    match protocol_json_object_field(json, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn protocol_json_argument_text(value : Json) -> String {
  match value {
    String(text) => text
    Object(_) | Array(_) => value.stringify()
    _ => ""
  }
}

///|
fn protocol_json_object_field_or_empty(json : Json, key : String) -> Json {
  match protocol_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn protocol_json_object_field(json : Json, key : String) -> Json? {
  @mooncore.json_object_field(json, key)
}

///|
fn protocol_json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}
