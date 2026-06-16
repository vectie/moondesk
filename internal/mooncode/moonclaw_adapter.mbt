///|
pub fn moonclaw_adapter_contract_json() -> Json {
  {
    "kind": "mooncode-moonclaw-adapter-contract",
    "protocol": "mooncode.v1",
    "owner": "mooncode",
    "runtime_owner": "moonclaw",
    "reference": "../moonclaw",
    "daemon": {
      "legacy_task_create": "POST /v1/task",
      "legacy_task_events": "GET /v1/task/<task-id>/events",
      "legacy_task_forward": "ANY /v1/task/<task-id>/...",
      "native_target": "/v1/mooncode/capabilities plus /v1/mooncode/sessions?book_root=<path>, /v1/mooncode/sessions/<id>?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-dispatch?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-loop?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-events?book_root=<path>, /v1/mooncode/sessions/<id>/tool-exec?book_root=<path>, /v1/mooncode/sessions/<id>/commands, and /v1/mooncode/sessions/<id>/package-result",
    },
    "event_mapping": moonclaw_event_mapping_json(),
    "tool_mapping": Json::array(moonclaw_tool_mapping_rows()),
    "native_gap": "Current MoonClaw daemon routes now expose native MoonCode capabilities, cold book-local sidecar list/show, native runtime-claim receipts, native runtime-dispatch delivery receipts, native runtime-turn execution receipts for explicit, deterministic, or bounded model-planned tool calls with tool-result feedback plus planner reasoning/assistant/tool-call events, native runtime-loop queue supervision, native runtime-events evidence ingress, native read/edit/write/shell/moon_check/finish tool execution, command ingestion, session stream snapshots, native tool/file-edit eval-report evidence, prompt/steer/cancel controls, package-result acknowledgement, normalized MoonClaw task stream proof, and book-local durable MoonCode sidecars. Remaining native gap is a production-grade OpenSeek-style service for live steering, diff-aware review, long-running resume/cancel UX, and broader model-backed coding eval cases.",
    "boundary": {
      "moondesk": "records MoonCode command/session/review state and normalizes MoonClaw compatibility events",
      "moonclaw": "executes tools, streams events, enforces approvals, and reports proof",
      "mooncode": "defines the reusable protocol and adapter mapping",
    },
  }
}

///|
pub fn moonclaw_runtime_loop_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-loop",
  max_turns? : Int = 8,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
    "max_turns": max_turns,
  }
}

///|
pub fn moonclaw_runtime_turn_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-turn",
) -> Json {
  {
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
  }
}

///|
pub fn moonclaw_runtime_dispatch_mode(
  response : Json,
  accepted? : Bool = true,
) -> String {
  if !accepted {
    return "moonclaw-mooncode-runtime"
  }
  if json_string(response, "kind", default="") == "mooncode-runtime-loop" {
    "moonclaw-mooncode-runtime-loop"
  } else {
    "moonclaw-mooncode-runtime-turn"
  }
}

///|
pub fn moonclaw_native_command_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/commands"
}

///|
pub fn moonclaw_native_runtime_loop_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/runtime-loop"
}

///|
pub fn moonclaw_native_runtime_turn_endpoint(session_id : String) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/runtime-turn"
}

///|
pub fn moonclaw_native_eval_report_endpoint(
  session_id : String,
  book_root : String,
) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/eval-report?book_root=\{moonclaw_query_value(book_root)}"
}

///|
pub fn moonclaw_native_stream_endpoint(
  session_id : String,
  book_root : String,
  format : String,
  since : Int,
) -> String {
  "/v1/mooncode/sessions/\{moonclaw_query_value(session_id)}/stream?book_root=\{moonclaw_query_value(book_root)}&format=\{moonclaw_query_value(format)}&since=\{since}"
}

///|
fn moonclaw_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if moonclaw_query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      moonclaw_append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn moonclaw_query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn moonclaw_append_percent_encoded_char(
  pieces : Array[String],
  ch : Char,
) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(moonclaw_percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(moonclaw_percent_encoded_byte(0xC0 + code / 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(moonclaw_percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(moonclaw_percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(moonclaw_percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn moonclaw_percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}

///|
pub fn moonclaw_event_mapping_json() -> Json {
  {
    "AssistantMessageDelta": {
      "event": "assistant_delta",
      "lane": "transcript",
      "status": "running",
    },
    "AssistantMessage": {
      "event": "assistant_message",
      "lane": "transcript",
      "status": "done",
    },
    "PreToolCall": { "event": "tool_call", "lane": "tool", "status": "running" },
    "PostToolCall": {
      "event": "tool_result",
      "lane": "tool",
      "status": "done-or-failed",
    },
    "Cancelled": {
      "event": "agent_aborted",
      "lane": "review",
      "status": "failed",
    },
    "Failed": { "event": "agent_aborted", "lane": "review", "status": "failed" },
  }
}

///|
pub fn moonclaw_tool_mapping_rows() -> Array[Json] {
  [
    moonclaw_tool_mapping_row("read_file", "read", "native-compatible"),
    moonclaw_tool_mapping_row(
      "read_multiple_files", "read", "native-compatible",
    ),
    moonclaw_tool_mapping_row("read_resource", "read", "native-compatible"),
    moonclaw_tool_mapping_row("write_to_file", "write", "native-compatible"),
    moonclaw_tool_mapping_row("replace_in_file", "edit", "native-compatible"),
    moonclaw_tool_mapping_row("patch_edit", "edit", "native-compatible"),
    moonclaw_tool_mapping_row("apply_patch", "apply_patch", "native-compatible"),
    moonclaw_tool_mapping_row("execute_command", "shell", "native-compatible"),
    moonclaw_tool_mapping_row("list_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("glob_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("search_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("runtime_context", "read", "context-compatible"),
    moonclaw_tool_mapping_row("todo", "finish", "planning-only"),
  ]
}

///|
pub fn moonclaw_tool_to_mooncode_tool(tool_name : String) -> String {
  match tool_name {
    "read_file" | "read_multiple_files" | "read_resource" => "read"
    "write_to_file" => "write"
    "replace_in_file" | "patch_edit" => "edit"
    "apply_patch" => "apply_patch"
    "execute_command" => "shell"
    "list_files" | "glob_files" | "search_files" | "runtime_context" => "read"
    "todo" => "finish"
    _ => tool_name
  }
}

///|
pub fn moonclaw_adapter_readiness(
  daemon_running : Bool,
  native_mooncode_ready : Bool,
  legacy_task_bridge_ready : Bool,
  task_events_ready : Bool,
) -> Json {
  let missing : Array[String] = []
  if !daemon_running {
    missing.push("moonclaw-daemon")
  }
  if !native_mooncode_ready {
    missing.push("native-/v1/mooncode")
  }
  if !legacy_task_bridge_ready {
    missing.push("legacy-/v1/task bridge")
  }
  if !task_events_ready {
    missing.push("legacy task event stream")
  }
  let status = if native_mooncode_ready {
    "native-ready"
  } else if daemon_running && legacy_task_bridge_ready && task_events_ready {
    "compatibility-bridge"
  } else {
    "missing-runtime"
  }
  {
    "kind": "mooncode-moonclaw-adapter-readiness",
    "protocol": "mooncode.v1",
    "status": status,
    "daemon_running": daemon_running,
    "native_mooncode_ready": native_mooncode_ready,
    "legacy_task_bridge_ready": legacy_task_bridge_ready,
    "task_events_ready": task_events_ready,
    "missing": Json::array([ for item in missing => Json::string(item) ]),
    "contract": moonclaw_adapter_contract_json(),
  }
}

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

///|
test "mooncode moonclaw adapter maps moonclaw tools to mooncode tools" {
  assert_eq(moonclaw_tool_to_mooncode_tool("execute_command"), "shell")
  assert_eq(moonclaw_tool_to_mooncode_tool("read_file"), "read")
  assert_eq(moonclaw_tool_to_mooncode_tool("write_to_file"), "write")
  assert_eq(moonclaw_tool_to_mooncode_tool("replace_in_file"), "edit")
  assert_eq(moonclaw_tool_to_mooncode_tool("unknown_tool"), "unknown_tool")
  let contract = moonclaw_adapter_contract_json()
  assert_eq(
    moonclaw_json_string(contract, "kind", default=""),
    "mooncode-moonclaw-adapter-contract",
  )
  assert_true(contract.stringify().contains("/v1/task/<task-id>/events"))
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/runtime-events?book_root=<path>"),
  )
  assert_true(
    contract
    .stringify()
    .contains("/v1/mooncode/sessions/<id>/tool-exec?book_root=<path>"),
  )
  assert_true(
    contract.stringify().contains("read/edit/write/shell/moon_check/finish"),
  )
}

///|
test "mooncode moonclaw adapter normalizes tool events" {
  let raw : Json = {
    "id": "evt-1",
    "created": 0,
    "desc": {
      "msg": "PreToolCall",
      "tool_call": {
        "id": "call-1",
        "function": {
          "name": "execute_command",
          "arguments": "{\"command\":\"moon test\"}",
        },
        "type": "function",
      },
      "name": "execute_command",
    },
  }
  guard moonclaw_event_to_runtime_event(
      raw,
      fallback_id="fallback",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(event) else {
    fail("expected MoonClaw tool event")
  }
  assert_eq(moonclaw_json_string(event, "event", default=""), "tool_call")
  assert_eq(moonclaw_json_string(event, "tool_name", default=""), "shell")
  let tool_call = moonclaw_json_object_field_or_empty(event, "tool_call")
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  assert_eq(moonclaw_json_string(function, "name", default=""), "shell")
}

///|
test "mooncode moonclaw adapter shapes legacy status events" {
  guard moonclaw_status_event_record(
      {
        "id": "evt-model",
        "created": "2026-06-16T00:00:00Z",
        "desc": { "msg": "ModelLoaded", "name": "dev-model" },
      },
      fallback_id="fallback",
    )
    is Some(event) else {
    fail("status event was not projected")
  }
  assert_eq(json_string(event, "lane", default=""), "runtime")
  assert_eq(json_string(event, "kind", default=""), "ModelLoaded")
  assert_eq(json_string(event, "title", default=""), "Model loaded: dev-model")
  assert_eq(json_string(event, "status", default=""), "running")
  guard moonclaw_status_event_record(
      { "desc": { "msg": "Failed", "error": { "message": "tool failed" } } },
      fallback_id="fallback-failed",
    )
    is Some(failed_event) else {
    fail("failed event was not projected")
  }
  assert_eq(json_string(failed_event, "id", default=""), "fallback-failed")
  assert_eq(json_string(failed_event, "title", default=""), "MoonClaw failed")
  assert_eq(json_string(failed_event, "status", default=""), "failed")
  assert_true(
    json_string(failed_event, "detail", default="").contains("tool failed"),
  )
}

///|
test "mooncode moonclaw adapter owns native runtime request bodies" {
  let loop_request = moonclaw_runtime_loop_request(
    "session-demo",
    "/tmp/book",
    consumer_id="moondesk-ui-runtime-loop",
    max_turns=5,
  )
  assert_eq(json_string(loop_request, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(loop_request, "session_id", default=""), "session-demo")
  assert_eq(json_string(loop_request, "book_root", default=""), "/tmp/book")
  assert_eq(
    json_string(loop_request, "consumer_id", default=""),
    "moondesk-ui-runtime-loop",
  )
  assert_eq(moonclaw_json_int(loop_request, "max_turns", default=0), 5)
  let turn_request = moonclaw_runtime_turn_request(
    "session-demo",
    "/tmp/book",
    consumer_id="moondesk-ui-runtime-turn",
  )
  assert_eq(json_string(turn_request, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(turn_request, "session_id", default=""), "session-demo")
  assert_eq(json_string(turn_request, "book_root", default=""), "/tmp/book")
  assert_eq(
    json_string(turn_request, "consumer_id", default=""),
    "moondesk-ui-runtime-turn",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode({ "kind": "mooncode-runtime-loop" }),
    "moonclaw-mooncode-runtime-loop",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode({ "kind": "mooncode-runtime-turn" }),
    "moonclaw-mooncode-runtime-turn",
  )
  assert_eq(
    moonclaw_runtime_dispatch_mode(
      { "kind": "mooncode-runtime-turn" },
      accepted=false,
    ),
    "moonclaw-mooncode-runtime",
  )
  assert_eq(
    moonclaw_native_eval_report_endpoint("session one", "/tmp/moon book"),
    "/v1/mooncode/sessions/session%20one/eval-report?book_root=%2Ftmp%2Fmoon%20book",
  )
  assert_eq(
    moonclaw_native_command_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/commands",
  )
  assert_eq(
    moonclaw_native_runtime_loop_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/runtime-loop",
  )
  assert_eq(
    moonclaw_native_runtime_turn_endpoint("session one"),
    "/v1/mooncode/sessions/session%20one/runtime-turn",
  )
  assert_eq(
    moonclaw_native_stream_endpoint("session one", "/tmp/moon book", "sse", 7),
    "/v1/mooncode/sessions/session%20one/stream?book_root=%2Ftmp%2Fmoon%20book&format=sse&since=7",
  )
}

///|
test "mooncode moonclaw adapter shapes legacy transcript events" {
  guard moonclaw_event_record(
      {
        "id": "evt-user",
        "created": "2026-06-16T00:00:00Z",
        "desc": { "msg": "UserMessage", "content": "Create a MoonBook tool" },
      },
      fallback_id="fallback",
    )
    is Some(user_event) else {
    fail("user event was not projected")
  }
  assert_eq(moonclaw_json_string(user_event, "lane", default=""), "transcript")
  assert_eq(moonclaw_json_string(user_event, "kind", default=""), "user")
  guard moonclaw_event_record(
      {
        "id": "evt-request",
        "desc": {
          "msg": "RequestCompleted",
          "message": {
            "content": [
              { "text": "Implemented the tool." },
              { "text": "Tests pass." },
            ],
          },
        },
      },
      fallback_id="fallback",
    )
    is Some(request_event) else {
    fail("request-completed event was not projected")
  }
  assert_eq(
    moonclaw_json_string(request_event, "detail", default=""),
    "Implemented the tool.\nTests pass.",
  )
}

///|
test "mooncode moonclaw adapter shapes legacy tool lane events" {
  guard moonclaw_tool_event_record(
      {
        "id": "evt-diff",
        "created": "2026-06-16T00:00:00Z",
        "desc": {
          "msg": "PostToolCall",
          "name": "write_to_file",
          "result": {
            "path": "tools/demo/main.mbt",
            "diff": "\n+fn main { println(\"ok\") }",
          },
          "text": "updated tools/demo/main.mbt",
        },
      },
      fallback_id="fallback",
    )
    is Some(diff_event) else {
    fail("diff tool event was not projected")
  }
  assert_eq(json_string(diff_event, "lane", default=""), "diff")
  assert_eq(json_string(diff_event, "path", default=""), "tools/demo/main.mbt")
  assert_eq(
    json_string(diff_event, "title", default=""),
    "File changed: tools/demo/main.mbt",
  )
  guard moonclaw_tool_event_record(
      {
        "id": "evt-test",
        "desc": {
          "msg": "PostToolCall",
          "name": "execute_command",
          "tool_call": {
            "function": { "arguments": "{\"command\":\"moon test\"}" },
          },
          "result": { "status": 0, "stdout": "ok", "stderr": "" },
        },
      },
      fallback_id="fallback",
    )
    is Some(test_event) else {
    fail("test tool event was not projected")
  }
  assert_eq(json_string(test_event, "lane", default=""), "test")
  assert_eq(json_string(test_event, "command", default=""), "moon test")
  assert_eq(event_json_int(test_event, "exit_code", default=-1), 0)
}

///|
test "mooncode moonclaw adapter readiness distinguishes bridge from native" {
  let bridged = moonclaw_adapter_readiness(true, false, true, true)
  assert_eq(
    moonclaw_json_string(bridged, "status", default=""),
    "compatibility-bridge",
  )
  let native = moonclaw_adapter_readiness(true, true, true, true)
  assert_eq(moonclaw_json_string(native, "status", default=""), "native-ready")
}
