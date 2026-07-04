///|
// Model-planner evidence contract for MoonCode runtime events.
//
// This report is intentionally backend-owned: the browser may show work as
// active only after MoonClaw emits command-scoped runtime evidence.

///|
priv struct ModelPlannerCommandEvidence {
  command_id : String
  action : String
  model : String
  command_seen_at : String
  mut runtime_service_started_count : Int
  mut runtime_turn_started_count : Int
  mut planner_started_count : Int
  mut planner_selected_count : Int
  mut planner_failed_count : Int
  mut planner_reasoning_count : Int
  mut model_tool_call_count : Int
  mut tool_result_count : Int
  mut assistant_event_count : Int
  mut terminal_event_count : Int
  mut failure_event_count : Int
  mut latest_event_id : String
  mut latest_status : String
  mut latest_created_at : String
  mut latest_title : String
}

///|
pub fn model_planner_evidence_contract_json() -> Json {
  {
    "kind": "mooncode-model-planner-evidence-contract",
    "protocol": protocol_version(),
    "owner": {
      "runtime": "moonclaw",
      "projection": "mooncode",
      "ui": "moondesk",
    },
    "model_planned_command_rule": "A prompt, steer, or package command with a selected model and no explicit runtime_tool_calls is model-planned.",
    "working_signal_rule": "Moondesk may show active work only after command-scoped MoonClaw evidence exists: runtime.turn_started, runtime.planner_started, planner reasoning, planner-selected tool calls, assistant output, or command-scoped failure.",
    "required_sequence": [
      "command.prompt/command.steer/command.package", "runtime.service_started",
      "runtime.turn_started", "runtime.planner_started or runtime.planner_failed",
      "runtime.planner_selected plus planner reasoning/tool calls, or runtime.planner_failed",
      "tool result evidence when tools run", "assistant response, runtime.turn_finished, or command-scoped failure",
    ],
    "contract_failure_rule": "Once a model-planned turn has runtime.turn_started, missing planner evidence is a runtime contract failure instead of a UI thinking state.",
  }
}

///|
pub fn model_planner_evidence_report(
  session_id : String,
  events : Array[Json],
) -> Json {
  let commands : Array[ModelPlannerCommandEvidence] = []
  let problems : Array[Json] = []
  let mut service_started_count = 0
  let mut service_finished_count = 0
  let mut observed_at = ""
  for event in events {
    observed_at = model_planner_latest_timestamp(
      observed_at,
      json_string(event, "created_at", default=""),
    )
    match model_planner_command_candidate(event) {
      Some(command) =>
        if model_planner_command_index(commands, command.command_id) < 0 {
          commands.push(command)
        }
      None => ()
    }
    let kind = model_planner_event_kind(event)
    if kind == "runtime.service_started" {
      service_started_count += 1
    } else if kind == "runtime.service_finished" ||
      kind == "runtime.service_failed" {
      service_finished_count += 1
    }
  }
  for event in events {
    let command_id = model_planner_event_command_id(event)
    let index = model_planner_command_index(commands, command_id)
    if index >= 0 {
      model_planner_apply_event(commands[index], event)
    } else if command_id != "" && model_planner_event_is_planner_evidence(event) {
      problems.push(
        model_planner_problem(
          event,
          reason="planner-evidence-without-model-command",
          command_id~,
        ),
      )
    }
  }
  let command_items : Array[Json] = []
  let mut pending_count = 0
  let mut running_count = 0
  let mut satisfied_count = 0
  let mut planner_failed_count = 0
  let mut contract_failed_count = 0
  let mut working_evidence_count = 0
  for command in commands {
    command.runtime_service_started_count = service_started_count
    let status = model_planner_command_status(command)
    if model_planner_command_has_working_evidence(command) {
      working_evidence_count += 1
    }
    match status {
      "pending" => pending_count += 1
      "running" | "service-started" => running_count += 1
      "satisfied" => satisfied_count += 1
      "planner-failed" => planner_failed_count += 1
      "contract-failed" => {
        contract_failed_count += 1
        problems.push(model_planner_missing_evidence_problem(command))
      }
      _ => ()
    }
    command_items.push(model_planner_command_json(command, status))
  }
  let status = if contract_failed_count > 0 ||
    problems.length() > contract_failed_count {
    "contract-failed"
  } else if commands.length() == 0 {
    "no-model-planned-commands"
  } else if planner_failed_count > 0 {
    "planner-failed"
  } else if running_count > 0 {
    "running"
  } else if pending_count > 0 {
    "pending"
  } else {
    "satisfied"
  }
  {
    "kind": "mooncode-model-planner-evidence-report",
    "protocol": protocol_version(),
    "session_id": session_id,
    "observed_at": observed_at,
    "status": status,
    "contract_satisfied": status != "contract-failed",
    "model_planned_command_count": commands.length(),
    "pending_command_count": pending_count,
    "running_command_count": running_count,
    "satisfied_command_count": satisfied_count,
    "planner_failed_command_count": planner_failed_count,
    "contract_failed_command_count": contract_failed_count,
    "working_evidence_command_count": working_evidence_count,
    "runtime_service_started_count": service_started_count,
    "runtime_service_finished_count": service_finished_count,
    "problem_count": problems.length(),
    "problems": Json::array(problems),
    "commands": Json::array(command_items),
    "contract": model_planner_evidence_contract_json(),
  }
}

///|
fn model_planner_command_candidate(
  event : Json,
) -> ModelPlannerCommandEvidence? {
  if !model_planner_event_is_command_record(event) {
    return None
  }
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let command_id = json_string(packet, "command_id", default="")
  let action = model_planner_command_action(event, packet)
  let model = model_planner_command_model(event, packet)
  if command_id == "" ||
    model == "" ||
    !model_planner_action_allowed(action) ||
    json_array_items(packet, "runtime_tool_calls").length() > 0 {
    None
  } else {
    Some(
      model_planner_command_evidence(
        command_id~,
        action~,
        model~,
        command_seen_at=json_string(event, "created_at", default=""),
      ),
    )
  }
}

///|
fn model_planner_command_evidence(
  command_id~ : String,
  action~ : String,
  model~ : String,
  command_seen_at~ : String,
) -> ModelPlannerCommandEvidence {
  {
    command_id,
    action,
    model,
    command_seen_at,
    runtime_service_started_count: 0,
    runtime_turn_started_count: 0,
    planner_started_count: 0,
    planner_selected_count: 0,
    planner_failed_count: 0,
    planner_reasoning_count: 0,
    model_tool_call_count: 0,
    tool_result_count: 0,
    assistant_event_count: 0,
    terminal_event_count: 0,
    failure_event_count: 0,
    latest_event_id: "",
    latest_status: "",
    latest_created_at: command_seen_at,
    latest_title: "",
  }
}

///|
fn model_planner_apply_event(
  command : ModelPlannerCommandEvidence,
  event : Json,
) -> Unit {
  let kind = model_planner_event_kind(event)
  let event_name = json_string(event, "event", default="")
  let lane = json_string(event, "lane", default="")
  let status = json_string(event, "status", default="")
  if kind == "runtime.turn_started" {
    command.runtime_turn_started_count += 1
  }
  if kind == "runtime.planner_started" {
    command.planner_started_count += 1
  } else if kind == "runtime.planner_selected" {
    command.planner_selected_count += 1
  } else if kind == "runtime.planner_failed" {
    command.planner_failed_count += 1
  }
  if (kind == "reasoning_delta" || kind == "reasoning_message") &&
    json_string(event, "planner_mode", default="") == "model-tool-calls" {
    command.planner_reasoning_count += 1
  }
  if (kind == event_tool_call() || event_name == event_tool_call()) &&
    json_string(event, "planner_mode", default="") == "model-tool-calls" {
    command.model_tool_call_count += 1
  }
  if event_name == event_tool_result() ||
    (
      json_string(event, "tool_call_id", default="") != "" &&
      status != "running"
    ) {
    command.tool_result_count += 1
  }
  if lane == "transcript" || kind == "assistant" || kind == "assistant_delta" {
    command.assistant_event_count += 1
  }
  if kind == "runtime.turn_finished" ||
    kind == "finish" ||
    event_name == "runtime_finished" ||
    (lane == "transcript" && status == "done") {
    command.terminal_event_count += 1
  }
  if status == "failed" ||
    kind == "command_error" ||
    kind == "turn_failed" ||
    kind == "max_steps_exhausted" ||
    kind == "runtime_unavailable" {
    command.failure_event_count += 1
  }
  let created_at = json_string(event, "created_at", default="")
  command.latest_created_at = model_planner_latest_timestamp(
    command.latest_created_at,
    created_at,
  )
  if created_at == "" || command.latest_created_at == created_at {
    command.latest_event_id = json_string(event, "id", default="")
    command.latest_status = status
    command.latest_title = json_string(event, "title", default="")
  }
}

///|
fn model_planner_command_json(
  command : ModelPlannerCommandEvidence,
  status : String,
) -> Json {
  {
    "command_id": command.command_id,
    "action": command.action,
    "model": command.model,
    "status": status,
    "working_evidence": model_planner_command_has_working_evidence(command),
    "command_seen_at": command.command_seen_at,
    "latest_event_id": command.latest_event_id,
    "latest_status": command.latest_status,
    "latest_title": command.latest_title,
    "latest_created_at": command.latest_created_at,
    "runtime_service_started_count": command.runtime_service_started_count,
    "runtime_turn_started_count": command.runtime_turn_started_count,
    "planner_started_count": command.planner_started_count,
    "planner_selected_count": command.planner_selected_count,
    "planner_failed_count": command.planner_failed_count,
    "planner_reasoning_count": command.planner_reasoning_count,
    "model_tool_call_count": command.model_tool_call_count,
    "tool_result_count": command.tool_result_count,
    "assistant_event_count": command.assistant_event_count,
    "terminal_event_count": command.terminal_event_count,
    "failure_event_count": command.failure_event_count,
    "rule": model_planner_command_rule(command),
  }
}

///|
fn model_planner_command_status(
  command : ModelPlannerCommandEvidence,
) -> String {
  if command.runtime_turn_started_count > 0 &&
    !model_planner_command_has_planner_evidence(command) {
    return "contract-failed"
  }
  if command.planner_failed_count > 0 {
    return "planner-failed"
  }
  if model_planner_command_has_planner_evidence(command) &&
    (command.terminal_event_count > 0 || command.assistant_event_count > 0) {
    return "satisfied"
  }
  if model_planner_command_has_planner_evidence(command) {
    return "running"
  }
  if command.runtime_turn_started_count > 0 {
    return "running"
  }
  if command.runtime_service_started_count > 0 {
    return "service-started"
  }
  "pending"
}

///|
fn model_planner_command_rule(command : ModelPlannerCommandEvidence) -> String {
  if model_planner_command_status(command) == "contract-failed" {
    "MoonClaw started the model-planned turn but did not emit runtime.planner_started, runtime.planner_selected, model planner reasoning, model-planned tool calls, or runtime.planner_failed."
  } else if !model_planner_command_has_working_evidence(command) {
    "The command is queued. The UI must not show a working state until MoonClaw emits command-scoped runtime evidence."
  } else {
    "The visible working state is backed by command-scoped MoonClaw planner/runtime evidence."
  }
}

///|
fn model_planner_missing_evidence_problem(
  command : ModelPlannerCommandEvidence,
) -> Json {
  {
    "reason": "missing-model-planner-evidence-after-turn-start",
    "command_id": command.command_id,
    "action": command.action,
    "model": command.model,
    "latest_event_id": command.latest_event_id,
    "latest_title": command.latest_title,
    "latest_status": command.latest_status,
    "latest_created_at": command.latest_created_at,
  }
}

///|
fn model_planner_problem(
  event : Json,
  reason~ : String,
  command_id~ : String,
) -> Json {
  {
    "reason": reason,
    "command_id": command_id,
    "id": json_string(event, "id", default=""),
    "lane": json_string(event, "lane", default=""),
    "kind": model_planner_event_kind(event),
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "created_at": json_string(event, "created_at", default=""),
  }
}

///|
fn model_planner_command_has_working_evidence(
  command : ModelPlannerCommandEvidence,
) -> Bool {
  command.runtime_turn_started_count > 0 ||
  command.planner_started_count > 0 ||
  command.planner_selected_count > 0 ||
  command.planner_failed_count > 0 ||
  command.planner_reasoning_count > 0 ||
  command.model_tool_call_count > 0 ||
  command.tool_result_count > 0 ||
  command.assistant_event_count > 0 ||
  command.failure_event_count > 0
}

///|
fn model_planner_command_has_planner_evidence(
  command : ModelPlannerCommandEvidence,
) -> Bool {
  command.planner_started_count > 0 ||
  command.planner_selected_count > 0 ||
  command.planner_failed_count > 0 ||
  command.planner_reasoning_count > 0 ||
  command.model_tool_call_count > 0
}

///|
fn model_planner_event_is_command_record(event : Json) -> Bool {
  let kind = model_planner_event_kind(event)
  kind == "command.prompt" ||
  kind == "command.steer" ||
  kind == "command.package"
}

///|
fn model_planner_event_is_planner_evidence(event : Json) -> Bool {
  let kind = model_planner_event_kind(event)
  kind == "runtime.planner_started" ||
  kind == "runtime.planner_selected" ||
  kind == "runtime.planner_failed" ||
  json_string(event, "planner_mode", default="") == "model-tool-calls"
}

///|
fn model_planner_event_command_id(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_id = json_string(packet, "command_id", default="")
  if packet_id != "" {
    return packet_id
  }
  runtime_first_string(
    event,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
}

///|
fn model_planner_event_kind(event : Json) -> String {
  runtime_first_string(event, ["kind", "event"], default="")
}

///|
fn model_planner_command_action(event : Json, packet : Json) -> String {
  let action = json_string(packet, "action", default="")
  if action != "" {
    return action
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let kind = model_planner_event_kind(event)
  if kind.has_prefix("command.") {
    kind["command.".length():].to_owned()
  } else {
    "prompt"
  }
}

///|
fn model_planner_command_model(event : Json, packet : Json) -> String {
  let model = json_string(packet, "model", default="")
  if model != "" {
    model
  } else {
    json_string(event, "model", default="")
  }
}

///|
fn model_planner_action_allowed(action : String) -> Bool {
  action == "prompt" || action == "steer" || action == "package"
}

///|
fn model_planner_command_index(
  commands : Array[ModelPlannerCommandEvidence],
  command_id : String,
) -> Int {
  if command_id == "" {
    return -1
  }
  for index, command in commands {
    if command.command_id == command_id {
      return index
    }
  }
  -1
}

///|
fn model_planner_latest_timestamp(
  current : String,
  incoming : String,
) -> String {
  if incoming == "" {
    current
  } else if current == "" || incoming.compare(current) > 0 {
    incoming
  } else {
    current
  }
}
