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
