///|
/// The command actions accepted by the current MoonCode native runtime.
pub(all) enum MoonCodeCommandKind {
  Prompt
  Steer
  RunTests
  RunBuild
  RunEval
  Package
  Commit
  Accept
  Reject
  ApproveTool
  RejectTool
  ApplyPatch
  RevertPatch
  Cancel
  Note
} derive(Debug, Eq)

///|
/// The daemon-owned status of an accepted command packet.
pub enum MoonCodeCommandStatus {
  Accepted
} derive(Debug, Eq)

///|
/// A validated caller-owned command submission containing neither daemon-owned
/// acceptance fields nor transport JSON.
pub(all) struct MoonCodeCommand {
  kind : MoonCodeCommandKind
  client_turn_id : String
  context_path : String
  message : String
  model : String
  web_search : Bool
  planner_max_steps : Int?
  approval_id : String
  target_command_id : String
  tool_call_id : String
  force_preflight : Bool
} derive(Debug, Eq)

///|
pub fn MoonCodeCommandKind::to_string(self : MoonCodeCommandKind) -> String {
  match self {
    Prompt => "prompt"
    Steer => "steer"
    RunTests => "run_tests"
    RunBuild => "run_build"
    RunEval => "run_eval"
    Package => "package"
    Commit => "commit"
    Accept => "accept"
    Reject => "reject"
    ApproveTool => "approve_tool"
    RejectTool => "reject_tool"
    ApplyPatch => "apply_patch"
    RevertPatch => "revert_patch"
    Cancel => "cancel"
    Note => "note"
  }
}

///|
pub fn MoonCodeCommandStatus::to_string(self : MoonCodeCommandStatus) -> String {
  match self {
    Accepted => "accepted"
  }
}

///|
fn mooncode_command_kind(action : String) -> MoonCodeCommandKind? {
  match action {
    "prompt" => Some(Prompt)
    "steer" => Some(Steer)
    "run_tests" => Some(RunTests)
    "run_build" => Some(RunBuild)
    "run_eval" => Some(RunEval)
    "package" => Some(Package)
    "commit" => Some(Commit)
    "accept" => Some(Accept)
    "reject" => Some(Reject)
    "approve_tool" => Some(ApproveTool)
    "reject_tool" => Some(RejectTool)
    "apply_patch" => Some(ApplyPatch)
    "revert_patch" => Some(RevertPatch)
    "cancel" => Some(Cancel)
    "note" => Some(Note)
    _ => None
  }
}

///|
fn command_codec_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    Some(_) => None
    None => Some("")
  }
}

///|
fn command_codec_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => None
    None => Some(false)
  }
}

///|
fn command_codec_planner_max_steps(
  fields : Map[String, Json],
) -> Result[Int?, String] {
  match fields.get("planner_max_steps") {
    None | Some(Null) => Ok(None)
    Some(Number(value, repr=_)) => {
      let steps = value.to_int()
      if steps > 0 && steps.to_double() == value {
        Ok(Some(steps))
      } else {
        Err("planner_max_steps must be a positive integer when supplied")
      }
    }
    Some(_) => Err("planner_max_steps must be a positive integer when supplied")
  }
}

///|
fn command_codec_requires_target(kind : MoonCodeCommandKind) -> Bool {
  kind is ApproveTool ||
  kind is RejectTool ||
  kind is ApplyPatch ||
  kind is RevertPatch ||
  kind is Cancel
}

///|
fn command_codec_requires_approval(kind : MoonCodeCommandKind) -> Bool {
  kind is ApproveTool || kind is RejectTool
}

///|
fn command_codec_invalid_combination(command : MoonCodeCommand) -> String? {
  let has_target = command.target_command_id != ""
  let has_approval = command.approval_id != ""
  let has_tool_call = command.tool_call_id != ""
  if command.client_turn_id == "" {
    Some("client_turn_id is required")
  } else if command_codec_requires_target(command.kind) && !has_target {
    Some("target_command_id is required for this command")
  } else if !command_codec_requires_target(command.kind) && has_target {
    Some("target_command_id is not valid for this command")
  } else if command_codec_requires_approval(command.kind) &&
    (!has_approval || !has_tool_call) {
    Some("approval_id and tool_call_id are required for tool decisions")
  } else if !command_codec_requires_approval(command.kind) &&
    (has_approval || has_tool_call) {
    Some("approval_id and tool_call_id are not valid for this command")
  } else {
    None
  }
}

///|
/// Decode and validate a caller-owned command submission.
pub fn decode_mooncode_command(
  payload : Json,
) -> Result[MoonCodeCommand, String] {
  guard payload is Object(fields) else {
    return Err("MoonCode command must be a JSON object")
  }
  let action = match fields.get("action") {
    Some(String(value)) => value
    _ => return Err("action must be a string")
  }
  let kind = match mooncode_command_kind(action) {
    Some(value) => value
    None => return Err("unsupported MoonCode command action: \{action}")
  }
  let planner_max_steps = match command_codec_planner_max_steps(fields) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let string_keys = [
    "client_turn_id", "context_path", "message", "model", "approval_id", "target_command_id",
    "tool_call_id",
  ]
  let strings : Array[String] = []
  for key in string_keys {
    match command_codec_string(fields, key) {
      Some(value) => strings.push(value)
      None => return Err("\{key} must be a string")
    }
  }
  let web_search = match command_codec_bool(fields, "web_search") {
    Some(value) => value
    None => return Err("web_search must be a boolean")
  }
  let force_preflight = match command_codec_bool(fields, "force_preflight") {
    Some(value) => value
    None => return Err("force_preflight must be a boolean")
  }
  let command = MoonCodeCommand::{
    kind,
    client_turn_id: strings[0],
    context_path: strings[1],
    message: strings[2],
    model: strings[3],
    web_search,
    planner_max_steps,
    approval_id: strings[4],
    target_command_id: strings[5],
    tool_call_id: strings[6],
    force_preflight,
  }
  match command_codec_invalid_combination(command) {
    Some(error) => Err(error)
    None => Ok(command)
  }
}

///|
fn command_codec_submission_fields(
  command : MoonCodeCommand,
) -> Map[String, Json] {
  {
    "action": command.kind.to_string().to_json(),
    "client_turn_id": command.client_turn_id.to_json(),
    "context_path": command.context_path.to_json(),
    "message": command.message.to_json(),
    "model": command.model.to_json(),
    "web_search": command.web_search.to_json(),
    "approval_id": command.approval_id.to_json(),
    "target_command_id": command.target_command_id.to_json(),
    "tool_call_id": command.tool_call_id.to_json(),
    "force_preflight": command.force_preflight.to_json(),
  }
}

///|
/// The sole supported-action encoder for caller command submissions.
pub fn encode_mooncode_command(
  command : MoonCodeCommand,
) -> Result[Json, String] {
  match command_codec_invalid_combination(command) {
    Some(error) => Err(error)
    None => {
      let fields = command_codec_submission_fields(command)
      match command.planner_max_steps {
        Some(value) if value > 0 =>
          fields["planner_max_steps"] = value.to_json()
        Some(_) =>
          return Err(
            "planner_max_steps must be a positive integer when supplied",
          )
        None => ()
      }
      Ok(Json::object(fields))
    }
  }
}
