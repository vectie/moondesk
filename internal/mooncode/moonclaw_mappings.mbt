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
    "PreToolCall": {
      "event": event_tool_call(),
      "lane": "tool",
      "status": "running",
    },
    "PostToolCall": {
      "event": event_tool_result(),
      "lane": "tool",
      "status": "done-or-failed",
    },
    "Cancelled": {
      "event": "runtime_aborted",
      "lane": "review",
      "status": "failed",
    },
    "Failed": {
      "event": "runtime_aborted",
      "lane": "review",
      "status": "failed",
    },
  }
}

///|
pub fn moonclaw_tool_mapping_rows() -> Array[Json] {
  [
    moonclaw_tool_mapping_row("read_file", "read", "native"),
    moonclaw_tool_mapping_row("read_multiple_files", "read", "native"),
    moonclaw_tool_mapping_row("read_resource", "read", "native"),
    moonclaw_tool_mapping_row("write_to_file", "write", "native"),
    moonclaw_tool_mapping_row("replace_in_file", "edit", "native"),
    moonclaw_tool_mapping_row("patch_edit", "edit", "native"),
    moonclaw_tool_mapping_row("apply_patch", "apply_patch", "native"),
    moonclaw_tool_mapping_row("execute_command", "shell", "native"),
    moonclaw_tool_mapping_row("list_files", "read", "discovery"),
    moonclaw_tool_mapping_row("glob_files", "read", "discovery"),
    moonclaw_tool_mapping_row("search_files", "read", "discovery"),
    moonclaw_tool_mapping_row("runtime_context", "read", "context"),
    moonclaw_tool_mapping_row("todo", "finish", "planning-only"),
    moonclaw_tool_mapping_row("Bash", "shell", "package-style"),
    moonclaw_tool_mapping_row("FileRead", "read", "package-style"),
    moonclaw_tool_mapping_row("Read", "read", "package-style"),
    moonclaw_tool_mapping_row("FileEdit", "edit", "package-style"),
    moonclaw_tool_mapping_row("Edit", "edit", "package-style"),
    moonclaw_tool_mapping_row("NotebookEdit", "edit", "package-style"),
    moonclaw_tool_mapping_row("FileWrite", "write", "package-style"),
    moonclaw_tool_mapping_row("Write", "write", "package-style"),
    moonclaw_tool_mapping_row("Glob", "glob", "package-style"),
    moonclaw_tool_mapping_row("Grep", "grep", "package-style"),
    moonclaw_tool_mapping_row("TodoWrite", "todo_write", "package-style"),
    moonclaw_tool_mapping_row("WebFetch", "web_fetch", "package-style"),
    moonclaw_tool_mapping_row("WebSearch", "web_search", "package-style"),
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
    "Bash" => "shell"
    "FileRead" | "Read" => "read"
    "FileEdit" | "Edit" | "NotebookEdit" => "edit"
    "FileWrite" | "Write" => "write"
    "Glob" => "glob"
    "Grep" => "grep"
    "TodoWrite" => "todo_write"
    "WebFetch" => "web_fetch"
    "WebSearch" => "web_search"
    _ => tool_name
  }
}

///|
pub fn moonclaw_runtime_readiness(
  daemon_running : Bool,
  native_mooncode_ready : Bool,
) -> Json {
  let missing : Array[String] = []
  if !daemon_running {
    missing.push("moonclaw-daemon")
  }
  if !native_mooncode_ready {
    missing.push("native-/v1/code")
  }
  let status = if native_mooncode_ready {
    "native-ready"
  } else {
    "missing-runtime"
  }
  {
    "kind": "mooncode-moonclaw-runtime-readiness",
    "protocol": protocol_version(),
    "status": status,
    "daemon_running": daemon_running,
    "native_mooncode_ready": native_mooncode_ready,
    "missing": Json::array([ for item in missing => Json::string(item) ]),
    "contract": moonclaw_runtime_contract_json(),
  }
}
