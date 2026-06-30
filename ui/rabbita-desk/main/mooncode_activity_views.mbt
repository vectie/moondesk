///|
struct MoonCodeActivityRow {
  tone : String
  label : String
  title : String
  detail : String
  status : String
}

///|
fn render_mooncode_activity_row(row : MoonCodeActivityRow) -> @rabbita.Html {
  div(class="mooncode-activity-row " + row.tone + " " + row.status, [
    div(class="mooncode-activity-dot", ""),
    div(class="mooncode-activity-copy", [
      div(class="mooncode-activity-line", [
        strong(row.label),
        span(row.status),
      ]),
      p(class="mooncode-activity-title", row.title),
      if row.detail == "" {
        span(class="mooncode-activity-detail empty", "")
      } else {
        pre(class="mooncode-activity-detail", row.detail)
      },
    ]),
  ])
}

///|
fn mooncode_activity_row_from_event(
  event : MoonCodeEvent,
) -> MoonCodeActivityRow? {
  if mooncode_event_is_user_prompt(event) ||
    mooncode_event_is_assistant_delta(event) ||
    mooncode_event_is_assistant_final(event) ||
    mooncode_activity_is_finish_tool_call(event) ||
    mooncode_activity_is_control_bookkeeping(event) ||
    mooncode_activity_is_idle_bookkeeping(event) ||
    mooncode_activity_is_manifest_bookkeeping(event) {
    return None
  }
  if mooncode_activity_is_reasoning(event) {
    return Some(mooncode_activity_row(
      tone="thinking",
      label="Thinking",
      title=mooncode_activity_title(event, "Model reasoning"),
      detail=mooncode_activity_detail(event),
      status=event.status,
    ))
  }
  if mooncode_activity_is_tool_start(event) {
    return Some(mooncode_activity_row(
      tone=mooncode_activity_tool_tone(event),
      label=mooncode_activity_tool_label_for_event(event),
      title=mooncode_activity_tool_title(event),
      detail=mooncode_activity_tool_detail(event),
      status=event.status,
    ))
  }
  if mooncode_activity_is_tool_result(event) {
    return Some(mooncode_activity_row(
      tone=mooncode_activity_result_tone(event),
      label=mooncode_activity_result_label(event),
      title=mooncode_activity_result_title(event),
      detail=mooncode_activity_result_detail(event),
      status=event.status,
    ))
  }
  if mooncode_activity_is_edit(event) {
    return Some(mooncode_activity_row(
      tone="edit",
      label="Edited",
      title=mooncode_activity_title(event, "File change"),
      detail=mooncode_activity_detail(event),
      status=event.status,
    ))
  }
  if mooncode_activity_is_test(event) {
    return Some(mooncode_activity_row(
      tone="test",
      label="Checked",
      title=mooncode_activity_title(event, "Validation"),
      detail=mooncode_activity_result_detail(event),
      status=event.status,
    ))
  }
  if mooncode_activity_is_runtime(event) {
    return Some(mooncode_activity_row(
      tone=if event.status == "failed" { "failed" } else { "runtime" },
      label=mooncode_activity_runtime_label(event),
      title=mooncode_activity_title(event, "Runtime"),
      detail=mooncode_activity_runtime_detail(event),
      status=event.status,
    ))
  }
  None
}

///|
fn mooncode_activity_row(
  tone~ : String,
  label~ : String,
  title~ : String,
  detail~ : String,
  status~ : String,
) -> MoonCodeActivityRow {
  {
    tone,
    label,
    title: mooncode_activity_clamp(title, 96),
    detail: mooncode_activity_clamp(detail, 360),
    status: if status == "" { "active" } else { status },
  }
}

///|
fn mooncode_activity_is_reasoning(event : MoonCodeEvent) -> Bool {
  event.kind == "reasoning_delta" ||
  event.kind == "reasoning_message" ||
  event.kind == "runtime.planner_started" ||
  event.kind == "runtime.planner_selected" ||
  (
    event.kind == "runtime_update" &&
    (
      event.detail.contains("asking model") ||
      event.detail.contains("model-tool-calls") ||
      (
        event.detail.contains("selected") &&
        event.detail.contains("tool call")
      )
    )
  ) ||
  event.title.contains("planner") ||
  event.title.contains("Planner")
}

///|
fn mooncode_activity_is_tool_start(event : MoonCodeEvent) -> Bool {
  event.kind == "tool_call" ||
  event.kind == "tool_started" ||
  event.title.contains("Tool started")
}

///|
fn mooncode_activity_is_finish_tool_call(event : MoonCodeEvent) -> Bool {
  if event.kind != "tool_call" && event.kind != "tool_started" {
    return false
  }
  let tool_name = mooncode_activity_tool_name(event)
  tool_name == "finish" || tool_name == "prompt" || tool_name == "steer"
}

///|
fn mooncode_activity_is_tool_result(event : MoonCodeEvent) -> Bool {
  event.kind == "tool_result" ||
  event.kind == "runtime.tool_result" ||
  event.tool_result is Some(_)
}

///|
fn mooncode_activity_is_edit(event : MoonCodeEvent) -> Bool {
  event.lane == "diff" ||
  event.kind == "diff" ||
  event.kind == "file_change" ||
  event.kind == "patch_applied" ||
  event.kind == "patch_reverted" ||
  event.kind.contains("change_set") ||
  event.kind.contains("patch_set")
}

///|
fn mooncode_activity_is_test(event : MoonCodeEvent) -> Bool {
  event.lane == "test" ||
  event.kind == "test_result" ||
  event.kind == "moon_check" ||
  event.kind == "moon_cmd" ||
  event.title.contains("test") ||
  event.title.contains("check")
}

///|
fn mooncode_activity_is_runtime(event : MoonCodeEvent) -> Bool {
  event.lane == "runtime" ||
  event.kind.contains("runtime") ||
  event.kind == "usage" ||
  event.kind == "command_error" ||
  event.kind == "turn_failed" ||
  event.kind == "max_steps_exhausted"
}

///|
fn mooncode_activity_is_control_bookkeeping(event : MoonCodeEvent) -> Bool {
  event.kind == "runtime.command_queued" ||
  event.kind == "runtime.turn_started" ||
  event.kind == "runtime.turn_finished" ||
  event.kind == "runtime.service_started" ||
  event.kind == "runtime.service_finished" ||
  event.kind == "runtime_loop" ||
  event.kind == "usage"
}

///|
fn mooncode_activity_is_idle_bookkeeping(event : MoonCodeEvent) -> Bool {
  event.kind == "runtime_loop" &&
  event.status == "done" &&
  event.title.contains("idle")
}

///|
fn mooncode_activity_is_manifest_bookkeeping(event : MoonCodeEvent) -> Bool {
  event.kind.contains(".manifest") ||
  event.kind == "runtime.handoff" ||
  event.kind == "action_plan" ||
  event.kind == "runtime_evidence" ||
  (
    event.title.contains("command queued") &&
    event.detail.contains("Queued `prompt`")
  )
}

///|
fn mooncode_activity_title(event : MoonCodeEvent, fallback : String) -> String {
  match mooncode_activity_clean_title(event) {
    Some(title) => return title
    None => ()
  }
  if event.title.has_prefix("Tool started") {
    fallback
  } else if event.title != "" {
    event.title
  } else if event.kind != "" {
    fallback
  } else {
    fallback
  }
}

///|
fn mooncode_activity_tool_title(event : MoonCodeEvent) -> String {
  match mooncode_activity_tool_subject(event) {
    Some(subject) => return subject
    None => ()
  }
  let tool_name = mooncode_activity_tool_name(event)
  if tool_name != "" {
    return mooncode_activity_tool_default_title(event)
  }
  if event.command != "" && event.command != "prompt" && event.command != "steer" {
    "Command: " + event.command
  } else if event.kind != "" {
    "Tool"
  } else {
    "Tool call"
  }
}

///|
fn mooncode_activity_tool_detail(event : MoonCodeEvent) -> String {
  match mooncode_activity_tool_subject(event) {
    Some(_) => return ""
    None => ()
  }
  let command = mooncode_activity_tool_command(event)
  if command != "" {
    return command
  }
  if event.path != "" {
    return event.path
  }
  if event.detail.trim().has_prefix("{") {
    ""
  } else {
    mooncode_activity_detail(event)
  }
}

///|
fn mooncode_activity_tool_tone(event : MoonCodeEvent) -> String {
  let tool_name = mooncode_activity_normalized_tool_name(event)
  if mooncode_activity_tool_is_edit(tool_name) {
    "edit"
  } else if mooncode_activity_tool_is_test(
    tool_name,
    mooncode_activity_tool_command(event),
  ) {
    "test"
  } else {
    "tool"
  }
}

///|
fn mooncode_activity_tool_label_for_event(event : MoonCodeEvent) -> String {
  let tool_name = mooncode_activity_normalized_tool_name(event)
  if tool_name == "websearch" || tool_name == "web_search" {
    "Searching web"
  } else if tool_name == "webfetch" || tool_name == "web_fetch" {
    "Reading web page"
  } else if tool_name == "fileread" ||
    tool_name == "file_read" ||
    tool_name == "read" {
    "Reading file"
  } else if tool_name == "filewrite" ||
    tool_name == "file_write" ||
    tool_name == "write" {
    "Writing file"
  } else if tool_name == "fileedit" ||
    tool_name == "file_edit" ||
    tool_name == "notebookedit" ||
    tool_name == "notebook_edit" ||
    tool_name == "edit" ||
    tool_name == "apply_patch" ||
    tool_name == "revert_patch" {
    "Editing file"
  } else if tool_name == "bash" || tool_name == "shell" {
    if mooncode_activity_command_is_test(mooncode_activity_tool_command(event)) {
      "Running tests"
    } else {
      "Running command"
    }
  } else if tool_name == "grep" {
    "Searching files"
  } else if tool_name == "glob" {
    "Finding files"
  } else if tool_name == "todowrite" || tool_name == "todo_write" {
    "Updating plan"
  } else if tool_name == "moon_check" {
    "Checking project"
  } else if tool_name == "moon_cmd" {
    "Running Moon command"
  } else if tool_name == "moon_ide" {
    "Inspecting code"
  } else if tool_name == "package_app_tool" {
    "Packaging app"
  } else {
    "Using tool"
  }
}

///|
fn mooncode_activity_tool_default_title(event : MoonCodeEvent) -> String {
  let tool_name = mooncode_activity_normalized_tool_name(event)
  if tool_name == "moon_check" {
    "moon check"
  } else if tool_name == "moon_cmd" {
    "moon command"
  } else {
    mooncode_activity_tool_label_for_event(event)
  }
}

///|
fn mooncode_activity_result_tone(event : MoonCodeEvent) -> String {
  if event.status == "failed" || event.exit_code != 0 {
    "failed"
  } else if mooncode_activity_is_test(event) {
    "test"
  } else {
    "tool"
  }
}

///|
fn mooncode_activity_result_label(event : MoonCodeEvent) -> String {
  if event.status == "failed" || event.exit_code != 0 {
    "Failed"
  } else if mooncode_activity_is_test(event) {
    "Checked"
  } else {
    "Completed"
  }
}

///|
fn mooncode_activity_result_title(event : MoonCodeEvent) -> String {
  match mooncode_activity_tool_subject(event) {
    Some(subject) => return subject
    None => ()
  }
  let tool_name = mooncode_activity_normalized_tool_name(event)
  if tool_name != "" {
    mooncode_activity_tool_default_title(event)
  } else {
    mooncode_activity_title(event, "Completed step")
  }
}

///|
fn mooncode_activity_result_detail(event : MoonCodeEvent) -> String {
  match event.tool_result {
    Some(result) => {
      let output = json_string_value(result, "output", default="")
        .trim()
        .to_owned()
      if output != "" {
        match mooncode_activity_package_result_summary(output) {
          Some(summary) => return summary
          None => return output
        }
      }
      let message = json_string_value(result, "message", default="")
        .trim()
        .to_owned()
      if message != "" {
        return message
      }
    }
    None => ()
  }
  mooncode_activity_detail(event)
}

///|
fn mooncode_activity_package_result_summary(output : String) -> String? {
  let text = output.trim().to_owned()
  if !text.has_prefix("{") {
    return None
  }
  let parsed = @json.parse(text) catch { _ => Json::object({}) }
  match parsed {
    Object(_) => mooncode_activity_package_result_json_summary(parsed)
    _ => None
  }
}

///|
fn mooncode_activity_package_result_json_summary(result : Json) -> String? {
  match mooncode_activity_package_file_read_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  match mooncode_activity_package_file_change_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  match mooncode_activity_package_search_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  match mooncode_activity_package_web_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  match mooncode_activity_package_command_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  match mooncode_activity_package_todo_summary(result) {
    Some(summary) => return Some(summary)
    None => ()
  }
  None
}

///|
fn mooncode_activity_package_file_read_summary(result : Json) -> String? {
  let file = mooncode_activity_json_object_field_or_empty(result, "file")
  let path = mooncode_activity_first_json_string(
    file,
    ["filePath", "file_path", "path"],
  )
  if path == "" {
    return None
  }
  let content = json_string_value(file, "content", default="")
  let num_lines = json_int_value(file, "numLines", default=0)
  let total_lines = json_int_value(file, "totalLines", default=0)
  if content == "" && num_lines == 0 && total_lines == 0 {
    return None
  }
  let lines = if num_lines > 0 {
    num_lines
  } else if total_lines > 0 {
    total_lines
  } else {
    0
  }
  if lines > 0 {
    Some("Read \{lines} line(s) from \{path}.")
  } else {
    Some("Read \{path}.")
  }
}

///|
fn mooncode_activity_package_file_change_summary(result : Json) -> String? {
  let path = mooncode_activity_first_json_string(
    result,
    ["filePath", "file_path", "path"],
  )
  if path == "" {
    return None
  }
  let change_type = json_string_value(result, "type", default="")
  let git_diff = mooncode_activity_json_object_field_or_empty(result, "gitDiff")
  let additions = json_int_value(git_diff, "additions", default=0)
  let deletions = json_int_value(git_diff, "deletions", default=0)
  if additions > 0 || deletions > 0 {
    Some("Updated \{path} (+\{additions} -\{deletions}).")
  } else if change_type == "create" {
    Some("Created \{path}.")
  } else if change_type == "update" {
    Some("Updated \{path}.")
  } else {
    Some("Edited \{path}.")
  }
}

///|
fn mooncode_activity_package_search_summary(result : Json) -> String? {
  let num_files = json_int_value(result, "numFiles", default=-1)
  let num_matches = json_int_value(result, "numMatches", default=-1)
  if num_files < 0 && num_matches < 0 {
    return None
  }
  if num_matches >= 0 {
    Some("Found \{num_matches} match(es) in \{num_files} file(s).")
  } else {
    Some("Found \{num_files} file(s).")
  }
}

///|
fn mooncode_activity_package_web_summary(result : Json) -> String? {
  let query = json_string_value(result, "query", default="").trim().to_owned()
  if query != "" {
    let count = mooncode_activity_package_web_result_count(result)
    if count > 0 {
      return Some("Found \{count} web result(s) for \{query}.")
    }
    return Some("Searched the web for \{query}.")
  }
  let url = json_string_value(result, "url", default="").trim().to_owned()
  if url != "" {
    let code = json_int_value(result, "code", default=0)
    if code > 0 {
      Some("Read \{url} (HTTP \{code}).")
    } else {
      Some("Read \{url}.")
    }
  } else {
    None
  }
}

///|
fn mooncode_activity_package_web_result_count(result : Json) -> Int {
  let mut count = 0
  match json_field(result, "results") {
    Some(Array(items)) =>
      for item in items {
        match item {
          Object(_) => {
            match json_field(item, "content") {
              Some(Array(hits)) => count += hits.length()
              _ => ()
            }
          }
          String(text) if text.trim() != "" => count += 1
          _ => ()
        }
      }
    _ => ()
  }
  count
}

///|
fn mooncode_activity_package_command_summary(result : Json) -> String? {
  let interrupted = mooncode_activity_json_bool_value(
    result,
    "interrupted",
    default=false,
  )
  let backgrounded = mooncode_activity_json_bool_value(
    result,
    "backgroundedByUser",
    default=false,
  ) ||
    mooncode_activity_json_bool_value(
      result,
      "assistantAutoBackgrounded",
      default=false,
    )
  if interrupted {
    return Some("Command was interrupted.")
  }
  if backgrounded {
    return Some("Command is running in the background.")
  }
  let stdout = json_string_value(result, "stdout", default="").trim().to_owned()
  let stderr = json_string_value(result, "stderr", default="").trim().to_owned()
  if stdout != "" && stdout.length() <= 220 {
    Some(stdout)
  } else if stderr != "" && stderr.length() <= 220 {
    Some(stderr)
  } else if stdout != "" || stderr != "" {
    Some("Command completed with output.")
  } else {
    None
  }
}

///|
fn mooncode_activity_package_todo_summary(result : Json) -> String? {
  match json_field(result, "newTodos") {
    Some(Array(todos)) => Some("Updated plan with \{todos.length()} item(s).")
    _ => None
  }
}

///|
fn mooncode_activity_json_bool_value(
  json : Json,
  key : String,
  default~ : Bool,
) -> Bool {
  match json_field(json, key) {
    Some(value) => @json.from_json(value) catch { _ => default }
    None => default
  }
}

///|
fn mooncode_activity_runtime_label(event : MoonCodeEvent) -> String {
  if event.kind.contains("finished") || event.kind.contains("turn_finished") {
    "Finished"
  } else if event.kind.contains("started") || event.status == "running" {
    "Running"
  } else if event.status == "failed" {
    "Failed"
  } else {
    "Runtime"
  }
}

///|
fn mooncode_activity_runtime_detail(event : MoonCodeEvent) -> String {
  if event.kind == "runtime.planner_started" ||
    event.kind == "runtime.planner_selected" ||
    event.kind == "runtime.turn_started" ||
    event.kind == "runtime.turn_finished" {
    ""
  } else {
    mooncode_activity_detail(event)
  }
}

///|
fn mooncode_activity_clean_title(event : MoonCodeEvent) -> String? {
  match event.kind {
    "runtime.command_queued" => Some("Queued")
    "runtime.planner_started" => Some("Planning next step")
    "runtime.planner_selected" => Some("Selected next action")
    "runtime.turn_started" => Some("Started working")
    "runtime.turn_finished" => Some("Finished step")
    "reasoning_delta" | "reasoning_message" => Some("Thinking")
    _ => {
      if event.kind == "runtime_update" &&
        event.detail.contains("asking model") {
        Some("Choosing next action")
      } else if event.kind == "runtime_update" &&
        (
          event.detail.contains("model-tool-calls") ||
          (
            event.detail.contains("selected") &&
            event.detail.contains("tool call")
          )
        ) {
        Some("Selected next action")
      } else if event.title.contains("planner") || event.title.contains("Planner") {
        Some("Thinking")
      } else {
        None
      }
    }
  }
}

///|
fn mooncode_activity_tool_name(event : MoonCodeEvent) -> String {
  let detail = mooncode_activity_detail_json(event)
  let tool = mooncode_activity_first_json_string(
    detail,
    ["tool", "tool_name", "name"],
  )
  if tool != "" {
    return tool
  }
  match json_field(detail, "tool_call") {
    Some(Object(_)) => {
      let tool_call = mooncode_activity_json_object_field_or_empty(
        detail,
        "tool_call",
      )
      let function = mooncode_activity_json_object_field_or_empty(
        tool_call,
        "function",
      )
      let name = json_string_value(function, "name", default="")
      if name != "" {
        return name
      }
    }
    _ => ()
  }
  if event.kind != "" &&
    event.kind != "tool_call" &&
    event.kind != "tool_started" &&
    event.kind != "tool_result" &&
    event.kind != "runtime.tool_result" {
    return event.kind
  }
  ""
}

///|
fn mooncode_activity_normalized_tool_name(event : MoonCodeEvent) -> String {
  mooncode_activity_tool_name(event).replace(old="-", new="_").to_lower()
}

///|
fn mooncode_activity_tool_args(event : MoonCodeEvent) -> Json {
  let detail = mooncode_activity_detail_json(event)
  match json_field(detail, "parsed_arguments") {
    Some(Object(_)) => return mooncode_activity_json_object_field_or_empty(
      detail,
      "parsed_arguments",
    )
    _ => ()
  }
  match mooncode_activity_first_json_argument(detail, [
    "arguments", "args", "input",
  ]) {
    Some(args) => return args
    None => ()
  }
  let tool_call = mooncode_activity_json_object_field_or_empty(
    detail,
    "tool_call",
  )
  let function = mooncode_activity_json_object_field_or_empty(
    tool_call,
    "function",
  )
  match mooncode_activity_first_json_argument(function, ["arguments"]) {
    Some(args) => args
    None => detail
  }
}

///|
fn mooncode_activity_tool_subject(event : MoonCodeEvent) -> String? {
  if event.path != "" {
    return Some(event.path)
  }
  let args = mooncode_activity_tool_args(event)
  let subject = mooncode_activity_first_json_string(
    args,
    [
      "description", "query", "url", "file_path", "path", "pattern", "command",
      "notebook_path", "filePath", "file", "target", "cwd",
    ],
  )
  if subject != "" {
    return Some(subject)
  }
  let command = mooncode_activity_tool_command(event)
  if command != "" {
    Some(command)
  } else {
    mooncode_activity_todo_subject(args)
  }
}

///|
fn mooncode_activity_first_json_string(
  json : Json,
  keys : Array[String],
) -> String {
  for key in keys {
    let value = json_string_value(json, key, default="").trim().to_owned()
    if value != "" {
      return value
    }
  }
  ""
}

///|
fn mooncode_activity_detail_json(event : MoonCodeEvent) -> Json {
  let detail = event.detail.trim().to_owned()
  if detail.has_prefix("{") {
    @json.parse(detail) catch { _ => Json::object({}) }
  } else {
    Json::object({})
  }
}

///|
fn mooncode_activity_json_object_field_or_empty(
  json : Json,
  key : String,
) -> Json {
  match json_field(json, key) {
    Some(value) =>
      match value {
        Object(_) => value
        _ => Json::object({})
      }
    _ => Json::object({ })
  }
}

///|
fn mooncode_activity_first_json_argument(
  json : Json,
  keys : Array[String],
) -> Json? {
  for key in keys {
    match json_field(json, key) {
      Some(String(text)) => {
        let parsed = @json.parse(text.trim().to_owned()) catch {
          _ => Json::object({})
        }
        match parsed {
          Object(_) => return Some(parsed)
          _ => ()
        }
      }
      Some(value) =>
        match value {
          Object(_) => return Some(value)
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn mooncode_activity_tool_command(event : MoonCodeEvent) -> String {
  if event.command != "" && event.command != "prompt" && event.command != "steer" {
    return event.command
  }
  let args = mooncode_activity_tool_args(event)
  let command = mooncode_activity_first_json_string(
    args,
    ["command", "cmd"],
  )
  if command != "" {
    return command
  }
  match json_field(args, "cmd") {
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
    _ => ""
  }
}

///|
fn mooncode_activity_todo_subject(args : Json) -> String? {
  match json_field(args, "todos") {
    Some(Array(todos)) => {
      for todo in todos {
        let status = json_string_value(todo, "status", default="")
        if status == "in_progress" {
          let text = mooncode_activity_first_json_string(
            todo,
            ["activeForm", "content"],
          )
          if text != "" {
            return Some(text)
          }
        }
      }
      for todo in todos {
        let text = mooncode_activity_first_json_string(
          todo,
          ["activeForm", "content"],
        )
        if text != "" {
          return Some(text)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn mooncode_activity_tool_is_edit(tool_name : String) -> Bool {
  tool_name == "fileedit" ||
  tool_name == "file_edit" ||
  tool_name == "filewrite" ||
  tool_name == "file_write" ||
  tool_name == "notebookedit" ||
  tool_name == "notebook_edit" ||
  tool_name == "edit" ||
  tool_name == "write" ||
  tool_name == "apply_patch" ||
  tool_name == "revert_patch"
}

///|
fn mooncode_activity_tool_is_test(tool_name : String, command : String) -> Bool {
  tool_name == "moon_check" ||
  tool_name == "moon_cmd" ||
  mooncode_activity_command_is_test(command)
}

///|
fn mooncode_activity_command_is_test(command : String) -> Bool {
  let normalized = command.to_lower()
  normalized.contains("test") ||
  normalized.contains("check") ||
  normalized.contains("build")
}

///|
fn mooncode_activity_clean_detail(event : MoonCodeEvent) -> String? {
  match event.kind {
    "runtime.planner_started" |
    "runtime.planner_selected" |
    "runtime.turn_started" |
    "runtime.turn_finished" => Some("")
    _ => {
      if event.detail.contains("Queued `prompt`") {
        Some("")
      } else if event.detail.contains("model-tool-calls") ||
        (
          event.detail.contains("selected") &&
          event.detail.contains("tool call")
        ) {
        Some("Selected the next action.")
      } else if event.detail.contains("asking model") &&
        event.detail.contains("tool batch") {
        Some("Choosing the next action.")
      } else {
        None
      }
    }
  }
}

///|
fn mooncode_activity_detail(event : MoonCodeEvent) -> String {
  match mooncode_activity_clean_detail(event) {
    Some(detail) => return detail
    None => ()
  }
  if event.command != "" && event.command != "prompt" && event.command != "steer" {
    return event.command
  }
  if event.path != "" && event.detail == "" {
    return event.path
  }
  let detail = event.detail.trim().to_owned()
  if detail != "" {
    detail
  } else if event.path != "" {
    event.path
  } else {
    ""
  }
}

///|
fn mooncode_activity_clamp(text : String, limit : Int) -> String {
  let normalized = text.trim().replace(old="\r", new="").to_owned()
  if normalized.length() <= limit {
    normalized
  } else {
    normalized[:limit].to_owned() + "..."
  }
}
