///|
// Native MoonCode per-tool policy contracts.

///|
pub fn native_command_tool_policies(
  action : String,
  context_path : String,
) -> Array[Json] {
  let policies : Array[Json] = []
  for tool in native_command_tool_sequence(action) {
    policies.push(native_command_tool_policy(tool, action, context_path))
  }
  policies
}

///|
pub fn native_command_tool_policy(
  tool : String,
  action : String,
  context_path : String,
) -> Json {
  match tool {
    "read" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=["path"],
        proof_events=["tool_call", "tool_result"],
        guardrails=[
          "resolve path relative to selected MoonBook root", "reject parent traversal and absolute paths outside the book",
          "return bounded content with path and byte metadata",
        ],
      )
    "edit" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="review",
        mutates_files=true,
        required_inputs=["path", "old", "new"],
        proof_events=["tool_call", "file_change", "diff", "tool_result"],
        guardrails=[
          "require recent bounded read context before replacing text", "reject empty old text or stale old text without applying partial edits",
          "run MoonBit manifest guardrails before editing moon.mod or moon.pkg",
          "emit diff evidence before review or packaging gates can pass",
        ],
      )
    "write" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="review",
        mutates_files=true,
        required_inputs=["path", "content"],
        proof_events=["tool_call", "file_change", "diff", "tool_result"],
        guardrails=[
          "write only inside executable MoonBook roots or reviewed wiki paths", "reject new moon.mod.json files for MoonBit code",
          "reject JSON-shaped moon.mod or moon.pkg content", "emit full-path diff evidence for operator review",
        ],
      )
    "shell" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="policy",
        mutates_files=false,
        required_inputs=["cmd"],
        proof_events=["tool_call", "tool_result", "runtime_update"],
        guardrails=[
          "accept argv arrays instead of raw shell strings", "run under selected MoonBook root or a book-relative cwd",
          "require bounded timeout and capped output", "destructive, networked, or broad workspace commands require operator policy approval",
        ],
      )
    "moon_check" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=[],
        proof_events=["tool_call", "tool_result", "test_result"],
        guardrails=[
          "prefer moon check before broad moon test while iterating", "capture command, exit code, target, and bounded diagnostics",
          "publish test_result evidence for action-plan and acceptance gates",
        ],
      )
    "package_app_tool" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="operator",
        mutates_files=true,
        required_inputs=["artifact_root"],
        proof_events=[
          "tool_call", "artifact", "package.manifest", "package.index", "package_verified",
        ],
        guardrails=[
          "package only accepted or runtime-proven code artifacts", "bind package manifest to source paths inside the selected MoonBook",
          "write package index under portable/app-tool or another MoonBook-owned output root",
        ],
      )
    "finish" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=["summary"],
        proof_events=["agent_finished"],
        guardrails=[
          "summarize changed paths, test evidence, artifacts, and residual risks",
          "do not claim accepted output without review, test, or package evidence",
        ],
      )
    _ =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="unknown",
        mutates_files=false,
        required_inputs=[],
        proof_events=["tool_result"],
        guardrails=["runtime must reject unknown tools before execution"],
      )
  }
}

///|
fn native_command_tool_policy_entry(
  tool : String,
  action : String,
  context_path : String,
  approval~ : String,
  mutates_files~ : Bool,
  required_inputs~ : Array[String],
  proof_events~ : Array[String],
  guardrails~ : Array[String],
) -> Json {
  {
    "tool": tool,
    "action": action,
    "context_path": context_path,
    "approval": approval,
    "mutates_files": mutates_files,
    "required_inputs": string_array_json(required_inputs),
    "proof_events": string_array_json(proof_events),
    "guardrails": string_array_json(guardrails),
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "ui_owner": "moondesk",
    "artifact_owner": "moonbook",
  }
}
