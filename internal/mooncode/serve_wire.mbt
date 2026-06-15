///|
priv enum ServeCommand {
  Prompt(String)
  Steer(String)
  Cancel
}

///|
pub fn runtime_tool_names() -> Array[String] {
  [
    "shell", "read", "edit", "write", "moon_check", "finish", "apply_patch", "package_app_tool",
  ]
}

///|
pub fn serve_command_names() -> Array[String] {
  ["prompt", "steer", "cancel"]
}

///|
pub fn tool_call_wire_contract_json() -> Json {
  {
    "kind": "mooncode-tool-call-wire-contract",
    "protocol": "mooncode.v1",
    "owner": "mooncode",
    "runtime_owner": "moonclaw",
    "reference": "../openseek/deepseek/json_decode.mbt",
    "accepted_shapes": [
      "native function tool call: {id,type,function:{name,arguments}}", "runtime event wrapper: {event:'tool_call'|'tool_started'|'tool_result',tool_call:{id,function:{name,arguments}}}",
      "flattened runtime event: {tool_call_id,tool_name,arguments}",
    ],
    "supported_tools": serve_string_array_json(runtime_tool_names()),
    "argument_rule": "function.arguments is kept as the raw JSON string and also exposed as parsed_arguments when it is valid JSON; MoonClaw owns final tool-specific validation before execution.",
    "unknown_tool_policy": "unknown tool names fail this decoder and should be emitted as tool_call_decode_error runtime events, not silently executed",
  }
}

///|
pub fn decode_tool_call(json : Json) -> Result[Json, String] {
  let payload = tool_call_payload(json)
  let tool_call_id = tool_call_id(json, payload)
  let tool_name = tool_call_name(json, payload)
  if tool_name == "" {
    return Err("expected tool_name or function.name")
  }
  if !runtime_tool_names().contains(tool_name) {
    return Err("unknown tool: \{tool_name}")
  }
  let arguments = tool_call_arguments(json, payload)
  Ok({
    "kind": "mooncode-tool-call",
    "protocol": "mooncode.v1",
    "tool_call_id": tool_call_id,
    "tool_name": tool_name,
    "arguments": arguments,
    "parsed_arguments": tool_call_arguments_json(arguments),
    "mutates_files": tool_call_mutates_files(tool_name),
    "requires_review": tool_call_requires_review(tool_name),
  })
}

///|
pub fn tool_call_wire_valid(json : Json) -> Bool {
  decode_tool_call(json) is Ok(_)
}

///|
pub fn tool_call_decode_report(json : Json) -> Json {
  match decode_tool_call(json) {
    Ok(decoded) =>
      {
        "ok": true,
        "protocol": "mooncode.v1",
        "tool_call": decoded,
        "tool_name": serve_json_string(decoded, "tool_name", default=""),
        "tool_call_id": serve_json_string(decoded, "tool_call_id", default=""),
      }
    Err(message) =>
      {
        "ok": false,
        "protocol": "mooncode.v1",
        "error": message,
        "tool_call": Json::object({}),
      }
  }
}

///|
pub fn decode_serve_command(json : Json) -> Result[Json, String] {
  match decode_serve_command_enum(json) {
    Ok(command) => Ok(serve_command_to_json(command))
    Err(message) => Err(message)
  }
}

///|
pub fn serve_wire_valid(json : Json) -> Bool {
  decode_serve_command_enum(json) is Ok(_)
}

///|
fn decode_serve_command_enum(json : Json) -> Result[ServeCommand, String] {
  match json {
    { "command": "prompt", "text": String(text), .. } => Ok(Prompt(text))
    { "command": "steer", "text": String(text), .. } => Ok(Steer(text))
    { "command": "prompt", .. } | { "command": "steer", .. } =>
      Err("expected a string \"text\" field")
    { "command": "cancel", .. } => Ok(Cancel)
    { "command": String(other), .. } => Err("unknown command: \{other}")
    _ => Err("expected a {\"command\": ...} object")
  }
}

///|
fn serve_command_to_json(command : ServeCommand) -> Json {
  match command {
    Prompt(text) => { "command": "prompt", "text": text }
    Steer(text) => { "command": "steer", "text": text }
    Cancel => { "command": "cancel" }
  }
}

///|
fn tool_call_payload(json : Json) -> Json {
  match serve_json_object_field(json, "tool_call") {
    Some(nested) =>
      match nested {
        Json::Object(_) => nested
        _ => json
      }
    _ => json
  }
}

///|
fn tool_call_id(json : Json, payload : Json) -> String {
  let direct = serve_first_string(
    json,
    ["tool_call_id", "call_id", "id"],
    default="",
  )
  if direct != "" {
    direct
  } else {
    serve_json_string(payload, "id", default="")
  }
}

///|
fn tool_call_name(json : Json, payload : Json) -> String {
  let direct = serve_first_string(json, ["tool_name", "name"], default="")
  if direct != "" {
    return direct
  }
  let function = serve_json_object_field_or_empty(payload, "function")
  serve_json_string(function, "name", default="")
}

///|
fn tool_call_arguments(json : Json, payload : Json) -> String {
  let direct = serve_first_json(json, ["arguments", "args", "input"])
  match direct {
    Some(value) => serve_json_argument_text(value)
    None => {
      let function = serve_json_object_field_or_empty(payload, "function")
      match serve_json_object_field(function, "arguments") {
        Some(value) => serve_json_argument_text(value)
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
fn tool_call_mutates_files(tool_name : String) -> Bool {
  tool_name == "edit" ||
  tool_name == "write" ||
  tool_name == "apply_patch" ||
  tool_name == "package_app_tool"
}

///|
fn tool_call_requires_review(tool_name : String) -> Bool {
  tool_call_mutates_files(tool_name) ||
  tool_name == "shell" ||
  tool_name == "finish"
}

///|
fn serve_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = serve_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn serve_first_json(json : Json, keys : Array[String]) -> Json? {
  for key in keys {
    match serve_json_object_field(json, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn serve_json_argument_text(value : Json) -> String {
  match value {
    Json::String(text) => text
    Json::Object(_) | Json::Array(_) => value.stringify()
    _ => ""
  }
}

///|
fn serve_json_object_field_or_empty(json : Json, key : String) -> Json {
  match serve_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn serve_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn serve_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn serve_json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn serve_string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => Json::string(item) ])
}

///|
test "mooncode serve wire decodes openseek commands" {
  guard decode_serve_command({ "command": "prompt", "text": "hi" })
    is Ok(prompt) else {
    fail("prompt did not decode")
  }
  guard prompt is { "command": "prompt", "text": "hi", .. } else {
    fail("prompt decoded to unexpected payload")
  }
  guard decode_serve_command({ "command": "steer", "text": "left" })
    is Ok(steer) else {
    fail("steer did not decode")
  }
  guard steer is { "command": "steer", "text": "left", .. } else {
    fail("steer decoded to unexpected payload")
  }
  guard decode_serve_command({ "command": "cancel" }) is Ok(cancel) else {
    fail("cancel did not decode")
  }
  guard cancel is { "command": "cancel", .. } else {
    fail("cancel decoded to unexpected payload")
  }
  assert_true(serve_wire_valid({ "command": "prompt", "text": "hi" }))
}

///|
test "mooncode serve wire rejects invalid commands with actionable errors" {
  guard decode_serve_command({ "command": "prompt" }) is Err(missing_text) else {
    fail("textless prompt accepted")
  }
  assert_true(missing_text.contains("text"))
  guard decode_serve_command({ "command": "reboot" }) is Err(unknown) else {
    fail("unknown command accepted")
  }
  assert_true(unknown.contains("unknown command: reboot"))
  guard decode_serve_command("nonsense") is Err(not_object) else {
    fail("non-object accepted")
  }
  assert_true(not_object.contains("command"))
  assert_false(serve_wire_valid({ "command": "steer" }))
}

///|
test "mooncode tool call wire decodes native openseek function calls" {
  guard decode_tool_call({
      "id": "call-read",
      "type": "function",
      "function": {
        "name": "read",
        "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
      },
    })
    is Ok(call) else {
    fail("native tool call did not decode")
  }
  assert_eq(serve_json_string(call, "tool_call_id", default=""), "call-read")
  assert_eq(serve_json_string(call, "tool_name", default=""), "read")
  assert_eq(
    serve_json_string(
      serve_json_object_field_or_empty(call, "parsed_arguments"),
      "path",
      default="",
    ),
    "tools/demo/main.mbt",
  )
  assert_false(serve_json_bool(call, "mutates_files", default=true))
  assert_true(
    tool_call_wire_valid({
      "id": "call-shell",
      "function": {
        "name": "shell",
        "arguments": "{\"cmd\":[\"moon\",\"test\"]}",
      },
    }),
  )
}

///|
test "mooncode tool call wire decodes runtime event wrappers" {
  guard decode_tool_call({
      "event": "tool_started",
      "tool_call": {
        "id": "call-write",
        "function": {
          "name": "write",
          "arguments": {
            "path": "tools/demo/main.mbt",
            "content": "fn main { println(1) }",
          },
        },
      },
    })
    is Ok(call) else {
    fail("wrapped tool call did not decode")
  }
  assert_eq(serve_json_string(call, "tool_call_id", default=""), "call-write")
  assert_eq(serve_json_string(call, "tool_name", default=""), "write")
  assert_true(serve_json_string(call, "arguments", default="").contains("path"))
  assert_true(serve_json_bool(call, "mutates_files", default=false))
  assert_true(serve_json_bool(call, "requires_review", default=false))
}

///|
test "mooncode tool call wire rejects unknown or malformed tools" {
  guard decode_tool_call({
      "id": "call-bad",
      "function": { "name": "delete_world", "arguments": "{}" },
    })
    is Err(unknown) else {
    fail("unknown tool accepted")
  }
  assert_true(unknown.contains("unknown tool: delete_world"))
  guard decode_tool_call({ "id": "call-empty" }) is Err(malformed) else {
    fail("tool call without name accepted")
  }
  assert_true(malformed.contains("tool_name"))
  assert_false(
    tool_call_wire_valid({
      "function": { "name": "delete_world", "arguments": "{}" },
    }),
  )
  let report = tool_call_decode_report({
    "tool_name": "moon_check",
    "arguments": { "target": "internal/mooncode" },
  })
  assert_true(serve_json_bool(report, "ok", default=false))
  assert_eq(serve_json_string(report, "tool_name", default=""), "moon_check")
}
