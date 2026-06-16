///|
fn moonclaw_tool_event(
  event_name~ : String,
  event_id~ : String,
  created_at~ : String,
  desc~ : Json,
  failed~ : Bool,
) -> Json {
  let tool_call = moonclaw_json_object_field_or_empty(desc, "tool_call")
  let raw_name = moonclaw_json_string(desc, "name", default="")
  let tool_name = moonclaw_tool_to_mooncode_tool(raw_name)
  let normalized_tool_call = moonclaw_tool_call_with_name(tool_call, tool_name)
  let detail = moonclaw_json_string(
    desc,
    "text",
    default=if failed { "MoonClaw tool failed." } else { "" },
  )
  {
    "event": event_name,
    "id": event_id,
    "created_at": created_at,
    "tool_name": tool_name,
    "moonclaw_tool_name": raw_name,
    "tool_call_id": moonclaw_json_string(tool_call, "id", default=""),
    "tool_call": normalized_tool_call,
    "arguments": moonclaw_tool_call_arguments(tool_call),
    "content": detail,
    "error": moonclaw_json_object_field_or_empty(desc, "error").stringify(),
    "status": if failed {
      "failed"
    } else {
      "done"
    },
  }
}

///|
fn moonclaw_tool_name(desc : Json) -> String {
  let direct = moonclaw_json_string(desc, "name", default="")
  if direct != "" {
    return direct
  }
  let tool_call = moonclaw_json_object_field_or_empty(desc, "tool_call")
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  moonclaw_json_string(function, "name", default="tool")
}

///|
fn moonclaw_tool_arguments_from_desc(desc : Json) -> String {
  let tool_call = moonclaw_json_object_field_or_empty(desc, "tool_call")
  moonclaw_tool_call_arguments(tool_call)
}

///|
fn moonclaw_tool_result_object(desc : Json) -> Json {
  match moonclaw_json_object_field_or_empty(desc, "result") {
    Json::Object(_) as object => object
    Json::Array(items) =>
      if items.length() > 1 {
        items[1]
      } else {
        Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn moonclaw_tool_path(desc : Json) -> String {
  let result = moonclaw_tool_result_object(desc)
  let path = moonclaw_first_string(
    result,
    ["path", "file", "target"],
    default="",
  )
  if path != "" {
    return path
  }
  let args = @json.parse(moonclaw_tool_arguments_from_desc(desc)) catch {
    _ => Json::object({})
  }
  moonclaw_first_string(args, ["path", "file", "target"], default="")
}

///|
fn moonclaw_tool_diff(desc : Json) -> String {
  let result = moonclaw_tool_result_object(desc)
  let diff = moonclaw_json_string(result, "diff", default="")
  if diff != "" {
    diff
  } else {
    let text = moonclaw_tool_text(desc)
    if text.contains("\n+") || text.contains("\n-") {
      text
    } else {
      ""
    }
  }
}

///|
fn moonclaw_tool_command(desc : Json) -> String {
  let result = moonclaw_tool_result_object(desc)
  let command = moonclaw_json_string(result, "command", default="")
  if command != "" {
    return command
  }
  let args = @json.parse(moonclaw_tool_arguments_from_desc(desc)) catch {
    _ => Json::object({})
  }
  moonclaw_first_string(args, ["command", "cmd"], default="")
}

///|
fn moonclaw_tool_exit_code(desc : Json) -> Int {
  moonclaw_json_int(moonclaw_tool_result_object(desc), "status", default=0)
}

///|
fn moonclaw_tool_text(desc : Json) -> String {
  let text = moonclaw_json_string(
    desc,
    "text",
    default=moonclaw_json_string(desc, "rendered", default=""),
  )
  if text != "" {
    return text
  }
  let result = moonclaw_tool_result_object(desc)
  let stdout = moonclaw_json_string(result, "stdout", default="")
  let stderr = moonclaw_json_string(result, "stderr", default="")
  [stdout, stderr].join("\n")
}
