///|
pub fn runtime_event_fallback_id(event : Json) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(event.stringify()).to_fixedarray()),
  )
  "mooncode-runtime-event-" + digest[:16].to_owned()
}

///|
pub fn normalize_runtime_event_with_defaults(
  event : Json,
  fallback_created_at~ : String,
) -> Json? {
  let with_created_at = if json_string(event, "created_at", default="") == "" &&
    json_string(event, "created", default="") == "" {
    runtime_with_field(event, "created_at", fallback_created_at.to_json())
  } else {
    event
  }
  normalize_runtime_event(
    with_created_at,
    fallback_id=runtime_event_fallback_id(event),
    fallback_created_at~,
  )
}

///|
pub fn normalize_runtime_loop_response_event(
  response : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  if json_string(response, "kind", default="") != "mooncode-runtime-loop" {
    return None
  }
  let stopped_by = runtime_json_string(
    response,
    "stopped_by",
    default="unknown",
  )
  let status = match stopped_by {
    "failed" => "failed"
    "cancelled" => "cancelled"
    "max_turns" => "running"
    _ => "done"
  }
  Some(
    event_record(
      id=runtime_json_string(response, "id", default=fallback_id),
      lane="runtime",
      kind="runtime_loop",
      title="Native runtime loop: \{stopped_by}",
      status~,
      created_at=runtime_first_string(
        response,
        ["created_at", "created"],
        default=fallback_created_at,
      ),
      detail=runtime_json_string(
        response,
        "message",
        default="MoonClaw native runtime loop stopped by \{stopped_by}",
      ),
      path=runtime_json_string(response, "book_root", default=""),
      command="runtime-loop",
    ),
  )
}

///|
pub fn native_response_event_items(
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Array[Json] {
  let incoming = runtime_json_array_items(response, "events")
  let execution = runtime_json_object_field_or_empty(response, "execution")
  for event in runtime_json_array_items(execution, "events") {
    incoming.push(event)
  }
  match
    normalize_runtime_loop_response_event(
      response,
      fallback_id=loop_fallback_id,
      fallback_created_at=loop_fallback_created_at,
    ) {
    Some(event) => incoming.push(event)
    None => ()
  }
  for event in runtime_json_array_items(response, "package_events") {
    incoming.push(event)
  }
  let turn_receipt = runtime_json_object_field_or_empty(
    response, "turn_receipt",
  )
  for event in runtime_json_array_items(turn_receipt, "events") {
    incoming.push(event)
  }
  let mut turn_index = 0
  for turn in runtime_json_array_items(response, "turns") {
    for
      event in native_response_event_items(
        turn,
        loop_fallback_id=loop_fallback_id + "-turn-" + turn_index.to_string(),
        loop_fallback_created_at~,
      ) {
      incoming.push(event)
    }
    turn_index += 1
  }
  incoming
}

///|
pub fn append_native_response_events(
  session : Json,
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Json {
  let incoming = native_response_event_items(
    response,
    loop_fallback_id~,
    loop_fallback_created_at~,
  )
  if incoming.length() == 0 {
    return session
  }
  let current = runtime_json_array_items(session, "mooncode_command_events")
  let events = merge_events(current, incoming, [])
  runtime_with_field(session, "mooncode_command_events", Json::array(events))
}

///|
pub fn runtime_event_ingest_report(
  payload : Json,
  session_id~ : String,
  ingested_at~ : String,
) -> Json {
  let candidates = runtime_json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  let rejected : Array[Json] = []
  for candidate in incoming {
    match runtime_ingest_event(candidate, ingested_at) {
      Some(event) => events.push(event)
      None =>
        rejected.push({
          "reason": "unsupported-runtime-event-shape",
          "event": candidate,
        })
    }
  }
  {
    "kind": "mooncode-runtime-event-ingest-report",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "ingested_at": ingested_at,
    "submitted_count": incoming.length(),
    "accepted_count": events.length(),
    "rejected_count": rejected.length(),
    "events": Json::array(events),
    "rejected": Json::array(rejected),
    "command_progress": runtime_event_command_progress(events),
    "status": if events.length() > 0 {
      "accepted"
    } else {
      "empty"
    },
    "owner": { "runtime": "moonclaw", "protocol": "mooncode", "ui": "moondesk" },
  }
}

///|
pub fn runtime_event_sink_response(
  session_id : String,
  events : Array[Json],
  event_log_path~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-event-sink",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "event_log_path": event_log_path,
    "event_count": events.length(),
    "events": Json::array(events),
    "command_progress": runtime_event_command_progress(events),
    "post_contract": runtime_event_ingest_contract(session_id),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_event_sink_result_response(
  session_id : String,
  events : Array[Json],
  session : Json,
  event_log_path~ : String,
) -> Json {
  runtime_event_sink_response(
    session_id,
    events,
    event_log_path~,
    workspace_id=runtime_json_string(session, "workspace_id", default=""),
    workspace_name=runtime_json_string(session, "workspace_name", default=""),
    task_id=runtime_json_string(session, "moonclaw_task_id", default=""),
  )
}

///|
pub fn runtime_event_ingest_result_response(
  session_id : String,
  accepted_events : Array[Json],
  all_events : Array[Json],
  ingest_report : Json,
  final_session : Json,
  session_response : Json,
  event_log_path~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-event-ingest-result",
    "session_id": session_id,
    "accepted_event_count": accepted_events.length(),
    "ingest_report": ingest_report,
    "event_log_path": event_log_path,
    "command_progress": runtime_event_command_progress(all_events),
    "action_plan": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_action_plan_manifest",
    ),
    "change_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_change_set_manifest",
    ),
    "patch_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_patch_set_manifest",
    ),
    "tool_approvals": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_tool_approvals_manifest",
    ),
    "test_runs": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_test_runs_manifest",
    ),
    "runtime_evidence": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_evidence_manifest",
    ),
    "eval_report": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_eval_report_manifest",
    ),
    "runtime_handoff": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_handoff_manifest",
    ),
    "session": session_response,
  }
}

///|
pub fn runtime_ingest_events(
  payload : Json,
  ingested_at~ : String,
) -> Array[Json] {
  json_array_items(
    runtime_event_ingest_report(payload, session_id="", ingested_at~),
    "events",
  )
}

///|
fn runtime_ingest_event(event : Json, ingested_at : String) -> Json? {
  if json_string(event, "lane", default="") != "" &&
    json_string(event, "kind", default="") != "" {
    return Some(
      canonical_event_record(
        event,
        fallback_id=runtime_event_fallback_id(event),
        fallback_created_at=ingested_at,
      ),
    )
  }
  match
    normalize_runtime_event_with_defaults(
      event,
      fallback_created_at=ingested_at,
    ) {
    Some(normalized) => Some(normalized)
    None =>
      match
        moonclaw_event_to_runtime_event(
          event,
          fallback_id=runtime_event_fallback_id(event),
          fallback_created_at=ingested_at,
        ) {
        Some(converted) =>
          normalize_runtime_event_with_defaults(
            converted,
            fallback_created_at=ingested_at,
          )
        None => None
      }
  }
}

///|
pub fn normalize_runtime_event(
  event : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  let name = json_string(event, "event", default="")
  if name == "" {
    return None
  }
  let event_id = runtime_json_string(event, "id", default=fallback_id)
  let created_at = runtime_first_string(
    event,
    ["created_at", "created"],
    default=if event_id == "" { fallback_created_at } else { event_id },
  )
  match name {
    "agent_step" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind="agent_step",
          title="Agent step",
          status="running",
          created_at~,
          detail=event.stringify(),
        ),
      )
    "assistant_delta" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="assistant_delta",
          title="Assistant streaming",
          status="running",
          created_at~,
          detail=json_string(event, "content", default=""),
        ),
      )
    "assistant_message" =>
      Some(
        event_record(
          id=event_id,
          lane="transcript",
          kind="assistant",
          title="Assistant response",
          status="done",
          created_at~,
          detail=json_string(event, "content", default=""),
        ),
      )
    "reasoning_delta" | "reasoning_message" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind=name,
          title="Reasoning",
          status=if name == "reasoning_message" { "done" } else { "running" },
          created_at~,
          detail=json_string(event, "content", default=""),
        ),
      )
    "runtime_update" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind="runtime_update",
          title="Runtime update",
          status="running",
          created_at~,
          detail=json_string(event, "content", default=""),
        ),
      )
    "tool_call" | "tool_started" =>
      match decode_tool_call(event) {
        Ok(_) => Some(runtime_tool_call_event(event_id, created_at, event))
        Err(message) =>
          Some(
            runtime_tool_call_decode_error_event(
              event_id, created_at, event, message,
            ),
          )
      }
    "tool_result" =>
      match decode_tool_call(event) {
        Ok(_) => Some(runtime_tool_result_event(event_id, created_at, event))
        Err(message) =>
          Some(
            runtime_tool_call_decode_error_event(
              event_id, created_at, event, message,
            ),
          )
      }
    "tool_call_decode_error" =>
      Some(
        event_record(
          id=event_id,
          lane="tool",
          kind=json_string(event, "tool_name", default="tool"),
          title="Tool decode failed",
          status="failed",
          created_at~,
          detail=json_string(event, "error", default=event.stringify()),
        ),
      )
    "file_change" | "diff" =>
      Some(
        event_record(
          id=event_id,
          lane="diff",
          kind=name,
          title="File changed: \{event_label(json_string(event, "path", default=""))}",
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          path=json_string(event, "path", default=""),
          diff=json_string(event, "diff", default=""),
        ),
      )
    "patch_applied" | "patch_reverted" => {
      let command = if name == "patch_applied" {
        "apply_patch"
      } else {
        "revert_patch"
      }
      Some(
        event_record(
          id=event_id,
          lane="review",
          kind="runtime.\{name}",
          title=if name == "patch_applied" {
            "Patch applied by runtime"
          } else {
            "Patch reverted by runtime"
          },
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          path=json_string(event, "path", default=""),
          diff=json_string(event, "diff", default=""),
          command~,
          command_packet=runtime_event_command_packet(event, command),
        ),
      )
    }
    "package_built" | "package_verified" =>
      Some(
        event_record(
          id=event_id,
          lane="artifact",
          kind="runtime.\{name}",
          title=if name == "package_verified" {
            "Package verified by runtime"
          } else {
            "Package built by runtime"
          },
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          path=json_string(event, "path", default=""),
          command="package",
          command_packet=runtime_event_command_packet(event, "package"),
        ),
      )
    "package_manifest"
    | "package.manifest"
    | "package_index"
    | "package.index" => {
      let kind = match name {
        "package_manifest" | "package.manifest" => "package.manifest"
        _ => "package.index"
      }
      Some(
        event_record(
          id=event_id,
          lane="artifact",
          kind~,
          title=if kind == "package.manifest" {
            "Package manifest recorded"
          } else {
            "Package index recorded"
          },
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          path=json_string(event, "path", default=""),
          command="package",
          command_packet=runtime_event_command_packet(event, "package"),
        ),
      )
    }
    "commit_created" =>
      Some(
        event_record(
          id=event_id,
          lane="review",
          kind="runtime.commit_created",
          title="Commit created by runtime",
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(
            event,
            ["detail", "content", "sha"],
            default="",
          ),
          path=json_string(event, "path", default=""),
          command="commit",
          command_packet=runtime_event_command_packet(event, "commit"),
        ),
      )
    "test_result" =>
      Some(
        event_record(
          id=event_id,
          lane="test",
          kind="test_result",
          title=json_string(event, "title", default="Test result"),
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          command=runtime_first_string(
            event,
            ["command", "target", "tool"],
            default="",
          ),
          exit_code=runtime_json_int(
            event,
            "exit_code",
            default=runtime_json_int(event, "exit_status", default=0),
          ),
          command_packet=runtime_event_command_packet(event, "run_tests"),
        ),
      )
    "artifact" =>
      Some(
        event_record(
          id=event_id,
          lane="artifact",
          kind="artifact",
          title=json_string(event, "title", default="Artifact"),
          status=json_string(event, "status", default="done"),
          created_at~,
          detail=runtime_first_string(event, ["detail", "content"], default=""),
          path=json_string(event, "path", default=""),
        ),
      )
    "agent_finished" =>
      Some(
        event_record(
          id=event_id,
          lane="review",
          kind="finish",
          title="Agent finished",
          status="done",
          created_at~,
          detail=json_string(event, "answer", default=""),
          command_packet=runtime_event_command_packet(
            event,
            runtime_first_string(event, ["action"], default="prompt"),
          ),
        ),
      )
    "agent_aborted" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind="agent_aborted",
          title="Agent interrupted",
          status="cancelled",
          created_at~,
          detail=json_string(event, "reason", default="interrupted"),
        ),
      )
    "max_steps_exhausted" | "turn_failed" | "command_error" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind=name,
          title=runtime_event_title(name),
          status="failed",
          created_at~,
          detail=runtime_first_string(
            event,
            ["error", "content"],
            default=event.stringify(),
          ),
        ),
      )
    "steer_applied" | "steer_dropped" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind=name,
          title=runtime_event_title(name),
          status=if name == "steer_applied" { "done" } else { "failed" },
          created_at~,
          detail=json_string(event, "content", default=""),
          command_packet=runtime_event_command_packet(event, "steer"),
        ),
      )
    "usage" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind="usage",
          title="Token usage",
          status="done",
          created_at~,
          detail="prompt=\{runtime_json_int(event, "prompt_tokens", default=0)} completion=\{runtime_json_int(event, "completion_tokens", default=0)} total=\{runtime_json_int(event, "prompt_tokens", default=0) + runtime_json_int(event, "completion_tokens", default=0)}",
        ),
      )
    _ => None
  }
}

///|
pub fn canonical_event_record(
  event : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json {
  let lane = normalize_event_lane(json_string(event, "lane", default="runtime"))
  let kind = runtime_trimmed_text(
    json_string(event, "kind", default="runtime_update"),
    fallback="runtime_update",
  )
  let created_at = runtime_first_string(
    event,
    ["created_at", "created"],
    default=fallback_created_at,
  )
  let id = runtime_json_string(event, "id", default=fallback_id)
  let command = if kind == "test_result" {
    runtime_first_string(event, ["command", "target", "tool"], default="")
  } else {
    json_string(event, "command", default="")
  }
  let exit_code = runtime_json_int(
    event,
    "exit_code",
    default=runtime_json_int(event, "exit_status", default=0),
  )
  event_record(
    id~,
    lane~,
    kind~,
    title=runtime_trimmed_text(
      json_string(event, "title", default=runtime_event_title(kind)),
      fallback=runtime_event_title(kind),
    ),
    status=runtime_trimmed_text(
      json_string(event, "status", default="done"),
      fallback="done",
    ),
    created_at~,
    detail=runtime_first_string(event, ["detail", "content"], default=""),
    path=json_string(event, "path", default=""),
    diff=json_string(event, "diff", default=""),
    command~,
    exit_code~,
    command_packet=runtime_json_object_field_or_empty(event, "command_packet"),
  )
}

///|
pub fn tool_authorization_preview_event(
  payload : Json,
  created_at : String,
  fallback_id~ : String,
) -> Json {
  let base = runtime_with_field(payload, "event", "tool_call".to_json())
  let with_created_at = if json_string(base, "created_at", default="") == "" {
    runtime_with_field(base, "created_at", created_at.to_json())
  } else {
    base
  }
  let with_id = if json_string(with_created_at, "id", default="") == "" {
    runtime_with_field(with_created_at, "id", fallback_id.to_json())
  } else {
    with_created_at
  }
  match
    normalize_runtime_event(
      with_id,
      fallback_id~,
      fallback_created_at=created_at,
    ) {
    Some(event) => event
    None => {
      let tool_name = runtime_first_string(
        payload,
        ["tool_name", "name"],
        default="tool",
      )
      let path = runtime_first_string(
        payload,
        ["path", "file", "target"],
        default="",
      )
      let command = runtime_first_string(
        payload,
        ["command", "cmd"],
        default="",
      )
      let detail = runtime_first_string(
        payload,
        ["arguments", "args", "input", "detail"],
        default="",
      )
      let lane = tool_lane(tool_name, path, "", command, detail)
      event_record(
        id=json_string(with_id, "id", default=fallback_id),
        lane~,
        kind=tool_name,
        title="Tool started: \{tool_name}",
        status="running",
        created_at~,
        detail~,
        path~,
        command~,
      )
    }
  }
}

///|
pub fn normalize_event_lane(lane : String) -> String {
  match lane {
    "transcript"
    | "runtime"
    | "tool"
    | "diff"
    | "test"
    | "artifact"
    | "review" => lane
    _ => "runtime"
  }
}

///|
pub fn runtime_event_title(name : String) -> String {
  match name {
    "max_steps_exhausted" => "Max steps exhausted"
    "turn_failed" => "Turn failed"
    "command_error" => "Command error"
    "steer_applied" => "Steering applied"
    "steer_dropped" => "Steering dropped"
    _ => name
  }
}

///|
pub fn tool_lane(
  name : String,
  path : String,
  diff : String,
  command : String,
  text : String,
) -> String {
  let lower = "\{name}\n\{path}\n\{command}\n\{text}".to_lower()
  if lower.contains("portable/") ||
    lower.contains("site/generated") ||
    lower.contains("app-tool") ||
    lower.contains("package") {
    "artifact"
  } else if lower.contains("moon test") ||
    lower.contains("moon check") ||
    lower.contains("moon build") ||
    lower.contains("total tests") ||
    lower.contains("test_result") {
    "test"
  } else if diff != "" ||
    lower.contains("write") ||
    lower.contains("edit") ||
    lower.contains("apply_patch") ||
    lower.contains("meta_write_to_file") {
    "diff"
  } else {
    "tool"
  }
}

///|
pub fn event_label(value : String) -> String {
  if value == "" {
    "none"
  } else {
    value
  }
}

///|
fn runtime_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
}

///|
fn runtime_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn runtime_json_object_field_or_empty(json : Json, key : String) -> Json {
  match runtime_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn runtime_json_array_items(json : Json, key : String) -> Array[Json] {
  match runtime_json_object_field(json, key) {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn runtime_json_string_array_items(json : Json, key : String) -> Array[String] {
  match runtime_json_object_field(json, key) {
    Some(Json::Array(values)) => {
      let result : Array[String] = []
      for value in values {
        match value {
          Json::String(text) => result.push(text)
          _ => ()
        }
      }
      result
    }
    _ => []
  }
}

///|
fn runtime_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = runtime_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn runtime_json_string(json : Json, key : String, default~ : String) -> String {
  match runtime_json_object_field(json, key) {
    Some(Json::String(value)) => value
    Some(value) => value.stringify()
    None => default
  }
}

///|
fn runtime_json_int(json : Json, key : String, default~ : Int) -> Int {
  match runtime_json_object_field(json, key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(Json::String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}

///|
fn runtime_trimmed_text(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    fallback
  } else {
    trimmed
  }
}

///|
test "mooncode normalizes OpenSeek runtime events into lanes" {
  let fallback_a = runtime_event_fallback_id({
    "event": "assistant_delta",
    "content": "hello",
  })
  let fallback_b = runtime_event_fallback_id({
    "event": "assistant_delta",
    "content": "hello",
  })
  assert_eq(fallback_a, fallback_b)
  assert_true(fallback_a.has_prefix("mooncode-runtime-event-"))
  guard normalize_runtime_event_with_defaults(
      { "event": "assistant_delta", "content": "hello" },
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(defaulted_event) else {
    fail("defaulted assistant_delta was not normalized")
  }
  assert_eq(json_string(defaulted_event, "id", default=""), fallback_a)
  assert_eq(
    json_string(defaulted_event, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  guard normalize_runtime_event(
      {
        "event": "tool_call",
        "tool_call_id": "call-shell",
        "tool_name": "shell",
        "command_id": "cmd-test-call",
        "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"],\"cwd\":\"tools/demo\"}",
      },
      fallback_id="runtime-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(tool_call_event) else {
    fail("tool_call was not normalized")
  }
  assert_eq(json_string(tool_call_event, "lane", default=""), "test")
  assert_eq(json_string(tool_call_event, "kind", default=""), "shell")
  assert_eq(
    json_string(tool_call_event, "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(tool_call_event, "status", default=""), "running")
  let tool_call_packet = runtime_json_object_field_or_empty(
    tool_call_event, "command_packet",
  )
  assert_eq(
    json_string(tool_call_packet, "command_id", default=""),
    "cmd-test-call",
  )
  assert_eq(json_string(tool_call_packet, "action", default=""), "run_tests")
  guard normalize_runtime_event(
      {
        "event": "tool_result",
        "tool_call_id": "call-check",
        "tool_name": "moon_check",
        "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"],\"cwd\":\"tools/demo\"}",
        "command_id": "cmd-test-1",
        "content": "Total tests: 3, passed: 3",
        "is_error": false,
      },
      fallback_id="runtime-2",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(test_event) else {
    fail("tool_result was not normalized")
  }
  assert_eq(json_string(test_event, "lane", default=""), "test")
  assert_eq(json_string(test_event, "status", default=""), "done")
  assert_eq(
    json_string(test_event, "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(test_event, "path", default=""), "")
  assert_eq(json_string(test_event, "tool_call_id", default=""), "call-check")
  let test_packet = runtime_json_object_field_or_empty(
    test_event, "command_packet",
  )
  assert_eq(json_string(test_packet, "command_id", default=""), "cmd-test-1")
  assert_eq(json_string(test_packet, "action", default=""), "run_tests")
  guard normalize_runtime_event(
      { "event": "agent_finished", "answer": "done" },
      fallback_id="runtime-3",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(review_event) else {
    fail("agent_finished was not normalized")
  }
  assert_eq(json_string(review_event, "lane", default=""), "review")
  assert_eq(json_string(review_event, "kind", default=""), "finish")
  guard normalize_runtime_event(
      { "event": "steer_applied", "content": "focus the tests" },
      fallback_id="runtime-4",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(steer_applied_event) else {
    fail("steer_applied was not normalized")
  }
  assert_eq(json_string(steer_applied_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(steer_applied_event, "kind", default=""),
    "steer_applied",
  )
  assert_eq(json_string(steer_applied_event, "status", default=""), "done")
  assert_eq(
    json_string(steer_applied_event, "detail", default=""),
    "focus the tests",
  )
  guard normalize_runtime_event(
      { "event": "steer_dropped", "content": "too late" },
      fallback_id="runtime-5",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(steer_dropped_event) else {
    fail("steer_dropped was not normalized")
  }
  assert_eq(
    json_string(steer_dropped_event, "kind", default=""),
    "steer_dropped",
  )
  assert_eq(json_string(steer_dropped_event, "status", default=""), "failed")
}

///|
test "mooncode runtime event ingest report accepts canonical and openseek events" {
  let report = runtime_event_ingest_report(
    {
      "events": [
        {
          "lane": "diff",
          "kind": "write",
          "path": "tools/demo/main.mbt",
          "detail": "changed",
        },
        {
          "event": "tool_result",
          "tool_name": "moon_check",
          "content": "moon check passed",
          "command_id": "cmd-tests",
          "action": "run_tests",
        },
        { "event": "unknown_runtime_event" },
      ],
    },
    session_id="agent-demo",
    ingested_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  assert_eq(runtime_json_int(report, "submitted_count", default=0), 3)
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 2)
  assert_eq(runtime_json_int(report, "rejected_count", default=0), 1)
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "lane", default=""), "diff")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(events[1], "lane", default=""), "test")
  assert_eq(
    json_string(events[1], "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  let progress = runtime_json_object_field_or_empty(report, "command_progress")
  assert_eq(
    json_string(progress, "kind", default=""),
    "mooncode-runtime-event-command-progress",
  )
}

///|
test "mooncode runtime event ingest accepts moonclaw run_tests proof events" {
  let events = runtime_ingest_events(
    {
      "events": [
        {
          "protocol": "mooncode.v1",
          "session_id": "session-tests",
          "command_id": "cmd-tests",
          "command_packet": { "command_id": "cmd-tests", "action": "run_tests" },
          "lane": "test",
          "kind": "test_result",
          "event": "test_result",
          "title": "MoonCode tests failed",
          "status": "failed",
          "test_status": "failed",
          "detail": "moon check failed with status 7",
          "content": "failure output",
          "output": "failure output",
          "tool": "moon_check",
          "target": "cmd/daemon",
          "exit_status": 7,
          "created_at": "2026-06-15T00:00:00Z",
          "source": "moonclaw-native-runtime-turn",
        },
      ],
    },
    ingested_at="2026-06-15T00:00:01Z",
  )
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "test_result")
  assert_eq(json_string(events[0], "status", default=""), "failed")
  assert_eq(json_string(events[0], "command", default=""), "cmd/daemon")
  assert_eq(runtime_json_int(events[0], "exit_code", default=0), 7)
  let packet = runtime_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(packet, "action", default=""), "run_tests")
}

///|
test "mooncode runtime event ingest accepts moonclaw tool events" {
  let report = runtime_event_ingest_report(
    {
      "id": "evt-moonclaw-tool",
      "created": 0,
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "id": "call-1",
          "function": {
            "name": "execute_command",
            "arguments": "{\"command\":\"moon test\"}",
          },
          "type": "function",
        },
        "name": "execute_command",
        "result": { "ok": true },
        "text": "Total tests: 1, passed: 1",
      },
    },
    session_id="s1",
    ingested_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  let events = runtime_json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_true(
    json_string(events[0], "detail", default="").contains("Total tests"),
  )
}

///|
test "mooncode normalizes nested tool results for approval correlation" {
  guard normalize_runtime_event(
      {
        "event": "tool_result",
        "tool_call": {
          "id": "call-write-result",
          "function": {
            "name": "write",
            "arguments": "{\"path\":\"tools/demo/main.mbt\",\"content\":\"fn main { println(1) }\"}",
          },
        },
        "command_id": "cmd-prompt-1",
        "content": "wrote tools/demo/main.mbt",
        "diff": "--- /dev/null\n+++ b/tools/demo/main.mbt\n@@\n+fn main { println(1) }\n",
      },
      fallback_id="runtime-write-result",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(result) else {
    fail("nested tool_result was not normalized")
  }
  assert_eq(json_string(result, "lane", default=""), "diff")
  assert_eq(json_string(result, "kind", default=""), "write")
  assert_eq(json_string(result, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(result, "diff", default="").contains(
      "+++ b/tools/demo/main.mbt",
    ),
  )
  assert_eq(
    json_string(result, "tool_call_id", default=""),
    "call-write-result",
  )
  let packet = runtime_json_object_field_or_empty(result, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-prompt-1")
  assert_eq(json_string(packet, "action", default=""), "prompt")
}

///|
test "mooncode normalizes mutating native tool calls into diff review" {
  guard normalize_runtime_event(
      {
        "event": "tool_started",
        "tool_call": {
          "id": "call-write",
          "function": {
            "name": "write",
            "arguments": "{\"path\":\"tools/demo/main.mbt\",\"content\":\"fn main { println(1) }\"}",
          },
        },
      },
      fallback_id="runtime-6",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(tool_call_event) else {
    fail("tool_started was not normalized")
  }
  assert_eq(json_string(tool_call_event, "lane", default=""), "diff")
  assert_eq(json_string(tool_call_event, "kind", default=""), "write")
  assert_eq(
    json_string(tool_call_event, "path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(
    json_string(tool_call_event, "tool_call_id", default=""),
    "call-write",
  )
}

///|
test "mooncode rejects unknown runtime tool calls during normalization" {
  guard normalize_runtime_event(
      {
        "event": "tool_call",
        "tool_call_id": "call-danger",
        "tool_name": "delete_everything",
        "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
        "command_id": "cmd-danger",
      },
      fallback_id="runtime-danger",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(rejected) else {
    fail("unknown tool call was not converted to a decode error")
  }
  assert_eq(json_string(rejected, "lane", default=""), "tool")
  assert_eq(json_string(rejected, "kind", default=""), "tool_call_decode_error")
  assert_eq(json_string(rejected, "status", default=""), "failed")
  assert_eq(json_string(rejected, "tool_call_id", default=""), "call-danger")
  assert_eq(json_string(rejected, "tool_name", default=""), "delete_everything")
  assert_true(
    json_string(rejected, "detail", default="").contains(
      "unknown tool: delete_everything",
    ),
  )
  let report = runtime_json_object_field_or_empty(rejected, "decode_report")
  assert_eq(json_bool(report, "ok", default=true), false)
  assert_true(
    json_string(report, "error", default="").contains(
      "unknown tool: delete_everything",
    ),
  )
  let packet = runtime_json_object_field_or_empty(rejected, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-danger")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(rejected, "source_event", default=""), "tool_call")
}

///|
test "mooncode normalizes native runtime loop responses" {
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "protocol": "mooncode.v1",
        "session_id": "agent-demo",
        "book_root": "/tmp/demo-book",
        "consumer_id": "moonclaw-native-runtime-loop",
        "ran_turn_count": 0,
        "failed_turn_count": 0,
        "stopped_by": "idle",
        "message": "MoonClaw native runtime loop found no claimable MoonCode commands.",
      },
      fallback_id="loop-idle",
      fallback_created_at="2026-06-16T00:00:00Z",
    )
    is Some(idle_event) else {
    fail("idle runtime loop was not normalized")
  }
  assert_eq(json_string(idle_event, "id", default=""), "loop-idle")
  assert_eq(json_string(idle_event, "lane", default=""), "runtime")
  assert_eq(json_string(idle_event, "kind", default=""), "runtime_loop")
  assert_eq(json_string(idle_event, "status", default=""), "done")
  assert_eq(
    json_string(idle_event, "created_at", default=""),
    "2026-06-16T00:00:00Z",
  )
  assert_eq(json_string(idle_event, "path", default=""), "/tmp/demo-book")
  assert_eq(json_string(idle_event, "command", default=""), "runtime-loop")
  assert_true(
    json_string(idle_event, "detail", default="").contains("no claimable"),
  )
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "stopped_by": "failed",
        "message": "failed",
      },
      fallback_id="loop-failed",
      fallback_created_at="2026-06-16T00:00:01Z",
    )
    is Some(failed_event) else {
    fail("failed runtime loop was not normalized")
  }
  assert_eq(json_string(failed_event, "status", default=""), "failed")
  guard normalize_runtime_loop_response_event(
      {
        "kind": "mooncode-runtime-loop",
        "stopped_by": "cancelled",
        "message": "cancelled",
      },
      fallback_id="loop-cancelled",
      fallback_created_at="2026-06-16T00:00:02Z",
    )
    is Some(cancelled_event) else {
    fail("cancelled runtime loop was not normalized")
  }
  assert_eq(json_string(cancelled_event, "status", default=""), "cancelled")
  guard normalize_runtime_loop_response_event(
      { "kind": "mooncode-runtime-turn" },
      fallback_id="turn",
      fallback_created_at="2026-06-16T00:00:03Z",
    )
    is None else {
    fail("runtime turn response normalized as a loop")
  }
}

///|
test "mooncode extracts native response events from loop payloads" {
  let event = event_record(
    id="native-event",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="running",
    created_at="1",
    detail="native",
  )
  let execution_event = event_record(
    id="execution-event",
    lane="tool",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="execution",
  )
  let package_event = event_record(
    id="package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let receipt_event = event_record(
    id="receipt-event",
    lane="runtime",
    kind="runtime_acknowledged",
    title="Runtime acknowledged",
    status="done",
    created_at="4",
    detail="receipt",
  )
  let nested_event = event_record(
    id="nested-event",
    lane="review",
    kind="finish",
    title="Finished",
    status="done",
    created_at="5",
    detail="nested",
  )
  let events = native_response_event_items(
    {
      "kind": "mooncode-runtime-loop",
      "protocol": "mooncode.v1",
      "session_id": "agent-demo",
      "book_root": "/tmp/demo-book",
      "stopped_by": "idle",
      "message": "MoonClaw native runtime loop reached idle.",
      "events": [event],
      "execution": { "events": [execution_event] },
      "package_events": [package_event],
      "turn_receipt": { "events": [receipt_event] },
      "turns": [{ "events": [nested_event] }],
    },
    loop_fallback_id="loop-event",
    loop_fallback_created_at="2026-06-16T00:00:00Z",
  )
  assert_eq(events.length(), 6)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "execution-event")
  assert_eq(json_string(events[2], "id", default=""), "loop-event")
  assert_eq(json_string(events[2], "kind", default=""), "runtime_loop")
  assert_eq(json_string(events[3], "id", default=""), "package-event")
  assert_eq(json_string(events[4], "id", default=""), "receipt-event")
  assert_eq(json_string(events[5], "id", default=""), "nested-event")
}

///|
test "mooncode appends native response events with durable id dedupe" {
  let existing_event = event_record(
    id="native-event",
    lane="runtime",
    kind="tool_call",
    title="Tool call",
    status="running",
    created_at="1",
    detail="existing",
  )
  let new_event = event_record(
    id="execution-event",
    lane="runtime",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="execution",
  )
  let package_event = event_record(
    id="package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let session = append_native_response_events(
    { "mooncode_command_events": [existing_event] },
    {
      "kind": "mooncode-runtime-loop",
      "protocol": "mooncode.v1",
      "session_id": "agent-demo",
      "stopped_by": "idle",
      "events": [existing_event],
      "execution": { "events": [new_event] },
      "package_events": [package_event],
    },
    loop_fallback_id="loop-event",
    loop_fallback_created_at="2026-06-16T00:00:00Z",
  )
  let events = runtime_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 4)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "execution-event")
  assert_eq(json_string(events[2], "id", default=""), "loop-event")
  assert_eq(json_string(events[3], "id", default=""), "package-event")
}

///|
test "mooncode normalizes runtime patch execution proof events" {
  guard normalize_runtime_event(
      {
        "event": "patch_applied",
        "path": "tools/demo/main.mbt#hunk-1",
        "detail": "applied cleanly",
      },
      fallback_id="patch-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(applied) else {
    fail("patch_applied was not normalized")
  }
  assert_eq(json_string(applied, "lane", default=""), "review")
  assert_eq(json_string(applied, "kind", default=""), "runtime.patch_applied")
  assert_eq(json_string(applied, "command", default=""), "apply_patch")
  assert_eq(
    json_string(applied, "path", default=""),
    "tools/demo/main.mbt#hunk-1",
  )
  guard normalize_runtime_event(
      { "event": "patch_reverted", "path": "tools/demo/main.mbt" },
      fallback_id="patch-proof-2",
      fallback_created_at="2026-06-15T00:00:01Z",
    )
    is Some(reverted) else {
    fail("patch_reverted was not normalized")
  }
  assert_eq(json_string(reverted, "kind", default=""), "runtime.patch_reverted")
  assert_eq(json_string(reverted, "command", default=""), "revert_patch")
}

///|
test "mooncode normalizes runtime package proof events" {
  guard normalize_runtime_event(
      {
        "event": "package_verified",
        "command_id": "cmd-package-1",
        "path": "portable/app-tool/mooncode/s1/index.json",
        "detail": "bundle verified",
      },
      fallback_id="package-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(proof) else {
    fail("package_verified was not normalized")
  }
  assert_eq(json_string(proof, "lane", default=""), "artifact")
  assert_eq(json_string(proof, "kind", default=""), "runtime.package_verified")
  assert_eq(json_string(proof, "command", default=""), "package")
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-package-1")
  assert_eq(json_string(packet, "action", default=""), "package")
  assert_eq(
    json_string(proof, "path", default=""),
    "portable/app-tool/mooncode/s1/index.json",
  )
}

///|
test "mooncode normalizes runtime commit proof events" {
  guard normalize_runtime_event(
      {
        "event": "commit_created",
        "command_id": "cmd-commit-1",
        "sha": "abc1234",
        "detail": "Committed reviewed MoonBook changes",
      },
      fallback_id="commit-proof-1",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(proof) else {
    fail("commit_created was not normalized")
  }
  assert_eq(json_string(proof, "lane", default=""), "review")
  assert_eq(json_string(proof, "kind", default=""), "runtime.commit_created")
  assert_eq(json_string(proof, "command", default=""), "commit")
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-commit-1")
  assert_eq(json_string(packet, "action", default=""), "commit")
  assert_true(json_string(proof, "detail", default="").contains("Committed"))
}

///|
test "mooncode tool authorization preview normalizes shell payloads" {
  let preview = tool_authorization_preview_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"],\"cwd\":\"apps/demo\"}",
    },
    "2026-06-15T00:00:00Z",
    fallback_id="preview-1",
  )
  assert_eq(json_string(preview, "id", default=""), "preview-1")
  assert_eq(
    json_string(preview, "created_at", default=""),
    "2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(preview, "lane", default=""), "tool")
  assert_eq(json_string(preview, "kind", default=""), "shell")
  assert_eq(json_string(preview, "command", default=""), "npm run build")
  assert_eq(json_string(preview, "tool_call_id", default=""), "call-build")
}

///|
test "mooncode tool authorization preview preserves explicit read path" {
  let preview = tool_authorization_preview_event(
    {
      "id": "read-preview",
      "created_at": "2026-06-15T00:01:00Z",
      "tool_name": "read",
      "path": "wiki/index.md",
    },
    "2026-06-15T00:00:00Z",
    fallback_id="fallback-preview",
  )
  assert_eq(json_string(preview, "id", default=""), "read-preview")
  assert_eq(
    json_string(preview, "created_at", default=""),
    "2026-06-15T00:01:00Z",
  )
  assert_eq(json_string(preview, "lane", default=""), "tool")
  assert_eq(json_string(preview, "kind", default=""), "read")
  assert_eq(json_string(preview, "path", default=""), "wiki/index.md")
}

///|
test "mooncode canonical event record clamps lanes and titles" {
  let event = canonical_event_record(
    {
      "id": "event-1",
      "lane": "unknown",
      "kind": "",
      "status": "",
      "content": "hello",
    },
    fallback_id="fallback-1",
    fallback_created_at="2026-06-15T00:00:00Z",
  )
  assert_eq(json_string(event, "id", default=""), "event-1")
  assert_eq(json_string(event, "lane", default=""), "runtime")
  assert_eq(json_string(event, "kind", default=""), "runtime_update")
  assert_eq(json_string(event, "status", default=""), "done")
  assert_eq(json_string(event, "detail", default=""), "hello")
}

///|
test "mooncode runtime event command progress groups scoped events" {
  let packet : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let progress = runtime_event_command_progress([
    event_record(
      id="unscoped",
      lane="runtime",
      kind="runtime_update",
      title="Unscoped",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="visible but not command proof",
    ),
    event_record(
      id="tool-start",
      lane="test",
      kind="moon_check",
      title="Tool started",
      status="running",
      created_at="2026-06-15T00:00:01Z",
      detail="moon check",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
    event_record(
      id="tool-result",
      lane="test",
      kind="moon_check",
      title="Tool finished",
      status="done",
      created_at="2026-06-15T00:00:02Z",
      detail="ok",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="Agent finished",
      status="done",
      created_at="2026-06-15T00:00:03Z",
      detail="done",
      command_packet=packet,
    ),
  ])
  assert_eq(
    json_string(progress, "kind", default=""),
    "mooncode-runtime-event-command-progress",
  )
  assert_eq(runtime_json_int(progress, "command_count", default=0), 1)
  assert_eq(runtime_json_int(progress, "scoped_event_count", default=0), 3)
  assert_eq(runtime_json_int(progress, "running_command_count", default=0), 1)
  let commands = runtime_json_array_items(progress, "commands")
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "command_id", default=""), "cmd-tests")
  assert_eq(json_string(commands[0], "action", default=""), "run_tests")
  assert_eq(json_string(commands[0], "status", default=""), "running")
  assert_eq(runtime_json_int(commands[0], "event_count", default=0), 3)
  assert_eq(runtime_json_int(commands[0], "tool_call_count", default=0), 1)
  assert_eq(runtime_json_int(commands[0], "tool_result_count", default=0), 1)
  assert_eq(json_string(commands[0], "latest_event_id", default=""), "finish")
  assert_true(
    runtime_json_string_array_items(commands[0], "lanes").contains("test"),
  )
  assert_true(
    runtime_json_string_array_items(commands[0], "lanes").contains("review"),
  )
}

///|
test "mooncode runtime event sink response owns event surface" {
  let packet : Json = { "command_id": "cmd-1", "action": "prompt" }
  let event = event_record(
    id="event-1",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="done",
    created_at="2026-06-15T00:00:00Z",
    detail="ready",
    command_packet=packet,
  )
  let response = runtime_event_sink_response(
    "session-demo",
    [event],
    event_log_path="/tmp/session/events.jsonl",
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
  )
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-runtime-event-sink",
  )
  assert_eq(runtime_json_int(response, "event_count", default=0), 1)
  assert_eq(
    json_string(response, "event_log_path", default=""),
    "/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "post_contract"),
      "endpoint",
      default="",
    ),
    "/api/mooncode/sessions/session-demo/runtime-events",
  )
  assert_true(
    runtime_json_object_field(response, "runtime_protocol")
    is Some(Json::Object(_)),
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "owner"),
      "runtime",
      default="",
    ),
    "moonclaw",
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "command_count",
      default=0,
    ),
    1,
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "scoped_event_count",
      default=0,
    ),
    1,
  )
  let aggregate = runtime_event_sink_result_response(
    "session-demo",
    [event],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "moonclaw_task_id": "task-demo",
    },
    event_log_path="/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(aggregate, "kind", default=""),
    "mooncode-runtime-event-sink",
  )
  assert_eq(json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(aggregate, "workspace_name", default=""), "Demo")
  assert_eq(json_string(aggregate, "task_id", default=""), "task-demo")
}

///|
test "mooncode runtime event ingest result response owns manifest surface" {
  let packet : Json = { "command_id": "cmd-1", "action": "run_tests" }
  let event = event_record(
    id="event-1",
    lane="test",
    kind="test_result",
    title="Tests passed",
    status="done",
    created_at="2026-06-15T00:00:00Z",
    detail="Total tests: 1, passed: 1",
    command="moon test",
    command_packet=packet,
  )
  let ingest_report : Json = {
    "kind": "mooncode-runtime-event-ingest-report",
    "accepted_count": 1,
  }
  let final_session : Json = {
    "mooncode_last_action_plan_manifest": { "kind": "mooncode-action-plan" },
    "mooncode_last_change_set_manifest": { "kind": "mooncode-change-set" },
    "mooncode_last_patch_set_manifest": { "kind": "mooncode-patch-set" },
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
    },
    "mooncode_last_test_runs_manifest": { "kind": "mooncode-test-runs" },
    "mooncode_last_runtime_evidence_manifest": {
      "kind": "mooncode-runtime-evidence",
    },
    "mooncode_last_eval_report_manifest": { "kind": "mooncode-eval-report" },
    "mooncode_last_runtime_handoff_manifest": {
      "kind": "mooncode-runtime-handoff",
    },
  }
  let response = runtime_event_ingest_result_response(
    "session-demo",
    [event],
    [event],
    ingest_report,
    final_session,
    { "id": "session-demo", "kind": "mooncode-session" },
    event_log_path="/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-runtime-event-ingest-result",
  )
  assert_eq(runtime_json_int(response, "accepted_event_count", default=0), 1)
  assert_eq(
    json_string(response, "event_log_path", default=""),
    "/tmp/session/events.jsonl",
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "action_plan"),
      "kind",
      default="",
    ),
    "mooncode-action-plan",
  )
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(response, "command_progress"),
      "command_count",
      default=0,
    ),
    1,
  )
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(response, "session"),
      "id",
      default="",
    ),
    "session-demo",
  )
}
