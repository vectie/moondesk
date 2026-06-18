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
          title=if name == event_package_verified() {
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
          kind=event_test_result(),
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
    "steer_applied" | "steer_dropped" | "steer_deferred" =>
      Some(
        event_record(
          id=event_id,
          lane="runtime",
          kind=name,
          title=runtime_event_title(name),
          status=if name == "steer_applied" {
            "done"
          } else if name == "steer_deferred" {
            "queued"
          } else {
            "failed"
          },
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
