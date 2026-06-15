///|
pub fn tool_contract_json() -> Json {
  {
    "kind": "mooncode-tool-contract",
    "protocol": "mooncode.v1",
    "version": 1,
    "owner": "moonclaw",
    "execution_owner": "moonclaw-or-standalone-mooncode",
    "approval_owner": "moondesk",
    "artifact_owner": "moonbook",
    "supported_tools": string_array_json(runtime_tool_names()),
    "tools": Json::array([
      tool_contract_entry(
        id="read",
        lane="tool",
        approval="auto",
        mutates_files=false,
        requires_review=false,
        input_fields=[
          tool_field(
            "path",
            "string",
            required=true,
            "Book-relative file path to read.",
          ),
          tool_field(
            "max_bytes",
            "integer",
            required=false,
            "Optional byte cap for bounded reads.",
          ),
        ],
        output_events=["tool_result"],
        safety_policy="Only read files inside the selected MoonBook workspace; never traverse outside the book root.",
      ),
      tool_contract_entry(
        id="edit",
        lane="diff",
        approval="review",
        mutates_files=true,
        requires_review=true,
        input_fields=[
          tool_field(
            "path",
            "string",
            required=true,
            "Book-relative file path to edit.",
          ),
          tool_field("old", "string", required=true, "Exact text to replace."),
          tool_field("new", "string", required=true, "Replacement text."),
        ],
        output_events=["file_change", "diff", "tool_result"],
        safety_policy="Emit a diff event for every edit and keep operator review state separate from execution.",
      ),
      tool_contract_entry(
        id="write",
        lane="diff",
        approval="review",
        mutates_files=true,
        requires_review=true,
        input_fields=[
          tool_field(
            "path",
            "string",
            required=true,
            "Book-relative file path to create or replace.",
          ),
          tool_field(
            "content",
            "string",
            required=true,
            "Complete UTF-8 file content.",
          ),
        ],
        output_events=["file_change", "diff", "tool_result"],
        safety_policy="Write only within allowed executable MoonBook roots such as tools, apps, portable/app-tool, site/generated, or reviewed wiki paths.",
      ),
      tool_contract_entry(
        id="apply_patch",
        lane="diff",
        approval="review",
        mutates_files=true,
        requires_review=true,
        input_fields=[
          tool_field(
            "patch",
            "string",
            required=true,
            "Unified patch text to apply inside the selected MoonBook.",
          ),
          tool_field(
            "paths",
            "array<string>",
            required=false,
            "Expected book-relative changed paths.",
          ),
        ],
        output_events=["file_change", "diff", "patch_applied", "tool_result"],
        safety_policy="Apply only reviewed patches under the selected MoonBook and emit patch_applied or patch_reverted runtime proof.",
      ),
      tool_contract_entry(
        id="shell",
        lane="tool",
        approval="policy",
        mutates_files=false,
        requires_review=true,
        input_fields=[
          tool_field(
            "cmd",
            "array<string>",
            required=true,
            "Argument-vector command, not a raw shell string.",
          ),
          tool_field(
            "cwd",
            "string",
            required=false,
            "Book-relative working directory.",
          ),
          tool_field(
            "timeout_ms",
            "integer",
            required=false,
            "Bounded execution timeout.",
          ),
        ],
        output_events=["tool_result", "runtime_update"],
        safety_policy="Run bounded commands under the selected book root; destructive or networked commands require explicit policy approval.",
      ),
      tool_contract_entry(
        id="moon_check",
        lane="test",
        approval="auto",
        mutates_files=false,
        requires_review=false,
        input_fields=[
          tool_field(
            "target",
            "string",
            required=false,
            "Optional MoonBit package or file target.",
          ),
          tool_field(
            "command",
            "string",
            required=false,
            "check, test, build, fmt, or info.",
          ),
        ],
        output_events=["test_result", "tool_result"],
        safety_policy="Surface exit code, command, stdout/stderr summary, and failing target as test_result evidence.",
      ),
      tool_contract_entry(
        id="package_app_tool",
        lane="artifact",
        approval="operator",
        mutates_files=true,
        requires_review=true,
        input_fields=[
          tool_field(
            "source",
            "string",
            required=true,
            "Book-relative source path to package.",
          ),
          tool_field(
            "kind",
            "string",
            required=false,
            "tool, miniapp, generated-site, or app-tool.",
          ),
          tool_field(
            "output",
            "string",
            required=false,
            "Book-relative package output path.",
          ),
        ],
        output_events=[
          "diff", "artifact", "package.manifest", "package.index", "package_verified",
          "tool_result",
        ],
        safety_policy="Package accepted executable MoonBook output and emit source inventory plus package verification proof.",
      ),
      tool_contract_entry(
        id="finish",
        lane="review",
        approval="operator",
        mutates_files=false,
        requires_review=true,
        input_fields=[
          tool_field(
            "summary",
            "string",
            required=true,
            "Final implementation summary.",
          ),
          tool_field(
            "tests",
            "array<string>",
            required=false,
            "Validation commands and outcomes.",
          ),
          tool_field(
            "risks",
            "array<string>",
            required=false,
            "Residual risks or missing evidence.",
          ),
        ],
        output_events=["review", "agent_finished"],
        safety_policy="Finish only after file changes, test evidence, and package readiness are available or explicitly called out as missing.",
      ),
    ]),
    "constraints": {
      "workspace_scope": "All paths are selected-MoonBook relative and must resolve inside the book root.",
      "path_rule": "MoonClaw or standalone mooncode validates paths before reading, writing, editing, packaging, or running tools.",
      "diff_rule": "Every mutating tool emits durable file_change and diff events before Moondesk can render accept/reject/package controls.",
      "test_rule": "run_tests and package actions are not complete until test_result or package artifact evidence is appended.",
      "approval_rule": "Moondesk records operator approval intent; MoonClaw enforces policy for shell, write/edit, and package execution.",
      "extraction_rule": "The schema is data-only and can move into a standalone mooncode package without depending on Rabbita UI types.",
    },
  }
}

///|
pub fn tool_contract_tool_ids(contract : Json) -> Array[String] {
  let ids : Array[String] = []
  for tool in json_array_items(contract, "tools") {
    ids.push(json_string(tool, "id", default=""))
  }
  ids
}

///|
fn tool_contract_entry(
  id~ : String,
  lane~ : String,
  approval~ : String,
  mutates_files~ : Bool,
  requires_review~ : Bool,
  input_fields~ : Array[Json],
  output_events~ : Array[String],
  safety_policy~ : String,
) -> Json {
  {
    "id": id,
    "owner": "moonclaw",
    "lane": lane,
    "approval": approval,
    "input_fields": Json::array(input_fields),
    "output_events": string_array_json(output_events),
    "mutates_files": mutates_files,
    "requires_review": requires_review,
    "executable_boundary": "MoonClaw executes; Moondesk renders and records review intent; MoonBook stores accepted artifacts.",
    "safety_policy": safety_policy,
  }
}

///|
fn tool_field(
  name : String,
  type_ : String,
  required~ : Bool,
  description : String,
) -> Json {
  {
    "name": name,
    "type": type_,
    "required": required,
    "description": description,
  }
}

///|
fn string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => Json::string(item) ])
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
test "mooncode tool contract covers openseek builtins" {
  let contract = tool_contract_json()
  assert_eq(json_string(contract, "kind", default=""), "mooncode-tool-contract")
  assert_eq(json_string(contract, "owner", default=""), "moonclaw")
  let ids = tool_contract_tool_ids(contract)
  for required in runtime_tool_names() {
    assert_true(ids.contains(required))
  }
  assert_true(
    json_string(contract, "execution_owner", default="").contains("mooncode"),
  )
  let constraints = match contract {
    Json::Object(object) => object.get("constraints").unwrap_or({})
    _ => {}
  }
  assert_true(
    json_string(constraints, "path_rule", default="").contains(
      "validates paths",
    ),
  )
}

///|
test "mooncode tool contract marks mutating tools for diff review" {
  let contract = tool_contract_json()
  for tool in json_array_items(contract, "tools") {
    if json_bool(tool, "mutates_files", default=false) {
      assert_true(json_bool(tool, "requires_review", default=false))
      let outputs = [
        for event in json_array_items(tool, "output_events") => {
          json_string({ "value": event }, "value", default="")
        }
      ]
      assert_true(outputs.contains("diff"))
    }
  }
}
