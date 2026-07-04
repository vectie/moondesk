///|
fn runtime_tool_call_event(
  id : String,
  created_at : String,
  event : Json,
) -> Json {
  let name = runtime_tool_event_name(event)
  let detail = runtime_tool_event_arguments(event)
  let path = runtime_tool_event_path(event)
  let command = runtime_tool_event_command(event)
  let lane = tool_lane(name, path, "", command, detail)
  let status = json_string(event, "status", default="running")
  runtime_with_field(
    runtime_with_field(
      event_record(
        id~,
        lane~,
        kind=name,
        title="Tool started: \{name}",
        status~,
        created_at~,
        detail~,
        path~,
        command~,
        command_packet=runtime_event_command_packet(
          event,
          runtime_tool_event_action(event, lane),
        ),
      ),
      "tool_call_id",
      runtime_tool_event_call_id(event).to_json(),
    ),
    "arguments",
    detail.to_json(),
  )
}

///|
fn runtime_tool_event_action(event : Json, lane : String) -> String {
  let action = runtime_first_string(event, ["action"], default="")
  if action != "" {
    return action
  }
  match lane {
    "test" => "run_tests"
    "artifact" => "package"
    _ => "prompt"
  }
}

///|
fn runtime_tool_result_event(
  id : String,
  created_at : String,
  event : Json,
) -> Json {
  let name = runtime_tool_event_name(event)
  let content = json_string(event, "content", default="")
  let path = runtime_tool_event_path(event)
  let diff = json_string(event, "diff", default="")
  let command = runtime_tool_event_command(event)
  let arguments = runtime_tool_event_arguments(event)
  let lane = tool_lane(name, path, diff, command, content)
  let status = if json_bool(event, "is_error", default=false) {
    "failed"
  } else {
    "done"
  }
  runtime_with_field(
    runtime_with_field(
      event_record(
        id~,
        lane~,
        kind=name,
        title=match lane {
          "diff" => "File changed"
          "test" => "Test/build command"
          "artifact" => "Artifact packaged"
          _ => "Tool finished: \{name}"
        },
        status~,
        created_at~,
        detail=content,
        path~,
        diff~,
        command~,
        command_packet=runtime_event_command_packet(
          event,
          runtime_tool_event_action(event, lane),
        ),
      ),
      "tool_call_id",
      runtime_tool_event_call_id(event).to_json(),
    ),
    "arguments",
    arguments.to_json(),
  )
}

///|
fn runtime_tool_call_decode_error_event(
  id : String,
  created_at : String,
  event : Json,
  message : String,
) -> Json {
  let tool_name = runtime_tool_event_name(event)
  let tool_call_id = runtime_tool_event_call_id(event)
  let action = runtime_tool_event_action(event, "tool")
  runtime_with_field(
    runtime_with_field(
      runtime_with_field(
        runtime_with_field(
          runtime_with_field(
            event_record(
              id~,
              lane="tool",
              kind=event_tool_call_decode_error(),
              title="Tool decode failed",
              status="failed",
              created_at~,
              detail=message,
              command_packet=runtime_event_command_packet(event, action),
            ),
            "command",
            action.to_json(),
          ),
          "source_event",
          json_string(event, "event", default="").to_json(),
        ),
        "tool_name",
        tool_name.to_json(),
      ),
      "tool_call_id",
      tool_call_id.to_json(),
    ),
    "decode_report",
    tool_call_decode_report(event),
  )
}

///|
fn runtime_event_command_packet(event : Json, action : String) -> Json {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  if json_string(packet, "command_id", default="") != "" {
    return packet
  }
  let command_id = runtime_first_string(
    event,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
  if command_id == "" {
    Json::object({})
  } else {
    {
      "protocol": protocol_version(),
      "kind": kind_command_ref(),
      "command_id": command_id,
      "action": action,
      "control": command_control(action),
      "runtime_proof": true,
      "session_id": json_string(event, "session_id", default=""),
      "runtime_session_id": json_string(event, "runtime_session_id", default=""),
      "run_id": runtime_first_string(
        event,
        ["run_id", "runId", "runtime_run_id", "service_id"],
        default="",
      ),
      "client_turn_id": runtime_first_string(
        event,
        ["client_turn_id", "clientTurnId"],
        default="",
      ),
      "target_command_id": json_string(event, "target_command_id", default=""),
      "applied_to_command_id": json_string(
        event,
        "applied_to_command_id",
        default="",
      ),
    }
  }
}

///|
fn runtime_tool_event_call_id(event : Json) -> String {
  match decode_tool_call(event) {
    Ok(decoded) => return json_string(decoded, "tool_call_id", default="")
    Err(_) => ()
  }
  let direct = runtime_first_string(
    event,
    ["tool_call_id", "call_id"],
    default="",
  )
  if direct != "" {
    return direct
  }
  let tool_call = runtime_json_object_field_or_empty(event, "tool_call")
  json_string(tool_call, "id", default="")
}

///|
fn runtime_tool_event_name(event : Json) -> String {
  match decode_tool_call(event) {
    Ok(decoded) => return json_string(decoded, "tool_name", default="tool")
    Err(_) => ()
  }
  let direct = runtime_first_string(event, ["tool_name", "name"], default="")
  if direct != "" {
    return direct
  }
  let tool_call = runtime_json_object_field_or_empty(event, "tool_call")
  let function = runtime_json_object_field_or_empty(tool_call, "function")
  json_string(function, "name", default="tool")
}

///|
fn runtime_tool_event_arguments(event : Json) -> String {
  match decode_tool_call(event) {
    Ok(decoded) => return json_string(decoded, "arguments", default="")
    Err(_) => ()
  }
  let direct = runtime_first_string(
    event,
    ["arguments", "args", "input"],
    default="",
  )
  if direct != "" {
    return direct
  }
  let tool_call = runtime_json_object_field_or_empty(event, "tool_call")
  let function = runtime_json_object_field_or_empty(tool_call, "function")
  json_string(function, "arguments", default="")
}

///|
fn runtime_tool_event_args_json(event : Json) -> Json {
  match decode_tool_call(event) {
    Ok(decoded) =>
      return runtime_json_object_field_or_empty(decoded, "parsed_arguments")
    Err(_) => ()
  }
  let text = runtime_tool_event_arguments(event)
  @json.parse(text) catch {
    _ => Json::object({})
  }
}

///|
fn runtime_tool_event_path(event : Json) -> String {
  let direct = runtime_first_string(
    event,
    ["path", "file", "target"],
    default="",
  )
  if direct != "" {
    return direct
  }
  let args = runtime_tool_event_args_json(event)
  runtime_first_string(
    args,
    ["path", "file_path", "notebook_path", "file", "target"],
    default="",
  )
}

///|
fn runtime_tool_event_command(event : Json) -> String {
  let direct = runtime_first_string(event, ["command", "cmd"], default="")
  if direct != "" {
    return direct
  }
  let args = runtime_tool_event_args_json(event)
  match runtime_json_object_field(args, "cmd") {
    Some(Array(parts)) => {
      let values : Array[String] = []
      for part in parts {
        match part {
          String(text) => values.push(text)
          _ => ()
        }
      }
      values.join(" ")
    }
    _ => runtime_first_string(args, ["command", "cmd"], default="")
  }
}
