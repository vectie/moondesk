///|
pub fn runtime_consumer_expected_tool_sequence(
  runtime_command : Json,
) -> Array[String] {
  let summary = rq_json_object_field_or_empty(
    runtime_command, "execution_summary",
  )
  let from_summary = rq_json_string_array_items(summary, "tool_sequence")
  if from_summary.length() > 0 {
    from_summary
  } else {
    native_command_tool_sequence(
      rq_json_string(runtime_command, "action", default="prompt"),
    )
  }
}

///|
pub fn runtime_consumer_tool_outcome(
  tool : String,
  call_id? : String = "",
  arguments? : String = "",
  content? : String = "",
  path? : String = "",
  command? : String = "",
  exit_code? : Int = 0,
  is_error? : Bool = false,
) -> Json {
  {
    "tool": tool,
    "tool_call_id": if call_id == "" {
      "call-\{tool}"
    } else {
      call_id
    },
    "arguments": arguments,
    "content": content,
    "path": path,
    "command": command,
    "exit_code": exit_code,
    "is_error": is_error,
  }
}

///|
pub fn runtime_consumer_test_result_event(
  command? : String = "",
  status? : String = "done",
  exit_code? : Int = 0,
  detail? : String = "",
) -> Json {
  {
    "event": event_test_result(),
    "command": command,
    "status": status,
    "exit_code": exit_code,
    "detail": detail,
  }
}

///|
pub fn runtime_consumer_artifact_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "artifact", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_verified_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": event_package_verified(), "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_manifest_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "package_manifest", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_index_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "package_index", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_commit_created_event(
  sha : String,
  detail? : String = "",
) -> Json {
  { "event": "commit_created", "sha": sha, "detail": detail }
}

///|
pub fn runtime_consumer_package_output_ack(
  runtime_command : Json,
  source_path : String,
  output_path : String,
  manifest_path : String,
  index_path : String,
  package_kind? : String = "app-tool",
  check_command? : String = "moon check",
  test_command? : String = "moon test",
  consumer_id? : String = "mooncode-runtime",
  acknowledged_at? : String = "",
) -> Json {
  let package_args = (
    { "source": source_path, "output": output_path, "kind": package_kind } :
    Json).stringify()
  runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome(
        "read",
        call_id="call-read-package-source",
        arguments=({ "path": source_path } : Json).stringify(),
        content="source inventory recorded for \{source_path}",
        path=source_path,
      ),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-package-check",
        arguments=({ "command": check_command } : Json).stringify(),
        content="\{check_command} passed",
        command=check_command,
      ),
      runtime_consumer_tool_outcome(
        "shell",
        call_id="call-package-test",
        arguments=({ "command": test_command } : Json).stringify(),
        content="\{test_command} passed",
        command=test_command,
      ),
      runtime_consumer_tool_outcome(
        "package_app_tool",
        call_id="call-package-app-tool",
        arguments=package_args,
        content="packaged \{source_path} into \{output_path}",
        path=output_path,
      ),
      runtime_consumer_tool_outcome(
        "finish",
        content="Packaged \{package_kind} output at \{output_path}.",
      ),
    ],
    [
      {
        "event": "diff",
        "path": output_path,
        "detail": "Packaged executable MoonBook output for \{source_path}.",
      },
      runtime_consumer_test_result_event(
        command=test_command,
        exit_code=0,
        detail="\{test_command} passed",
      ),
      runtime_consumer_artifact_event(
        output_path,
        detail="Packaged \{package_kind} artifact",
      ),
      runtime_consumer_package_manifest_event(
        manifest_path,
        detail="Package manifest for \{output_path}",
      ),
      runtime_consumer_package_index_event(
        index_path,
        detail="Package index includes \{output_path}",
      ),
      runtime_consumer_package_verified_event(
        output_path,
        detail="Package verification passed",
      ),
    ],
    consumer_id~,
    acknowledged_at~,
    detail="Runtime consumer packaged executable MoonBook output with typed proof.",
  )
}

///|
pub fn runtime_consumer_completion_ack(
  runtime_command : Json,
  tool_outcomes : Array[Json],
  proof_events : Array[Json],
  consumer_id? : String = "mooncode-runtime",
  acknowledged_at? : String = "",
  status? : String = "runtime-completed",
  detail? : String = "Runtime consumer completed command with typed tool proof.",
) -> Json {
  {
    "consumer_id": consumer_id,
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "status": status,
    "detail": detail,
    "acknowledged_at": acknowledged_at,
    "events": Json::array(
      runtime_consumer_ack_events(
        runtime_command,
        tool_outcomes,
        proof_events,
        acknowledged_at~,
      ),
    ),
  }
}
