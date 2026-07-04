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
  @mooncode_core.runtime_tool_moonclaw_mapping_rows()
}

///|
pub fn moonclaw_tool_to_mooncode_tool(tool_name : String) -> String {
  @mooncode_core.runtime_tool_from_moonclaw_tool(tool_name)
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
