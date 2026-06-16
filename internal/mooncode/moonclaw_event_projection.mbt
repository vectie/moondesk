///|
// MoonClaw task and tool events projected into MoonCode runtime events.

///|
pub fn moonclaw_event_to_runtime_event(
  event : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  let desc = moonclaw_json_object_field_or_empty(event, "desc")
  let msg = moonclaw_json_string(desc, "msg", default="")
  if msg == "" {
    return None
  }
  let event_id = moonclaw_json_string(event, "id", default=fallback_id)
  let created_at = moonclaw_first_string(
    event,
    ["created_at", "created"],
    default=fallback_created_at,
  )
  match msg {
    "AssistantMessageDelta" =>
      Some({
        "event": "assistant_delta",
        "id": event_id,
        "created_at": created_at,
        "content": moonclaw_json_string(desc, "content", default=""),
      })
    "AssistantMessage" =>
      Some({
        "event": "assistant_message",
        "id": event_id,
        "created_at": created_at,
        "content": moonclaw_json_string(desc, "content", default=""),
      })
    "PreToolCall" =>
      Some(
        moonclaw_tool_event(
          event_name="tool_call",
          event_id~,
          created_at~,
          desc~,
          failed=false,
        ),
      )
    "PostToolCall" =>
      Some(
        moonclaw_tool_event(
          event_name="tool_result",
          event_id~,
          created_at~,
          desc~,
          failed=moonclaw_json_object_field(desc, "error") is Some(_),
        ),
      )
    "Cancelled" =>
      Some({
        "event": "agent_aborted",
        "id": event_id,
        "created_at": created_at,
        "reason": "MoonClaw task cancelled.",
      })
    "Failed" =>
      Some({
        "event": "agent_aborted",
        "id": event_id,
        "created_at": created_at,
        "reason": moonclaw_json_object_field_or_empty(desc, "error").stringify(),
      })
    _ => None
  }
}

///|
pub fn moonclaw_status_event_record(
  event : Json,
  fallback_id~ : String,
) -> Json? {
  let desc = moonclaw_json_object_field_or_empty(event, "desc")
  let msg = moonclaw_json_string(desc, "msg", default="")
  let event_id = moonclaw_json_field_text(event, "id", default=fallback_id)
  let created_at = moonclaw_json_field_text(event, "created", default=event_id)
  match msg {
    "MessageQueued"
    | "MessageUnqueued"
    | "PreConversation"
    | "PostConversation"
    | "ModelLoaded"
    | "TokenCounted"
    | "ContextPruned"
    | "Failed"
    | "Cancelled" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind=msg,
          title=moonclaw_status_event_title(msg, desc),
          status=moonclaw_status_event_status(msg),
          created_at~,
          detail=if msg == "Failed" {
            moonclaw_json_field_text(desc, "error", default="")
          } else {
            desc.stringify()
          },
        ),
      )
    _ => None
  }
}

///|
pub fn moonclaw_event_record(event : Json, fallback_id~ : String) -> Json? {
  let desc = moonclaw_json_object_field_or_empty(event, "desc")
  let msg = moonclaw_json_string(desc, "msg", default="")
  let event_id = moonclaw_json_field_text(event, "id", default=fallback_id)
  let created_at = moonclaw_json_field_text(event, "created", default=event_id)
  match msg {
    "UserMessage" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="user",
          title="User prompt",
          status="done",
          created_at~,
          detail=moonclaw_json_string(desc, "content", default=""),
        ),
      )
    "AssistantMessageDelta" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="assistant_delta",
          title="Assistant response",
          status="running",
          created_at~,
          detail=moonclaw_json_string(desc, "content", default=""),
        ),
      )
    "AssistantMessage" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="assistant",
          title="Assistant response",
          status="done",
          created_at~,
          detail=moonclaw_json_string(desc, "content", default=""),
        ),
      )
    "RequestCompleted" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="assistant",
          title="Assistant response",
          status="done",
          created_at~,
          detail=match moonclaw_json_object_field(desc, "message") {
            Some(message) => moonclaw_openai_message_content_text(message)
            None => ""
          },
        ),
      )
    "PreToolCall" | "PostToolCall" =>
      moonclaw_tool_event_record(event, fallback_id=event_id)
    "MessageQueued"
    | "MessageUnqueued"
    | "PreConversation"
    | "PostConversation"
    | "ModelLoaded"
    | "TokenCounted"
    | "ContextPruned"
    | "Failed"
    | "Cancelled" => moonclaw_status_event_record(event, fallback_id=event_id)
    _ => None
  }
}

///|
pub fn moonclaw_tool_event_record(event : Json, fallback_id~ : String) -> Json? {
  let desc = moonclaw_json_object_field_or_empty(event, "desc")
  let msg = moonclaw_json_string(desc, "msg", default="")
  let event_id = moonclaw_json_field_text(event, "id", default=fallback_id)
  let created_at = moonclaw_json_field_text(event, "created", default=event_id)
  match msg {
    "PreToolCall" => {
      let name = moonclaw_tool_name(desc)
      Some(
        event_record(
          id=event_id,
          lane="tool",
          kind="tool_call",
          title="Tool started: \{name}",
          status="running",
          created_at~,
          detail=moonclaw_tool_arguments_from_desc(desc),
          command=moonclaw_tool_command(desc),
          path=moonclaw_tool_path(desc),
        ),
      )
    }
    "PostToolCall" => {
      let name = moonclaw_tool_name(desc)
      let path = moonclaw_tool_path(desc)
      let diff = moonclaw_tool_diff(desc)
      let command = moonclaw_tool_command(desc)
      let exit_code = moonclaw_tool_exit_code(desc)
      let text = moonclaw_tool_text(desc)
      let status = if moonclaw_json_object_field(desc, "error") is Some(_) ||
        exit_code > 0 {
        "failed"
      } else {
        "done"
      }
      let lane = tool_lane(name, path, diff, command, text)
      let title = match lane {
        "diff" => "File changed: \{event_label(path)}"
        "test" => "Test/build command: \{event_label(command)}"
        "artifact" => "Artifact packaged: \{event_label(path)}"
        _ => "Tool finished: \{name}"
      }
      Some(
        event_record(
          id=event_id,
          lane~,
          kind=name,
          title~,
          status~,
          created_at~,
          detail=text,
          path~,
          diff~,
          command~,
          exit_code~,
        ),
      )
    }
    _ => None
  }
}

///|
fn moonclaw_status_event_status(msg : String) -> String {
  match msg {
    "Failed" => "failed"
    "Cancelled" => "cancelled"
    "PostConversation" => "done"
    _ => "running"
  }
}

///|
fn moonclaw_status_event_title(msg : String, desc : Json) -> String {
  match msg {
    "ModelLoaded" =>
      "Model loaded: \{moonclaw_json_string(desc, "name", default="default")}"
    "TokenCounted" =>
      "Context measured: \{moonclaw_json_int(desc, "token_count", default=0)} tokens"
    "ContextPruned" => "Context pruned"
    "Failed" => "MoonClaw failed"
    "Cancelled" => "MoonClaw cancelled"
    "PostConversation" => "Conversation finished"
    "MessageQueued" => "Message queued"
    "MessageUnqueued" => "Message started"
    _ => "Runtime: \{msg}"
  }
}

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

///|
fn moonclaw_openai_message_content_text(message : Json) -> String {
  match moonclaw_json_object_field(message, "content") {
    Some(Json::String(content)) => content
    Some(Json::Array(parts)) => {
      let chunks : Array[String] = []
      for part in parts {
        match part {
          Json::String(text) => chunks.push(text)
          Json::Object(fields) =>
            match fields.get("text") {
              Some(Json::String(text)) => chunks.push(text)
              _ => ()
            }
          _ => ()
        }
      }
      chunks.join("\n")
    }
    Some(value) => value.stringify()
    None => ""
  }
}

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
